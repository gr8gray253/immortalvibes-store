# Immortal Vibes — Home Page Immersive Redesign
**Date:** 2026-04-08  
**Status:** Approved  
**Scope:** Home page visual composition, mouse look-around interaction, T1 pull-up transition redesign

---

## Overview

The home page becomes a first-person Earth POV looking up into space. The user is standing on Earth, staring up at the void. Mouse movement tilts the camera like a head turning — a wide-angle fisheye-style look-around using CSS 3D tilt plus layered star parallax. Clicking to enter the store fires a first-person explosive pull-up: the horizon drops away, stars streak radially outward, atmosphere blows past the edges, a breach flash, and you're in The Void.

---

## Section 1 — Scene Composition

Full-bleed, 100vh canvas environment. Layers back to front:

| Layer | Description |
|---|---|
| Void base | `#030308` background |
| Deep star field | 600+ stars, 0.5–1px, minimal tilt response (0.8% parallax) |
| Mid star field | 300 stars, 1–2px, moderate tilt response (2% parallax) |
| Close star field | 100 stars, 2–3px, strong tilt response (4% parallax) |
| Milky Way band | Diagonal canvas gradient smear, ~3% opacity. Barely visible, adds realism. |
| Atmosphere horizon | Bottom 12% of viewport. Curved limb glow: deep navy → `#4FC3F7` → transparent, radiating upward. Earth's edge below. |
| Hero text | "RISE BEYOND THE MORTAL PLANE" — upper-center of sky. Tilts opposite to scene at 30% intensity. Feels painted on the sky. |
| CTA | "ENTER THE MISSIONS" below tagline. Subtle gold underline pulse. Click fires pull-up. |

**Palette compliance:** Earth Blue (`#4FC3F7`) is used exclusively for the atmosphere horizon — correct per design constraints. No colored UI accents.

---

## Section 2 — Mouse Look-Around Interaction

### Tilt System

- Listen on `mousemove` at document level
- Normalize mouse offset from viewport center to `[-1, 1]` on both axes
- Apply to scene container via GSAP:
  - `rotateY`: max ±8° (horizontal look)
  - `rotateX`: max ±6° (vertical look)
  - `perspective: 800px` on wrapper
  - `duration: 1.2, ease: power2.out` — heavy lag, feels like head turning not cursor tracking

### Star Layer Parallax (on top of tilt)

| Layer | X/Y translate |
|---|---|
| Deep | `mouse * 0.8%` |
| Mid | `mouse * 2%` |
| Close | `mouse * 4%` |

### Atmosphere Horizon

Lives inside the scene container — tilts with it. As you look left, the horizon curves slightly left. Reinforces the "globe below" feeling.

### Idle Breathing

When mouse has not moved for 3 seconds, start a slow GSAP sine oscillation: `±1.5°` on both axes, period ~8s. Keeps the scene alive when the user isn't moving. Cancels immediately on next `mousemove`.

### Mobile

Tilt disabled. StarField runs normally. CTA tap fires pull-up.

---

## Section 3 — T1 First-Person Pull-Up Redesign

Replaces existing T1 (third-person rocket launch + city skyline) entirely.

**Total duration: ~1.4s**

### Timeline

| Time | Event |
|---|---|
| 0ms | Click fires. Horizon bar snaps in at bottom of screen. |
| 0–200ms | Horizon bar accelerates downward and exits screen. Camera lifting. |
| 0–400ms | Stars begin radial stretch from screen center outward. Slow — still in atmosphere. |
| 200–600ms | Star streaks accelerate — full radial hyperspace burst. Stars become lines. |
| 300–700ms | Atmosphere edge glow (`#4FC3F7`) rushes past screen edges and exits top. Blue smear at periphery. |
| 600–900ms | Streaks reach maximum length. Void fills center. Speed is total. |
| 800–1000ms | Breach flash — Lunar White (`#F0EDE6`) flash, 80ms peak, then fade. Atmosphere breaks. |
| 1000–1400ms | Flash fades. Streaks contract back to star points — you've entered The Void. Destination page fades in from 1.05x scale. |

### Implementation

- Star streaks drawn on a **separate canvas overlay** (not StarField canvas) — radial lines from center, length proportional to `speed` curve, opacity fading at tips
- GSAP timeline drives a `speed` variable (0 → 1 → 0) that the canvas reads each `requestAnimationFrame`
- Horizon bar is a DOM div: `position: fixed; bottom: 0; width: 100%; height: 8px; background: linear-gradient(...)` — animated with GSAP `y` from 0 to `+100vh`
- Atmosphere smear: two `position: fixed` divs at left/right edges, `#4FC3F7` gradient, animated opacity + `y` translate
- **T1 function signature unchanged** — `triggerTransition('t1')` still works. Only internals change.
- Existing T2/T3/T4 are not touched.

---

## Files Affected

| File | Change |
|---|---|
| `web/src/routes/+page.svelte` | Redesign hero scene, add look-around interaction, add CTA |
| `web/src/lib/components/TransitionOverlay.svelte` | Rewrite T1 animation sequence |
| `web/src/lib/components/StarField.svelte` | Expose layer refs for parallax translation |
| `web/src/app.css` | No changes expected |

---

## Out of Scope

- T2, T3, T4 transitions — untouched
- Mission pages — untouched
- Cart, checkout — untouched
- Mobile tilt — deferred (not in scope for demo)
