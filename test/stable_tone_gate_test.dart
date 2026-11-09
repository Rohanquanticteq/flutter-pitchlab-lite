import 'package:flutter_test/flutter_test.dart';
import 'package:pitchlab_lite/features/pitch_detection/data/stable_tone_gate.dart';
import 'package:pitchlab_lite/features/pitch_detection/domain/pitch_reading.dart';

PitchReading reading(double frequency, {double confidence = 0.95}) {
  return PitchReading.fromFrequency(
    frequency,
    confidence: confidence,
  );
}

void main() {
  group('StableToneGate', () {
    test('requires a sustained stable tone before exposing pitch', () {
      final gate = StableToneGate();

      for (var i = 0; i < 4; i++) {
        expect(gate.process(reading(440.0)), isNull);
      }

      final accepted = gate.process(reading(440.0));
      expect(accepted, isNotNull);
      expect(accepted!.noteLabel, 'A');
    });

    test('rejects rapidly changing speech-like pitch frames', () {
      final gate = StableToneGate();
      final speechLikeFrequencies = <double>[
        196.00, // G3
        246.94, // B3
        174.61, // F3
        261.63, // C4
        207.65, // G#3
        293.66, // D4
        185.00, // F#3
        233.08, // A#3
      ];

      for (final frequency in speechLikeFrequencies) {
        expect(gate.process(reading(frequency)), isNull);
      }

      expect(gate.lockedReading, isNull);
    });

    test('treats octave changes of the same pitch class as stable', () {
      final gate = StableToneGate();

      for (var i = 0; i < 5; i++) {
        gate.process(reading(440.0));
      }

      final octaveLower = gate.process(reading(220.0));
      expect(octaveLower, isNotNull);
      expect(octaveLower!.noteLabel, 'A');
    });

    test('requires re-acquisition before switching to a new note', () {
      final gate = StableToneGate();

      for (var i = 0; i < 5; i++) {
        gate.process(reading(440.0));
      }

      for (var i = 0; i < 4; i++) {
        expect(gate.process(reading(523.251)), isNull); // C5
      }

      final switched = gate.process(reading(523.251));
      expect(switched, isNotNull);
      expect(switched!.noteLabel, 'C');
    });

    test('low-confidence voiced input does not acquire a tone', () {
      final gate = StableToneGate();

      for (var i = 0; i < 8; i++) {
        expect(
          gate.process(reading(440.0, confidence: 0.65)),
          isNull,
        );
      }

      expect(gate.lockedReading, isNull);
    });
  });
}
