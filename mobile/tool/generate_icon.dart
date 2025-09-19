// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

Future<void> main(List<String> args) async {
  const size = 1024;
  final image = img.Image(width: size, height: size);

  const topLeft = [94, 0, 255];
  const topRight = [255, 64, 205];
  const bottomLeft = [140, 0, 255];
  const bottomRight = [255, 146, 82];

  final centerX = size / 2;
  final centerY = size / 2;
  final highlightRadius = size * 0.9;
  final vignetteRadius = size * 0.78;

  for (var y = 0; y < size; y++) {
    final ty = y / (size - 1);
    for (var x = 0; x < size; x++) {
      final tx = x / (size - 1);

      final top = _lerpColor(topLeft, topRight, tx);
      final bottom = _lerpColor(bottomLeft, bottomRight, tx);
      var color = _lerpColor(top, bottom, ty);

      final dx = x - centerX;
      final dy = y - centerY;
      final dist = sqrt(dx * dx + dy * dy);

      final highlight = (1 - dist / highlightRadius).clamp(0.0, 1.0);
      if (highlight > 0) {
        color = _mix(color, const [255, 255, 255], highlight * 0.28);
      }

      final vignette = (dist / vignetteRadius).clamp(0.0, 1.0);
      if (vignette > 0) {
        final strength = pow(vignette, 1.8).toDouble();
        color = _mix(color, const [24, 12, 48], strength * 0.18);
      }

      image.setPixelRgba(x, y, color[0], color[1], color[2], 255);
    }
  }

  _applyRoundedCorners(image, radius: (size * 0.23).round());

  final vThickness = size * 0.12;
  final shadowOffset = (size * 0.018).round();
  final topY = (size * 0.24).round();
  final bottomY = (size * 0.62).round();
  final leftX = (size * 0.32).round();
  final rightX = (size * 0.68).round();
  final centerBottomX = (size * 0.5).round();

  final shadowColor = img.ColorRgba8(10, 0, 40, 90);
  img.drawLine(image,
      x1: leftX + shadowOffset,
      y1: topY + shadowOffset,
      x2: centerBottomX + shadowOffset,
      y2: bottomY + shadowOffset,
      color: shadowColor,
      thickness: vThickness,
      antialias: true);
  img.drawLine(image,
      x1: rightX + shadowOffset,
      y1: topY + shadowOffset,
      x2: centerBottomX + shadowOffset,
      y2: bottomY + shadowOffset,
      color: shadowColor,
      thickness: vThickness,
      antialias: true);

  final white = img.ColorRgba8(255, 255, 255, 255);
  img.drawLine(image,
      x1: leftX,
      y1: topY,
      x2: centerBottomX,
      y2: bottomY,
      color: white,
      thickness: vThickness,
      antialias: true);
  img.drawLine(image,
      x1: rightX,
      y1: topY,
      x2: centerBottomX,
      y2: bottomY,
      color: white,
      thickness: vThickness,
      antialias: true);

  final capRadius = (vThickness / 2).round();
  for (final point in [
    Point(leftX, topY),
    Point(rightX, topY),
    Point(centerBottomX, bottomY),
  ]) {
    img.fillCircle(image,
        x: point.x.toInt(), y: point.y.toInt(), radius: capRadius, color: white);
  }

  final textLayer = img.Image(width: 420, height: 140, numChannels: 4);
  img.fill(textLayer, color: img.ColorRgba8(0, 0, 0, 0));
  img.drawString(textLayer, 'Vibe', font: img.arial48, color: white);
  final scaledText = img.copyResize(textLayer,
      width: (size * 0.46).round(),
      interpolation: img.Interpolation.cubic);
  final textX = ((size - scaledText.width) / 2).round();
  final textY = (size * 0.71).round();
  img.compositeImage(image, scaledText,
      dstX: textX, dstY: textY, blend: img.BlendMode.alpha);

  final output = File('assets/icons/vibe_icon.png');
  await output.create(recursive: true);
  await output.writeAsBytes(img.encodePng(image));
  print('Icon generated at ${output.path}');
}

List<int> _lerpColor(List<int> a, List<int> b, double t) => [
      _lerpComponent(a[0], b[0], t),
      _lerpComponent(a[1], b[1], t),
      _lerpComponent(a[2], b[2], t),
    ];

List<int> _mix(List<int> a, List<int> b, double t) => _lerpColor(a, b, t);

int _lerpComponent(int a, int b, double t) =>
    (a + (b - a) * t).clamp(0, 255).round();

void _applyRoundedCorners(img.Image image, {required int radius}) {
  final w = image.width;
  final h = image.height;
  final radiusSquared = radius * radius;

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = x < radius
          ? radius - x - 0.5
          : (x >= w - radius ? x - (w - radius) + 0.5 : 0.0);
      final dy = y < radius
          ? radius - y - 0.5
          : (y >= h - radius ? y - (h - radius) + 0.5 : 0.0);

      if (dx <= 0 || dy <= 0) {
        continue;
      }

      if ((dx * dx + dy * dy) > radiusSquared) {
        image.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
}
