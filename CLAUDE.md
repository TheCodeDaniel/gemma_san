# Gemma-San — CLAUDE.md

## Project Overview

Gemma-San is an offline AI tutor for African children (ages 5–12), running Google's Gemma 4 E2B model entirely on-device via flutter_gemma. It supports voice input (whisper.cpp), voice output (Android system TTS), and a three-tier memory system that compacts automatically in the background. The app targets low-to-mid-range Android phones and must work fully offline after the one-time model download. This is a hackathon submission due May 18, 2026.

---

## Tech Stack

| Layer            | Technology                                                                                    |
| ---------------- | --------------------------------------------------------------------------------------------- |
| UI framework     | Flutter (Android only, minSdk 26)                                                             |
| On-device LLM    | `flutter_gemma ^0.14.1` — Gemma 4 E2B via `ModelType.gemma4`, native function calling enabled |
| STT              | whisper.cpp (via FFI wrapper in `lib/services/stt/`)                                          |
| TTS              | Android system TTS (`flutter_tts` as fallback)                                                |
| Local storage    | `sqflite` — chat history, memory, user profile                                                |
| Animations       | `lottie`                                                                                      |
| State management | `flutter_riverpod`                                                                            |
| Background work  | Dart `Isolate` — anything expected to take >100ms                                             |
| Permissions      | `permission_handler`                                                                          |
| Audio capture    | `record`                                                                                      |
| File management  | `path_provider`                                                                               |

---

## Gemma Tool Functions

Gemma uses native function calling. The v1 tools are:

| Tool                | Purpose                                                                        |
| ------------------- | ------------------------------------------------------------------------------ |
| `socratic_teach`    | Ask a leading question to guide the child toward the answer                    |
| `direct_teach`      | Explain a concept clearly and directly                                         |
| `encourage`         | Deliver a warm, culturally-appropriate encouragement message                   |
| `show_illustration` | Render an illustration (Lottie or static image) relevant to the topic          |
| `start_practice`    | Begin a phonics or arithmetic drilling loop                                    |
| `remember`          | Write a fact about the child (name, progress, preferences) to the memory store |
| `recall`            | Read from the memory store to personalize a response                           |

All tool definitions live in `lib/services/gemma/tool_definitions.dart`.

---

## Folder Structure

```
lib/
  core/             # Theme, constants, shared utilities
  data/
    repositories/   # sqflite-backed data access
  domain/
    entities/       # Pure Dart data classes
    use_cases/      # Business logic, no Flutter deps
  features/
    onboarding/     # Avatar picker, age selector, permissions flow
    conversation/   # Voice in → Gemma → voice out main loop
    camera/         # Photo capture + multimodal flow + annotations
    practice/       # Phonics drilling loop
    memory/         # Three-tier memory + auto-compaction isolate
    history/        # Topic-organized chat history browser
  services/
    gemma/          # flutter_gemma wrapper + tool definitions
    stt/            # whisper.cpp FFI wrapper
    tts/            # Android TTS wrapper
    storage/        # Model file management in external storage
```

Each feature folder follows this internal layout (add as needed):

```
features/<name>/
  data/             # feature-local data sources
  domain/           # feature-local use cases / entities
  presentation/
    pages/
    widgets/
    providers/      # Riverpod providers scoped to this feature
```

---

## Coding Standards

- **Architecture**: Clean Architecture. UI widgets contain zero business logic.
- **State**: Riverpod only. No `setState` outside of truly local ephemeral UI state.
- **Isolates**: Any operation expected to take >100ms must run in a Dart `Isolate` or `compute()`.
- **Comments**: Only where the _why_ is non-obvious. No inline narration of what the code does.
- **Imports**: Relative imports within a feature; package imports across features.
- **No premature abstractions**: Three similar lines is fine. Extract only when a fourth would appear.

---

## Critical Constraints

- **Fully offline** after the one-time Hugging Face model download on first launch.
- **Target device**: 4–6 GB RAM Android phones (e.g., Tecno Spark 10, Infinix Hot 30).
- **First-audio latency**: ≤1.5 s from end of child's speech to start of TTS output.
- **Model**: Gemma 4 E2B only. No cloud API calls during tutoring sessions.
- **minSdkVersion**: 26 (Android 8.0).

---

## Known Limitations (v1)

- **Vision / camera**: Blocked by `libLiteRtLm.so` rejecting Gemma 4's 3-subgraph vision encoder ("must have exactly one signature but got 3"). Not patchable client-side — fix requires Google to update the native binary. Camera/multimodal deferred to v2.

---

## Build State Log

| Day | Goal                                                            | Status                                                                                                       |
| --- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| 1   | LM Studio validation: Pidgin quality, function calling, SVG gen | Done — Pidgin ✅, function calling ✅, SVG dropped from scope                                                |
| 2   | Scaffold, flutter_gemma installed, HF model access verified     | Done                                                                                                         |
| 3   | GemmaService: GPU backend, DEV_MODEL_PATH shortcut, HF download | Done                                                                                                         |
| 4   | STT: Whisper tiny via whisper_flutter_new, WAV recording        | Done — tiny model avoids OOM alongside Gemma 4B                                                              |
| 5   | TTS: sentence-streaming via flutter_tts, interruption support   | Done — speech starts at first sentence boundary, ~1–2s                                                       |
| 6   | Camera/image UI, gallery picker, vision spike                   | Done — vision blocked by libLiteRtLm.so (Gemma 4 has 3-subgraph encoder; LiteRT requires 1). Deferred to v2. |
| 7   | Tool-call mode signaling: 3 tools, system prompt, TutorResponse | Done — socratic/direct/encourage, mode pill on diagnostic screen                                             |
| 8   | Practice mode: phonics drilling loop, fuzzy STT eval, 5 levels  | Done                                                                                                         |
| 9   | Adaptive practice: SRS scheduler, SQLite persistence, session stats | Done                                                                                                     |
| 10  | Conversation feature                                            | Upcoming                                                                                                     |

---

## Key Commands

```bash
# Get dependencies
flutter pub get

# Analyze (must be zero errors before any PR)
flutter analyze

# Run on connected Android device (no emulator — Gemma needs GPU)
flutter run

# Build release APK
flutter build apk --release
```
