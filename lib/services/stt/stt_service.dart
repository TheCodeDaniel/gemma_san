import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

typedef DownloadProgressCallback = void Function(int percent);

// WhisperModel.tiny keeps inference RAM ~250 MB — safe alongside the Gemma 4B model.
// Small (~1 GB inference) triggers the OOM killer on 8 GB devices with Gemma loaded.
const _model = WhisperModel.tiny;
const _modelUrl = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin';

class SttService {
  bool _ready = false;
  bool _initializing = false;

  bool get isReady => _ready;

  Future<void> initialize({DownloadProgressCallback? onProgress}) async {
    if (_ready || _initializing) return;
    _initializing = true;

    try {
      final dir = await getApplicationSupportDirectory();
      final modelPath = _model.getPath(dir.path);
      debugPrint('[STT] model path: $modelPath');

      if (_isDownloadComplete(modelPath)) {
        debugPrint('[STT] model already on disk, skipping download');
        onProgress?.call(100);
      } else {
        await _cleanPartial(modelPath);
        debugPrint('[STT] downloading Whisper small…');
        final sw = Stopwatch()..start();
        await _downloadModel(url: _modelUrl, savePath: modelPath, onProgress: onProgress);
        debugPrint('[STT] download complete in ${sw.elapsed}');
      }

      _ready = true;
      debugPrint('[STT] ready');
    } catch (_) {
      _initializing = false;
      rethrow;
    }
  }

  /// Transcribes [audioFilePath] (16 kHz mono WAV).
  /// whisper_flutter_new runs FFI in Isolate.run() internally.
  Future<String> transcribe(String audioFilePath) async {
    if (!_ready) throw StateError('SttService not initialized');

    final audioBytes = File(audioFilePath).existsSync() ? File(audioFilePath).lengthSync() : -1;
    debugPrint('[STT] transcribing — ${audioBytes}B');

    if (audioBytes < 16000) {
      debugPrint('[STT] audio too short, skipping');
      return '';
    }

    final sw = Stopwatch()..start();

    // Whisper() defaults modelDir to getApplicationSupportDirectory() on Android,
    // which is exactly where we downloaded the model.
    final whisper = Whisper(model: _model);
    final response = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(audio: audioFilePath, isNoTimestamps: true, language: 'auto', threads: 4),
    );

    final text = response.text.trim();
    debugPrint('[STT] done in ${sw.elapsed} — ${text.length} chars');
    return text;
  }

  Future<void> dispose() async {
    _ready = false;
    _initializing = false;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static String _markerPath(String modelPath) => '$modelPath.complete';

  static bool _isDownloadComplete(String modelPath) =>
      File(modelPath).existsSync() && File(_markerPath(modelPath)).existsSync();

  static Future<void> _cleanPartial(String modelPath) async {
    for (final path in [modelPath, _markerPath(modelPath)]) {
      final f = File(path);
      if (f.existsSync()) await f.delete().catchError((_) => f);
    }
  }

  static Future<void> _downloadModel({
    required String url,
    required String savePath,
    DownloadProgressCallback? onProgress,
  }) async {
    final file = File(savePath);
    HttpClient? client;
    IOSink? sink;

    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 30);

      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('Connection', 'keep-alive');

      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Whisper download failed: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      sink = file.openWrite();
      int received = 0;
      int lastReported = -1;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;

        if (contentLength > 0) {
          final pct = (received * 100 ~/ contentLength).clamp(0, 99);
          if (pct != lastReported) {
            lastReported = pct;
            debugPrint('[STT] download $pct%');
            onProgress?.call(pct);
          }
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      await File(_markerPath(savePath)).writeAsString('ok');
      onProgress?.call(100);

      debugPrint('[STT] download finished — ${(received / 1024 / 1024).toStringAsFixed(1)} MB');
    } catch (e) {
      await sink?.close().catchError((_) {});
      await _cleanPartial(savePath);
      rethrow;
    } finally {
      client?.close(force: true);
    }
  }
}
