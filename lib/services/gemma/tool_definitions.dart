import 'package:flutter_gemma/flutter_gemma.dart';

const kSystemPrompt = '''
You are Gemma-San, a warm and patient tutor for children across Africa.

Always reply in the same language the child used.
Set language_code to the BCP-47 code of the language you used (e.g. en, ha, yo, ig, sw, fr, am, zu, pcm).

You MUST call exactly one function in every reply — never reply with plain text.

Rules:
- Call socratic_teach when the child is working through a concept step by step. Use stage=probe to explore what they know, stage=build to deepen understanding, stage=resolve to confirm they got it.
- Call direct_teach when the child asks a direct factual question, or says they don't know twice in a row.
- Call encourage when the child is tired, frustrated, or struggling emotionally.

Keep spoken_response short: 4–6 sentences for teaching, 1–2 sentences for encourage.
''';

const _languageCodeParam = {
  'language_code': {
    'type': 'string',
    'description': 'BCP-47 code of the language used in spoken_response (e.g. en, ha, yo, ig, sw, fr, am, zu, pcm).',
  },
};

const kGemmaTools = [
  Tool(
    name: 'socratic_teach',
    description: 'Guide the child to discover the answer themselves through questions.',
    parameters: {
      'type': 'object',
      'properties': {
        'spoken_response': {
          'type': 'string',
          'description': 'What to say out loud — a guiding question or hint, in the child\'s language.',
        },
        'stage': {
          'type': 'string',
          'enum': ['probe', 'build', 'resolve'],
          'description': 'probe: explore prior knowledge. build: deepen understanding. resolve: confirm understanding.',
        },
        'target_concept': {'type': 'string', 'description': 'The concept being taught this turn.'},
        'next_concept_step': {'type': 'string', 'description': 'The micro-step towards the concept to reach next.'},
        ..._languageCodeParam,
      },
      'required': ['spoken_response', 'stage', 'target_concept', 'next_concept_step', 'language_code'],
    },
  ),
  Tool(
    name: 'direct_teach',
    description: 'Give a clear direct explanation for factual questions or when the child is stuck.',
    parameters: {
      'type': 'object',
      'properties': {
        'spoken_response': {'type': 'string', 'description': 'Clear explanation in the child\'s language.'},
        'follow_up_check': {'type': 'string', 'description': 'A simple question to check the child understood.'},
        ..._languageCodeParam,
      },
      'required': ['spoken_response', 'follow_up_check', 'language_code'],
    },
  ),
  Tool(
    name: 'encourage',
    description: 'Warm brief encouragement when the child is struggling or emotionally discouraged.',
    parameters: {
      'type': 'object',
      'properties': {
        'spoken_response': {
          'type': 'string',
          'description': 'Short warm encouragement in the child\'s language (1–2 sentences).',
        },
        ..._languageCodeParam,
      },
      'required': ['spoken_response', 'language_code'],
    },
  ),
];
