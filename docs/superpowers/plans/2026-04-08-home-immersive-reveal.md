# Home Page Immersive Reveal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the home page hero as an Earth POV night sky with mouse-driven look-around, and replace the T1 transition with a first-person explosive pull-up into space.

**Architecture:** A new `mouseParallax` writable store bridges mouse position from `+page.svelte` to `StarField.svelte`. The hero scene uses CSS 3D perspective tilt on a wrapper div for the look-around effect. The T1 transition is fully rewritten: new DOM elements in `TransitionOverlay.svelte` and a new `playT1Out` in `t1-ascent.ts` using a canvas streak loop driven by a GSAP-tweened `speed` value.

**Tech Stack:** SvelteKit, GSAP, TypeScript, canvas 2D API

---

## File Map

| File | Change |
|---|---|
| `web/src/lib/stores/mouseParallax.ts` | **Create** — writable store `{ x, y }` |
| `web/src/lib/components/StarField.svelte` | **Modify** — subscribe to mouseParallax, apply per-layer canvas offset |
| `web/src/routes/+page.svelte` | **Modify** — redesign hero scene, add look-around + idle breathing, update CTA |
| `web/src/lib/transitions/t1-ascent.ts` | **Modify** — new T1Elements interface + full first-person animation rewrite |
| `web/src/lib/components/TransitionOverlay.svelte` | **Modify** — replace T1 layer DOM, update getT1Els() to match new interface |

---

## Task 1: Create mouseParallax store

**Files:**
- Create: `web/src/lib/stores/mouseParallax.ts`

- [ ] **Step 1: Create the store file**

```typescript
// web/src/lib/stores/mouseParallax.ts
import { writable } from 'svelte/store';

export const mouseParallax = writable<{ x: number; y: number }>({ x: 0, y: 0 });
```

- [ ] **Step 2: Commit**

```bash
git add web/src/lib/stores/mouseParallax.ts
git commit -m "feat: add mouseParallax store for home page look-around"
```

---

## Task 2: Add mouse parallax to StarField

**Files:**
- Modify: `web/src/lib/components/StarField.svelte`

The existing StarField has 3 layers (indices 0, 1, 2) with scroll parallax. Add mouse offset on top: deep layer shifts ±0.8% of canvas width, mid ±1.8%, close ±3.5%. Subscribe to the store in `onMount`, store values in local `mouseX`/`mouseY` variables, and apply in `draw()`.

- [ ] **Step 1: Add store import and local mouse variables**

In `<script lang="ts">`, after the existing imports, add:

```typescript
import { mouseParallax } from '$lib/stores/mouseParallax';

let mouseX = 0;
let mouseY = 0;
```

- [ ] **Step 2: Subscribe to the store in onMount**

In `onMount`, after `window.addEventListener('resize', resize)`, add:

```typescript
    const unsubMouse = mouseParallax.subscribe(({ x, y }) => {
      mouseX = x;
      mouseY = y;
    });
```

And in the return callback of `onMount` (or in `onDestroy`, alongside the existing cleanup):

```typescript
    return () => {
      cancelAnimationFrame(rafId);
      window.removeEventListener('resize', resize);
      scrollTriggerInstance?.kill();
      unsubMouse();
    };
```

> Note: `onMount` in Svelte accepts a return value that is the cleanup function. Replace the existing `onMount` body so it returns the cleanup. Currently the cleanup is in `onDestroy` — merge them into the `onMount` return.

The full updated `onMount` should be:

```typescript
  onMount(() => {
    if (!browser) return;

    ctx = canvas.getContext('2d')!;
    buildStars();
    resize();

    window.addEventListener('resize', resize);

    scrollTriggerInstance = ScrollTrigger.create({
      start: 0,
      end: 'max',
      onUpdate: (self) => {
        scrollY = self.scroll();
      }
    });

    const unsubMouse = mouseParallax.subscribe(({ x, y }) => {
      mouseX = x;
      mouseY = y;
    });

    rafId = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(rafId);
      window.removeEventListener('resize', resize);
      scrollTriggerInstance?.kill();
      unsubMouse();
    };
  });
```

Remove the `onDestroy` block entirely (it's now redundant).

- [ ] **Step 3: Apply mouse offset in draw()**

Replace the existing `draw()` function with:

```typescript
  // Mouse parallax multipliers per layer (fraction of canvas dimension)
  const MOUSE_MULT = [0.008, 0.018, 0.035];

  function draw(): void {
    if (!ctx || !canvas) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    LAYERS.forEach((layer, i) => {
      const scrollOffset = scrollY * layer.speed;
      const mox = mouseX * MOUSE_MULT[i] * canvas.width;
      const moy = mouseY * MOUSE_MULT[i] * canvas.height;

      stars[i].forEach((star) => {
        const x = star.x * canvas.width + mox;
        const rawY = star.y * canvas.height - scrollOffset + moy;
        const y = ((rawY % canvas.height) + canvas.height) % canvas.height;

        ctx.beginPath();
        ctx.arc(x, y, star.radius, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(240, 237, 230, ${star.alpha})`;
        ctx.fill();
      });
    });

    rafId = requestAnimationFrame(draw);
  }
```

- [ ] **Step 4: Verify build passes**

```bash
cd web && pnpm check
```

Expected: no TypeScript errors.

- [ ] **Step 5: Commit**

```bash
git add web/src/lib/components/StarField.svelte
git commit -m "feat: StarField reads mouseParallax store for depth-separated look-around"
```

---

## Task 3: Redesign home page hero (Earth POV scene + look-around)

**Files:**
- Modify: `web/src/routes/+page.svelte`

Replace the `<MissionScene>` wrapper with a new `scene-perspective` + `scene-inner` structure. Add milky way band, atmosphere horizon. Wire mouse look-around (CSS 3D tilt on `scene-inner` + writes to `mouseParallax` store). Add idle breathing. Update CTA.

- [ ] **Step 1: Replace the entire +page.svelte with the following**

```svelte
<!-- web/src/routes/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { gsap } from 'gsap';
  import { ScrollTrigger } from 'gsap/ScrollTrigger';
  import { revealOnScroll } from '$lib/animations/reveal';
  import { mouseParallax } from '$lib/stores/mouseParallax';

  gsap.registerPlugin(ScrollTrigger);

  let sceneInner: HTMLElement;
  let heroContent: HTMLElement;
  let heroHeading: HTMLHeadingElement;
  let heroSub: HTMLParagraphElement;
  let heroCta: HTMLAnchorElement;
  let teaserSection: HTMLElement;

  onMount(() => {
    // ── Hero entrance ──
    const tl = gsap.timeline({ defaults: { ease: 'power2.out' } });
    tl
      .from(heroHeading, { opacity: 0, y: 40, duration: 1.2, delay: 0.3 })
      .from(heroSub, { opacity: 0, y: 20, duration: 0.8 }, '-=0.6')
      .from(heroCta, { opacity: 0, y: 16, duration: 0.6 }, '-=0.4');

    // ── Mouse look-around ──
    let idleTween: gsap.core.Tween | null = null;
    let idleTimer: ReturnType<typeof setTimeout>;

    function startIdleBreathing() {
      idleTween = gsap.to(sceneInner, {
        rotateX: 1.5,
        rotateY: 1.5,
        duration: 4,
        ease: 'sine.inOut',
        yoyo: true,
        repeat: -1,
        overwrite: true
      });
    }

    function onMouseMove(e: MouseEvent) {
      clearTimeout(idleTimer);
      idleTween?.kill();
      idleTween = null;

      // Normalize to -1..1 from viewport center
      const nx = (e.clientX / window.innerWidth - 0.5) * 2;
      const ny = (e.clientY / window.innerHeight - 0.5) * 2;

      // Tilt the scene
      gsap.to(sceneInner, {
        rotateY: nx * 8,
        rotateX: -ny * 6,
        duration: 1.2,
        ease: 'power2.out',
        overwrite: 'auto'
      });

      // Counter-tilt hero content (30% — feels painted on sky)
      gsap.to(heroContent, {
        rotateY: -nx * 8 * 0.3,
        rotateX: ny * 6 * 0.3,
        duration: 1.2,
        ease: 'power2.out',
        overwrite: 'auto'
      });

      // Drive star layer parallax
      mouseParallax.set({ x: nx, y: ny });

      idleTimer = setTimeout(startIdleBreathing, 3000);
    }

    // Start idle after 3s of inactivity on load
    idleTimer = setTimeout(startIdleBreathing, 3000);
    window.addEventListener('mousemove', onMouseMove);

    // ── Scroll reveals ──
    if (teaserSection) {
      const items = teaserSection.querySelectorAll<HTMLElement>('.teaser-item');
      items.forEach((el, i) => revealOnScroll(el, i * 0.12));
    }

    return () => {
      window.removeEventListener('mousemove', onMouseMove);
      clearTimeout(idleTimer);
      idleTween?.kill();
      mouseParallax.set({ x: 0, y: 0 });
    };
  });

  const missions = [
    { number: '001', label: 'Low Earth Orbit', product: 'Warped Reality Beanie', slug: 'warped-reality-beanie', image: '/photos/blue-beanie.jpeg' },
    { number: '002', label: 'Lunar Surface',   product: 'Vanguard Trucker Hat',  slug: 'vanguard-trucker-hat', image: null },
    { number: '003', label: 'Stellar Nursery', product: 'Racerback Tanktop',     slug: 'racerback-tanktop',    image: '/photos/tank-front.png' },
    { number: '004', label: 'Deep Space',      product: 'Next Drop',             slug: null,                   image: null },
  ] as const;
</script>

<svelte:head>
  <title>Immortal Vibes — Rise Beyond the Mortal Plane</title>
  <meta name="description" content="Garments built for those who orbit higher. Limited drops, infinite purpose." />
</svelte:head>

<!-- Earth POV hero: night sky looking up -->
<div class="scene-perspective">
  <div class="scene-inner" bind:this={sceneInner}>

    <!-- Milky Way band overlay -->
    <div class="milky-way" aria-hidden="true"></div>

    <!-- Atmosphere horizon at bottom -->
    <div class="atmosphere-horizon" aria-hidden="true"></div>

    <!-- Hero content -->
    <section class="hero">
      <div class="hero-inner" bind:this={heroContent}>
        <p class="hero-eyebrow">IMMORTAL VIBES</p>

        <h1 bind:this={heroHeading} class="hero-heading">
          RISE BEYOND<br />THE MORTAL PLANE
        </h1>

        <p bind:this={heroSub} class="hero-sub">
          Garments built for those who orbit higher.<br />
          Limited drops. Infinite purpose.
        </p>

        <a
          bind:this={heroCta}
          href="/shop"
          class="hero-cta"
          data-magnetic
        >
          ENTER THE MISSIONS
        </a>
      </div>

      <!-- Scroll indicator -->
      <div class="scroll-indicator" aria-hidden="true">
        <span class="scroll-line"></span>
        <span class="scroll-label">SCROLL</span>
      </div>
    </section>

  </div>
</div>

<!-- Mission teasers below the fold -->
<section bind:this={teaserSection} class="teasers">
  <div class="teasers-inner">
    <p class="teasers-eyebrow">ACTIVE MISSIONS</p>

    {#each missions as mission}
      <div class="teaser-item">
        <span class="teaser-number">{mission.number}</span>
        <div class="teaser-body">
          <p class="teaser-label">{mission.label}</p>
          <p class="teaser-product">{mission.product}</p>
        </div>
        {#if mission.image}
          <img class="teaser-image" src={mission.image} alt={mission.product} />
        {/if}
        {#if mission.slug}
          <a href="/shop/{mission.slug}" class="teaser-link" data-magnetic>
            VIEW →
          </a>
        {:else}
          <span class="teaser-tbd">TBD</span>
        {/if}
      </div>
    {/each}
  </div>
</section>

<style>
  /* ── Scene wrapper ── */
  .scene-perspective {
    perspective: 800px;
    perspective-origin: 50% 50%;
    position: relative;
    width: 100%;
    min-height: 100vh;
    overflow: hidden;
  }

  .scene-inner {
    transform-style: preserve-3d;
    position: relative;
    width: 100%;
    min-height: 100vh;
    will-change: transform;
  }

  /* ── Milky Way band ── */
  .milky-way {
    position: absolute;
    inset: 0;
    background: linear-gradient(
      135deg,
      transparent 20%,
      rgba(240, 237, 230, 0.008) 35%,
      rgba(240, 237, 230, 0.022) 42%,
      rgba(240, 237, 230, 0.032) 50%,
      rgba(240, 237, 230, 0.022) 58%,
      rgba(240, 237, 230, 0.008) 65%,
      transparent 80%
    );
    pointer-events: none;
    z-index: 1;
  }

  /* ── Atmosphere horizon ── */
  .atmosphere-horizon {
    position: absolute;
    bottom: 0;
    left: -10%;
    right: -10%;
    height: 14vh;
    background: radial-gradient(
      ellipse at 50% 100%,
      rgba(8, 22, 65, 0.7) 0%,
      rgba(15, 45, 110, 0.5) 20%,
      rgba(25, 65, 140, 0.3) 40%,
      rgba(55, 130, 190, 0.18) 60%,
      rgba(79, 195, 247, 0.08) 75%,
      transparent 90%
    );
    border-radius: 50% 50% 0 0 / 80% 80% 0 0;
    pointer-events: none;
    z-index: 1;
  }

  /* ── Hero ── */
  .hero {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    text-align: center;
    padding: 6rem 2rem 4rem;
    position: relative;
    z-index: 2;
  }

  .hero-inner {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2rem;
    transform-style: preserve-3d;
    will-change: transform;
  }

  .hero-eyebrow {
    font-family: 'Inter', sans-serif;
    font-size: 0.6rem;
    letter-spacing: 0.4em;
    color: rgba(240, 237, 230, 0.35);
    margin: 0;
  }

  .hero-heading {
    font-family: 'Cormorant Garamond', serif;
    font-size: clamp(3rem, 10vw, 9rem);
    font-weight: 300;
    color: #F0EDE6;
    margin: 0;
    line-height: 0.95;
    letter-spacing: -0.01em;
  }

  .hero-sub {
    font-family: 'Inter', sans-serif;
    font-size: 0.875rem;
    line-height: 1.8;
    color: rgba(240, 237, 230, 0.45);
    margin: 0;
  }

  .hero-cta {
    display: inline-block;
    border: 1px solid rgba(240, 237, 230, 0.2);
    border-bottom-color: rgba(200, 146, 42, 0.35);
    color: rgba(240, 237, 230, 0.7);
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.25em;
    padding: 1rem 2.5rem;
    text-decoration: none;
    transition: border-color 0.2s, color 0.2s;
    animation: ctaPulse 2.8s ease-in-out infinite;
  }

  .hero-cta:hover {
    border-color: rgba(240, 237, 230, 0.6);
    border-bottom-color: rgba(200, 146, 42, 0.8);
    color: #F0EDE6;
  }

  @keyframes ctaPulse {
    0%, 100% { border-bottom-color: rgba(200, 146, 42, 0.15); }
    50%       { border-bottom-color: rgba(200, 146, 42, 0.6); }
  }

  .scroll-indicator {
    position: absolute;
    bottom: 2.5rem;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
    animation: scrollBob 2.5s ease-in-out infinite;
  }

  .scroll-line {
    display: block;
    width: 1px;
    height: 40px;
    background: linear-gradient(to bottom, transparent, rgba(240,237,230,0.3));
  }

  .scroll-label {
    font-family: 'Inter', sans-serif;
    font-size: 0.55rem;
    letter-spacing: 0.25em;
    color: rgba(240, 237, 230, 0.25);
  }

  @keyframes scrollBob {
    0%, 100% { transform: translateX(-50%) translateY(0); }
    50% { transform: translateX(-50%) translateY(6px); }
  }

  /* ── Teasers ── */
  .teasers {
    background: #030308;
    padding: 8rem 2rem;
  }

  .teasers-inner {
    max-width: 800px;
    margin: 0 auto;
  }

  .teasers-eyebrow {
    font-family: 'Inter', sans-serif;
    font-size: 0.6rem;
    letter-spacing: 0.3em;
    color: rgba(240, 237, 230, 0.3);
    margin: 0 0 3rem;
  }

  .teaser-item {
    display: flex;
    align-items: center;
    gap: 2rem;
    padding: 1.75rem 0;
    border-bottom: 1px solid rgba(240, 237, 230, 0.06);
  }

  .teaser-number {
    font-family: 'Inter', sans-serif;
    font-size: 0.6rem;
    letter-spacing: 0.2em;
    color: rgba(240, 237, 230, 0.2);
    width: 2.5rem;
    flex-shrink: 0;
  }

  .teaser-body {
    flex: 1;
  }

  .teaser-label {
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.15em;
    color: rgba(240, 237, 230, 0.3);
    margin: 0 0 0.25rem;
    text-transform: uppercase;
  }

  .teaser-product {
    font-family: 'Cormorant Garamond', serif;
    font-size: 1.4rem;
    font-weight: 300;
    color: #F0EDE6;
    margin: 0;
  }

  .teaser-link {
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.15em;
    color: rgba(240, 237, 230, 0.4);
    text-decoration: none;
    transition: color 0.2s;
    flex-shrink: 0;
  }

  .teaser-link:hover {
    color: #F0EDE6;
  }

  .teaser-image {
    width: 56px;
    height: 56px;
    object-fit: contain;
    filter: drop-shadow(0 4px 12px rgba(0, 0, 0, 0.5));
    transform: rotate(-6deg);
    flex-shrink: 0;
    opacity: 0.85;
    transition: opacity 0.2s, transform 0.3s;
  }

  .teaser-item:hover .teaser-image {
    opacity: 1;
    transform: rotate(-3deg) scale(1.06);
  }

  .teaser-tbd {
    font-family: 'Inter', sans-serif;
    font-size: 0.6rem;
    letter-spacing: 0.2em;
    color: rgba(240, 237, 230, 0.15);
    flex-shrink: 0;
  }
</style>
```

- [ ] **Step 2: Verify build passes**

```bash
cd web && pnpm check
```

Expected: no TypeScript errors.

- [ ] **Step 3: Smoke test in browser**

```bash
pnpm dev
```

Open http://localhost:5173. Verify:
- Star field visible (global StarField from layout)
- Subtle milky way diagonal band visible across hero
- Atmosphere horizon glow visible at bottom of hero
- "ENTER THE MISSIONS" CTA with gold pulse on bottom border
- Moving mouse causes stars to shift at different rates (parallax)
- Scene tilts slightly with mouse movement (atmosphere tilts with it)
- After 3s idle, scene drifts in a gentle breathing oscillation

- [ ] **Step 4: Commit**

```bash
git add web/src/routes/+page.svelte
git commit -m "feat: Earth POV hero with night sky, atmosphere horizon, mouse look-around"
```

---

## Task 4: Rewrite T1 first-person pull-up transition

**Files:**
- Modify: `web/src/lib/transitions/t1-ascent.ts`
- Modify: `web/src/lib/components/TransitionOverlay.svelte`

Do both files in this task — the `T1Elements` interface must match between them. Do the `t1-ascent.ts` file first, then update the overlay to match.

### Part A — Rewrite t1-ascent.ts

- [ ] **Step 1: Replace the entire content of t1-ascent.ts**

```typescript
// web/src/lib/transitions/t1-ascent.ts
import gsap from 'gsap';

export interface T1Elements {
  overlay: HTMLElement;
  flash: HTMLElement;
  horizon: HTMLElement;
  streakCanvas: HTMLCanvasElement;
  atmoLeft: HTMLElement;
  atmoRight: HTMLElement;
}

function drawStreaks(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
  speed: number
): void {
  ctx.clearRect(0, 0, w, h);
  if (speed < 0.02) return;

  const cx = w / 2;
  const cy = h / 2;
  // Diagonal of canvas = max possible streak length
  const maxLen = Math.sqrt(cx * cx + cy * cy) * 1.2;
  const count = 220;

  for (let i = 0; i < count; i++) {
    const angle = (i / count) * Math.PI * 2;
    // Deterministic length variation per streak (no Math.random — stable across frames)
    const lenMult = 0.5 + ((i * 73) % 100) / 200;
    const len = speed * maxLen * lenMult;
    const tail = speed * 0.22;

    const x1 = cx + Math.cos(angle) * len * tail;
    const y1 = cy + Math.sin(angle) * len * tail;
    const x2 = cx + Math.cos(angle) * len;
    const y2 = cy + Math.sin(angle) * len;

    const grad = ctx.createLinearGradient(x1, y1, x2, y2);
    const alpha = Math.min(speed * 0.75, 0.65);
    grad.addColorStop(0, `rgba(240,237,230,${alpha})`);
    grad.addColorStop(1, 'rgba(240,237,230,0)');

    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.lineTo(x2, y2);
    ctx.strokeStyle = grad;
    ctx.lineWidth = 0.4 + (i % 4) * 0.2;
    ctx.stroke();
  }
}

export function playT1Out(
  els: T1Elements,
  onMidpoint: () => void
): gsap.core.Timeline {
  const tl = gsap.timeline();

  // ── Setup ──
  gsap.set(els.overlay, { display: 'block', opacity: 1 });
  gsap.set([els.flash, els.atmoLeft, els.atmoRight, els.streakCanvas], { opacity: 0 });
  gsap.set([els.atmoLeft, els.atmoRight], { y: 0 });
  gsap.set(els.horizon, { y: 0, opacity: 1 });

  // Init streak canvas dimensions (set once — do NOT resize inside draw loop)
  const w = window.innerWidth;
  const h = window.innerHeight;
  els.streakCanvas.width = w;
  els.streakCanvas.height = h;
  const ctx = els.streakCanvas.getContext('2d')!;

  // GSAP-tweened speed value — RAF reads this each frame
  const state = { speed: 0 };
  let rafId = 0;

  function loop() {
    drawStreaks(ctx, w, h, state.speed);
    rafId = requestAnimationFrame(loop);
  }

  tl
    // ── 0–400ms: Horizon drops away ──
    .to(els.horizon, { y: '100vh', duration: 0.4, ease: 'power3.in' }, 0)

    // ── 0ms: Start streak RAF + show canvas ──
    .call(() => {
      gsap.set(els.streakCanvas, { opacity: 1 });
      rafId = requestAnimationFrame(loop);
    }, [], 0)

    // ── 0–500ms: Speed ramps from 0 → 1 ──
    .to(state, { speed: 1, duration: 0.5, ease: 'power3.in' }, 0)

    // ── 300ms: Atmosphere edge smears appear ──
    .to([els.atmoLeft, els.atmoRight], { opacity: 0.75, duration: 0.15, ease: 'power2.out' }, 0.3)

    // ── 450–850ms: Atmo smears rush off screen upward ──
    .to([els.atmoLeft, els.atmoRight], { y: '-100vh', duration: 0.4, ease: 'power3.in' }, 0.45)

    // ── 500ms: Route change (load destination page in background) ──
    .call(onMidpoint, [], 0.5)

    // ── 800ms: Breach flash peak ──
    .to(els.flash, { opacity: 1, duration: 0.08, ease: 'power4.in' }, 0.8)
    .to(els.flash, { opacity: 0, duration: 0.22, ease: 'power2.out' }, 0.88)

    // ── 900ms–1200ms: Speed ramps back to 0 ──
    .to(state, { speed: 0, duration: 0.3, ease: 'power3.out' }, 0.9)

    // ── 1200ms: Stop RAF, hide canvas ──
    .call(() => {
      cancelAnimationFrame(rafId);
      gsap.set(els.streakCanvas, { opacity: 0 });
    }, [], 1.2)

    // ── Pad to 1.4s ──
    .to({}, { duration: 0.2 }, 1.2);

  return tl;
}

export function playT1In(els: T1Elements, onComplete: () => void): gsap.core.Timeline {
  const tl = gsap.timeline({ onComplete });

  tl
    .to(els.overlay, { opacity: 0, duration: 0.3, ease: 'power2.out' })
    .call(() => { gsap.set(els.overlay, { display: 'none' }); });

  return tl;
}
```

### Part B — Update TransitionOverlay.svelte T1 layer

- [ ] **Step 2: Replace T1 DOM ref declarations**

In `<script lang="ts">`, find the `// T1` comment block:

```typescript
  // T1
  let t1Flash: HTMLElement;
  let t1Blast: HTMLElement;
  let t1Shockwave: HTMLElement;
  let t1StreakEls: HTMLElement[] = [];
  let t1Atmo: HTMLElement;
  let t1Stars: HTMLCanvasElement;
  let t1City: HTMLElement;
```

Replace with:

```typescript
  // T1
  let t1Flash: HTMLElement;
  let t1Horizon: HTMLElement;
  let t1StreakCanvas: HTMLCanvasElement;
  let t1AtmoLeft: HTMLElement;
  let t1AtmoRight: HTMLElement;
```

- [ ] **Step 3: Update getT1Els()**

Replace:

```typescript
  function getT1Els(): T1Elements {
    return { overlay: overlayEl, flash: t1Flash, blast: t1Blast, shockwave: t1Shockwave, streaks: t1StreakEls, atmo: t1Atmo, starsCanvas: t1Stars, cityline: t1City };
  }
```

With:

```typescript
  function getT1Els(): T1Elements {
    return { overlay: overlayEl, flash: t1Flash, horizon: t1Horizon, streakCanvas: t1StreakCanvas, atmoLeft: t1AtmoLeft, atmoRight: t1AtmoRight };
  }
```

- [ ] **Step 4: Replace the T1 layer HTML**

In the template, find `<!-- T1 LAYERS -->` and replace the entire `<div class="t1-layer">` block:

```html
  <!-- T1 LAYERS -->
  <div class="t1-layer">
    <div bind:this={t1Flash} class="t1-flash"></div>
    <div bind:this={t1Horizon} class="t1-horizon"></div>
    <canvas bind:this={t1StreakCanvas} class="t1-streak-canvas"></canvas>
    <div bind:this={t1AtmoLeft} class="t1-atmo-left"></div>
    <div bind:this={t1AtmoRight} class="t1-atmo-right"></div>
  </div>
```

- [ ] **Step 5: Replace T1 CSS**

In `<style>`, find `/* T1 */` and replace everything until `/* T2 */`:

```css
  /* T1 */
  .t1-layer { position: absolute; inset: 0; }

  .t1-flash {
    position: absolute;
    inset: 0;
    background: #F0EDE6;
    opacity: 0;
  }

  .t1-horizon {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 14vh;
    background: radial-gradient(
      ellipse at 50% 100%,
      rgba(8, 22, 65, 0.7) 0%,
      rgba(15, 45, 110, 0.5) 20%,
      rgba(25, 65, 140, 0.3) 40%,
      rgba(79, 195, 247, 0.08) 75%,
      transparent 90%
    );
    border-radius: 50% 50% 0 0 / 80% 80% 0 0;
  }

  .t1-streak-canvas {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    opacity: 0;
  }

  .t1-atmo-left {
    position: absolute;
    top: 0;
    bottom: 0;
    left: 0;
    width: 18vw;
    background: linear-gradient(
      to right,
      rgba(79, 195, 247, 0.45) 0%,
      rgba(30, 100, 200, 0.25) 40%,
      transparent 100%
    );
    opacity: 0;
  }

  .t1-atmo-right {
    position: absolute;
    top: 0;
    bottom: 0;
    right: 0;
    width: 18vw;
    background: linear-gradient(
      to left,
      rgba(79, 195, 247, 0.45) 0%,
      rgba(30, 100, 200, 0.25) 40%,
      transparent 100%
    );
    opacity: 0;
  }
```

- [ ] **Step 6: Verify build passes**

```bash
cd web && pnpm check
```

Expected: no TypeScript errors.

- [ ] **Step 7: Smoke test the transition**

```bash
pnpm dev
```

Open http://localhost:5173. Click "ENTER THE MISSIONS". Verify the sequence:
1. Horizon glow drops off the bottom of the screen
2. Radial star streaks rush outward from center, accelerating
3. Blue atmosphere smears appear on left/right edges and rush upward off screen
4. White breach flash at ~800ms
5. Streaks fade, void fills the screen
6. Shop page fades in

- [ ] **Step 8: Commit**

```bash
git add web/src/lib/transitions/t1-ascent.ts web/src/lib/components/TransitionOverlay.svelte
git commit -m "feat: T1 transition redesigned as first-person pull-up — horizon drop, radial streaks, breach flash"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] Earth POV night sky scene — Task 3 (milky way, atmosphere horizon, void background via global StarField)
- [x] Mouse look-around with fisheye-style tilt — Task 3 (CSS 3D rotateX/Y + Task 2 canvas parallax)
- [x] Star layer depth separation — Task 2 (3 layers at 0.8%, 1.8%, 3.5% multipliers)
- [x] Idle breathing animation — Task 3 (sine yoyo oscillation after 3s idle)
- [x] CTA "ENTER THE MISSIONS" with gold pulse — Task 3 (ctaPulse animation)
- [x] Mobile: tilt disabled — Task 3 (mousemove only, no deviceorientation)
- [x] T1 horizon drops away — Task 4 (t1-horizon div, y → 100vh)
- [x] T1 radial star streaks — Task 4 (drawStreaks canvas, 220 lines, speed-driven)
- [x] T1 atmosphere edge smears — Task 4 (atmoLeft/atmoRight, y → -100vh)
- [x] T1 breach flash — Task 4 (#F0EDE6 flash at 800ms)
- [x] T1 signature unchanged — Task 4 (triggerOut/triggerIn API preserved)
- [x] T2/T3/T4 untouched — correct, only T1 layer DOM modified

**Placeholder scan:** None found.

**Type consistency:** `T1Elements` interface defined in `t1-ascent.ts`, consumed in `TransitionOverlay.svelte` via `getT1Els()`. All 5 fields (`overlay`, `flash`, `horizon`, `streakCanvas`, `atmoLeft`, `atmoRight`) match between definition and usage.
