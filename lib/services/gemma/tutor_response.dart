enum TutorMode { socratic, direct, encourage }

class TutorResponse {
  const TutorResponse({
    required this.mode,
    required this.spokenText,
    this.metadata = const {},
  });

  final TutorMode mode;
  final String spokenText;
  final Map<String, dynamic> metadata;
}
