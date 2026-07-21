# Aster✱

> **Your screen becomes the whiteboard.**

Aster✱ is a native spatial tutor for macOS. Press **Option–Space**, select an equation, research figure, graph, circuit, code block, paragraph, homework problem, or educational anatomy diagram, and ask a question. Aster✱ diagnoses the misconception before explaining, teaches through synchronized voice and on-target drawings, checks an independent answer, and remembers the resulting mastery evidence for the next lesson.

The animated **✱** is Aster✱’s physical presence: it lands beside the cursor, pulses while reading, stretches into each teaching mark, then collapses beside the concept as a clickable lesson bookmark. “Hey Aster” offers the same entry point as an explicit opt-in wake mode.

Built for the **OpenAI Build Week · Education Track** with **Codex** and **GPT-5.6**.

## Try it

- Download: [`public/Aster-macOS.zip`](public/Aster-macOS.zip)
- App bundle after packaging: `macos/dist/Aster.app`
- Landing page locally: `npm install && npm run dev`
- Aster✱ requires the learner’s own OpenAI API key. First-run onboarding validates it before an explicit save to macOS Keychain.

The prototype is ad-hoc signed. A first-run relocation guard detects Downloads/App Translocation and quarantine metadata before onboarding, then offers **Move to Applications & Relaunch** so Screen Recording attaches to one stable app identity. After replacing Aster✱ with a newer build, macOS may require approval again; the permission-repair state gives exact remove-old-entry, re-add, check, and restart steps.

After onboarding, Aster✱ uses a single compact native Settings window with General, Voice, Permissions, Learning, and Account panes. It remembers the last pane, opens with **Command–Comma**, and routes permission errors directly to recovery controls.

## The problem

Dense visual learning material is hard to translate into a text-chat prompt. A learner must leave the equation or diagram, capture it, upload it, describe where they are confused, mentally map a prose response back to the source, and repeat. That context switching is especially costly for notation-heavy research papers, multi-step equations, circuits, graphs, and anatomy plates.

Aster✱ removes that translation layer. Its core unit is not an answer—it is a **spatial teaching turn** synchronized across voice, overlay, note, and mastery check.

## Product loop

1. **Select** the exact context with a drag—or click for a cursor-centered region.
2. **Follow** that region locally as the source changes; nothing is sent until the learner asks.
3. **Diagnose** with one short choice before any explanation appears.
4. **Teach** through staged narration, notebook insights, and precisely mapped annotations.
5. **Fade** the scaffolding and ask for an independent prediction or transfer.
6. **Assess** the learner’s reasoning against explicit success criteria.
7. **Remember** demonstrated strengths, shaky areas, mastery, and the next teaching strategy across app launches.
8. **Adapt** the next lesson or offer a learner-controlled Desmos/Manim demonstration.

## Why it is different

| Existing pattern | Aster✱ |
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
Any-display region / native window selection + semantic cursor anchor
        ↓
Local target recovery + optional recent-frame video buffer (zero API calls)
        ↓
GPT-5.6 diagnostic turn → learner choice
        ↓
GPT-5.6 spatial lesson turn
  • Terra by default / Sol precision mode
  • image understanding
  • strict spatial_lesson JSON schema
        ↓
Native macOS presentation
  • transparent click-through annotation panel
  • persistent SwiftUI tutor notebook
  • AVSpeechSynthesizer narration
  • independent mastery check
        ↓
GPT-5.6 assessment turn
        ↓
Persistent concept graph + evidence + spaced review
```

Three strict schemas separate diagnosis, teaching, and assessment. A lesson contains one to four synchronized steps; every step has narration, a notebook insight, and no more than four normalized annotations. Coordinates from the cropped context are validated and mapped back into the selected screen region. If localization is uncertain, the model is instructed to use fewer marks and request a tighter selection.

Learner memory is stored as evidence rather than a transcript: concept mastery, attempts, what the learner demonstrated, remaining shaky areas, and the next teaching strategy. The next diagnostic turn receives that compact profile so Aster✱ can truthfully say, for example, “You demonstrated softmax purpose; square-root scaling is still shaky.”

## Built with OpenAI

- **GPT-5.6 Terra** handles visual diagnosis and is the default spatial-lesson model.
- **GPT-5.6 Sol** is available as Precision mode for unusually dense pages.
- **GPT-5.6 Luna** assesses mastery answers without paying vision-model costs.
- **Responses API** accepts the screenshot and returns a strict structured lesson plan.
- **Codex** was used to research the problem and judging rubric, design the product system, implement the Swift app and landing page, debug packaging, and create the submission materials.

For the Build Week submission, add the public Codex session ID to `/feedback` and here before the deadline:

```text
Codex session ID: <add public session ID>
```

## Efficient API use

- macOS Speech Recognition and `AVSpeechSynthesizer` handle voice without an additional audio-model request.
- Only the selected region is downsampled to a maximum width of 1600 px.
- Diagnosis uses Terra with a 500-token cap; standard spatial lessons use Terra with a 1,400-token cap; answer assessment uses Luna with a 450-token cap.
- Precision mode is explicit rather than automatic.
- Settings shows per-session request and token usage, with direct links to OpenAI’s live usage and budget controls.

## Privacy and safety

- No continuous or hidden API surveillance.
- “Hey Aster” listening is off by default, visibly configurable, and uses macOS Speech Recognition only after the learner opts in.
- Follow mode visibly refreshes only the learner-selected region every two seconds on-device; a screen image is sent only after the learner asks.
- Capture state is visible in the interface.
- The API key is stored in macOS Keychain only after explicit validation and save, can be removed immediately from Settings, and is excluded from the repository.
- Every Responses API request sets `store: false`; Aster✱ never bundles or logs the key.
- Aster✱ teaches labeled educational anatomy; it does not interpret radiology, diagnose disease, or give medical advice.
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
| Technological Implementation | Multi-display/window capture, semantic cursor anchoring, recent-frame video context, Retina mapping, animated native overlay, global hotkey, strict Responses API schemas, adaptive learner model, conversational voice, embedded Desmos/Manim previews, action undo, explicit Keychain lifecycle, and session usage visibility |
| Design | One coherent Aster✱ system across macOS and responsive web; visible context/follow states; mandatory diagnostic choices; staged annotation choreography; voice, notebook, mastery, and memory states |
| Potential Impact | Removes screenshot/upload/context-switch friction from research papers, STEM notation, and anatomy diagrams while emphasizing comprehension rather than answer generation |
| Quality of Idea | OS-native spatial tutoring, cursor-as-context, cross-app teaching, and a constrained “demonstrate, never take over” agent contract |

See [`docs/DEMO_SCRIPT.md`](docs/DEMO_SCRIPT.md) for the sub-three-minute submission story and [`docs/EVALS.md`](docs/EVALS.md) for the annotation-quality evaluation plan.

## Safety boundaries

- Aster✱ deliberately does not provide general autonomous Mac control, submit graded work, or run model-authored Python. Cross-app content is previewed and copied for learner-controlled paste.
- Browser video controls are limited to the active HTML5 video in Safari/Chrome and may require the browser’s JavaScript-from-Apple-Events setting.
- Manim uses fixed local templates and requires a local Manim CLI installation.
- Every teaching turn requires the learner’s own validated OpenAI API key; there is no canned or keyless teaching path.
