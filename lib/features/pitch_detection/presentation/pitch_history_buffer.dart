import 'package:flutter/foundation.dart';
import 'package:pitchlab_lite/features/pitch_detection/domain/pitch_reading.dart';

@immutable
class PitchHistoryPoint {
  const PitchHistoryPoint({
    required this.time,
    required this.pitchClassPosition,
    required this.confidence,
  });

  final DateTime time;
  final double? pitchClassPosition;
  final double confidence;

  bool get hasPitch => pitchClassPosition != null;
}

class PitchHistoryBuffer {
  PitchHistoryBuffer({
    this.historyDuration = const Duration(seconds: 8),
    this.maxPoints = 512,
  });

  final Duration historyDuration;
  final int maxPoints;
  final List<PitchHistoryPoint> _points = <PitchHistoryPoint>[];

  List<PitchHistoryPoint> get points => List<PitchHistoryPoint>.unmodifiable(_points);

  void addReading(PitchReading reading, {DateTime? at}) {
    _points.add(
      PitchHistoryPoint(
        time: at ?? DateTime.now(),
        pitchClassPosition: reading.pitchClassPosition,
        confidence: reading.confidence,
      ),
    );
    _trim(at ?? DateTime.now());
  }

  void addGap({DateTime? at}) {
    final now = at ?? DateTime.now();
    if (_points.isNotEmpty && !_points.last.hasPitch) {
      _trim(now);
      return;
    }

    _points.add(
      PitchHistoryPoint(
        time: now,
        pitchClassPosition: null,
        confidence: 0,
      ),
    );
    _trim(now);
  }

  void clear() => _points.clear();

  void trim({DateTime? now}) => _trim(now ?? DateTime.now());

  void _trim(DateTime now) {
    final cutoff = now.subtract(historyDuration);
    var removeCount = 0;
    while (removeCount < _points.length && _points[removeCount].time.isBefore(cutoff)) {
      removeCount++;
    }
    if (removeCount > 0) {
      _points.removeRange(0, removeCount);
    }

    final overflow = _points.length - maxPoints;
    if (overflow > 0) {
      _points.removeRange(0, overflow);
    }
  }
}
