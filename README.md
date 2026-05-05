# Gemma-San

> Offline AI tutor for Nigerian children, powered by Gemma 4 on-device.

Hackathon submission — deadline May 18, 2026.

---

## What It Is

Gemma-San is a native Android app that acts as a patient, voice-first tutor for Nigerian children aged 5–12. It runs Google's Gemma 4 E2B model entirely on-device using flutter_gemma, so it works in classrooms with no internet after the initial model download. The tutor speaks in Nigerian Pidgin or English, uses the phone camera to annotate physical objects, and adapts to each child via a local memory system.

---

## Why

Millions of Nigerian children lack access to quality, personalized tutoring. Gemma-San brings Socratic and direct-teach pedagogy to a $100 Android phone, offline, in the child's own language.

---

## Architecture

```
┌─────────────────────────────────────────────┐
│                Flutter UI                   │
│  (Riverpod state, feature-first widgets)    │
└────────────────────┬────────────────────────┘
                     │
        ┌────────────▼────────────┐
        │     Domain / Use Cases  │
        └────────────┬────────────┘
                     │
   ┌─────────────────┼──────────────────┐
   │                 │                  │
┌──▼──┐         ┌────▼────┐       ┌────▼────┐
│sqflite│       │flutter_ │       │whisper  │
│memory│        │ gemma   │       │.cpp STT │
│store │        │(Gemma 4)│       │+ TTS    │
└──────┘        └─────────┘       └─────────┘
```

*(Full architecture diagram — TODO: add Mermaid or image)*

---

## Build Instructions

### Prerequisites

- Flutter 3.32+ with Dart 3.11+
- Android SDK, minSdkVersion 26
- A physical Android device with 4+ GB RAM (emulator won't run Gemma)
- Hugging Face account with access to `google/gemma-4-e2b`

### Setup

```bash
# 1. Install dependencies
flutter pub get

# 2. Connect your Android device and verify
flutter devices

# 3. Run (debug)
flutter run

# 4. On first launch, the app will prompt for model download
#    (~2 GB, requires internet on first run only)
```

### Build release APK

```bash
flutter build apk --release
```

---

## Roadmap

| Day | Goal |
|-----|------|
| 1 | LM Studio validation — Pidgin quality, function calling ✅ |
| 2 | Scaffold + flutter_gemma install + HF model access ← *here* |
| 3–4 | Conversation feature: voice in → Gemma → TTS out |
| 5–6 | Memory system (three-tier + isolate compaction) |
| 7–8 | Camera + annotation flow |
| 9–10 | Practice / phonics drilling loop |
| 11–12 | Onboarding flow (avatar, age, permissions) |
| 13–14 | History browser + polish |
| 15–16 | Performance tuning (latency, RAM) |
| 17 | Final testing on device + submission |

---

## License

MIT
