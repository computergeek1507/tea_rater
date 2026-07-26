import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Full-screen live camera view that runs on-device text recognition on
/// each frame and lets the user tap a recognized line to use as the result.
class LiveOcrScannerPage extends StatefulWidget {
  const LiveOcrScannerPage({super.key});

  @override
  State<LiveOcrScannerPage> createState() => _LiveOcrScannerPageState();
}

class _LiveOcrScannerPageState extends State<LiveOcrScannerPage> {
  CameraController? _controller;
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  bool _busy = false;
  bool _starting = true;
  String? _error;
  List<String> _lines = [];

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _starting = false;
      });
      await controller.startImageStream(_onFrame);
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  void _onFrame(CameraImage image) {
    if (_busy) return;
    final controller = _controller;
    if (controller == null) return;
    _busy = true;
    _recognizeFrame(image, controller).whenComplete(() => _busy = false);
  }

  Future<void> _recognizeFrame(
      CameraImage image, CameraController controller) async {
    final input = _toInputImage(image, controller.description);
    if (input == null) return;
    try {
      final result = await _recognizer.processImage(input);
      final lines = result.blocks
          .expand((b) => b.lines)
          .map((l) => l.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (mounted) setState(() => _lines = lines);
    } catch (e) {
      debugPrint('OCR recognize error: $e');
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    if (!Platform.isAndroid) return null;
    final rotationCompensation = _orientations[DeviceOrientation.portraitUp]!;
    final sensorOrientation = camera.sensorOrientation;
    final rotationValue = camera.lensDirection == CameraLensDirection.front
        ? (sensorOrientation + rotationCompensation) % 360
        : (sensorOrientation - rotationCompensation + 360) % 360;
    final rotation = InputImageRotationValue.fromRawValue(rotationValue);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan tea name'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.white)),
              ),
            )
          : _starting || _controller == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(child: CameraPreview(_controller!)),
                    _LineList(
                      lines: _lines,
                      onPick: (line) => Navigator.pop(context, line),
                    ),
                  ],
                ),
    );
  }
}

class _LineList extends StatelessWidget {
  const _LineList({required this.lines, required this.onPick});
  final List<String> lines;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      constraints: const BoxConstraints(minHeight: 120, maxHeight: 220),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: lines.isEmpty
          ? const Center(
              child: Text('Point the camera at the tea name…',
                  style: TextStyle(color: Colors.white70)),
            )
          : ListView.builder(
              itemCount: lines.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(lines[i],
                    style: const TextStyle(color: Colors.white)),
                trailing:
                    const Icon(Icons.check_circle_outline, color: Colors.white70),
                onTap: () => onPick(lines[i]),
              ),
            ),
    );
  }
}
