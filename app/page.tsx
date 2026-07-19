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
    copy: "Point at the exact term, structure, or object. Aster anchors to it locally—even when its window moves.",
  },
  {
    n: "02",
    title: "Ask",
    copy: "Press ⌥ Space and speak naturally. Talk back, interrupt, and continue the same tutoring conversation.",
  },
  {
    n: "03",
    title: "See it click",
    copy: "Aster teaches in voice while drawing, animating flows, simplifying dense diagrams, and checking you.",
  },
];

const actions = [
  {
    tag: "DESMOS",
    title: "Show the change",
    copy: "Preview an equation, then open it in Desmos so a parameter can be explored—not merely described.",
    color: "signal",
  },
  {
    tag: "MANIM",
    title: "Animate the idea",
    copy: "Preview a bounded local animation for derivatives, vectors, fields, circuits, geometry, waves, or molecules.",
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
      <svg viewBox="0 0 32 32" fill="none">
        <path className="cursor-ray" d="M3 3L6.2 15.2L9 11.9L14.2 17.1L16.7 14.6L11.5 9.4L15.2 6.3L3 3Z" />
        <path d="M23 13L29 7" />
        <path d="M23 23L29 28" />
        <path d="M18 24L18 30" />
        <path d="M13 19L3 19" />
        <circle cx="18" cy="19" r="2.8" />
      </svg>
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

function WebGLField() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const gl = canvas.getContext("webgl", {
      alpha: true,
      antialias: false,
      powerPreference: "low-power",
    });
    if (!gl) return;

    const vertexSource = `
      attribute vec2 a_position;
      void main() {
        gl_Position = vec4(a_position, 0.0, 1.0);
      }
    `;
    const fragmentSource = `
      precision mediump float;
      uniform vec2 u_resolution;
      uniform vec2 u_pointer;
      uniform float u_time;

      float glow(vec2 point, vec2 center, float radius) {
        return smoothstep(radius, 0.0, length(point - center));
      }

      void main() {
        vec2 uv = gl_FragCoord.xy / u_resolution.xy;
        vec2 aspect = vec2(u_resolution.x / u_resolution.y, 1.0);
        vec2 point = (uv - 0.5) * aspect;
        vec2 cursor = (u_pointer - 0.5) * aspect;
        float drift = u_time * 0.07;

        vec3 color = mix(vec3(0.018, 0.024, 0.055), vec3(0.060, 0.028, 0.052), uv.x);
        color += vec3(0.82, 0.16, 0.055) * glow(point, vec2(0.52 + sin(drift) * 0.10, 0.26), 0.62) * 0.34;
        color += vec3(0.10, 0.48, 0.39) * glow(point, vec2(0.78, -0.18 + cos(drift * 1.3) * 0.09), 0.54) * 0.18;
        color += vec3(0.10, 0.22, 0.62) * glow(point, vec2(-0.50, 0.36), 0.58) * 0.20;
        color += vec3(1.0, 0.33, 0.16) * glow(point, cursor, 0.22) * 0.13;

        float ribbons = sin((point.x * 4.2) + sin(point.y * 5.0 + drift * 5.0)) * 0.5 + 0.5;
        ribbons *= smoothstep(0.75, 0.05, abs(point.y + 0.08));
        color += vec3(0.18, 0.10, 0.22) * ribbons * 0.10;

        float grain = fract(sin(dot(gl_FragCoord.xy + u_time, vec2(12.9898, 78.233))) * 43758.5453);
        color += (grain - 0.5) * 0.018;
        gl_FragColor = vec4(color, 0.96);
      }
    `;

    const compile = (type: number, source: string) => {
      const shader = gl.createShader(type);
      if (!shader) return null;
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        gl.deleteShader(shader);
        return null;
      }
      return shader;
    };

    const vertexShader = compile(gl.VERTEX_SHADER, vertexSource);
    const fragmentShader = compile(gl.FRAGMENT_SHADER, fragmentSource);
    if (!vertexShader || !fragmentShader) return;

    const program = gl.createProgram();
    if (!program) return;
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) return;
    gl.useProgram(program);

    const vertices = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vertices);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]), gl.STATIC_DRAW);
    const position = gl.getAttribLocation(program, "a_position");
    gl.enableVertexAttribArray(position);
    gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);

    const resolution = gl.getUniformLocation(program, "u_resolution");
    const pointer = gl.getUniformLocation(program, "u_pointer");
    const time = gl.getUniformLocation(program, "u_time");
    const cursor = { x: 0.72, y: 0.68 };
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const startedAt = performance.now();
    let frame = 0;

    const resize = () => {
      const bounds = canvas.getBoundingClientRect();
      const density = Math.min(window.devicePixelRatio || 1, 1.5);
      canvas.width = Math.max(1, Math.round(bounds.width * density));
      canvas.height = Math.max(1, Math.round(bounds.height * density));
      gl.viewport(0, 0, canvas.width, canvas.height);
    };
    const followPointer = (event: globalThis.PointerEvent) => {
      const bounds = canvas.getBoundingClientRect();
      cursor.x = (event.clientX - bounds.left) / bounds.width;
      cursor.y = 1 - (event.clientY - bounds.top) / bounds.height;
    };
    const render = (now: number) => {
      gl.uniform2f(resolution, canvas.width, canvas.height);
      gl.uniform2f(pointer, cursor.x, cursor.y);
      gl.uniform1f(time, (now - startedAt) / 1000);
      gl.drawArrays(gl.TRIANGLES, 0, 6);
      if (!reducedMotion) frame = requestAnimationFrame(render);
    };

    resize();
    window.addEventListener("resize", resize);
    window.addEventListener("pointermove", followPointer, { passive: true });
    frame = requestAnimationFrame(render);

    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener("resize", resize);
      window.removeEventListener("pointermove", followPointer);
      gl.deleteBuffer(vertices);
      gl.deleteProgram(program);
      gl.deleteShader(vertexShader);
      gl.deleteShader(fragmentShader);
    };
  }, []);

  return <canvas ref={canvasRef} className="webgl-field" aria-hidden="true" />;
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
                <span><i className="signal-dot" /> Right atrium</span>
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
  const pageRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    let animationContext: { revert: () => void } | undefined;
    let cancelled = false;

    async function animatePage() {
      const [{ gsap }, { ScrollTrigger }] = await Promise.all([
        import("gsap"),
        import("gsap/ScrollTrigger"),
      ]);
      if (cancelled || !pageRef.current) return;
      gsap.registerPlugin(ScrollTrigger);
      animationContext = gsap.context(() => {
        gsap.from("[data-hero-reveal]", {
          y: 26,
          autoAlpha: 0,
          duration: 0.85,
          stagger: 0.08,
          ease: "power3.out",
        });
        gsap.from(".hero-stage", {
          x: 52,
          autoAlpha: 0,
          duration: 1.15,
          delay: 0.18,
          ease: "power3.out",
        });
        gsap.utils.toArray<HTMLElement>("[data-reveal]").forEach((element) => {
          gsap.from(element, {
            y: 52,
            autoAlpha: 0,
            duration: 0.9,
            ease: "power3.out",
            scrollTrigger: {
              trigger: element,
              start: "top 86%",
              once: true,
            },
          });
        });
      }, pageRef);
    }

    animatePage();
    return () => {
      cancelled = true;
      animationContext?.revert();
    };
  }, []);

  function trackPointer(event: PointerEvent<HTMLElement>) {
    const rect = heroRef.current?.getBoundingClientRect();
    if (!rect || !heroRef.current) return;
    heroRef.current.style.setProperty("--pointer-x", `${event.clientX - rect.left}px`);
    heroRef.current.style.setProperty("--pointer-y", `${event.clientY - rect.top}px`);
  }

  return (
    <main ref={pageRef}>
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
        <WebGLField />
        <div className="pointer-aura" aria-hidden="true" />
        <div className="hero-copy">
          <div className="eyebrow" data-hero-reveal><span className="eyebrow-dot" /> Meet your on-screen tutor</div>
          <h1 data-hero-reveal>Your screen becomes the <span>whiteboard</span>.</h1>
          <p className="hero-manifesto" data-hero-reveal>Don’t bring your question to the tutor. Bring the tutor to your question.</p>
          <div className="hero-learning-loop" aria-label="How Aster helps you learn" data-hero-reveal>
            <p><b>Point.</b><span>Highlight anything you’re learning.</span></p>
            <p><b>Learn.</b><span>Aster explains it aloud and draws directly where it matters.</span></p>
            <p><b>Master.</b><span>It checks what clicked, remembers what didn’t, and helps you revisit it.</span></p>
          </div>
          <div className="hero-actions" data-hero-reveal>
            <a className="primary-button" href="/Aster-macOS.zip" download>
              <span className="apple-glyph">⌘</span>
              <span><small>Prototype for</small>macOS</span>
              <b>↓</b>
            </a>
          </div>
          <div className="hero-meta" data-hero-reveal>
            <span><i /> No screenshots or uploads</span>
            <span><i /> Teaches where you’re looking</span>
            <span><i /> Remembers what needs practice</span>
          </div>
        </div>

        <div className="hero-stage" aria-label="Interactive Aster teaching demonstration">
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

      <section className="trust-strip" aria-label="Aster capabilities" data-reveal>
        <span>Research papers</span><i />
        <span>Equations</span><i />
        <span>Anatomy</span><i />
        <span>Circuits</span><i />
        <span>Graphs</span><i />
        <span>Videos</span>
      </section>

      <section className="how-section" id="how" data-reveal>
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

      <section className="voice-section" id="learning" data-reveal>
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

      <section className="memory-section" data-reveal>
        <div className="memory-copy">
          <span className="section-kicker">REMEMBERS THE LEARNER, NOT JUST THE CHAT</span>
          <h2>Every explanation changes what comes next.</h2>
          <p>
            Aster stores compact learning evidence on your Mac: what you demonstrated, what is still shaky, concept
            dependencies, review timing, and the next strategy. Mastery changes only after you answer.
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

      <section className="agent-section" data-reveal>
        <div className="section-heading centered-heading">
          <span className="section-kicker">TOOLS FOR DEEPER UNDERSTANDING</span>
          <h2>An agent with a teacher’s restraint.</h2>
          <p>Aster opens a teaching surface only when it helps you understand: visualizing a change, creating reversible scratch work, or generating focused practice. Every action is previewed, bounded, reversible, and permissioned.</p>
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

      <section className="privacy-section" id="privacy" data-reveal>
        <div className="privacy-card">
          <div className="privacy-copy">
            <span className="section-kicker">PRIVACY YOU CAN SEE</span>
            <h2>Quiet until invited.</h2>
            <p>
              Until you invoke Aster, no screen context leaves your Mac. When you do, Aster follows only the region
              or window you chose, visibly marks that boundary, and excludes its own overlay. Your API key stays in macOS Keychain.
            </p>
            <div className="privacy-points">
              <span><i>✓</i> Selected-region capture</span>
              <span><i>✓</i> Native speech on-device</span>
              <span><i>✓</i> Local learner memory</span>
            </div>
          </div>
          <div className="budget-widget">
            <div className="privacy-state"><span><i /> LOCAL UNTIL INVOKED</span><b>No silent background uploads.</b><small>Screen context moves only after an explicit request.</small></div>
            <div className="budget-top"><span>API budget guard</span><b>$0.37 used</b></div>
            <div className="budget-bar"><i /></div>
            <div className="budget-scale"><span>$0</span><span>Hard stop at $5</span></div>
            <div className="capture-state"><span className="capture-icon"><i /></span><div><b>Following selected context locally</b><small>No API request until you ask Aster</small></div></div>
          </div>
        </div>
      </section>

      <section className="final-cta" data-reveal>
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
      </footer>
    </main>
  );
}
