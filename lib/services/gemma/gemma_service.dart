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
import '../svg/svg_validator.dart';
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

// Dev shortcut: set DEV_MODEL_PATH to an absolute path on the device where you've
// already pushed the model file (e.g. /sdcard/Download/gemma-4-E4B-it.litertlm).
// When set and the file exists, initialize() skips HF download entirely.
// Leave empty (or omit) in production builds.
const _devModelPath = String.fromEnvironment('DEV_MODEL_PATH', defaultValue: '');

const _maxTokens = 4096;
const _maxTurns = 4; // 2 full exchanges kept in working memory

const _summarySystemPrompt =
    'You are a learning assistant. Call the lesson_summary function with '
    'a child-friendly paragraph summary (max 80 words) and 3–5 key concept '
    'sentences. Use simple English a child can understand.';

final _summaryTool = Tool(
  name: 'lesson_summary',
  description: 'Output a structured lesson summary for a child.',
  parameters: {
    'type': 'object',
    'properties': {
      'summary': {
        'type': 'string',
        'description': 'A child-friendly paragraph summary of what was learned (max 80 words).',
      },
      'key_concepts': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': '3–5 key things the child learned, each as a short sentence.',
      },
    },
    'required': ['summary', 'key_concepts'],
  },
);

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
  String? _ageRange;
  String _injectedMemory = '';
  List<Tool>? _sessionTools;
  String? _sessionSystemPrompt;

  bool get isReady => _model != null;

  /// Idempotent. Downloads model on first call using dart:io HttpClient
  /// (bypasses WorkManager to avoid Android's 10-min background task timeout),
  /// then loads it into memory.
  Future<void> initialize({DownloadProgressCallback? onProgress}) async {
    if (isReady || _initializing) return;
    _initializing = true;

    try {
      debugPrint('[Gemma] initializing SDK…');
      final usingLocalModel = _devModelPath.isNotEmpty;
      await FlutterGemma.initialize(huggingFaceToken: usingLocalModel ? '' : _hfToken);

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

      InferenceModel? loadedModel;
      final swLoad = Stopwatch()..start();
      // NPU omitted: standard .litertlm files aren't NPU-compiled; attempting it
      // blocks for ~20 s then fails, triggering ANR on real devices.
      for (final backend in [PreferredBackend.gpu, PreferredBackend.cpu]) {
        try {
          loadedModel = await FlutterGemma.getActiveModel(
            maxTokens: _maxTokens,
            preferredBackend: backend,
            supportImage: true,
          );
          debugPrint('[Gemma] ${backend.name.toUpperCase()} backend active — load: ${swLoad.elapsed}');
          break;
        } catch (e) {
          debugPrint('[Gemma] ${backend.name} unavailable: $e');
        }
      }
      if (loadedModel == null) throw StateError('No inference backend available (tried NPU/GPU/CPU)');
      _model = loadedModel;
    } catch (_) {
      _initializing = false;
      rethrow;
    }
  }

  // ── Session lifecycle ──────────────────────────────────────────────────────

  /// Call when the child opens a conversation. Creates a DB session row and
  /// loads memory context for injection into subsequent generate() calls.
  Future<void> startSession(
    String childId,
    Database db, {
    String? ageRange,
    List<Tool>? toolsOverride,
    String? systemInstructionOverride,
  }) async {
    if (_sessionId != null) await endSession();

    _childId = childId;
    _ageRange = ageRange;
    _sessionTools = toolsOverride;
    _sessionSystemPrompt = systemInstructionOverride;
    _memoryDao = MemoryDao(db);
    await _memoryDao!.closeOrphanedSessions(childId);
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
    _ageRange = null;
    _sessionTools = null;
    _sessionSystemPrompt = null;
  }

  // ── Generate ───────────────────────────────────────────────────────────────

  Stream<TutorResponse> generate(String prompt) async* {
    final model = _model;
    if (model == null) throw StateError('GemmaService.initialize() not called');

    _addTurn(role: 'user', text: prompt);
    final fullPrompt = _buildPromptWithContext(prompt);

    final tools = _sessionTools ?? kGemmaTools;
    final sysPrompt = _sessionSystemPrompt ?? kSystemPrompt;
    debugPrint('[Gemma] creating session (tools=${tools.length})…');
    final session = await model.createSession(tools: tools, systemInstruction: sysPrompt);

    try {
      try {
      await session.addQueryChunk(Message.text(text: fullPrompt, isUser: true));

      final sw = Stopwatch()..start();
      await session.getResponse();
      debugPrint('[Gemma] response in ${sw.elapsed}');

      final raw = session is RawSdkResponseSession ? session.lastRawResponse : null;
      debugPrint('[Gemma] raw response: $raw');

      // Primary path: SDK converts <|tool_call>...<tool_call|> to OpenAI JSON.
      var calls = raw != null ? SdkResponseParser.extractToolCalls(raw) : <FunctionCallResponse>[];

      // Fallback: C library streamed raw Gemma 4 tokens instead of JSON.
      // Parses <|tool_call>call:name{key:<"|>val<"|>,...} directly.
      if (calls.isEmpty && raw != null) {
        calls = _parseRawGemma4Calls(raw);
        if (calls.isNotEmpty) debugPrint('[Gemma] used raw-format fallback parser');
      }

      if (calls.isNotEmpty) {
        final call = calls.first;
        final args = _sanitizeArgs(call.args);
        debugPrint('[Gemma] tool call: ${call.name} args=$args');

        // Auto-detect topic. Only fires until topic is set (updateSessionTopic
        // ignores the call if a topic already exists for this session).
        if (_sessionId != null && _memoryDao != null) {
          final String? detected = switch (call.name) {
            'socratic_teach' => (args['target_concept'] as String?)?.toLowerCase().trim(),
            'direct_teach' => (args['subject'] as String?)?.toLowerCase().trim(),
            'show_illustration' => args['topic_id'] as String?,
            'try_drawing' => (args['topic'] as String?)?.toLowerCase().trim(),
            _ => null,
          };
          if (detected != null && detected.isNotEmpty) {
            await _memoryDao!.updateSessionTopic(_sessionId!, detected);
          }
        }

        final spokenText = _resolveSpokenText(call.name, args);
        final langCode = args['language_code'] as String?;

        if (call.name == 'try_drawing') {
          final topic = (args['topic'] as String?) ?? '';
          final rawSvg = (args['svg_code'] as String?) ?? '';
          final validation = SvgValidator.validate(topic, rawSvg);
          _addTurn(role: 'assistant', text: spokenText);
          yield TutorResponse(
            mode: TutorMode.direct,
            spokenText: spokenText,
            languageCode: langCode,
            tryDrawingSvg: validation.valid ? rawSvg : null,
            tryDrawingTopic: topic,
            metadata: args,
          );
        } else if (call.name == 'show_illustration') {
          final topicId = (args['topic_id'] as String?) ?? '';
          // Validate against registry — Gemma may hallucinate a value outside the enum.
          final resolvedId = IllustrationRegistry.hasIllustration(topicId) ? topicId : null;
          debugPrint('[Illustration] topic=$topicId resolved=$resolvedId');
          _addTurn(role: 'assistant', text: spokenText);
          yield TutorResponse(
            mode: TutorMode.direct,
            spokenText: spokenText,
            languageCode: langCode,
            illustrationTopicId: resolvedId,
            metadata: args,
          );
        } else if (call.name == 'remember') {
          final fact = (args['fact'] as String?) ?? '';
          if (fact.isNotEmpty) {
            final key = 'fact_${DateTime.now().millisecondsSinceEpoch}';
            await _memoryDao?.saveFact(_childId, key, fact);
            debugPrint('[Memory] saveFact key=$key value=$fact');
          }
          _addTurn(role: 'assistant', text: spokenText);
          yield TutorResponse(mode: TutorMode.direct, spokenText: spokenText, languageCode: langCode, metadata: args);
        } else {
          final mode = switch (call.name) {
            'socratic_teach' => TutorMode.socratic,
            'direct_teach' => TutorMode.direct,
            'encourage' => TutorMode.encourage,
            'quiz_question' => TutorMode.quiz,
            _ => TutorMode.direct,
          };
          _addTurn(role: 'assistant', text: spokenText);
          yield TutorResponse(mode: mode, spokenText: spokenText, languageCode: langCode, metadata: args);
        }
      } else {
        // Last resort: salvage spoken_response from truncated/malformed output.
        final salvaged = raw != null ? _salvageSpokenText(raw) : null;
        debugPrint('[Gemma] no tool call — salvaged=${salvaged != null}');
        final spokenText = salvaged ?? 'Something went wrong — please try again.';
        _addTurn(role: 'assistant', text: spokenText);
        yield TutorResponse(mode: TutorMode.direct, spokenText: spokenText);
      }

      // Persist turn data after every response so force-killed sessions survive.
      final sid = _sessionId;
      final dao = _memoryDao;
      if (sid != null && dao != null) {
        await dao.persistTurnProgress(sid, _turns.length, _compactSession());
      }
      } catch (e) {
        if (kDebugMode) debugPrint('[Gemma] generate error: $e');
        _addTurn(role: 'assistant', text: '');
        yield TutorResponse(mode: TutorMode.direct, spokenText: 'Something went wrong — please try again.');
      }
    } finally {
      await session.close();
    }
  }

  // When the upstream flutter_gemma fix lands, flip this to true and uncomment
  // the vision call block inside generateWithImage().
  static const bool _supportsVision = true;

  Stream<TutorResponse> generateWithImage(Uint8List imageBytes, {String query = ''}) async* {
    if (!_supportsVision) {
      debugPrint('[Gemma] Vision not supported — returning fallback');
      yield const TutorResponse(
        spokenText:
            "I can't see pictures clearly yet — coming soon! "
            'For now, tell me what you see and I\'ll help.',
        mode: TutorMode.direct,
      );
      return;
    }

    final model = _model;
    if (model == null) throw StateError('GemmaService.initialize() not called');

    final tools = _sessionTools ?? kGemmaTools;
    final sysPrompt = _sessionSystemPrompt ?? kSystemPrompt;
    debugPrint('[Gemma] createSession for vision…');
    final session = await model.createSession(tools: tools, systemInstruction: sysPrompt);

    try {
      await session.addQueryChunk(
        Message.withImage(
          text: query.isNotEmpty ? query : 'What do you see in this picture?',
          imageBytes: imageBytes,
          isUser: true,
        ),
      );

      final sw = Stopwatch()..start();
      await session.getResponse();
      debugPrint('[Gemma] vision response in ${sw.elapsed}');

      final raw = session is RawSdkResponseSession ? session.lastRawResponse : null;
      debugPrint('[Gemma] vision raw: $raw');

      var calls = raw != null ? SdkResponseParser.extractToolCalls(raw) : <FunctionCallResponse>[];
      if (calls.isEmpty && raw != null) {
        calls = _parseRawGemma4Calls(raw);
        if (calls.isNotEmpty) debugPrint('[Gemma] vision used raw-format fallback parser');
      }

      if (calls.isNotEmpty) {
        final call = calls.first;
        final args = _sanitizeArgs(call.args);
        final spokenText = _resolveSpokenText(call.name, args);
        final langCode = args['language_code'] as String?;
        final mode = switch (call.name) {
          'socratic_teach' => TutorMode.socratic,
          'direct_teach' => TutorMode.direct,
          'encourage' => TutorMode.encourage,
          'quiz_question' => TutorMode.quiz,
          _ => TutorMode.direct,
        };
        _addTurn(role: 'assistant', text: spokenText);
        yield TutorResponse(mode: mode, spokenText: spokenText, languageCode: langCode, metadata: args);
      } else {
        final salvaged = raw != null ? _salvageSpokenText(raw) : null;
        final spokenText = salvaged ?? "I had trouble seeing that picture. Try describing what you see!";
        _addTurn(role: 'assistant', text: spokenText);
        yield TutorResponse(mode: TutorMode.direct, spokenText: spokenText);
      }

      final sid = _sessionId;
      final dao = _memoryDao;
      if (sid != null && dao != null) {
        await dao.persistTurnProgress(sid, _turns.length, _compactSession());
      }
    } catch (e) {
      debugPrint('[Gemma] Vision inference error: $e');
      yield const TutorResponse(
        spokenText: "I had trouble seeing that picture. Try describing what you see!",
        mode: TutorMode.direct,
      );
    } finally {
      await session.close();
    }
  }

  /// Generates a child-friendly lesson summary from past session data for [topic].
  /// Returns a `(summary, concepts)` record. The caller is responsible for caching
  /// the result via [MemoryDao.saveLessonSummary].
  Future<({String summary, List<String> concepts})> generateLessonSummary({
    required String topic,
    required List<String> sessionSummaries,
  }) async {
    final model = _model;
    if (model == null || sessionSummaries.isEmpty) {
      return (summary: 'You have been exploring "$topic". Keep learning!', concepts: <String>[]);
    }

    final prompt =
        'Summarize what this child has learned about "$topic" in simple English. '
        'Session data: ${sessionSummaries.take(5).join('; ')}';

    final session = await model.createSession(tools: [_summaryTool], systemInstruction: _summarySystemPrompt);

    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      await session.getResponse();

      final raw = session is RawSdkResponseSession ? session.lastRawResponse : null;
      if (raw == null) {
        return (summary: 'You have been exploring "$topic"!', concepts: <String>[]);
      }

      final calls = SdkResponseParser.extractToolCalls(raw);
      if (calls.isEmpty) {
        return (summary: _extractPlainText(raw), concepts: <String>[]);
      }

      final args = calls.first.args;
      final summary = (args['summary'] as String?) ?? '';
      final conceptsRaw = args['key_concepts'];
      final concepts = conceptsRaw is List ? conceptsRaw.cast<String>() : <String>[];
      return (summary: summary, concepts: concepts);
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
        // Truncate long assistant responses — they burn ~200-300 tokens each turn.
        final text = (t.role == 'assistant' && t.text.length > 200) ? '${t.text.substring(0, 200)}…' : t.text;
        buf.writeln('$label: $text');
      }
      buf.writeln();
    }

    if (priorTurns.isEmpty) {
      buf.writeln('[FIRST TURN]');
    }
    buf.write(currentPrompt);
    return buf.toString();
  }

  /// Pure-Dart compaction — serialises user turns for cross-session injection.
  String _compactSession() {
    final userTurns = _turns.where((t) => t.role == 'user').map((t) => t.text).take(5).toList();
    return jsonEncode({'user_turns': userTurns, 'turn_count': _turns.length});
  }

  Future<String> _buildMemoryContext(String childId) async {
    final dao = _memoryDao;
    if (dao == null) return '';
    final facts = await dao.allFacts(childId);
    final sessions = await dao.recentSessions(childId, limit: 2);
    final memCtx = MemoryDao.buildMemoryContext(facts, sessions);

    if (_ageRange == null) return memCtx;
    final ageLine = 'Child age group: $_ageRange — adjust vocabulary to this age.';
    if (memCtx.isEmpty) {
      return '[BACKGROUND — context only, do not answer this:\n$ageLine]';
    }
    // Inject age line inside the existing block so the model sees one header.
    return memCtx.replaceFirst(
      '[BACKGROUND — context only, do not answer this:\n',
      '[BACKGROUND — context only, do not answer this:\n$ageLine\n',
    );
  }

  // ── Private: model download & loading ─────────────────────────────────────

  /// New flutter_gemma versions leave Gemma 4 special quote tokens inside JSON
  /// string values (e.g. "<|\"|>en<|\"|>" instead of "en"). Strip them.
  static Map<String, dynamic> _sanitizeArgs(Map<String, dynamic> args) =>
      args.map((k, v) => MapEntry(k, v is String ? v.replaceAll('<|"|>', '').replaceAll('<"|>', '').trim() : v));

  /// Resolve the spoken text from sanitized args, with per-tool fallbacks.
  /// Newer SDK builds may omit spoken_response; this handles all known cases.
  static String _resolveSpokenText(String toolName, Map<String, dynamic> args) {
    if (toolName == 'quiz_question') {
      return (args['spoken_question'] as String? ?? '');
    }

    final primary = args['spoken_response'] as String?;
    if (primary != null && _looksLikeResponse(primary)) return primary;

    if (kDebugMode) debugPrint('[Gemma] spoken_response empty for $toolName — scanning fields');

    if (toolName == 'socratic_teach') {
      // Scan all string fields for one that contains '?' — model sometimes puts
      // the real question in a sibling field (e.g. target_concept on confusion).
      for (final v in args.values) {
        if (v is String && v.contains('?') && _looksLikeResponse(v)) {
          if (kDebugMode) debugPrint('[Gemma] socratic fallback: found question in sibling field');
          return v;
        }
      }
      // Construct a stage-appropriate Socratic question from available metadata.
      final stage = (args['stage'] as String? ?? '');
      final concept = (args['target_concept'] as String? ?? '').trim();
      if (concept.isNotEmpty) {
        return switch (stage) {
          'probe'   => 'What do you already know about $concept?',
          'build'   => 'Good! What else do you think is important about $concept?',
          'narrow'  => 'Let\'s make it simple — can you guess one thing about $concept?',
          'resolve' => 'Can you explain how $concept works in your own words?',
          _         => 'What do you know about $concept?',
        };
      }
      return 'Let me think about that for a moment…';
    }

    return 'Let me think about that for a moment…';
  }

  /// Returns true only when [s] looks like a real natural-language response —
  /// not a serialisation fragment such as `,stage:` or `<|"|>`.
  static bool _looksLikeResponse(String s) {
    if (s.length < 4) return false;
    // Reject obvious serialisation artifacts: comma-prefixed, raw delimiters, etc.
    if (s.startsWith(',') || s.startsWith(':') || s.startsWith('<') || s.startsWith('{')) return false;
    // Reject bare field references like ",stage:" or "stage:"
    if (RegExp(r'^,?\s*\w+:\s*$').hasMatch(s)) return false;
    // Must contain at least a few consecutive letters (real words)
    return RegExp(r'[a-zA-Z]{3,}').hasMatch(s);
  }

  /// Parse the native Gemma 4 token format emitted when the C library does not
  /// convert to OpenAI JSON:
  ///   `<|tool_call>call:funcname{key:<"|>value<"|>,...}<tool_call|>`
  static List<FunctionCallResponse> _parseRawGemma4Calls(String raw) {
    const marker = '<|tool_call>call:';
    final start = raw.indexOf(marker);
    if (start < 0) return const [];

    final rest = raw.substring(start + marker.length);
    final braceIdx = rest.indexOf('{');
    if (braceIdx < 0) return const [];

    final name = rest.substring(0, braceIdx).trim();
    if (name.isEmpty) return const [];

    final argsStr = rest.substring(braceIdx + 1);
    final args = <String, dynamic>{};

    // Matches both delimiter forms: <"|> (4 chars) and <|"|> (5 chars).
    final re = RegExp(r'(\w+):<\|?"?\|?>(.*?)<\|?"?\|?>', dotAll: true);
    for (final m in re.allMatches(argsStr)) {
      args[m.group(1)!] = m.group(2)!;
    }

    if (args.isEmpty) return const [];
    return [FunctionCallResponse(name: name, args: args)];
  }

  /// Extract just the spoken_response value from raw/truncated Gemma 4 output
  /// when full tool-call parsing has already failed.
  static String? _salvageSpokenText(String raw) {
    for (final delim in ['<"|>', '<|"|>']) {
      final key = 'spoken_response:$delim';
      final idx = raw.indexOf(key);
      if (idx < 0) continue;
      final start = idx + key.length;
      final end = raw.indexOf(delim, start);
      final text = end > start
          ? raw.substring(start, end).trim()
          : raw.substring(start).replaceAll(RegExp(r'[,}].*$', dotAll: true), '').trim();
      if (_looksLikeResponse(text)) return text;
    }
    return null;
  }

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
