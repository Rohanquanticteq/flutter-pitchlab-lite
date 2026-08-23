import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pitchlab_lite/features/pitch_detection/presentation/pitch_history_buffer.dart';

class PitchHistoryPainter extends CustomPainter {
  PitchHistoryPainter({
    required this.points,
    required this.now,
    required this.historyDuration,
  });

  final List<PitchHistoryPoint> points;
  final DateTime now;
  final Duration historyDuration;

  static const double _labelWidth = 52;
  static const double _verticalPadding = 24;
  static const List<String> _notes = <String>[
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

  static const List<Color> _noteColors = <Color>[
    Color(0xFF9AEF62),
    Color(0xFF6EDB74),
    Color(0xFF62E8C4),
    Color(0xFF74D4DB),
    Color(0xFF81C9F2),
    Color(0xFF787BF2),
    Color(0xFF7974D5),
    Color(0xFFC152E9),
    Color(0xFFD950B4),
    Color(0xFFF26772),
    Color(0xFFF29B68),
    Color(0xFFD5C766),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    if (size.width <= _labelWidth || size.height <= _verticalPadding * 2) {
      return;
    }

    final top = _verticalPadding;
    final bottom = size.height - _verticalPadding;
    final rowSpacing = (bottom - top) / (_notes.length - 1);

    _paintGrid(canvas, size, top, bottom, rowSpacing);
    _paintHistory(canvas, size, top, bottom, rowSpacing);
  }

  void _paintGrid(
    Canvas canvas,
    Size size,
    double top,
    double bottom,
    double rowSpacing,
  ) {
    final linePaint = Paint()
      ..color = const Color(0xFF7D858A).withValues(alpha: 0.48)
      ..strokeWidth = 1.25;

    for (var pitchClass = 0; pitchClass < _notes.length; pitchClass++) {
      final y = bottom - pitchClass * rowSpacing;
      canvas.drawLine(Offset(_labelWidth, y), Offset(size.width, y), linePaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: _notes[pitchClass],
          style: const TextStyle(
            color: Color(0xFFE9EAEC),
            fontSize: 24,
            fontWeight: FontWeight.w300,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _labelWidth - 8);

      textPainter.paint(
        canvas,
        Offset(8, y - textPainter.height / 2),
      );
    }
  }

  void _paintHistory(
    Canvas canvas,
    Size size,
    double top,
    double bottom,
    double rowSpacing,
  ) {
    if (points.length < 2) {
      return;
    }

    final graphLeft = _labelWidth + 10;
    final graphRight = size.width - 8;
    final graphWidth = graphRight - graphLeft;
    final historyMicros = historyDuration.inMicroseconds.toDouble();

    PitchHistoryPoint? previous;
    Offset? previousOffset;

    for (final point in points) {
      final ageMicros = now.difference(point.time).inMicroseconds.toDouble();
      if (ageMicros < 0 || ageMicros > historyMicros) {
        previous = point;
        previousOffset = null;
        continue;
      }

      final position = point.pitchClassPosition;
      if (position == null) {
        previous = point;
        previousOffset = null;
        continue;
      }

      final x = graphRight - (ageMicros / historyMicros) * graphWidth;
      final y = bottom - position * rowSpacing;
      final currentOffset = Offset(x, y.clamp(top, bottom));

      final previousPoint = previous;
      final previousPointOffset = previousOffset;
      if (previousPoint != null &&
          previousPoint.hasPitch &&
          previousPointOffset != null &&
          point.time.difference(previousPoint.time).inMilliseconds <= 180) {
        final averagePitch =
            ((previousPoint.pitchClassPosition! + position) / 2).round() % 12;
        final color = _noteColors[averagePitch];
        final confidence =
            ((previousPoint.confidence + point.confidence) / 2).clamp(0.0, 1.0);
        _drawGlowingSegment(
          canvas,
          previousPointOffset,
          currentOffset,
          color,
          confidence,
        );
      }

      previous = point;
      previousOffset = currentOffset;
    }
  }

  void _drawGlowingSegment(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
    double confidence,
  ) {
    final opacity = (0.28 + confidence * 0.72).clamp(0.0, 1.0);

    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: 0.15 * opacity)
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: 0.35 * opacity)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = 1.5 + confidence * 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant PitchHistoryPainter oldDelegate) => true;
}
