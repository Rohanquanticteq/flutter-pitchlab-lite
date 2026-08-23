import 'package:flutter_test/flutter_test.dart';
import 'package:pitchlab_lite/features/pitch_detection/domain/pitch_reading.dart';

void main() {
  group('PitchReading.fromFrequency', () {
    test('maps 440 Hz to A4 at zero cents', () {
      final reading = PitchReading.fromFrequency(440, confidence: 1);

      expect(reading.noteLabel, 'A4');
      expect(reading.cents, closeTo(0, 0.001));
    });

    test('maps middle C to C4', () {
      final reading = PitchReading.fromFrequency(261.625565, confidence: 1);

      expect(reading.noteLabel, 'C4');
      expect(reading.cents, closeTo(0, 0.01));
    });

    test('reports sharp pitch with positive cents', () {
      final reading = PitchReading.fromFrequency(445, confidence: 1);

      expect(reading.noteLabel, 'A4');
      expect(reading.cents, greaterThan(0));
    });
  });
}
