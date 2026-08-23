import 'dart:math' as math;

class PitchReading {
  const PitchReading({
    required this.frequency,
    required this.noteName,
    required this.octave,
    required this.cents,
    required this.confidence,
    required this.pitchClassPosition,
  });

  /// Raw detected fundamental frequency from the microphone.
  final double frequency;

  /// Octave-independent chromatic pitch class, for example C, D#, or A.
  final String noteName;

  /// Scientific-pitch octave. Kept internally for diagnostics/future features,
  /// but deliberately excluded from the primary PitchLab-style note label.
  final int octave;

  /// Deviation from the nearest chromatic note in cents.
  final double cents;

  final double confidence;

  /// Continuous octave-independent pitch position in the range [0, 12), where
  /// C = 0, C# = 1, ... B = 11. Values between integers represent cents.
  ///
  /// This is the value the future PitchLab-style scrolling graph should use so
  /// an octave-detection change such as D#2 -> D#3 does not jump to another row.
  final double pitchClassPosition;

  /// Primary app label. PitchLab-style output intentionally omits the octave.
  String get noteLabel => noteName;

  /// Scientific pitch notation is still available for diagnostics if needed.
  String get scientificNoteLabel => '$noteName$octave';

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
    final pitchClassPosition = _positiveModulo(fractionalMidi, 12.0);

    return PitchReading(
      frequency: frequency,
      noteName: _noteNames[noteIndex],
      octave: octave,
      cents: cents,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
      pitchClassPosition: pitchClassPosition,
    );
  }

  static double _positiveModulo(double value, double modulus) {
    final result = value % modulus;
    return result < 0 ? result + modulus : result;
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
