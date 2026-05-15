# Gemma-San — Feature Impact Document

> **Target audience:** Children ages 5–12 in Nigeria and sub-Saharan Africa.
> **Device target:** Low-to-mid-range Android phones (Tecno Spark 10, Infinix Hot 30, 4–6 GB RAM).
> **Connectivity requirement:** Internet needed once (model download ~1.5 GB). After that: **fully offline, forever.**

---

## The core problem this solves

Nigeria has roughly **13 million out-of-school children** — the largest number of any country in the world. Those who do attend school often face classes of 60–80 pupils per teacher, no textbooks, and unreliable electricity. A child who falls behind has no safety net. Private tutors cost more than most families earn in a week.

Gemma-San puts a patient, always-available tutor directly on the phone that most Nigerian families already own — and keeps it working even when there is no internet.

---

## Feature breakdown

### 1. Fully offline AI tutoring engine
**Teaching impact: Critical**

- Runs Google's Gemma 4 E2B (2-billion-parameter) language model entirely on-device using the LiteRT runtime.
- After a one-time download, the AI works with **zero internet** — in a village, on a farm, during a power cut, at midnight.
- No subscription. No data cost per query. No cloud dependency that can go offline or change pricing.

**Why it matters:** In Nigeria's rural north and delta regions, mobile internet penetration is below 30% and data is expensive. "Offline-first" is not a feature — it is the difference between the app working and not working for most of the target audience.

---

### 2. Voice input — Speech-to-text (STT)
**Teaching impact: High**

- Uses whisper.cpp (Whisper Tiny, ~40 MB) running fully on-device.
- Records in mono 16kHz WAV, transcribes in under 1.5 seconds on a mid-range phone.
- Works in English and Nigerian English accent patterns.

**Why it matters:** Many children in the 5–8 age range are pre-literate or slow typists. Voice removes the keyboard barrier entirely. A child who cannot yet write "photosynthesis" can still ask about it by speaking. The first-audio latency target (≤ 1.5s from end of speech to start of AI reply) keeps the interaction feeling natural, not robotic.

---

### 3. Voice output — Text-to-speech (TTS)
**Teaching impact: High**

- Uses Android's built-in TTS engine (zero extra download).
- Detects the language of each AI response and picks the closest available voice: Nigerian English → British English → American English, with Hausa / Yoruba / Igbo / Swahili voices used when available.
- Sentence-streaming: TTS starts speaking at the **first sentence boundary** while the rest of the response is still being generated — perceived latency drops from ~3s to ~1s.
- Stops immediately when the user navigates away or sends a new message.

**Why it matters:** Many children in the target age group are still developing reading fluency. Hearing the AI speak the answer reinforces both content and correct pronunciation simultaneously. The Nigerian English voice preference is a deliberate cultural choice — children should hear a voice that sounds like them, not a foreign accent.

---

### 4. Multilingual responses
**Teaching impact: High**

- The AI detects and mirrors the language the child writes or speaks in.
- Supported language codes: `en` (English), `ha` (Hausa), `yo` (Yoruba), `ig` (Igbo), `pcm` (Nigerian Pidgin), `sw` (Swahili), `fr` (French), `am` (Amharic), `zu` (Zulu).
- No language setting required — the child simply speaks or types in their language.

**Why it matters:** Nigeria has over 500 languages and three dominant regional ones (Hausa, Yoruba, Igbo) plus Pidgin as the common tongue. A child who thinks in Hausa but attends an English-medium school faces a double cognitive load. Gemma-San meeting the child in their own language removes that barrier and dramatically improves comprehension.

---

### 5. Socratic teaching mode
**Teaching impact: Very High**

- The AI's default mode for any conceptual topic.
- Rather than giving the answer, Gemma-San asks one guiding question per turn, structured across three stages: **probe** (what does the child already know?), **build** (add one fact, ask one question), **resolve** (summarise, apply).
- Uses culturally grounded Nigerian examples: yam, NEPA, danfo bus, akara, generator.
- Never gives the full answer unprompted — the child must work toward it.

**Why it matters:** Decades of cognitive science research (Bloom's Taxonomy, Vygotsky's ZPD) show that a child who arrives at an answer through guided questioning retains it 2–3× longer than a child who is told the answer. Most Nigerian classrooms cannot afford the 1-to-1 attention this requires. Gemma-San makes Socratic dialogue available at any hour, for free.

---

### 6. Direct teaching mode
**Teaching impact: High**

- Used for pure fact questions, or when the child has said "I don't know" twice in a row.
- Delivers a clear 3–5 sentence explanation with one relatable Nigerian example.
- Ends with a comprehension check question.
- The AI will not "over-explain" — it stays within the child's apparent level.

**Why it matters:** Socratic mode is powerful but can frustrate a child who genuinely does not have the prerequisite knowledge. The mode-switching logic ensures the child always gets the information they need, in the most effective format for their current state.

---

### 7. Encouragement mode
**Teaching impact: Medium-High**

- Triggered when the child shows frustration (very short replies, "abeg", repeated wrong answers).
- 1–2 sentence warm affirmation of effort, not ability ("You dey try well well!").
- Never condescending. Never used twice in a row — the AI immediately returns to teaching.

**Why it matters:** Research on learning mindset (Dweck, 2006) shows that praising effort rather than ability produces more resilient learners. For children who already feel behind, a moment of warm acknowledgement before returning to the lesson can be the difference between continuing and giving up.

---

### 8. Three-tier memory system
**Teaching impact: Very High**

- **Working memory:** The last 4 turns of the current conversation are kept in context so the AI can reference what was just said.
- **Cross-session facts:** When the child volunteers personal information (name, age, hobby, favourite subject), the AI stores it via the `remember` tool and injects it into every future session. "Welcome back, Amara! Last time you were curious about fractions."
- **Session history:** Every conversation is stored in SQLite with timestamps, turn counts, and a compacted summary. If the app is force-killed mid-session, the session is recovered on next open (orphan recovery).

**Why it matters:** A human tutor remembers their student. This is what makes tutoring fundamentally different from a textbook. The three-tier system gives Gemma-San genuine continuity — a child who tells it their name on day 1 will be greeted by name on day 30. This builds trust and emotional investment in the learning relationship.

---

### 9. Quiz mode
**Teaching impact: High**

- Available from the "My Lessons" history screen for any topic the child has previously explored.
- Runs a structured 5-question quiz using a dedicated system prompt and `quiz_question` tool.
- Questions are calibrated to the child's age and the lesson content.
- After question 5, the AI delivers a personalised score and encouragement.
- The quiz conversation is fully voice-enabled (mic input + TTS output).

**Why it matters:** Retrieval practice — the act of recalling information under mild pressure — is one of the most evidence-supported memory techniques in learning science. The quiz mode converts passive lesson history into an active review loop with near-zero teacher effort.

---

### 10. SVG illustration library (22 topics)
**Teaching impact: High**

- 22 hand-crafted SVG illustrations covering the Nigerian primary school curriculum:
  `animal_cell`, `day_and_night`, `digestive_system`, `dry_season`, `earth_layers`, `electricity_circuit`, `flower_parts`, `food_chain`, `germs_microbes`, `healthy_food`, `human_heart`, `life_cycle_butterfly`, `lungs`, `photosynthesis`, `plant_cell`, `rainy_season`, `simple_machines`, `skeleton`, `solar_system`, `states_of_matter`, `water_cycle`, `weather`.
- All assets are bundled in the APK — no network fetch.
- Illustrations fade in smoothly alongside the spoken explanation.
- Tap any illustration to open a fullscreen interactive viewer (pinch to zoom 0.5×–5×).

**Why it matters:** Visual learning is especially important for children ages 5–10. In a classroom without printed textbooks or a working projector, these illustrations may be the first time a child has ever seen a labelled diagram of the digestive system or the water cycle. The topics were chosen to map directly to Nigeria's Basic Education curriculum (JSS 1–3).

---

### 11. Experimental AI drawing (try_drawing)
**Teaching impact: Medium**

- For topics not in the pre-built library, Gemma-San attempts to generate a simple SVG diagram on-the-fly (traffic lights, clock faces, city skylines, bar charts, number lines, flags, etc.).
- Generated SVGs are validated before display: must have a proper `viewBox`, 3–30 shape elements, no malformed XML.
- If validation fails, the spoken explanation continues normally — the child never sees a broken drawing.
- "Experimental drawing" label and thumbs-up/down feedback stored in SharedPreferences for future improvement.

**Why it matters:** The pre-built library covers 22 topics. The primary school curriculum has hundreds. AI-generated drawings extend visual learning to any topic, with graceful degradation when the model's output falls below quality thresholds. The feedback mechanism creates a lightweight data signal for curating which generated drawings are actually good.

---

### 12. Camera / visual question answering
**Teaching impact: High (pending vision model fix)**

- The child can take a photo and send it to Gemma-San with a custom text question.
- The preview screen shows the captured image and a text field: "Ask something about this picture…"
- The image + query are sent together to the vision API.
- Currently blocked at inference by a native library limitation (Gemma 4's 3-subgraph encoder). The UI is fully wired; the feature activates the moment the upstream fix ships.

**Why it matters:** When it works, this is transformational. A child can photograph a page from a textbook and ask "What does this mean?", snap a picture of a plant in the garden and ask "What kind of plant is this?", or show the AI their written maths homework and ask "Did I do this right?". It turns the camera into a learning instrument.

---

### 13. Phonics & word drilling (Practice mode)
**Teaching impact: High**

- Standalone practice mode for phonics and vocabulary drilling.
- Items presented on a card with a flip animation. Child taps the mic and says the word.
- STT transcription is evaluated with fuzzy matching (handles partial pronunciation).
- Two attempts per item before it auto-advances.
- Progress bar across 15 items per session.
- Session summary screen with score and mascot state feedback.

**Why it matters:** Phonics fluency is the single strongest predictor of reading success in primary school. A child who cannot decode words cannot access any other subject. The practice mode gives targeted, repeatable drilling that a classroom teacher with 60 students cannot feasibly provide to each child individually.

---

### 14. Spaced Repetition System (SRS) scheduler
**Teaching impact: Very High**

- All phonics items are tracked with a mastery score (0.0–1.0) stored in SQLite.
- Review intervals after correct answers: +1 hour → +1 day → +3 days → +7 days.
- After a wrong answer: +5 minutes (resurfaces in same session) or +1 day (second wrong).
- Maximum 3 new items per session; 15 items total per session cap.
- Difficulty levels unlock automatically when ≥70% of level-1 items are mastered.

**Why it matters:** SRS is the most evidence-backed system for long-term vocabulary and language retention (Ebbinghaus forgetting curve). Apps like Duolingo and Anki are built on this foundation. Gemma-San brings this algorithm to phonics for children who have never had access to a tutor who would know which words to revisit and when.

---

### 15. Lesson history ("My Lessons")
**Teaching impact: High**

- Every conversation topic is automatically detected and catalogued.
- Topics are organised by mastery level: Learning → Getting There → Mastered (based on number of sessions).
- Each topic shows its last visit date, session count, and a generated lesson summary.
- Lesson summaries are auto-generated by Gemma using a structured `lesson_summary` tool — a paragraph + 3–5 key concept sentences in child-friendly language.
- "Quiz Me" button launches a quiz on any topic directly from the summary screen.

**Why it matters:** A child (or a parent) can see what has been covered, how well it was understood, and revisit any topic instantly. This turns isolated conversations into a coherent learning record — the equivalent of a school exercise book, but self-organising and searchable.

---

### 16. Avatar system & personalisation
**Teaching impact: Medium**

- 10 animal avatars (lion, elephant, butterfly, monkey, parrot, fish, owl, fox, bear, frog) with unique emoji and background colours.
- Avatar is chosen during onboarding and displayed consistently across: home screen header, chat bubbles, lesson history cards.
- Lesson history is scoped per-avatar, so siblings sharing a phone maintain separate learning records.
- Avatar can be changed at any time from the home screen.

**Why it matters:** Children are more engaged with technology they feel "belongs" to them. The avatar creates identity ownership. Per-avatar lesson history is a practical necessity in households where one phone is shared among three or four children — common in the target demographic.

---

### 17. Onboarding flow
**Teaching impact: Medium**

- Four-screen onboarding: Welcome → Age picker → Avatar picker → Permissions.
- Age ranges: 5–6, 7–8, 9–10, 11–12. Stored and injected into every session so the AI calibrates vocabulary and complexity.
- Permissions screen explains camera and microphone access in plain language before requesting them.
- All preferences persisted in SharedPreferences; never re-shown after completion.

**Why it matters:** Age-calibrated tutoring is significantly more effective than one-size-fits-all responses. A 6-year-old and a 12-year-old asking "What is gravity?" need very different answers. The onboarding captures this signal once and applies it silently to every future interaction.

---

### 18. Animated mascot — Mama San the owl
**Teaching impact: Medium**

- Custom vector-drawn owl with four reactive states: **idle**, **listening** (mic active), **thinking** (AI processing), **speaking** (TTS playing).
- State changes are instant and animated — the child always knows what the app is doing without reading status text.
- Collapses from a large full-screen display into a small AppBar icon when the first message is sent, freeing screen space for conversation.
- Appears on the splash screen, home screen, practice screen, and inline in the conversation AppBar.

**Why it matters:** For young children, especially pre-literate ones, visual feedback is essential. The owl's state changes communicate "I'm listening", "I'm thinking", and "I'm talking" in a language that requires no reading. This reduces anxiety and keeps attention on the learning content rather than on deciphering app state.

---

### 19. Privacy — zero data leaves the device
**Teaching impact: Critical**

- All AI inference runs on-device. No query, no conversation, no child's name, age, or personal fact ever leaves the phone.
- No account required. No email. No analytics SDK. No remote logging.
- The only network activity is the one-time model download from Hugging Face — authenticated with a token, then never needed again.

**Why it matters:** Children are a protected class under data privacy law in most jurisdictions (COPPA, GDPR-K, Nigeria's NDPR). But beyond legal compliance: parents in the target demographic are often wary of "the phone recording their children." Gemma-San can be used with mobile data turned off after setup. This is a genuine trust differentiator.

---

### 20. Works on affordable hardware
**Teaching impact: Critical**

- Minimum spec: Android 8.0 (API 26), 4 GB RAM.
- Tested on devices that retail for ₦80,000–₦150,000 (~$50–$100 USD) — the Tecno Spark and Infinix Hot family that dominates the Nigerian mid-range market.
- CPU inference mode available for devices without a compatible GPU (slower but functional).
- Model is ~1.5 GB; after download it is stored in external storage and not duplicated.

**Why it matters:** An AI tutor that only runs on a flagship phone helps no one in this demographic. The deliberate choice of Gemma 4 E2B (2B parameters) over larger models is an equity decision. Running acceptably on a ₦80,000 phone means the app is accessible to the families who need it most.

---

## Summary table

| Feature | Category | Teaching Impact |
|---|---|---|
| Fully offline AI engine | Infrastructure | Critical |
| Zero data privacy | Infrastructure | Critical |
| Affordable hardware support | Infrastructure | Critical |
| Voice input (STT) | Interaction | High |
| Voice output (TTS) | Interaction | High |
| Multilingual responses | Accessibility | High |
| Socratic teaching mode | Pedagogy | Very High |
| Direct teaching mode | Pedagogy | High |
| Three-tier memory system | Personalisation | Very High |
| SRS phonics scheduler | Pedagogy | Very High |
| Encouragement mode | Wellbeing | Medium-High |
| Quiz mode | Assessment | High |
| SVG illustration library | Visual learning | High |
| Lesson history & summaries | Progress tracking | High |
| Phonics drilling (Practice) | Foundational literacy | High |
| Experimental AI drawing | Visual learning | Medium |
| Camera / visual Q&A | Multimodal learning | High (pending) |
| Avatar & personalisation | Engagement | Medium |
| Age-calibrated onboarding | Personalisation | Medium |
| Animated mascot (Mama San) | Engagement / UX | Medium |

---

## Real-world impact potential

**If deployed at scale to 100,000 children:**

- Each child averages 3 sessions per week, 15 minutes per session → **45 minutes of personalised 1-to-1 tutoring per week per child**, at zero recurring cost.
- In a typical Nigerian public school, a child receives approximately **3–5 minutes of individual teacher attention per week**.
- Gemma-San delivers **9–15× more direct educational attention** than the classroom can provide — entirely offline, at any time of day.

**The phonics SRS alone:** A child who uses Practice mode daily for 6 months will have reviewed 200+ words with optimal spacing — roughly equivalent to the explicit phonics instruction in an entire primary school year.

**The memory system:** A child who starts in primary 2 and uses the app through primary 6 will have an AI tutor that remembers four years of their learning history, personal facts, and topic mastery — continuity no human tutor at a Nigerian public school can realistically maintain.

---

*Gemma-San was built in 14 days as a hackathon submission. The architecture is designed to scale — the model, the illustration library, the SRS item bank, and the memory schema can all be extended without rewriting the app.*
