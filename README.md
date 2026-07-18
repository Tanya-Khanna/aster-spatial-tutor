# Aster

> **Your screen becomes the whiteboard.**

Aster is a native spatial tutor for macOS. Press **Option–Space**, point at an equation, research figure, graph, circuit, or educational anatomy diagram, and ask a question. Aster teaches by voice while drawing circles, arrows, highlights, and labels directly over the material—then asks the learner to complete the thought.

Built for the **OpenAI Build Week · Education Track** with **Codex** and **GPT-5.6**.

## Try it

- Download: [`public/Aster-macOS.zip`](public/Aster-macOS.zip)
- App bundle after packaging: `macos/dist/Aster.app`
- Landing page locally: `npm install && npm run dev`
- No API key? Choose Research, Math, or Anatomy on the welcome screen and run Demo mode.

The prototype is ad-hoc signed. On first use, macOS may ask for permission to open it and for Screen Recording, Microphone, and Speech Recognition access.

## The problem

Dense visual learning material is hard to translate into a text-chat prompt. A learner must leave the equation or diagram, capture it, upload it, describe where they are confused, mentally map a prose response back to the source, and repeat. That context switching is especially costly for notation-heavy research papers, multi-step equations, circuits, graphs, and anatomy plates.

Aster removes that translation layer. Its core unit is not an answer—it is a **spatial teaching turn** synchronized across voice, overlay, note, and mastery check.

## Product loop

1. **Point** near the confusing object and press **⌥ Space**.
2. **Ask** naturally by voice or text.
3. **See** Aster capture one explicit screen state with a cursor halo.
4. **Learn** through synchronized narration and at most four targeted annotations.
5. **Keep** one concise note in the persistent overlay notebook.
6. **Prove it** by answering Aster’s short mastery question.

## Why it is different

| Existing pattern | Aster |
| --- | --- |
| Upload a screenshot into a separate chat | Start from the material already on screen |
| Explain “the variable in the second line” | Use the learner’s cursor as spatial context |
| Return a wall of prose | Coordinate voice with precise visual marks |
| Solve the whole problem | Diagnose, scaffold one step, then hand it back |
| Let an agent act without a learning contract | Preview Desmos/Manim actions and require approval |

## Architecture

```text
⌥ Space + voice/text
        ↓
Explicit main-screen capture + visible cursor halo
        ↓
GPT-5.6 Responses API
  • Terra by default / Sol precision mode
  • image understanding
  • strict spatial_lesson JSON schema
        ↓
Native macOS presentation
  • transparent click-through annotation panel
  • persistent SwiftUI tutor notebook
  • AVSpeechSynthesizer narration
  • one-question mastery check
```

The schema limits a turn to four annotations with normalized coordinates, a spoken explanation, a notebook takeaway, a mastery question, and an optional `desmos` or `manim` suggestion. If the model is uncertain, the instruction explicitly asks it to use fewer marks and request a clearer pointer.

## Built with OpenAI

- **GPT-5.6 Terra** is the default vision/reasoning model for cost-sensitive teaching turns.
- **GPT-5.6 Sol** is available as Precision mode for unusually dense pages.
- **Responses API** accepts the screenshot and returns a strict structured lesson plan.
- **Codex** was used to research the problem and judging rubric, design the product system, implement the Swift app and landing page, debug packaging, and create the submission materials.

For the Build Week submission, add the public Codex session ID to `/feedback` and here before the deadline:

```text
Codex session ID: <add public session ID>
```

## $5 budget design

- macOS Speech Recognition and `AVSpeechSynthesizer` handle voice without paid audio tokens.
- Screenshots are downsampled to a maximum width of 1440 px.
- Standard turns use Terra, low reasoning effort, high image detail, and at most 900 output tokens.
- Precision mode is explicit rather than automatic.
- Token usage is priced into a local ledger; new live requests stop at a conservative **$4.80 reserve threshold** so a bounded final response does not discover the $5 limit after crossing it.
- Demo mode is deterministic and costs **$0**.

## Privacy and safety

- No continuous or hidden background capture.
- Screen capture happens only after the learner activates Aster.
- Capture state is visible in the interface.
- The API key is stored in macOS Keychain and excluded from the repository.
- Aster teaches labeled educational anatomy; it does not interpret radiology, diagnose disease, or give medical advice.
- Tool suggestions are previews. This prototype does not silently type into or modify another app.

## Run the macOS app

Requirements: macOS 13+, Swift 6 command-line tools or Xcode.

```bash
cd macos
zsh scripts/package.sh
open dist/Aster.app
```

The script compiles a release binary, assembles a `.app`, applies an ad-hoc signature, and updates `public/Aster-macOS.zip`.

## Run the landing page

Requirements: Node.js 22.13+.

```bash
npm install
npm run dev
```

Validation:

```bash
npm test
cd macos && swift build -c release
```

## Judge-ready evidence

| Criterion | Evidence in this repository |
| --- | --- |
| Technological Implementation | Native AppKit overlay, global Carbon hotkey, Screen Recording capture, cursor grounding, Responses API vision, strict JSON schema, native voice, Keychain storage, local spend guard |
| Design | One coherent Aster system across macOS and responsive web; translucent persistent tutor surface; animated annotation choreography; voice, note, and mastery states |
| Potential Impact | Removes screenshot/upload/context-switch friction from research papers, STEM notation, and anatomy diagrams; demo emphasizes comprehension rather than answer generation |
| Quality of Idea | OS-native spatial tutoring, cursor-as-context, cross-app teaching, and a constrained “demonstrate, never take over” agent contract |

See [`docs/DEMO_SCRIPT.md`](docs/DEMO_SCRIPT.md) for the sub-three-minute submission story and [`docs/EVALS.md`](docs/EVALS.md) for the annotation-quality evaluation plan.

## Prototype boundaries

- Main-display capture is implemented; window-level and multi-display anchoring are next.
- The shipped demo makes Desmos/Manim suggestions visible but does not execute them. A production version should run them through a controlled integration with explicit confirmation.
- A live API turn requires the learner’s own OpenAI API key. The submission can be evaluated fully in free Demo mode.

Independent Build Week project. Not affiliated with or endorsed by Apple or OpenAI.
