import 'package:flutter_test/flutter_test.dart';
import 'package:pitchlab_lite/features/pitch_detection/domain/pitch_reading.dart';
import 'package:pitchlab_lite/features/pitch_detection/presentation/pitch_history_buffer.dart';

void main() {
  test('history buffer is bounded and trims old pitch points', () {
    final buffer = PitchHistoryBuffer(
      historyDuration: const Duration(seconds: 2),
      maxPoints: 3,
    );
    final base = DateTime(2026, 1, 1, 12);
    final reading = PitchReading.fromFrequency(440, confidence: 0.9);

    buffer.addReading(reading, at: base);
    buffer.addReading(reading, at: base.add(const Duration(milliseconds: 500)));
    buffer.addReading(reading, at: base.add(const Duration(seconds: 1)));
    buffer.addReading(reading, at: base.add(const Duration(milliseconds: 1500)));

    expect(buffer.points, hasLength(3));

    buffer.trim(now: base.add(const Duration(seconds: 4)));
    expect(buffer.points, isEmpty);
  });

  test('gap marker breaks the pitch trace without duplicating gaps', () {
    final buffer = PitchHistoryBuffer();
    final reading = PitchReading.fromFrequency(440, confidence: 0.9);
    final now = DateTime(2026, 1, 1, 12);

    buffer.addReading(reading, at: now);
    buffer.addGap(at: now.add(const Duration(milliseconds: 50)));
    buffer.addGap(at: now.add(const Duration(milliseconds: 100)));

    expect(buffer.points, hasLength(2));
    expect(buffer.points.last.hasPitch, isFalse);
  });
}
