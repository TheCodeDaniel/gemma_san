import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

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
  late String _deviceCountry;

  Stream<bool> get speakingStream => _speakingController.stream;

  bool get isReady => _ready;

  Future<void> initialize() async {
    if (_ready) return;

    _deviceCountry = ui.PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? 'NG';
    debugPrint('[TTS] device country: $_deviceCountry');

    await _setTtsLanguage('en');

    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);

    _tts.setCompletionHandler(_onUtteranceDone);
    _tts.setCancelHandler(_onUtteranceDone);
    _tts.setErrorHandler((_) => _onUtteranceDone());

    _ready = true;
    debugPrint('[TTS] ready');
  }

  /// Called after each Gemma response with the BCP-47 language code the model used.
  /// Switches TTS voice to the best available match for that language + device country.
  Future<void> setResponseLanguage(String langCode) async {
    if (!_ready) return;
    await _setTtsLanguage(langCode);
  }

  void enqueue(String sentence) {
    final s = sentence.trim();
    if (!_ready || s.isEmpty) return;
    _queue.add(s);
    if (!_processingQueue) _startQueue();
  }

  Future<void> stop() async {
    _stopped = true;
    _queue.clear();
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

  /// Tries language variants in priority order; stops at the first that succeeds.
  Future<void> _setTtsLanguage(String langCode) async {
    final candidates = [
      '$langCode-$_deviceCountry', // e.g. en-NG, ha-NG
      langCode, // e.g. en, ha
      'en-$_deviceCountry', // en-NG fallback
      'en-US', // last resort
    ];
    for (final lang in candidates) {
      if (await _tts.setLanguage(lang) == 1) {
        debugPrint('[TTS] language → $lang');
        return;
      }
    }
  }

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
        await _utteranceCompleter!.future;
      } catch (_) {
        _utteranceCompleter = null;
      }
    }

    if (!_stopped) {
      _processingQueue = false;
      if (!_speakingController.isClosed) _speakingController.add(false);
    }
  }
}
