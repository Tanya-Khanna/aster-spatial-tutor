# Spatial teaching evaluation

Aster✱’s main technical risk is not eloquence. It is whether an annotation lands on the right target and whether the teaching turn improves understanding. The evaluation therefore separates **grounding**, **pedagogy**, and **interaction reliability**.

## Benchmark set

Build a small, redistributable set of 30 screens:

- 10 math and physics screens: equations, graphs, and a circuit schematic.
- 10 research-paper screens: dense notation, multi-column text, and one figure/table.
- 10 labeled anatomy screens: organs, tissue diagrams, and directional processes.

For each screen, store:

- the learner question;
- a cursor point or region;
- one to four acceptable target boxes;
- the misconception or learning objective;
- prohibited behavior, such as revealing a final graded answer or making a clinical claim.

Do not store private learner content in the benchmark.

## Metrics

### 1. Annotation target accuracy

The Swift suite includes a deterministic 400-placement coordinate benchmark spanning narrow equation targets and larger diagram regions. It verifies crop-to-display mapping before pixel rounding. Manual evaluation additionally covers OCR anchors, visual-object anchors, window movement, resize, scroll, zoom, and every attached display.

- **Target hit rate:** percentage of circles/highlights whose center lies inside an acceptable target.
- **IoU:** overlap between the annotation rectangle and the expert target box.
- **Arrow endpoint error:** normalized distance from the returned endpoint to the nearest acceptable anchor.
- **Abstention quality:** when the target is genuinely ambiguous, does Aster✱ use fewer annotations and ask the learner to point again?

Initial release gate: at least 90% target hit rate on the curated benchmark set, zero annotations outside the visible screen, and no more than four marks per turn.

### 2. Teaching quality

Two reviewers score each turn from 1–5:

- identifies the relevant visual object;
- explains the causal or structural idea intuitively;
- avoids unnecessary solution completion;
- coordinates voice, note, and marks without contradiction;
- asks a useful mastery question;
- stays within anatomy safety boundaries.

Initial release gate: median score ≥4 on every dimension and zero clinical/diagnostic statements.

### 3. Product reliability

- global hotkey opens Aster✱ from another app;
- the ✱ lands beside the cursor, visibly enters its reading state, and morphs from the same origin into each mark;
- the final ✱ bookmark is clickable, stays attached to the taught concept, and reopens the correct lesson;
- opt-in “Hey Aster” activates Aster✱, hands off to normal conversational listening, and returns to wake listening afterward;
- wake listening is off by default and stops immediately when disabled;
- overlay remains visible across focus changes;
- overlay is click-through and does not block the source app;
- `Esc` or closing the panel clears annotations;
- denied permissions produce a useful recovery message;
- if Screen & System Audio Recording is enabled for a stale ad-hoc build, the app identifies the current copy, refreshes status after activation, and offers an exact-copy restart;
- if the app is launched from Downloads, App Translocation, or with quarantine metadata, onboarding is blocked until the one-click Applications relocation and relaunch succeeds;
- the welcome window launches maximized and its first-run and home compositions expand at wide display sizes without clipping;
- Settings opens as one compact native window, restores the last toolbar pane, supports Command–Comma, and deep-links permission recovery without interrupting onboarding;
- General, Voice, Permissions, Learning, and Account controls retain their values across app restarts;
- microphone can start, stop, and start again without an input-tap crash;
- API key never appears in process logs or repository files.
- an unauthenticated teaching request opens key onboarding and never produces canned content;
- saving validates before Keychain persistence, and Remove API key deletes the Keychain item immediately;
- the interface makes authenticated and unauthenticated states unmistakable;
- every Responses API body contains `store: false`.

### 4. Adaptation and memory

- a diagnostic choice occurs before every new explanation;
- an answer is assessed against the lesson’s explicit success criteria;
- mastery changes only after learner evidence, never merely after viewing a lesson;
- demonstrated strengths and shaky areas survive app restart;
- the next diagnostic accurately references stored evidence without inventing prior knowledge;
- “Explain more simply” changes the requested strategy while preserving the concept and selected context.

## Comparison experiment

For five visual questions, compare two flows with the same learner:

1. screenshot → separate text chat → return to source;
2. Aster✱ hotkey → spatial teaching turn → mastery check.

Record time-to-first-useful-explanation, number of context switches, and mastery-question accuracy. With a small hackathon sample this is directional rather than statistically conclusive, so report raw observations and avoid claiming measured population impact.

## Failure policy

- If screen localization confidence is low, do not invent a target; ask the learner to point more tightly.
- If the lesson schema fails to decode, show a concise retry message and draw nothing.
- If Screen & System Audio Recording permission is absent, explain exactly where to grant it.
- If a page appears clinical or diagnostic, decline interpretation and offer general educational anatomy instead.
