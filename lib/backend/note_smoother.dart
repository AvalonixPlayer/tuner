import 'dart:math';
import 'note_helper.dart';

/// Временной сглаживатель для стабилизации показаний тюнера.
/// Использует медианный фильтр, проверку стабильности (CV) и
/// гистерезис при смене ноты.
class NoteSmoother {
  NoteSmoother({
    this.bufferSize = 7,
    this.maxCv = 0.04,        // максимальный коэффициент вариации (4%)
    this.confirmationCount = 3, // сколько раз подряд нужна новая нота
    this.nullTolerance = 2,     // сколько null подряд допустимо
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

  /// Сбросить состояние
  void reset() {
    _freqBuffer.clear();
    _lastStableNote = null;
    _pendingNote = null;
    _pendingCount = 0;
    _nullCount = 0;
  }

  /// Принять новое измерение и вернуть стабилизированную ноту (или null)
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

    // Нужно минимум 4 валидных измерения для стабильности
    if (_freqBuffer.length < 4) {
      return _lastStableNote;
    }

    // Медианный фильтр: берём медиану частот
    final sorted = List<double>.from(_freqBuffer)..sort();
    final medianFreq = sorted[sorted.length ~/ 2];

    // Проверка стабильности: коэффициент вариации
    final mean = _freqBuffer.reduce((a, b) => a + b) / _freqBuffer.length;
    final variance = _freqBuffer
        .map((f) => (f - mean) * (f - mean))
        .reduce((a, b) => a + b) /
        _freqBuffer.length;
    final cv = sqrt(variance) / mean;

    if (cv > maxCv) {
      // Слишком нестабильно — возвращаем последнюю стабильную
      return _lastStableNote;
    }

    // Пересчитываем NoteInfo от медианной частоты
    final stableNote = NoteInfo.fromFrequency(medianFreq, tuningFork: detected.tuningFork);
    if (stableNote == null) {
      return _lastStableNote;
    }

    // === ГИСТЕРЕЗИС НОТЫ ===
    if (_lastStableNote == null) {
      _lastStableNote = stableNote;
      return stableNote;
    }

    // Если нота та же (с точностью до октавы) — сразу обновляем
    if (stableNote.note == _lastStableNote!.note &&
        stableNote.octave == _lastStableNote!.octave) {
      _lastStableNote = stableNote;
      _pendingNote = null;
      _pendingCount = 0;
      return stableNote;
    }

    // Новая нота — требуем подтверждения
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

