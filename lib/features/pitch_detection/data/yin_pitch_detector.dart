import 'dart:math' as math;

class PitchDetection {
  const PitchDetection({
    required this.frequency,
    required this.confidence,
    required this.rms,
  });

  final double? frequency;
  final double confidence;
  final double rms;

  bool get hasPitch => frequency != null;
}

class YinPitchDetector {
  const YinPitchDetector._();

  static const double defaultThreshold = 0.15;
  static const double defaultSilenceRms = 0.008;
  static const double defaultMinFrequency = 65.0;
  static const double defaultMaxFrequency = 1200.0;

  static PitchDetection detect(
    List<double> input,
    int sampleRate, {
    double threshold = defaultThreshold,
    double silenceRms = defaultSilenceRms,
    double minFrequency = defaultMinFrequency,
    double maxFrequency = defaultMaxFrequency,
  }) {
    if (input.length < 256 || sampleRate <= 0) {
      return const PitchDetection(frequency: null, confidence: 0, rms: 0);
    }

    var mean = 0.0;
    for (final sample in input) {
      mean += sample;
    }
    mean /= input.length;

    final samples = List<double>.filled(input.length, 0.0, growable: false);
    var squareSum = 0.0;
    for (var i = 0; i < input.length; i++) {
      final centered = input[i] - mean;
      samples[i] = centered;
      squareSum += centered * centered;
    }

    final rms = math.sqrt(squareSum / samples.length);
    if (rms < silenceRms) {
      return PitchDetection(frequency: null, confidence: 0, rms: rms);
    }

    final minTau = math.max(2, (sampleRate / maxFrequency).floor());
    final maxTau = math.min(
      (sampleRate / minFrequency).ceil(),
      (samples.length / 2).floor(),
    );

    if (maxTau <= minTau + 2) {
      return PitchDetection(frequency: null, confidence: 0, rms: rms);
    }

    final difference = List<double>.filled(maxTau + 1, 0.0, growable: false);
    final analysisLength = samples.length - maxTau;

    for (var tau = 1; tau <= maxTau; tau++) {
      var sum = 0.0;
      for (var i = 0; i < analysisLength; i++) {
        final delta = samples[i] - samples[i + tau];
        sum += delta * delta;
      }
      difference[tau] = sum;
    }

    final cmnd = List<double>.filled(maxTau + 1, 1.0, growable: false);
    var runningSum = 0.0;
    for (var tau = 1; tau <= maxTau; tau++) {
      runningSum += difference[tau];
      cmnd[tau] = runningSum == 0.0
          ? 1.0
          : (difference[tau] * tau) / runningSum;
    }

    int? candidateTau;
    for (var tau = minTau; tau < maxTau; tau++) {
      if (cmnd[tau] < threshold) {
        while (tau + 1 <= maxTau && cmnd[tau + 1] < cmnd[tau]) {
          tau++;
        }
        candidateTau = tau;
        break;
      }
    }

    if (candidateTau == null) {
      var bestTau = minTau;
      var bestValue = cmnd[minTau];
      for (var tau = minTau + 1; tau <= maxTau; tau++) {
        if (cmnd[tau] < bestValue) {
          bestValue = cmnd[tau];
          bestTau = tau;
        }
      }

      if (bestValue > 0.30) {
        return PitchDetection(
          frequency: null,
          confidence: (1.0 - bestValue).clamp(0.0, 1.0).toDouble(),
          rms: rms,
        );
      }
      candidateTau = bestTau;
    }

    final refinedTau = _parabolicInterpolation(cmnd, candidateTau);
    if (!refinedTau.isFinite || refinedTau <= 0) {
      return PitchDetection(frequency: null, confidence: 0, rms: rms);
    }

    final frequency = sampleRate / refinedTau;
    final confidence = (1.0 - cmnd[candidateTau]).clamp(0.0, 1.0).toDouble();

    if (!frequency.isFinite ||
        frequency < minFrequency ||
        frequency > maxFrequency ||
        confidence < 0.70) {
      return PitchDetection(
        frequency: null,
        confidence: confidence,
        rms: rms,
      );
    }

    return PitchDetection(
      frequency: frequency,
      confidence: confidence,
      rms: rms,
    );
  }

  static double _parabolicInterpolation(List<double> values, int index) {
    if (index <= 0 || index >= values.length - 1) {
      return index.toDouble();
    }

    final left = values[index - 1];
    final center = values[index];
    final right = values[index + 1];
    final denominator = 2.0 * (2.0 * center - right - left);

    if (denominator.abs() < 1e-12) {
      return index.toDouble();
    }

    return index + (right - left) / denominator;
  }
}
