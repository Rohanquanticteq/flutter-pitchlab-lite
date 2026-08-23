import 'dart:async';
import 'dart:isolate';
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

class PitchAnalysisWorker {
  final StreamController<PitchAnalysisResult> _resultController =
      StreamController<PitchAnalysisResult>.broadcast();

  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSubscription;
  Isolate? _isolate;
  SendPort? _workerPort;
  Completer<void>? _readyCompleter;

  Stream<PitchAnalysisResult> get results => _resultController.stream;

  Future<void> start() async {
    if (_isolate != null) {
      return;
    }

    final receivePort = ReceivePort();
    _receivePort = receivePort;
    _readyCompleter = Completer<void>();
    _receiveSubscription = receivePort.listen(_handleMessage);
    _isolate = await Isolate.spawn(_workerEntryPoint, receivePort.sendPort);
    await _readyCompleter!.future;
  }

  void analyze(Uint8List pcm16Bytes, int sampleRate) {
    final workerPort = _workerPort;
    if (workerPort == null) {
      return;
    }

    workerPort.send(<Object>[
      TransferableTypedData.fromList(<Uint8List>[pcm16Bytes]),
      sampleRate,
    ]);
  }

  Future<void> dispose() async {
    _workerPort?.send('stop');
    _workerPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    await _receiveSubscription?.cancel();
    _receiveSubscription = null;
    _receivePort?.close();
    _receivePort = null;
    await _resultController.close();
  }

  void _handleMessage(dynamic message) {
    if (message is SendPort) {
      _workerPort = message;
      final completer = _readyCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      return;
    }

    if (message is Map<Object?, Object?>) {
      _resultController.add(
        PitchAnalysisResult(
          frequency: message['frequency'] as double?,
          confidence: (message['confidence'] as num).toDouble(),
          rms: (message['rms'] as num).toDouble(),
        ),
      );
    }
  }

  static void _workerEntryPoint(SendPort mainPort) {
    final commandPort = ReceivePort();
    mainPort.send(commandPort.sendPort);

    commandPort.listen((dynamic message) {
      if (message == 'stop') {
        commandPort.close();
        return;
      }

      if (message is! List<Object> || message.length != 2) {
        return;
      }

      final transferable = message[0] as TransferableTypedData;
      final sampleRate = message[1] as int;
      final bytes = transferable.materialize().asUint8List();
      final samples = _pcm16LittleEndianToNormalizedSamples(bytes);
      final detection = YinPitchDetector.detect(samples, sampleRate);

      mainPort.send(<String, double?>{
        'frequency': detection.frequency,
        'confidence': detection.confidence,
        'rms': detection.rms,
      });
    });
  }

  static List<double> _pcm16LittleEndianToNormalizedSamples(Uint8List bytes) {
    final evenLength = bytes.length - (bytes.length % 2);
    final samples = List<double>.filled(evenLength ~/ 2, 0.0, growable: false);
    final data = ByteData.sublistView(bytes, 0, evenLength);

    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}
