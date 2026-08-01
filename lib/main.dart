import 'package:dynamic_color/dynamic_color.dart' show ColorSchemeHarmonization, DynamicColorBuilder;
import 'package:flutter/material.dart';
import 'package:tuner/screens/tuner.dart';

void main() {
  runApp(const TunerApp());
}

class TunerApp extends StatelessWidget {
  const TunerApp({super.key});
  static const _defaultColor = Colors.green;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        if (lightDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
        } else {
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: _defaultColor,
            brightness: Brightness.light,
          );
        }

        ColorScheme darkColorScheme;
        if (darkDynamic != null) {
          darkColorScheme = darkDynamic.harmonized();
        } else {
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: _defaultColor,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: 'Dynamic Color Demo',
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          home: const Tuner(title: "AvalonixTuner"),
        );
      },
    );
  }
}

