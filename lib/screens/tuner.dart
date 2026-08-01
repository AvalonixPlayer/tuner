import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../backend/note_helper.dart';
import '../backend/microphone_tuner.dart';

class GuitarTuning {
  final String name;
  final List<NoteInfo> strings; 

  const GuitarTuning(this.name, this.strings);

  List<String> get notes => strings.map((n) => n.fullNoteWithOctave).toList();

  GuitarTuning withTuningFork(double tuningFork) {
    return GuitarTuning(
      name,
      strings
          .map((n) => NoteInfo.noteFromString(
        n.fullNoteWithOctave,
        tuningFork: tuningFork,
      ))
          .toList(),
    );
  }

  static GuitarTuning _build(String name, List<String> noteStrings) {
    return GuitarTuning(name, NoteInfo.parseNotes(noteStrings));
  }

  static final standard =
  _build('Standard (E)', ['E2', 'A2', 'D3', 'G3', 'B3', 'E4']);
  static final dropD = _build('Drop D', ['D2', 'A2', 'D3', 'G3', 'B3', 'E4']);
  static final dStandard =
  _build('D Standard', ['D2', 'G2', 'C3', 'F3', 'A3', 'D4']);
  static final dropC = _build('Drop C', ['C2', 'G2', 'C3', 'F3', 'A3', 'D4']);
  static final openG = _build('Open G', ['D2', 'G2', 'D3', 'G3', 'B3', 'D4']);
  static final openD =
  _build('Open D', ['D2', 'A2', 'D3', 'F#3', 'A3', 'D4']);
  static final halfStepDown = _build(
    'Half Step Down',
    ['Eb2', 'Ab2', 'Db3', 'Gb3', 'Bb3', 'Eb4'],
  );
}

final List<GuitarTuning> kGuitarTunings = [
  GuitarTuning.standard,
  GuitarTuning.dropD,
  GuitarTuning.dStandard,
  GuitarTuning.dropC,
  GuitarTuning.openG,
  GuitarTuning.openD,
  GuitarTuning.halfStepDown,
];

class Tuner extends StatefulWidget {
  const Tuner({super.key, required this.title});
  final String title;

  @override
  State<Tuner> createState() => _TunerState();
}

class _TunerState extends State<Tuner> with SingleTickerProviderStateMixin {
  int _a4Reference = 440;
  GuitarTuning _selectedTuning = kGuitarTunings.first;

  bool _isListening = false;
  bool _permissionDenied = false;

  late final MicrophoneTuner _micTuner;
  StreamSubscription<NoteInfo?>? _noteSubscription;
  NoteInfo? _detectedNoteInfo;

  double get _cents => _detectedNoteInfo?.centsOffset ?? 0;
  String get _detectedNote => _detectedNoteInfo?.fullNoteWithOctave ?? '--';
  double get _detectedFrequency => _detectedNoteInfo?.actualFrequency ?? 0;

  late final AnimationController _needleController;
  late Animation<double> _needleAnim;

  @override
  void initState() {
    super.initState();
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _needleAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.easeOutCubic),
    );
    _micTuner = MicrophoneTuner(tuningFork: _a4Reference.toDouble());
  }

  @override
  void dispose() {
    _noteSubscription?.cancel();
    _micTuner.dispose();
    _needleController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
      return;
    }

    setState(() => _permissionDenied = false);

    try {
      _noteSubscription?.cancel();
      _noteSubscription = _micTuner.noteStream.listen((note) {
        if (!mounted) return;
        setState(() => _detectedNoteInfo = note);
        if (note != null) {
          _animateNeedleTo(note.centsOffset);
        }
      });

      await _micTuner.start();
      if (!mounted) return;
      setState(() => _isListening = true);
    } on MicrophonePermissionDenied {
      await _noteSubscription?.cancel();
      _noteSubscription = null;
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _permissionDenied = true;
      });
      _showPermissionDeniedSnackBar();
    } catch (_) {
      await _noteSubscription?.cancel();
      _noteSubscription = null;
      if (!mounted) return;
      setState(() => _isListening = false);
    }
  }

  Future<void> _stopListening() async {
    await _micTuner.stop();
    await _noteSubscription?.cancel();
    _noteSubscription = null;
    _animateNeedleTo(0);
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _detectedNoteInfo = null;
    });
  }

  void _showPermissionDeniedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Нужен доступ к микрофону, чтобы слышать звук струны. '
              'Разрешите доступ в настройках устройства.',
        ),
      ),
    );
  }

  void _animateNeedleTo(double cents) {
    final clamped = cents.clamp(-50.0, 50.0);
    _needleAnim = Tween<double>(
      begin: _needleAnim.value,
      end: clamped,
    ).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.easeOutCubic),
    );
    _needleController.forward(from: 0);
  }

  bool get _inTune =>
      _isListening && _detectedNoteInfo != null && _cents.abs() <= 5;

  void _openA4Picker() {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        int tempValue = _a4Reference;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Калибровка A4',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Эталонная частота ноты A4 в герцах',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundIconButton(
                          icon: Icons.remove,
                          onTap: () {
                            if (tempValue > 400) {
                              setSheetState(() => tempValue--);
                            }
                          },
                        ),
                        Container(
                          width: 140,
                          alignment: Alignment.center,
                          child: Text(
                            '$tempValue Hz',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        _RoundIconButton(
                          icon: Icons.add,
                          onTap: () {
                            if (tempValue < 480) {
                              setSheetState(() => tempValue++);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _a4Reference = tempValue;
                            _selectedTuning = _selectedTuning.withTuningFork(
                              tempValue.toDouble(),
                            );
                          });
                          _micTuner.updateTuningFork(tempValue.toDouble());
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Применить',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openTuningPicker() {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Guitar Tuning',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: kGuitarTunings.map((t) {
                        final selected = t.name == _selectedTuning.name;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() => _selectedTuning = t);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? colors.primaryContainer.withValues(alpha: 0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? colors.primary
                                    : colors.outlineVariant.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.name,
                                        style: TextStyle(
                                          color: selected
                                              ? colors.primary
                                              : colors.onSurface,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        t.notes.join(' · '),
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check_circle,
                                    color: colors.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      drawer: _SettingsDrawer(
        a4Reference: _a4Reference,
        selectedTuning: _selectedTuning,
        onA4Tap: () {
          Navigator.pop(context);
          _openA4Picker();
        },
        onTuningTap: () {
          Navigator.pop(context);
          _openTuningPicker();
        },
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) => Column(
            children: [
              _TopBar(
                title: widget.title,
                onMenuTap: () => Scaffold.of(context).openDrawer(),
              ),
              const SizedBox(height: 8),
              _TuningChip(
                label: _selectedTuning.name,
                onTap: _openTuningPicker,
              ),
              const Spacer(),
              Text(
                _detectedNote,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _openA4Picker,
                child: Text(
                  '($_a4Reference Hz)',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _needleAnim,
                builder: (context, _) {
                  return _TunerGauge(
                    cents: _needleAnim.value,
                    inTune: _inTune,
                    leftLabel: 'G#4',
                    rightLabel: 'A#4',
                  );
                },
              ),
              const Spacer(),
              Text(
                'Current frequency: ${_detectedFrequency == 0 ? '--' : _detectedFrequency.toStringAsFixed(0)} Hz',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 20,
                child: !_isListening
                    ? const SizedBox.shrink()
                    : _detectedNoteInfo == null
                    ? Text(
                  'Listening...',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                )
                    : Text(
                  _inTune
                      ? 'In tune'
                      : (_cents < 0 ? 'Too low' : 'Too high'),
                  style: TextStyle(
                    color: _inTune ? colors.primary : colors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _StartButton(
                isListening: _isListening,
                onTap: () => _toggleListening(),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onMenuTap});
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

class _TuningChip extends StatelessWidget {
  const _TuningChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 15,
              color: colors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _TunerGauge extends StatelessWidget {
  const _TunerGauge({
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
            painter: _GaugePainter(
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

class _GaugePainter extends CustomPainter {
  _GaugePainter({
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
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.cents != cents ||
        oldDelegate.inTune != inTune ||
        oldDelegate.colors != colors;
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.isListening, required this.onTap});
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: colors.onSurface, size: 22),
      ),
    );
  }
}

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({
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
            _DrawerItem(
              icon: Icons.graphic_eq_rounded,
              label: 'Guitar set',
              value: selectedTuning.name,
              onTap: onTuningTap,
            ),
            _DrawerItem(
              icon: Icons.tune_rounded,
              label: 'Calibrate A4',
              value: '$a4Reference Hz',
              onTap: onA4Tap,
            ),
            _DrawerItem(
              icon: Icons.language_rounded,
              label: 'Language',
              value: null,
              onTap: () {},
            ),
            _DrawerItem(
              icon: Icons.speed_rounded,
              label: 'Sensitivity',
              value: null,
              onTap: () {},
            ),
            _DrawerItem(
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

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: colors.onSurfaceVariant, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
