import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pitchlab_lite/features/pitch_detection/data/yin_pitch_detector.dart';

void main() {
  const sampleRate = 44100;
  const sampleCount = 2048;

  test('detects a 440 Hz sine wave', () {
    final samples = List<double>.generate(
      sampleCount,
      (index) => math.sin(2 * math.pi * 440 * index / sampleRate),
      growable: false,
    );

    final result = YinPitchDetector.detect(samples, sampleRate);

    expect(result.frequency, isNotNull);
    expect(result.frequency!, closeTo(440, 1.0));
    expect(result.confidence, greaterThan(0.9));
  });

  test('returns no pitch for silence', () {
    final samples = List<double>.filled(sampleCount, 0.0);

    final result = YinPitchDetector.detect(samples, sampleRate);

    expect(result.frequency, isNull);
  });

  test('detects a lower voice-range tone', () {
    final samples = List<double>.generate(
      sampleCount,
      (index) => 0.7 * math.sin(2 * math.pi * 110 * index / sampleRate),
      growable: false,
    );

    final result = YinPitchDetector.detect(samples, sampleRate);

    expect(result.frequency, isNotNull);
    expect(result.frequency!, closeTo(110, 1.0));
  });
}
