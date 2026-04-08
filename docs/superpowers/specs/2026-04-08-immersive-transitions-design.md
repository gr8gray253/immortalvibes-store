# Immortal Vibes — Immersive Transitions & Mission Cards
**Design Spec · 2026-04-08**

---

## Overview

Replace SvelteKit's default page navigation with a 4-transition cinematic system inspired by Star Wars and Destiny 2. Every route change has a purpose-built transition. Mission cards become full-bleed planetary environments with embedded product previews.

---

## Mission Cards — Option B (Full Immersive)

### Concept
Each mission card is a viewport into a world. The planet/environment bleeds edge-to-edge. The product photo is embedded in the scene — floating in the nebula, hovering in orbit, sitting on the surface. A dark gradient at the bottom surfaces text. Feels like selecting a destination in Destiny 2.

### Layout (per card)
- **Aspect ratio:** 3/4 portrait
- **Background layer:** Full-bleed planetary environment (CSS radial gradients + star field)
- **Product layer:** Product photo positioned and sized per mission — floats in upper 60% of card, drop-shadow matching environment color
- **Overlay layer:** Scanline texture (subtle `repeating-linear-gradient`) at 3% opacity
- **Text layer (bottom 45%):** `linear-gradient` to dark, then:
  - Mission number (e.g. `MISSION 001`) — tiny, spaced, low opacity
  - Location name (e.g. `LOW EARTH ORBIT`) — colored per mission
  - Product name — Cormorant Garamond, ~1.3rem, white
  - Availability dot + status + price (right-aligned)
- **Border:** 1px `rgba(240,237,230,0.06)`, on hover shifts to mission accent color at 25% opacity

### Hover State
- Card lifts: `translateY(-4px) scale(1.01)`
- Product image: lifts further `translateY(-8px)`, subtle scale up
- Glow: `box-shadow` using mission accent color
- CTA badge fades in top-right: `EXPLORE →`

### Per-Mission Environments

| Mission | Product | Environment | Accent | Planet hint |
|---|---|---|---|---|
| 001 · LEO | Warped Reality Beanie | Deep navy → midnight blue | `#4FC3F7` | Earth sphere bottom-left, blue atmosphere rim |
| 002 · Lunar Surface | Vanguard Trucker Hat | Near-black → warm gray | `rgba(200,190,180,0.7)` | Gray regolith floor, Earthrise top-right |
| 003 · Stellar Nursery | Racerback Tanktop | Black → deep amber/rust | `rgba(255,130,50,0.8)` | Nebula cloud fill, orange-red radials |
| 004 · Deep Space | Next Drop (TBD) | Black → deep rust | `rgba(180,80,40,0.6)` | Mars-red void, "CLASSIFIED" treatment |

### Product Positioning
- Product image: `position: absolute`, sized to ~55% card width, positioned upper-center or slightly right
- `filter: drop-shadow(0 16px 40px <mission-accent-color> at 30% opacity)`
- `transform: rotate(-4deg)` default, `-2deg` on hover — slight tilt for life
- When `image_url` is empty (trucker hat): show silhouette placeholder with mission accent glow

---

## The 4-Transition System

All transitions use GSAP + a `<TransitionOverlay>` Svelte component that mounts at layout level, above all page content, `z-index: 9000`. Transitions are triggered by SvelteKit's `beforeNavigate` / `afterNavigate` lifecycle hooks.

### T1 — Explosive Ascent (Homepage → Shop)
**Trigger:** Any navigation to `/shop`
**Duration:** ~900ms total

**Phase 1 — Ignition (0–150ms)**
- Full-screen white flash (`opacity: 0 → 1 → 0` over 150ms)
- Explosion plume: radial gradient expanding from bottom-center, orange-white
- Shockwave ring: `border-radius: 50%` scaling from 0 to 200vw
- City skyline (SVG path, bottom strip) shudders via GSAP shake

**Phase 2 — Ascent (150–450ms)**
- Vertical speed streaks: 8–10 `<div>` elements, 1px wide, `scaleY` from 0 to full height, staggered, blue-white color
- Atmosphere glow: `rgba(79,195,247,0.35)` gradient rising from bottom, fading out
- Motion blur: CSS `filter: blur(2px)` on the canvas element while speed streaks are active

**Phase 3 — The Void (450–700ms)**
- All speed elements fade out simultaneously
- `StarField` canvas fades IN — full brightness, full density (2x normal star count for this moment)
- Silence: no UI chrome, no overlay text — just the star field
- Subtle nebula hint: two large blurred `radial-gradient` divs, very low opacity (3–4%)
- Duration: 250ms held — do not rush this

**Phase 4 — Arrival (700–900ms)**
- Shop page content fades up from `opacity: 0, translateY: 30px` → normal
- Stars persist (StarField continues running under shop content)
- Mission cards stagger in with `revealOnScroll`-style entrance (already implemented)
- Overlay dismisses

### T2 — Kessel Run Hyperspace Jump (Shop → Mission/Product)
**Trigger:** Mission card click → `/shop/[slug]`
**Duration:** ~550ms

- Star streaks radiate outward from click position (not screen center)
- Color tinted per destination: LEO = `#4FC3F7` tint, Stellar Nursery = `rgba(255,130,50)` tint, Lunar = white, Deep Space = rust
- Peak: white flash at ~300ms
- Destination mission scene fades in through the flash
- GSAP timeline: `gsap.timeline()` — streaks `scaleX` from 0, flash, page swap, streaks fade

### T3 — Hyperspace Ring Jump (Mission → Mission)
**Trigger:** Prev/Next mission arrows on product pages
**Duration:** ~650ms

- Current page content: `scale(0.95) opacity(0)` spiraling inward via GSAP
- Concentric gold rings expand from screen center: 5 rings, staggered `scale(0 → 3)`, `opacity(0.6 → 0)`
- Mission Gold `#C8922A` throughout — color never changes between missions
- New mission content: enters from center `scale(1.1 → 1) opacity(0 → 1)`
- Ring pulse: outermost ring at `0ms`, innermost at `200ms` (reverse order = imploding feel)

### T4 — Return to Earth (Any → Homepage)
**Trigger:** Logo click or any navigation to `/`
**Duration:** ~800ms

- Stars in upper portion fade out first
- Re-entry heat shield: radial gradient expanding from top-center, amber-orange
- Craft dot descends from top: `translateY(-100vh → 40vh)` over 400ms
- Atmosphere thickens: blue `rgba(79,195,247,0.3)` gradient rising from bottom
- Earth surface appears: city skyline SVG fades in at bottom
- Homepage hero fades up through the surface layer
- Inverse of T1 — same city SVG asset reused

---

## Implementation Architecture

### New Files
- `web/src/lib/components/TransitionOverlay.svelte` — canvas + overlay divs, all transition rendering
- `web/src/lib/stores/transition.ts` — Svelte store: `{ active: boolean, type: T1|T2|T3|T4, destination: string }`
- `web/src/lib/transitions/t1-ascent.ts` — GSAP timeline factory for T1
- `web/src/lib/transitions/t2-hyperspace.ts` — GSAP timeline factory for T2
- `web/src/lib/transitions/t3-ring.ts` — GSAP timeline factory for T3
- `web/src/lib/transitions/t4-return.ts` — GSAP timeline factory for T4

### Modified Files
- `web/src/routes/+layout.svelte` — mount `TransitionOverlay`, wire `beforeNavigate`/`afterNavigate`
- `web/src/lib/components/MissionCard.svelte` — full Option B redesign
- `web/src/routes/shop/[slug]/+page.svelte` — add Prev/Next mission nav arrows

### Transition Routing Logic
```
navigate to /shop          → T1 (from any page)
navigate to /shop/[slug]   → T2 (from /shop), T3 (from another /shop/[slug])
navigate to /             → T4 (from any page)
```

### StarField Integration
- T1 Phase 3 signals `StarField` to boost density: store flag `transitionStarBurst: true`
- StarField reads flag and temporarily doubles particle count + brightness
- Resets after 500ms

---

## Constraints
- All transitions respect `prefers-reduced-motion` — if set, replace with simple 200ms crossfade
- GSAP already installed (`gsap` + `ScrollTrigger`) — `MotionPathPlugin` not needed
- No new npm packages — pure GSAP + CSS
- `MagneticCursor` z-index stays at 9999 (above `TransitionOverlay` at 9000)
- Transition must complete before new page becomes interactive — lock pointer events during active transition

---

## Out of Scope
- Sound design (no audio)
- Mobile-specific transition variants (same transitions, scaled timing if needed)
- Transition for `/checkout`, `/order/[id]` — standard fade only
