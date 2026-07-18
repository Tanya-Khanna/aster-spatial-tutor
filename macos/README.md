# Aster for macOS

Aster is a native spatial tutor for macOS. Press **Option–Space**, drag around the exact learning context, and ask by voice or text. Aster follows that region locally, diagnoses before explaining, teaches through synchronized voice and staged annotations, checks an independent answer, and persists concept-level mastery evidence across launches.

## Product loop

1. Select an exact region or click for a cursor-centered context.
2. Follow that region locally without spending API tokens.
3. Diagnose with one short question and concrete misconception choices.
4. Reveal a spatial lesson step-by-step through voice, notebook, and overlays.
5. Fade the scaffolding and collect an independent transfer answer.
6. Assess against explicit success criteria.
7. Save mastery, strengths, shaky areas, and the next strategy.
8. Adapt the next lesson or open an approved Desmos/Manim demonstration.

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
- The app keeps a local estimated-cost ledger and stops at $5.
- Demo mode works without an API key using three deterministic sample lessons.

## Current prototype boundaries

- Exact main-display region capture is implemented; multi-display anchoring is next.
- Desmos is an embedded sandbox populated from a structured payload. Manim runs one of four fixed local templates after confirmation and requires a local Manim CLI.
- Aster teaches labeled educational anatomy diagrams. It is not for radiology, diagnosis, or medical advice.
