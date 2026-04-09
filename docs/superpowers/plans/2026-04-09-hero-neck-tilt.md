# Hero Neck-Tilt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the HeroScene into a first-person neck-tilt world where mouse Y rotates the camera from ground to sky, revealing "THE MORTAL PLANE" at the horizon and "RISE BEYOND" + the CTA button in the Milky Way at full tilt.

**Architecture:** All text overlays ("THE MORTAL PLANE", "RISE BEYOND", button) move inside `HeroScene.svelte` and are controlled directly from the `draw()` rAF loop via `element.style` — no Svelte reactivity, no callbacks. `+page.svelte` is stripped down to the scroll indicator and teasers section.

**Tech Stack:** SvelteKit · Canvas 2D · GSAP (entry fade only) · CSS mix-blend-mode

**Dev server:** `cd web && npm run dev` → http://localhost:5173

---

## File Map

| File | Action | What changes |
|------|--------|-------------|
| `web/src/lib/components/HeroScene.svelte` | Modify | horizonY formula, text overlays, MW opacity curve |
| `web/src/routes/+page.svelte` | Modify | Remove heading, sub-copy, eyebrow, old CTA logic |

---

### Task 1: Extend horizonY so the ground can fully exit the screen

**Files:**
- Modify: `web/src/lib/components/HeroScene.svelte`

- [ ] **Step 1: Read the current draw() function**

Open `web/src/lib/components/HeroScene.svelte`. Find the `draw()` function. Locate this line:

```ts
const horizonY = h * (0.55 + camY * 0.34);
```

- [ ] **Step 2: Replace the horizonY formula**

Replace that single line with:

```ts
const horizonY = h * (0.50 + camY * 0.52);
```

This gives:
- `camY = -1` → `horizonY = -2%` (nearly all ground)
- `camY = 0` → `horizonY = 50%` (horizon at midpoint — floating neutral)
- `camY = +1` → `horizonY = 102%` (horizon off-screen — pure sky)

- [ ] **Step 3: Verify visually**

Open http://localhost:5173. Move mouse to the very top of the screen. The ground and horizon line should completely disappear — only sky and stars visible. Move mouse to center — horizon should sit at the vertical midpoint. Move mouse to bottom — almost entirely ground.

- [ ] **Step 4: Commit**

```bash
cd "C:\Users\EricG\Desktop\immortalvibes"
git add web/src/lib/components/HeroScene.svelte
git commit -m "feat: extend horizonY range so ground exits screen at full tilt"
```

---

### Task 2: Add "THE MORTAL PLANE" text anchored to the horizon

**Files:**
- Modify: `web/src/lib/components/HeroScene.svelte`

- [ ] **Step 1: Add the element binding variable**

In the `<script lang="ts">` block, find the line:

```ts
let mwPhotoEl: HTMLElement;
```

Add below it:

```ts
let mortalEl: HTMLElement;
```

- [ ] **Step 2: Drive opacity and position from draw()**

In `draw()`, find the MW photo block:

```ts
// MW photo: only visible when looking up — purely camY driven
if (mwPhotoEl) {
```

Directly above that block, add:

```ts
// "THE MORTAL PLANE" — anchored just above the horizon, fades early in tilt
if (mortalEl) {
  mortalEl.style.top = `${horizonY - 28}px`;
  mortalEl.style.opacity = String(Math.max(0, 1 - camY * 2.8));
}
```

- [ ] **Step 3: Add the HTML element to the template**

In the template section, find the `<div bind:this={mwPhotoEl} ...>` element. Add before it:

```svelte
<div
  bind:this={mortalEl}
  aria-hidden="true"
  class="text-mortal"
>
  THE MORTAL PLANE
</div>
```

- [ ] **Step 4: Add CSS**

In the `<style>` block, add:

```css
.text-mortal {
  position: fixed;
  left: 50%;
  transform: translateX(-50%);
  font-family: 'Cormorant Garamond', serif;
  font-size: 0.75rem;
  font-weight: 300;
  letter-spacing: 0.4em;
  color: rgba(240, 237, 230, 0.55);
  white-space: nowrap;
  pointer-events: none;
  z-index: 5;
  text-shadow: 0 0 20px rgba(0, 0, 0, 0.9);
}
```

- [ ] **Step 5: Verify visually**

Open http://localhost:5173. With mouse at center, "THE MORTAL PLANE" should appear just above the horizon line. As you move the mouse upward, it should fade out before the horizon reaches the bottom. Moving mouse back down brings it back.

- [ ] **Step 6: Commit**

```bash
cd "C:\Users\EricG\Desktop\immortalvibes"
git add web/src/lib/components/HeroScene.svelte
git commit -m "feat: add THE MORTAL PLANE text anchored to horizon"
```

---

### Task 3: Add "RISE BEYOND" text and CTA button at screen center

**Files:**
- Modify: `web/src/lib/components/HeroScene.svelte`

- [ ] **Step 1: Add element binding variables**

In `<script lang="ts">`, below `let mortalEl: HTMLElement;`, add:

```ts
let riseEl: HTMLElement;
let ctaEl: HTMLAnchorElement;
```

- [ ] **Step 2: Drive opacity from draw()**

In `draw()`, directly after the `mortalEl` block you added in Task 2, add:

```ts
// "RISE BEYOND" — reveals at deep tilt
if (riseEl) {
  riseEl.style.opacity = String(Math.max(0, (camY - 0.55) * 4));
}

// CTA button — appears after "RISE BEYOND" reads
if (ctaEl) {
  const ctaOpacity = Math.max(0, (camY - 0.65) * 5);
  ctaEl.style.opacity = String(ctaOpacity);
  ctaEl.style.pointerEvents = ctaOpacity < 0.1 ? 'none' : 'all';
}
```

- [ ] **Step 3: Add HTML elements to the template**

In the template, after the `.text-mortal` div, add:

```svelte
<div
  bind:this={riseEl}
  aria-hidden="true"
  class="text-rise"
>
  RISE BEYOND
</div>

<a
  bind:this={ctaEl}
  href="/shop"
  class="text-cta"
>
  ENTER THE MISSIONS
</a>
```

- [ ] **Step 4: Add CSS**

In `<style>`, add:

```css
.text-rise {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  font-family: 'Cormorant Garamond', serif;
  font-size: 1.8rem;
  font-weight: 300;
  letter-spacing: 0.4em;
  color: rgba(240, 237, 230, 0.90);
  white-space: nowrap;
  pointer-events: none;
  z-index: 5;
  opacity: 0;
  text-shadow: 0 0 40px rgba(240, 237, 230, 0.2);
}

.text-cta {
  position: fixed;
  top: calc(50% + 3.25rem);
  left: 50%;
  transform: translateX(-50%);
  z-index: 5;
  display: inline-block;
  border: 1px solid rgba(240, 237, 230, 0.3);
  border-bottom-color: rgba(200, 146, 42, 0.5);
  color: rgba(240, 237, 230, 0.9);
  font-family: 'Inter', sans-serif;
  font-size: 0.65rem;
  letter-spacing: 0.25em;
  padding: 1rem 2.5rem;
  text-decoration: none;
  background: rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(8px);
  box-shadow: 0 0 30px rgba(240, 237, 230, 0.08), 0 0 60px rgba(200, 146, 42, 0.06);
  animation: ctaPulse 2.8s ease-in-out infinite;
  opacity: 0;
  pointer-events: none;
  white-space: nowrap;
}

.text-cta:hover {
  border-color: rgba(240, 237, 230, 0.8);
  border-bottom-color: rgba(200, 146, 42, 1);
  color: #F0EDE6;
  box-shadow: 0 0 50px rgba(240, 237, 230, 0.18), 0 0 100px rgba(200, 146, 42, 0.14);
}

@keyframes ctaPulse {
  0%, 100% { border-bottom-color: rgba(200, 146, 42, 0.15); }
  50%       { border-bottom-color: rgba(200, 146, 42, 0.65); }
}
```

- [ ] **Step 5: Verify visually**

Open http://localhost:5173. Move mouse to the top of the screen. "RISE BEYOND" should fade in at screen center, followed shortly by the "ENTER THE MISSIONS" button below it. Both should be invisible at neutral (mouse center) and while looking at the horizon. Click the button — it should navigate to `/shop`.

- [ ] **Step 6: Commit**

```bash
cd "C:\Users\EricG\Desktop\immortalvibes"
git add web/src/lib/components/HeroScene.svelte
git commit -m "feat: add RISE BEYOND text and CTA button revealed at full tilt"
```

---

### Task 4: Fix Milky Way opacity curve — base leak + camY scaling

**Files:**
- Modify: `web/src/lib/components/HeroScene.svelte`

- [ ] **Step 1: Replace the MW opacity calculation in draw()**

Find this block in `draw()`:

```ts
// MW photo: only visible when looking up — purely camY driven
if (mwPhotoEl) {
  const lookUp = Math.max(0, camY - 0.05); // small deadzone before it appears
  mwPhotoEl.style.opacity = String(Math.min(0.88, lookUp * 2.0));
}
```

Replace with:

```ts
// MW photo: faint base "leak" always visible, swells to full at tilt
if (mwPhotoEl) {
  const mwOpacity = Math.min(0.85, 0.04 + Math.max(0, camY - 0.2) * 1.02);
  mwPhotoEl.style.opacity = String(mwOpacity);
}
```

Result:
- `camY = 0` → opacity 0.04 (barely visible shimmer at top — the "leak")
- `camY = 0.2` → opacity 0.04 (threshold, starts growing)
- `camY = 0.6` → opacity ~0.45 (clearly visible)
- `camY = 1.0` → opacity 0.85 (Milky Way dominates)

- [ ] **Step 2: Verify the bottom mask is present in CSS**

In `<style>`, confirm the `.mw-photo` rule contains:

```css
mask-image: linear-gradient(to bottom, black 30%, transparent 72%);
-webkit-mask-image: linear-gradient(to bottom, black 30%, transparent 72%);
```

If either line is missing, add it to `.mw-photo`.

- [ ] **Step 3: Verify the translateY direction**

In `draw()`, confirm this line reads:

```ts
milkyWayOffsetY = -camY * h * 0.10;
```

The negative sign is critical — it moves the photo upward as you tilt back. If it reads `camY * h * 0.10` (positive), fix it.

- [ ] **Step 4: Verify visually**

Open http://localhost:5173. At neutral (mouse center), there should be a faint cool shimmer at the very top of the screen — barely perceptible. As you move the mouse up, the Milky Way should swell in and shift upward. At full tilt it should fill the sky behind "RISE BEYOND" and the button.

- [ ] **Step 5: Commit**

```bash
cd "C:\Users\EricG\Desktop\immortalvibes"
git add web/src/lib/components/HeroScene.svelte
git commit -m "feat: MW base opacity leak + camY swell curve + upward parallax"
```

---

### Task 5: Clean up +page.svelte

**Files:**
- Modify: `web/src/routes/+page.svelte`

The heading, sub-copy, eyebrow, and CTA have all moved into `HeroScene.svelte`. Strip `+page.svelte` down to the scroll indicator, teasers, and the GSAP plugin registration (still used by `revealOnScroll`).

- [ ] **Step 1: Rewrite the script block**

Replace the entire `<script lang="ts">` block with:

```ts
<script lang="ts">
  import { onMount } from 'svelte';
  import { gsap } from 'gsap';
  import { ScrollTrigger } from 'gsap/ScrollTrigger';
  import { revealOnScroll } from '$lib/animations/reveal';
  import HeroScene from '$lib/components/HeroScene.svelte';

  gsap.registerPlugin(ScrollTrigger);

  let teaserSection: HTMLElement;

  onMount(() => {
    if (teaserSection) {
      const items = teaserSection.querySelectorAll<HTMLElement>('.teaser-item');
      items.forEach((el, i) => revealOnScroll(el, i * 0.12));
    }
  });

  const missions = [
    { number: '001', label: 'Low Earth Orbit', product: 'Warped Reality Beanie', slug: 'warped-reality-beanie', image: '/photos/blue-beanie.jpeg' },
    { number: '002', label: 'Lunar Surface',   product: 'Vanguard Trucker Hat',  slug: 'vanguard-trucker-hat', image: null },
    { number: '003', label: 'Stellar Nursery', product: 'Racerback Tanktop',     slug: 'racerback-tanktop',    image: '/photos/tank-front.png' },
    { number: '004', label: 'Deep Space',      product: 'Next Drop',             slug: null,                   image: null },
  ] as const;
</script>
```

- [ ] **Step 2: Rewrite the template**

Replace everything between `<svelte:head>` and the `<style>` block with:

```svelte
<svelte:head>
  <title>Immortal Vibes — Rise Beyond the Mortal Plane</title>
  <meta name="description" content="Garments built for those who orbit higher. Limited drops, infinite purpose." />
</svelte:head>

<HeroScene />

<!-- Scroll indicator — anchored to bottom of viewport during hero -->
<section class="hero-spacer">
  <div class="scroll-indicator" aria-hidden="true">
    <span class="scroll-line"></span>
    <span class="scroll-label">SCROLL</span>
  </div>
</section>

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
```

- [ ] **Step 3: Rewrite the style block**

Replace the entire `<style>` block with:

```svelte
<style>
  .hero-spacer {
    position: relative;
    z-index: 10;
    min-height: 100vh;
    pointer-events: none;
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
    background: linear-gradient(to bottom, transparent, rgba(240, 237, 230, 0.3));
  }

  .scroll-label {
    font-family: 'Inter', sans-serif;
    font-size: 0.55rem;
    letter-spacing: 0.25em;
    color: rgba(240, 237, 230, 0.25);
  }

  @keyframes scrollBob {
    0%, 100% { transform: translateX(-50%) translateY(0); }
    50%       { transform: translateX(-50%) translateY(6px); }
  }

  /* ── Teasers ── */
  .teasers {
    position: relative;
    z-index: 10;
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

  .teaser-body { flex: 1; }

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

  .teaser-link:hover { color: #F0EDE6; }

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

- [ ] **Step 4: Verify visually**

Open http://localhost:5173. The page should show the HeroScene canvas, scroll indicator at the bottom of the viewport, and the teasers section when scrolled. No heading, no sub-copy, no eyebrow visible in the page layer.

- [ ] **Step 5: Commit**

```bash
cd "C:\Users\EricG\Desktop\immortalvibes"
git add web/src/routes/+page.svelte
git commit -m "refactor: strip +page.svelte — heading and CTA live in HeroScene"
```

---

## Success Criteria Checklist

Run through these after all tasks complete:

- [ ] Mouse at center: horizon at ~50% of viewport, "THE MORTAL PLANE" readable just above it, faint MW shimmer at top edge
- [ ] Mouse moving up: "THE MORTAL PLANE" fades, horizon drops, MW grows
- [ ] Mouse at top: pure sky/stars, no ground, "RISE BEYOND" fully visible, button clickable, MW at ~85% opacity
- [ ] Button navigates to `/shop`
- [ ] Mouse leaves window: world returns to neutral (camY → 0, MW → 0.04, "RISE BEYOND" → hidden)
- [ ] Teasers section still renders correctly below the fold
- [ ] No console errors
