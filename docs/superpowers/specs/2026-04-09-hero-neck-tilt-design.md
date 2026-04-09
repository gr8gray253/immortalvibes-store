# Hero Neck-Tilt Design
**Date:** 2026-04-09  
**Project:** Immortal Vibes  
**Scope:** HeroScene.svelte + +page.svelte  
**Status:** Approved — ready for implementation

---

## Concept

The homepage is a first-person world. The mouse Y axis controls a "neck tilt" — looking down at the ground vs tilting your head all the way back to stare into the Milky Way.

The tagline "RISE BEYOND THE MORTAL PLANE" is split across the two worlds. It is never visible in full at the same time — only complete in the viewer's mind.

---

## The Tilt Mechanic

Mouse Y maps to `camY` via the existing lerp system:
```
targetY = -((e.clientY / h - 0.5) * 2)   // -1 (bottom) to +1 (top)
```

Horizon position formula (replaces current):
```
horizonY = h * (0.50 + camY * 0.52)
```

| camY | horizonY | View |
|------|----------|------|
| -1 | -2% of h | Nearly all ground — looking down |
| 0 | 50% of h | Horizon at midpoint — neutral/floating |
| +1 | 102% of h | Horizon off-screen — pure sky, full tilt |

At `camY = 1`, `horizonY >= h` — the canvas draws zero ground. The 50/50 neutral split intentionally reads as already weightless, consistent with the brand's "orbit higher" positioning.

Mouse leave resets `targetX = 0`, `targetY = 0`.

---

## Text — "THE MORTAL PLANE"

Anchored to the horizon. Sinks with the ground as you tilt.

- **Position:** `top = horizonY - 28px`, centered horizontally. Follows `horizonY` every frame from the `draw()` loop via direct style assignment.
- **Opacity:** `max(0, 1 - camY * 2.8)` — fully visible at neutral, zero by camY ≈ 0.36 (well before horizon exits the screen)
- **Type:** Cormorant Garamond, ~0.75rem, letter-spacing 0.35em, Lunar White at 55% base opacity
- **Behaviour:** Fades before the horizon drops, so the Earth disappears quietly — not abruptly

---

## Text — "RISE BEYOND"

Fixed at the center of the viewport. Lives in the stars.

- **Position:** `position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%)`
- **Opacity:** `max(0, (camY - 0.55) * 4)` — invisible until 55% tilted, fully visible by camY ≈ 0.80
- **Type:** Cormorant Garamond, ~1.8rem, letter-spacing 0.4em, Lunar White at 90% opacity, subtle text-shadow glow
- **Behaviour:** Reads before the button appears — sets the intention first

---

## Button — "ENTER THE MISSIONS"

Same fixed center position, below "RISE BEYOND".

- **Position:** ~3.25rem below "RISE BEYOND" text, same horizontal center (tunable)
- **Opacity:** `max(0, (camY - 0.65) * 5)` — appears after "RISE BEYOND", fully visible by camY ≈ 0.85
- **pointer-events:** toggled off when opacity < 0.1 (never accidentally clickable while invisible)
- **Style:** existing border/glow/pulse treatment — unchanged
- **Link:** `href="/shop"`

Both "RISE BEYOND" and the button live as HTML elements inside `HeroScene.svelte`, opacity set directly from the `draw()` rAF loop.

---

## Milky Way Photo

Always present — invisible enough at neutral to feel like a secret, unmistakable at full tilt.

**Opacity curve:**
```
opacity = min(0.85, 0.04 + max(0, camY - 0.2) * 1.02)
```

| camY | opacity | Effect |
|------|---------|--------|
| 0 | 0.04 | Faint shimmer at top edge — the "leak" |
| 0.2 | 0.04 | Threshold — starts growing |
| 0.6 | ~0.45 | Clearly visible — you're committed to looking up |
| 1.0 | 0.85 | Near full — Milky Way dominates |

**Position:**
- `translateY(-camY * h * 0.08)` — shifts upward as you tilt, reinforcing the rotation toward it
- `mix-blend-mode: screen` over dark canvas sky
- `mask-image: linear-gradient(to bottom, black 30%, transparent 72%)` — fades at bottom, never bleeds into ground

**The leak:** At 4% opacity with screen blend over near-black sky, the top edge shows a faint cool-blue shimmer. Enough to invite curiosity, not enough to read as a photo.

---

## +page.svelte Cleanup

Removals only — nothing added:
- Sub-copy removed ("Garments built for those who orbit higher…")
- "IMMORTAL VIBES" eyebrow removed
- Old camY-based CTA logic removed
- CTA `<a>` tag moves into `HeroScene.svelte`

Retained:
- Scroll indicator (teasers section remains below the fold)
- Teasers section (unchanged)

---

## Files Changed

| File | Change |
|------|--------|
| `web/src/lib/components/HeroScene.svelte` | New horizonY formula, "THE MORTAL PLANE" + "RISE BEYOND" + button HTML, MW opacity curve, translateY direction fix, mouse leave handler |
| `web/src/routes/+page.svelte` | Remove sub-copy, eyebrow, old CTA logic |

---

## Success Criteria

- Mouse at center: horizon at 50%, "THE MORTAL PLANE" readable at horizon, MW barely perceptible at top edge
- Mouse moving up: "THE MORTAL PLANE" fades, horizon drops, MW grows
- Mouse at top: pure sky, no ground, "RISE BEYOND" fully visible, button clickable, MW at ~85% opacity
- Mouse leaves window: world returns smoothly to neutral
- Button is always reachable — mouse stays in "looking up" territory when hovering it
