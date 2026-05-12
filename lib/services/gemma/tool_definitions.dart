import 'package:flutter_gemma/flutter_gemma.dart';

import '../illustration/illustration_registry.dart';

const kSystemPrompt = '''
You are Gemma-San, a warm and patient AI tutor for children.

Always reply in the same language the child used.
Set language_code to the BCP-47 code of the language you used (e.g. en, ha, yo, ig, sw, fr, am, zu, pcm).

You MUST call exactly one function in every reply — never reply with plain text.

Rules:
- Call socratic_teach when the child is working through a concept step by step. Use stage=probe to explore what they know, stage=build to deepen understanding, stage=resolve to confirm they got it.
- Call direct_teach when the child asks a direct factual question, or says they don't know twice in a row. Set subject to a short noun phrase naming the topic (e.g. "photosynthesis", "fractions").
- Call encourage when the child is tired, frustrated, or struggling emotionally.
- Call remember when the child tells you their name, age, hobby, family members, or any personal fact worth keeping across sessions. Store the fact and give a friendly spoken reply.
- Call show_illustration when the child asks about a topic that exactly matches one of the available illustration IDs. The illustration will appear on screen alongside your spoken response.

Keep spoken_response short: 4–6 sentences for teaching, 1–2 sentences for encourage and remember.

If memory context appears in square brackets at the start of the message, use it naturally to personalise your reply — do not repeat it back verbatim.
''';

const _languageCodeParam = {
  'language_code': {
    'type': 'string',
    'description': 'BCP-47 code of the language used in spoken_response (e.g. en, ha, yo, ig, sw, fr, am, zu, pcm).',
  },
};

// Not `const` — show_illustration description embeds a runtime-built topic list.
final kGemmaTools = [
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
        'subject': {
          'type': 'string',
          'description':
              'The main topic or concept being explained — a short noun phrase (e.g. "photosynthesis", "water cycle", "addition").',
        },
        'spoken_response': {'type': 'string', 'description': 'Clear explanation in the child\'s language.'},
        'follow_up_check': {'type': 'string', 'description': 'A simple question to check the child understood.'},
        ..._languageCodeParam,
      },
      'required': ['subject', 'spoken_response', 'follow_up_check', 'language_code'],
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
  Tool(
    name: 'remember',
    description: 'Store a personal fact about the child to recall in future sessions.',
    parameters: {
      'type': 'object',
      'properties': {
        'fact': {
          'type': 'string',
          'description':
              'The fact to remember, phrased as a statement (e.g. "child likes football", "child\'s name is Amara", "child is 8 years old").',
        },
        'spoken_response': {
          'type': 'string',
          'description': 'Warm acknowledgement to say out loud to the child (1–2 sentences).',
        },
        ..._languageCodeParam,
      },
      'required': ['fact', 'spoken_response', 'language_code'],
    },
  ),
  Tool(
    name: 'show_illustration',
    description:
        'Display a pre-built illustration alongside a spoken explanation. '
        'ONLY call this when the child asks about one of these exact topic IDs — '
        'do not guess or approximate: ${IllustrationRegistry.allTopicIds.join(", ")}.',
    parameters: {
      'type': 'object',
      'properties': {
        'topic_id': {
          'type': 'string',
          'enum': IllustrationRegistry.allTopicIds,
          'description': 'Exact topic ID from the allowed list.',
        },
        'spoken_response': {
          'type': 'string',
          'description': 'Explanation to say out loud alongside the illustration (4–6 sentences).',
        },
        ..._languageCodeParam,
      },
      'required': ['topic_id', 'spoken_response', 'language_code'],
    },
  ),
];
