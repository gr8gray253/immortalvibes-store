# SvelteKit Core — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap the SvelteKit frontend for Immortal Vibes — project scaffolding, design system, global star field layout, navigation, typed API client, page shells, and Cloudflare Pages deployment.

**Architecture:** SvelteKit runs on Cloudflare Pages via `@sveltejs/adapter-cloudflare`. All API calls go through a typed fetch wrapper in `src/lib/api.ts` that targets the Go API (via CF Worker in prod, localhost:8080 in dev). The root layout mounts a Canvas-based star field and nav/footer that wrap every page.

**Tech Stack:** SvelteKit 2, `@sveltejs/adapter-cloudflare`, Tailwind CSS v3, GSAP 3 (ScrollTrigger), TypeScript, Google Fonts (Cormorant Garamond + Inter)

---

## File Structure

```
web/
├── src/
│   ├── app.html                        # HTML shell — Google Fonts links, root div
│   ├── app.css                         # Global CSS: custom properties, resets, typography utilities
│   ├── lib/
│   │   ├── api.ts                      # Typed fetch wrapper for all Go API endpoints
│   │   ├── components/
│   │   │   ├── Nav.svelte              # Transparent→glassmorphism nav on scroll
│   │   │   ├── StarField.svelte        # Canvas 3-layer parallax star field
│   │   │   └── Footer.svelte          # Minimal footer, lunar text
│   │   └── stores/
│   │       └── cart.ts                 # Writable store: cart item count
│   └── routes/
│       ├── +layout.svelte              # Root layout: StarField + Nav + slot + Footer
│       ├── +layout.ts                  # Root layout load (empty, sets prerender=false)
│       ├── +page.svelte                # Homepage shell
│       ├── +error.svelte               # 404 / error page — "Lost in the void"
│       ├── shop/
│       │   └── +page.svelte            # Shop shell
│       ├── about/
│       │   └── +page.svelte            # About shell
│       └── contact/
│           └── +page.svelte            # Contact shell
├── static/
│   └── favicon.ico                     # Placeholder favicon
├── svelte.config.js                    # adapter-cloudflare, vitePreprocess
├── vite.config.ts                      # Standard SvelteKit vite config
├── tailwind.config.ts                  # Extended with brand tokens
├── postcss.config.js                   # Tailwind + autoprefixer
├── tsconfig.json                       # SvelteKit default tsconfig
└── package.json
```

---

## Task 1: Scaffold SvelteKit Project

**Files:**
- Create: `web/` (entire directory via CLI)
- Modify: `web/svelte.config.js`
- Modify: `web/package.json`

- [ ] **Step 1: Scaffold the project**

Run from the repo root (`immortalvibes/`):

```bash
npm create svelte@latest web
```

At prompts, select:
- Which Svelte app template? → **Skeleton project**
- Add type checking with TypeScript? → **Yes, using TypeScript syntax**
- Select additional options → check **Add ESLint** and **Add Prettier**

Expected output ends with:
```
Your project is ready!
```

- [ ] **Step 2: Install dependencies**

```bash
cd web && npm install
npm install -D @sveltejs/adapter-cloudflare
npm install -D tailwindcss@3 postcss autoprefixer
npm install gsap
npm install -D @types/gsap
```

Expected: no peer dep errors. `node_modules/` created.

- [ ] **Step 3: Replace `svelte.config.js` with adapter-cloudflare**

```js
// web/svelte.config.js
import adapter from '@sveltejs/adapter-cloudflare';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter({
      routes: {
        include: ['/*'],
        exclude: ['<all>']
      }
    })
  }
};

export default config;
```

- [ ] **Step 4: Verify dev server starts**

```bash
npm run dev
```

Expected output:
```
  VITE v5.x.x  ready in xxx ms
  ➜  Local:   http://localhost:5173/
```

Open `http://localhost:5173/` — browser shows the default SvelteKit skeleton page (white background, "Welcome to SvelteKit" heading).

Kill dev server (`Ctrl+C`).

- [ ] **Step 5: Commit**

```bash
cd web
git add -A
git commit -m "feat: scaffold SvelteKit project with adapter-cloudflare"
```

---

## Task 2: Configure Tailwind CSS

**Files:**
- Create: `web/tailwind.config.ts`
- Create: `web/postcss.config.js`
- Modify: `web/src/app.css`
- Modify: `web/vite.config.ts`

- [ ] **Step 1: Init Tailwind**

```bash
cd web && npx tailwindcss init -p --ts
```

Expected: creates `tailwind.config.ts` and `postcss.config.js`.

- [ ] **Step 2: Replace `tailwind.config.ts` with brand-extended config**

```ts
// web/tailwind.config.ts
import type { Config } from 'tailwindcss';

export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      colors: {
        void: '#030308',
        space: '#08080f',
        navy: '#0A0E2A',
        lunar: '#F0EDE6',
        gold: '#C8922A',
        'earth-blue': '#4FC3F7'
      },
      fontFamily: {
        display: ['"Cormorant Garamond"', 'serif'],
        body: ['Inter', 'sans-serif']
      },
      letterSpacing: {
        hero: '0.6em'
      },
      backdropBlur: {
        nav: '12px'
      }
    }
  },
  plugins: []
} satisfies Config;
```

- [ ] **Step 3: Verify `postcss.config.js` (generated by init — confirm contents)**

```js
// web/postcss.config.js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {}
  }
};
```

If it was generated with CommonJS (`module.exports`), replace with the ESM version above.

- [ ] **Step 4: Write `src/app.css`**

This file holds all CSS custom properties, the Tailwind directives, resets, and typography utility classes.

```css
/* web/src/app.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

/* ─── Brand Custom Properties ────────────────────────── */
:root {
  --void: #030308;
  --space: #08080f;
  --navy: #0A0E2A;
  --lunar: #F0EDE6;
  --gold: #C8922A;
  --earth-blue: #4FC3F7;
}

/* ─── Base Reset ─────────────────────────────────────── */
*, *::before, *::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

html {
  background-color: var(--void);
  color: var(--lunar);
  font-family: 'Inter', sans-serif;
  font-weight: 300;
  scroll-behavior: smooth;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

body {
  min-height: 100vh;
  background-color: var(--void);
  overflow-x: hidden;
}

/* ─── Typography Utilities ───────────────────────────── */
.type-hero {
  font-family: 'Cormorant Garamond', serif;
  font-weight: 200;
  letter-spacing: 0.6em;
  text-transform: uppercase;
}

.type-display {
  font-family: 'Cormorant Garamond', serif;
  font-weight: 300;
  letter-spacing: 0.4em;
  text-transform: uppercase;
}

.type-body {
  font-family: 'Inter', sans-serif;
  font-weight: 300;
}

.type-label {
  font-family: 'Inter', sans-serif;
  font-weight: 400;
  font-size: 0.75rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

/* ─── Price: gold ONLY ───────────────────────────────── */
.price {
  color: var(--gold);
  font-family: 'Inter', sans-serif;
  font-weight: 400;
}

/* ─── LEO Scene: earth-blue lives HERE only ─────────── */
.leo-scene {
  background-color: var(--navy);
  color: var(--earth-blue);
}

/* ─── Lunar opacity hierarchy ────────────────────────── */
.text-lunar-primary   { color: rgba(240, 237, 230, 1.0); }
.text-lunar-secondary { color: rgba(240, 237, 230, 0.7); }
.text-lunar-tertiary  { color: rgba(240, 237, 230, 0.4); }
.text-lunar-ghost     { color: rgba(240, 237, 230, 0.2); }

/* ─── Scrollbar ──────────────────────────────────────── */
::-webkit-scrollbar { width: 4px; }
::-webkit-scrollbar-track { background: var(--void); }
::-webkit-scrollbar-thumb { background: rgba(240, 237, 230, 0.2); border-radius: 2px; }
```

- [ ] **Step 5: Update `src/app.html` to import Google Fonts and app.css**

```html
<!-- web/src/app.html -->
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%sveltekit.assets%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
    <link
      href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@200;300&family=Inter:wght@300;400&display=swap"
      rel="stylesheet"
    />
    %sveltekit.head%
  </head>
  <body data-sveltekit-preload-data="hover">
    <div style="display: contents">%sveltekit.body%</div>
  </body>
</html>
```

- [ ] **Step 6: Import app.css in root layout (placeholder until Task 5)**

Create a minimal `src/routes/+layout.svelte` just to wire the CSS import:

```svelte
<!-- web/src/routes/+layout.svelte -->
<script>
  import '../app.css';
</script>

<slot />
```

- [ ] **Step 7: Verify Tailwind is working**

Start dev server:
```bash
npm run dev
```

Edit `src/routes/+page.svelte` temporarily to:
```svelte
<h1 class="type-hero text-4xl text-lunar p-8">Immortal Vibes</h1>
```

Open `http://localhost:5173/` — heading should render in Cormorant Garamond at 200 weight with 0.6em letter-spacing on a near-black background.

Revert `+page.svelte` to:
```svelte
<p>Home</p>
```

Kill dev server.

- [ ] **Step 8: Commit**

```bash
git add tailwind.config.ts postcss.config.js src/app.css src/app.html src/routes/+layout.svelte src/routes/+page.svelte
git commit -m "feat: configure Tailwind CSS with brand design tokens and global typography"
```

---

## Task 3: Cart Store

**Files:**
- Create: `web/src/lib/stores/cart.ts`

- [ ] **Step 1: Write the cart store**

```ts
// web/src/lib/stores/cart.ts
import { writable, derived } from 'svelte/store';

export interface CartItem {
  variantId: string;
  productId: string;
  title: string;
  quantity: number;
  unitPrice: number; // in cents
  currency: string;
}

export interface CartState {
  id: string | null;
  items: CartItem[];
}

const initialState: CartState = {
  id: null,
  items: []
};

function createCartStore() {
  const { subscribe, set, update } = writable<CartState>(initialState);

  return {
    subscribe,
    setCart(id: string, items: CartItem[]) {
      set({ id, items });
    },
    addItem(item: CartItem) {
      update((state) => {
        const existing = state.items.find((i) => i.variantId === item.variantId);
        if (existing) {
          return {
            ...state,
            items: state.items.map((i) =>
              i.variantId === item.variantId
                ? { ...i, quantity: i.quantity + item.quantity }
                : i
            )
          };
        }
        return { ...state, items: [...state.items, item] };
      });
    },
    removeItem(variantId: string) {
      update((state) => ({
        ...state,
        items: state.items.filter((i) => i.variantId !== variantId)
      }));
    },
    clear() {
      set(initialState);
    }
  };
}

export const cart = createCartStore();

/** Derived: total item count for badge display */
export const cartCount = derived(cart, ($cart) =>
  $cart.items.reduce((sum, item) => sum + item.quantity, 0)
);
```

- [ ] **Step 2: Verify TypeScript compiles**

```bash
npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add src/lib/stores/cart.ts
git commit -m "feat: add cart writable store with item count derived store"
```

---

## Task 4: API Client

**Files:**
- Create: `web/src/lib/api.ts`
- Create: `web/src/lib/env.ts`

- [ ] **Step 1: Create environment helper**

```ts
// web/src/lib/env.ts
import { browser } from '$app/environment';
import { PUBLIC_API_URL } from '$env/static/public';

/**
 * Returns the Go API base URL.
 * In dev: http://localhost:8080
 * In prod: value of PUBLIC_API_URL env var (the CF Worker URL)
 */
export function getApiBase(): string {
  if (!browser && typeof PUBLIC_API_URL === 'undefined') {
    // SSR build-time fallback — adapter-cloudflare will use the env var at runtime
    return 'http://localhost:8080';
  }
  return PUBLIC_API_URL ?? 'http://localhost:8080';
}
```

- [ ] **Step 2: Add `PUBLIC_API_URL` to `.env` for local dev**

Create `web/.env`:
```
PUBLIC_API_URL=http://localhost:8080
```

Create `web/.env.example`:
```
PUBLIC_API_URL=https://immortalvibes-worker.<subdomain>.workers.dev
```

- [ ] **Step 3: Write the typed API client**

```ts
// web/src/lib/api.ts
import { getApiBase } from './env';

// ─── Domain Types ────────────────────────────────────────

export interface Price {
  amount: number;   // integer cents
  currency: string; // ISO 4217, e.g. "USD"
}

export interface ProductVariant {
  id: string;
  title: string;
  price: Price;
  available: boolean;
  sku: string;
}

export interface Product {
  id: string;
  title: string;
  description: string;
  handle: string;
  images: string[];       // array of image URLs
  variants: ProductVariant[];
  tags: string[];
  available: boolean;
  createdAt: string;      // ISO 8601
}

export interface LineItem {
  variantId: string;
  quantity: number;
}

export interface Cart {
  id: string;
  items: LineItem[];
  subtotal: Price;
  createdAt: string;
  updatedAt: string;
}

export interface CheckoutSession {
  id: string;
  cartId: string;
  currency: string;
  url: string;          // redirect URL for payment provider
  expiresAt: string;    // ISO 8601
}

export interface Order {
  id: string;
  status: 'pending' | 'paid' | 'fulfilled' | 'cancelled';
  items: LineItem[];
  total: Price;
  createdAt: string;
  updatedAt: string;
}

// ─── Error Type ──────────────────────────────────────────

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

// ─── Internal fetch helper ────────────────────────────────

async function apiFetch<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const base = getApiBase();
  const url = `${base}${path}`;

  const response = await fetch(url, {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers
    },
    ...options
  });

  if (!response.ok) {
    let code = 'UNKNOWN_ERROR';
    let message = `HTTP ${response.status}`;
    try {
      const body = await response.json();
      code = body.code ?? code;
      message = body.message ?? message;
    } catch {
      // response body is not JSON — use defaults
    }
    throw new ApiError(response.status, code, message);
  }

  return response.json() as Promise<T>;
}

// ─── Product Endpoints ────────────────────────────────────

/** Fetch all products */
export function getProducts(): Promise<Product[]> {
  return apiFetch<Product[]>('/api/v1/products');
}

/** Fetch a single product by ID */
export function getProduct(id: string): Promise<Product> {
  return apiFetch<Product>(`/api/v1/products/${id}`);
}

// ─── Cart Endpoints ───────────────────────────────────────

/** Create a new empty cart */
export function createCart(): Promise<Cart> {
  return apiFetch<Cart>('/api/v1/carts', { method: 'POST' });
}

/** Fetch a cart by ID */
export function getCart(id: string): Promise<Cart> {
  return apiFetch<Cart>(`/api/v1/carts/${id}`);
}

/**
 * Replace the line items in a cart.
 * Pass the full desired item list — server replaces, not merges.
 */
export function updateCart(id: string, items: LineItem[]): Promise<Cart> {
  return apiFetch<Cart>(`/api/v1/carts/${id}`, {
    method: 'PUT',
    body: JSON.stringify({ items })
  });
}

// ─── Checkout Endpoints ───────────────────────────────────

/** Create a checkout session for the given cart */
export function createCheckout(cartId: string, currency: string): Promise<CheckoutSession> {
  return apiFetch<CheckoutSession>('/api/v1/checkout', {
    method: 'POST',
    body: JSON.stringify({ cartId, currency })
  });
}

// ─── Order Endpoints ──────────────────────────────────────

/** Fetch a completed order by ID */
export function getOrder(id: string): Promise<Order> {
  return apiFetch<Order>(`/api/v1/orders/${id}`);
}
```

- [ ] **Step 4: Verify TypeScript compiles**

```bash
npx tsc --noEmit
```

Expected: no errors. If you see `Cannot find module '$env/static/public'`, that is a SvelteKit virtual module resolved at build time — it is fine; the tsc check via `tsconfig.json` has the SvelteKit type shims already included.

- [ ] **Step 5: Commit**

```bash
git add src/lib/api.ts src/lib/env.ts .env .env.example
git commit -m "feat: add typed API client and environment helper"
```

---

## Task 5: StarField Component

**Files:**
- Create: `web/src/lib/components/StarField.svelte`

- [ ] **Step 1: Write the StarField component**

This component owns a `<canvas>` element. It generates 3 layers of stars (close/mid/far), runs a `requestAnimationFrame` draw loop, and uses GSAP ScrollTrigger to apply parallax offsets per layer.

```svelte
<!-- web/src/lib/components/StarField.svelte -->
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { browser } from '$app/environment';
  import gsap from 'gsap';
  import ScrollTrigger from 'gsap/ScrollTrigger';

  if (browser) {
    gsap.registerPlugin(ScrollTrigger);
  }

  // Layer configuration: speed is the parallax scroll multiplier
  interface Layer {
    count: number;
    speed: number;    // 0.2 = slow (far), 0.8 = fast (close)
    minRadius: number;
    maxRadius: number;
    minAlpha: number;
    maxAlpha: number;
  }

  const LAYERS: Layer[] = [
    { count: 200, speed: 0.2, minRadius: 0.5, maxRadius: 0.8, minAlpha: 0.2, maxAlpha: 0.4 },
    { count: 120, speed: 0.5, minRadius: 0.6, maxRadius: 1.1, minAlpha: 0.3, maxAlpha: 0.6 },
    { count: 60,  speed: 0.8, minRadius: 0.9, maxRadius: 1.5, minAlpha: 0.4, maxAlpha: 0.7 }
  ];

  interface Star {
    x: number; // 0..1 normalized
    y: number; // 0..1 normalized
    radius: number;
    alpha: number;
  }

  let canvas: HTMLCanvasElement;
  let ctx: CanvasRenderingContext2D;
  let rafId: number;
  let stars: Star[][] = [];
  let scrollY = 0;
  let scrollTriggerInstance: ScrollTrigger | null = null;

  function rand(min: number, max: number): number {
    return min + Math.random() * (max - min);
  }

  function buildStars(): void {
    stars = LAYERS.map((layer) =>
      Array.from({ length: layer.count }, () => ({
        x: Math.random(),
        y: Math.random(),
        radius: rand(layer.minRadius, layer.maxRadius),
        alpha: rand(layer.minAlpha, layer.maxAlpha)
      }))
    );
  }

  function resize(): void {
    if (!canvas) return;
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  }

  function draw(): void {
    if (!ctx || !canvas) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    LAYERS.forEach((layer, i) => {
      const parallaxOffset = scrollY * layer.speed;

      stars[i].forEach((star) => {
        const x = star.x * canvas.width;
        // Apply parallax: shift Y up by offset, wrap with modulo
        const rawY = star.y * canvas.height - parallaxOffset;
        const y = ((rawY % canvas.height) + canvas.height) % canvas.height;

        ctx.beginPath();
        ctx.arc(x, y, star.radius, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(240, 237, 230, ${star.alpha})`;
        ctx.fill();
      });
    });

    rafId = requestAnimationFrame(draw);
  }

  onMount(() => {
    if (!browser) return;

    ctx = canvas.getContext('2d')!;
    buildStars();
    resize();

    window.addEventListener('resize', resize);

    // GSAP ScrollTrigger drives the parallax scrollY value
    scrollTriggerInstance = ScrollTrigger.create({
      start: 0,
      end: 'max',
      onUpdate: (self) => {
        scrollY = self.scroll();
      }
    });

    rafId = requestAnimationFrame(draw);
  });

  onDestroy(() => {
    if (!browser) return;
    cancelAnimationFrame(rafId);
    window.removeEventListener('resize', resize);
    scrollTriggerInstance?.kill();
  });
</script>

<canvas
  bind:this={canvas}
  aria-hidden="true"
  style="
    position: fixed;
    inset: 0;
    width: 100vw;
    height: 100vh;
    pointer-events: none;
    z-index: 0;
  "
/>
```

- [ ] **Step 2: Start dev server and verify star field renders**

The root `+layout.svelte` still only has `<slot />` at this point — we'll wire it in Task 7. For a quick visual check, temporarily edit `src/routes/+page.svelte`:

```svelte
<script>
  import StarField from '$lib/components/StarField.svelte';
</script>

<StarField />
<div style="position:relative;z-index:1;padding:2rem;">
  <p style="color:#F0EDE6;">Stars visible behind this text</p>
</div>
```

Run:
```bash
npm run dev
```

Open `http://localhost:5173/` — you should see small white/near-white dots scattered across the near-black background. Scroll down to verify parallax shift (add a tall div temporarily if needed).

Revert `+page.svelte` to `<p>Home</p>`.

- [ ] **Step 3: Commit**

```bash
git add src/lib/components/StarField.svelte src/routes/+page.svelte
git commit -m "feat: add Canvas StarField component with 3-layer GSAP ScrollTrigger parallax"
```

---

## Task 6: Nav Component

**Files:**
- Create: `web/src/lib/components/Nav.svelte`

- [ ] **Step 1: Write the Nav component**

The nav starts fully transparent. On scroll past 10px it transitions to glassmorphism. Uses a Svelte `$effect` (Svelte 5) or `onMount` scroll listener (Svelte 4 compatible).

```svelte
<!-- web/src/lib/components/Nav.svelte -->
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { browser } from '$app/environment';
  import { cartCount } from '$lib/stores/cart';
  import { page } from '$app/stores';

  let scrolled = false;
  let scrollHandler: (() => void) | null = null;

  onMount(() => {
    if (!browser) return;

    scrollHandler = () => {
      scrolled = window.scrollY > 10;
    };
    window.addEventListener('scroll', scrollHandler, { passive: true });
  });

  onDestroy(() => {
    if (browser && scrollHandler) {
      window.removeEventListener('scroll', scrollHandler);
    }
  });

  function isActive(href: string): boolean {
    return $page.url.pathname === href || $page.url.pathname.startsWith(href + '/');
  }
</script>

<nav
  class="nav"
  class:nav--scrolled={scrolled}
  aria-label="Main navigation"
>
  <div class="nav__inner">
    <!-- Logo -->
    <a href="/" class="nav__logo" aria-label="Immortal Vibes home">
      <span class="nav__logo-symbol" aria-hidden="true">⌥</span>
      <span class="nav__logo-text">Immortal Vibes</span>
    </a>

    <!-- Links -->
    <ul class="nav__links" role="list">
      <li>
        <a
          href="/shop"
          class="nav__link"
          class:nav__link--active={isActive('/shop')}
        >Shop</a>
      </li>
      <li>
        <a
          href="/about"
          class="nav__link"
          class:nav__link--active={isActive('/about')}
        >About</a>
      </li>
      <li>
        <a
          href="/contact"
          class="nav__link"
          class:nav__link--active={isActive('/contact')}
        >Contact</a>
      </li>
    </ul>

    <!-- Cart -->
    <a href="/cart" class="nav__cart" aria-label="Cart ({$cartCount} items)">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.5"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z" />
        <line x1="3" y1="6" x2="21" y2="6" />
        <path d="M16 10a4 4 0 0 1-8 0" />
      </svg>
      {#if $cartCount > 0}
        <span class="nav__cart-badge" aria-hidden="true">{$cartCount}</span>
      {/if}
    </a>
  </div>
</nav>

<style>
  .nav {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 100;
    background: transparent;
    transition:
      background 0.3s ease,
      backdrop-filter 0.3s ease,
      border-bottom-color 0.3s ease;
    border-bottom: 1px solid transparent;
  }

  .nav--scrolled {
    background: rgba(3, 3, 8, 0.7);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border-bottom-color: rgba(240, 237, 230, 0.08);
  }

  .nav__inner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    max-width: 1280px;
    margin: 0 auto;
    padding: 1.25rem 2rem;
    gap: 2rem;
  }

  .nav__logo {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    text-decoration: none;
    color: rgba(240, 237, 230, 1);
    flex-shrink: 0;
  }

  .nav__logo-symbol {
    font-size: 1.25rem;
    line-height: 1;
    opacity: 0.8;
  }

  .nav__logo-text {
    font-family: 'Cormorant Garamond', serif;
    font-weight: 300;
    font-size: 1.1rem;
    letter-spacing: 0.25em;
    text-transform: uppercase;
  }

  .nav__links {
    display: flex;
    align-items: center;
    gap: 2.5rem;
    list-style: none;
    margin: 0 auto;
  }

  .nav__link {
    font-family: 'Inter', sans-serif;
    font-weight: 300;
    font-size: 0.8rem;
    letter-spacing: 0.15em;
    text-transform: uppercase;
    text-decoration: none;
    color: rgba(240, 237, 230, 0.7);
    transition: color 0.2s ease;
  }

  .nav__link:hover,
  .nav__link--active {
    color: rgba(240, 237, 230, 1);
  }

  .nav__cart {
    position: relative;
    display: flex;
    align-items: center;
    color: rgba(240, 237, 230, 0.7);
    text-decoration: none;
    transition: color 0.2s ease;
    flex-shrink: 0;
  }

  .nav__cart:hover {
    color: rgba(240, 237, 230, 1);
  }

  .nav__cart-badge {
    position: absolute;
    top: -6px;
    right: -8px;
    min-width: 16px;
    height: 16px;
    background: rgba(240, 237, 230, 0.9);
    color: #030308;
    border-radius: 8px;
    font-family: 'Inter', sans-serif;
    font-weight: 400;
    font-size: 0.65rem;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0 3px;
    line-height: 1;
  }
</style>
```

- [ ] **Step 2: Visual check**

Temporarily import Nav in the current `+layout.svelte`:

```svelte
<!-- web/src/routes/+layout.svelte -->
<script>
  import '../app.css';
  import Nav from '$lib/components/Nav.svelte';
</script>

<Nav />
<slot />
```

```bash
npm run dev
```

Open `http://localhost:5173/`:
- Nav is transparent over the dark background
- Logo shows "⌥ Immortal Vibes" in Cormorant Garamond
- Shop / About / Contact links visible in Inter
- Cart icon in top-right

Add inline style `height: 200vh` to `+page.svelte` body temporarily, then scroll — nav background should blur in after 10px of scroll.

Revert `+page.svelte` back to `<p>Home</p>`.

- [ ] **Step 3: Commit**

```bash
git add src/lib/components/Nav.svelte src/routes/+layout.svelte
git commit -m "feat: add Nav component with transparent-to-glassmorphism scroll transition"
```

---

## Task 7: Footer Component

**Files:**
- Create: `web/src/lib/components/Footer.svelte`

- [ ] **Step 1: Write the Footer component**

```svelte
<!-- web/src/lib/components/Footer.svelte -->
<footer class="footer">
  <div class="footer__inner">
    <p class="footer__copy">
      &copy; {new Date().getFullYear()} Immortal Vibes
    </p>
    <nav class="footer__links" aria-label="Footer navigation">
      <a href="/shop" class="footer__link">Shop</a>
      <a href="/about" class="footer__link">About</a>
      <a href="/contact" class="footer__link">Contact</a>
    </nav>
  </div>
</footer>

<style>
  .footer {
    position: relative;
    z-index: 10;
    border-top: 1px solid rgba(240, 237, 230, 0.08);
    padding: 2rem 0;
    margin-top: 6rem;
  }

  .footer__inner {
    max-width: 1280px;
    margin: 0 auto;
    padding: 0 2rem;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 1rem;
  }

  .footer__copy {
    font-family: 'Inter', sans-serif;
    font-weight: 300;
    font-size: 0.75rem;
    letter-spacing: 0.08em;
    color: rgba(240, 237, 230, 0.4);
  }

  .footer__links {
    display: flex;
    gap: 1.5rem;
  }

  .footer__link {
    font-family: 'Inter', sans-serif;
    font-weight: 300;
    font-size: 0.75rem;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    text-decoration: none;
    color: rgba(240, 237, 230, 0.4);
    transition: color 0.2s ease;
  }

  .footer__link:hover {
    color: rgba(240, 237, 230, 0.8);
  }
</style>
```

- [ ] **Step 2: Commit**

```bash
git add src/lib/components/Footer.svelte
git commit -m "feat: add minimal Footer component"
```

---

## Task 8: Root Layout

**Files:**
- Modify: `web/src/routes/+layout.svelte`
- Create: `web/src/routes/+layout.ts`

- [ ] **Step 1: Write the full root layout**

This replaces the placeholder from Task 2/6.

```svelte
<!-- web/src/routes/+layout.svelte -->
<script lang="ts">
  import '../app.css';
  import { browser } from '$app/environment';
  import { onNavigate } from '$app/navigation';
  import StarField from '$lib/components/StarField.svelte';
  import Nav from '$lib/components/Nav.svelte';
  import Footer from '$lib/components/Footer.svelte';

  // View Transition API for page transitions (progressive enhancement)
  if (browser) {
    onNavigate((navigation) => {
      if (!document.startViewTransition) return;
      return new Promise((resolve) => {
        document.startViewTransition(async () => {
          resolve();
          await navigation.complete;
        });
      });
    });
  }
</script>

<!-- Star field fixed behind everything -->
<StarField />

<!-- Page chrome: nav sits above star field -->
<Nav />

<!-- Main content -->
<main class="layout-main">
  <slot />
</main>

<!-- Footer -->
<Footer />

<style>
  :global(body) {
    background-color: var(--void);
  }

  .layout-main {
    position: relative;
    z-index: 10;
    /* Offset for fixed nav height (~72px) */
    padding-top: 4.5rem;
    min-height: 100vh;
  }
</style>
```

- [ ] **Step 2: Write `+layout.ts`**

```ts
// web/src/routes/+layout.ts
// Root layout load — nothing to load globally yet.
// Sets prerender false so Cloudflare Pages serves all routes dynamically.
export const prerender = false;

export function load() {
  return {};
}
```

- [ ] **Step 3: Visual check**

```bash
npm run dev
```

Open `http://localhost:5173/`:
- Stars visible in the background (canvas fixed, z-index 0)
- Nav rendered above stars
- Footer rendered at page bottom
- No layout shift / overlap

Navigate to `/about`, `/shop`, `/contact` — browser should hit the 404 page (we haven't created routes yet). That is expected.

- [ ] **Step 4: Commit**

```bash
git add src/routes/+layout.svelte src/routes/+layout.ts
git commit -m "feat: complete root layout with StarField, Nav, Footer, and view transitions"
```

---

## Task 9: Page Shells

**Files:**
- Modify: `web/src/routes/+page.svelte`
- Create: `web/src/routes/shop/+page.svelte`
- Create: `web/src/routes/about/+page.svelte`
- Create: `web/src/routes/contact/+page.svelte`
- Create: `web/src/routes/+error.svelte`

- [ ] **Step 1: Homepage shell**

```svelte
<!-- web/src/routes/+page.svelte -->
<svelte:head>
  <title>Immortal Vibes</title>
  <meta name="description" content="Apparel forged at the edge of orbit." />
</svelte:head>

<section class="hero">
  <div class="hero__content">
    <h1 class="type-hero hero__title">Immortal Vibes</h1>
    <p class="hero__sub type-label text-lunar-secondary">
      Apparel forged at the edge of orbit
    </p>
    <a href="/shop" class="hero__cta type-label">
      Explore Collection
    </a>
  </div>
</section>

<style>
  .hero {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: calc(100vh - 4.5rem);
    padding: 2rem;
    text-align: center;
  }

  .hero__content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1.5rem;
  }

  .hero__title {
    font-size: clamp(2rem, 8vw, 5rem);
    color: rgba(240, 237, 230, 1);
  }

  .hero__sub {
    font-size: 0.8rem;
    letter-spacing: 0.2em;
  }

  .hero__cta {
    display: inline-block;
    margin-top: 1rem;
    padding: 0.75rem 2.5rem;
    border: 1px solid rgba(240, 237, 230, 0.3);
    color: rgba(240, 237, 230, 0.8);
    text-decoration: none;
    letter-spacing: 0.2em;
    font-size: 0.75rem;
    transition:
      border-color 0.25s ease,
      color 0.25s ease,
      background 0.25s ease;
  }

  .hero__cta:hover {
    border-color: rgba(240, 237, 230, 0.7);
    color: rgba(240, 237, 230, 1);
    background: rgba(240, 237, 230, 0.05);
  }
</style>
```

- [ ] **Step 2: Shop shell**

```svelte
<!-- web/src/routes/shop/+page.svelte -->
<svelte:head>
  <title>Shop — Immortal Vibes</title>
  <meta name="description" content="Browse the Immortal Vibes collection." />
</svelte:head>

<section class="page-section">
  <header class="page-header">
    <h1 class="type-display page-title">Collection</h1>
    <p class="type-body text-lunar-secondary page-subtitle">
      Products load here in Plan 4.
    </p>
  </header>

  <div class="product-grid" aria-label="Product grid placeholder">
    <!-- Product cards populated in Plan 4 -->
  </div>
</section>

<style>
  .page-section {
    max-width: 1280px;
    margin: 0 auto;
    padding: 4rem 2rem;
  }

  .page-header {
    margin-bottom: 3rem;
  }

  .page-title {
    font-size: clamp(1.5rem, 4vw, 3rem);
    color: rgba(240, 237, 230, 1);
    margin-bottom: 0.75rem;
  }

  .page-subtitle {
    font-size: 0.9rem;
  }

  .product-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 2rem;
  }
</style>
```

- [ ] **Step 3: About shell**

```svelte
<!-- web/src/routes/about/+page.svelte -->
<svelte:head>
  <title>About — Immortal Vibes</title>
  <meta name="description" content="The story behind Immortal Vibes." />
</svelte:head>

<section class="page-section">
  <header class="page-header">
    <h1 class="type-display page-title">About</h1>
  </header>
  <div class="prose type-body text-lunar-secondary">
    <p>Brand story content loads here in Plan 5.</p>
  </div>
</section>

<style>
  .page-section {
    max-width: 800px;
    margin: 0 auto;
    padding: 4rem 2rem;
  }

  .page-header {
    margin-bottom: 3rem;
  }

  .page-title {
    font-size: clamp(1.5rem, 4vw, 3rem);
    color: rgba(240, 237, 230, 1);
  }

  .prose {
    line-height: 1.8;
    font-size: 1rem;
  }
</style>
```

- [ ] **Step 4: Contact shell**

```svelte
<!-- web/src/routes/contact/+page.svelte -->
<svelte:head>
  <title>Contact — Immortal Vibes</title>
  <meta name="description" content="Get in touch with Immortal Vibes." />
</svelte:head>

<section class="page-section">
  <header class="page-header">
    <h1 class="type-display page-title">Contact</h1>
  </header>
  <p class="type-body text-lunar-secondary">
    Contact form loads here in Plan 5.
  </p>
</section>

<style>
  .page-section {
    max-width: 600px;
    margin: 0 auto;
    padding: 4rem 2rem;
  }

  .page-header {
    margin-bottom: 3rem;
  }

  .page-title {
    font-size: clamp(1.5rem, 4vw, 3rem);
    color: rgba(240, 237, 230, 1);
  }
</style>
```

- [ ] **Step 5: 404 / Error page**

```svelte
<!-- web/src/routes/+error.svelte -->
<script>
  import { page } from '$app/stores';
</script>

<svelte:head>
  <title>{$page.status} — Lost in the void</title>
</svelte:head>

<section class="void-error">
  <div class="void-error__content">
    <p class="void-error__code type-label text-lunar-tertiary">
      {$page.status}
    </p>
    <h1 class="type-hero void-error__title">
      Lost in the void
    </h1>
    <p class="type-body text-lunar-secondary void-error__message">
      {$page.error?.message ?? 'This coordinate does not exist.'}
    </p>
    <a href="/" class="void-error__link type-label">
      Return to orbit
    </a>
  </div>
</section>

<style>
  .void-error {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: calc(100vh - 4.5rem);
    padding: 2rem;
    text-align: center;
  }

  .void-error__content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1.25rem;
  }

  .void-error__code {
    font-size: 0.7rem;
    letter-spacing: 0.3em;
  }

  .void-error__title {
    font-size: clamp(2rem, 6vw, 4rem);
    color: rgba(240, 237, 230, 0.9);
  }

  .void-error__message {
    font-size: 0.9rem;
    max-width: 380px;
    line-height: 1.7;
  }

  .void-error__link {
    display: inline-block;
    margin-top: 1.5rem;
    padding: 0.65rem 2rem;
    border: 1px solid rgba(240, 237, 230, 0.25);
    color: rgba(240, 237, 230, 0.7);
    text-decoration: none;
    font-size: 0.7rem;
    letter-spacing: 0.2em;
    transition:
      border-color 0.25s ease,
      color 0.25s ease;
  }

  .void-error__link:hover {
    border-color: rgba(240, 237, 230, 0.6);
    color: rgba(240, 237, 230, 1);
  }
</style>
```

- [ ] **Step 6: Visual check — all pages**

```bash
npm run dev
```

Visit each URL and verify:
- `http://localhost:5173/` — hero text "IMMORTAL VIBES" in Cormorant Garamond, stars behind, nav transparent at top, glassmorphism on scroll. "Explore Collection" button border-visible.
- `http://localhost:5173/shop` — "COLLECTION" heading, empty grid area.
- `http://localhost:5173/about` — "ABOUT" heading.
- `http://localhost:5173/contact` — "CONTACT" heading.
- `http://localhost:5173/does-not-exist` — 404, "Lost in the void" hero text, "Return to orbit" link.

All pages: stars visible behind content, nav chrome, footer at bottom.

- [ ] **Step 7: Commit**

```bash
git add src/routes/+page.svelte src/routes/shop/+page.svelte src/routes/about/+page.svelte src/routes/contact/+page.svelte src/routes/+error.svelte
git commit -m "feat: add page shells for /, /shop, /about, /contact, and 404 error page"
```

---

## Task 10: Build Verification

**Files:**
- None new — verifying existing work compiles for CF Pages.

- [ ] **Step 1: Run full TypeScript check**

```bash
cd web && npx tsc --noEmit
```

Expected: exits with code 0, no output.

- [ ] **Step 2: Run SvelteKit build**

```bash
npm run build
```

Expected output ends with:
```
✓ built in Xs
```

No errors. The `.svelte-kit/output/` directory is created.

If you see `Error: Cannot find module '@sveltejs/adapter-cloudflare'` — run `npm install -D @sveltejs/adapter-cloudflare` again and retry.

- [ ] **Step 3: Run preview to verify build output**

```bash
npm run preview
```

Open `http://localhost:4173/` — same visual result as dev server. All 4 routes accessible.

Kill preview server.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: verify production build passes for CF Pages"
```

---

## Task 11: Cloudflare Pages Deployment

**Files:**
- Create: `web/.env.production` (not committed — documented below)
- No code changes — this is dashboard + CLI configuration.

- [ ] **Step 1: Push repository to GitHub**

If the repo isn't on GitHub yet:

```bash
# from immortalvibes/ root
git remote add origin https://github.com/<your-username>/immortalvibes.git
git branch -M main
git push -u origin main
```

Expected: repo appears at `https://github.com/<your-username>/immortalvibes`.

- [ ] **Step 2: Create Cloudflare Pages project via dashboard**

1. Go to [https://dash.cloudflare.com/](https://dash.cloudflare.com/) → **Workers & Pages** → **Create application** → **Pages** → **Connect to Git**
2. Select your GitHub account → choose the `immortalvibes` repository → click **Begin setup**
3. Configure build settings:
   - **Project name:** `immortalvibes`
   - **Production branch:** `main`
   - **Build command:** `cd web && npm install && npm run build`
   - **Build output directory:** `web/.svelte-kit/cloudflare`
   - **Root directory:** `/` (repo root)
4. Under **Environment variables (optional)**, click **Add variable**:
   - Variable name: `PUBLIC_API_URL`
   - Value: `https://immortalvibes-worker.<your-subdomain>.workers.dev`
   - Environment: **Production** (and **Preview** if desired)
5. Click **Save and Deploy**

Expected: Cloudflare triggers a build. Build log shows `npm run build` completing successfully. Deploy status shows **Success**.

- [ ] **Step 3: Verify live deployment**

Once deployment is green:
- Visit `https://immortalvibes.pages.dev/` — same visual result as local dev.
- Visit `https://immortalvibes.pages.dev/shop` — shop shell renders.
- Visit `https://immortalvibes.pages.dev/does-not-exist` — "Lost in the void" 404 page.

- [ ] **Step 4: Verify auto-deploy on push**

Make a trivial change:
```bash
# in web/src/routes/+page.svelte, change the subtitle text slightly, then:
git add src/routes/+page.svelte
git commit -m "chore: trigger CF Pages auto-deploy verification"
git push origin main
```

Expected: Cloudflare dashboard shows a new deployment triggered automatically within ~30 seconds of the push.

---

## Self-Review Checklist

**1. Spec coverage:**

| Requirement | Task |
|---|---|
| SvelteKit project with adapter-cloudflare | Task 1 |
| Tailwind CSS installed | Task 1, 2 |
| GSAP installed | Task 1, 5 |
| Global star field — canvas, 3 parallax layers | Task 5 |
| Scroll speeds 0.2x / 0.5x / 0.8x | Task 5 — `LAYERS` config |
| `requestAnimationFrame` draw loop | Task 5 |
| GSAP ScrollTrigger for parallax | Task 5 |
| Stars 0.5-1.5px radius, semi-transparent lunar white | Task 5 — `LAYERS` config |
| Root layout — star field + nav + footer + slot | Task 8 |
| Page transitions | Task 8 — View Transition API |
| Nav transparent → glassmorphism on scroll | Task 6 |
| Nav: logo ⌥ trident | Task 6 |
| Nav: Shop / About / Contact links | Task 6 |
| Nav: cart icon with item count badge | Task 6 |
| CSS custom properties — all 6 brand tokens | Task 2 |
| Tailwind config extended with brand tokens | Task 2 |
| Typography classes — display/hero in Cormorant, body in Inter | Task 2 |
| Two fonts only | Task 2 — app.html + app.css |
| Accent rule: gold for prices only, earth-blue for LEO scene only | Task 2 — `.price`, `.leo-scene` classes |
| API client `src/lib/api.ts` — all 7 functions | Task 4 |
| Typed interfaces: Product, Price, Cart, LineItem, Order | Task 4 |
| `ApiError` class | Task 4 |
| Cart store with item count derived store | Task 3 |
| Page shells: /, /shop, /about, /contact | Task 9 |
| 404 "Lost in the void" | Task 9 |
| CF Pages deployment — GitHub connect, env var | Task 11 |
| `PUBLIC_API_URL` env var | Task 4, 11 |

No gaps found.

**2. Placeholder scan:**

- Shop/About/Contact shells have placeholder text like "Products load here in Plan 4" — these are intentional per the spec ("content placeholder — real content in Plans 4-5") and are not implementation omissions.
- All component code is complete and real.
- No "TBD", "TODO", or "implement later" in any code block.

**3. Type consistency:**

- `CartItem` defined in `cart.ts` — used only within that file; `Nav.svelte` imports `cartCount` (derived, no type needed there).
- `LineItem` in `api.ts` uses `{ variantId, quantity }` — consistent across `updateCart()` signature and `Cart.items` field.
- `CheckoutSession` returned by `createCheckout()` — not referenced elsewhere in this plan (Plans 4-5 consume it).
- `StarField.svelte` — `Star` interface, `Layer` interface, `LAYERS` array, `buildStars()`, `draw()`, `resize()` — all internal, no cross-file type surface.
- `Nav.svelte` uses `$page` from `$app/stores` and `cartCount` from `$lib/stores/cart` — both correctly imported.
- `getApiBase()` in `env.ts` — called by `apiFetch()` in `api.ts` — signature matches.

All consistent.

---

Plan complete and saved to `docs/superpowers/plans/2026-04-07-plan-3-sveltekit-core.md`.

**Two execution options:**

**1. Subagent-Driven (recommended)** — Fresh subagent per task, review between tasks, fast iteration loop.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
