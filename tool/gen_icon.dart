// Procedurally renders the Tea Rater app icon (1024x1024 PNG).
//
// Run: dart run tool/gen_icon.dart
//
// Output: assets/icon/icon.png  +  assets/icon/icon_foreground.png
//   * icon.png            — full legacy / squircle icon (background filled)
//   * icon_foreground.png — Android adaptive icon foreground (transparent)
//
// After regenerating, re-run flutter_launcher_icons to push them to every
// platform target:  dart run flutter_launcher_icons

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int size = 1024;

final img.ColorRgba8 bgBlue = img.ColorRgba8(21, 101, 192, 255);
final img.ColorRgba8 bgBlueDeep = img.ColorRgba8(13, 71, 161, 255);
final img.ColorRgba8 transparent = img.ColorRgba8(0, 0, 0, 0);
final img.ColorRgba8 cup = img.ColorRgba8(255, 255, 255, 255);
final img.ColorRgba8 cupShadow = img.ColorRgba8(225, 235, 245, 255);
final img.ColorRgba8 tea = img.ColorRgba8(141, 71, 28, 255);
final img.ColorRgba8 teaHi = img.ColorRgba8(180, 105, 50, 255);
final img.ColorRgba8 steam = img.ColorRgba8(245, 124, 0, 255);

void main() {
  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(_render(true)));
  File('assets/icon/icon_foreground.png')
      .writeAsBytesSync(img.encodePng(_render(false)));
  stdout.writeln('Wrote assets/icon/icon.png + assets/icon/icon_foreground.png');
}

img.Image _render(bool withBackground) {
  final c = img.Image(width: size, height: size, numChannels: 4);
  img.fill(c, color: transparent);

  if (withBackground) {
    _radialFill(c, bgBlue, bgBlueDeep);
  }

  // Saucer
  _fillEllipse(c, 512, 830, 380, 56, cupShadow);
  _fillEllipse(c, 512, 820, 380, 56, cup);

  // Cup body — rounded rectangle, slightly tapered
  _fillRoundRect(c, 290, 380, 720, 760, 44, cup);
  // Subtle inner shadow on the right side of cup body
  _fillRoundRect(c, 660, 400, 716, 750, 30, cupShadow);

  // Handle — thick ring on the right
  img.fillCircle(c, x: 760, y: 570, radius: 110, color: cup);
  img.fillCircle(c, x: 760, y: 570, radius: 60,
      color: withBackground ? bgBlue : transparent);

  // Tea surface visible at the cup rim
  _fillEllipse(c, 505, 400, 200, 30, tea);
  img.fillRect(c, x1: 305, y1: 400, x2: 705, y2: 430, color: tea);
  _fillEllipse(c, 505, 430, 200, 30, tea);
  // Tea highlight band
  _fillEllipse(c, 470, 395, 110, 12, teaHi);

  // Steam ribbons — three sinuous trails of soft circles above the cup
  _steamRibbon(c, -120, phase: 0.0);
  _steamRibbon(c, 0, phase: 1.2);
  _steamRibbon(c, 120, phase: 2.4);

  return c;
}

void _radialFill(img.Image c, img.ColorRgba8 inner, img.ColorRgba8 outer) {
  const cx = size / 2, cy = size / 2;
  final maxR = math.sqrt(cx * cx + cy * cy);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = x - cx, dy = y - cy;
      final t = (math.sqrt(dx * dx + dy * dy) / maxR).clamp(0.0, 1.0);
      final r = _lerp(inner.r, outer.r, t);
      final g = _lerp(inner.g, outer.g, t);
      final b = _lerp(inner.b, outer.b, t);
      c.setPixelRgba(x, y, r, g, b, 255);
    }
  }
}

int _lerp(num a, num b, double t) => (a + (b - a) * t).round();

void _fillEllipse(
    img.Image c, int cx, int cy, num rx, num ry, img.ColorRgba8 color) {
  final yMin = math.max(0, (cy - ry).floor());
  final yMax = math.min(size - 1, (cy + ry).ceil());
  final xMin = math.max(0, (cx - rx).floor());
  final xMax = math.min(size - 1, (cx + rx).ceil());
  for (int y = yMin; y <= yMax; y++) {
    for (int x = xMin; x <= xMax; x++) {
      final dx = (x - cx) / rx;
      final dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1.0) {
        c.setPixel(x, y, color);
      }
    }
  }
}

void _fillRoundRect(
    img.Image c, int x1, int y1, int x2, int y2, int r, img.ColorRgba8 color) {
  img.fillRect(c, x1: x1, y1: y1 + r, x2: x2, y2: y2 - r, color: color);
  img.fillRect(c, x1: x1 + r, y1: y1, x2: x2 - r, y2: y2, color: color);
  img.fillCircle(c, x: x1 + r, y: y1 + r, radius: r, color: color);
  img.fillCircle(c, x: x2 - r, y: y1 + r, radius: r, color: color);
  img.fillCircle(c, x: x1 + r, y: y2 - r, radius: r, color: color);
  img.fillCircle(c, x: x2 - r, y: y2 - r, radius: r, color: color);
}

void _steamRibbon(img.Image c, int offsetX, {double phase = 0.0}) {
  // Curl from y=350 (just above cup rim) up to y=80.
  for (double t = 0; t <= 1.0; t += 0.008) {
    final y = (350 - 270 * t).round();
    final x = (512 + offsetX + 38 * math.sin(t * math.pi * 3 + phase)).round();
    final radius = (26 - 10 * t).round().clamp(8, 30);
    img.fillCircle(c, x: x, y: y, radius: radius, color: steam);
  }
}
