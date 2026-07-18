"use client";

import { useEffect, useRef, useState, type PointerEvent } from "react";

type SceneKey = "paper" | "math" | "anatomy";

const scenes: Record<
  SceneKey,
  {
    tab: string;
    eyebrow: string;
    title: string;
    voice: string;
    prompt: string;
    note: string;
  }
> = {
  paper: {
    tab: "Research paper",
    eyebrow: "Attention Is All You Need · §3.2",
    title: "Scaled dot-product attention",
    voice:
      "This square root is a temperature control. It keeps large dot products from making the softmax overconfident.",
    prompt: "Why divide by √dₖ?",
    note: "Keeps gradients useful as dimensions grow",
  },
  math: {
    tab: "Calculus",
    eyebrow: "Problem set · Question 4",
    title: "Integration by substitution",
    voice:
      "Notice that cos(x) is the derivative of sin(x). Circle that pair—then the substitution becomes visible.",
    prompt: "Walk me through the first step",
    note: "u = sin(x)  ·  du = cos(x)dx",
  },
  anatomy: {
    tab: "Anatomy",
    eyebrow: "Cardiovascular system · Plate 12",
    title: "Blood flow through the heart",
    voice:
      "Follow the blue path first. Deoxygenated blood enters the right atrium, then moves through the tricuspid valve.",
    prompt: "Trace the path of blood",
    note: "vena cava → right atrium → right ventricle",
  },
};

const lessons = [
  {
    n: "01",
    title: "Point",
    copy: "Hover your cursor near the part that is confusing. Aster uses that gesture as spatial context.",
  },
  {
    n: "02",
    title: "Ask",
    copy: "Press ⌥ Space and speak naturally. No uploads, tabs, or re-explaining what you are looking at.",
  },
  {
    n: "03",
    title: "See it click",
    copy: "Aster teaches in voice while drawing on the exact variables, structures, and connections that matter.",
  },
];

const actions = [
  {
    tag: "DESMOS",
    title: "Show the change",
    copy: "Preview an equation, then open it in Desmos so a parameter can be explored—not merely described.",
    color: "violet",
  },
  {
    tag: "MANIM",
    title: "Animate the idea",
    copy: "Turn a dense derivation into a short visual sequence when a static annotation is not enough.",
    color: "mint",
  },
  {
    tag: "MASTERY",
    title: "Hand it back",
    copy: "Aster fades its help and asks one focused question. The learner, not the agent, completes the thought.",
    color: "coral",
  },
];

function AsterMark() {
  return (
    <span className="aster-mark" aria-hidden="true">
      <i />
      <i />
    </span>
  );
}

function VoiceWave({ dark = false }: { dark?: boolean }) {
  return (
    <span className={`voice-wave ${dark ? "on-dark" : ""}`} aria-hidden="true">
      {[5, 11, 18, 9, 14, 22, 12, 7, 16, 10].map((height, index) => (
        <i key={index} style={{ height }} />
      ))}
    </span>
  );
}

function ProductStage({ scene }: { scene: SceneKey }) {
  const data = scenes[scene];

  return (
    <div className={`product-stage scene-${scene}`}>
      <div className="browser-bar">
        <span className="traffic-lights"><i /><i /><i /></span>
        <span className="document-name">{data.eyebrow}</span>
        <span className="stage-status"><i /> Aster can see this window</span>
      </div>

      <div className="paper-canvas" key={scene}>
        <div className="paper-copy">
          <span className="paper-kicker">{data.eyebrow}</span>
          <h3>{data.title}</h3>
          {scene === "paper" && (
            <>
              <p>
                An attention function maps a query and a set of key-value pairs to an output. We compute the dot
                products of the query with all keys, divide each by <b>√dₖ</b>, and apply a softmax.
              </p>
              <div className="equation attention-equation">
                Attention(Q, K, V) = softmax(
                <span className="fraction"><span>QKᵀ</span><span>√dₖ</span></span>
                )V
              </div>
              <p className="paper-faint">
                The scaling factor counteracts the growth in dot-product magnitude for large key dimensions.
              </p>
              <div className="target-ring target-paper" />
              <div className="target-arrow arrow-paper"><span>temperature</span></div>
              <div className="target-highlight highlight-paper" />
            </>
          )}

          {scene === "math" && (
            <>
              <p>Evaluate the integral. Begin by identifying an inner function and its derivative.</p>
              <div className="equation math-equation">∫ sin(x)² cos(x) dx</div>
              <div className="substitution">u = sin(x) &nbsp;&nbsp; → &nbsp;&nbsp; du = cos(x) dx</div>
              <div className="target-ring target-math-a" />
              <div className="target-ring target-math-b" />
              <div className="target-arrow arrow-math"><span>derivative pair</span></div>
            </>
          )}

          {scene === "anatomy" && (
            <div className="anatomy-layout">
              <div className="heart-diagram" aria-label="Stylized heart anatomy diagram">
                <span className="vessel vessel-a" />
                <span className="vessel vessel-b" />
                <span className="heart-core">♥</span>
                <span className="flow flow-a">1</span>
                <span className="flow flow-b">2</span>
                <span className="flow flow-c">3</span>
              </div>
              <div className="anatomy-labels">
                <span><i className="blue-dot" /> Vena cava</span>
                <span><i className="violet-dot" /> Right atrium</span>
                <span><i className="coral-dot" /> Left ventricle</span>
              </div>
              <div className="target-ring target-heart" />
              <div className="target-arrow arrow-heart"><span>start here</span></div>
            </div>
          )}
        </div>

        <div className="cursor-demo" aria-hidden="true"><span /></div>

        <div className="tutor-popover">
          <div className="tutor-topline">
            <span className="mini-mark"><AsterMark /></span>
            <span>Aster is teaching</span>
            <VoiceWave />
          </div>
          <p>{data.voice}</p>
          <div className="lesson-note"><span>Key idea</span>{data.note}</div>
          <div className="chat-input"><span>{data.prompt}</span><b>↑</b></div>
        </div>
      </div>
    </div>
  );
}

export default function Home() {
  const [scene, setScene] = useState<SceneKey>("paper");
  const [scrolled, setScrolled] = useState(false);
  const heroRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  function trackPointer(event: PointerEvent<HTMLElement>) {
    const rect = heroRef.current?.getBoundingClientRect();
    if (!rect || !heroRef.current) return;
    heroRef.current.style.setProperty("--pointer-x", `${event.clientX - rect.left}px`);
    heroRef.current.style.setProperty("--pointer-y", `${event.clientY - rect.top}px`);
  }

  return (
    <main>
      <nav className={scrolled ? "site-nav nav-scrolled" : "site-nav"} aria-label="Main navigation">
        <a className="brand" href="#top" aria-label="Aster home"><AsterMark /><span>Aster</span></a>
        <div className="nav-links">
          <a href="#how">How it works</a>
          <a href="#learning">For learning</a>
          <a href="#privacy">Privacy</a>
        </div>
        <a className="nav-download" href="/Aster-macOS.zip" download>
          <span>Download for Mac</span><b>↓</b>
        </a>
      </nav>

      <section
        className="hero"
        id="top"
        ref={heroRef}
        onPointerMove={trackPointer}
      >
        <div className="pointer-aura" aria-hidden="true" />
        <div className="hero-copy">
          <div className="eyebrow"><span className="eyebrow-dot" /> A spatial tutor for macOS</div>
          <h1>Your screen becomes<br />the <span>whiteboard.</span></h1>
          <p>
            Select an equation, figure, paragraph, chart, code block, or diagram. Aster diagnoses first, teaches by
            voice and on-target drawing, checks your understanding, and remembers what still needs work.
          </p>
          <div className="hero-actions">
            <a className="primary-button" href="/Aster-macOS.zip" download>
              <span className="apple-glyph">●</span>
              <span><small>Prototype for</small>macOS</span>
              <b>↓</b>
            </a>
            <a className="text-button" href="#demo"><span className="play-icon">▶</span> See it teach</a>
          </div>
          <div className="hero-meta">
            <span><i /> Exact context selection</span>
            <span><i /> Local live follow</span>
            <span><i /> Persistent mastery</span>
          </div>
        </div>

        <div className="hero-stage" id="demo">
          <div className="scene-switcher" role="tablist" aria-label="Choose a lesson demo">
            {(Object.keys(scenes) as SceneKey[]).map((key) => (
              <button
                key={key}
                className={scene === key ? "active" : ""}
                onClick={() => setScene(key)}
                role="tab"
                aria-selected={scene === key}
              >
                {scenes[key].tab}
              </button>
            ))}
          </div>
          <ProductStage scene={scene} />
          <div className="hotkey-pill"><span>Press</span><kbd>⌥</kbd><kbd>Space</kbd><span>anywhere</span></div>
        </div>
      </section>

      <section className="trust-strip" aria-label="Aster capabilities">
        <span>Research papers</span><i />
        <span>Equations</span><i />
        <span>Anatomy</span><i />
        <span>Circuits</span><i />
        <span>Graphs</span>
      </section>

      <section className="how-section" id="how">
        <div className="section-heading split-heading">
          <div>
            <span className="section-kicker">ZERO CONTEXT SWITCHING</span>
            <h2>Stay with the hard part.</h2>
          </div>
          <p>
            Learning breaks when you leave the page to describe the page. Aster starts from the material already in
            front of you and keeps every explanation anchored there.
          </p>
        </div>
        <div className="lesson-steps">
          {lessons.map((lesson, index) => (
            <article key={lesson.n} className="lesson-step">
              <span className="step-number">{lesson.n}</span>
              <div className={`step-visual visual-${index + 1}`}>
                {index === 0 && <><span className="mini-cursor">⌁</span><i /><b>this part</b></>}
                {index === 1 && <><AsterMark /><VoiceWave dark /></>}
                {index === 2 && <><span className="mini-equation">x² + y² = r²</span><i /><b>radius</b></>}
              </div>
              <h3>{lesson.title}</h3>
              <p>{lesson.copy}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="voice-section" id="learning">
        <div className="voice-visual">
          <div className="voice-orbit orbit-one" />
          <div className="voice-orbit orbit-two" />
          <div className="voice-core"><AsterMark /><VoiceWave dark /></div>
          <div className="voice-quote quote-one">“Why does that term disappear?”</div>
          <div className="voice-quote quote-two">“Compare these two structures.”</div>
          <div className="voice-quote quote-three">“Show me, don’t just tell me.”</div>
        </div>
        <div className="voice-copy">
          <span className="section-kicker light">VOICE + SPATIAL EXPLANATION</span>
          <h2>It teaches the way a great tutor points.</h2>
          <p>
            Aster’s voice carries the story while the overlay carries the reference. The learner never has to hold
            “that variable over there” in working memory.
          </p>
          <div className="principle-list">
            <div><span>1</span><p><b>Diagnose</b> with one short choice before explaining.</p></div>
            <div><span>2</span><p><b>Annotate</b> one synchronized visual step at a time.</p></div>
            <div><span>3</span><p><b>Verify</b> independently, then update mastery evidence.</p></div>
          </div>
        </div>
      </section>

      <section className="memory-section">
        <div className="memory-copy">
          <span className="section-kicker">REMEMBERS THE LEARNER, NOT JUST THE CHAT</span>
          <h2>Every explanation changes what comes next.</h2>
          <p>
            Aster stores compact learning evidence on your Mac: what you demonstrated, what is still shaky, and the
            next teaching strategy. Mastery changes only after you answer—not simply because you watched.
          </p>
          <div className="memory-loop" aria-label="Adaptive learning loop">
            <span>Diagnose</span><i>→</i><span>Teach</span><i>→</i><span>Predict</span><i>→</i><span>Assess</span><i>→</i><span>Adapt</span>
          </div>
        </div>
        <div className="learner-model-card">
          <div className="learner-card-top">
            <div><span>LEARNER MODEL</span><b>Attention mechanisms</b></div>
            <strong>68%</strong>
          </div>
          <div className="mastery-track"><i /></div>
          <div className="evidence-row understood"><span>✓</span><div><b>Understands</b><p>Softmax purpose · dot products</p></div></div>
          <div className="evidence-row shaky"><span>~</span><div><b>Still shaky</b><p>Why variance grows · square-root scaling</p></div></div>
          <div className="next-strategy"><span>NEXT STRATEGY</span><p>Connect dimension growth to softmax saturation with two visual comparisons.</p></div>
          <div className="memory-quote">“You understood softmax last time. Let’s connect it to the scaling term.”</div>
        </div>
      </section>

      <section className="agent-section">
        <div className="section-heading centered-heading">
          <span className="section-kicker">DEMONSTRATES, NEVER TAKES OVER</span>
          <h2>An agent with a teacher’s restraint.</h2>
          <p>Aster can open a real teaching surface, but every action is bounded, previewed, and learner-approved.</p>
        </div>
        <div className="action-grid">
          {actions.map((action, index) => (
            <article className={`action-card ${action.color}`} key={action.tag}>
              <div className="action-window">
                <span className="action-tag">{action.tag}</span>
                {index === 0 && <div className="graph-demo"><i /><i /><i /><b>y = a(x − h)²</b></div>}
                {index === 1 && <div className="frames-demo"><span>∫</span><i>→</i><span>Σ</span><i>→</i><span>◎</span></div>}
                {index === 2 && <div className="question-demo"><span>Now you try</span><b>Which variable controls the width?</b><i>Answer aloud →</i></div>}
              </div>
              <h3>{action.title}</h3>
              <p>{action.copy}</p>
              <button type="button">Preview first <span>↗</span></button>
            </article>
          ))}
        </div>
      </section>

      <section className="privacy-section" id="privacy">
        <div className="privacy-card">
          <div className="privacy-copy">
            <span className="section-kicker">PRIVACY YOU CAN SEE</span>
            <h2>Quiet until invited.</h2>
            <p>
              No invisible API surveillance. Aster visibly follows only the region you selected, refreshes it locally,
              and sends a screen image only after you ask. Your API key stays in macOS Keychain.
            </p>
            <div className="privacy-points">
              <span><i>✓</i> Selected-region capture</span>
              <span><i>✓</i> Native speech on-device</span>
              <span><i>✓</i> Local learner memory</span>
            </div>
          </div>
          <div className="budget-widget">
            <div className="budget-top"><span>Project budget</span><b>$0.37 used</b></div>
            <div className="budget-bar"><i /></div>
            <div className="budget-scale"><span>$0</span><span>Hard stop at $5</span></div>
            <div className="capture-state"><span className="capture-icon"><i /></span><div><b>Following selected context locally</b><small>No API request until you ask Aster</small></div></div>
          </div>
        </div>
      </section>

      <section className="final-cta">
        <div className="cta-glow" />
        <AsterMark />
        <span className="section-kicker light">ASTER FOR MAC</span>
        <h2>Meet the material<br />where it lives.</h2>
        <p>The downloadable Build Week prototype. Bring your own OpenAI API key—or explore its built-in demo mode.</p>
        <a className="light-button" href="/Aster-macOS.zip" download><span>Download Aster</span><b>↓</b></a>
        <small>macOS 13+ · Apple silicon & Intel · Ad-hoc signed prototype</small>
      </section>

      <footer>
        <a className="brand footer-brand" href="#top"><AsterMark /><span>Aster</span></a>
        <p>Built for OpenAI Build Week · Education Track</p>
        <p className="disclaimer">Independent project. Not affiliated with or endorsed by Apple or OpenAI.</p>
      </footer>
    </main>
  );
}
