import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

// E4B model (4B effective params). Swap to an E2B URL if RAM is tight on target devices.
const _modelUrl =
    'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/'
    'resolve/main/gemma-4-E4B-it.litertlm';

// Set at build time: flutter run --dart-define=HF_TOKEN=hf_xxx
// Or via .vscode/launch.json (see project root).
const _hfToken = String.fromEnvironment('HF_TOKEN');

typedef DownloadProgressCallback = void Function(int percent);

class GemmaService {
  InferenceModel? _model;
  bool _initializing = false;

  bool get isReady => _model != null;

  /// Idempotent. Downloads model on first call (shows progress), loads it, then resolves.
  Future<void> initialize({DownloadProgressCallback? onProgress}) async {
    if (isReady || _initializing) return;
    _initializing = true;

    if (_hfToken.isEmpty) {
      _initializing = false;
      throw StateError(
        'HF_TOKEN is empty. Build with: flutter run --dart-define=HF_TOKEN=hf_xxx',
      );
    }

    try {
      debugPrint('[Gemma] initializing SDK…');
      await FlutterGemma.initialize(huggingFaceToken: _hfToken);

      debugPrint('[Gemma] installing model (skipped if cached):\n  $_modelUrl');
      final swInstall = Stopwatch()..start();

      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      )
          .fromNetwork(_modelUrl, token: _hfToken)
          .withProgress((p) {
            debugPrint('[Gemma] download $p%');
            onProgress?.call(p);
          })
          .install();

      debugPrint('[Gemma] install/cache done in ${swInstall.elapsed}');

      debugPrint('[Gemma] loading model into memory…');
      final swLoad = Stopwatch()..start();
      _model = await FlutterGemma.getActiveModel(maxTokens: 2048);
      debugPrint('[Gemma] model ready — load time: ${swLoad.elapsed}');
    } catch (_) {
      _initializing = false;
      rethrow;
    }
  }

  /// Streams response tokens for [prompt]. Creates and closes a fresh session per call.
  Stream<String> generate(String prompt) async* {
    final model = _model;
    if (model == null) throw StateError('GemmaService.initialize() not called');

    debugPrint('[Gemma] creating session…');
    final session = await model.createSession();

    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));

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
}
