import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  const TopBar({required this.title, required this.onMenuTap});
  final String title;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenuTap,
            icon: const Icon(Icons.menu_rounded),
            color: colors.onSurface,
            iconSize: 26,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }
}
