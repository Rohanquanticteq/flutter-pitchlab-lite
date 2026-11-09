import 'dart:math' as math;

import 'package:pitchlab_lite/features/pitch_detection/domain/pitch_reading.dart';

/// Filters raw pitch estimates into tuner-grade readings.
///
/// YIN correctly finds pitch in voiced speech too. A tuner should not react to
/// every short speech phoneme, so this gate requires a new chromatic pitch to
/// remain stable for several consecutive frames before exposing it.
///
/// Stability is evaluated modulo one octave. That means octave estimation
/// changes such as D#2 -> D#3 are treated as the same tuner pitch class.
class StableToneGate {
  StableToneGate({
    this.acquireFrames = 5,
    this.acquireToleranceCents = 55.0,
    this.followToleranceCents = 100.0,
    this.minimumConfidence = 0.70,
    this.releaseAfterMissingFrames = 6,
  }) : assert(acquireFrames > 0),
       assert(acquireToleranceCents > 0),
       assert(followToleranceCents >= acquireToleranceCents),
       assert(minimumConfidence >= 0 && minimumConfidence <= 1),
       assert(releaseAfterMissingFrames > 0);

  final int acquireFrames;
  final double acquireToleranceCents;
  final double followToleranceCents;
  final double minimumConfidence;
  final int releaseAfterMissingFrames;

  PitchReading? _lockedReading;
  PitchReading? _candidateAnchor;
  PitchReading? _candidateLatest;
  int _candidateFrames = 0;
  int _missingFrames = 0;

  PitchReading? get lockedReading => _lockedReading;

  PitchReading? process(PitchReading? reading) {
    if (reading == null || reading.confidence < minimumConfidence) {
      _candidateAnchor = null;
      _candidateLatest = null;
      _candidateFrames = 0;
      _missingFrames++;

      if (_missingFrames >= releaseAfterMissingFrames) {
        _lockedReading = null;
      }

      // Silence/unreliable audio must create a visible gap. We retain the
      // internal lock briefly only so a short dropout does not require a full
      // re-acquisition when the same musical tone immediately returns.
      return null;
    }

    _missingFrames = 0;
    final locked = _lockedReading;

    if (locked != null &&
        _pitchClassDistanceCents(locked, reading) <= followToleranceCents) {
      _lockedReading = reading;
      _clearCandidate();
      return reading;
    }

    final anchor = _candidateAnchor;
    if (anchor == null ||
        _pitchClassDistanceCents(anchor, reading) > acquireToleranceCents) {
      _candidateAnchor = reading;
      _candidateLatest = reading;
      _candidateFrames = 1;
      return null;
    }

    _candidateLatest = reading;
    _candidateFrames++;

    if (_candidateFrames < acquireFrames) {
      return null;
    }

    final accepted = _candidateLatest!;
    _lockedReading = accepted;
    _clearCandidate();
    return accepted;
  }

  void reset() {
    _lockedReading = null;
    _missingFrames = 0;
    _clearCandidate();
  }

  void _clearCandidate() {
    _candidateAnchor = null;
    _candidateLatest = null;
    _candidateFrames = 0;
  }

  static double _pitchClassDistanceCents(
    PitchReading first,
    PitchReading second,
  ) {
    final semitoneDistance =
        (first.pitchClassPosition - second.pitchClassPosition).abs();
    final circularDistance = math.min(
      semitoneDistance,
      12.0 - semitoneDistance,
    );
    return circularDistance * 100.0;
  }
}
