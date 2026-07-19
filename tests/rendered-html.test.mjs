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

test("server-renders Aster's complete product story", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Aster — The spatial tutor for macOS<\/title>/i);
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
  assert.match(html, /Aster-macOS\.zip/);
  assert.doesNotMatch(html, /codex-preview|react-loading-skeleton|Your site is taking shape/i);
});

test("ships the app archive, social card, and removes the starter preview", async () => {
  const [packageJson, page, layout, css] = await Promise.all([
    readFile(new URL("package.json", root), "utf8"),
    readFile(new URL("app/page.tsx", root), "utf8"),
    readFile(new URL("app/layout.tsx", root), "utf8"),
    readFile(new URL("app/globals.css", root), "utf8"),
    access(new URL("public/Aster-macOS.zip", root)),
    access(new URL("public/og.png", root)),
  ]);

  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  assert.match(page, /The spatial tutor for macOS/);
  assert.match(page, /scene-switcher/);
  assert.match(css, /prefers-reduced-motion/);
  assert.match(layout, /\/og\.png/);
  await assert.rejects(access(new URL("app\/_sites-preview", root)));
});
