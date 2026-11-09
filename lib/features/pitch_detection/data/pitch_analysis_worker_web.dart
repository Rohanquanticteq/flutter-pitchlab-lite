import 'dart:async';
import 'dart:typed_data';

import 'package:pitchlab_lite/features/pitch_detection/data/yin_pitch_detector.dart';

class PitchAnalysisResult {
  const PitchAnalysisResult({
    required this.frequency,
    required this.confidence,
    required this.rms,
  });

  final double? frequency;
  final double confidence;
  final double rms;
}

/// Browser-compatible pitch analysis worker.
///
/// Dart isolates/ReceivePort are not available in the same way in Flutter Web.
/// For the development preview we keep processing bounded and yield back to the
/// browser event loop between frames. Native Android/iOS continues to use the
/// isolate implementation.
class PitchAnalysisWorker {
  final StreamController<PitchAnalysisResult> _resultController =
      StreamController<PitchAnalysisResult>.broadcast();

  bool _started = false;
  bool _busy = false;
  bool _disposed = false;
  Uint8List? _pendingFrame;
  int? _pendingSampleRate;

  Stream<PitchAnalysisResult> get results => _resultController.stream;

  Future<void> start() async {
    if (_disposed) {
      throw StateError('PitchAnalysisWorker has been disposed.');
    }
    _started = true;
  }

  void analyze(Uint8List pcm16Bytes, int sampleRate) {
    if (!_started || _disposed) {
      return;
    }

    if (_busy) {
      // Keep only the newest waiting frame, matching the native backpressure
      // behavior and preventing browser-side latency growth.
      _pendingFrame = pcm16Bytes;
      _pendingSampleRate = sampleRate;
      return;
    }

    _runFrame(pcm16Bytes, sampleRate);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _started = false;
    _busy = false;
    _pendingFrame = null;
    _pendingSampleRate = null;
    await _resultController.close();
  }

  void _runFrame(Uint8List bytes, int sampleRate) {
    _busy = true;

    Timer.run(() {
      if (_disposed) {
        _busy = false;
        return;
      }

      try {
        final samples = _pcm16LittleEndianToNormalizedSamples(bytes);
        final detection = YinPitchDetector.detect(samples, sampleRate);

        if (!_resultController.isClosed) {
          _resultController.add(
            PitchAnalysisResult(
              frequency: detection.frequency,
              confidence: detection.confidence,
              rms: detection.rms,
            ),
          );
        }
      } catch (error, stackTrace) {
        if (!_resultController.isClosed) {
          _resultController.addError(error, stackTrace);
        }
      } finally {
        _busy = false;

        final pendingFrame = _pendingFrame;
        final pendingSampleRate = _pendingSampleRate;
        _pendingFrame = null;
        _pendingSampleRate = null;

        if (!_disposed &&
            pendingFrame != null &&
            pendingSampleRate != null) {
          _runFrame(pendingFrame, pendingSampleRate);
        }
      }
    });
  }

  static List<double> _pcm16LittleEndianToNormalizedSamples(Uint8List bytes) {
    final evenLength = bytes.length - (bytes.length % 2);
    final samples =
        List<double>.filled(evenLength ~/ 2, 0.0, growable: false);
    final data = ByteData.sublistView(bytes, 0, evenLength);

    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}
