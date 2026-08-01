import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import 'frequency_detector.dart';
import 'note_helper.dart';
import 'note_smoother.dart';

class MicrophoneTuner {
  MicrophoneTuner({
    double tuningFork = 440.0,
    int sampleRate = 48000,
    double minAmplitudeThreshold = 0.01,
    int targetSampleCount = 8192,
  })  : _tuningFork = tuningFork,
        _sampleRate = sampleRate,
        _minAmplitudeThreshold = minAmplitudeThreshold,
        _targetBytes = targetSampleCount * 2;

  final AudioRecorder _recorder = AudioRecorder();

  double _tuningFork;
  final int _sampleRate;
  final double _minAmplitudeThreshold;
  final int _targetBytes;

  StreamSubscription<Uint8List>? _pcmSubscription;
  final StreamController<NoteInfo?> _noteController =
  StreamController<NoteInfo?>.broadcast();

  bool _isListening = false;
  bool get isListening => _isListening;

  Stream<NoteInfo?> get noteStream => _noteController.stream;

  final BytesBuilder _pcmBuffer = BytesBuilder();
  final NoteSmoother _smoother = NoteSmoother();

  void updateTuningFork(double tuningFork) {
    _tuningFork = tuningFork;
    _smoother.reset();
  }

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> start() async {
    if (_isListening) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      await requestMicrophonePermission();
      throw MicrophonePermissionDenied();
    }

    _pcmBuffer.clear();
    _smoother.reset();

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );

    _isListening = true;
    _pcmSubscription = stream.listen(
      _onPcmChunk,
      onError: (Object error, StackTrace stackTrace) {
        _noteController.add(null);
      },
    );
  }

  Future<void> stop() async {
    if (!_isListening) return;
    _isListening = false;
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    await _recorder.stop();
    _pcmBuffer.clear();
    _smoother.reset();
    _noteController.add(null);
  }

  void _onPcmChunk(Uint8List chunk) {
    _pcmBuffer.add(chunk);

    if (_pcmBuffer.length < _targetBytes) {
      return;
    }

    final buffer = _pcmBuffer.toBytes();
    final usableChunk = Uint8List.sublistView(buffer, 0, _targetBytes);

    final remaining = buffer.length - _targetBytes;
    if (remaining > 0) {
      _pcmBuffer.clear();
      _pcmBuffer.add(Uint8List.sublistView(buffer, _targetBytes));
    } else {
      _pcmBuffer.clear();
    }

    final frequency = FrequencyDetector.detectExactFrequency(
      rawPcmBytes: usableChunk,
      sampleRate: _sampleRate,
      minAmplitudeThreshold: _minAmplitudeThreshold,
    );

    if (frequency == null) {
      final smoothed = _smoother.smooth(null);
      _noteController.add(smoothed);
      return;
    }

    final note = NoteInfo.fromFrequency(frequency, tuningFork: _tuningFork);
    if (note == null) {
      final smoothed = _smoother.smooth(null);
      _noteController.add(smoothed);
      return;
    }

    final smoothed = _smoother.smooth(note);
    _noteController.add(smoothed);
  }

  Future<void> dispose() async {
    await stop();
    await _noteController.close();
    await _recorder.dispose();
  }
}

class MicrophonePermissionDenied implements Exception {
  @override
  String toString() => 'Microphone can\'t be accessed.';
}