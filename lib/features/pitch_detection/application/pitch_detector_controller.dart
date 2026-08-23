import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pitchlab_lite/features/pitch_detection/data/microphone_pitch_service.dart';
import 'package:pitchlab_lite/features/pitch_detection/domain/pitch_reading.dart';

enum PitchDetectorStatus {
  idle,
  starting,
  listening,
  noPitch,
  permissionDenied,
  error,
}

class PitchDetectorController extends ChangeNotifier {
  PitchDetectorController({MicrophonePitchService? service})
      : _service = service ?? MicrophonePitchService() {
    _readingSubscription = _service.readings.listen(
      _onReading,
      onError: _onStreamError,
    );
  }

  final MicrophonePitchService _service;
  StreamSubscription<PitchReading?>? _readingSubscription;

  PitchDetectorStatus _status = PitchDetectorStatus.idle;
  PitchReading? _reading;
  String? _errorMessage;
  bool _disposed = false;

  PitchDetectorStatus get status => _status;
  PitchReading? get reading => _reading;
  String? get errorMessage => _errorMessage;

  bool get isRunning =>
      _status == PitchDetectorStatus.listening ||
      _status == PitchDetectorStatus.noPitch;

  Future<void> start() async {
    if (_disposed || _status == PitchDetectorStatus.starting || isRunning) {
      return;
    }

    _setState(status: PitchDetectorStatus.starting, reading: null, error: null);

    try {
      final started = await _service.start();
      if (_disposed) {
        return;
      }

      if (!started) {
        _setState(
          status: PitchDetectorStatus.permissionDenied,
          reading: null,
          error: 'Microphone permission is required to detect pitch.',
        );
        return;
      }

      _setState(status: PitchDetectorStatus.noPitch, reading: null, error: null);
    } catch (error) {
      if (!_disposed) {
        _setState(
          status: PitchDetectorStatus.error,
          reading: null,
          error: 'Unable to start microphone: $error',
        );
      }
    }
  }

  Future<void> stop() async {
    if (_disposed) {
      return;
    }

    try {
      await _service.stop();
      if (!_disposed) {
        _setState(status: PitchDetectorStatus.idle, reading: null, error: null);
      }
    } catch (error) {
      if (!_disposed) {
        _setState(
          status: PitchDetectorStatus.error,
          reading: null,
          error: 'Unable to stop microphone: $error',
        );
      }
    }
  }

  void _onReading(PitchReading? reading) {
    if (_disposed || !_service.isRunning) {
      return;
    }

    if (reading == null) {
      _setState(status: PitchDetectorStatus.noPitch, reading: null, error: null);
    } else {
      _setState(
        status: PitchDetectorStatus.listening,
        reading: reading,
        error: null,
      );
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    if (_disposed) {
      return;
    }
    _setState(
      status: PitchDetectorStatus.error,
      reading: null,
      error: 'Microphone stream error: $error',
    );
  }

  void _setState({
    required PitchDetectorStatus status,
    required PitchReading? reading,
    required String? error,
  }) {
    _status = status;
    _reading = reading;
    _errorMessage = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_readingSubscription?.cancel());
    _readingSubscription = null;
    unawaited(_service.dispose());
    super.dispose();
  }
}
