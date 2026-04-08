# Napkin Runbook — Immortal Vibes

## Curation Rules
- Re-prioritize on every read.
- Keep recurring, high-value notes only.
- Max 10 items per category.
- Each item includes date + "Do instead".

## Execution & Validation (Highest Priority)

1. **[2026-04-07] Go API must only be reachable through Cloudflare — never directly**
   Do instead: Go's Fly.io config + middleware rejects any request missing `X-Proxy-Secret` header. CF Worker injects it. Test by hitting the Fly.io URL directly — it must 403.

2. **[2026-04-07] Stripe is source of truth for products — no custom admin**
   Do instead: Products, prices, descriptions managed in Stripe Dashboard. R2 images uploaded via script. Metadata fields carry extra info (size chart URL, care instructions, mission number).

3. **[2026-04-07] Multi-currency prices are explicit in Stripe — never auto-converted**
   Do instead: Set USD, GBP, EUR, AUD prices per product directly in Stripe. `CF-IPCountry` header drives currency selection in Go. Display currency in SvelteKit UI, not just at Stripe checkout.

## Domain Behavior Guardrails

1. **[2026-04-07] Mission Gold (`#C8922A`) is for prices only — nowhere else**
   Do instead: Use Lunar White opacity variations for all other UI chrome. Earth Blue lives only inside the LEO product scene environment — never as a button, tag, or highlight.

2. **[2026-04-07] No puzzle-piece shapes — organic curves only (global STOP)**
   Do instead: Visual test: "Does it look like a jigsaw puzzle piece?" If yes → wrong. Flowing asymmetric edge curves are allowed; symmetrical socket/bump shapes are not.

3. **[2026-04-07] Each product gets its own space environment — treat them as separate scenes**
   Do instead: LEO = cool blues, Lunar = warm grays, Stellar Nursery = oranges/reds, Deep Space = rust/black. Never bleed one scene's color temperature into another.

4. **[2026-04-07] Stock is tracked in Fly.io Postgres, not Stripe**
   Do instead: `product_stock` table (stripe_product_id, quantity, status). Webhook decrements on purchase. Admin sets via `PUT /api/admin/products/:id/stock` with `X-Admin-Secret` header. No UI.

## Architecture

1. **[2026-04-07] File structure — api/ is Go, worker/ is CF Worker TypeScript**
   Do instead: Go module at `api/` (chi router), CF Worker at `worker/src/index.ts`, SvelteKit at `web/` (Plan 3). Keep concerns strictly separated.

2. **[2026-04-07] KV namespaces: CARTS (TTL 7d), SESSIONS (TTL 30d)**
   Do instead: Cart state and session tokens live in CF KV. Don't use R2 for these. R2 is product images only, served via CF CDN.

## User Directives

1. **[2026-04-07] Phase 1 is guest checkout only — no auth, no accounts**
   Do instead: Email + shipping collected at Stripe checkout. Customer accounts are Phase 2. Don't build auth infrastructure now.

2. **[2026-04-07] No OpenAI products**
   Do instead: If AI features needed, use Claude API only.
