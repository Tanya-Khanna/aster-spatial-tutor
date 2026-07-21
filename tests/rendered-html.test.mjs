import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);
  return worker.fetch(
    new Request("http://localhost/", { headers: { accept: "text/html" } }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("server-renders Aster star's complete product story", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Aster✱ — The spatial tutor for macOS<\/title>/i);
  assert.match(html, /Don’t bring your question to the tutor/);
  assert.match(html, /Highlight anything you’re learning/);
  assert.match(html, /draws directly where it matters/);
  assert.match(html, /helps you revisit it/);
  assert.match(html, /Research paper/);
  assert.match(html, /Calculus/);
  assert.match(html, /Anatomy/);
  assert.match(html, /Quiet until invited/);
  assert.match(html, /REMEMBERS THE LEARNER/);
  assert.match(html, /Diagnose/);
  assert.match(html, /Remembers what needs practice/);
  assert.match(html, /isn’t notarized by Apple yet/);
  assert.match(html, /Open Anyway/);
  assert.match(html, /scroll down to <strong>Security<\/strong>/);
  assert.match(html, /Aster was blocked to protect your Mac/);
  assert.match(html, /Set up Aster✱ in three minutes/);
  assert.match(html, /Connect &amp; learn/);
  assert.match(html, /Validate and save/);
  assert.match(html, /Move to Applications &amp; Relaunch/);
  assert.match(html, /own OpenAI API key is required/);
  assert.match(html, /macOS 13\+ · Apple silicon · Ad-hoc signed prototype/);
  assert.doesNotMatch(html, /Apple silicon &amp; Intel/);
  assert.match(html, /Aster-macOS\.zip\?v=0\.5\.3/);
  assert.equal((html.match(/href="\/Aster-macOS\.zip\?v=0\.5\.3"/g) ?? []).length, 3);
  assert.match(html, /Whole Screen/);
  assert.match(html, /Point/);
  assert.match(html, /Region/);
  assert.match(html, /Freehand Loop/);
  assert.match(html, /Screen &amp; System Audio Recording/);
  assert.match(html, /remove old Aster rows with −/);
  assert.match(html, /Request again/);
  assert.doesNotMatch(html, /demo mode|without an? API key|leave empty for/i);
  assert.doesNotMatch(html, /\$5|budget guard|hard stop/i);
  assert.doesNotMatch(html, /codex-preview|react-loading-skeleton|Your site is taking shape/i);
});

test("ships a key-required app archive, social card, and removes the starter preview", async () => {
  const [packageJson, page, layout, css, tutorModel, nativeViews, asterApp, relocationService, screenCapture, overlay, openAIClient, contextSelector, voiceServices, companion, readme, macReadme, demoScript] = await Promise.all([
    readFile(new URL("package.json", root), "utf8"),
    readFile(new URL("app/page.tsx", root), "utf8"),
    readFile(new URL("app/layout.tsx", root), "utf8"),
    readFile(new URL("app/globals.css", root), "utf8"),
    readFile(new URL("macos/Sources/Aster/TutorModel.swift", root), "utf8"),
    readFile(new URL("macos/Sources/Aster/Views.swift", root), "utf8"),
    readFile(new URL("macos/Sources/Aster/AsterApp.swift", root), "utf8"),
    readFile(new URL("macos/Sources/Aster/AppRelocationService.swift", root), "utf8"),
    readFile(new URL("macos/Sources/Aster/ScreenCaptureService.swift", root), "utf8"),
    readFile(new URL("macos/Sources/Aster/OverlayController.swift", root), "utf8"),
    readFile(new URL("macos/Sources/Aster/OpenAIClient.swift", root), "utf8"),
    readFile(new URL("macos/Sources/Aster/ContextSelectionController.swift", root), "utf8"),
    readFile(new URL("macos/Sources/Aster/VoiceServices.swift", root), "utf8"),
    readFile(new URL("macos/Sources/Aster/AsterStarCompanion.swift", root), "utf8"),
    readFile(new URL("README.md", root), "utf8"),
    readFile(new URL("macos/README.md", root), "utf8"),
    readFile(new URL("docs/DEMO_SCRIPT.md", root), "utf8"),
    access(new URL("public/Aster-macOS.zip", root)),
    access(new URL("public/og.png", root)),
  ]);

  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  assert.match(page, /Your screen becomes the/);
  assert.match(page, /const downloadHref = "\/Aster-macOS\.zip\?v=0\.5\.3"/);
  assert.equal((page.match(/href=\{downloadHref\}/g) ?? []).length, 3);
  assert.match(page, /scene-switcher/);
  assert.doesNotMatch(`${page}\n${css}`, /summon-demo|summon-modes|summon-prompt/);
  assert.doesNotMatch(`${page}\n${css}`, /budget-widget|budget-bar|budget-scale/i);
  assert.match(css, /prefers-reduced-motion/);
  assert.match(css, /--hand:/);
  assert.match(css, /@media \(max-width: 1240px\)/);
  assert.doesNotMatch(css, /perspective\(1400px\) rotateY/);
  assert.match(layout, /\/og\.png/);
  assert.doesNotMatch(`${tutorModel}\n${nativeViews}`, /runDemo|demoDiagnostic|demoLesson|demoAssessment|personalizedDemoDiagnostic|Demo mode/i);
  assert.doesNotMatch(`${readme}\n${macReadme}\n${demoScript}`, /Demo mode|without an API key|deterministic demo/i);
  assert.match(nativeViews, /Remove API key \/ Sign out/);
  assert.match(nativeViews, /Validate and save/);
  assert.match(nativeViews, /TutorBarView/);
  assert.match(nativeViews, /ForEach\(ContextMode\.allCases\)/);
  assert.match(nativeViews, /VIDEO CONTEXT · LOCAL/);
  assert.match(nativeViews, /toggleStyle\(\.switch\)/);
  assert.match(nativeViews, /asterLearnerBubble/);
  assert.match(nativeViews, /LOCAL ONLY · NOTHING SENT/);
  assert.doesNotMatch(nativeViews, /Point \/ select|Use current window/);
  assert.match(nativeViews, /switch model\.settingsPane/);
  assert.match(nativeViews, /General|Permissions|Learning|Account/);
  assert.match(asterApp, /NSToolbar/);
  assert.match(asterApp, /CommandGroup\(replacing: \.appSettings\)/);
  assert.match(asterApp, /\.nonactivatingPanel/);
  assert.match(asterApp, /override var canBecomeKey: Bool \{ true \}/);
  assert.match(asterApp, /asterFocusComposer/);
  const tutorActivationBody = tutorModel.match(/func activate\(\) \{([^}]*)\}/)?.[1] ?? "";
  assert.notEqual(tutorActivationBody, "");
  assert.doesNotMatch(tutorActivationBody, /NSApp\.activate/);
  assert.match(`${tutorModel}\n${nativeViews}\n${asterApp}`, /Move to Applications & Relaunch|moveToApplicationsAndRelaunch/);
  assert.match(relocationService, /AppTranslocation/);
  assert.match(relocationService, /com\.apple\.quarantine/);
  assert.match(relocationService, /removeQuarantineRecursively/);
  assert.match(asterApp, /sharingType = \.readOnly/);
  assert.match(overlay, /sharingType = \.readOnly/);
  assert.match(screenCapture, /captureDisplayExcludingAsterWindows/);
  assert.match(screenCapture, /window\.sharingType = \.none/);
  assert.match(screenCapture, /target\.selectionPath/);
  assert.match(screenCapture, /mask\.addClip\(\)/);
  assert.match(contextSelector, /Click the exact thing you mean/);
  assert.match(contextSelector, /pointer: pointer/);
  assert.match(tutorModel, /shouldEnableDetectedVideo/);
  assert.doesNotMatch(tutorModel, /consecutiveFrameChanges/);
  assert.match(voiceServices, /questionAfterWakePhrase/);
  assert.match(voiceServices, /requiresOnDeviceRecognition = true/);
  assert.match(voiceServices, /1\.15/);
  assert.doesNotMatch(companion, /bookmark|AsterGlyphRenderer\.draw/);
  assert.match(openAIClient, /"store": false/);
  await assert.rejects(access(new URL("app\/_sites-preview", root)));
});
