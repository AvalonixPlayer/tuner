import 'dart:math';
import 'note_helper.dart';

class NoteSmoother {
  NoteSmoother({
    this.bufferSize = 7,
    this.maxCv = 0.04,        
    this.confirmationCount = 2, 
    this.nullTolerance = 2,    
  });

  final int bufferSize;
  final double maxCv;
  final int confirmationCount;
  final int nullTolerance;

  final List<double> _freqBuffer = [];
  NoteInfo? _lastStableNote;
  Note? _pendingNote;
  int _pendingCount = 0;
  int _nullCount = 0;

  void reset() {
    _freqBuffer.clear();
    _lastStableNote = null;
    _pendingNote = null;
    _pendingCount = 0;
    _nullCount = 0;
  }

  NoteInfo? smooth(NoteInfo? detected) {
    if (detected == null || detected.actualFrequency <= 0) {
      _nullCount++;
      if (_nullCount > nullTolerance) {
        _freqBuffer.clear();
        _pendingNote = null;
        _pendingCount = 0;
        _lastStableNote = null;
      }
      return _lastStableNote;
    }

    _nullCount = 0;
    _freqBuffer.add(detected.actualFrequency);
    if (_freqBuffer.length > bufferSize) {
      _freqBuffer.removeAt(0);
    }

    if (_freqBuffer.length < 4) {
      return _lastStableNote;
    }

    final sorted = List<double>.from(_freqBuffer)..sort();
    final medianFreq = sorted[sorted.length ~/ 2];

    final mean = _freqBuffer.reduce((a, b) => a + b) / _freqBuffer.length;
    final variance = _freqBuffer
        .map((f) => (f - mean) * (f - mean))
        .reduce((a, b) => a + b) /
        _freqBuffer.length;
    final cv = sqrt(variance) / mean;

    if (cv > maxCv) {
      return _lastStableNote;
    }

    final stableNote = NoteInfo.fromFrequency(medianFreq, tuningFork: detected.tuningFork);
    if (stableNote == null) {
      return _lastStableNote;
    }

    if (_lastStableNote == null) {
      _lastStableNote = stableNote;
      return stableNote;
    }

    if (stableNote.note == _lastStableNote!.note &&
        stableNote.octave == _lastStableNote!.octave) {
      _lastStableNote = stableNote;
      _pendingNote = null;
      _pendingCount = 0;
      return stableNote;
    }

    if (_pendingNote == stableNote.note) {
      _pendingCount++;
      if (_pendingCount >= confirmationCount) {
        _lastStableNote = stableNote;
        _pendingNote = null;
        _pendingCount = 0;
        return stableNote;
      }
    } else {
      _pendingNote = stableNote.note;
      _pendingCount = 1;
    }

    return _lastStableNote;
  }
}

