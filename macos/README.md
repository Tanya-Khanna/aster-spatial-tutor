# Aster✱ for macOS

Aster✱ is a native spatial tutor for macOS. Press **Option–Space** or say **“Hey Aster”** to open a slim, movable teaching bar above any app. Whole Screen is ready by default; Point pins an explicit click, while Region and Freehand Loop narrow the visual scope. With voice enabled, Aster✱ listens immediately and sends after a short pause. Typing works in every mode. Following and visual context stay local until the learner submits a question.

The ✱ stays inside the tutor bar rather than creating a second floating mascot. Point mode places a quiet coral pin at the learner’s explicit click and uses that stable location as the source of the overlay. The optional “Hey Aster” wake phrase is disabled by default and exposes a live status plus an end-to-end test control in Settings.

The tutor bar and Point/Region/Freehand selectors are non-activating, key-capable AppKit panels. They can accept typed input over the current app, full-screen Space, or secondary display without making Aster✱ the active application or switching to its desktop Space.

## Product loop

1. Open the persistent bar with Option–Space or the optional wake phrase.
2. Choose Whole Screen, Point, Region, or Freehand Loop and follow that scope locally without an API request.
3. Diagnose with one short question and concrete misconception choices, while allowing the learner to describe a different confusion or quietly skip.
4. Reveal a spatial lesson step-by-step through voice, notebook, and overlays.
5. Fade the scaffolding and collect an independent transfer answer.
6. Assess against explicit success criteria.
7. Save mastery, strengths, shaky areas, and the next strategy.
8. Schedule review, generate targeted practice, or open an approved Desmos/Manim demonstration.

## Build and package

This prototype uses Swift Package Manager and can be built using the Apple command-line developer tools:

```bash
cd macos
zsh scripts/package.sh
```

The packaged application is written to `macos/dist/Aster.app` and the downloadable archive to `public/Aster-macOS.zip`.

Before onboarding, Aster✱ blocks launches from Downloads/App Translocation or any quarantined copy. **Move to Applications & Relaunch** stages the bundle in `/Applications`, removes quarantine recursively, launches that stable copy, and closes the temporary process. Because the prototype is ad-hoc signed, replacing it can still leave **Screen & System Audio Recording** enabled for an older code identity; the recovery state explains how to remove old entries, re-add `/Applications/Aster.app`, check access, and restart.

Aster✱’s welcome, tutor, settings, selection, companion, and teaching-overlay windows are visible in user-created screenshots. During Aster✱’s own internal context capture, those windows are temporarily marked non-shareable so they are excluded from the image sent for tutoring.

## API and privacy

- GPT-5.6 Terra diagnoses and teaches; Precision mode uses GPT-5.6 Sol; GPT-5.6 Luna assesses answers. Ordinary visual turns are capped near 1024 px and Responses API output streams into the tutor surface; Precision mode retains original pixels.
- Diagnosis, spatial lessons, and mastery assessment use separate strict schemas.
- The bar visibly follows the active Whole Screen, Point, Region, or Freehand Loop scope locally; API capture is question-triggered.
- Aster✱ requires the learner’s own OpenAI API key. It is validated before an explicit save to macOS Keychain.
- Settings shows whether OpenAI is connected and provides an immediate **Remove API key / Sign out** control.
- Every Responses API request uses `store: false`; the key is never bundled or logged.
- Voice input and narration use macOS frameworks, avoiding additional API spend.
- Settings reports per-session request and token usage and links to OpenAI’s live spend and budget pages.

## Implemented advanced capabilities

- Multi-display region capture, selected-window following, Retina mapping, local OCR/visual-object anchors, and recovery after window movement, resizing, scrolling, or zooming.
- Conversational voice with automatic voice turns, interruption, synchronized narration, replay, speed control, and collapsible transcript.
- Recent-frame video mode with bounded four-frame context, browser caption/timestamp grounding, pausing for the teaching turn, and resuming after the check. Safari/Chrome may request Automation permission and must allow JavaScript from Apple Events.
- Animated flow/focus/comparison overlays and safe diagram primitives for simplified redraws.
- Desmos plus nine fixed local Manim families with an embedded low-resolution preview. Manim requires a local CLI; model-authored Python is never executed.
- Permission modes, reversible scratch work, safe typing previews, action history/undo, shaky-area practice, spaced review, misconception clusters, dependencies, difficulty, and analogy preferences.
- Four-step first-run onboarding, visible authenticated/unauthenticated states, permission recovery, adaptive light/dark appearance, and destructive-action confirmations. Ongoing preferences live in a compact five-pane native Settings window that remembers its last pane and opens with Command–Comma.
- Aster✱ teaches labeled educational anatomy diagrams. It is not for radiology, diagnosis, or medical advice.
