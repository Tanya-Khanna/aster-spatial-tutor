# Spatial teaching evaluation

Aster’s main technical risk is not eloquence. It is whether an annotation lands on the right target and whether the teaching turn improves understanding. The evaluation therefore separates **grounding**, **pedagogy**, and **interaction reliability**.

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

- **Target hit rate:** percentage of circles/highlights whose center lies inside an acceptable target.
- **IoU:** overlap between the annotation rectangle and the expert target box.
- **Arrow endpoint error:** normalized distance from the returned endpoint to the nearest acceptable anchor.
- **Abstention quality:** when the target is genuinely ambiguous, does Aster use fewer annotations and ask the learner to point again?

Initial release gate: at least 90% target hit rate on the curated demo set, zero annotations outside the visible screen, and no more than four marks per turn.

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

- global hotkey opens Aster from another app;
- overlay remains visible across focus changes;
- overlay is click-through and does not block the source app;
- `Esc` or closing the panel clears annotations;
- denied permissions produce a useful recovery message;
- microphone can start, stop, and start again without an input-tap crash;
- app refuses a live request after the $4.80 reserve threshold;
- API key never appears in process logs or repository files.

## Comparison experiment

For five visual questions, compare two flows with the same learner:

1. screenshot → separate text chat → return to source;
2. Aster hotkey → spatial teaching turn → mastery check.

Record time-to-first-useful-explanation, number of context switches, and mastery-question accuracy. With a small hackathon sample this is directional rather than statistically conclusive, so report raw observations and avoid claiming measured population impact.

## Failure policy

- If screen localization confidence is low, do not invent a target; ask the learner to point more tightly.
- If the lesson schema fails to decode, show a concise retry message and draw nothing.
- If Screen Recording permission is absent, explain exactly where to grant it.
- If a page appears clinical or diagnostic, decline interpretation and offer general educational anatomy instead.
