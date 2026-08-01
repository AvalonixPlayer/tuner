import 'dart:math' as math;

import 'package:flutter/material.dart';

class GaugePainter extends CustomPainter {
  GaugePainter({
    required this.cents,
    required this.inTune,
    required this.colors,
  });

  final double cents;
  final bool inTune;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.78);
    final radius = size.width / 2 - 10;

    final arcPaint = Paint()
      ..color = colors.onSurface.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, math.pi, math.pi, false, arcPaint);

    final tickPaint = Paint()
      ..color = colors.onSurfaceVariant.withValues(alpha: 0.5)
      ..strokeWidth = 1.6;

    for (final t in [-50, -25, 0, 25, 50]) {
      final angle = math.pi + (math.pi * ((t + 50) / 100));
      final outer = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final inner = Offset(
        center.dx + (radius - 8) * math.cos(angle),
        center.dy + (radius - 8) * math.sin(angle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    final angle = math.pi + (math.pi * ((cents.clamp(-50, 50) + 50) / 100));
    final needleLength = radius - 14;
    final tip = Offset(
      center.dx + needleLength * math.cos(angle),
      center.dy + needleLength * math.sin(angle),
    );

    final needleColor = inTune ? colors.primary : colors.outline;

    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, needlePaint);

    final indicatorPaint = Paint()..color = needleColor;
    final indicatorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: tip, width: 16, height: 8),
      const Radius.circular(3),
    );

    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(angle + math.pi / 2);
    canvas.translate(-tip.dx, -tip.dy);
    canvas.drawRRect(indicatorRect, indicatorPaint);
    canvas.restore();

    final pivotPaint = Paint()..color = colors.surfaceContainerHighest;
    canvas.drawCircle(center, 15, pivotPaint);

    final pivotBorder = Paint()
      ..color = colors.outlineVariant.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, 15, pivotBorder);
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) {
    return oldDelegate.cents != cents ||
        oldDelegate.inTune != inTune ||
        oldDelegate.colors != colors;
  }
}
