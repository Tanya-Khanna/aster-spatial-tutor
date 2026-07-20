# Aster✱ for macOS

Aster✱ is a native spatial tutor for macOS. Press **Option–Space**, drag around the exact learning context, and ask by voice or text. Aster✱ follows that region locally, diagnoses before explaining, teaches through synchronized voice and staged annotations, checks an independent answer, and persists concept-level mastery evidence across launches.

The ✱ cursor companion is the source of the overlay: it lands and reads beside the pointer, morphs into each annotation, and collapses into a clickable bookmark that reopens the exact lesson. The optional “Hey Aster” wake phrase is disabled by default.

## Product loop

1. Select an exact region on any display, click for cursor context, or lock a native window.
2. Follow that region locally without spending API tokens.
3. Diagnose with one short question and concrete misconception choices.
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

## API and privacy

- GPT-5.6 Terra diagnoses and teaches; Precision mode uses GPT-5.6 Sol; GPT-5.6 Luna assesses answers.
- Diagnosis, spatial lessons, and mastery assessment use separate strict schemas.
- Visible follow mode refreshes only the selected region locally; API capture is question-triggered.
- The API key is stored in the macOS Keychain.
- Voice input and narration use macOS frameworks, avoiding additional API spend.
- Demo mode works without an API key using three deterministic sample lessons.

## Implemented advanced capabilities

- Multi-display region capture, selected-window following, Retina mapping, local OCR/visual-object anchors, and recovery after window movement, resizing, scrolling, or zooming.
- Conversational voice with automatic voice turns, interruption, synchronized narration, replay, speed control, and collapsible transcript.
- Recent-frame video mode with bounded four-frame context, browser caption/timestamp grounding, pausing for the teaching turn, and resuming after the check. Safari/Chrome may request Automation permission and must allow JavaScript from Apple Events.
- Animated flow/focus/comparison overlays and safe diagram primitives for simplified redraws.
- Desmos plus nine fixed local Manim families with an embedded low-resolution preview. Manim requires a local CLI; model-authored Python is never executed.
- Permission modes, reversible scratch work, safe typing previews, action history/undo, shaky-area practice, spaced review, misconception clusters, dependencies, difficulty, and analogy preferences.
- Aster✱ teaches labeled educational anatomy diagrams. It is not for radiology, diagnosis, or medical advice.
