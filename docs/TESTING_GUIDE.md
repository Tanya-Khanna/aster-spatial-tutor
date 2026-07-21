# Aster✱ end-to-end testing guide

This guide tests the downloadable macOS application, its landing page, and the complete learning loop from a clean install through a second learning session. It is written for a human tester who has not seen the code.

## What counts as a pass

Aster✱ passes only when it teaches the material actually selected, keeps its own interface out of the captured context, avoids doing the learner's work, and records mastery only after the learner answers an understanding check.

Do not mark a test as passed because the interface merely appeared. Verify the expected behavior and record evidence.

For every run, record:

- build version and download time;
- macOS version and Mac model;
- display arrangement and appearance mode;
- browser or source application;
- context mode;
- exact learner prompt;
- time to first diagnostic text;
- time to first teaching text;
- whether each annotation hit its intended target;
- API request and token totals shown in Settings → Account;
- pass, fail, or blocked;
- screenshot or screen recording for every failure.

## Requirements

- Apple Silicon Mac running macOS 13 or later. The current package is not a universal Intel binary.
- A fresh download from the [Aster✱ landing page](https://aster-spatial-tutor.tanyak897.chatgpt.site/).
- A valid user-owned OpenAI API key with a deliberately small project budget.
- Chrome or Safari for browser-video testing.
- Microphone and Speech Recognition access for voice tests.
- Optional: a second display.
- Optional: a local Manim CLI installation for the Manim rendering test.

The complete learning loop normally uses three API requests: diagnosis, lesson generation, and assessment. Context-selection and local-follow tests should use zero API requests until a question is submitted.

## Demo material

Open these before starting the corresponding test. These pages were selected because they provide public, stable, visually dense learning material.

| Material | Demo page | Recommended scope | Test question | What Aster✱ should recognize |
| --- | --- | --- | --- | --- |
| Research paper | [Attention Is All You Need PDF](https://arxiv.org/pdf/1706.03762), section 3.2 | Point on `√dₖ` | “Why are we dividing by the square root of the key dimension?” | Dot-product magnitude, dimension, and softmax saturation—not generic algebra |
| Physics equation | [Schrödinger equation](https://en.wikipedia.org/wiki/Schr%C3%B6dinger_equation) | Region around the time-dependent equation | “Could you explain this equation?” | `iℏ∂/∂t`, the state `|Ψ⟩`, and the Hamiltonian `Ĥ` |
| Anatomy | [OpenStax heart and blood flow](https://openstax.org/books/pharmacology/pages/16-1-introduction-to-the-heart-circulation-and-blood-flow) | Freehand Loop around the heart diagram | “Trace the path of blood through these chambers and valves.” | Labeled educational anatomy and flow direction; no diagnosis or clinical claims |
| Circuit | [Falstad Circuit Simulator](https://falstad.com/circuit/) | Region around a branch or component | “Why does current split here, and what stays conserved?” | Junction, branches, current flow, and conservation |
| Graph | [Desmos Graphing Calculator](https://www.desmos.com/calculator) with `y=a(x-h)^2` | Point on `h` or Region around the expression and graph | “How does changing `h` move this graph?” | Horizontal translation and the sign inside the parentheses |
| Code | [MDN `Array.prototype.reduce()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/reduce), “Try it” example | Region around the code block | “Why is `initialValue` passed here?” | Accumulator initialization and first callback behavior |
| Data visualization | [Our World in Data: Life expectancy](https://ourworldindata.org/grapher/life-expectancy) | Whole Screen or Region around the chart | “What does the shape of this chart show, and what can we not conclude from it?” | Trend, axes, comparison, and the distinction between observation and causation |
| Molecular diagram | [OpenStax: Drawing Chemical Structures](https://openstax.org/books/organic-chemistry/pages/1-12-drawing-chemical-structures) | Freehand Loop around one structure | “How does this shorthand preserve the molecule's bonding information?” | Atoms, bonds, omitted hydrogens, and structural shorthand |
| Video | [3Blue1Brown: But what is a neural network?](https://www.youtube.com/watch?v=aircAruvnKk) | Whole Screen with Video Context enabled | Pause on a neuron/activation diagram and ask “What is this layer doing to the inputs?” | The visible video frame plus available caption context |

Use the research-paper, Schrödinger, and anatomy pages for the required release smoke test. The remaining pages provide broader subject coverage.

## Phase 1 — automated preflight

From the repository root, run:

```bash
cd macos
swift test
swift build -c release
zsh scripts/package.sh
cd ..
npm test
```

Pass when:

- every Swift test passes;
- the release build succeeds;
- `public/Aster-macOS.zip` is regenerated;
- the landing-page build and rendered-HTML tests pass;
- the worktree contains only changes intentionally being tested.

Also inspect the ZIP and confirm it contains:

- `Aster.app/Contents/MacOS/Aster`;
- `Aster.app/Contents/Resources/Aster.icns`;
- `Aster.app/Contents/Info.plist`;
- a code signature.

## Phase 2 — prepare a genuinely fresh test

Deleting an `.app` does not terminate a running macOS process, and reinstalling an app does not automatically remove Keychain, UserDefaults, Application Support, or privacy permissions.

To test first-run behavior safely:

1. Open the existing Aster✱ Settings → Learning and select **Reset learner memory**.
2. Open Settings → Account and select **Remove API key / Sign out**.
3. Choose **Quit Aster✱** from its menu-bar item. Do not merely close its panel or move the `.app` to Trash while it is running.
4. In System Settings → Privacy & Security → Screen & System Audio Recording, remove old Aster entries if the permission flow itself is under test.
5. Move the old `/Applications/Aster.app` to Trash.
6. Download the ZIP again from the landing page and expand it in Downloads.

Pass when Activity Monitor shows no old Aster process before launching the new copy.

## Phase 3 — Gatekeeper and relocation

1. Launch `Aster.app` from Downloads.
2. If Gatekeeper shows “Apple could not verify Aster,” close the dialog.
3. Open System Settings → Privacy & Security, scroll to Security, and choose **Open Anyway** for Aster.
4. Reopen Aster.
5. Verify that the relocation screen appears before normal onboarding.
6. Choose **Move to Applications & Relaunch**.

Pass when:

- Aster clearly explains why a stable Applications location is required;
- the app exists at `/Applications/Aster.app`;
- the Downloads copy exits;
- the Applications copy relaunches;
- onboarding does not continue inside a randomized translocation path;
- the Dock and Finder show the coral Aster icon.

Manual fallback: drag Aster to Applications, quit every old Aster process, and reopen `/Applications/Aster.app`.

## Phase 4 — onboarding and permissions

### Introduction

1. Verify the first screen explains the product in plain language.
2. Resize or maximize the window.
3. Move forward and backward through onboarding.

Pass when the layout uses the available space without clipping, the teaching preview remains readable, and navigation retains the current step.

### Screen Recording

1. Choose the Screen & System Audio Recording permission action.
2. Grant access to `/Applications/Aster.app`.
3. Return to Aster and choose **I granted access — Check again**.
4. Restart if macOS requests it.

Pass when the status changes to Allowed and Aster can capture a selected region.

Failure-recovery test:

1. Deny or remove Screen Recording access.
2. Attempt to use a context mode.
3. Open Aster Settings → Permissions.

Pass when Aster provides the complete recovery sequence without clipped instructions: remove stale entries, add the current Applications copy, enable it, check again, and restart.

### Optional voice permissions

1. Continue without granting Microphone or Speech Recognition.
2. Confirm typed questions remain usable.
3. Later grant both from Settings → Permissions.

Pass when voice is clearly optional and permission denial never blocks typed tutoring.

### API key

1. Leave the field empty and attempt to continue.
2. Enter a malformed key.
3. Enter a valid key and choose **Validate and save**.

Pass when:

- empty and malformed values are rejected;
- the key is masked;
- a key is saved only after successful validation;
- the UI clearly changes to authenticated;
- no key appears in logs, source, screenshots, or error text;
- no canned lesson is available without a key.

## Phase 5 — first launch and global activation

1. Finish onboarding and open a normal Chrome, Safari, Preview, or PDF window.
2. Press **Option–Space** while that other application is frontmost.
3. Repeat from a full-screen browser Space.
4. If available, repeat with the pointer on a second display.
5. Drag the Aster bar to a new position.
6. Collapse and expand the transcript drawer.
7. Switch applications while Aster remains open.

Pass when:

- the bar appears over the current material without switching to the desktop;
- the source application remains frontmost;
- the bar accepts typing;
- the bar follows the active Space and display;
- it remains movable and visible until explicitly closed;
- the overlay is click-through and the underlying material remains interactive.

## Phase 6 — privacy before submission

1. Open Aster and select each context mode without submitting a question.
2. Wait at least ten seconds while scrolling or moving the cursor.
3. Open Settings → Account and inspect the session request count.

Pass when:

- the bar says **LOCAL ONLY · NOTHING SENT** before submission;
- local following and selection create zero API requests;
- the badge changes only after the learner submits;
- Aster's own panel, transcript, cursor chrome, and overlays are absent from captured learning context.

Release-blocker check: if diagnosis mentions “the Aster panel,” “text behind the panel,” prior Aster messages, or other Aster UI, record a failure. The selected source—not Aster—is the only valid visual context.

## Phase 7 — all four context modes

### Whole Screen

1. Open the life-expectancy chart.
2. Use Whole Screen and submit the recommended chart question.

Pass when Aster uses the visible chart and axes, not unrelated browser chrome. Whole Screen should be selected by default on a newly opened bar.

### Point

1. Open the attention paper at section 3.2.
2. Select Point and click exactly on `√dₖ`.
3. Move the cursor somewhere else before asking.
4. Submit the recommended question.

Pass when the quiet coral pin remains on `√dₖ`, the semantic target does not follow the moved cursor, and teaching marks originate from the pinned term.

### Region

1. Open the Schrödinger equation page.
2. Draw a tight box around only the time-dependent equation.
3. Submit “Could you explain this equation?”

Pass when the diagnostic recognizes the equation. Good diagnostic options concern time evolution, the Hamiltonian, or the state vector. Object-disambiguation options such as “the text behind the panel” fail the test.

### Freehand Loop

1. Open the OpenStax heart diagram.
2. Draw a loop around only the heart chambers and valves.
3. Submit the recommended anatomy question.

Pass when everything outside the loop is removed from the sent image, annotations remain inside the selected scope, and the explanation stays educational rather than clinical.

### Tracking and recovery

For Point and Region:

1. Scroll slightly after locking the context.
2. Resize the source window.
3. Zoom the page.

Record whether the intended object remains correctly anchored. A temporary “anchor hidden” state is acceptable; silently jumping to unrelated text is not.

## Phase 8 — text, voice, and wake phrase

### Typed question

1. Disable **Listen when Aster✱ opens**.
2. Open Aster, type a question, and press Return.

Pass when one question is submitted and the composer clears.

### Immediate voice conversation

1. Enable **Listen when Aster✱ opens** and **Send after a short pause**.
2. Press Option–Space.
3. Speak one complete question and pause.

Pass when live transcription appears in the composer and the question is submitted once after approximately one second of silence. The microphone must be able to stop and start again without crashing.

### Conversational follow-up

1. Enable **Conversational follow-ups**.
2. Complete a lesson until Aster asks the independent understanding check.
3. Answer aloud.

Pass when Aster listens again at the check, submits the answer once, and assesses it.

### “Hey Aster”

1. Confirm the wake phrase is off by default on a clean install.
2. Enable it in Settings → Voice.
3. Use **Test “Hey Aster”** and confirm the listening indicator.
4. With another application frontmost, say “Hey Aster, explain this diagram.”
5. Disable the wake phrase again.

Pass when Aster opens without a Space switch, preserves the words after “Hey Aster” as the question, hands off to normal listening, and stops wake listening immediately when disabled.

## Phase 9 — diagnosis behavior and streaming

Use the Schrödinger Region test.

1. Submit the question and watch the diagnostic card.
2. Confirm text appears progressively rather than only after the full response completes.
3. Inspect the 2–3 primary choices.
4. Expand **None of these — here's what I'm stuck on**, type “I understand the symbols, but not why this determines time evolution,” and continue.
5. Repeat in a new turn and choose **Skip, just explain**.

Pass when:

- diagnosis asks one short conceptual question before explaining;
- choices distinguish plausible misconceptions rather than identify UI objects;
- the custom text is reflected in the subsequent teaching;
- Skip proceeds without pretending the learner selected a misconception;
- no explanation appears before the diagnostic unless Skip was selected;
- Settings → Account records Ask → first diagnostic text latency.

## Phase 10 — spatial teaching

Complete the attention-paper lesson.

Verify:

- the first narration appears progressively while the structured lesson continues generating;
- narration, notebook text, and annotations describe the same idea;
- circles surround single objects;
- highlights cover meaningful spans;
- arrow endpoints land on their intended source and destination;
- labels sit beside rather than over source material;
- no step shows more than four annotations;
- dense-diagram simplification, if used, preserves the causal structure;
- no annotation appears outside the selected display or scope;
- voice and drawings advance as one staged lesson;
- Settings → Account records Choice → first teaching text latency.

Use the teaching controls:

1. Select Previous.
2. Select Replay.
3. Select Next.
4. Move the narration-speed slider toward the tortoise and then the hare.
5. Switch between Transcript and Notebook.

Pass when replay redraws and renarrates the current step, navigation never skips or duplicates a step, speed changes are audible, and Notebook contains the durable insight rather than the entire chat.

## Phase 11 — fade, independent check, assessment, and adaptation

1. Let the final teaching step finish or select Next on the final step.
2. Observe the drawings.
3. Answer the displayed understanding check incorrectly but thoughtfully.
4. Repeat another lesson and answer correctly with reasoning.

Pass when:

- visual scaffolding fades after the final teaching step;
- Aster asks a prediction or transfer-style question rather than “Did you understand?”;
- the learner can answer by voice or text;
- Aster assesses reasoning against explicit success criteria;
- feedback identifies demonstrated understanding and a specific shaky area;
- a score and next teaching strategy are produced;
- **Explain more simply** and **Use an analogy** become available after an incorrect answer;
- **Simpler**, **Follow-up**, and **Challenge me** work during the check state;
- viewing a lesson without answering does not change mastery;
- mastery changes only after an assessed learner answer.

API accounting: a complete diagnosis → lesson → assessment loop should add three completed requests to the session count.

## Phase 12 — learner memory and restart

1. Complete and answer a lesson about attention scaling.
2. Open Settings → Learning and record Concepts remembered, Understanding checks, and Reviews ready.
3. Quit Aster completely with Command–Q or the menu-bar Quit command.
4. Reopen `/Applications/Aster.app`.
5. Return to the attention paper and ask a related question.

Pass when:

- the transcript starts as a fresh process session;
- the compact learner profile survives;
- the next diagnosis references only evidence actually demonstrated;
- it distinguishes understood ideas from shaky ones;
- it does not claim that the learner mastered something merely because Aster explained it.

### Reset learner memory

1. Choose Settings → Learning → Reset learner memory.
2. Confirm the destructive prompt.
3. Quit and reopen.

Pass when concept evidence, checks, review schedule, and learning preferences are removed while the API key remains.

### Current spaced-review boundary

The code calculates review dates, changes intervals from assessment performance, persists them, and reports a **Reviews ready** count. Automated tests cover that scheduler.

The current app does not yet proactively resurface a due concept with a learner-facing “why this is back” explanation. Do not mark proactive spaced review as shipped until that experience exists and has its own acceptance test.

## Phase 13 — browser video context

Browser control is limited to an active HTML5 video in Safari or Chrome. The browser may require permission to execute JavaScript from Apple Events.

1. Open the 3Blue1Brown video in Safari or Chrome.
2. Pause on a clear neuron or activation diagram.
3. Open Aster with Whole Screen.
4. Confirm Video Context does not turn on merely because pixels are changing.
5. Enable Video Context explicitly using the video button.
6. Ask the recommended question by voice or text.
7. Confirm the badge reads **VIDEO CONTEXT · LOCAL** and offers a visible off control.
8. Complete the understanding check.

Pass when:

- Aster retains at most four recent frames locally;
- frames and captions are sent only after submission;
- Aster pauses at the teaching moment when browser control succeeds;
- the explanation concerns the visible sequence rather than one unrelated frame;
- annotations remain relevant to the newest frame;
- playback resumes after the understanding check when Aster paused it;
- turning Video Context off returns to one current frame.

If browser automation permission is unavailable, record pause/resume as blocked rather than failing visual understanding.

## Phase 14 — bounded teaching actions

### Permission modes

In Settings → General, test **Ask every time**, **Internal teaching tools only**, and **Never**.

Pass when Never blocks tool execution and Ask every time presents a confirmation before a suggested tool runs.

### Desmos

1. Use the parabola demo and ask Aster to show how changing `h` moves the graph.
2. If Aster suggests Desmos, select **Open Desmos sandbox**.
3. Approve the preview.

Pass when a separate learner-controlled sandbox opens with the previewed comparison and sliders. Aster must not edit the learner's original Desmos page or submit work.

### Manim

1. Install Manim locally if this optional test is in scope.
2. Use a vector, circuit, field, geometry, wave, molecule, limit, matrix, or derivative prompt that benefits from animation.
3. Approve the bounded template preview.

Pass when Aster runs a fixed local template, times out safely, shows the rendered preview, and never executes arbitrary model-authored Python. Without Manim installed, it must show a useful error.

### Present but not currently exposed as complete UI flows

The code contains local scratch work, zoomable context, copy-for-paste typing preview, and undo actions. It does not currently expose all of them through a stable end-user control path. Treat these as implementation groundwork—not fully shipped manual features—until buttons, permission copy, and acceptance paths are present.

General autonomous Mac control, silent clicking, automatic typing, form submission, and graded-work completion are intentionally out of scope and must not occur.

## Phase 15 — settings and key lifecycle

Open Settings with the gear and Command–Comma. Test every pane.

### General

- Toggle High-precision reasoning and restart.
- Change the action-permission mode and restart.

Pass when values persist. Precision mode should retain more image detail and use the explicit precision model; it should never turn on automatically.

### Voice

- Change narration speed.
- Toggle Listen on open, Send after pause, Conversational follow-ups, and Hey Aster.
- Restart after each group of changes.

Pass when values persist and the UI remains legible in light and dark appearance.

### Permissions

- Verify current Screen Recording, Microphone, and Speech states.
- Deny and recover each permission.

Pass when required versus optional permissions are unmistakable.

### Learning

- Verify concepts and checks change only after assessments.
- Reset memory and verify persistence behavior described above.

### Account

- Verify authenticated and unauthenticated states.
- Verify request count, input tokens, output tokens, and both latency measurements update.
- Open live usage and budget links.
- Remove the API key, confirm, and restart.

Pass when removal immediately deletes the Keychain item, returns to unauthenticated onboarding, and no question can trigger a canned lesson.

Reinstall note: macOS normally preserves Keychain, UserDefaults, Application Support, and TCC permissions when only the `.app` bundle is deleted. Use Aster's explicit sign-out and memory-reset controls when testing a clean state.

## Phase 16 — errors and recovery

Test these conditions one at a time:

- no API key;
- malformed or revoked key;
- network disconnected;
- OpenAI rate or budget limit reached;
- Screen Recording denied;
- Microphone denied while typing remains available;
- source window closed after selection;
- target scrolled off screen;
- malformed or incomplete structured model response;
- Manim missing;
- app launched from Downloads or a quarantined path.

Pass when Aster draws nothing from an incomplete lesson, never crashes, gives a concise recovery action, and preserves unrelated learner data.

## Phase 17 — visual, display, and accessibility quality

Repeat the smoke flow in:

- macOS Light appearance;
- macOS Dark appearance;
- a narrow non-maximized source window;
- a maximized source window;
- a full-screen browser;
- each attached display;
- increased display scaling if available.

Verify:

- readable contrast in learner and tutor bubbles;
- no clipped permission or diagnostic text;
- consistent Aster✱ coral branding and app icon;
- the bar does not cover its own selected target after being moved;
- annotation coordinates remain correct across Retina scale factors;
- keyboard focus enters the composer;
- Return submits once;
- Escape clears lesson annotations;
- standard controls expose understandable VoiceOver labels;
- reduced-motion users can still understand state changes.

## Phase 18 — landing page and download

Open the production landing page on desktop and mobile-width browsers.

Verify:

- the production URL opens in a private/incognito browser where the tester is not signed in to the owner's ChatGPT account;
- all three download calls-to-action fetch the same current `Aster-macOS.zip`;
- the downloaded ZIP expands and launches;
- hero content, navigation anchors, subject switcher, teaching loop, privacy section, setup instructions, and final CTA render correctly;
- setup instructions accurately describe Gatekeeper, Open Anyway, relocation to Applications, permissions, and API-key setup;
- no “Demo mode” or keyless-teaching claims remain;
- the social preview and app icon are present;
- the page is keyboard navigable and has no horizontal overflow;
- the live site matches the committed source and the ZIP hash expected for the release.

## Subject-coverage pass

Run at least one question on every demo material row. Score each response from 1–5 for:

- correct object identification;
- conceptual accuracy;
- spatial annotation accuracy;
- clarity of narration;
- useful diagnostic choice;
- useful independent check;
- restraint—teaching without completing graded work.

Release target: median score at least 4 in every category, no clinical claim, no annotation outside the source, and no Aster UI in model context.

## Current capability boundaries to report honestly

These should not be presented as fully shipped until their tests become passable:

- proactive spaced-review resurfacing with a “why this is back” explanation;
- a visible New conversation action that clears the entire transcript and lesson state;
- guaranteed self-window exclusion across every macOS capture path—the Schrödinger test is the release gate for the currently observed regression;
- general autonomous Mac control;
- unrestricted model-generated Manim/Python execution;
- automatic typing into other applications;
- a stable UI for scratchpad, zoom, typing preview, and full undo history;
- an exposed selected-window targeting control;
- universal Intel support and Apple notarization;
- persistent chat history or screenshot logs;
- guaranteed semantic tracking through arbitrary scroll, zoom, and dynamic-layout changes;
- proactive background tutoring while Aster is closed.

## Final release gate

Do not publish a judge-facing build unless all required items pass:

- automated preflight is green;
- fresh download reaches onboarding and relocates successfully;
- Screen Recording recovery works on the exact packaged copy;
- Option–Space works over Chrome, Preview/PDF, full screen, and a second display when available;
- all four context modes send only the intended content;
- Aster's own UI is excluded from model context;
- voice and typed submission both work;
- diagnosis choices are conceptual and both learner escapes work;
- question and first narration stream progressively;
- annotations hit the intended objects;
- fade → independent check → assessment completes end to end;
- evidence persists across quit and reopen without persisting chat;
- evidence-only mastery is preserved;
- video context is explicit, local before submission, and visibly removable;
- bounded action permissions are respected;
- sign-out, memory reset, and error recovery work;
- landing-page downloads match the tested ZIP;
- the judge-facing landing page is accessible without the owner's signed-in session;
- every known limitation is disclosed rather than implied as complete.

## Bug-report template

```text
Title:
Build/version:
macOS and Mac:
Source app/site:
Display and appearance:
Context mode:
Voice or text:
Exact question:
Expected:
Actual:
First diagnostic latency:
First teaching latency:
Session request/token counts:
Reproducibility: __ / 3 attempts
Screenshot or recording:
Additional notes:
```
