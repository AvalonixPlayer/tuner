import 'dart:math';
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

class FrequencyDetector {
  static double? detectExactFrequency({
    required Uint8List rawPcmBytes,
    required int sampleRate,
    double minAmplitudeThreshold = 0.02,
  }) {
    final Int16List int16Samples = rawPcmBytes.buffer.asInt16List();
    if (int16Samples.isEmpty) return null;

    final fftSize = int16Samples.length;
    final samples = List<double>.filled(fftSize, 0.0);

    var sumSquares = 0.0;
    var magicNormalization = 32768.0;
    double normalized;
    for (int i = 0; i < fftSize; i++) {
      normalized = int16Samples[i] /  magicNormalization;
      samples[i] = normalized;
      sumSquares += normalized * normalized;
    }

    // расчет среднеквадратичную амплитуду чтобы узнать громкость
    final rms = sqrt(sumSquares / fftSize);
    if (rms < minAmplitudeThreshold) {
      return null; // импровизация шумодава
    }

    final windowCoeffs = Window.hanning(fftSize);
    final windowedSamples = List<double>.generate(
      fftSize, (i) => samples[i] * windowCoeffs[i],
    );

    final fft = FFT(fftSize);
    final fftResult = fft.realFft(samples);

    // убрать зеркалo
    final halfSpectrum = fftResult.discardConjugates();

    final numBins = halfSpectrum.length;
    final List<double> magnitudes = List<double>.filled(numBins, 0.0);

    for (var i = 0; i < numBins; i++) {
      final c = halfSpectrum[i];
      final real = c.x; final imag = c.y;
      magnitudes[i] = sqrt(real * real + imag * imag);
    }

    var maxIndex = -1;
    var maxMag = -1.0;

    for (var i = 1; i < numBins; i++) {
      if (magnitudes[i] > maxMag) {
        maxMag = magnitudes[i];
        maxIndex = i;
      }
    }

    if (maxIndex <= 0 || maxIndex >= numBins - 1) {
      return null;
    }

    // параболическая интерболяция для точности
    final alpha = magnitudes[maxIndex - 1];
    final beta  = magnitudes[maxIndex];
    final gamma = magnitudes[maxIndex + 1];

    final denominator = alpha - 2 * beta + gamma;
    if (denominator == 0) return maxIndex * (sampleRate / fftSize);

    final delta = 0.5 * (alpha - gamma) / denominator;
    final exactBin = maxIndex + delta;

    return exactBin * (sampleRate /fftSize);
  }
}