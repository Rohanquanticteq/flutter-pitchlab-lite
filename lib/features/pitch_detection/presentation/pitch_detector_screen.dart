import 'package:flutter/material.dart';
import 'package:pitchlab_lite/features/pitch_detection/application/pitch_detector_controller.dart';
import 'package:pitchlab_lite/features/pitch_detection/presentation/pitch_history_buffer.dart';
import 'package:pitchlab_lite/features/pitch_detection/presentation/pitch_history_painter.dart';

class PitchDetectorScreen extends StatefulWidget {
  const PitchDetectorScreen({super.key});

  @override
  State<PitchDetectorScreen> createState() => _PitchDetectorScreenState();
}

class _PitchDetectorScreenState extends State<PitchDetectorScreen>
    with SingleTickerProviderStateMixin {
  late final PitchDetectorController _controller;
  late final AnimationController _repaintTicker;
  final PitchHistoryBuffer _history = PitchHistoryBuffer();

  PitchDetectorStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    _controller = PitchDetectorController()..addListener(_onControllerChanged);
    _repaintTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _repaintTicker.dispose();
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }

    final reading = _controller.reading;
    if (reading != null) {
      _history.addReading(reading);
    } else if (_controller.status == PitchDetectorStatus.noPitch &&
        _lastStatus != PitchDetectorStatus.noPitch) {
      _history.addGap();
    }

    if (_controller.status == PitchDetectorStatus.idle) {
      _history.clear();
    }

    _lastStatus = _controller.status;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reading = _controller.reading;
    final isBusy = _controller.status == PitchDetectorStatus.starting;
    final isActive = _controller.isRunning;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AnimatedBuilder(
              animation: _repaintTicker,
              builder: (BuildContext context, Widget? child) {
                _history.trim();
                return CustomPaint(
                  painter: PitchHistoryPainter(
                    points: _history.points,
                    now: DateTime.now(),
                    historyDuration: _history.historyDuration,
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _MicControl(
                isBusy: isBusy,
                isActive: isActive,
                onPressed: isBusy
                    ? null
                    : isActive
                        ? _controller.stop
                        : _controller.start,
              ),
            ),
            Positioned(
              left: 64,
              right: 12,
              bottom: 12,
              child: _PitchStatusOverlay(
                readingLabel: reading?.noteLabel,
                frequency: reading?.frequency,
                cents: reading?.cents,
                status: _controller.status,
                errorMessage: _controller.errorMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicControl extends StatelessWidget {
  const _MicControl({
    required this.isBusy,
    required this.isActive,
    required this.onPressed,
  });

  final bool isBusy;
  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC101214),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: isActive ? 'Stop listening' : 'Start listening',
        onPressed: onPressed,
        color: Colors.white,
        icon: isBusy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(isActive ? Icons.stop_rounded : Icons.mic_rounded),
      ),
    );
  }
}

class _PitchStatusOverlay extends StatelessWidget {
  const _PitchStatusOverlay({
    required this.readingLabel,
    required this.frequency,
    required this.cents,
    required this.status,
    required this.errorMessage,
  });

  final String? readingLabel;
  final double? frequency;
  final double? cents;
  final PitchDetectorStatus status;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final label = readingLabel;
    final hz = frequency;
    final centValue = cents;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomRight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: errorMessage != null
                ? Text(
                    errorMessage!,
                    style: const TextStyle(color: Color(0xFFFF8A80)),
                  )
                : label != null && hz != null && centValue != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${hz.toStringAsFixed(1)} Hz',
                            style: const TextStyle(
                              color: Color(0xFFB7BDC1),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${centValue >= 0 ? '+' : ''}${centValue.toStringAsFixed(0)}¢',
                            style: const TextStyle(
                              color: Color(0xFFB7BDC1),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _statusText(status),
                        style: const TextStyle(
                          color: Color(0xFFB7BDC1),
                          fontSize: 13,
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  String _statusText(PitchDetectorStatus status) {
    return switch (status) {
      PitchDetectorStatus.idle => 'Tap the microphone to start',
      PitchDetectorStatus.starting => 'Starting microphone…',
      PitchDetectorStatus.listening => 'Listening…',
      PitchDetectorStatus.noPitch => 'Listening — no clear pitch',
      PitchDetectorStatus.permissionDenied => 'Microphone permission denied',
      PitchDetectorStatus.error => 'Pitch detection unavailable',
    };
  }
}
