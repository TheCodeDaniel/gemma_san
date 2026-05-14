enum TutorMode { socratic, direct, encourage, quiz }

class TutorResponse {
  const TutorResponse({
    required this.mode,
    required this.spokenText,
    this.languageCode,
    this.illustrationTopicId,
    this.tryDrawingSvg,
    this.tryDrawingTopic,
    this.metadata = const {},
  });

  final TutorMode mode;
  final String spokenText;

  /// BCP-47 language tag from the model (e.g. 'en', 'ha', 'yo', 'ig').
  /// Null means unknown — TTS will keep its current language.
  final String? languageCode;

  /// If set, the conversation UI should render the matching pre-built SVG inline.
  final String? illustrationTopicId;

  /// If set, the conversation UI should render an experimentally generated SVG.
  /// Already validated by SvgValidator — safe to render directly.
  final String? tryDrawingSvg;

  /// Display name of the drawn topic (e.g. "traffic light").
  final String? tryDrawingTopic;

  final Map<String, dynamic> metadata;
}
