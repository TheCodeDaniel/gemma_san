import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

// E2B model (2B effective params) — lighter, better for low-end target devices.
// Vision (supportImage: true) blocked: Gemma 4 E2B/E4B both have 3-subgraph vision
// encoders that flutter_gemma 0.14.x rejects. Text generation works fine.
const _modelUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/'
    'resolve/main/gemma-4-E2B-it.litertlm';

const _modelFilename = 'gemma-4-E2B-it.litertlm';

// Set at build time via .env / --dart-define=HF_TOKEN=hf_xxx
const _hfToken = String.fromEnvironment('HF_TOKEN');

// USE_GPU=false  → CPU backend (works on emulator and all real devices, slower)
// USE_GPU=true   → GPU backend (real device only — crashes on emulator's SwiftShader)
const _useGpu = bool.fromEnvironment('USE_GPU', defaultValue: false);

// Dev shortcut: set DEV_MODEL_PATH to an absolute path on the device where you've
// already pushed the model file (e.g. /sdcard/Download/gemma-4-E4B-it.litertlm).
// When set and the file exists, initialize() skips HF download entirely.
// Leave empty (or omit) in production builds.
const _devModelPath = String.fromEnvironment('DEV_MODEL_PATH', defaultValue: '');

// Vision encoder needs ~190 MB of GPU headroom. With supportImage=true the
// KV cache at 512 tokens (~190 MB) fits alongside the vision subgraphs on S22.
// Raise back to 1024 only if vision is disabled and you need longer context.
const _maxTokens = 512;

typedef DownloadProgressCallback = void Function(int percent);

class GemmaService {
  InferenceModel? _model;
  bool _initializing = false;

  bool get isReady => _model != null;

  /// Idempotent. Downloads model on first call using dart:io HttpClient
  /// (bypasses WorkManager to avoid Android's 10-min background task timeout),
  /// then loads it into memory.
  Future<void> initialize({DownloadProgressCallback? onProgress}) async {
    if (isReady || _initializing) return;
    _initializing = true;

    try {
      debugPrint('[Gemma] initializing SDK…');
      await FlutterGemma.initialize(huggingFaceToken: _hfToken);

      String modelPath;
      if (_devModelPath.isNotEmpty && File(_devModelPath).existsSync()) {
        debugPrint('[Gemma] DEV: using model at $_devModelPath — skipping download');
        modelPath = _devModelPath;
        onProgress?.call(100);
      } else {
        if (_hfToken.isEmpty) {
          _initializing = false;
          throw StateError('HF_TOKEN is empty. Add HF_TOKEN=hf_xxx to your .env file.');
        }
        modelPath = await _localModelPath();
        debugPrint('[Gemma] model path: $modelPath');

        if (_isDownloadComplete(modelPath)) {
          debugPrint('[Gemma] model already on disk (complete), skipping download');
          onProgress?.call(100);
        } else {
          await _cleanPartial(modelPath);
          debugPrint('[Gemma] downloading model…');
          final sw = Stopwatch()..start();
          await _downloadModel(url: _modelUrl, savePath: modelPath, token: _hfToken, onProgress: onProgress);
          debugPrint('[Gemma] download complete in ${sw.elapsed}');
        }
      }

      // Register with flutter_gemma — fromFile records metadata only, no copy.
      debugPrint('[Gemma] registering model…');
      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromFile(modelPath).install();

      final backend = _useGpu ? PreferredBackend.gpu : PreferredBackend.cpu;
      debugPrint('[Gemma] loading model (backend=${backend.name}, maxTokens=$_maxTokens, vision=true)…');
      final swLoad = Stopwatch()..start();
      _model = await FlutterGemma.getActiveModel(maxTokens: _maxTokens, preferredBackend: backend, supportImage: false);
      debugPrint('[Gemma] model ready — load time: ${swLoad.elapsed}');
    } catch (_) {
      _initializing = false;
      rethrow;
    }
  }

  /// Streams response tokens for [prompt], with optional [imagePath] for vision.
  /// The image file is deleted from disk once Gemma has read the bytes.
  Stream<String> generate(String prompt, {String? imagePath}) async* {
    final model = _model;
    if (model == null) throw StateError('GemmaService.initialize() not called');

    debugPrint('[Gemma] creating session (vision=${imagePath != null})…');
    final session = await model.createSession();

    try {
      final Message message;
      if (imagePath != null) {
        final bytes = await File(imagePath).readAsBytes();
        message = Message.withImage(text: prompt, imageBytes: bytes, isUser: true);
        // Free disk space immediately — bytes are now in the native engine.
        await File(imagePath).delete().catchError((Object _) => File(imagePath));
        debugPrint('[Gemma] image loaded — ${bytes.lengthInBytes} bytes');
      } else {
        message = Message.text(text: prompt, isUser: true);
      }
      await session.addQueryChunk(message);

      int tokenCount = 0;
      bool firstToken = true;
      final swFirst = Stopwatch()..start();
      final swTotal = Stopwatch()..start();

      await for (final token in session.getResponseAsync()) {
        if (firstToken) {
          debugPrint('[Gemma] time to first token: ${swFirst.elapsed}');
          firstToken = false;
        }
        tokenCount++;
        yield token;
      }

      debugPrint(
        '[Gemma] done — $tokenCount tokens in ${swTotal.elapsed} '
        '(${(tokenCount / swTotal.elapsed.inMilliseconds * 1000).toStringAsFixed(1)} tok/s)',
      );
    } finally {
      await session.close();
    }
  }

  Future<void> dispose() async {
    await _model?.close();
    _model = null;
    _initializing = false;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static Future<String> _localModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_modelFilename';
  }

  /// Marker written next to the model file only after a successful download.
  /// Its presence means the model file is complete and safe to load.
  static String _markerPath(String modelPath) => '$modelPath.complete';

  static bool _isDownloadComplete(String modelPath) =>
      File(modelPath).existsSync() && File(_markerPath(modelPath)).existsSync();

  static Future<void> _cleanPartial(String modelPath) async {
    for (final path in [modelPath, _markerPath(modelPath)]) {
      final f = File(path);
      if (f.existsSync()) await f.delete().catchError((_) => f);
    }
  }

  /// Downloads [url] to [savePath] using dart:io HttpClient.
  /// No WorkManager, no foreground service — runs in Dart's main isolate,
  /// immune to Android's background task timeout.
  static Future<void> _downloadModel({
    required String url,
    required String savePath,
    required String token,
    DownloadProgressCallback? onProgress,
  }) async {
    final file = File(savePath);
    HttpClient? client;
    IOSink? sink;

    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 30);

      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Connection', 'keep-alive');

      final response = await request.close();

      switch (response.statusCode) {
        case 401:
          throw Exception(
            'HuggingFace token rejected (401). '
            'Ensure your token has Read access to the model repo.',
          );
        case 403:
          throw Exception(
            'Access denied (403). Accept the model licence at '
            'huggingface.co/litert-community/gemma-4-E4B-it-litert-lm',
          );
        case 404:
          throw Exception('Model file not found (404). Check the URL.');
        default:
          if (response.statusCode != 200) {
            throw Exception('Download failed: HTTP ${response.statusCode}');
          }
      }

      final contentLength = response.contentLength; // -1 if server omits it
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
            debugPrint('[Gemma] download $pct%');
            onProgress?.call(pct);
          }
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Write completion marker — only reached if stream finished without error.
      await File(_markerPath(savePath)).writeAsString('ok');

      onProgress?.call(100);
      debugPrint(
        '[Gemma] download finished — '
        '${(received / 1024 / 1024).toStringAsFixed(1)} MB',
      );
    } catch (e) {
      await sink?.close().catchError((_) {});
      // Delete both the partial model and any stale marker.
      await _cleanPartial(savePath);
      rethrow;
    } finally {
      client?.close(force: true);
    }
  }
}
