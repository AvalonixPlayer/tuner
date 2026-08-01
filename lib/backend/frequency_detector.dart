import 'dart:math';
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

class FrequencyDetector {
  static const double _minGuitarFreq = 50.0;
  static const double _maxGuitarFreq = 1400.0;

  static const double _minSNRdB = 1.0;

  static const double _minPeakProminence = 1.6;

  static const int _hpsHarmonics = 5;

  static double? detectExactFrequency({
    required Uint8List rawPcmBytes,
    required int sampleRate,
    double minAmplitudeThreshold = 0.005,
  }) {
    final Int16List int16Samples = rawPcmBytes.buffer.asInt16List();
    if (int16Samples.isEmpty) return null;

    final fftSize = int16Samples.length;
    final samples = List<double>.filled(fftSize, 0.0);

    var sumSquares = 0.0;
    const magicNormalization = 32768.0;
    for (int i = 0; i < fftSize; i++) {
      final normalized = int16Samples[i] / magicNormalization;
      samples[i] = normalized;
      sumSquares += normalized * normalized;
    }

    final rms = sqrt(sumSquares / fftSize);
    if (rms < minAmplitudeThreshold) {
      return null;
    }

    final windowCoeffs = Window.hanning(fftSize);
    final windowedSamples = List<double>.generate(
      fftSize,
          (i) => samples[i] * windowCoeffs[i],
    );

    final fft = FFT(fftSize);
    final fftResult = fft.realFft(windowedSamples);

    final halfSpectrum = fftResult.discardConjugates();
    final numBins = halfSpectrum.length;

    final List<double> magnitudes = List<double>.filled(numBins, 0.0);
    for (var i = 0; i < numBins; i++) {
      final c = halfSpectrum[i];
      magnitudes[i] = sqrt(c.x * c.x + c.y * c.y);
    }

    final binResolution = sampleRate / fftSize;
    final lowBin = max(1, (_minGuitarFreq / binResolution).ceil());
    final highBin = min(numBins - 1, (_maxGuitarFreq / binResolution).floor());

    if (lowBin >= highBin) return null;

    final hpsRange = highBin;
    final List<double> hps = List<double>.from(
      magnitudes.sublist(0, min(hpsRange + 1, numBins)),
    );

    for (var harmonic = 2; harmonic <= _hpsHarmonics; harmonic++) {
      for (var i = 0; i < hps.length; i++) {
        final srcIndex = i * harmonic;
        if (srcIndex < numBins) {
          hps[i] *= magnitudes[srcIndex];
        } else {
          hps[i] = 0.0;
        }
      }
    }

    var maxIndex = -1;
    var maxHpsVal = -1.0;
    for (var i = lowBin; i <= highBin && i < hps.length; i++) {
      if (hps[i] > maxHpsVal) {
        maxHpsVal = hps[i];
        maxIndex = i;
      }
    }

    if (maxIndex <= lowBin || maxIndex >= highBin || maxIndex <= 0) {
      return null;
    }

    final peakMag = magnitudes[maxIndex];

    final neighborRange = 3;
    var neighborSum = 0.0;
    var neighborCount = 0;
    for (var i = maxIndex - neighborRange; i <= maxIndex + neighborRange; i++) {
      if (i != maxIndex && i >= 0 && i < numBins) {
        neighborSum += magnitudes[i];
        neighborCount++;
      }
    }
    if (neighborCount > 0) {
      final neighborAvg = neighborSum / neighborCount;
      if (neighborAvg > 0 && peakMag / neighborAvg < _minPeakProminence) {
        return null;
      }
    }

    final signalPower = peakMag * peakMag;
    var noisePower = 0.0;
    var noiseCount = 0;
    for (var i = lowBin; i <= highBin; i++) {
      if ((i - maxIndex).abs() > 4) {
        noisePower += magnitudes[i] * magnitudes[i];
        noiseCount++;
      }
    }
    if (noiseCount > 0) {
      noisePower /= noiseCount;
      if (noisePower > 0) {
        final snr = 10 * log(signalPower / noisePower);
        if (snr < _minSNRdB) {
          return null;
        }
      }
    }

    final fundamentalIndex = maxIndex;

    final alpha = magnitudes[fundamentalIndex - 1];
    final beta = magnitudes[fundamentalIndex];
    final gamma = magnitudes[fundamentalIndex + 1];

    final denominator = alpha - 2 * beta + gamma;
    double frequency;
    if (denominator == 0) {
      frequency = fundamentalIndex * binResolution;
    } else {
      final delta = 0.5 * (alpha - gamma) / denominator;
      final exactBin = fundamentalIndex + delta;
      frequency = exactBin * binResolution;
    }

    if (frequency < _minGuitarFreq || frequency > _maxGuitarFreq) {
      return null;
    }

    return frequency;
  }
}
