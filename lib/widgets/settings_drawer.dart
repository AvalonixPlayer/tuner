import 'package:flutter/material.dart';

import '../models/guitar_tuning.dart';
import 'drawer_item.dart';

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({
    required this.a4Reference,
    required this.selectedTuning,
    required this.onA4Tap,
    required this.onTuningTap,
  });

  final int a4Reference;
  final GuitarTuning selectedTuning;
  final VoidCallback onA4Tap;
  final VoidCallback onTuningTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colors.surface,
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.settings_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'App Settings',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: colors.outlineVariant.withValues(alpha: 0.3), height: 1),
            const SizedBox(height: 8),
            DrawerItem(
              icon: Icons.graphic_eq_rounded,
              label: 'Guitar set',
              value: selectedTuning.name,
              onTap: onTuningTap,
            ),
            DrawerItem(
              icon: Icons.tune_rounded,
              label: 'Calibrate A4',
              value: '$a4Reference Hz',
              onTap: onA4Tap,
            ),
            DrawerItem(
              icon: Icons.language_rounded,
              label: 'Language',
              value: null,
              onTap: () {},
            ),
            DrawerItem(
              icon: Icons.speed_rounded,
              label: 'Sensitivity',
              value: null,
              onTap: () {},
            ),
            DrawerItem(
              icon: Icons.info_outline_rounded,
              label: 'About the app',
              value: null,
              onTap: () {},
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'AvalonixTuner · v1.0',
                style: TextStyle(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
