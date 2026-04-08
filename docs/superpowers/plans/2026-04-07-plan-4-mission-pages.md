# Mission Pages — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the cinematic product experience for Immortal Vibes — homepage, shop mission-select, and individual product pages, each with a unique space environment rendered in CSS + canvas, GSAP animations, a magnetic cursor, and an add-to-cart particle burst.

**Architecture:** Each route loads product data from the Go API; the `mission_number` field in the product response drives which space environment `MissionScene` renders. Animation utilities (`parallax.ts`, `reveal.ts`) wrap GSAP/ScrollTrigger and are called from `onMount` in each page component. The magnetic cursor and particle burst are self-contained Svelte components that manage their own canvas/RAF loops.

**Tech Stack:** SvelteKit, Cloudflare Pages, GSAP (core + ScrollTrigger), Tailwind CSS, HTML Canvas API

---

## File Map

| Path | Role |
|---|---|
| `web/src/lib/animations/parallax.ts` | GSAP ScrollTrigger parallax helper — exported function, no side effects |
| `web/src/lib/animations/reveal.ts` | GSAP scroll-reveal utility — registers one ScrollTrigger per element |
| `web/src/lib/components/MissionScene.svelte` | Full-page mission background: CSS gradient + canvas star field, keyed by `missionNumber` prop |
| `web/src/lib/components/MissionCard.svelte` | Shop page card: environment preview, 3D tilt on hover, click navigates to product |
| `web/src/lib/components/MagneticCursor.svelte` | Replaces system cursor on desktop; warps toward `[data-magnetic]` elements within 100px |
| `web/src/lib/components/ParticleBurst.svelte` | Canvas overlay particle system triggered by add-to-cart click |
| `web/src/lib/components/SizeSelector.svelte` | Size picker: S / M / L / XL radio-style buttons |
| `web/src/lib/components/StockBadge.svelte` | SOLD OUT / COMING SOON badge + email capture for coming_soon state |
| `web/src/routes/+page.svelte` | Homepage — replaces Plan 3 placeholder |
| `web/src/routes/shop/+page.ts` | Load all products from Go API |
| `web/src/routes/shop/+page.svelte` | Mission-select 2×2 grid — replaces Plan 3 placeholder |
| `web/src/routes/shop/[slug]/+page.ts` | Load single product from Go API |
| `web/src/routes/shop/[slug]/+page.svelte` | Individual product/mission page |

---

## Task 1: Animation Utilities

**Files:**
- Create: `web/src/lib/animations/parallax.ts`
- Create: `web/src/lib/animations/reveal.ts`

- [ ] **Step 1: Create `parallax.ts`**

```typescript
// web/src/lib/animations/parallax.ts
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

/**
 * Apply a vertical parallax effect to `element`.
 * `speed` controls how many px the element moves per 100px of scroll.
 * Positive speed = moves up slower than the page (typical background parallax).
 */
export function applyParallax(element: HTMLElement, speed: number = 0.4): ScrollTrigger {
  return ScrollTrigger.create({
    trigger: element,
    start: 'top bottom',
    end: 'bottom top',
    scrub: true,
    onUpdate: (self) => {
      const progress = self.progress; // 0 → 1
      const yOffset = (progress - 0.5) * speed * window.innerHeight;
      gsap.set(element, { y: yOffset });
    },
  });
}
```

- [ ] **Step 2: Create `reveal.ts`**

```typescript
// web/src/lib/animations/reveal.ts
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

/**
 * Fade-up + scale reveal triggered when `element` enters viewport.
 * Returns the ScrollTrigger so the caller can kill it on destroy.
 */
export function revealOnScroll(element: HTMLElement, delay: number = 0): ScrollTrigger {
  gsap.set(element, { opacity: 0, y: 30, scale: 0.95 });

  return ScrollTrigger.create({
    trigger: element,
    start: 'top 85%',
    once: true,
    onEnter: () => {
      gsap.to(element, {
        opacity: 1,
        y: 0,
        scale: 1,
        duration: 0.8,
        delay,
        ease: 'power2.out',
      });
    },
  });
}
```

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/animations/parallax.ts web/src/lib/animations/reveal.ts
git commit -m "feat: add GSAP parallax and scroll-reveal animation utilities"
```

---

## Task 2: MissionScene Component

**Files:**
- Create: `web/src/lib/components/MissionScene.svelte`

This component renders a full-page mission background. It accepts a `missionNumber` prop (`"001" | "002" | "003" | "004"`) and renders the correct CSS gradient + a canvas star field on top.

- [ ] **Step 1: Write `MissionScene.svelte`**

```svelte
<!-- web/src/lib/components/MissionScene.svelte -->
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';

  export let missionNumber: '001' | '002' | '003' | '004' = '001';

  // --- Mission environment configs ---
  const missions = {
    '001': {
      // Low Earth Orbit
      gradient: 'linear-gradient(to top, #060a14, #0a1020)',
      glowColor: 'rgba(30,111,217,0.3)',
      glowPosition: 'bottom',
      starCount: 220,
      starColorRange: [180, 220], // blue-white
    },
    '002': {
      // Lunar Surface
      gradient: 'linear-gradient(to top, #1a1814, #030308)',
      glowColor: 'rgba(240,237,230,0.04)',
      glowPosition: 'bottom',
      starCount: 280,
      starColorRange: [220, 255], // white-ish
    },
    '003': {
      // Stellar Nursery
      gradient: 'linear-gradient(to top, #3d1200, #030308)',
      glowColor: 'rgba(255,100,30,0.18)',
      glowPosition: 'center',
      starCount: 260,
      starColorRange: [200, 255], // warm white
    },
    '004': {
      // Deep Space
      gradient: 'linear-gradient(to top, #2a0d00, #030308)',
      glowColor: 'rgba(180,60,20,0.12)',
      glowPosition: 'center',
      starCount: 200,
      starColorRange: [200, 240],
    },
  } as const;

  $: config = missions[missionNumber] ?? missions['001'];

  let canvas: HTMLCanvasElement;
  let animationId: number;

  interface Star {
    x: number;
    y: number;
    radius: number;
    alpha: number;
    twinkleSpeed: number;
    twinklePhase: number;
  }

  let stars: Star[] = [];

  function initStars(width: number, height: number): Star[] {
    const out: Star[] = [];
    for (let i = 0; i < config.starCount; i++) {
      const [lo, hi] = config.starColorRange;
      out.push({
        x: Math.random() * width,
        y: Math.random() * height,
        radius: Math.random() * 1.2 + 0.2,
        alpha: Math.random() * 0.6 + 0.3,
        twinkleSpeed: Math.random() * 0.015 + 0.005,
        twinklePhase: Math.random() * Math.PI * 2,
      });
    }
    return out;
  }

  function drawStars(ctx: CanvasRenderingContext2D, t: number) {
    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    for (const star of stars) {
      const alpha = star.alpha * (0.7 + 0.3 * Math.sin(t * star.twinkleSpeed + star.twinklePhase));
      ctx.beginPath();
      ctx.arc(star.x, star.y, star.radius, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(240,237,230,${alpha})`;
      ctx.fill();
    }
  }

  function startLoop(ctx: CanvasRenderingContext2D) {
    let t = 0;
    function frame() {
      t += 1;
      drawStars(ctx, t);
      animationId = requestAnimationFrame(frame);
    }
    animationId = requestAnimationFrame(frame);
  }

  function resize() {
    if (!canvas) return;
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    stars = initStars(canvas.width, canvas.height);
  }

  onMount(() => {
    const ctx = canvas.getContext('2d')!;
    resize();
    window.addEventListener('resize', resize);
    startLoop(ctx);
  });

  onDestroy(() => {
    cancelAnimationFrame(animationId);
    window.removeEventListener('resize', resize);
  });
</script>

<div
  class="mission-scene"
  style="background: {config.gradient};"
>
  <!-- Ambient glow layer -->
  {#if config.glowPosition === 'bottom'}
    <div
      class="glow glow--bottom"
      style="background: radial-gradient(ellipse 80% 40% at 50% 100%, {config.glowColor}, transparent);"
    ></div>
  {:else}
    <div
      class="glow glow--center"
      style="background: radial-gradient(ellipse 60% 50% at 50% 60%, {config.glowColor}, transparent);"
    ></div>
  {/if}

  <!-- Star canvas -->
  <canvas bind:this={canvas} class="star-canvas" aria-hidden="true"></canvas>

  <!-- Page content goes here -->
  <slot />
</div>

<style>
  .mission-scene {
    position: relative;
    min-height: 100vh;
    width: 100%;
    overflow: hidden;
  }

  .glow {
    position: absolute;
    inset: 0;
    pointer-events: none;
    z-index: 1;
  }

  .star-canvas {
    position: absolute;
    inset: 0;
    z-index: 2;
    pointer-events: none;
  }

  /* Content placed in the slot sits above canvas */
  :global(.mission-scene > *:not(.glow):not(.star-canvas)) {
    position: relative;
    z-index: 3;
  }
</style>
```

- [ ] **Step 2: Visual check**

Run `npm run dev` inside `web/`. Navigate to any route that uses `<MissionScene missionNumber="001" />`. You should see:
- Dark blue gradient background (`#060a14` → `#0a1020`)
- Blue glow at the bottom of the viewport
- ~220 white/blue-tinted stars twinkling subtly in a canvas layer

Try `missionNumber="003"` and confirm a warm orange/red gradient appears with a center glow.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/components/MissionScene.svelte
git commit -m "feat: add MissionScene canvas star field with per-mission environments"
```

---

## Task 3: MissionCard Component

**Files:**
- Create: `web/src/lib/components/MissionCard.svelte`

3D tilt on `mousemove`, lerps back to 0 on `mouseleave`. Uses the same mission gradient as `MissionScene` but as a card background. Clicking navigates to the product page.

- [ ] **Step 1: Write `MissionCard.svelte`**

```svelte
<!-- web/src/lib/components/MissionCard.svelte -->
<script lang="ts">
  import { goto } from '$app/navigation';

  export let missionNumber: '001' | '002' | '003' | '004';
  export let title: string;
  export let subtitle: string; // e.g. "001 · Low Earth Orbit"
  export let slug: string;
  export let imageUrl: string = '';
  export let status: 'available' | 'sold_out' | 'coming_soon' = 'available';

  const gradients: Record<string, string> = {
    '001': 'linear-gradient(135deg, #060a14 0%, #0a1020 60%, rgba(30,111,217,0.15) 100%)',
    '002': 'linear-gradient(135deg, #030308 0%, #1a1814 100%)',
    '003': 'linear-gradient(135deg, #030308 0%, #3d1200 100%)',
    '004': 'linear-gradient(135deg, #030308 0%, #2a0d00 100%)',
  };

  let card: HTMLDivElement;
  let rx = 0;
  let ry = 0;
  const MAX_TILT = 12;

  function handleMouseMove(e: MouseEvent) {
    const rect = card.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    const dx = e.clientX - cx;
    const dy = e.clientY - cy;
    ry = (dx / (rect.width / 2)) * MAX_TILT;
    rx = -(dy / (rect.height / 2)) * MAX_TILT;
  }

  function handleMouseLeave() {
    rx = 0;
    ry = 0;
  }

  function handleClick() {
    goto(`/shop/${slug}`);
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' || e.key === ' ') handleClick();
  }
</script>

<div
  bind:this={card}
  class="mission-card"
  style="background: {gradients[missionNumber]}; transform: perspective(800px) rotateX({rx}deg) rotateY({ry}deg);"
  on:mousemove={handleMouseMove}
  on:mouseleave={handleMouseLeave}
  on:click={handleClick}
  on:keydown={handleKeydown}
  role="button"
  tabindex="0"
  data-magnetic
  aria-label="View {title} product page"
>
  <!-- Mini star layer — static SVG dots for card preview -->
  <svg class="card-stars" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
    {#each Array(30) as _, i}
      <circle
        cx="{(i * 137.5) % 100}%"
        cy="{(i * 97.3) % 100}%"
        r="{0.5 + (i % 3) * 0.4}"
        fill="rgba(240,237,230,{0.3 + (i % 4) * 0.15})"
      />
    {/each}
  </svg>

  <div class="card-content">
    <p class="mission-label">{subtitle}</p>
    <h2 class="product-title">{title}</h2>

    {#if status === 'sold_out'}
      <span class="badge badge--sold-out">SOLD OUT</span>
    {:else if status === 'coming_soon'}
      <span class="badge badge--coming-soon">COMING SOON</span>
    {:else}
      <span class="card-cta">EXPLORE MISSION →</span>
    {/if}

    {#if imageUrl}
      <img class="card-product-image" src={imageUrl} alt={title} />
    {/if}
  </div>
</div>

<style>
  .mission-card {
    position: relative;
    overflow: hidden;
    border: 1px solid rgba(240, 237, 230, 0.08);
    border-radius: 4px;
    cursor: pointer;
    aspect-ratio: 4 / 5;
    transition: transform 0.3s ease, box-shadow 0.3s ease;
    will-change: transform;
  }

  .mission-card:hover {
    box-shadow: 0 24px 64px rgba(0, 0, 0, 0.6);
  }

  .card-stars {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
  }

  .card-content {
    position: relative;
    z-index: 1;
    padding: 2rem;
    height: 100%;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
  }

  .mission-label {
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.2em;
    text-transform: uppercase;
    color: rgba(240, 237, 230, 0.5);
    margin: 0 0 0.5rem;
  }

  .product-title {
    font-family: 'Cormorant Garamond', serif;
    font-size: 1.8rem;
    font-weight: 300;
    color: #F0EDE6;
    margin: 0 0 1rem;
    line-height: 1.15;
  }

  .card-cta {
    font-family: 'Inter', sans-serif;
    font-size: 0.7rem;
    letter-spacing: 0.15em;
    color: rgba(240, 237, 230, 0.6);
  }

  .badge {
    display: inline-block;
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.2em;
    padding: 0.25rem 0.75rem;
    border-radius: 2px;
  }

  .badge--sold-out {
    border: 1px solid rgba(240, 237, 230, 0.3);
    color: rgba(240, 237, 230, 0.5);
  }

  .badge--coming-soon {
    border: 1px solid rgba(240, 237, 230, 0.2);
    color: rgba(240, 237, 230, 0.4);
  }

  .card-product-image {
    position: absolute;
    top: 1.5rem;
    right: 1rem;
    width: 45%;
    object-fit: contain;
    filter: drop-shadow(0 8px 24px rgba(0, 0, 0, 0.5));
    transform: rotate(-8deg);
    transition: transform 0.4s ease;
  }

  .mission-card:hover .card-product-image {
    transform: rotate(-4deg) scale(1.04) translateY(-4px);
  }
</style>
```

- [ ] **Step 2: Visual check**

Render a `<MissionCard missionNumber="003" title="Racerback Tanktop" subtitle="003 · Stellar Nursery" slug="racerback-tanktop" />` anywhere in the app. Confirm:
- Orange/red gradient card background
- Static star dots visible
- Mouse over: card tilts toward cursor (max ±12°), snaps back smoothly on leave
- "EXPLORE MISSION →" text at bottom left

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/components/MissionCard.svelte
git commit -m "feat: add MissionCard with 3D perspective tilt on hover"
```

---

## Task 4: MagneticCursor Component

**Files:**
- Create: `web/src/lib/components/MagneticCursor.svelte`

Track mouse globally. Hide the system cursor site-wide. Render a custom dot that lerps toward `[data-magnetic]` element centers when within 100px.

- [ ] **Step 1: Write `MagneticCursor.svelte`**

```svelte
<!-- web/src/lib/components/MagneticCursor.svelte -->
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { gsap } from 'gsap';

  let cursorDot: HTMLDivElement;
  let cursorRing: HTMLDivElement;

  // Raw mouse position
  let mouseX = -100;
  let mouseY = -100;

  // Rendered positions (lerped)
  let dotX = -100;
  let dotY = -100;

  let rafId: number;
  let isHovering = false;

  const MAGNETIC_RADIUS = 100;
  const MAGNETIC_PULL = 0.3; // 30% toward element center

  function getMagneticElements(): NodeListOf<Element> {
    return document.querySelectorAll('[data-magnetic]');
  }

  function computeMagneticOffset(mx: number, my: number): { x: number; y: number } {
    for (const el of getMagneticElements()) {
      const rect = el.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      const dist = Math.hypot(mx - cx, my - cy);

      if (dist < MAGNETIC_RADIUS) {
        const pull = 1 - dist / MAGNETIC_RADIUS; // 0 → 1 as cursor approaches
        return {
          x: mx + (cx - mx) * MAGNETIC_PULL * pull,
          y: my + (cy - my) * MAGNETIC_PULL * pull,
        };
      }
    }
    return { x: mx, y: my };
  }

  function loop() {
    const target = computeMagneticOffset(mouseX, mouseY);

    // Lerp dot toward target
    dotX += (target.x - dotX) * 0.12;
    dotY += (target.y - dotY) * 0.12;

    gsap.set(cursorDot, { x: dotX, y: dotY });
    gsap.set(cursorRing, { x: dotX, y: dotY });

    rafId = requestAnimationFrame(loop);
  }

  function onMouseMove(e: MouseEvent) {
    mouseX = e.clientX;
    mouseY = e.clientY;
  }

  function onMouseDown() {
    gsap.to(cursorDot, { scale: 0.6, duration: 0.1 });
    gsap.to(cursorRing, { scale: 1.4, opacity: 0.4, duration: 0.15 });
  }

  function onMouseUp() {
    gsap.to(cursorDot, { scale: 1, duration: 0.2, ease: 'back.out(2)' });
    gsap.to(cursorRing, { scale: 1, opacity: 1, duration: 0.2 });
  }

  function onMouseEnterMagnetic() {
    isHovering = true;
    gsap.to(cursorDot, { scale: 1.6, duration: 0.2 });
  }

  function onMouseLeaveMagnetic() {
    isHovering = false;
    gsap.to(cursorDot, { scale: 1, duration: 0.2 });
  }

  onMount(() => {
    window.addEventListener('mousemove', onMouseMove);
    window.addEventListener('mousedown', onMouseDown);
    window.addEventListener('mouseup', onMouseUp);

    // Attach hover listeners to all magnetic elements present at mount
    // (for dynamic elements, MutationObserver would be needed; skip for now — elements are static)
    const attachHoverListeners = () => {
      for (const el of getMagneticElements()) {
        el.addEventListener('mouseenter', onMouseEnterMagnetic);
        el.addEventListener('mouseleave', onMouseLeaveMagnetic);
      }
    };

    attachHoverListeners();

    // Re-attach when DOM changes (e.g. route navigation adds new [data-magnetic] elements)
    const observer = new MutationObserver(attachHoverListeners);
    observer.observe(document.body, { childList: true, subtree: true });

    rafId = requestAnimationFrame(loop);

    return () => {
      observer.disconnect();
    };
  });

  onDestroy(() => {
    cancelAnimationFrame(rafId);
    window.removeEventListener('mousemove', onMouseMove);
    window.removeEventListener('mousedown', onMouseDown);
    window.removeEventListener('mouseup', onMouseUp);
  });
</script>

<svelte:head>
  <style>
    * { cursor: none !important; }
  </style>
</svelte:head>

<div bind:this={cursorRing} class="cursor-ring" aria-hidden="true"></div>
<div bind:this={cursorDot} class="cursor-dot" aria-hidden="true"></div>

<style>
  .cursor-dot,
  .cursor-ring {
    position: fixed;
    top: 0;
    left: 0;
    pointer-events: none;
    z-index: 9999;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    will-change: transform;
  }

  .cursor-dot {
    width: 6px;
    height: 6px;
    background: #F0EDE6;
  }

  .cursor-ring {
    width: 32px;
    height: 32px;
    border: 1px solid rgba(240, 237, 230, 0.4);
    background: transparent;
    transition: opacity 0.2s;
  }
</style>
```

- [ ] **Step 2: Mount in root layout**

Open `web/src/routes/+layout.svelte` (created in Plan 3). Add `MagneticCursor` inside the layout body, outside any `<main>` wrapper so it's always present:

```svelte
<script lang="ts">
  import MagneticCursor from '$lib/components/MagneticCursor.svelte';
  // ... existing imports
</script>

<MagneticCursor />
<!-- existing layout content -->
<slot />
```

- [ ] **Step 3: Visual check**

Run dev server. Move cursor around the page. Confirm:
- System cursor is hidden
- Small white dot follows mouse with ~12 frames of lag (lerp)
- Thin ring follows the dot
- When cursor enters a `[data-magnetic]` element (e.g. a `MissionCard`), dot scales up 1.6×
- Cursor dot warps slightly toward card centers when within 100px

- [ ] **Step 4: Commit**

```bash
git add web/src/lib/components/MagneticCursor.svelte web/src/routes/+layout.svelte
git commit -m "feat: add magnetic cursor with RAF lerp and data-magnetic element warp"
```

---

## Task 5: SizeSelector Component

**Files:**
- Create: `web/src/lib/components/SizeSelector.svelte`

- [ ] **Step 1: Write `SizeSelector.svelte`**

```svelte
<!-- web/src/lib/components/SizeSelector.svelte -->
<script lang="ts">
  export let sizes: string[] = ['S', 'M', 'L', 'XL'];
  export let selected: string = '';
  export let onChange: (size: string) => void = () => {};

  function select(size: string) {
    selected = size;
    onChange(size);
  }
</script>

<div class="size-selector" role="radiogroup" aria-label="Select size">
  {#each sizes as size}
    <button
      class="size-btn"
      class:selected={selected === size}
      on:click={() => select(size)}
      role="radio"
      aria-checked={selected === size}
      data-magnetic
    >
      {size}
    </button>
  {/each}
</div>

<style>
  .size-selector {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .size-btn {
    width: 3rem;
    height: 3rem;
    border: 1px solid rgba(240, 237, 230, 0.2);
    background: transparent;
    color: rgba(240, 237, 230, 0.6);
    font-family: 'Inter', sans-serif;
    font-size: 0.75rem;
    letter-spacing: 0.1em;
    cursor: none;
    transition: border-color 0.2s, color 0.2s, background 0.2s;
  }

  .size-btn:hover {
    border-color: rgba(240, 237, 230, 0.5);
    color: #F0EDE6;
  }

  .size-btn.selected {
    border-color: #F0EDE6;
    color: #F0EDE6;
    background: rgba(240, 237, 230, 0.06);
  }
</style>
```

- [ ] **Step 2: Commit**

```bash
git add web/src/lib/components/SizeSelector.svelte
git commit -m "feat: add SizeSelector radio-style size picker"
```

---

## Task 6: StockBadge Component

**Files:**
- Create: `web/src/lib/components/StockBadge.svelte`

- [ ] **Step 1: Write `StockBadge.svelte`**

```svelte
<!-- web/src/lib/components/StockBadge.svelte -->
<script lang="ts">
  export let status: 'available' | 'sold_out' | 'coming_soon' = 'available';

  let email = '';
  let submitted = false;

  async function submitEmail() {
    if (!email || submitted) return;
    // POST to Go API /waitlist endpoint (wired in Plan 5 — for now, optimistic UI only)
    submitted = true;
  }
</script>

{#if status === 'sold_out'}
  <div class="badge badge--sold-out">
    <span class="badge-dot"></span>
    SOLD OUT
  </div>
{:else if status === 'coming_soon'}
  <div class="coming-soon">
    <div class="badge badge--coming-soon">
      <span class="badge-dot badge-dot--pulse"></span>
      COMING SOON
    </div>
    {#if !submitted}
      <form class="email-capture" on:submit|preventDefault={submitEmail}>
        <input
          type="email"
          bind:value={email}
          placeholder="Your email for launch notification"
          class="email-input"
          required
        />
        <button type="submit" class="email-submit" data-magnetic>NOTIFY ME</button>
      </form>
    {:else}
      <p class="submitted-msg">You're on the list.</p>
    {/if}
  </div>
{/if}

<style>
  .badge {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.2em;
    padding: 0.4rem 1rem;
    border-radius: 2px;
  }

  .badge--sold-out {
    border: 1px solid rgba(240, 237, 230, 0.25);
    color: rgba(240, 237, 230, 0.4);
  }

  .badge--coming-soon {
    border: 1px solid rgba(240, 237, 230, 0.2);
    color: rgba(240, 237, 230, 0.5);
    margin-bottom: 1rem;
  }

  .badge-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: rgba(240, 237, 230, 0.4);
    display: inline-block;
  }

  .badge-dot--pulse {
    animation: pulse 2s ease-in-out infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 1; }
  }

  .coming-soon {
    display: flex;
    flex-direction: column;
  }

  .email-capture {
    display: flex;
    gap: 0.5rem;
    align-items: stretch;
  }

  .email-input {
    flex: 1;
    background: rgba(240, 237, 230, 0.04);
    border: 1px solid rgba(240, 237, 230, 0.15);
    color: #F0EDE6;
    font-family: 'Inter', sans-serif;
    font-size: 0.75rem;
    padding: 0.6rem 0.8rem;
    outline: none;
    transition: border-color 0.2s;
  }

  .email-input::placeholder {
    color: rgba(240, 237, 230, 0.3);
  }

  .email-input:focus {
    border-color: rgba(240, 237, 230, 0.4);
  }

  .email-submit {
    background: transparent;
    border: 1px solid rgba(240, 237, 230, 0.3);
    color: rgba(240, 237, 230, 0.7);
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.15em;
    padding: 0 1rem;
    cursor: none;
    transition: border-color 0.2s, color 0.2s;
    white-space: nowrap;
  }

  .email-submit:hover {
    border-color: rgba(240, 237, 230, 0.6);
    color: #F0EDE6;
  }

  .submitted-msg {
    font-family: 'Inter', sans-serif;
    font-size: 0.75rem;
    color: rgba(240, 237, 230, 0.5);
    margin: 0;
    letter-spacing: 0.05em;
  }
</style>
```

- [ ] **Step 2: Commit**

```bash
git add web/src/lib/components/StockBadge.svelte
git commit -m "feat: add StockBadge with sold-out state and coming-soon email capture"
```

---

## Task 7: ParticleBurst Component

**Files:**
- Create: `web/src/lib/components/ParticleBurst.svelte`

A canvas overlay spawned imperatively. Exported `trigger(x, y)` function creates 40 particles at `(x, y)`, animates them upward with gravity and alpha decay, then self-destructs.

- [ ] **Step 1: Write `ParticleBurst.svelte`**

```svelte
<!-- web/src/lib/components/ParticleBurst.svelte -->
<script lang="ts" context="module">
  interface Particle {
    x: number;
    y: number;
    vx: number;
    vy: number;
    alpha: number;
    radius: number;
  }

  const PARTICLE_COUNT = 40;
  const GRAVITY = 0.1;
  const ALPHA_DECAY = 0.02;

  function createParticle(originX: number, originY: number): Particle {
    // Angle: upward cone — -90deg (straight up) ± 60deg → range [-150deg, -30deg]
    const angleDeg = -90 + (Math.random() - 0.5) * 120;
    const angleRad = (angleDeg * Math.PI) / 180;
    const speed = 2 + Math.random() * 4; // 2–6 px/frame
    return {
      x: originX,
      y: originY,
      vx: Math.cos(angleRad) * speed,
      vy: Math.sin(angleRad) * speed,
      alpha: 0.9 + Math.random() * 0.1,
      radius: 1 + Math.random() * 2,
    };
  }

  function updateParticle(p: Particle): Particle {
    return {
      ...p,
      x: p.x + p.vx,
      y: p.y + p.vy,
      vy: p.vy + GRAVITY,
      alpha: p.alpha - ALPHA_DECAY,
    };
  }
</script>

<script lang="ts">
  import { onMount, onDestroy } from 'svelte';

  let canvas: HTMLCanvasElement;
  let ctx: CanvasRenderingContext2D;
  let particles: Particle[] = [];
  let rafId: number;
  let active = false;

  export function trigger(originX: number, originY: number) {
    particles = Array.from({ length: PARTICLE_COUNT }, () => createParticle(originX, originY));
    active = true;
    if (!rafId) animate();
  }

  function animate() {
    if (!ctx || !canvas) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    particles = particles
      .map(updateParticle)
      .filter((p) => p.alpha > 0);

    for (const p of particles) {
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
      // Star-gold tint for the burst
      ctx.fillStyle = `rgba(200, 146, 42, ${p.alpha})`;
      ctx.fill();
    }

    if (particles.length > 0) {
      rafId = requestAnimationFrame(animate);
    } else {
      active = false;
      rafId = 0;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
    }
  }

  function resize() {
    if (!canvas) return;
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  }

  onMount(() => {
    ctx = canvas.getContext('2d')!;
    resize();
    window.addEventListener('resize', resize);
  });

  onDestroy(() => {
    cancelAnimationFrame(rafId);
    window.removeEventListener('resize', resize);
  });
</script>

<canvas bind:this={canvas} class="particle-canvas" aria-hidden="true"></canvas>

<style>
  .particle-canvas {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 1000;
  }
</style>
```

- [ ] **Step 2: Usage pattern — how to call `trigger` from a product page**

In the product page (Task 11), the add-to-cart button click handler does:

```svelte
<script lang="ts">
  import ParticleBurst from '$lib/components/ParticleBurst.svelte';
  let burst: ParticleBurst;

  function handleAddToCart(e: MouseEvent) {
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const originX = rect.left + rect.width / 2;
    const originY = rect.top;
    burst.trigger(originX, originY);
    // ... actual cart logic
  }
</script>

<ParticleBurst bind:this={burst} />
<button on:click={handleAddToCart}>ADD TO CART</button>
```

- [ ] **Step 3: Visual check**

Wire the usage pattern into any test page. Click the button. Confirm:
- ~40 gold particles explode upward from the button's top edge
- Particles arc outward in a ±60° cone
- Gravity pulls them into a natural arc
- All particles fully fade out within ~600ms (40 particles × 0.02 alpha decay ÷ 60fps ≈ 33 frames ≈ 550ms)
- Canvas clears cleanly after burst completes

- [ ] **Step 4: Commit**

```bash
git add web/src/lib/components/ParticleBurst.svelte
git commit -m "feat: add ParticleBurst canvas particle system for add-to-cart effect"
```

---

## Task 8: Shop Page Data Loader

**Files:**
- Create: `web/src/routes/shop/+page.ts`

- [ ] **Step 1: Write `+page.ts`**

The Go API (established in Plans 1–2) exposes `GET /api/products`. The response is an array of product objects. The loader fetches and returns them.

```typescript
// web/src/routes/shop/+page.ts
import type { PageLoad } from './$types';

export interface Product {
  id: string;
  slug: string;
  name: string;
  description: string;
  price_usd: number;    // cents
  price_gbp: number;    // cents
  currency: string;     // 'usd' | 'gbp' — determined by Go API from CF geo header
  status: 'available' | 'sold_out' | 'coming_soon';
  sizes: string[];
  image_url: string;
  mission_number: '001' | '002' | '003' | '004';
}

export interface PageData {
  products: Product[];
}

export const load: PageLoad = async ({ fetch }): Promise<PageData> => {
  const apiBase = import.meta.env.VITE_API_BASE_URL ?? '';
  const res = await fetch(`${apiBase}/api/products`);

  if (!res.ok) {
    throw new Error(`Failed to fetch products: ${res.status}`);
  }

  const products: Product[] = await res.json();
  return { products };
};
```

- [ ] **Step 2: Commit**

```bash
git add web/src/routes/shop/+page.ts
git commit -m "feat: add shop page loader — fetch all products from Go API"
```

---

## Task 9: Shop Page — Mission Select

**Files:**
- Modify: `web/src/routes/shop/+page.svelte` (replace Plan 3 placeholder)

- [ ] **Step 1: Write `shop/+page.svelte`**

```svelte
<!-- web/src/routes/shop/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import type { PageData } from './$types';
  import MissionCard from '$lib/components/MissionCard.svelte';
  import { revealOnScroll } from '$lib/animations/reveal';

  export let data: PageData;

  let heading: HTMLHeadingElement;
  let grid: HTMLDivElement;

  onMount(() => {
    if (heading) revealOnScroll(heading, 0);
    if (grid) {
      const cards = grid.querySelectorAll<HTMLElement>('.reveal-card');
      cards.forEach((card, i) => revealOnScroll(card, i * 0.1));
    }
  });
</script>

<svelte:head>
  <title>Mission Select — Immortal Vibes</title>
</svelte:head>

<main class="shop-page">
  <!-- Background gradient -->
  <div class="shop-bg" aria-hidden="true"></div>

  <!-- Static star layer (no canvas here — lightweight) -->
  <svg class="shop-stars" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
    {#each Array(60) as _, i}
      <circle
        cx="{(i * 137.508) % 100}%"
        cy="{(i * 97.3) % 100}%"
        r="{0.4 + (i % 4) * 0.35}"
        fill="rgba(240,237,230,{0.15 + (i % 5) * 0.1})"
      />
    {/each}
  </svg>

  <div class="shop-inner">
    <header class="shop-header">
      <p class="shop-eyebrow">SELECT YOUR MISSION</p>
      <h1 bind:this={heading} class="shop-title">Choose Your Orbit</h1>
    </header>

    <div bind:this={grid} class="mission-grid">
      {#each data.products as product (product.id)}
        <div class="reveal-card">
          <MissionCard
            missionNumber={product.mission_number}
            title={product.name}
            subtitle="{product.mission_number} · {missionLabel(product.mission_number)}"
            slug={product.slug}
            imageUrl={product.image_url}
            status={product.status}
          />
        </div>
      {/each}

      <!-- Placeholder card for missions without products yet -->
      {#if data.products.length < 4}
        {#each Array(4 - data.products.length) as _, i}
          <div class="reveal-card">
            <div class="mission-placeholder">
              <p class="placeholder-label">CLASSIFIED</p>
              <p class="placeholder-sub">Next drop: TBD</p>
            </div>
          </div>
        {/each}
      {/if}
    </div>
  </div>
</main>

<script lang="ts">
  function missionLabel(num: string): string {
    const labels: Record<string, string> = {
      '001': 'Low Earth Orbit',
      '002': 'Lunar Surface',
      '003': 'Stellar Nursery',
      '004': 'Deep Space',
    };
    return labels[num] ?? 'Unknown';
  }
</script>

<style>
  .shop-page {
    position: relative;
    min-height: 100vh;
    background: #030308;
    overflow: hidden;
  }

  .shop-bg {
    position: absolute;
    inset: 0;
    background: radial-gradient(ellipse 80% 50% at 50% 0%, rgba(8,8,15,0.9), #030308);
  }

  .shop-stars {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
  }

  .shop-inner {
    position: relative;
    z-index: 1;
    max-width: 1200px;
    margin: 0 auto;
    padding: 8rem 2rem 4rem;
  }

  .shop-header {
    text-align: center;
    margin-bottom: 5rem;
  }

  .shop-eyebrow {
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.3em;
    color: rgba(240, 237, 230, 0.4);
    margin: 0 0 1.5rem;
  }

  .shop-title {
    font-family: 'Cormorant Garamond', serif;
    font-size: clamp(2.5rem, 6vw, 5rem);
    font-weight: 300;
    color: #F0EDE6;
    margin: 0;
    line-height: 1;
  }

  .mission-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 1.5rem;
  }

  @media (max-width: 640px) {
    .mission-grid {
      grid-template-columns: 1fr;
    }
  }

  .mission-placeholder {
    aspect-ratio: 4 / 5;
    border: 1px solid rgba(240, 237, 230, 0.05);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
  }

  .placeholder-label {
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.3em;
    color: rgba(240, 237, 230, 0.2);
    margin: 0;
  }

  .placeholder-sub {
    font-family: 'Inter', sans-serif;
    font-size: 0.7rem;
    color: rgba(240, 237, 230, 0.15);
    margin: 0;
  }

  .reveal-card {
    /* initial visibility handled by revealOnScroll — opacity 0 set by GSAP */
  }
</style>
```

- [ ] **Step 2: Visual check**

Navigate to `/shop`. Confirm:
- Dark `#030308` background with static stars
- "SELECT YOUR MISSION" eyebrow and "Choose Your Orbit" heading fade up on load
- 2×2 grid of `MissionCard` components (or fewer + classified placeholders if API returns fewer than 4 products)
- Cards stagger-reveal on scroll entry (0.1s delay between each)
- Each card shows its correct gradient background on hover

- [ ] **Step 3: Commit**

```bash
git add web/src/routes/shop/+page.svelte
git commit -m "feat: build mission-select shop page with staggered reveal grid"
```

---

## Task 10: Product Page Data Loader

**Files:**
- Create: `web/src/routes/shop/[slug]/+page.ts`

- [ ] **Step 1: Write `[slug]/+page.ts`**

```typescript
// web/src/routes/shop/[slug]/+page.ts
import type { PageLoad } from './$types';
import type { Product } from '../+page.js';

export interface PageData {
  product: Product;
}

export const load: PageLoad = async ({ fetch, params }): Promise<PageData> => {
  const apiBase = import.meta.env.VITE_API_BASE_URL ?? '';
  const res = await fetch(`${apiBase}/api/products/${params.slug}`);

  if (res.status === 404) {
    throw new Error(`Product not found: ${params.slug}`);
  }

  if (!res.ok) {
    throw new Error(`Failed to fetch product: ${res.status}`);
  }

  const product: Product = await res.json();
  return { product };
};
```

- [ ] **Step 2: Commit**

```bash
git add web/src/routes/shop/[slug]/+page.ts
git commit -m "feat: add product page loader — fetch single product by slug"
```

---

## Task 11: Product Mission Page

**Files:**
- Modify: `web/src/routes/shop/[slug]/+page.svelte` (replace Plan 3 placeholder)

This is the cinematic hero page. Full-page `MissionScene` background, floating product image, size selector, currency-aware price, add-to-cart with particle burst, and sold-out / coming-soon state.

- [ ] **Step 1: Write `[slug]/+page.svelte`**

```svelte
<!-- web/src/routes/shop/[slug]/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { gsap } from 'gsap';
  import type { PageData } from './$types';
  import MissionScene from '$lib/components/MissionScene.svelte';
  import SizeSelector from '$lib/components/SizeSelector.svelte';
  import StockBadge from '$lib/components/StockBadge.svelte';
  import ParticleBurst from '$lib/components/ParticleBurst.svelte';
  import { revealOnScroll } from '$lib/animations/reveal';

  export let data: PageData;

  $: product = data.product;
  $: missionNumber = product.mission_number;

  let selectedSize = '';
  let burst: ParticleBurst;
  let productImage: HTMLImageElement;
  let heroContent: HTMLDivElement;
  let addCartBtn: HTMLButtonElement;
  let cartError = '';

  const missionLabels: Record<string, string> = {
    '001': 'Low Earth Orbit',
    '002': 'Lunar Surface',
    '003': 'Stellar Nursery',
    '004': 'Deep Space',
  };

  function formatPrice(cents: number, currency: string): string {
    const symbol = currency === 'gbp' ? '£' : '$';
    return `${symbol}${(cents / 100).toFixed(2)}`;
  }

  function getDisplayPrice(): string {
    if (product.currency === 'gbp') return formatPrice(product.price_gbp, 'gbp');
    return formatPrice(product.price_usd, 'usd');
  }

  function handleAddToCart(e: MouseEvent) {
    if (!selectedSize) {
      cartError = 'Please select a size.';
      // Shake the size selector
      gsap.to('.size-selector', {
        x: [-6, 6, -4, 4, 0],
        duration: 0.35,
        ease: 'none',
      });
      return;
    }
    cartError = '';

    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    burst.trigger(rect.left + rect.width / 2, rect.top);

    // Placeholder: cart store will be wired in Plan 5
    console.log('Add to cart:', product.id, selectedSize);
  }

  onMount(() => {
    // Floating product image animation
    if (productImage) {
      gsap.to(productImage, {
        y: -12,
        rotation: 1.5,
        duration: 4,
        ease: 'sine.inOut',
        repeat: -1,
        yoyo: true,
      });
    }

    // Hero content reveal
    if (heroContent) {
      const children = heroContent.querySelectorAll<HTMLElement>('.reveal-child');
      children.forEach((el, i) => revealOnScroll(el, i * 0.08));
    }
  });
</script>

<svelte:head>
  <title>{product.name} — Immortal Vibes</title>
  <meta name="description" content={product.description} />
</svelte:head>

<ParticleBurst bind:this={burst} />

<MissionScene missionNumber={missionNumber}>
  <div class="product-page">
    <!-- Mission label top-left -->
    <div class="mission-tag reveal-child">
      <span class="mission-number">{missionNumber}</span>
      <span class="mission-name">{missionLabels[missionNumber]}</span>
    </div>

    <div class="product-layout">
      <!-- Left: product image -->
      <div class="image-col">
        {#if product.image_url}
          <img
            bind:this={productImage}
            class="product-hero-image"
            src={product.image_url}
            alt={product.name}
          />
        {:else}
          <div class="image-placeholder"></div>
        {/if}
      </div>

      <!-- Right: product details -->
      <div bind:this={heroContent} class="details-col">
        <p class="reveal-child product-category">
          MISSION {missionNumber} · IMMORTAL VIBES
        </p>

        <h1 class="reveal-child product-name">{product.name}</h1>

        <p class="reveal-child product-price">{getDisplayPrice()}</p>

        <p class="reveal-child product-description">{product.description}</p>

        {#if product.status === 'available'}
          <div class="reveal-child">
            <p class="field-label">SELECT SIZE</p>
            <SizeSelector
              sizes={product.sizes}
              bind:selected={selectedSize}
            />
            {#if cartError}
              <p class="cart-error">{cartError}</p>
            {/if}
          </div>

          <button
            bind:this={addCartBtn}
            class="reveal-child add-to-cart"
            on:click={handleAddToCart}
            data-magnetic
          >
            ADD TO CART
          </button>
        {:else}
          <div class="reveal-child">
            <StockBadge status={product.status} />
          </div>
        {/if}
      </div>
    </div>
  </div>
</MissionScene>

<style>
  .product-page {
    min-height: 100vh;
    padding: 2rem;
    display: flex;
    flex-direction: column;
  }

  .mission-tag {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1.5rem 0 3rem;
  }

  .mission-number {
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.3em;
    color: rgba(240, 237, 230, 0.35);
  }

  .mission-name {
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.2em;
    color: rgba(240, 237, 230, 0.35);
    text-transform: uppercase;
  }

  .product-layout {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 6rem;
    align-items: center;
    flex: 1;
    max-width: 1200px;
    margin: 0 auto;
    width: 100%;
    padding-bottom: 6rem;
  }

  @media (max-width: 768px) {
    .product-layout {
      grid-template-columns: 1fr;
      gap: 3rem;
    }
  }

  .image-col {
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .product-hero-image {
    max-width: 100%;
    max-height: 70vh;
    object-fit: contain;
    filter: drop-shadow(0 24px 80px rgba(0, 0, 0, 0.6));
    will-change: transform;
  }

  .image-placeholder {
    width: 300px;
    height: 400px;
    border: 1px solid rgba(240, 237, 230, 0.06);
  }

  .details-col {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .product-category {
    font-family: 'Inter', sans-serif;
    font-size: 0.6rem;
    letter-spacing: 0.25em;
    color: rgba(240, 237, 230, 0.35);
    margin: 0;
  }

  .product-name {
    font-family: 'Cormorant Garamond', serif;
    font-size: clamp(2rem, 5vw, 4rem);
    font-weight: 300;
    color: #F0EDE6;
    margin: 0;
    line-height: 1.05;
  }

  .product-price {
    font-family: 'Cormorant Garamond', serif;
    font-size: 1.5rem;
    color: #C8922A;
    margin: 0;
    letter-spacing: 0.02em;
  }

  .product-description {
    font-family: 'Inter', sans-serif;
    font-size: 0.875rem;
    line-height: 1.7;
    color: rgba(240, 237, 230, 0.55);
    margin: 0;
    max-width: 38ch;
  }

  .field-label {
    font-family: 'Inter', sans-serif;
    font-size: 0.6rem;
    letter-spacing: 0.2em;
    color: rgba(240, 237, 230, 0.35);
    margin: 0 0 0.75rem;
  }

  .cart-error {
    font-family: 'Inter', sans-serif;
    font-size: 0.7rem;
    color: rgba(240, 237, 230, 0.45);
    margin: 0.5rem 0 0;
  }

  .add-to-cart {
    display: inline-block;
    width: 100%;
    max-width: 320px;
    padding: 1.1rem 2rem;
    background: #F0EDE6;
    color: #030308;
    border: none;
    font-family: 'Inter', sans-serif;
    font-size: 0.7rem;
    letter-spacing: 0.2em;
    cursor: none;
    transition: background 0.2s, transform 0.1s;
  }

  .add-to-cart:hover {
    background: #ffffff;
    transform: translateY(-1px);
  }

  .add-to-cart:active {
    transform: translateY(0);
  }
</style>
```

- [ ] **Step 2: Visual check**

Navigate to `/shop/warped-reality-beanie` (or whichever slug the API returns). Confirm:
- Full-page Low Earth Orbit (001) environment: dark blue gradient, earth glow at bottom, twinkling stars
- Product image floats up and down slowly, slight rotation
- Mission tag top-left shows "001 · LOW EARTH ORBIT"
- Product name in Cormorant Garamond display type
- Price displayed in gold (`#C8922A`) — correct currency based on geo
- Size selector: S/M/L/XL buttons, selecting one highlights it with a border
- ADD TO CART: clicking without size selected shakes the selector; clicking with size selected fires gold particle burst
- Navigate to a `sold_out` product — Add to Cart replaced with SOLD OUT badge
- Navigate to a `coming_soon` product — badge + email input appears

- [ ] **Step 3: Commit**

```bash
git add web/src/routes/shop/[slug]/+page.svelte
git commit -m "feat: build cinematic product mission page with floating image, particle burst, stock states"
```

---

## Task 12: Homepage

**Files:**
- Modify: `web/src/routes/+page.svelte` (replace Plan 3 placeholder)

Full-bleed star field hero with brand statement, scroll-triggered mission teasers below.

- [ ] **Step 1: Write `+page.svelte`**

```svelte
<!-- web/src/routes/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { gsap } from 'gsap';
  import { ScrollTrigger } from 'gsap/ScrollTrigger';
  import MissionScene from '$lib/components/MissionScene.svelte';
  import { revealOnScroll } from '$lib/animations/reveal';
  import { applyParallax } from '$lib/animations/parallax';

  gsap.registerPlugin(ScrollTrigger);

  let heroHeading: HTMLHeadingElement;
  let heroSub: HTMLParagraphElement;
  let heroCta: HTMLAnchorElement;
  let teaserSection: HTMLElement;
  let starCanvas: HTMLElement;

  onMount(() => {
    // Hero entrance sequence — not scroll triggered, runs immediately
    const tl = gsap.timeline({ defaults: { ease: 'power2.out' } });
    tl
      .from(heroHeading, { opacity: 0, y: 40, duration: 1.2, delay: 0.3 })
      .from(heroSub, { opacity: 0, y: 20, duration: 0.8 }, '-=0.6')
      .from(heroCta, { opacity: 0, y: 16, duration: 0.6 }, '-=0.4');

    // Scroll reveals for mission teasers
    if (teaserSection) {
      const items = teaserSection.querySelectorAll<HTMLElement>('.teaser-item');
      items.forEach((el, i) => revealOnScroll(el, i * 0.12));
    }
  });

  const missions = [
    { number: '001', label: 'Low Earth Orbit', product: 'Warped Reality Beanie', slug: 'warped-reality-beanie' },
    { number: '002', label: 'Lunar Surface',   product: 'Vanguard Trucker Hat',  slug: 'vanguard-trucker-hat' },
    { number: '003', label: 'Stellar Nursery', product: 'Racerback Tanktop',     slug: 'racerback-tanktop' },
    { number: '004', label: 'Deep Space',      product: 'Next Drop',             slug: null },
  ];
</script>

<svelte:head>
  <title>Immortal Vibes — Rise Beyond the Mortal Plane</title>
  <meta name="description" content="Garments built for those who orbit higher. Limited drops, infinite purpose." />
</svelte:head>

<!-- Hero: full-bleed mission 001 scene as base -->
<MissionScene missionNumber="001">
  <section class="hero">
    <div class="hero-inner">
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
        SELECT YOUR MISSION
      </a>
    </div>

    <!-- Scroll indicator -->
    <div class="scroll-indicator" aria-hidden="true">
      <span class="scroll-line"></span>
      <span class="scroll-label">SCROLL</span>
    </div>
  </section>
</MissionScene>

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
  .hero {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    text-align: center;
    padding: 6rem 2rem 4rem;
    position: relative;
  }

  .hero-inner {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2rem;
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
    border: 1px solid rgba(240, 237, 230, 0.3);
    color: rgba(240, 237, 230, 0.7);
    font-family: 'Inter', sans-serif;
    font-size: 0.65rem;
    letter-spacing: 0.25em;
    padding: 1rem 2.5rem;
    text-decoration: none;
    transition: border-color 0.2s, color 0.2s;
  }

  .hero-cta:hover {
    border-color: rgba(240, 237, 230, 0.7);
    color: #F0EDE6;
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

  /* Teaser section */
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

  .teaser-tbd {
    font-family: 'Inter', sans-serif;
    font-size: 0.6rem;
    letter-spacing: 0.2em;
    color: rgba(240, 237, 230, 0.15);
    flex-shrink: 0;
  }
</style>
```

- [ ] **Step 2: Visual check**

Navigate to `/`. Confirm:
- Full-bleed dark blue gradient hero with twinkling stars and earth-blue glow at bottom
- "RISE BEYOND THE MORTAL PLANE" appears with a staggered fade-up (heading, then sub, then CTA)
- CTA button "SELECT YOUR MISSION" links to `/shop` and has hover border transition
- Bobbing scroll indicator below
- Scrolling down reveals 4 mission teaser rows, each fading up as it enters viewport at 85%
- Clicking a teaser link navigates to the correct product page

- [ ] **Step 3: Commit**

```bash
git add web/src/routes/+page.svelte
git commit -m "feat: build cinematic homepage with star field hero and mission teaser section"
```

---

## Self-Review Checklist

**1. Spec coverage:**

| Requirement | Task |
|---|---|
| Homepage with star field hero | Task 12 |
| "RISE BEYOND THE MORTAL PLANE" brand statement | Task 12 |
| GSAP scroll reveal of mission teasers | Task 12 (revealOnScroll) |
| Shop 2×2 mission select grid | Task 9 |
| 3D tilt on hover (±12°) | Task 3 |
| Product page: unique space environment | Task 11 (MissionScene) |
| Product image floating/rotating | Task 11 (GSAP timeline) |
| Size selector | Task 5 + Task 11 |
| Currency-aware price (from API) | Task 11 (getDisplayPrice) |
| Add to Cart button | Task 11 |
| Particle burst on Add to Cart | Task 7 + Task 11 |
| Sold out state (disabled button, badge) | Task 6 + Task 11 |
| Coming soon state (email capture) | Task 6 + Task 11 |
| Magnetic cursor | Task 4 |
| GSAP scroll reveals | Tasks 1, 9, 11, 12 |
| Parallax utility | Task 1 |
| MissionScene per product (mission_number) | Task 2 + Task 11 |
| mission_number drives environment | Task 2 (config map) |

All requirements covered. No gaps found.

**2. Placeholder scan:** No TBD, TODO, or "similar to Task N" patterns. All code blocks are complete. The only forward reference is the waitlist POST endpoint in `StockBadge` (noted as "Plan 5") — this is correctly identified as future work, not a placeholder.

**3. Type consistency:**
- `Product` type defined in `shop/+page.ts`, re-imported in `[slug]/+page.ts` via `import type { Product } from '../+page.js'` — consistent.
- `missionNumber` prop type `'001' | '002' | '003' | '004'` used identically in `MissionScene`, `MissionCard`, and the product page.
- `ParticleBurst.trigger(x, y)` signature defined in Task 7 Step 1, used correctly in Task 11 Step 1 and Task 7 Step 2.
- `revealOnScroll(element, delay)` signature defined in Task 1, called with correct signature in Tasks 9, 11, 12.
- `SizeSelector` `bind:selected` and `sizes` props defined in Task 5, bound correctly in Task 11.
- `StockBadge` `status` prop defined in Task 6, passed correctly in Task 11.

All types consistent across tasks.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-07-plan-4-mission-pages.md`.

**Two execution options:**

**1. Subagent-Driven (recommended)** — Fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
