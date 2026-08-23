import 'package:flutter/material.dart';
import 'package:pitchlab_lite/features/pitch_detection/application/pitch_detector_controller.dart';

class PitchDetectorScreen extends StatefulWidget {
  const PitchDetectorScreen({super.key});

  @override
  State<PitchDetectorScreen> createState() => _PitchDetectorScreenState();
}

class _PitchDetectorScreenState extends State<PitchDetectorScreen> {
  late final PitchDetectorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PitchDetectorController()..addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final reading = _controller.reading;
    final isBusy = _controller.status == PitchDetectorStatus.starting;
    final isActive = _controller.isRunning;

    return Scaffold(
      appBar: AppBar(title: const Text('Pitch Detector')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    reading?.noteLabel ?? '--',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    reading == null
                        ? _statusText(_controller.status)
                        : '${reading.frequency.toStringAsFixed(1)} Hz',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (reading != null)
                    Text(
                      '${reading.cents >= 0 ? '+' : ''}${reading.cents.toStringAsFixed(1)} cents'
                      '  •  ${(reading.confidence * 100).toStringAsFixed(0)}% confidence',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  if (_controller.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 20),
                    Text(
                      _controller.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 36),
                  FilledButton.icon(
                    onPressed: isBusy
                        ? null
                        : isActive
                            ? _controller.stop
                            : _controller.start,
                    icon: Icon(isActive ? Icons.stop : Icons.mic),
                    label: Text(
                      isBusy
                          ? 'Starting…'
                          : isActive
                              ? 'Stop listening'
                              : 'Start listening',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sing or play one clear note at a time. Audio is analyzed live and is not saved.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusText(PitchDetectorStatus status) {
    return switch (status) {
      PitchDetectorStatus.idle => 'Tap Start listening',
      PitchDetectorStatus.starting => 'Requesting microphone…',
      PitchDetectorStatus.listening => 'Listening…',
      PitchDetectorStatus.noPitch => 'Listening — no clear pitch detected',
      PitchDetectorStatus.permissionDenied => 'Microphone permission denied',
      PitchDetectorStatus.error => 'Pitch detection unavailable',
    };
  }
}
