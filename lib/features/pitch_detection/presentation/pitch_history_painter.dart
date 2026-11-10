import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pitchlab_lite/features/pitch_detection/presentation/pitch_history_buffer.dart';

class PitchHistoryPainter extends CustomPainter {
  PitchHistoryPainter({
    required this.points,
    required this.candidatePoints,
    required this.now,
    required this.historyDuration,
  });

  final List<PitchHistoryPoint> points;
  final List<PitchHistoryPoint> candidatePoints;
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

    _paintGrid(canvas, size, bottom, rowSpacing);
    _paintCandidateHistory(canvas, size, top, bottom, rowSpacing);
    _paintHistory(canvas, size, top, bottom, rowSpacing);
  }

  void _paintGrid(
    Canvas canvas,
    Size size,
    double bottom,
    double rowSpacing,
  ) {
    final linePaint = Paint()
      ..color = const Color(0xFF7D858A).withValues(alpha: 0.42)
      ..strokeWidth = 1.1;

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

  void _paintCandidateHistory(
    Canvas canvas,
    Size size,
    double top,
    double bottom,
    double rowSpacing,
  ) {
    if (candidatePoints.isEmpty) {
      return;
    }

    final graphLeft = _labelWidth + 8;
    final graphRight = size.width - 8;
    final graphWidth = graphRight - graphLeft;
    final historyMicros = historyDuration.inMicroseconds.toDouble();

    for (final point in candidatePoints) {
      final position = point.pitchClassPosition;
      if (position == null) {
        continue;
      }

      final ageMicros = now.difference(point.time).inMicroseconds.toDouble();
      if (ageMicros < 0 || ageMicros > historyMicros) {
        continue;
      }

      final x = graphRight - (ageMicros / historyMicros) * graphWidth;
      final y = (bottom - position * rowSpacing).clamp(top, bottom).toDouble();
      final confidence = point.confidence.clamp(0.0, 1.0).toDouble();
      final pitchClass = position.round() % 12;
      final ageFraction =
          (ageMicros / historyMicros).clamp(0.0, 1.0).toDouble();
      final historyStrength = 1.0 - ageFraction * 0.35;

      _drawPitchEnergyMark(
        canvas,
        center: Offset(x, y),
        color: _noteColors[pitchClass],
        confidence: confidence,
        rowSpacing: rowSpacing,
        historyStrength: historyStrength,
        seed: point.time.microsecondsSinceEpoch,
        intensityScale: 0.34,
        drawCore: false,
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
    if (points.isEmpty) {
      return;
    }

    final graphLeft = _labelWidth + 8;
    final graphRight = size.width - 8;
    final graphWidth = graphRight - graphLeft;
    final historyMicros = historyDuration.inMicroseconds.toDouble();

    PitchHistoryPoint? previousPoint;
    Offset? previousCenter;

    for (final point in points) {
      final position = point.pitchClassPosition;
      if (position == null) {
        previousPoint = null;
        previousCenter = null;
        continue;
      }

      final ageMicros = now.difference(point.time).inMicroseconds.toDouble();
      if (ageMicros < 0 || ageMicros > historyMicros) {
        previousPoint = null;
        previousCenter = null;
        continue;
      }

      final x = graphRight - (ageMicros / historyMicros) * graphWidth;
      final y = (bottom - position * rowSpacing).clamp(top, bottom).toDouble();
      final confidence = point.confidence.clamp(0.0, 1.0).toDouble();
      final currentCenter = Offset(x, y);

      final ageFraction =
          (ageMicros / historyMicros).clamp(0.0, 1.0).toDouble();
      final historyStrength = 1.0 - ageFraction * 0.18;

      final previous = previousPoint;
      final previousOffset = previousCenter;
      if (previous != null && previousOffset != null) {
        final previousPosition = previous.pitchClassPosition!;
        final timeGapMs = point.time.difference(previous.time).inMilliseconds;
        final pitchDistance =
            _pitchClassDistance(previousPosition, position);

        if (timeGapMs > 0 &&
            timeGapMs <= 180 &&
            pitchDistance <= 0.75) {
          _paintInterpolatedEnergy(
            canvas,
            fromPoint: previous,
            toPoint: point,
            from: previousOffset,
            to: currentCenter,
            fromPosition: previousPosition,
            toPosition: position,
            rowSpacing: rowSpacing,
            top: top,
            bottom: bottom,
            historyStrength: historyStrength,
          );
        }
      }

      final pitchClass = position.round() % 12;
      _drawPitchEnergyMark(
        canvas,
        center: currentCenter,
        color: _noteColors[pitchClass],
        confidence: confidence,
        rowSpacing: rowSpacing,
        historyStrength: historyStrength,
        seed: point.time.microsecondsSinceEpoch,
      );

      previousPoint = point;
      previousCenter = currentCenter;
    }
  }

  void _paintInterpolatedEnergy(
    Canvas canvas, {
    required PitchHistoryPoint fromPoint,
    required PitchHistoryPoint toPoint,
    required Offset from,
    required Offset to,
    required double fromPosition,
    required double toPosition,
    required double rowSpacing,
    required double top,
    required double bottom,
    required double historyStrength,
  }) {
    final pixelDistance = (to.dx - from.dx).abs();
    if (pixelDistance < 3) {
      return;
    }

    final steps = (pixelDistance / 3.0).ceil();
    final pitchDelta = _shortestPitchDelta(fromPosition, toPosition);

    for (var i = 1; i < steps; i++) {
      final t = i / steps;
      final x = from.dx + (to.dx - from.dx) * t;
      final interpolatedPosition = _wrapPitchClass(
        fromPosition + pitchDelta * t,
      );
      final y = (bottom - interpolatedPosition * rowSpacing)
          .clamp(top, bottom)
          .toDouble();
      final confidence =
          fromPoint.confidence +
          (toPoint.confidence - fromPoint.confidence) * t;
      final pitchClass = interpolatedPosition.round() % 12;

      _drawPitchEnergyMark(
        canvas,
        center: Offset(x, y),
        color: _noteColors[pitchClass],
        confidence: confidence.clamp(0.0, 1.0).toDouble(),
        rowSpacing: rowSpacing,
        historyStrength: historyStrength,
        seed: fromPoint.time.microsecondsSinceEpoch + i * 997,
      );
    }
  }

  double _pitchClassDistance(double first, double second) {
    final difference = (first - second).abs();
    return math.min(difference, 12.0 - difference);
  }

  double _shortestPitchDelta(double from, double to) {
    var delta = to - from;
    if (delta > 6.0) {
      delta -= 12.0;
    } else if (delta < -6.0) {
      delta += 12.0;
    }
    return delta;
  }

  double _wrapPitchClass(double value) {
    final wrapped = value % 12.0;
    return wrapped < 0 ? wrapped + 12.0 : wrapped;
  }

  void _drawPitchEnergyMark(
    Canvas canvas, {
    required Offset center,
    required Color color,
    required double confidence,
    required double rowSpacing,
    required double historyStrength,
    required int seed,
    double intensityScale = 1.0,
    bool drawCore = true,
  }) {
    // Confidence now controls visual intensity directly. Weak-but-stable pitch
    // is deliberately visible as a faint trace, while clean tones build a
    // much brighter and thicker band.
    final strength =
        (((0.06 + confidence * 0.94) * historyStrength) * intensityScale)
            .clamp(0.0, 1.0)
            .toDouble();
    final plumeHeight = rowSpacing * (0.12 + confidence * 0.28);
    final plumeWidth = 1.8 + confidence * 4.2;

    // A broad, low-opacity halo. Overlapping samples create the soft
    // horizontal energy band seen in PitchLab without connecting data points.
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: plumeWidth * 3.0,
        height: plumeHeight * 1.55,
      ),
      Paint()
        ..color = color.withValues(alpha: 0.10 * strength)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
    );

    // Mid-energy body. Each sample is independent, so a note change cannot
    // create a vertical or diagonal connector to the previous note.
    canvas.drawLine(
      Offset(center.dx, center.dy - plumeHeight * 0.42),
      Offset(center.dx, center.dy + plumeHeight * 0.42),
      Paint()
        ..color = color.withValues(alpha: 0.28 * strength)
        ..strokeWidth = plumeWidth
        ..strokeCap = StrokeCap.round
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
    );

    // Bright pitch core is reserved for confirmed/stable pitch. Raw candidates
    // stay soft so they read as uncertain energy rather than a locked note.
    if (drawCore) {
      canvas.drawLine(
        Offset(center.dx, center.dy - plumeHeight * 0.16),
        Offset(center.dx, center.dy + plumeHeight * 0.16),
        Paint()
          ..color = color.withValues(alpha: 0.82 * strength)
          ..strokeWidth = 1.1 + confidence * 1.7
          ..strokeCap = StrokeCap.round,
      );
    }

    // Deterministic side wisps mimic the reference app's fuzzy/noisy texture
    // without introducing random flicker on every repaint.
    for (var i = 0; i < 3; i++) {
      final noise = _noise(seed, i);
      final side = i.isEven ? -1.0 : 1.0;
      final dx = side * (1.3 + noise * plumeWidth);
      final verticalOffset = (noise - 0.5) * plumeHeight * 0.58;
      final halfHeight = plumeHeight * (0.08 + noise * 0.14);

      canvas.drawLine(
        Offset(center.dx + dx, center.dy + verticalOffset - halfHeight),
        Offset(center.dx + dx, center.dy + verticalOffset + halfHeight),
        Paint()
          ..color = color.withValues(alpha: 0.18 * strength)
          ..strokeWidth = 0.7 + noise
          ..strokeCap = StrokeCap.round
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5),
      );
    }
  }

  double _noise(int seed, int index) {
    final value = math.sin(seed * 0.000001 + index * 12.9898) * 43758.5453;
    return value - value.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant PitchHistoryPainter oldDelegate) => true;
}
