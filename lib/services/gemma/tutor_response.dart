enum TutorMode { socratic, direct, encourage }

class TutorResponse {
  const TutorResponse({
    required this.mode,
    required this.spokenText,
    this.languageCode,
    this.metadata = const {},
  });

  final TutorMode mode;
  final String spokenText;
  /// BCP-47 language tag from the model (e.g. 'en', 'ha', 'yo', 'ig').
  /// Null means unknown — TTS will keep its current language.
  final String? languageCode;
  final Map<String, dynamic> metadata;
}
