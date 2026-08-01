import 'dart:async';

import 'package:flutter/material.dart';

import '../backend/note_helper.dart';
import '../backend/microphone_tuner.dart';
import '../models/guitar_tuning.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/start_button.dart';
import '../widgets/top_bar.dart';
import '../widgets/tuner_gauge.dart';
import '../widgets/tuning_chip.dart';

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

  late final MicrophoneTuner _micTuner;
  StreamSubscription<NoteInfo?>? _noteSubscription;
  NoteInfo? _detectedNoteInfo;

  double get _cents => _detectedNoteInfo?.centsOffset ?? 0;
  String get _detectedNote => _detectedNoteInfo?.fullNoteWithOctave ?? '--';
  double get _detectedFrequency => _detectedNoteInfo?.actualFrequency ?? 0;

  String get _leftLabel {
    if (_detectedNoteInfo == null) return '--';
    return _detectedNoteInfo!.previousSemitone.fullNoteWithOctave;
  }

  String get _rightLabel {
    if (_detectedNoteInfo == null) return '--';
    return _detectedNoteInfo!.nextSemitone.fullNoteWithOctave;
  }

  late final AnimationController _needleController;
  late Animation<double> _needleAnim;

  @override
  void initState() {
    super.initState();
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
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
          'Permission error. '
          'Set Microphone permission.',
        ),
      ),
    );
  }

  void _animateNeedleTo(double cents) {
    final clamped = cents.clamp(-50.0, 50.0);

    if ((_needleAnim.value - clamped).abs() < 1.5) return;

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
                        RoundIconButton(
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
                        RoundIconButton(
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
      drawer: SettingsDrawer(
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
              TopBar(
                title: widget.title,
                onMenuTap: () => Scaffold.of(context).openDrawer(),
              ),
              const SizedBox(height: 8),
              TuningChip(
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
                  return TunerGauge(
                    cents: _needleAnim.value,
                    inTune: _inTune,
                    leftLabel: _leftLabel,
                    rightLabel: _rightLabel,
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
              StartButton(
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