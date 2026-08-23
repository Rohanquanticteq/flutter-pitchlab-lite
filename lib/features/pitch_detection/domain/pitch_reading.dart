import 'dart:math' as math;

class PitchReading {
  const PitchReading({
    required this.frequency,
    required this.noteName,
    required this.octave,
    required this.cents,
    required this.confidence,
  });

  final double frequency;
  final String noteName;
  final int octave;
  final double cents;
  final double confidence;

  String get noteLabel => '$noteName$octave';

  factory PitchReading.fromFrequency(
    double frequency, {
    required double confidence,
    double referenceA4 = 440.0,
  }) {
    if (!frequency.isFinite || frequency <= 0) {
      throw ArgumentError.value(frequency, 'frequency', 'Must be positive');
    }
    if (!referenceA4.isFinite || referenceA4 <= 0) {
      throw ArgumentError.value(referenceA4, 'referenceA4', 'Must be positive');
    }

    final fractionalMidi =
        69.0 + 12.0 * (math.log(frequency / referenceA4) / math.ln2);
    final nearestMidi = fractionalMidi.round();
    final cents = (fractionalMidi - nearestMidi) * 100.0;
    final noteIndex = ((nearestMidi % 12) + 12) % 12;
    final octave = (nearestMidi ~/ 12) - 1;

    return PitchReading(
      frequency: frequency,
      noteName: _noteNames[noteIndex],
      octave: octave,
      cents: cents,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
    );
  }

  static const List<String> _noteNames = <String>[
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
}
