import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pitchlab_lite/features/pitch_detection/data/pitch_analysis_worker.dart';
import 'package:pitchlab_lite/features/pitch_detection/domain/pitch_reading.dart';
import 'package:record/record.dart';

class MicrophonePitchService {
  static const int sampleRate = 44100;
  static const int frameSampleCount = 2048;
  static const int _bytesPerSample = 2;
  static const int _frameByteCount = frameSampleCount * _bytesPerSample;

  final AudioRecorder _recorder = AudioRecorder();
  final PitchAnalysisWorker _analysisWorker = PitchAnalysisWorker();
  final StreamController<PitchReading?> _readingController =
      StreamController<PitchReading?>.broadcast();

  final Uint8List _frameBuffer = Uint8List(_frameByteCount);
  int _frameOffset = 0;
  bool _isRunning = false;
  bool _isDisposed = false;

  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<PitchAnalysisResult>? _analysisSubscription;

  Stream<PitchReading?> get readings => _readingController.stream;
  bool get isRunning => _isRunning;

  Future<bool> start() async {
    if (_isDisposed) {
      throw StateError('MicrophonePitchService has been disposed.');
    }
    if (_isRunning) {
      return true;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      return false;
    }

    await _analysisWorker.start();
    _analysisSubscription ??= _analysisWorker.results.listen(_handleAnalysisResult);

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        streamBufferSize: 4096,
      ),
    );

    _frameOffset = 0;
    _isRunning = true;
    _audioSubscription = stream.listen(
      _handleAudioChunk,
      onError: _readingController.addError,
      cancelOnError: false,
    );
    return true;
  }

  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;
    _frameOffset = 0;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _recorder.stop();
    if (!_readingController.isClosed) {
      _readingController.add(null);
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await stop();
    await _analysisSubscription?.cancel();
    _analysisSubscription = null;
    await _analysisWorker.dispose();
    await _recorder.dispose();
    await _readingController.close();
  }

  void _handleAudioChunk(Uint8List chunk) {
    if (!_isRunning || chunk.isEmpty) {
      return;
    }

    var sourceOffset = 0;
    while (sourceOffset < chunk.length) {
      final available = _frameByteCount - _frameOffset;
      final remaining = chunk.length - sourceOffset;
      final copyLength = math.min(available, remaining);

      _frameBuffer.setRange(
        _frameOffset,
        _frameOffset + copyLength,
        chunk,
        sourceOffset,
      );
      _frameOffset += copyLength;
      sourceOffset += copyLength;

      if (_frameOffset == _frameByteCount) {
        _analysisWorker.analyze(Uint8List.fromList(_frameBuffer), sampleRate);
        _frameOffset = 0;
      }
    }
  }

  void _handleAnalysisResult(PitchAnalysisResult result) {
    if (!_isRunning || _readingController.isClosed) {
      return;
    }

    final frequency = result.frequency;
    if (frequency == null) {
      _readingController.add(null);
      return;
    }

    _readingController.add(
      PitchReading.fromFrequency(
        frequency,
        confidence: result.confidence,
      ),
    );
  }
}
