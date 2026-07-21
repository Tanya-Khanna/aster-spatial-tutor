# Aster✱ repository handoff

Verified against the repository on **2026-07-21**. This file distinguishes repository evidence from manual behavior that still needs a final smoke test.

## Repository state

- Repository: <https://github.com/Tanya-Khanna/aster-spatial-tutor> (**public**, verified with GitHub CLI)
- Branch: `main`
- Application/source baseline imported before release packaging: `2bde29471da3f94b0c48f035488cab5c930e1cfb`
- Release: Aster✱ `0.5.2` (`CFBundleVersion` `17`), macOS 13+, Apple Silicon
- Download artifact: `public/Aster-macOS.zip`
- ZIP SHA-256: `e065c89d44182670cdbd3260a9f4f9a40d8c2b5a735478836b30c116a830d191`

The SHA above is the immutable application baseline immediately before the HANDOFF-only commit. After cloning, use `git rev-parse HEAD` for the final handoff commit; a commit cannot contain its own SHA because adding that SHA changes the commit.

## 1. What the project does

Aster✱ is a native SwiftUI/AppKit spatial tutor for macOS. Option-Space (or the opt-in on-device “Hey Aster” wake phrase) opens a movable, non-activating tutor bar over the learner's current app and Space. The learner scopes context using **Whole Screen**, **Point**, **Region**, or **Freehand Loop**, then asks by text or voice.

No OpenAI request occurs while selecting or locally following context. On explicit submission, Aster sends the chosen visual context and question, diagnoses before explaining, generates a staged lesson with voice and on-screen annotations, asks an independent check, assesses the answer, and stores compact learner evidence locally. A user-owned OpenAI API key is required; there is no demo/keyless lesson path.

## 2. Exact end-to-end demo flow

This is the implemented hero path. It makes three Responses API calls: diagnosis, lesson, and assessment.

1. Download `Aster-macOS.zip` from the landing page and expand it.
2. On the ad-hoc-signed build, dismiss Gatekeeper's verification dialog, open **System Settings → Privacy & Security**, choose **Open Anyway**, and relaunch.
3. From Downloads, use **Move to Applications & Relaunch**. Aster must run from `/Applications/Aster.app` before permission onboarding.
4. Grant **Screen & System Audio Recording**. Microphone and Speech Recognition are optional if using text.
5. Enter a user-owned OpenAI API key, validate it, and explicitly save it to Keychain.
6. Open [Attention Is All You Need, section 3.2](https://arxiv.org/pdf/1706.03762) in a normal browser/PDF window.
7. Press **Option-Space**. The bar should appear over that window without activating Aster or switching Spaces.
8. Choose **Point**, click `√dₖ`, then move the cursor away. The coral pin should stay at the click and the UI should still say the context is local.
9. Ask by text or voice: “Why are we dividing by the square root of the key dimension?” Only now is context sent.
10. Choose the conceptual diagnostic option about softmax/scaling. The learner may instead enter **None of these — here's what I'm stuck on** or use **Skip, just explain**.
11. Watch the first narration stream, then the structured lesson present 1–4 synchronized steps. Voice, notebook text, and bounded overlay marks should describe the same visual object.
12. After the final step, drawings fade and Aster asks an independent prediction/transfer question. Answer by text or voice.
13. Luna assesses the reasoning against explicit success criteria; Aster reports feedback and updates mastery, strengths, shaky areas, review timing, and next strategy.
14. Quit and reopen Aster. The transcript should be fresh, while learner evidence remains visible in Settings → Learning and can inform the next diagnosis.

Required pre-submission breadth smoke: repeat with a Region around the time-dependent [Schrödinger equation](https://en.wikipedia.org/wiki/Schr%C3%B6dinger_equation) and a Freehand Loop around the [OpenStax heart diagram](https://openstax.org/books/pharmacology/pages/16-1-introduction-to-the-heart-circulation-and-blood-flow). Full acceptance steps are in `docs/TESTING_GUIDE.md`.

## 3. Architecture and important files

### Native macOS app

- `macos/Sources/Aster/AsterApp.swift` — AppDelegate, menu bar, welcome/settings windows, non-activating tutor panel, positioning across Spaces/displays.
- `macos/Sources/Aster/TutorModel.swift` — application state machine and the select → diagnose → teach → check → assess → remember flow.
- `macos/Sources/Aster/OpenAIClient.swift` — Responses API requests, SSE streaming, strict schemas, model routing, image preparation, `store: false`.
- `macos/Sources/Aster/Models.swift` — context, API, lesson, annotation, assessment, and learner-memory models.
- `macos/Sources/Aster/Views.swift` — onboarding, tutor surface, settings panes, diagnostic escapes, transcript/notebook, errors.
- `macos/Sources/Aster/ContextSelectionController.swift` — Point, Region, Freehand Loop, and internal window-target selection.
- `macos/Sources/Aster/ScreenCaptureService.swift` — CoreGraphics display/window capture, cropping/masking, and Aster-window exclusion during internal capture.
- `macos/Sources/Aster/SemanticAnchorTracker.swift` — local Vision OCR/object tracking for best-effort anchor recovery.
- `macos/Sources/Aster/OverlayController.swift`, `AsterGlyphRenderer.swift`, `AsterStarCompanion.swift` — click-through drawing panels and ✱/annotation animation.
- `macos/Sources/Aster/VoiceServices.swift` — Speech framework input, wake phrase, and AVSpeechSynthesizer narration.
- `macos/Sources/Aster/BrowserVideoService.swift` — bounded Safari/Chrome HTML5-video state, captions, pause/resume, and recent-frame context.
- `macos/Sources/Aster/LearnerMemoryStore.swift` — Codable JSON learner profile in Application Support; evidence-only updates and SM-2-inspired review dates.
- `macos/Sources/Aster/KeychainStore.swift` — API-key lifecycle.
- `macos/Sources/Aster/ToolActionService.swift` — learner-approved Desmos sandbox, fixed Manim templates, and internal reversible-action groundwork.
- `macos/Sources/Aster/AppRelocationService.swift` — translocation/quarantine guard and Applications relocation.
- `macos/Tests/AsterTests/AsterTests.swift` — 21 Swift tests, including a deterministic 400-placement mapping loop.

### Website, packaging, and documentation

- `app/page.tsx`, `app/globals.css`, `app/layout.tsx` — landing page and browser simulation.
- `tests/rendered-html.test.mjs` — rendered-site and source-contract tests.
- `public/Aster-macOS.zip` — artifact used by all landing-page download CTAs; `app/page.tsx` currently uses `?v=0.5.2`.
- `macos/scripts/package.sh` — release build, app assembly, icon generation, ad-hoc signing, and ZIP refresh.
- `.openai/hosting.json` — existing OpenAI Sites project ID. Reuse it; do not create a duplicate project.
- `README.md`, `macos/README.md`, `docs/DEMO_SCRIPT.md`, `docs/EVALS.md`, `docs/TESTING_GUIDE.md` — product truth, demo, evaluation plan, and full QA plan.

`db/`, `drizzle/`, `examples/d1/`, and `app/chatgpt-auth.ts` are unused starter scaffolding for the current product. Native learner memory is JSON, not Drizzle/D1. Do not claim these files back the app's memory.

## 4. Completed during Build Week

Repository history spans July 18–21, 2026: the native prototype and landing page, diagnosis-first adaptive loop, native overlay and ✱ animation, global hotkey, four context modes, local following/capture, voice conversation, strict model contracts, learner memory, bounded Desmos/Manim actions, first-run onboarding, Keychain account lifecycle, Settings, permissions and relocation recovery, app icon, packaging, tests/evaluation docs, and Sites deployment. July 21 commits concentrate on panel behavior, scoped capture, wake/voice flow, streaming/performance, self-UI exclusion, transcript reset, stable Point pinning, and the `0.5.2` artifact.

## 5. What GPT-5.6 does

- **Diagnosis:** `gpt-5.6-terra`, low reasoning, low-detail image downscaled to at most 1024 px, 450 output tokens. Returns strict `diagnostic_plan` JSON and is instructed not to teach yet.
- **Teaching:** Terra with low reasoning by default; `gpt-5.6-sol` with medium reasoning only in explicit Precision mode. Standard images are capped near 1024 px; Precision retains the prepared original. Returns strict `spatial_lesson` JSON: 1–4 steps, narration, notebook insight, 0–4 known annotation types per step, optional bounded diagram primitives, and an independent check.
- **Assessment:** `gpt-5.6-luna`, low reasoning, text-only, 450 output tokens. Returns strict `mastery_assessment` JSON and may update memory only from demonstrated evidence.

All three calls use the Responses API with `stream: true`, `store: false`, a safety identifier, and schema-constrained `text.format`. Diagnostic question and first narration are revealed incrementally while complete JSON continues generating.

## 6. What Codex helped implement

Based on the Build Week Codex session history (not independently attributable from Git authorship), Codex paired on the SwiftUI/AppKit app, non-activating overlay windows and hotkey, screen/context capture and coordinate mapping, permissions and relocation recovery, voice flow, three Responses API schemas, overlay renderer, local learner evidence, bounded tool previews, tests, packaging, landing page, and Sites deployments. Major product-directed revisions included changing memory from conversation history to learner evidence, making diagnosis a separate turn, making the ✱ the drawing origin, removing demo mode, adding a real key lifecycle, and keeping the tutor panel over the learner's active Space.

The product decisions remained human-owned: diagnosis before explanation, explicit local-before-send privacy, evidence-only mastery, teacher restraint, and the Aster✱ interaction/brand.

## 7. Install, run, test, package, and deploy

Requirements: macOS 13+, Apple Silicon, Swift/Xcode command-line tools, and Node.js 22.13+.

```bash
git clone https://github.com/Tanya-Khanna/aster-spatial-tutor.git
cd aster-spatial-tutor
npm ci
```

Run native development build:

```bash
cd macos
swift run Aster
```

Run website locally:

```bash
npm run dev
```

Full automated preflight and package:

```bash
cd macos
swift test
swift build -c release
zsh scripts/package.sh
cd ..
npm test
```

Packaging writes `macos/dist/Aster.app` and refreshes `public/Aster-macOS.zip`. Check `git status` and commit the refreshed ZIP whenever application code/version changes.

Deployment has **no repository CLI command**. Run `npm test`, push the exact source commit to GitHub, then use the Codex **Sites** hosting workflow with project ID from `.openai/hosting.json` to save and deploy that pushed SHA. Do not invent `npm run deploy`, call `create_site`, or expose Sites bypass credentials. A different Codex account may need access granted to the existing Sites workspace/project before it can deploy.

## 8. Environment variables

**Required application/build environment variables: none verified.** In particular, the native app does not read `OPENAI_API_KEY`; the learner enters the key in onboarding and it is saved in macOS Keychain only after validation.

Recognized but not user-required build-tool variables are `CODEX_SANDBOX`, `WRANGLER_WRITE_LOGS`, `WRANGLER_LOG_PATH`, and `MINIFLARE_REGISTRY_PATH`; repository scripts/config set or detect them. Sites injects `ASSETS` and `IMAGES` Worker bindings. `DB` is referenced by unused D1 scaffolding, while `.openai/hosting.json` has `d1: null`; it is not required by the current landing page.

GitHub CLI and Sites deployment use account authentication, not repository environment variables. Never add an API key or Sites token to `.env`, source, logs, or the repo.

## 9. Deployment URLs and services

- GitHub: <https://github.com/Tanya-Khanna/aster-spatial-tutor>
- Landing page: <https://aster-spatial-tutor.tanyak897.chatgpt.site>
- OpenAI Sites project: `appgprj_6a5bcc874b888191921363cdbd2340ba`
- Live Sites version and source commit: verify from the Sites project before each submission handoff; deployments are immutable snapshots and do not update automatically from GitHub.
- Runtime AI service: OpenAI Responses API using the learner's own key
- Local/platform services: CoreGraphics, Vision, Speech, AVFoundation, Keychain, WebKit
- Optional teaching services: Desmos web API; local Manim CLI

The release site is intended to be public. Verify an incognito request returns HTTP 200 before sharing it with judges.

## 10. Known limitations and unreliable paths

- Current package is Apple Silicon only, ad-hoc signed, and not notarized. Gatekeeper, quarantine relocation, and TCC permission repair remain part of first launch.
- Deleting the app does not delete Keychain, UserDefaults, learner memory, or macOS TCC permissions. Use in-app Sign out/Reset memory and remove the privacy entry for a truly fresh test.
- The latest self-UI exclusion and panel-docking fixes need a live Schrödinger smoke test. Any diagnosis mentioning “the Aster panel,” prior transcript, or text hidden behind Aster is a release blocker.
- Point is an explicit cursor-centered crop plus best-effort Vision recovery, not guaranteed object-level semantic tracking. Region and Freehand Loop remain fixed display areas; arbitrary scrolling/zooming/layout changes can lose alignment.
- Selected-window targeting exists internally but is not exposed as one of the four current UI modes.
- Multi-display/full-screen panel behavior has automated configuration coverage but still needs human validation on the target judge Mac.
- Video context is opt-in/confirmed, bounded to at most four recent frames, and browser control is limited to active HTML5 video in Safari/Chrome. Automation/JavaScript-from-Apple-Events permission may block pause/resume.
- “Hey Aster” depends on available on-device Speech recognition and explicit optional permissions; test it on the actual machine.
- Review dates and due counts exist, but Aster does not proactively resurface a concept with a learner-facing “why this is back” explanation.
- The transcript intentionally resets between launches; only compact learner evidence persists. There is no persistent screenshot/chat log.
- The ✱ animates as the drawing origin and Point pin, but there is no shipped clickable persistent lesson-star/bookmark.
- Scratchpad, zoom, copy-for-paste preview, and undo have implementation groundwork but not complete stable end-user paths. General autonomous Mac control, silent clicking/typing, graded-work completion, and unrestricted model-generated Python are deliberately absent.
- Desmos needs network access. Manim needs a local CLI and only runs fixed templates.
- No complete human benchmark run is recorded for the 30-screen plan or its ≥90% target-hit release gate; `docs/EVALS.md` is a plan plus automated geometry evidence, not a completed impact study.

## 11. Last successfully tested flows

Verified on 2026-07-21; rerun for every release commit:

- `cd macos && swift test`: 21/21 Swift tests passed.
- `cd macos && swift build -c release`: succeeded.
- `cd macos && zsh scripts/package.sh`: release `0.5.2` build `17` refreshes the ZIP.
- `npm test`: production web build passed and 2/2 rendered-HTML tests passed.
- All three rendered download CTAs point to `/Aster-macOS.zip?v=0.5.2`.
- For release `0.5.2`, verify the deployed ZIP matches local SHA-256 `e065c89d44182670cdbd3260a9f4f9a40d8c2b5a735478836b30c116a830d191`.
- GitHub `main` was clean and synchronized before this HANDOFF-only change; the repository was verified public.
- The Sites deployment must be verified against the final pushed release commit, and anonymous access must return HTTP 200.

Manual behavior reported working during development: app icon in Dock, relocation/permission recovery after removing the stale TCC entry, and the native onboarding/settings flow. **Still required after the latest Point-pin release:** one uninterrupted live research-paper diagnosis → lesson → independent answer → assessment → restart flow. Run that before submission; do not infer it from green unit tests.

## 12. Remaining submission tasks

1. Verify the existing Sites project remains publicly accessible, then verify the landing URL and ZIP in an unsigned/incognito browser.
2. Run the required live smoke on research paper, Schrödinger equation, and anatomy material; specifically verify Aster UI exclusion and annotation targeting.
3. Test Option-Space over Chrome/Preview, full screen, and a second display; test text, immediate voice, follow-up voice, and “Hey Aster.”
4. Record the sub-three-minute native-app demo using `docs/DEMO_SCRIPT.md`; keep a clean second take.
5. Run the 30-screen/manual evaluation or report only the evidence actually collected. Do not claim the target gate as achieved without results.
6. Add the public Codex `/feedback` session/share identifier required by the contest. `README.md` still contains `<add public session ID>`; this handoff intentionally did not edit it.
7. Complete the Devpost fields, screenshots/thumbnail, repository URL, landing URL, demo video, truthful limitations, and final private-browser download check.
8. Confirm the new Codex account can access the existing Sites project. If not, arrange access rather than creating a conflicting duplicate deployment.

## 13. Do not change before submission

- Do not restore Demo mode, canned lessons, bundled keys, or an empty-key fallback.
- Preserve the four visible context modes and Point's explicit pinned click.
- Preserve the non-activating key-capable panel; never call `NSApp.activate(ignoringOtherApps: true)` on the summon path.
- Preserve **no model request before explicit learner submission**, own-overlay exclusion, minimum scoped capture, Keychain-only key storage, immediate sign-out, and `store: false` on every Responses request.
- Preserve the three separate schema contracts and ordering: diagnose → teach → independent check → assess → evidence update. Never update mastery merely because a lesson was viewed.
- Preserve streaming, low-effort/default Terra routing, explicit-only Sol Precision mode, and Luna text assessment unless a measured regression justifies a change.
- Preserve bounded, previewed, reversible teaching actions. Do not add general autonomous control or unrestricted model-authored execution.
- Keep the transcript ephemeral and learner evidence local. Do not claim Drizzle/D1 backs memory.
- Keep `Aster✱` branding and warm coral signal color consistent.
- If the app build changes, bump the release version/query consistently, rerun all tests/package steps, commit the new ZIP, and deploy the exact pushed SHA. Never point a CTA at a stale artifact.
- Do not claim proactive spaced review, clickable lesson bookmarks, exposed selected-window mode, perfect semantic tracking, notarization, Intel support, or complete scratch/typing/undo UI until those paths are actually implemented and tested.

## Fast orientation for the next session

Read, in order: `README.md`, this file, `docs/TESTING_GUIDE.md`, `macos/Sources/Aster/TutorModel.swift`, `macos/Sources/Aster/OpenAIClient.swift`, and `app/page.tsx`. Then run `git status --short --branch`, `git rev-parse HEAD`, `cd macos && swift test`, and `npm test` before changing anything.
