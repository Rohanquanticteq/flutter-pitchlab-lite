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
    test('requires a short sustained tone before exposing pitch', () {
      final gate = StableToneGate();

      for (var i = 0; i < 3; i++) {
        expect(gate.process(reading(440.0)), isNull);
      }

      final accepted = gate.process(reading(440.0));
      expect(accepted, isNotNull);
      expect(accepted!.noteLabel, 'A');
    });

    test('rejects rapidly changing speech-like pitch frames', () {
      final gate = StableToneGate();
      final speechLikeFrequencies = <double>[
        196.00,
        246.94,
        174.61,
        261.63,
        207.65,
        293.66,
        185.00,
        233.08,
      ];

      for (final frequency in speechLikeFrequencies) {
        expect(gate.process(reading(frequency)), isNull);
      }

      expect(gate.lockedReading, isNull);
    });

    test('treats octave changes of the same pitch class as stable', () {
      final gate = StableToneGate();

      for (var i = 0; i < 4; i++) {
        gate.process(reading(440.0));
      }

      final octaveLower = gate.process(reading(220.0, confidence: 0.60));
      expect(octaveLower, isNotNull);
      expect(octaveLower!.noteLabel, 'A');
    });

    test('allows normal vibrato around a locked tone', () {
      final gate = StableToneGate();

      for (var i = 0; i < 4; i++) {
        gate.process(reading(440.0));
      }

      expect(gate.process(reading(452.0, confidence: 0.58)), isNotNull);
      expect(gate.process(reading(430.0, confidence: 0.52)), isNotNull);
    });

    test('bridges brief detector dropouts after tone acquisition', () {
      final gate = StableToneGate();

      for (var i = 0; i < 4; i++) {
        gate.process(reading(440.0));
      }

      final firstHold = gate.process(null);
      final secondHold = gate.process(null);
      final thirdHold = gate.process(null);
      final releasedGap = gate.process(null);

      expect(firstHold, isNotNull);
      expect(secondHold, isNotNull);
      expect(thirdHold, isNotNull);
      expect(firstHold!.noteLabel, 'A');
      expect(firstHold.confidence, lessThan(0.95));
      expect(releasedGap, isNull);
    });

    test('requires re-acquisition before switching to a new note', () {
      final gate = StableToneGate();

      for (var i = 0; i < 4; i++) {
        gate.process(reading(440.0));
      }

      for (var i = 0; i < 3; i++) {
        expect(gate.process(reading(523.251)), isNotNull);
      }

      final switched = gate.process(reading(523.251));
      expect(switched, isNotNull);
      expect(switched!.noteLabel, 'C');
    });

    test('very low-confidence voiced input does not acquire a tone', () {
      final gate = StableToneGate();

      for (var i = 0; i < 8; i++) {
        expect(
          gate.process(reading(440.0, confidence: 0.40)),
          isNull,
        );
      }

      expect(gate.lockedReading, isNull);
    });
  });
}
