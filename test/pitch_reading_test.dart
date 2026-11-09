import 'package:flutter_test/flutter_test.dart';
import 'package:pitchlab_lite/features/pitch_detection/domain/pitch_reading.dart';

void main() {
  group('PitchReading.fromFrequency', () {
    test('maps 440 Hz to octave-independent A label', () {
      final reading = PitchReading.fromFrequency(440, confidence: 1);

      expect(reading.noteLabel, 'A');
      expect(reading.scientificNoteLabel, 'A4');
      expect(reading.cents, closeTo(0, 0.001));
    });

    test('maps middle C to octave-independent C label', () {
      final reading = PitchReading.fromFrequency(261.625565, confidence: 1);

      expect(reading.noteLabel, 'C');
      expect(reading.scientificNoteLabel, 'C4');
      expect(reading.cents, closeTo(0, 0.01));
    });

    test('same pitch class in different octaves has same primary label', () {
      final low = PitchReading.fromFrequency(77.7817459, confidence: 1); // D#2
      final high = PitchReading.fromFrequency(155.563492, confidence: 1); // D#3

      expect(low.noteLabel, 'D#');
      expect(high.noteLabel, 'D#');
      expect(low.scientificNoteLabel, 'D#2');
      expect(high.scientificNoteLabel, 'D#3');
      expect(low.pitchClassPosition, closeTo(high.pitchClassPosition, 0.001));
    });

    test('reports sharp pitch with positive cents', () {
      final reading = PitchReading.fromFrequency(445, confidence: 1);

      expect(reading.noteLabel, 'A');
      expect(reading.cents, greaterThan(0));
    });
  });
}
