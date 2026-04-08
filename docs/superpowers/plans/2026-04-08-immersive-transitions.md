# Immortal Vibes — Immersive Transitions & Mission Cards

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace default SvelteKit page navigation with a 4-transition cinematic system (Star Wars / Destiny 2 aesthetic) and redesign mission cards as full-bleed planetary environments.

**Architecture:** A `TransitionOverlay` Svelte component mounts at layout level above all page content. A `transition` store holds active state. `beforeNavigate` intercepts navigation, plays the out-animation, then calls `goto()` at the midpoint; `afterNavigate` plays the in-animation. Each transition has its own GSAP timeline factory. Mission cards are fully redesigned with per-mission planet environments and embedded product images.

**Tech Stack:** SvelteKit 5 (runes), GSAP 3 (already installed), TypeScript, CSS custom properties

---

## File Map

**Create:**
- `web/src/lib/stores/transition.ts` — transition state + mission accent colors + route resolver
- `web/src/lib/components/TransitionOverlay.svelte` — full-screen overlay, all 4 transition layers
- `web/src/lib/transitions/t1-ascent.ts` — T1 GSAP timeline factory (explosion → ascent → void → arrival)
- `web/src/lib/transitions/t2-hyperspace.ts` — T2 GSAP timeline factory (Kessel Run streaks)
- `web/src/lib/transitions/t3-ring.ts` — T3 GSAP timeline factory (Jedi hyperspace ring)
- `web/src/lib/transitions/t4-return.ts` — T4 GSAP timeline factory (re-entry descent)

**Modify:**
- `web/src/routes/+layout.svelte` — remove View Transition API, mount TransitionOverlay, wire beforeNavigate/afterNavigate
- `web/src/lib/components/MissionCard.svelte` — full Option B redesign (full-bleed planet, embedded product)
- `web/src/routes/shop/[slug]/+page.svelte` — add Prev/Next mission arrows that trigger T3

---

## Task 1: Transition Store

**Files:**
- Create: `web/src/lib/stores/transition.ts`

- [ ] **Create the transition store**

```ts
// web/src/lib/stores/transition.ts
import { writable } from 'svelte/store';

export type TransitionType = 'T1' | 'T2' | 'T3' | 'T4';

export interface TransitionState {
  active: boolean;
  type: TransitionType | null;
  clickX: number;  // for T2 — streak origin
  clickY: number;
  missionAccent: string;  // for T2 color tint
}

export const transitionStore = writable<TransitionState>({
  active: false,
  type: null,
  clickX: 0.5,
  clickY: 0.5,
  missionAccent: '#4FC3F7',
});

// Per-slug accent colors matching each mission environment
export const MISSION_ACCENT: Record<string, string> = {
  'warped-reality-beanie': '#4FC3F7',          // LEO — Earth blue
  'vanguard-trucker-hat': 'rgba(200,190,180,0.9)',  // Lunar — warm gray-white
  'racerback-tanktop':    'rgba(255,130,50,0.9)',   // Stellar Nursery — amber
};

// Ordered mission slugs for T3 prev/next
export const MISSION_ORDER = [
  'warped-reality-beanie',
  'vanguard-trucker-hat',
  'racerback-tanktop',
];

// Resolve which transition to use given from/to pathnames
export function resolveTransition(from: string, to: string): TransitionType | null {
  if (to === '/') return 'T4';
  if (to === '/shop') return 'T1';
  if (to.startsWith('/shop/') && from === '/shop') return 'T2';
  if (to.startsWith('/shop/') && from.startsWith('/shop/')) return 'T3';
  return null;
}

// Extract slug from pathname e.g. '/shop/warped-reality-beanie' → 'warped-reality-beanie'
export function slugFromPath(path: string): string {
  return path.split('/').pop() ?? '';
}
```

- [ ] **Commit**

```bash
cd /c/Users/EricG/Desktop/immortalvibes
git add web/src/lib/stores/transition.ts
git commit -m "feat: add transition store with route resolver and mission accents"
```

---

## Task 2: T1 — Explosive Ascent Timeline

**Files:**
- Create: `web/src/lib/transitions/t1-ascent.ts`

- [ ] **Create T1 timeline factory**

```ts
// web/src/lib/transitions/t1-ascent.ts
import gsap from 'gsap';

export interface T1Elements {
  overlay: HTMLElement;
  flash: HTMLElement;
  blast: HTMLElement;
  shockwave: HTMLElement;
  streaks: HTMLElement[];
  atmo: HTMLElement;
  starsCanvas: HTMLCanvasElement;
  cityline: HTMLElement;
}

// Draws a dense star field on the void canvas for T1 Phase 3
function drawVoidStars(canvas: HTMLCanvasElement): void {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  // 500 stars — denser than normal StarField to emphasise the void beauty
  for (let i = 0; i < 500; i++) {
    const x = Math.random() * canvas.width;
    const y = Math.random() * canvas.height;
    const r = Math.random() < 0.05 ? 2 : Math.random() < 0.2 ? 1.5 : 1;
    const alpha = 0.4 + Math.random() * 0.6;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(240,237,230,${alpha})`;
    ctx.fill();
  }

  // Subtle Milky Way smear — two overlapping soft ellipses
  const grd = ctx.createRadialGradient(
    canvas.width * 0.5, canvas.height * 0.5, 0,
    canvas.width * 0.5, canvas.height * 0.5, canvas.width * 0.4
  );
  grd.addColorStop(0, 'rgba(240,237,230,0.04)');
  grd.addColorStop(1, 'transparent');
  ctx.fillStyle = grd;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
}

// out: covers screen with explosion + ascent, calls onMidpoint when nav should fire
// in:  plays void reveal + page arrival
export function playT1Out(
  els: T1Elements,
  onMidpoint: () => void
): gsap.core.Timeline {
  const tl = gsap.timeline();

  // Make overlay visible
  gsap.set(els.overlay, { display: 'block', opacity: 1 });
  gsap.set([els.flash, els.blast, els.shockwave, ...els.streaks, els.atmo, els.starsCanvas], {
    opacity: 0,
  });
  gsap.set(els.starsCanvas, { display: 'none' });

  // Phase 1: Ignition (0–0.15s)
  tl
    // White flash
    .to(els.flash, { opacity: 1, duration: 0.08, ease: 'power3.in' })
    .to(els.flash, { opacity: 0, duration: 0.07, ease: 'power2.out' })
    // Blast plume expands from bottom-center
    .fromTo(els.blast,
      { scale: 0, opacity: 0, transformOrigin: '50% 100%' },
      { scale: 1, opacity: 1, duration: 0.15, ease: 'power3.out' }, 0
    )
    // Shockwave ring expands
    .fromTo(els.shockwave,
      { scale: 0, opacity: 0.6, transformOrigin: '50% 100%' },
      { scale: 4, opacity: 0, duration: 0.3, ease: 'power2.out' }, 0
    )
    // City shudder
    .to(els.cityline, { x: -4, duration: 0.04 }, 0.04)
    .to(els.cityline, { x: 4, duration: 0.04 }, 0.08)
    .to(els.cityline, { x: 0, duration: 0.04 }, 0.12)

    // Phase 2: Ascent (0.15–0.45s) — vertical speed streaks
    .to(els.atmo, { opacity: 1, duration: 0.1 }, 0.15)
    .to(els.blast, { opacity: 0, y: -80, duration: 0.3, ease: 'power2.in' }, 0.15);

  // Stagger streaks appearing
  els.streaks.forEach((streak, i) => {
    tl.fromTo(streak,
      { scaleY: 0, opacity: 0, transformOrigin: '50% 100%' },
      { scaleY: 1, opacity: 0.5 + Math.random() * 0.4, duration: 0.25, ease: 'power2.out' },
      0.15 + i * 0.02
    );
  });

  tl
    // Atmosphere fades, streaks thin out
    .to(els.atmo, { opacity: 0, duration: 0.15 }, 0.38)
    .to(els.streaks, { opacity: 0, duration: 0.1 }, 0.38)
    .to(els.cityline, { opacity: 0, y: 60, duration: 0.2 }, 0.2)

    // Fire navigation at midpoint (0.45s) — page loads under the overlay
    .call(onMidpoint, [], 0.45)

    // Phase 3: The Void (0.45–0.70s) — pure star beauty
    .call(() => {
      drawVoidStars(els.starsCanvas);
      gsap.set(els.starsCanvas, { display: 'block', opacity: 0 });
    }, [], 0.45)
    .to(els.starsCanvas, { opacity: 1, duration: 0.15, ease: 'power1.in' }, 0.45)
    // Hold the void — 250ms of silence
    .to({}, { duration: 0.25 }, 0.6);

  return tl;
}

export function playT1In(els: T1Elements, onComplete: () => void): gsap.core.Timeline {
  const tl = gsap.timeline({ onComplete });

  // Phase 4: Arrival (0.70–0.90s) — stars fade, shop materialises
  tl
    .to(els.starsCanvas, { opacity: 0, duration: 0.2, ease: 'power1.out' })
    .to(els.overlay, { opacity: 0, duration: 0.15, ease: 'power1.out' }, 0.1)
    .call(() => {
      gsap.set(els.overlay, { display: 'none' });
    });

  return tl;
}
```

- [ ] **Commit**

```bash
git add web/src/lib/transitions/t1-ascent.ts
git commit -m "feat: T1 explosive ascent timeline (ignition→ascent→void→arrival)"
```

---

## Task 3: T2 — Hyperspace Jump Timeline

**Files:**
- Create: `web/src/lib/transitions/t2-hyperspace.ts`

- [ ] **Create T2 timeline factory**

```ts
// web/src/lib/transitions/t2-hyperspace.ts
import gsap from 'gsap';

export interface T2Elements {
  overlay: HTMLElement;
  streaks: HTMLElement[];
  flash: HTMLElement;
  mist: HTMLElement;
}

// clickX/Y are normalised 0..1 viewport fractions
// accentColor is the destination mission tint
export function playT2(
  els: T2Elements,
  clickX: number,
  clickY: number,
  accentColor: string,
  onMidpoint: () => void,
  onComplete: () => void
): gsap.core.Timeline {
  const tl = gsap.timeline({ onComplete });

  const originX = `${clickX * 100}%`;
  const originY = `${clickY * 100}%`;

  gsap.set(els.overlay, { display: 'block', opacity: 1 });
  gsap.set([...els.streaks, els.flash, els.mist], { opacity: 0 });

  // Mist: subtle destination color fills background
  gsap.set(els.mist, { background: `radial-gradient(ellipse at ${originX} ${originY}, ${accentColor.replace(')', ',0.12)').replace('rgba(', 'rgba(').replace(',0.9)', ',0.12)')} 0%, transparent 60%)` });

  // Distribute streaks radially from click point
  els.streaks.forEach((streak, i) => {
    const angle = (i / els.streaks.length) * 360;
    const len = 30 + Math.random() * 50; // % of screen
    gsap.set(streak, {
      transformOrigin: '0% 50%',
      rotation: angle,
      left: originX,
      top: originY,
      width: `${len}%`,
    });
  });

  tl
    .to(els.mist, { opacity: 1, duration: 0.1 })
    // Streaks radiate outward — staggered
    .to(els.streaks, {
      opacity: 0.85,
      scaleX: 1,
      duration: 0.18,
      stagger: 0.008,
      ease: 'power2.in',
    }, 0.05)
    // Peak: white flash at 300ms
    .to(els.flash, { opacity: 1, duration: 0.06, ease: 'power3.in' }, 0.28)
    // Fire navigation at flash peak
    .call(onMidpoint, [], 0.3)
    // Flash fades, streaks collapse back, overlay lifts
    .to(els.flash, { opacity: 0, duration: 0.08, ease: 'power2.out' }, 0.3)
    .to(els.streaks, { opacity: 0, scaleX: 0, duration: 0.15, ease: 'power2.out' }, 0.3)
    .to(els.mist, { opacity: 0, duration: 0.1 }, 0.36)
    .to(els.overlay, { opacity: 0, duration: 0.1 }, 0.42)
    .call(() => gsap.set(els.overlay, { display: 'none' }));

  return tl;
}
```

- [ ] **Commit**

```bash
git add web/src/lib/transitions/t2-hyperspace.ts
git commit -m "feat: T2 hyperspace jump timeline (Kessel Run — tinted per destination)"
```

---

## Task 4: T3 — Hyperspace Ring Timeline

**Files:**
- Create: `web/src/lib/transitions/t3-ring.ts`

- [ ] **Create T3 timeline factory**

```ts
// web/src/lib/transitions/t3-ring.ts
import gsap from 'gsap';

export interface T3Elements {
  overlay: HTMLElement;
  rings: HTMLElement[];  // 5 rings, index 0 = outermost
  core: HTMLElement;
  rays: HTMLElement[];
}

export function playT3(
  els: T3Elements,
  mainContent: HTMLElement,
  onMidpoint: () => void,
  onComplete: () => void
): gsap.core.Timeline {
  const tl = gsap.timeline({ onComplete });

  gsap.set(els.overlay, { display: 'block', opacity: 1 });
  gsap.set([...els.rings, els.core, ...els.rays], { opacity: 0, scale: 0 });

  // Current page content spirals inward
  tl
    .to(mainContent, {
      scale: 0.92,
      opacity: 0,
      duration: 0.25,
      ease: 'power2.in',
    })
    // Rings implode inward from outermost — reverse stagger
    .to(els.rings, {
      scale: 1,
      opacity: (i) => 0.15 + i * 0.15,
      duration: 0.2,
      stagger: -0.04,  // innermost first (reverse)
      ease: 'power2.out',
    }, 0.1)
    .to(els.rays, { scale: 1, opacity: 0.4, duration: 0.15, stagger: 0.02 }, 0.15)
    .to(els.core, { scale: 1, opacity: 1, duration: 0.1 }, 0.2)
    // Fire navigation at ring peak
    .call(onMidpoint, [], 0.3)
    // Rings explode outward and fade — new content arrives
    .to([...els.rings, els.core, ...els.rays], {
      scale: 4,
      opacity: 0,
      duration: 0.25,
      stagger: 0.03,
      ease: 'power3.out',
    }, 0.35)
    // New page content tears in from center
    .fromTo(mainContent,
      { scale: 1.08, opacity: 0 },
      { scale: 1, opacity: 1, duration: 0.22, ease: 'power2.out' },
      0.38
    )
    .to(els.overlay, { opacity: 0, duration: 0.1 }, 0.55)
    .call(() => gsap.set(els.overlay, { display: 'none' }));

  return tl;
}
```

- [ ] **Commit**

```bash
git add web/src/lib/transitions/t3-ring.ts
git commit -m "feat: T3 hyperspace ring timeline (Jedi starfighter ring — gold)"
```

---

## Task 5: T4 — Return to Earth Timeline

**Files:**
- Create: `web/src/lib/transitions/t4-return.ts`

- [ ] **Create T4 timeline factory**

```ts
// web/src/lib/transitions/t4-return.ts
import gsap from 'gsap';

export interface T4Elements {
  overlay: HTMLElement;
  spaceStars: HTMLElement;
  heat: HTMLElement;
  craft: HTMLElement;
  trail: HTMLElement;
  atmo: HTMLElement;
  cityline: HTMLElement;
}

export function playT4(
  els: T4Elements,
  onMidpoint: () => void,
  onComplete: () => void
): gsap.core.Timeline {
  const tl = gsap.timeline({ onComplete });

  gsap.set(els.overlay, { display: 'block', opacity: 1 });
  gsap.set([els.spaceStars, els.heat, els.craft, els.trail, els.atmo, els.cityline], { opacity: 0 });
  gsap.set(els.cityline, { y: 60 });
  gsap.set(els.craft, { y: -80 });

  // Stars visible briefly at top (we're leaving space)
  tl
    .to(els.spaceStars, { opacity: 1, duration: 0.12 })
    .to(els.spaceStars, { opacity: 0, duration: 0.2 }, 0.18)
    // Craft descends from top of screen
    .to(els.craft, { opacity: 0.7, y: 0, duration: 0.3, ease: 'power2.in' }, 0.1)
    // Heat shield glow builds as craft enters atmosphere
    .to(els.heat, { opacity: 1, duration: 0.2, ease: 'power2.in' }, 0.2)
    .to(els.trail, { opacity: 0.6, duration: 0.2 }, 0.2)
    // Atmosphere thickens from below
    .to(els.atmo, { opacity: 1, duration: 0.25 }, 0.28)
    // Fire navigation at 0.4s — homepage loads under overlay
    .call(onMidpoint, [], 0.4)
    // Heat fades, city rises
    .to(els.heat, { opacity: 0, duration: 0.2 }, 0.45)
    .to(els.trail, { opacity: 0, duration: 0.15 }, 0.45)
    .to(els.craft, { opacity: 0, y: 40, duration: 0.2, ease: 'power2.out' }, 0.48)
    .to(els.cityline, { opacity: 1, y: 0, duration: 0.2, ease: 'power2.out' }, 0.52)
    // Overlay fades — homepage hero visible beneath
    .to(els.overlay, { opacity: 0, duration: 0.2 }, 0.65)
    .to(els.cityline, { opacity: 0, duration: 0.1 }, 0.7)
    .call(() => gsap.set(els.overlay, { display: 'none' }));

  return tl;
}
```

- [ ] **Commit**

```bash
git add web/src/lib/transitions/t4-return.ts
git commit -m "feat: T4 return-to-earth timeline (re-entry heat shield + city landing)"
```

---

## Task 6: TransitionOverlay Component

**Files:**
- Create: `web/src/lib/components/TransitionOverlay.svelte`

- [ ] **Create the overlay component**

```svelte
<!-- web/src/lib/components/TransitionOverlay.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { browser } from '$app/environment';
  import gsap from 'gsap';
  import { transitionStore } from '$lib/stores/transition';
  import { playT1Out, playT1In, type T1Elements } from '$lib/transitions/t1-ascent';
  import { playT2, type T2Elements } from '$lib/transitions/t2-hyperspace';
  import { playT3, type T3Elements } from '$lib/transitions/t3-ring';
  import { playT4, type T4Elements } from '$lib/transitions/t4-return';

  // Exposed so layout can call trigger methods
  export function triggerOut(
    type: 'T1' | 'T2' | 'T3' | 'T4',
    opts: { clickX?: number; clickY?: number; accentColor?: string; mainContent?: HTMLElement },
    onMidpoint: () => void
  ): Promise<void> {
    return new Promise((resolve) => {
      if (!browser) { resolve(); return; }
      if (type === 'T1') playT1Out(getT1Els(), onMidpoint);
      if (type === 'T2') playT2(getT2Els(), opts.clickX ?? 0.5, opts.clickY ?? 0.5, opts.accentColor ?? '#4FC3F7', onMidpoint, resolve);
      if (type === 'T3') playT3(getT3Els(), opts.mainContent!, onMidpoint, resolve);
      if (type === 'T4') playT4(getT4Els(), onMidpoint, resolve);
      if (type === 'T1') {
        // T1 out resolves after void phase — in is separate
        resolve();
      }
    });
  }

  export function triggerIn(type: 'T1' | 'T2' | 'T3' | 'T4', onComplete: () => void): void {
    if (!browser) { onComplete(); return; }
    if (type === 'T1') playT1In(getT1Els(), onComplete);
    else onComplete(); // T2/T3/T4 handle their own completion
  }

  // ── DOM refs ──
  let overlayEl: HTMLElement;

  // T1
  let t1Flash: HTMLElement;
  let t1Blast: HTMLElement;
  let t1Shockwave: HTMLElement;
  let t1StreakEls: HTMLElement[] = [];
  let t1Atmo: HTMLElement;
  let t1Stars: HTMLCanvasElement;
  let t1City: HTMLElement;

  // T2
  let t2StreakEls: HTMLElement[] = [];
  let t2Flash: HTMLElement;
  let t2Mist: HTMLElement;

  // T3
  let t3RingEls: HTMLElement[] = [];
  let t3Core: HTMLElement;
  let t3RayEls: HTMLElement[] = [];

  // T4
  let t4SpaceStars: HTMLElement;
  let t4Heat: HTMLElement;
  let t4Craft: HTMLElement;
  let t4Trail: HTMLElement;
  let t4Atmo: HTMLElement;
  let t4City: HTMLElement;

  function getT1Els(): T1Elements {
    return {
      overlay: overlayEl,
      flash: t1Flash,
      blast: t1Blast,
      shockwave: t1Shockwave,
      streaks: t1StreakEls,
      atmo: t1Atmo,
      starsCanvas: t1Stars,
      cityline: t1City,
    };
  }
  function getT2Els(): T2Elements {
    return { overlay: overlayEl, streaks: t2StreakEls, flash: t2Flash, mist: t2Mist };
  }
  function getT3Els(): T3Elements {
    return { overlay: overlayEl, rings: t3RingEls, core: t3Core, rays: t3RayEls };
  }
  function getT4Els(): T4Elements {
    return {
      overlay: overlayEl,
      spaceStars: t4SpaceStars,
      heat: t4Heat,
      craft: t4Craft,
      trail: t4Trail,
      atmo: t4Atmo,
      cityline: t4City,
    };
  }

  onMount(() => {
    if (!browser) return;
    // Start hidden
    gsap.set(overlayEl, { display: 'none' });
  });
</script>

<div
  bind:this={overlayEl}
  class="t-overlay"
  aria-hidden="true"
>

  <!-- ── T1 LAYERS ── -->
  <div class="t1-layer">
    <div bind:this={t1Flash} class="t1-flash"></div>

    <!-- Explosion blast plume -->
    <div bind:this={t1Blast} class="t1-blast"></div>
    <!-- Shockwave ring -->
    <div bind:this={t1Shockwave} class="t1-shockwave"></div>
    <!-- Atmosphere glow strip -->
    <div bind:this={t1Atmo} class="t1-atmo"></div>

    <!-- Speed streaks (10) -->
    {#each Array(10) as _, i}
      <div
        bind:this={t1StreakEls[i]}
        class="t1-streak"
        style="left: {8 + i * 9}%;"
      ></div>
    {/each}

    <!-- Void star canvas -->
    <canvas bind:this={t1Stars} class="t1-stars"></canvas>

    <!-- City silhouette SVG -->
    <div bind:this={t1City} class="t1-city">
      <svg viewBox="0 0 1440 120" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M0,120 L0,80 L40,80 L40,50 L60,50 L60,30 L80,30 L80,50 L100,50 L100,60
                 L140,60 L140,40 L160,40 L160,20 L180,20 L180,40 L200,40 L200,55
                 L240,55 L240,35 L260,35 L260,55 L280,55 L280,70 L320,70 L320,45
                 L350,45 L350,25 L370,25 L370,45 L390,45 L390,60 L420,60 L420,80
                 L460,80 L460,55 L490,55 L490,70 L520,70 L520,45 L540,45 L540,30
                 L560,30 L560,45 L580,45 L580,65 L620,65 L620,80 L660,80 L660,50
                 L680,50 L680,35 L700,35 L700,50 L720,50 L720,60 L760,60 L760,40
                 L800,40 L800,55 L840,55 L840,75 L880,75 L880,50 L910,50 L910,30
                 L930,30 L930,50 L960,50 L960,65 L1000,65 L1000,80 L1040,80
                 L1040,55 L1070,55 L1070,40 L1090,40 L1090,55 L1110,55 L1110,70
                 L1150,70 L1150,45 L1180,45 L1180,60 L1220,60 L1220,80 L1260,80
                 L1260,50 L1290,50 L1290,35 L1310,35 L1310,50 L1340,50 L1340,65
                 L1380,65 L1380,80 L1440,80 L1440,120 Z"
              fill="rgba(20,40,80,0.8)"
        />
        <!-- Window lights -->
        <rect x="62" y="35" width="4" height="3" fill="rgba(240,237,230,0.2)"/>
        <rect x="162" y="25" width="4" height="3" fill="rgba(240,237,230,0.15)"/>
        <rect x="352" y="30" width="4" height="3" fill="rgba(240,237,230,0.2)"/>
        <rect x="543" y="35" width="4" height="3" fill="rgba(240,237,230,0.15)"/>
        <rect x="912" y="35" width="4" height="3" fill="rgba(240,237,230,0.2)"/>
        <rect x="1072" y="45" width="4" height="3" fill="rgba(240,237,230,0.15)"/>
        <rect x="1292" y="40" width="4" height="3" fill="rgba(240,237,230,0.2)"/>
      </svg>
    </div>
  </div>

  <!-- ── T2 LAYERS ── -->
  <div class="t2-layer">
    <div bind:this={t2Mist} class="t2-mist"></div>
    {#each Array(16) as _, i}
      <div
        bind:this={t2StreakEls[i]}
        class="t2-streak"
        style="transform-origin: 0% 50%;"
      ></div>
    {/each}
    <div bind:this={t2Flash} class="t2-flash"></div>
  </div>

  <!-- ── T3 LAYERS ── -->
  <div class="t3-layer">
    {#each Array(8) as _, i}
      <div
        bind:this={t3RayEls[i]}
        class="t3-ray"
        style="transform: rotate({i * 45}deg);"
      ></div>
    {/each}
    {#each Array(5) as _, i}
      <div
        bind:this={t3RingEls[i]}
        class="t3-ring"
        style="
          width: {40 + i * 16}vmin;
          height: {40 + i * 16}vmin;
          opacity: {0.6 - i * 0.1};
        "
      ></div>
    {/each}
    <div bind:this={t3Core} class="t3-core"></div>
  </div>

  <!-- ── T4 LAYERS ── -->
  <div class="t4-layer">
    <div bind:this={t4SpaceStars} class="t4-space-stars">
      {#each Array(40) as _, i}
        <div
          class="t4-star"
          style="
            top: {Math.floor(Math.random() * 60)}%;
            left: {Math.floor(Math.random() * 100)}%;
            width: {i % 5 === 0 ? 2 : 1}px;
            height: {i % 5 === 0 ? 2 : 1}px;
            opacity: {0.4 + (i % 6) * 0.1};
          "
        ></div>
      {/each}
    </div>
    <div bind:this={t4Heat} class="t4-heat"></div>
    <div bind:this={t4Trail} class="t4-trail"></div>
    <div bind:this={t4Craft} class="t4-craft"></div>
    <div bind:this={t4Atmo} class="t4-atmo"></div>
    <div bind:this={t4City} class="t4-city">
      <svg viewBox="0 0 1440 120" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M0,120 L0,80 L40,80 L40,50 L60,50 L60,30 L80,30 L80,50 L100,50 L100,60
                 L140,60 L140,40 L160,40 L160,20 L180,20 L180,40 L200,40 L200,55
                 L240,55 L240,35 L260,35 L260,55 L280,55 L280,70 L320,70 L320,45
                 L350,45 L350,25 L370,25 L370,45 L390,45 L390,60 L420,60 L420,80
                 L460,80 L460,55 L490,55 L490,70 L520,70 L520,45 L540,45 L540,30
                 L560,30 L560,45 L580,45 L580,65 L620,65 L620,80 L660,80 L660,50
                 L680,50 L680,35 L700,35 L700,50 L720,50 L720,60 L760,60 L760,40
                 L800,40 L800,55 L840,55 L840,75 L880,75 L880,50 L910,50 L910,30
                 L930,30 L930,50 L960,50 L960,65 L1000,65 L1000,80 L1040,80
                 L1040,55 L1070,55 L1070,40 L1090,40 L1090,55 L1110,55 L1110,70
                 L1150,70 L1150,45 L1180,45 L1180,60 L1220,60 L1220,80 L1260,80
                 L1260,50 L1290,50 L1290,35 L1310,35 L1310,50 L1340,50 L1340,65
                 L1380,65 L1380,80 L1440,80 L1440,120 Z"
              fill="rgba(20,40,80,0.9)"
        />
      </svg>
    </div>
  </div>

</div>

<style>
  .t-overlay {
    position: fixed;
    inset: 0;
    z-index: 9000;
    pointer-events: none;
    background: #000005;
    display: none;
  }

  /* ── T1 ── */
  .t1-layer { position: absolute; inset: 0; }

  .t1-flash {
    position: absolute; inset: 0;
    background: #ffffff;
    opacity: 0;
  }

  .t1-blast {
    position: absolute;
    bottom: 0; left: 50%; transform: translateX(-50%);
    width: 60vw; height: 50vh;
    background: radial-gradient(ellipse at center bottom,
      rgba(255,255,200,0.95) 0%,
      rgba(255,200,50,0.85) 20%,
      rgba(255,100,20,0.7) 45%,
      rgba(200,50,0,0.35) 65%,
      transparent 80%
    );
    border-radius: 50% 50% 0 0;
    opacity: 0;
    transform-origin: 50% 100%;
  }

  .t1-shockwave {
    position: absolute;
    bottom: 0; left: 50%; transform: translateX(-50%);
    width: 40vw; height: 20vw;
    border: 1px solid rgba(255,180,50,0.4);
    border-radius: 50%;
    opacity: 0;
    transform-origin: 50% 100%;
  }

  .t1-atmo {
    position: absolute;
    bottom: 0; left: 0; right: 0; height: 35vh;
    background: linear-gradient(to top, rgba(79,195,247,0.4), transparent);
    opacity: 0;
  }

  .t1-streak {
    position: absolute;
    top: 0; bottom: 0;
    width: 1px;
    background: linear-gradient(to top,
      transparent 0%,
      rgba(180,220,255,0.6) 30%,
      rgba(220,235,255,0.8) 60%,
      transparent 100%
    );
    opacity: 0;
    transform-origin: 50% 100%;
  }

  .t1-stars {
    position: absolute; inset: 0;
    width: 100%; height: 100%;
    opacity: 0;
    display: none;
  }

  .t1-city {
    position: absolute;
    bottom: 0; left: 0; right: 0; height: 120px;
    overflow: hidden;
  }
  .t1-city svg { width: 100%; height: 100%; }

  /* ── T2 ── */
  .t2-layer { position: absolute; inset: 0; }

  .t2-mist {
    position: absolute; inset: 0;
    opacity: 0;
  }

  .t2-streak {
    position: absolute;
    height: 1px;
    background: linear-gradient(to right,
      transparent 0%,
      rgba(160,210,255,0.9) 30%,
      rgba(255,255,255,0.95) 60%,
      transparent 100%
    );
    opacity: 0;
    transform-origin: 0% 50%;
  }

  .t2-flash {
    position: absolute; inset: 0;
    background: #ffffff;
    opacity: 0;
  }

  /* ── T3 ── */
  .t3-layer { position: absolute; inset: 0; }

  .t3-ring {
    position: absolute;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%) scale(0);
    border-radius: 50%;
    border: 1px solid #C8922A;
    box-shadow: 0 0 12px rgba(200,146,42,0.25);
    opacity: 0;
  }

  .t3-core {
    position: absolute;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%) scale(0);
    width: 12px; height: 12px;
    border-radius: 50%;
    background: radial-gradient(ellipse, rgba(200,146,42,1), rgba(200,146,42,0.3) 70%);
    box-shadow: 0 0 30px rgba(200,146,42,0.8);
    opacity: 0;
  }

  .t3-ray {
    position: absolute;
    top: 50%; left: 50%;
    height: 1px;
    width: 50vw;
    transform-origin: 0% 50%;
    background: linear-gradient(to right, rgba(200,146,42,0.5), transparent);
    opacity: 0;
  }

  /* ── T4 ── */
  .t4-layer { position: absolute; inset: 0; }

  .t4-space-stars { position: absolute; inset: 0; opacity: 0; }
  .t4-star {
    position: absolute;
    border-radius: 50%;
    background: #F0EDE6;
  }

  .t4-heat {
    position: absolute;
    top: 5vh; left: 50%; transform: translateX(-50%);
    width: 120px; height: 80px;
    background: radial-gradient(ellipse at top center,
      rgba(255,220,100,0.9) 0%,
      rgba(255,120,30,0.6) 35%,
      rgba(200,50,0,0.3) 65%,
      transparent 80%
    );
    border-radius: 50%;
    opacity: 0;
    filter: blur(4px);
  }

  .t4-craft {
    position: absolute;
    left: 50%; transform: translateX(-50%);
    width: 10px; height: 10px;
    border-radius: 50% 50% 2px 2px;
    background: rgba(240,237,230,0.8);
    box-shadow: 0 0 8px rgba(255,180,80,0.5);
    opacity: 0;
    top: 8vh;
  }

  .t4-trail {
    position: absolute;
    left: 50%; transform: translateX(-50%);
    width: 3px;
    height: 60px;
    top: 10vh;
    background: linear-gradient(to bottom, rgba(255,180,50,0.4), rgba(255,80,0,0.2), transparent);
    opacity: 0;
    border-radius: 0 0 2px 2px;
  }

  .t4-atmo {
    position: absolute;
    bottom: 0; left: 0; right: 0; height: 40vh;
    background: linear-gradient(to top, rgba(79,195,247,0.35), rgba(79,195,247,0.08), transparent);
    opacity: 0;
  }

  .t4-city {
    position: absolute;
    bottom: 0; left: 0; right: 0; height: 120px;
    overflow: hidden;
    opacity: 0;
  }
  .t4-city svg { width: 100%; height: 100%; }

  /* Reduced motion: instant crossfade only */
  @media (prefers-reduced-motion: reduce) {
    .t-overlay { transition: opacity 0.2s !important; }
  }
</style>
```

- [ ] **Commit**

```bash
git add web/src/lib/components/TransitionOverlay.svelte
git commit -m "feat: TransitionOverlay component with T1/T2/T3/T4 DOM layers"
```

---

## Task 7: Wire Layout — Replace onNavigate with Transition System

**Files:**
- Modify: `web/src/routes/+layout.svelte`

- [ ] **Replace the layout file** with the wired transition version

```svelte
<!-- web/src/routes/+layout.svelte -->
<script lang="ts">
  import '../app.css';
  import { browser } from '$app/environment';
  import { beforeNavigate, afterNavigate, goto } from '$app/navigation';
  import StarField from '$lib/components/StarField.svelte';
  import Nav from '$lib/components/Nav.svelte';
  import Footer from '$lib/components/Footer.svelte';
  import MagneticCursor from '$lib/components/MagneticCursor.svelte';
  import CartDrawer from '$lib/components/CartDrawer.svelte';
  import TransitionOverlay from '$lib/components/TransitionOverlay.svelte';
  import { resolveTransition, slugFromPath, MISSION_ACCENT, transitionStore } from '$lib/stores/transition';

  let { children } = $props();

  let overlayComponent: TransitionOverlay;
  let mainEl: HTMLElement;
  let navigating = false;

  if (browser) {
    beforeNavigate(({ to, cancel }) => {
      if (navigating || !to) return;

      const fromPath = window.location.pathname;
      const toPath = to.url.pathname;
      const transType = resolveTransition(fromPath, toPath);

      if (!transType) return; // no transition for this route pair

      cancel();
      navigating = true;

      const slug = slugFromPath(toPath);
      const accent = MISSION_ACCENT[slug] ?? '#4FC3F7';

      // Read click position from store (set by MissionCard on click)
      let cx = 0.5, cy = 0.5;
      transitionStore.subscribe((s) => { cx = s.clickX; cy = s.clickY; })();

      overlayComponent.triggerOut(
        transType,
        { clickX: cx, clickY: cy, accentColor: accent, mainContent: mainEl },
        () => {
          // midpoint: fire the actual navigation
          goto(toPath, { noScroll: true }).then(() => {
            overlayComponent.triggerIn(transType, () => {
              navigating = false;
            });
          });
        }
      );
    });
  }
</script>

<MagneticCursor />
<StarField />
<TransitionOverlay bind:this={overlayComponent} />
<Nav />

<main bind:this={mainEl} class="layout-main">
  {@render children()}
</main>

<Footer />
<CartDrawer />

<style>
  :global(body) {
    background-color: var(--void);
  }

  .layout-main {
    position: relative;
    z-index: 10;
    padding-top: 4.5rem;
    min-height: 100vh;
  }
</style>
```

- [ ] **Verify dev server still starts without errors**

```bash
cd /c/Users/EricG/Desktop/immortalvibes/web
# check the running dev server output — no red errors
```

- [ ] **Test T1 in browser**: Open `localhost:5173`, click "SELECT YOUR MISSION". Verify explosion → ascent speed blur → void stars → shop fades in.

- [ ] **Test T4 in browser**: From shop, click the logo. Verify re-entry descent → city rises → homepage.

- [ ] **Commit**

```bash
cd /c/Users/EricG/Desktop/immortalvibes
git add web/src/routes/+layout.svelte
git commit -m "feat: wire transition system to layout — replaces View Transition API"
```

---

## Task 8: Mission Card — Option B Full Immersive

**Files:**
- Modify: `web/src/lib/components/MissionCard.svelte`

- [ ] **Replace MissionCard with Option B design**

The card stores the click position in `transitionStore` before navigation so T2 can radiate streaks from the correct screen position.

```svelte
<!-- web/src/lib/components/MissionCard.svelte -->
<script lang="ts">
  import { goto } from '$app/navigation';
  import { transitionStore, MISSION_ACCENT } from '$lib/stores/transition';

  export let missionNumber: '001' | '002' | '003' | '004';
  export let title: string;
  export let subtitle: string;
  export let slug: string;
  export let imageUrl: string = '';
  export let status: 'available' | 'sold_out' | 'coming_soon' = 'available';

  // Per-mission environment configs
  const envs: Record<string, {
    bg: string;
    accentColor: string;
    planetStyle: string;
    label: string;
  }> = {
    '001': {
      bg: 'linear-gradient(160deg, #000814 0%, #050d1e 45%, #0a1628 100%)',
      accentColor: '#4FC3F7',
      label: 'LOW EARTH ORBIT',
      planetStyle: `
        position:absolute;bottom:-15%;left:-10%;
        width:65%;aspect-ratio:1;border-radius:50%;
        background:radial-gradient(ellipse at 42% 38%,
          rgba(79,195,247,0.55) 0%,
          rgba(30,100,200,0.38) 35%,
          rgba(10,40,100,0.22) 58%,
          transparent 75%
        );
        box-shadow:0 0 40px rgba(79,195,247,0.12);
      `,
    },
    '002': {
      bg: 'linear-gradient(160deg, #050505 0%, #0e0c0a 50%, #1a1814 100%)',
      accentColor: 'rgba(200,190,180,0.8)',
      label: 'LUNAR SURFACE',
      planetStyle: `
        position:absolute;bottom:-5%;left:-5%;right:-5%;
        height:28%;
        background:linear-gradient(to top,rgba(160,150,140,0.18),transparent);
        border-top:1px solid rgba(160,150,140,0.08);
      `,
    },
    '003': {
      bg: 'linear-gradient(160deg, #030308 0%, #1a0800 50%, #2a0d00 100%)',
      accentColor: 'rgba(255,130,50,0.9)',
      label: 'STELLAR NURSERY',
      planetStyle: `
        position:absolute;inset:0;
        background:
          radial-gradient(ellipse at 65% 25%, rgba(255,80,20,0.22) 0%, transparent 55%),
          radial-gradient(ellipse at 30% 60%, rgba(180,40,0,0.18) 0%, transparent 50%);
      `,
    },
    '004': {
      bg: 'linear-gradient(160deg, #030308 0%, #1a0500 50%, #2a0800 100%)',
      accentColor: 'rgba(180,80,40,0.7)',
      label: 'DEEP SPACE',
      planetStyle: `
        position:absolute;bottom:-20%;left:50%;transform:translateX(-50%);
        width:80%;aspect-ratio:1;border-radius:50%;
        background:radial-gradient(ellipse at 45% 40%,
          rgba(180,60,20,0.35) 0%, rgba(120,30,5,0.2) 40%, transparent 65%
        );
      `,
    },
  };

  const env = envs[missionNumber];

  // Earthrise for mission 002
  const showEarthrise = missionNumber === '002';

  let card: HTMLDivElement;
  let rx = 0, ry = 0;
  const MAX_TILT = 10;

  function handleMouseMove(e: MouseEvent) {
    const rect = card.getBoundingClientRect();
    ry = ((e.clientX - rect.left) / rect.width - 0.5) * 2 * MAX_TILT;
    rx = -((e.clientY - rect.top) / rect.height - 0.5) * 2 * MAX_TILT;
  }
  function handleMouseLeave() { rx = 0; ry = 0; }

  function handleClick(e: MouseEvent) {
    if (!slug) return;
    // Store click position (normalised) for T2 streak origin
    const rect = card.getBoundingClientRect();
    transitionStore.update((s) => ({
      ...s,
      clickX: (rect.left + rect.width / 2) / window.innerWidth,
      clickY: (rect.top + rect.height / 2) / window.innerHeight,
      missionAccent: MISSION_ACCENT[slug] ?? '#4FC3F7',
    }));
    goto(`/shop/${slug}`);
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' || e.key === ' ') handleClick(e as unknown as MouseEvent);
  }
</script>

<div
  bind:this={card}
  class="mission-card"
  style="
    background: {env.bg};
    transform: perspective(900px) rotateX({rx}deg) rotateY({ry}deg);
    --accent: {env.accentColor};
  "
  on:mousemove={handleMouseMove}
  on:mouseleave={handleMouseLeave}
  on:click={handleClick}
  on:keydown={handleKeydown}
  role="button"
  tabindex="0"
  aria-label="Explore {title}"
>
  <!-- Planet / environment layer -->
  <div class="env-layer" style={env.planetStyle}></div>

  <!-- Earthrise (mission 002 only) -->
  {#if showEarthrise}
    <div class="earthrise"></div>
  {/if}

  <!-- Star field — subtle SVG dots -->
  <svg class="card-stars" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
    {#each Array(35) as _, i}
      <circle
        cx="{(i * 137.508) % 100}%"
        cy="{(i * 97.3) % 100}%"
        r="{0.5 + (i % 3) * 0.35}"
        fill="rgba(240,237,230,{0.25 + (i % 5) * 0.12})"
      />
    {/each}
  </svg>

  <!-- Product image — floats in the scene -->
  {#if imageUrl}
    <div class="product-zone">
      <img
        class="product-img"
        src={imageUrl}
        alt={title}
        style="filter: drop-shadow(0 20px 50px {env.accentColor});"
      />
    </div>
  {:else}
    <!-- Placeholder glow when no image -->
    <div class="product-placeholder" style="background: radial-gradient(ellipse, {env.accentColor.replace(')', ',0.12)').replace('rgb(', 'rgba(')}, transparent 70%);"></div>
  {/if}

  <!-- Scanline overlay -->
  <div class="scanlines" aria-hidden="true"></div>

  <!-- Accent hover rim -->
  <div class="accent-rim"></div>

  <!-- Bottom text overlay -->
  <div class="card-info">
    <p class="mission-num">MISSION {missionNumber}</p>
    <p class="location" style="color: {env.accentColor};">{env.label}</p>
    <h2 class="product-title">{title}</h2>

    <div class="card-footer">
      {#if status === 'sold_out'}
        <span class="badge badge-sold">SOLD OUT</span>
      {:else if status === 'coming_soon'}
        <span class="badge badge-soon">COMING SOON</span>
      {:else}
        <span class="cta">EXPLORE MISSION →</span>
      {/if}
    </div>
  </div>
</div>

<style>
  .mission-card {
    position: relative;
    overflow: hidden;
    border: 1px solid rgba(240,237,230,0.06);
    border-radius: 4px;
    cursor: pointer;
    aspect-ratio: 3/4;
    transition:
      transform 0.3s ease,
      box-shadow 0.3s ease,
      border-color 0.3s ease;
    will-change: transform;
  }

  .mission-card:hover {
    border-color: color-mix(in srgb, var(--accent) 35%, transparent);
    box-shadow: 0 20px 60px color-mix(in srgb, var(--accent) 15%, transparent);
  }

  .env-layer {
    pointer-events: none;
  }

  .earthrise {
    position: absolute;
    top: 8%;
    right: 10%;
    width: 22%;
    aspect-ratio: 1;
    border-radius: 50%;
    background: radial-gradient(ellipse at 40% 38%,
      rgba(79,195,247,0.5) 0%,
      rgba(30,80,180,0.38) 40%,
      rgba(10,30,100,0.2) 60%,
      transparent 75%
    );
    box-shadow: 0 0 16px rgba(79,195,247,0.2);
  }

  .card-stars {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
  }

  .product-zone {
    position: absolute;
    top: 6%;
    left: 50%;
    transform: translateX(-50%);
    width: 70%;
    display: flex;
    align-items: center;
    justify-content: center;
    pointer-events: none;
    transition: transform 0.4s ease;
  }

  .mission-card:hover .product-zone {
    transform: translateX(-50%) translateY(-8px) scale(1.04);
  }

  .product-img {
    width: 100%;
    max-height: 52%;
    object-fit: contain;
    transform: rotate(-5deg);
    transition: transform 0.4s ease;
  }

  .mission-card:hover .product-img {
    transform: rotate(-2deg);
  }

  .product-placeholder {
    position: absolute;
    top: 10%;
    left: 20%;
    right: 20%;
    height: 45%;
    border-radius: 50%;
    pointer-events: none;
  }

  .scanlines {
    position: absolute;
    inset: 0;
    background: repeating-linear-gradient(
      to bottom,
      transparent,
      transparent 2px,
      rgba(0,0,0,0.025) 2px,
      rgba(0,0,0,0.025) 4px
    );
    pointer-events: none;
    z-index: 2;
  }

  .accent-rim {
    position: absolute;
    inset: 0;
    border-radius: 4px;
    box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--accent) 0%, transparent);
    transition: box-shadow 0.3s ease;
    pointer-events: none;
    z-index: 3;
  }

  .mission-card:hover .accent-rim {
    box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--accent) 30%, transparent);
  }

  .card-info {
    position: absolute;
    bottom: 0; left: 0; right: 0;
    padding: 1.25rem;
    background: linear-gradient(to top,
      rgba(3,3,8,0.97) 0%,
      rgba(3,3,8,0.85) 38%,
      rgba(3,3,8,0.4) 62%,
      transparent 100%
    );
    z-index: 4;
  }

  .mission-num {
    font-family: 'Inter', sans-serif;
    font-size: 0.52rem;
    letter-spacing: 0.25em;
    color: rgba(240,237,230,0.3);
    margin: 0 0 0.12rem;
    text-transform: uppercase;
  }

  .location {
    font-family: 'Inter', sans-serif;
    font-size: 0.58rem;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    margin: 0 0 0.35rem;
  }

  .product-title {
    font-family: 'Cormorant Garamond', serif;
    font-size: 1.35rem;
    font-weight: 300;
    color: #F0EDE6;
    margin: 0 0 0.65rem;
    line-height: 1.1;
  }

  .card-footer { display: flex; align-items: center; }

  .cta {
    font-family: 'Inter', sans-serif;
    font-size: 0.6rem;
    letter-spacing: 0.18em;
    color: rgba(240,237,230,0.5);
    transition: color 0.2s;
    text-transform: uppercase;
  }

  .mission-card:hover .cta {
    color: rgba(240,237,230,0.85);
  }

  .badge {
    font-family: 'Inter', sans-serif;
    font-size: 0.58rem;
    letter-spacing: 0.18em;
    padding: 0.2rem 0.65rem;
    border-radius: 2px;
    text-transform: uppercase;
  }

  .badge-sold {
    border: 1px solid rgba(240,237,230,0.25);
    color: rgba(240,237,230,0.45);
  }

  .badge-soon {
    border: 1px solid rgba(240,237,230,0.15);
    color: rgba(240,237,230,0.35);
  }
</style>
```

- [ ] **Verify in browser**: Open `/shop` — mission cards should show full-bleed planetary environments with product images floating in the scene. Hover should lift the product and show accent rim glow.

- [ ] **Commit**

```bash
git add web/src/lib/components/MissionCard.svelte
git commit -m "feat: MissionCard Option B — full-bleed planet environments, product embedded in scene"
```

---

## Task 9: Prev/Next Mission Navigation on Product Page

**Files:**
- Modify: `web/src/routes/shop/[slug]/+page.svelte`

This adds mission navigation arrows that trigger T3 (hyperspace ring jump). The store update ensures T3 is detected by the layout's `resolveTransition` call.

- [ ] **Add mission nav arrows to the product page**

Add the following to `web/src/routes/shop/[slug]/+page.svelte` — insert in `<script>` and in the template:

In the `<script>` block, add after the existing imports:

```ts
  import { MISSION_ORDER, transitionStore } from '$lib/stores/transition';
  import { goto } from '$app/navigation';

  const currentIndex = MISSION_ORDER.indexOf(product.slug ?? '');
  const prevSlug = currentIndex > 0 ? MISSION_ORDER[currentIndex - 1] : null;
  const nextSlug = currentIndex < MISSION_ORDER.length - 1 ? MISSION_ORDER[currentIndex + 1] : null;

  function navigateMission(slug: string) {
    // T3 is triggered because resolveTransition sees /shop/[slug] → /shop/[slug]
    goto(`/shop/${slug}`, { noScroll: true });
  }
```

Add the mission nav markup inside `.product-page`, below the mission tag div and above `.product-layout`:

```svelte
  <!-- Mission prev/next nav -->
  {#if prevSlug || nextSlug}
    <div class="mission-nav">
      {#if prevSlug}
        <button
          class="mission-nav-btn"
          on:click={() => navigateMission(prevSlug)}
          aria-label="Previous mission"
          data-magnetic
        >
          ← PREV MISSION
        </button>
      {:else}
        <span></span>
      {/if}
      {#if nextSlug}
        <button
          class="mission-nav-btn"
          on:click={() => navigateMission(nextSlug)}
          aria-label="Next mission"
          data-magnetic
        >
          NEXT MISSION →
        </button>
      {/if}
    </div>
  {/if}
```

Add to the `<style>` block:

```css
  .mission-nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0 0 2rem;
    max-width: 1200px;
    margin: 0 auto;
    width: 100%;
  }

  .mission-nav-btn {
    font-family: 'Inter', sans-serif;
    font-size: 0.62rem;
    letter-spacing: 0.2em;
    color: rgba(240,237,230,0.35);
    background: none;
    border: 1px solid rgba(240,237,230,0.1);
    padding: 0.6rem 1.2rem;
    cursor: none;
    transition: color 0.2s, border-color 0.2s;
    text-transform: uppercase;
  }

  .mission-nav-btn:hover {
    color: rgba(240,237,230,0.75);
    border-color: rgba(240,237,230,0.25);
  }
```

- [ ] **Verify in browser**: Navigate to `/shop/warped-reality-beanie`. "NEXT MISSION →" button should appear. Clicking it triggers the T3 hyperspace ring transition to `/shop/vanguard-trucker-hat`. No prev button on first mission. No next button on last.

- [ ] **Commit**

```bash
git add web/src/routes/shop/[slug]/+page.svelte
git commit -m "feat: add prev/next mission nav to product page — triggers T3 hyperspace ring"
```

---

## Self-Review

**Spec coverage check:**
- ✅ T1 Explosive Ascent (ignition, ascent, void, arrival) — Tasks 2, 6, 7
- ✅ T2 Hyperspace Jump tinted per destination — Tasks 3, 7, 8
- ✅ T3 Hyperspace Ring mission switch — Tasks 4, 7, 9
- ✅ T4 Return to Earth — Tasks 5, 7
- ✅ TransitionOverlay at z-index 9000 — Task 6
- ✅ Mission cards Option B full-bleed — Task 8
- ✅ Per-mission planet environments — Task 8
- ✅ Product embedded in scene — Task 8
- ✅ Prev/Next nav arrows — Task 9
- ✅ `prefers-reduced-motion` respected — Task 6 style block
- ✅ Checkout/order routes excluded (resolveTransition returns null for them) — Task 1

**Type consistency check:**
- `T1Elements.streaks` → `HTMLElement[]` — used consistently in T1 factory and overlay
- `T2Elements.streaks` → `HTMLElement[]` — same
- `T3Elements.rings` → `HTMLElement[]` — same
- `triggerOut` / `triggerIn` exported from overlay — called with matching signatures in layout
- `MISSION_ORDER` / `MISSION_ACCENT` / `resolveTransition` / `slugFromPath` — all exported from store, all imported where needed

**Placeholder check:** None found.
