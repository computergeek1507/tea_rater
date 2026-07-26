import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const TeaRaterApp());

enum Rating { up, middle, down }

extension RatingX on Rating {
  String get label => switch (this) {
        Rating.up => 'up',
        Rating.middle => 'middle',
        Rating.down => 'down',
      };
  IconData get icon => switch (this) {
        Rating.up => Icons.thumb_up,
        Rating.middle => Icons.thumbs_up_down,
        Rating.down => Icons.thumb_down,
      };
  Color get color => switch (this) {
        Rating.up => const Color(0xFF1976D2),
        Rating.middle => const Color(0xFF78909C),
        Rating.down => const Color(0xFFF57C00),
      };
  static Rating? fromLabel(String? s) {
    for (final r in Rating.values) {
      if (r.label == s) return r;
    }
    return null;
  }
}

class Tea {
  Tea({
    required this.name,
    this.rating = Rating.middle,
    this.notes = '',
    this.count = 1,
  });
  String name;
  Rating rating;
  String notes;
  int count;

  Map<String, dynamic> toJson() => {
        'name': name,
        'rating': rating.label,
        'notes': notes,
        'count': count,
      };

  static Tea fromJson(Map<String, dynamic> j) => Tea(
        name: (j['name'] ?? '').toString(),
        rating: RatingX.fromLabel(j['rating'] as String?) ?? Rating.middle,
        notes: (j['notes'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 1,
      );
}

class TeaRaterApp extends StatelessWidget {
  const TeaRaterApp({super.key});
  @override
  Widget build(BuildContext context) {
    ColorScheme scheme(Brightness b) => ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: b,
        ).copyWith(secondary: const Color(0xFFF57C00));
    return MaterialApp(
      title: 'Tea Rater',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme(Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: scheme(Brightness.dark),
        useMaterial3: true,
      ),
      home: const TeaListPage(),
    );
  }
}

class TeaListPage extends StatefulWidget {
  const TeaListPage({super.key});
  @override
  State<TeaListPage> createState() => _TeaListPageState();
}

class _TeaListPageState extends State<TeaListPage> {
  static const _prefsKey = 'teas_v1';
  final List<Tea> _teas = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _loaded = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _cmp(Tea a, Tea b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  List<Tea> get _visibleTeas {
    final sorted = [..._teas]..sort(_cmp);
    if (_query.isEmpty) return sorted;
    final q = _query.toLowerCase();
    return sorted
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.notes.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _teas
          ..clear()
          ..addAll(list.map(Tea.fromJson));
      } catch (_) {}
    }
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_teas.map((t) => t.toJson()).toList()),
    );
  }

  static const _ratingCycle = [Rating.middle, Rating.up, Rating.down];

  void _cycleRating(Tea tea) {
    final i = _ratingCycle.indexOf(tea.rating);
    setState(() => tea.rating =
        _ratingCycle[(i < 0 ? 0 : i + 1) % _ratingCycle.length]);
    _save();
  }

  void _incrementCount(Tea tea) {
    setState(() => tea.count++);
    _save();
  }

  Future<void> _addOrEdit({Tea? existing}) async {
    final result = await showDialog<Tea>(
      context: context,
      builder: (_) => _TeaEditDialog(initial: existing),
    );
    if (result == null) return;
    setState(() {
      if (existing == null) {
        _teas.add(result);
      } else {
        existing.name = result.name;
        existing.rating = result.rating;
        existing.notes = result.notes;
      }
    });
    _save();
  }

  Future<void> _delete(Tea tea) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tea?'),
        content: Text('Remove "${tea.name}" from your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _teas.remove(tea));
      _save();
    }
  }

  Future<void> _export() async {
    final json = const JsonEncoder.withIndent('  ')
        .convert(_teas.map((t) => t.toJson()).toList());
    final bytes = utf8.encode(json);
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export teas as JSON',
      fileName: 'teas.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (path == null) return;
    try {
      final f = File(path);
      if (!await f.exists() || (await f.readAsBytes()).isEmpty) {
        await f.writeAsBytes(bytes, flush: true);
      }
      if (mounted) _snack('Exported ${_teas.length} teas to $path');
    } catch (e) {
      if (mounted) _snack('Export failed: $e');
    }
  }

  Future<void> _import() async {
    final res = await FilePicker.pickFiles(
      dialogTitle: 'Import teas JSON',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final file = res.files.single;
    try {
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        _snack('Could not read file');
        return;
      }
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        _snack('Invalid format: expected a JSON array');
        return;
      }
      final imported = decoded
          .whereType<Map<String, dynamic>>()
          .map(Tea.fromJson)
          .where((t) => t.name.isNotEmpty)
          .toList();
      if (imported.isEmpty) {
        _snack('No teas found in file');
        return;
      }
      final mode = await showDialog<_ImportMode>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import teas'),
          content: Text(
              'Found ${imported.length} teas in file. How should they be added?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _ImportMode.merge),
              child: const Text('Merge'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _ImportMode.replace),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (mode == null || !mounted) return;
      setState(() {
        if (mode == _ImportMode.replace) {
          _teas
            ..clear()
            ..addAll(imported);
        } else {
          final byName = {for (final t in _teas) t.name.toLowerCase(): t};
          for (final t in imported) {
            final existing = byName[t.name.toLowerCase()];
            if (existing == null) {
              _teas.add(t);
            } else {
              existing.rating = t.rating;
              if (t.notes.isNotEmpty) existing.notes = t.notes;
            }
          }
        }
      });
      _save();
      _snack('Imported ${imported.length} teas');
    } catch (e) {
      _snack('Import failed: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTeas;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tea Rater'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search teas',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'import') _import();
              if (v == 'export') _export();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('Import JSON'),
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_upload),
                  title: Text('Export JSON'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add tea'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _teas.isEmpty
              ? const _EmptyState()
              : visible.isEmpty
                  ? Center(
                      child: Text('No teas match "$_query"',
                          style: Theme.of(context).textTheme.bodyLarge),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final tea = visible[i];
                    return Card(
                      child: ListTile(
                        title: Text(tea.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: tea.notes.isEmpty ? null : Text(tea.notes),
                        onTap: () => _addOrEdit(existing: tea),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _incrementCount(tea),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '×${tea.count}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  'Rating: ${tea.rating.label} (tap to cycle)',
                              iconSize: 28,
                              icon: Icon(tea.rating.icon),
                              color: tea.rating.color,
                              onPressed: () => _cycleRating(tea),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(tea),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

enum _ImportMode { merge, replace }

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_food_beverage,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6)),
          const SizedBox(height: 16),
          const Text('No teas yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text('Tap "Add tea" to get started.'),
        ],
      ),
    );
  }
}

class _TeaEditDialog extends StatefulWidget {
  const _TeaEditDialog({this.initial});
  final Tea? initial;
  @override
  State<_TeaEditDialog> createState() => _TeaEditDialogState();
}

class _TeaEditDialogState extends State<_TeaEditDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.initial?.notes ?? '');
  late Rating _rating = widget.initial?.rating ?? Rating.middle;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add tea' : 'Edit tea'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final r in Rating.values)
                IconButton(
                  tooltip: r.label,
                  iconSize: 32,
                  icon: Icon(r.icon),
                  color: _rating == r
                      ? r.color
                      : Theme.of(context).disabledColor,
                  onPressed: () => setState(() => _rating = r),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              Tea(
                name: name,
                rating: _rating,
                notes: _notes.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
