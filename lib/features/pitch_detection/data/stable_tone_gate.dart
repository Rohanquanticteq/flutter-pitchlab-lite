import 'dart:math' as math;

import 'package:pitchlab_lite/features/pitch_detection/domain/pitch_reading.dart';

/// Converts raw pitch estimates into stable tuner-grade readings.
///
/// Normal speech often contains valid instantaneous pitch, but changes too
/// quickly to form a useful tuner trace. Musical tones are usually much more
/// stable over time. This gate therefore:
///
/// - requires a short stable acquisition window before exposing a new tone;
/// - tracks the locked tone through normal vibrato and octave estimation flips;
/// - bridges brief confidence dropouts instead of immediately breaking the line;
/// - requires a different pitch to become stable before switching notes.
class StableToneGate {
  StableToneGate({
    this.acquireFrames = 4,
    this.weakAcquireFrames = 7,
    this.acquireToleranceCents = 70.0,
    this.followToleranceCents = 130.0,
    this.minimumAcquireConfidence = 0.58,
    this.minimumWeakConfidence = 0.42,
    this.minimumFollowConfidence = 0.45,
    this.holdFrames = 3,
    this.releaseAfterMissingFrames = 8,
  }) : assert(acquireFrames > 0),
       assert(acquireToleranceCents > 0),
       assert(followToleranceCents >= acquireToleranceCents),
       assert(minimumAcquireConfidence >= 0 &&
           minimumAcquireConfidence <= 1),
       assert(minimumWeakConfidence >= 0 &&
           minimumWeakConfidence <= minimumAcquireConfidence),
       assert(minimumFollowConfidence >= 0 &&
           minimumFollowConfidence <= 1),
       assert(holdFrames >= 0),
       assert(releaseAfterMissingFrames > holdFrames);

  final int acquireFrames;
  final int weakAcquireFrames;
  final double acquireToleranceCents;
  final double followToleranceCents;
  final double minimumAcquireConfidence;
  final double minimumWeakConfidence;
  final double minimumFollowConfidence;
  final int holdFrames;
  final int releaseAfterMissingFrames;

  PitchReading? _lockedReading;
  PitchReading? _candidateAnchor;
  PitchReading? _candidateLatest;
  int _candidateFrames = 0;
  int _missingFrames = 0;

  PitchReading? get lockedReading => _lockedReading;

  PitchReading? process(PitchReading? reading) {
    final locked = _lockedReading;

    if (reading == null) {
      return _handleMissingFrame(locked);
    }

    if (locked != null) {
      final distance = _pitchClassDistanceCents(locked, reading);

      if (reading.confidence >= minimumFollowConfidence &&
          distance <= followToleranceCents) {
        _missingFrames = 0;
        _lockedReading = reading;
        _clearCandidate();
        return reading;
      }

      // A different pitch must prove itself before replacing the lock.
      // While that candidate is being acquired, keep the previous locked tone
      // briefly for visual continuity without clearing the candidate state.
      if (reading.confidence >= minimumWeakConfidence) {
        final switched = _processCandidate(
          reading,
          requiredFrames: reading.confidence >= minimumAcquireConfidence
              ? acquireFrames
              : weakAcquireFrames,
        );
        if (switched != null) {
          return switched;
        }
        return _holdLockedFrame(locked, preserveCandidate: true);
      }

      _clearCandidate();
      return _handleMissingFrame(locked);
    }

    if (reading.confidence < minimumWeakConfidence) {
      _clearCandidate();
      return null;
    }

    return _processCandidate(
      reading,
      requiredFrames: reading.confidence >= minimumAcquireConfidence
          ? acquireFrames
          : weakAcquireFrames,
    );
  }

  PitchReading? _processCandidate(
    PitchReading reading, {
    required int requiredFrames,
  }) {
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

    if (_candidateFrames < requiredFrames) {
      return null;
    }

    final accepted = _candidateLatest!;
    _lockedReading = accepted;
    _missingFrames = 0;
    _clearCandidate();
    return accepted;
  }

  PitchReading? _handleMissingFrame(PitchReading? locked) {
    _clearCandidate();
    return _holdLockedFrame(locked, preserveCandidate: false);
  }

  PitchReading? _holdLockedFrame(
    PitchReading? locked, {
    required bool preserveCandidate,
  }) {
    _missingFrames++;

    if (locked == null) {
      return null;
    }

    if (_missingFrames <= holdFrames) {
      // Preserve short gaps as a weaker reading so the visual trace remains
      // continuous through momentary YIN confidence dips or while a new note
      // is being confirmed.
      return PitchReading.fromFrequency(
        locked.frequency,
        confidence: (locked.confidence * 0.72).clamp(0.0, 1.0),
      );
    }

    if (_missingFrames >= releaseAfterMissingFrames) {
      _lockedReading = null;
      if (!preserveCandidate) {
        _clearCandidate();
      }
    }

    return null;
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
