# Immortal Vibes — Rebuild Design Spec
**Date:** 2026-04-07  
**Status:** Approved  
**Tagline:** Rise Beyond the Mortal Plane

---

## Overview

Full rebuild of theimmortalvibes.com from Shopify to a custom stack. Fitness/lifestyle clothing brand, small catalog (4 SKUs currently), global customer base including overseas buyers. Goal: a cinematic, over-the-top visual experience that makes the site a marvel to look at — each product gets its own space mission environment. The design is the product.

---

## Stack

| Layer | Technology | Purpose |
|---|---|---|
| Frontend | SvelteKit | SSR + client hydration, all UI |
| Hosting | Cloudflare Pages | SvelteKit deployment |
| Edge shield | Cloudflare Worker | Rate limiting, origin validation, reverse proxy to Go |
| Backend | Go on Fly.io | Cart, orders, Stripe integration, webhooks |
| Object storage | Cloudflare R2 | Product images, served via CF CDN |
| Session storage | Cloudflare KV | Cart state, session tokens |
| Payments | Stripe | Products, Prices (multi-currency), PaymentIntent, webhooks |
| DNS / CDN / DDoS | Cloudflare | All traffic passes through CF |

---

## Architecture

```
Browser → Cloudflare Pages (SvelteKit SSR)
                ↓ API calls
        Cloudflare Worker (shield)
                ↓ validated requests only
        Go API on Fly.io
                ↓
        Stripe API + Cloudflare KV + R2
```

### Security model
- Go API on Fly.io accepts traffic **only from Cloudflare IP ranges** — direct hits are dropped at the network level
- CF Worker validates origin header + enforces rate limits (KV counter) before forwarding
- Stripe webhook signature verified in Go on every event — no unsigned events processed
- Stripe Payment Element handles all card data — raw card numbers never touch the Go server

### Currency detection
- Cloudflare passes `CF-IPCountry` header to Go on every request — no external geolocation service needed
- Go reads the header and sets the Stripe PaymentIntent currency accordingly
- Explicit multi-currency prices defined per product in Stripe (USD, GBP, EUR, AUD at minimum)
- Prices display in local currency throughout the SvelteKit UI, not just at Stripe checkout

---

## Pages & Routes

### SvelteKit

| Route | Page | Visual Treatment |
|---|---|---|
| `/` | Homepage | Full-bleed star field hero · brand statement · cinematic product reveal on scroll · email capture |
| `/shop` | Mission Select | 4 cinematic mission cards — each a portal to a product world |
| `/shop/[slug]` | Product (Mission) Page | Unique space environment per product · parallax · 3D tilt · size selector · currency-aware price · particle burst on add to cart |
| `/cart` | Cart | Slide-in drawer · line items · multi-currency total |
| `/checkout` | Checkout | Stripe Payment Element fully styled in space theme — user never leaves the site |
| `/order/[id]` | Confirmation | Full-screen star shower celebration · order summary · email confirmation prompt |
| `/about` | About | Brand story · "Rise Beyond the Mortal Plane" · cinematic editorial treatment |
| `/contact` | Contact | Minimal form · email only |

### Go API

| Method | Route | Purpose |
|---|---|---|
| GET | `/api/products` | Fetch all Stripe products, enrich with R2 image URLs |
| GET | `/api/products/:id` | Single product + all multi-currency prices |
| POST | `/api/cart` | Create cart in KV, return cart token cookie |
| PUT | `/api/cart/:id` | Add / update / remove line items |
| POST | `/api/checkout` | Create Stripe PaymentIntent, set currency from CF-IPCountry |
| POST | `/api/webhooks/stripe` | Verify signature → confirm order → send email → clear cart |
| GET | `/api/order/:id` | Order data for confirmation page |
| POST | `/api/contact` | Contact form → email dispatch |
| PUT | `/api/admin/products/:id/stock` | Set stock quantity / status (requires `X-Admin-Secret` header) |

---

## Visual Design System

### Aesthetic Direction
Artemis mission + NASA space program. Not sci-fi, not fantasy — **real space**. The visual language references the actual color temperatures of space photography: the cold blues of Low Earth Orbit, the warm grays of the lunar surface, the hot oranges and reds of stellar nurseries. Minimal Swiss-grid typography discipline on top.

### Color Palette

| Token | Hex | Role |
|---|---|---|
| Deep Void | `#030308` | Primary background |
| Space Black | `#08080f` | Card / panel backgrounds |
| Deep Navy | `#0A0E2A` | LEO scene background only |
| Lunar White | `#F0EDE6` | All UI chrome — nav, tags, buttons, labels |
| Mission Gold | `#C8922A` | Prices exclusively — nowhere else |
| Earth Blue | `#4FC3F7` | Environmental color inside LEO scene only — not a UI accent |
| Mars Rust | `#8B4513` | Deep space / future product scene |

**Accent rule:** No color accent in the UI chrome beyond Lunar White opacity variations. Gold is reserved for prices so they read as value. Earth Blue lives only inside the LEO product environment — it never appears as a button, tag, or highlight. This ensures the accent palette works universally across all four product color variants (blue, green, sand, black) without any conflict.

### Typography
Two fonts only — a light serif for hero/display, a geometric sans for everything else.

| Role | Style |
|---|---|
| Hero / Display | Serif · 100–200 weight · 10–12px letter-spacing · all-caps |
| Mission Tag | Sans · 600 weight · 5px tracking · NASA Orange · monospace feel |
| Product Name | Sans · 300 weight · 5px tracking · Lunar White |
| Price | Monospace · Mission Gold · shows multi-currency pair |
| Body | Sans · 400 weight · normal tracking · muted (40–50% white) |

### Motion System

| Effect | Implementation | Trigger |
|---|---|---|
| Parallax star field | GSAP ScrollTrigger · 3 depth layers at 0.2×/0.5×/0.8× | Scroll |
| Product 3D tilt | CSS perspective transform · star surface parallax | Mousemove on card |
| Magnetic cursor | Custom cursor · warps toward interactive elements within 100px radius | Global |
| Scroll reveals | GSAP · fade up + scale from 0.95 | IntersectionObserver |
| Add to cart burst | Canvas particle system · ~40 stars · 600ms arc | Button click |
| Order celebration | Full-screen star shower · runs once · 3s | Confirmation page load |
| Nav glassmorphism | `backdrop-filter: blur()` · transparent at top · frosted on scroll | Scroll position |

---

## Product Mission Pages

Each of the 4 products gets a unique cinematic space environment. The shop page is a mission select screen. Every new SKU added to the catalog earns its own environment.

| Mission | Product | Scene | Color Temperature |
|---|---|---|---|
| 001 · Low Earth Orbit | Warped Reality Beanie | Earth curvature below · ISS altitude · atmosphere glow | Cool blues `#0a3060` → `#021020` |
| 002 · Lunar Surface | Vanguard Trucker Hat | Gray regolith · Earthrise · Artemis-direct reference | Warm grays · `#1a1814` |
| 003 · Stellar Nursery | Racerback Tanktop | Orion Nebula palette · star formation oranges and reds | Warm oranges `#3d1200` → `#030308` |
| 004 · Deep Space | Next drop (TBD) | Mars rust · deep black · reserved for next SKU | Rust `#2a0d00` → `#030308` |

---

## Product Management

**Stripe Dashboard is the source of truth.** The owner manages all products, prices, and descriptions directly in Stripe. No custom admin to build.

- Product images uploaded to R2 via a lightweight upload script (not a full admin UI)
- Stripe product metadata fields carry extra info: size chart URL, care instructions, mission number
- Multi-currency prices set explicitly per product in Stripe (not auto-converted)

---

## Data Flow: Purchase Journey

1. **Page load** — SvelteKit SSR fetches `/api/products` → Go reads Stripe Products API → enriches with R2 URLs → page renders with real data. `CF-IPCountry` sets display currency.
2. **Add to cart** — Client POSTs to `/api/cart` → CF Worker rate-checks → Go creates/updates cart in KV → returns cart token cookie.
3. **Checkout** — Client POSTs to `/api/checkout` → Go creates Stripe PaymentIntent with correct currency → client initializes Stripe Payment Element → user completes payment inside the space-themed `/checkout` page.
4. **Post-purchase** — Stripe fires `payment_intent.succeeded` webhook → Go verifies signature → marks order complete → dispatches confirmation email → clears KV cart → redirects to `/order/[id]`.

---

## Auth Strategy

- **Phase 1 (now):** Guest checkout only. Email + shipping collected at checkout, Stripe receipt sent automatically.
- **Phase 2 (future):** Customer accounts. Guest flow becomes the first step of signup. Order history backed by Stripe Customer objects + a Postgres table on Fly.io. KV session already in place — adding a user ID is minimal lift.

---

## Deployment

| Service | Config |
|---|---|
| Cloudflare Pages | Auto-deploy from GitHub main. SvelteKit adapter-cloudflare. |
| Fly.io | Go binary. Single region to start (IAD). Dockerfile. |
| Cloudflare Worker | Thin proxy script. Deployed via Wrangler. Routes `/api/*`. |
| Cloudflare R2 | Public bucket for product images. CF CDN serves them. |
| Cloudflare KV | Two namespaces: `CARTS` (TTL 7d), `SESSIONS` (TTL 30d). |
| Stripe | Test mode during dev. Webhook endpoint registered to Go on Fly. |

---

## Stock Management

Stripe has no native stock tracking. A lightweight `product_stock` table lives on Fly.io (Postgres):

```sql
product_stock (
  stripe_product_id TEXT PRIMARY KEY,
  quantity          INT NOT NULL DEFAULT 0,
  status            TEXT NOT NULL DEFAULT 'in_stock'
  -- status: 'in_stock' | 'sold_out' | 'coming_soon'
)
```

### How it works
- **On purchase:** `payment_intent.succeeded` webhook decrements `quantity`. When quantity hits 0, status auto-flips to `sold_out`.
- **Manual control:** Owner calls `PUT /api/admin/products/:id/stock` with a secret header to set quantity or status directly. No UI — just a curl command or a REST client. Sufficient for 4 SKUs.
- **Coming soon:** Owner sets status to `coming_soon` before a new drop. The mission card renders a teaser — no Add to Cart button, just atmosphere and a notify prompt (email capture to KV).
- **SvelteKit:** Every product fetch from Go includes `{ status, quantity }`. Frontend renders SOLD OUT badge and disables Add to Cart when status is not `in_stock`.

### Protected admin endpoint
`PUT /api/admin/products/:id/stock` requires `X-Admin-Secret: <env var>` header. No session, no OAuth — secret rotated via Fly.io env. Sufficient security for a one-owner store.

---

## Out of Scope (Phase 1)

- Customer accounts / order history
- Admin UI for product management (Stripe Dashboard handles this)
- Size-level stock tracking (tracked at product level, not variant level, for now)
- Email marketing / newsletter (email capture stores to KV list for now)
- Blog / editorial content
- Search

---

## Success Criteria

- Site loads under 2s on a cold CF Pages request
- Checkout completes end-to-end with correct currency for UK, AU, and EU visitors
- All 4 product mission pages render their unique space environments with full animation suite
- Stripe webhook processes a test payment and sends a confirmation email
- Go API is unreachable when hit directly — only accessible through Cloudflare
- The site looks like nothing else in the fitness/lifestyle space
