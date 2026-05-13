enum TutorMode { socratic, direct, encourage, quiz }

class TutorResponse {
  const TutorResponse({
    required this.mode,
    required this.spokenText,
    this.languageCode,
    this.illustrationTopicId,
    this.metadata = const {},
  });

  final TutorMode mode;
  final String spokenText;

  /// BCP-47 language tag from the model (e.g. 'en', 'ha', 'yo', 'ig').
  /// Null means unknown — TTS will keep its current language.
  final String? languageCode;

  /// If set, the conversation UI should render the matching SVG inline.
  /// Null means no illustration for this response.
  final String? illustrationTopicId;
  final Map<String, dynamic> metadata;
}
