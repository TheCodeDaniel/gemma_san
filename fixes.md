Comprehensive fix and polish pass on Gemma-San. Read CLAUDE.md first.

This is a multi-issue cleanup. There are 11 distinct issues across
bugs, AI behavior, UX, and feature restoration. Address them in the
order listed below — bugs first, then AI behavior, then UI polish,
then feature restoration. After each group, run flutter analyze and
verify no regressions before moving to the next.

DO NOT rush. Use ultrathink on the architecture changes. If any issue
requires architectural changes (memory injection, navigation lifecycle,
TTS engine reconfiguration), think through the full implication before
making the change.

Important constraint: We are no longer using Pidgin as a forced output
language. The system prompt should let Gemma respond in whatever
language the user used. Remove ALL hardcoded "respond in Pidgin"
instructions from system prompts, tool descriptions, and onboarding
copy.

=============================================================
GROUP 1: CRITICAL BUGS — fix first
=============================================================

BUG 1: Conversation back button doesn't stop audio playback.
When user presses back button (or any navigation out of the
conversation screen), TTS audio continues playing in the background.

Fix:

- In ConversationScreen, wrap the route in PopScope (Flutter 3.16+) or
  override the back navigation
- On screen dispose AND on back button intercept, call ttsService.stop()
- Also stop any ongoing Gemma streaming inference if mid-response
- Verify this works for: hardware back button, AppBar back arrow,
  swipe-back gesture (iOS-style)
- Test by starting a long response, pressing back mid-speech,
  verifying audio cuts immediately

BUG 2: Lesson history lost on app restart.
When the app is killed and reopened, all chat history disappears from
the My Lessons screen. This suggests sessions aren't being persisted
durably, or they're written only at clean-exit moments.

Fix:

- Audit the memory_dao.dart write logic. Session data MUST be written
  to SQLite after EVERY turn, not just at session end
- Each turn should append to the current session's transcript in DB
- On conversation screen open, create or resume the active session
  with a session_id stored in SharedPreferences
- On every turn (user message + AI response), write to DB immediately
  before continuing
- When user navigates away or app backgrounds, mark session as ended
  and trigger compaction (this part may already exist — preserve it)
- Add a recovery path: if app was killed mid-session, on next launch
  the incomplete session is still in DB with partial transcript.
  Trigger compaction on it lazily when My Lessons is opened
- Test: have a 3-turn conversation, force-kill app from recent apps,
  reopen, verify lesson appears in My Lessons

BUG 3: Quiz Me button uses Socratic flow instead of quiz mode.
In the lesson summary screen, the "Quiz Me" button currently triggers
a normal conversation that uses socratic_teach. It should trigger an
actual quiz flow.

Fix:

- Add a new tool: quiz_question (separate from the teaching tools)
  Parameters: spoken_question, expected_answer_hint, topic,
  question_number (e.g. 1 of 5), language_code
- When user taps "Quiz Me" on a lesson summary:
  - Pre-feed Gemma a system prompt containing the lesson's session
    summaries and key concepts (from memory_dao)
  - Set conversation mode to "quiz mode" (a state flag)
  - In quiz mode, the system prompt instructs Gemma to ONLY use
    quiz_question and direct_teach tools (no socratic_teach, no
    encourage as primary)
  - Ask 5 questions in sequence about the lesson topic
  - After each child answer, Gemma evaluates and moves to next question
  - At the end, show a brief summary: "You got X out of 5 right"
- Quiz mode UI: same conversation screen but with a small "Quiz: 2/5"
  badge in the header. Mode indicator pill should show "Quiz" not
  "Direct"
- Continue Learning button: same idea — pre-feed the lesson context
  into the system prompt so Gemma resumes meaningfully, then return
  to normal conversation mode

=============================================================
GROUP 2: AI BEHAVIOR
=============================================================

ISSUE 4: Fresh-chat over-sharing of memory context.
On a clean conversation start, when the user says "Hello", Gemma
responds with unnecessary memory recall like "I remember you are in
the 6-7 age group."

Fix:

- The current system prompt injects memory context unconditionally.
  Change this:
- For the FIRST turn of a session, inject memory context but instruct
  Gemma in the system prompt: "Greet the child warmly and briefly. Do
  not list memory facts unless the child asks. If you do not yet know
  the child's name, ask gently."
- For subsequent turns, memory context is available for Gemma to draw
  on contextually, but not enumerated explicitly
- Add to the system prompt a NEW behavior rule:
  "On the first turn of a conversation, respond ONLY with a warm
  greeting (1-2 sentences). If you know the child's name, use it. If
  not, introduce yourself as Gemma-San and ask their name. Do NOT
  list facts you remember about them. Do NOT mention their age group,
  past topics, or interests unless they specifically ask."
- The remember tool should still work normally — when child shares
  their name, age, interest, etc., call remember()

ISSUE 5: Socratic tooling needs improvement.
Already addressed in previous iterations — verify the current
socratic_teach, direct_teach, and encourage tools have the improved
descriptions with stage rules and trigger conditions. If they don't,
reference the latest version in conversation history.

ISSUE 6: TTS accent — use local Nigerian English voice.
Currently TTS speaks with American accent. Android's TTS engine
supports en-NG (English Nigeria) on most devices.

Fix:

- In ttsService.initialize(), query the device locale
- Get available TTS languages via flutterTts.getLanguages
- If en-NG is available, set it as the default
- If not, try en-GB (closer to Nigerian English than en-US)
- Fall back to en-US only if neither is available
- Make this a one-time setup with the preferred language cached in
  SharedPreferences
- Add a debug log showing which language was selected so we can
  verify on different devices
- Test on your S22: confirm the voice changes from American to
  Nigerian or British accent

=============================================================
GROUP 3: UX & UI POLISH
=============================================================

ISSUE 7: Avatar selection has no visible use.
The avatar picker exists in onboarding but the chosen avatar never
appears anywhere in the app.

Fix — use the avatar in three places:

1. Home screen header: display a small version of the chosen avatar
   next to "Welcome back" with a tap-to-change action
2. Conversation screen: in the user's chat bubbles (left side avatar
   indicator), show the child's avatar. Gemma's responses keep the
   Mama San owl
3. Lesson cards (My Lessons): small avatar badge on each lesson card
   indicating which child owned the session (forward-compatible with
   multi-child support)
4. Quiz results: avatar appears in the celebration screen at the end
   of a quiz

If the existing avatar set isn't visually rich enough, expand to 8-10
options: lion, elephant, butterfly, monkey, parrot, fish, owl, fox,
bear, frog. Use consistent flat illustration style matching the app.

ISSUE 8: Conversation screen mascot too large.
The Mama San owl SVG dominates the screen, leaving little room for
chat bubbles on smaller devices.

Fix:

- Collapse the mascot into the app bar / header during active
  conversation. Show only the small version (~48dp) animating per
  state
- When the conversation is empty (no messages yet), show the full
  large mascot with a friendly prompt
- As soon as the first message is sent or received, the mascot
  shrinks to the header with a smooth animation
- The mode indicator pill should sit next to the small mascot in
  the header
- This gives 80%+ of the screen height to chat content during
  active conversations

ISSUE 9: UI is good but not yet great.
The colors and structure are right, but the overall feel could be
more polished and emotionally engaging.

Push the polish further with these specific improvements:

- Add subtle background texture or grain to the cream background
  (very low opacity, like paper texture) for warmth
- Increase shadow depth slightly on cards (currently subtle, push to
  6-10px blur, 15-25% opacity) for more tactile feel
- Add micro-interactions: button press should have a satisfying
  spring animation (scale 0.96, 150ms ease-out, scale back with
  spring on release)
- Headings could use slightly more character — try ColorFiltered or
  a subtle shadow behind primary headings for depth
- Empty states should be more delightful — Mama San doing different
  poses or expressions in each empty state (sleeping for "no
  lessons yet", reading for "ready to teach")
- Loading states: replace generic spinners with a small Mama San
  thinking animation
- Page transitions: use slide + fade rather than default Flutter
  page transitions

Show me before/after screenshots of the home screen and conversation
screen after polish.

=============================================================
GROUP 4: FEATURE RESTORATION
=============================================================

ISSUE 10: Restore image scanning UI.
The camera/image scanning feature was previously removed because
libLiteRtLm.so rejected Gemma 4 vision encoder. We're restoring the
UI for v1.1 readiness — when the upstream fix lands, the wiring will
be there.

Fix:

- Restore the camera button on the conversation screen (use the
  previously removed code from the diagnostic version if still
  available; otherwise rebuild)
- Restore lib/features/camera/camera_capture_screen.dart if it was
  deleted
- Add the full UI flow:
  - Tap camera icon → image_picker opens camera
  - User captures photo
  - Preview shown with "Use this picture" and "Try again" buttons
  - On confirm, image bytes attached to next Gemma call via
    Message.withImage
  - Show fun animated UI during processing (Mama San "looking"
    animation)
- Behavior when vision fails (current state):
  - Catch the libLiteRtLm error gracefully
  - Show a friendly message: "I can't see pictures clearly yet —
    coming soon! For now, tell me what you see and I'll help."
  - Do NOT crash. Do NOT show technical errors.
  - Log the failure quietly for diagnostics
- Make the camera flow itself interactive and fun: smooth animations
  on the capture button, satisfying "click" haptic feedback on
  capture, preview with subtle zoom-in entrance
- All code logic must be complete and ready — if a future flutter_gemma
  update fixes vision support, this should "just work" without
  reconstruction

=============================================================
GROUP 5: META QUALITY
=============================================================

ISSUE 11: Zero bugs after this pass.

After completing groups 1-4:

- Run flutter analyze and resolve every warning and error
- Test every screen and every flow manually on the S22
- Specific test paths:
  a. Fresh install: onboarding → avatar → home → conversation
  (3 turns) → back button (audio stops) → home → My Lessons
  (session appears) → tap lesson → Quiz Me (quiz works) → back
  b. Restart app: cold start, verify all previous lessons still in
  My Lessons
  c. Fresh conversation: say "Hello" — verify Gemma greets briefly
  without dumping memory
  d. TTS check: verify accent is Nigerian (or British fallback),
  not American
  e. Avatar check: avatar visible in home, conversation, My Lessons
  f. Camera button: present, tappable, shows graceful "coming soon"
  message
  g. Conversation screen: mascot small in header during active chat
- Document any issue found during testing that you couldn't fix in
  this session
- If any architectural change required deferred work, log it clearly
  in CLAUDE.md with TODO markers

=============================================================
EXECUTION RULES
=============================================================

- Do Group 1 (bugs) completely before moving to Group 2
- After each group, pause and confirm before moving on
- Run flutter analyze between groups
- DO NOT add any "respond in Pidgin" instructions anywhere. The user
  has decided against forced Pidgin. Gemma should mirror the user's
  language naturally
- If you discover that fixing one issue requires touching code that
  affects another issue, address them together but flag this in your
  summary
- Use ultrathink for any architectural decision (memory persistence
  pattern, TTS lifecycle, quiz mode state management)
- Show me a brief summary at the end listing what was fixed, what
  was deferred, and any concerns

Stop now and confirm you understand the scope before starting. List
your proposed execution order in your reply.
