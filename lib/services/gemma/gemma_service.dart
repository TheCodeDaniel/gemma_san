import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/core/parsing/sdk_response_parser.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/memory_dao.dart';
import '../illustration/illustration_registry.dart';
import 'tool_definitions.dart';
import 'tutor_response.dart';

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

const _maxTokens = 2048;
const _maxTurns = 6; // 3 full exchanges kept in working memory

typedef DownloadProgressCallback = void Function(int percent);

typedef _Turn = ({String role, String text});

class GemmaService {
  InferenceModel? _model;
  bool _initializing = false;

  // ── Working memory ─────────────────────────────────────────────────────────
  final List<_Turn> _turns = [];
  MemoryDao? _memoryDao;
  String? _sessionId;
  String _childId = 'default';
  String _injectedMemory = '';

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
      debugPrint('[Gemma] loading model (backend=${backend.name}, maxTokens=$_maxTokens, vision=false)…');
      final swLoad = Stopwatch()..start();
      _model = await FlutterGemma.getActiveModel(maxTokens: _maxTokens, preferredBackend: backend, supportImage: false);
      debugPrint('[Gemma] model ready — load time: ${swLoad.elapsed}');
    } catch (_) {
      _initializing = false;
      rethrow;
    }
  }

  // ── Session lifecycle ──────────────────────────────────────────────────────

  /// Call when the child opens a conversation. Creates a DB session row and
  /// loads memory context for injection into subsequent generate() calls.
  Future<void> startSession(String childId, Database db) async {
    if (_sessionId != null) await endSession();

    _childId = childId;
    _memoryDao = MemoryDao(db);
    _sessionId = await _memoryDao!.createSession(childId);
    _turns.clear();
    _injectedMemory = await _buildMemoryContext(childId);
    debugPrint('[Memory] session started: $_sessionId, context=${_injectedMemory.length} chars');
  }

  /// Call when the child closes the conversation. Serializes the session turns
  /// as a compact summary and saves to DB for future injection.
  ///
  /// NOTE: InferenceModel is a native FFI object and cannot cross isolate
  /// boundaries. Compaction is pure-Dart JSON serialisation — no model call.
  Future<void> endSession() async {
    final sessionId = _sessionId;
    final dao = _memoryDao;
    if (sessionId == null || dao == null) return;

    final summary = _compactSession();
    await dao.closeSession(
      sessionId: sessionId,
      endedAt: DateTime.now().millisecondsSinceEpoch,
      turnCount: _turns.length,
      summaryJson: summary,
    );
    debugPrint('[Memory] session $sessionId closed — turns=${_turns.length} summary=$summary');

    _turns.clear();
    _sessionId = null;
    _memoryDao = null;
    _injectedMemory = '';
    _childId = 'default';
  }

  // ── Generate ───────────────────────────────────────────────────────────────

  Stream<TutorResponse> generate(String prompt) async* {
    final model = _model;
    if (model == null) throw StateError('GemmaService.initialize() not called');

    _addTurn(role: 'user', text: prompt);
    final fullPrompt = _buildPromptWithContext(prompt);

    debugPrint('[Gemma] creating session (tools=${kGemmaTools.length})…');
    final session = await model.createSession(tools: kGemmaTools, systemInstruction: kSystemPrompt);

    try {
      await session.addQueryChunk(Message.text(text: fullPrompt, isUser: true));

      final sw = Stopwatch()..start();
      await session.getResponse();
      debugPrint('[Gemma] response in ${sw.elapsed}');

      final raw = session is RawSdkResponseSession ? session.lastRawResponse : null;
      debugPrint('[Gemma] raw response: $raw');

      final calls = raw != null ? SdkResponseParser.extractToolCalls(raw) : <FunctionCallResponse>[];

      if (calls.isNotEmpty) {
        final call = calls.first;
        debugPrint('[Gemma] tool call: ${call.name} args=${call.args}');

        final spokenText = (call.args['spoken_response'] as String?) ?? '';
        final langCode = call.args['language_code'] as String?;

        if (call.name == 'show_illustration') {
          final topicId = (call.args['topic_id'] as String?) ?? '';
          // Validate against registry — Gemma may hallucinate a value outside the enum.
          final resolvedId = IllustrationRegistry.hasIllustration(topicId) ? topicId : null;
          debugPrint('[Illustration] topic=$topicId resolved=$resolvedId');
          _addTurn(role: 'assistant', text: spokenText);
          yield TutorResponse(
            mode: TutorMode.direct,
            spokenText: spokenText,
            languageCode: langCode,
            illustrationTopicId: resolvedId,
            metadata: call.args,
          );
        } else if (call.name == 'remember') {
          final fact = (call.args['fact'] as String?) ?? '';
          if (fact.isNotEmpty) {
            final key = 'fact_${DateTime.now().millisecondsSinceEpoch}';
            await _memoryDao?.saveFact(_childId, key, fact);
            debugPrint('[Memory] saveFact key=$key value=$fact');
          }
          _addTurn(role: 'assistant', text: spokenText);
          yield TutorResponse(mode: TutorMode.direct, spokenText: spokenText, languageCode: langCode, metadata: call.args);
        } else {
          final mode = switch (call.name) {
            'socratic_teach' => TutorMode.socratic,
            'direct_teach' => TutorMode.direct,
            'encourage' => TutorMode.encourage,
            _ => TutorMode.direct,
          };
          _addTurn(role: 'assistant', text: spokenText);
          yield TutorResponse(mode: mode, spokenText: spokenText, languageCode: langCode, metadata: call.args);
        }
      } else {
        // Fallback: model replied with plain text instead of a tool call.
        final text = raw != null ? _extractPlainText(raw) : '';
        debugPrint('[Gemma] no tool call — falling back to direct');
        final spokenText = text.isNotEmpty ? text : 'E get small wahala, try again.';
        _addTurn(role: 'assistant', text: spokenText);
        yield TutorResponse(mode: TutorMode.direct, spokenText: spokenText);
      }
    } finally {
      await session.close();
    }
  }

  Future<void> dispose() async {
    await endSession();
    await _model?.close();
    _model = null;
    _initializing = false;
  }

  // ── Private: working memory ────────────────────────────────────────────────

  void _addTurn({required String role, required String text}) {
    _turns.add((role: role, text: text));
    if (_turns.length > _maxTurns) _turns.removeAt(0);
  }

  String _buildPromptWithContext(String currentPrompt) {
    final buf = StringBuffer();

    if (_injectedMemory.isNotEmpty) {
      buf.writeln(_injectedMemory);
      buf.writeln();
    }

    // Include prior turns (all but the user turn we just added).
    final priorTurns = _turns.length > 1 ? _turns.sublist(0, _turns.length - 1) : <_Turn>[];
    if (priorTurns.isNotEmpty) {
      buf.writeln('[Recent conversation:]');
      for (final t in priorTurns) {
        final label = t.role == 'user' ? 'Child' : 'Gemma-San';
        buf.writeln('$label: ${t.text}');
      }
      buf.writeln();
    }

    buf.write(currentPrompt);
    return buf.toString();
  }

  /// Pure-Dart compaction — serialises user turns for cross-session injection.
  String _compactSession() {
    final userTurns = _turns
        .where((t) => t.role == 'user')
        .map((t) => t.text)
        .take(5)
        .toList();
    return jsonEncode({'user_turns': userTurns, 'turn_count': _turns.length});
  }

  Future<String> _buildMemoryContext(String childId) async {
    final dao = _memoryDao;
    if (dao == null) return '';
    final facts = await dao.allFacts(childId);
    final sessions = await dao.recentSessions(childId, limit: 3);
    return MemoryDao.buildMemoryContext(facts, sessions);
  }

  // ── Private: model download & loading ─────────────────────────────────────

  static String _extractPlainText(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final content = json['content'] as List?;
      if (content == null) return raw;
      final buf = StringBuffer();
      for (final item in content) {
        if (item is Map && item['type'] == 'text') buf.write(item['text'] ?? '');
      }
      return buf.toString();
    } catch (_) {
      return raw;
    }
  }

  static Future<String> _localModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_modelFilename';
  }

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
            debugPrint('[Gemma] download $pct%');
            onProgress?.call(pct);
          }
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      await File(_markerPath(savePath)).writeAsString('ok');
      onProgress?.call(100);
      debugPrint('[Gemma] download finished — ${(received / 1024 / 1024).toStringAsFixed(1)} MB');
    } catch (e) {
      await sink?.close().catchError((_) {});
      await _cleanPartial(savePath);
      rethrow;
    } finally {
      client?.close(force: true);
    }
  }
}
