import 'package:flutter/material.dart';

import 'gauge_painter.dart';
class TunerGauge extends StatelessWidget {
  const TunerGauge({
    required this.cents,
    required this.inTune,
    required this.leftLabel,
    required this.rightLabel,
  });

  final double cents;
  final bool inTune;
  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 300,
      height: 220,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: const Size(300, 190),
            painter: GaugePainter(
              cents: cents,
              inTune: inTune,
              colors: colors,
            ),
          ),
          Positioned(
            top: 88,
            left: 4,
            child: Text(
              leftLabel,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            top: 88,
            right: 4,
            child: Text(
              rightLabel,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
