import 'package:flutter/material.dart';

class StartButton extends StatelessWidget {
  const StartButton({required this.isListening, required this.onTap});
  final bool isListening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
        decoration: BoxDecoration(
          color: isListening
              ? colors.surfaceContainerHigh
              : colors.primaryContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isListening
                ? colors.outlineVariant.withValues(alpha: 0.2)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isListening ? Icons.stop_rounded : Icons.mic_rounded,
              size: 18,
              color: isListening
                  ? colors.onSurface
                  : colors.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              isListening ? 'Stop tuner' : 'Start tuner',
              style: TextStyle(
                color: isListening
                    ? colors.onSurface
                    : colors.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
