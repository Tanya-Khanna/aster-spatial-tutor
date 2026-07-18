# Aster for macOS

Aster is a native spatial STEM tutor for macOS. Press **Option–Space**, point at an equation, research figure, graph, circuit, or educational anatomy diagram, and ask a question. Aster captures the current screen with explicit permission, sends a budget-controlled vision request to GPT-5.6, and renders the returned lesson as voice, a persistent notebook, and normalized on-screen annotations.

## Product loop

1. See the selected screen and cursor halo.
2. Diagnose the misconception before solving.
3. Point with precise, structured annotations.
4. Teach one idea through voice and the persistent lesson notebook.
5. Ask the learner to predict or explain the next step.
6. Fade the scaffolding and verify understanding.

## Build and package

This prototype uses Swift Package Manager and can be built using the Apple command-line developer tools:

```bash
cd macos
zsh scripts/package.sh
```

The packaged application is written to `macos/dist/Aster.app` and the downloadable archive to `public/Aster-macOS.zip`.

## API and privacy

- GPT-5.6 Terra is the default model; Precision mode uses GPT-5.6 Sol.
- Responses are schema-constrained into an annotation lesson plan.
- Screen capture is user-triggered; there is no continuous background recording.
- The API key is stored in the macOS Keychain.
- Voice input and narration use macOS frameworks, avoiding additional API spend.
- The app keeps a local estimated-cost ledger and stops at $5.
- Demo mode works without an API key using three deterministic sample lessons.

## Current prototype boundaries

- Main-display capture is implemented; per-window and multi-display anchoring are next.
- Desmos and Manim are represented in the lesson schema and interface as safe preview actions. Production tool execution should use a controlled sandbox and require confirmation before modifying another app.
- Aster teaches labeled educational anatomy diagrams. It is not for radiology, diagnosis, or medical advice.
