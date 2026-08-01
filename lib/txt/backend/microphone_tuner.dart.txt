import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import 'frequency_detector.dart';
import 'note_helper.dart';

class MicrophoneTuner {
  MicrophoneTuner({
    double tuningFork = 440.0,
    int sampleRate = 44100,
    double minAmplitudeThreshold = 0.02,
  })  : _tuningFork = tuningFork,
        _sampleRate = sampleRate,
        _minAmplitudeThreshold = minAmplitudeThreshold;

  final AudioRecorder _recorder = AudioRecorder();

  double _tuningFork;
  final int _sampleRate;
  final double _minAmplitudeThreshold;

  StreamSubscription<Uint8List>? _pcmSubscription;
  final StreamController<NoteInfo?> _noteController =
  StreamController<NoteInfo?>.broadcast();

  bool _isListening = false;
  bool get isListening => _isListening;

  Stream<NoteInfo?> get noteStream => _noteController.stream;

  void updateTuningFork(double tuningFork) {
    _tuningFork = tuningFork;
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
    _noteController.add(null);
  }

  void _onPcmChunk(Uint8List chunk) {
    final usableLength = _largestPowerOfTwoNotExceeding(chunk.length ~/ 2) * 2;
    if (usableLength <= 0) {
      _noteController.add(null);
      return;
    }
    final trimmedChunk = usableLength == chunk.length
        ? chunk
        : Uint8List.sublistView(chunk, 0, usableLength);

    final frequency = FrequencyDetector.detectExactFrequency(
      rawPcmBytes: trimmedChunk,
      sampleRate: _sampleRate,
      minAmplitudeThreshold: _minAmplitudeThreshold,
    );

    if (frequency == null) {
      _noteController.add(null);
      return;
    }

    final note = NoteInfo.fromFrequency(frequency, tuningFork: _tuningFork);
    _noteController.add(note);
  }

  int _largestPowerOfTwoNotExceeding(int n) {
    if (n <= 0) return 0;
    var power = 1;
    while (power * 2 <= n) {
      power *= 2;
    }
    return power;
  }

  Future<void> dispose() async {
    await stop();
    await _noteController.close();
    await _recorder.dispose();
  }
}

class MicrophonePermissionDenied implements Exception {
  @override
  String toString() =>
      'Microphone can`t be accessed.';
}
