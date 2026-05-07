import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final _tts = FlutterTts();
  final _queue = Queue<String>();
  final _speakingController = StreamController<bool>.broadcast();

  bool _ready = false;
  bool _stopped = false;
  bool _processingQueue = false;
  Completer<void>? _utteranceCompleter;

  /// Emits true when speech starts, false when the queue drains or is stopped.
  Stream<bool> get speakingStream => _speakingController.stream;

  bool get isReady => _ready;

  Future<void> initialize() async {
    if (_ready) return;

    // Prefer Nigerian English accent; fall back to US English.
    final langOk = await _tts.setLanguage('en-NG');
    if (langOk != 1) await _tts.setLanguage('en-US');

    await _tts.setSpeechRate(0.48); // slightly slower for children
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);

    _tts.setCompletionHandler(_onUtteranceDone);
    _tts.setCancelHandler(_onUtteranceDone);
    _tts.setErrorHandler((_) => _onUtteranceDone());

    _ready = true;
    debugPrint('[TTS] ready');
  }

  /// Adds [sentence] to the speak queue. Starts the worker if idle.
  void enqueue(String sentence) {
    final s = sentence.trim();
    if (!_ready || s.isEmpty) return;
    _queue.add(s);
    if (!_processingQueue) _startQueue();
  }

  /// Immediately stops playback and clears the queue.
  Future<void> stop() async {
    _stopped = true;
    _queue.clear();
    // Resolve any pending await so the worker loop can exit.
    _utteranceCompleter?.complete();
    _utteranceCompleter = null;
    await _tts.stop();
    _processingQueue = false;
    _stopped = false;
    if (!_speakingController.isClosed) _speakingController.add(false);
  }

  Future<void> dispose() async {
    await stop();
    await _speakingController.close();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _onUtteranceDone() {
    _utteranceCompleter?.complete();
    _utteranceCompleter = null;
  }

  Future<void> _startQueue() async {
    _processingQueue = true;
    _speakingController.add(true);

    while (_queue.isNotEmpty && !_stopped) {
      final sentence = _queue.removeFirst();
      try {
        _utteranceCompleter = Completer<void>();
        await _tts.speak(sentence);
        // Wait for the completion/cancel/error handler to fire.
        await _utteranceCompleter!.future;
      } catch (_) {
        _utteranceCompleter = null;
      }
    }

    // Only emit idle if stop() didn't already do it.
    if (!_stopped) {
      _processingQueue = false;
      if (!_speakingController.isClosed) _speakingController.add(false);
    }
  }
}
