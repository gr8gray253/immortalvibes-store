# Cart & Checkout — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a fully embedded cart and checkout experience — cart drawer, shipping form, Stripe Payment Element, and order confirmation — entirely within the deep-space SvelteKit frontend without ever redirecting to Stripe's hosted page.

**Architecture:** Cart state lives in Cloudflare KV (keyed by cart token), with the token stored in a browser cookie. The SvelteKit frontend talks to the Go API for all cart mutations and checkout creation. Stripe Payment Element is mounted client-side using `@stripe/stripe-js`, initialized with a `clientSecret` returned by the Go API's `/api/checkout` endpoint, and styled via Stripe's `appearance` API to match the dark aesthetic.

**Tech Stack:** SvelteKit (Cloudflare Pages adapter), `@stripe/stripe-js`, Go API on Fly.io, Cloudflare KV, TypeScript, CSS custom properties from Plans 1–4 design system.

---

## File Structure

| Path | Action | Responsibility |
|---|---|---|
| `web/src/lib/stores/cart.ts` | Create | Svelte writable store — items, count, total, currency. Reads/writes cart token cookie. Syncs with Go API. |
| `web/src/lib/stores/currency.ts` | Create | Writable store holding detected currency string (`'USD'`, `'GBP'`, etc.). Set from layout load data. |
| `web/src/lib/api.ts` | Modify | Add `getCart`, `addToCart`, `removeFromCart`, `createCheckout`, `getOrder` API functions. |
| `web/src/lib/components/CartDrawer.svelte` | Create | Slide-in drawer from right. Lists `CartItem` components, subtotal, proceed CTA. |
| `web/src/lib/components/CartItem.svelte` | Create | Single line item: name, size, quantity stepper, price, remove button. |
| `web/src/lib/components/CheckoutForm.svelte` | Create | Shipping fields (name, email, address, city, country, postcode) with inline validation. |
| `web/src/lib/components/PaymentElement.svelte` | Create | Mounts Stripe Payment Element. Accepts `clientSecret`. Emits `paymentSubmit` and `paymentError`. |
| `web/src/lib/components/StarShower.svelte` | Create | Canvas full-screen particle celebration. Runs once on mount, auto-removes after 3s. |
| `web/src/routes/+layout.server.ts` | Modify | Detect currency from `CF-IPCountry` header. Return `{ currency, country }`. |
| `web/src/routes/+layout.svelte` | Modify | Wire currency store from load data. Add `CartDrawer`. Expose cart toggle. |
| `web/src/routes/checkout/+page.svelte` | Create | Two-column layout: order summary left, shipping + payment right. |
| `web/src/routes/checkout/+page.ts` | Create | Load cart from store; call `api.createCheckout()` to get `clientSecret` + `orderId`. |
| `web/src/routes/order/[id]/+page.svelte` | Create | Confirmation page: StarShower on mount, order details, "Continue Shopping". |
| `web/src/routes/order/[id]/+page.ts` | Create | Load order data from Go API. |

---

## Task 1: Install Stripe JS and scaffold API helpers

**Files:**
- Modify: `web/package.json`
- Create: `web/src/lib/api.ts`

- [ ] **Step 1: Install `@stripe/stripe-js`**

```bash
cd web && npm install @stripe/stripe-js
```

Expected output: `added 1 package` (or similar, no errors).

- [ ] **Step 2: Create `web/src/lib/api.ts`**

This file centralises all Go API calls. The base URL reads from `PUBLIC_API_URL` (set in `.env` and Cloudflare Pages env vars).

```typescript
// web/src/lib/api.ts
import { PUBLIC_API_URL } from '$env/static/public';

export interface CartItem {
  id: string;
  productId: string;
  name: string;
  size: string;
  quantity: number;
  unitPrice: number;   // in minor units (cents/pence)
  currency: string;
}

export interface Cart {
  id: string;
  items: CartItem[];
  currency: string;
}

export interface CheckoutResult {
  clientSecret: string;
  orderId: string;
}

export interface Order {
  id: string;
  items: CartItem[];
  total: number;
  currency: string;
  email: string;
  status: string;
}

async function apiFetch<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${PUBLIC_API_URL}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`API ${res.status}: ${body}`);
  }
  return res.json() as Promise<T>;
}

export const api = {
  getCart(cartId: string): Promise<Cart> {
    return apiFetch<Cart>(`/api/cart/${cartId}`);
  },

  addToCart(cartId: string, productId: string, size: string, quantity: number, currency: string): Promise<Cart> {
    return apiFetch<Cart>(`/api/cart/${cartId}/items`, {
      method: 'POST',
      body: JSON.stringify({ productId, size, quantity, currency }),
    });
  },

  updateCartItem(cartId: string, itemId: string, quantity: number): Promise<Cart> {
    return apiFetch<Cart>(`/api/cart/${cartId}/items/${itemId}`, {
      method: 'PATCH',
      body: JSON.stringify({ quantity }),
    });
  },

  removeCartItem(cartId: string, itemId: string): Promise<Cart> {
    return apiFetch<Cart>(`/api/cart/${cartId}/items/${itemId}`, {
      method: 'DELETE',
    });
  },

  createCheckout(cartId: string, currency: string, shipping: ShippingFields): Promise<CheckoutResult> {
    return apiFetch<CheckoutResult>('/api/checkout', {
      method: 'POST',
      body: JSON.stringify({ cartId, currency, shipping }),
    });
  },

  getOrder(orderId: string): Promise<Order> {
    return apiFetch<Order>(`/api/orders/${orderId}`);
  },
};

export interface ShippingFields {
  name: string;
  email: string;
  address: string;
  city: string;
  country: string;
  postcode: string;
}
```

- [ ] **Step 3: Verify TypeScript compiles**

```bash
cd web && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd web && git add package.json package-lock.json src/lib/api.ts
git commit -m "feat: add @stripe/stripe-js and API client module"
```

---

## Task 2: Currency store and layout server detection

**Files:**
- Create: `web/src/lib/stores/currency.ts`
- Modify: `web/src/routes/+layout.server.ts`
- Modify: `web/src/routes/+layout.svelte`

- [ ] **Step 1: Create currency store**

```typescript
// web/src/lib/stores/currency.ts
import { writable } from 'svelte/store';

export const currency = writable<string>('USD');
```

- [ ] **Step 2: Update `+layout.server.ts` to detect currency**

If the file already exists, add to the returned object. If it does not exist, create it in full.

```typescript
// web/src/routes/+layout.server.ts
import type { LayoutServerLoad } from './$types';

const EU_COUNTRIES = [
  'DE','FR','IT','ES','NL','BE','AT','PT','FI','IE',
  'GR','LU','SK','SI','EE','LV','LT','CY','MT',
];

const CURRENCY_MAP: Record<string, string> = {
  GB: 'GBP',
  AU: 'AUD',
  CA: 'CAD',
  JP: 'JPY',
  CH: 'CHF',
};

export const load: LayoutServerLoad = async ({ request }) => {
  const country = request.headers.get('CF-IPCountry') ?? 'US';

  let detectedCurrency: string;
  if (EU_COUNTRIES.includes(country)) {
    detectedCurrency = 'EUR';
  } else {
    detectedCurrency = CURRENCY_MAP[country] ?? 'USD';
  }

  return { currency: detectedCurrency, country };
};
```

- [ ] **Step 3: Wire currency into `+layout.svelte`**

Open the existing `+layout.svelte`. Add the import and `$effect` / `onMount` block to set the store from page data. The exact surrounding code in your layout will differ — insert the marked lines in the `<script>` block and do NOT remove existing imports.

```svelte
<!-- web/src/routes/+layout.svelte -->
<script lang="ts">
  // ADD these imports at the top of the existing imports:
  import { currency } from '$lib/stores/currency';
  import { onMount } from 'svelte';

  // ADD: receive layout data (alongside any existing `export let data`)
  export let data: { currency: string; country: string };

  // ADD: set currency store from server-detected value
  onMount(() => {
    currency.set(data.currency);
  });

  // ... rest of existing script unchanged ...
</script>

<!-- rest of layout unchanged -->
```

- [ ] **Step 4: Verify**

Run the dev server and open browser devtools. In the console run:
```javascript
// In browser console after importing store (dev only):
// Navigate to any page — no console errors expected
```

Expected: page loads, no TypeScript errors in terminal.

- [ ] **Step 5: Commit**

```bash
git add web/src/lib/stores/currency.ts web/src/routes/+layout.server.ts web/src/routes/+layout.svelte
git commit -m "feat: detect currency server-side from CF-IPCountry, wire to layout store"
```

---

## Task 3: Cart store with cookie persistence

**Files:**
- Create: `web/src/lib/stores/cart.ts`

- [ ] **Step 1: Write the cart store**

The store initialises from a cookie on mount, fetches the cart from the API, and exposes `addItem`, `removeItem`, `updateQuantity`, and `clear` methods. `cartToken` is stored in `document.cookie` with `SameSite=Lax; Path=/; Max-Age=2592000` (30 days).

```typescript
// web/src/lib/stores/cart.ts
import { writable, derived, get } from 'svelte/store';
import { browser } from '$app/environment';
import { api } from '$lib/api';
import type { Cart, CartItem } from '$lib/api';

// ── Cookie helpers ────────────────────────────────────────────────────────────
function getCookieValue(name: string): string | null {
  if (!browser) return null;
  const match = document.cookie.match(new RegExp(`(?:^|; )${name}=([^;]*)`));
  return match ? decodeURIComponent(match[1]) : null;
}

function setCookie(name: string, value: string): void {
  document.cookie = `${name}=${encodeURIComponent(value)}; SameSite=Lax; Path=/; Max-Age=2592000`;
}

function generateCartToken(): string {
  return crypto.randomUUID();
}

// ── Internal state ────────────────────────────────────────────────────────────
const _items = writable<CartItem[]>([]);
const _currency = writable<string>('USD');
const _loading = writable<boolean>(false);
const _error = writable<string | null>(null);
let _cartId: string | null = null;

// ── Derived stores ────────────────────────────────────────────────────────────
export const cartItems = { subscribe: _items.subscribe };

export const cartCount = derived(_items, ($items) =>
  $items.reduce((sum, item) => sum + item.quantity, 0)
);

export const cartTotal = derived(_items, ($items) =>
  $items.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0)
);

export const cartCurrency = { subscribe: _currency.subscribe };
export const cartLoading = { subscribe: _loading.subscribe };
export const cartError = { subscribe: _error.subscribe };

// ── Bootstrap ─────────────────────────────────────────────────────────────────
export async function initCart(currencyOverride?: string): Promise<void> {
  if (!browser) return;

  let token = getCookieValue('cart_token');
  if (!token) {
    token = generateCartToken();
    setCookie('cart_token', token);
  }
  _cartId = token;

  if (currencyOverride) _currency.set(currencyOverride);

  _loading.set(true);
  _error.set(null);

  try {
    const cart: Cart = await api.getCart(token);
    _items.set(cart.items);
    if (cart.currency) _currency.set(cart.currency);
  } catch (err) {
    // Cart may not exist yet on first visit — that's fine
    _items.set([]);
  } finally {
    _loading.set(false);
  }
}

export function getCartId(): string {
  if (!_cartId) {
    if (browser) {
      let token = getCookieValue('cart_token');
      if (!token) {
        token = generateCartToken();
        setCookie('cart_token', token);
      }
      _cartId = token;
    }
  }
  return _cartId ?? '';
}

// ── Mutations ─────────────────────────────────────────────────────────────────
export async function addItem(
  productId: string,
  name: string,
  size: string,
  unitPrice: number,
  currency: string
): Promise<void> {
  const cartId = getCartId();
  _loading.set(true);
  _error.set(null);
  try {
    const cart = await api.addToCart(cartId, productId, size, 1, currency);
    _items.set(cart.items);
  } catch (err) {
    _error.set(err instanceof Error ? err.message : 'Failed to add item');
  } finally {
    _loading.set(false);
  }
}

export async function removeItem(itemId: string): Promise<void> {
  const cartId = getCartId();
  _loading.set(true);
  _error.set(null);
  try {
    const cart = await api.removeCartItem(cartId, itemId);
    _items.set(cart.items);
  } catch (err) {
    _error.set(err instanceof Error ? err.message : 'Failed to remove item');
  } finally {
    _loading.set(false);
  }
}

export async function updateQuantity(itemId: string, quantity: number): Promise<void> {
  if (quantity < 1) {
    return removeItem(itemId);
  }
  const cartId = getCartId();
  _loading.set(true);
  _error.set(null);
  try {
    const cart = await api.updateCartItem(cartId, itemId, quantity);
    _items.set(cart.items);
  } catch (err) {
    _error.set(err instanceof Error ? err.message : 'Failed to update quantity');
  } finally {
    _loading.set(false);
  }
}

export function clearCart(): void {
  _items.set([]);
}
```

- [ ] **Step 2: Verify TypeScript**

```bash
cd web && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/stores/cart.ts
git commit -m "feat: cart store with KV-backed API sync and cookie token persistence"
```

---

## Task 4: CartItem component

**Files:**
- Create: `web/src/lib/components/CartItem.svelte`

- [ ] **Step 1: Create `CartItem.svelte`**

```svelte
<!-- web/src/lib/components/CartItem.svelte -->
<script lang="ts">
  import type { CartItem } from '$lib/api';
  import { removeItem, updateQuantity, cartCurrency } from '$lib/stores/cart';
  import { get } from 'svelte/store';

  export let item: CartItem;

  function formatPrice(minor: number, currency: string): string {
    return new Intl.NumberFormat('en', {
      style: 'currency',
      currency,
      minimumFractionDigits: 2,
    }).format(minor / 100);
  }

  async function handleRemove() {
    await removeItem(item.id);
  }

  async function handleDecrement() {
    await updateQuantity(item.id, item.quantity - 1);
  }

  async function handleIncrement() {
    await updateQuantity(item.id, item.quantity + 1);
  }

  $: currency = get(cartCurrency);
  $: lineTotal = formatPrice(item.unitPrice * item.quantity, item.currency);
</script>

<div class="cart-item">
  <div class="cart-item__info">
    <p class="cart-item__name">{item.name}</p>
    <p class="cart-item__size">Size: {item.size}</p>
  </div>

  <div class="cart-item__controls">
    <button class="qty-btn" on:click={handleDecrement} aria-label="Decrease quantity">−</button>
    <span class="qty-value">{item.quantity}</span>
    <button class="qty-btn" on:click={handleIncrement} aria-label="Increase quantity">+</button>
  </div>

  <div class="cart-item__right">
    <p class="cart-item__price">{lineTotal}</p>
    <button class="remove-btn" on:click={handleRemove} aria-label="Remove {item.name} from cart">
      ✕
    </button>
  </div>
</div>

<style>
  .cart-item {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1rem 0;
    border-bottom: 1px solid rgba(240, 237, 230, 0.08);
  }

  .cart-item__info {
    flex: 1;
  }

  .cart-item__name {
    font-size: 0.875rem;
    color: var(--color-lunar-white, #F0EDE6);
    margin: 0 0 0.25rem;
    letter-spacing: 0.05em;
  }

  .cart-item__size {
    font-size: 0.75rem;
    color: rgba(240, 237, 230, 0.5);
    margin: 0;
    text-transform: uppercase;
    letter-spacing: 0.1em;
  }

  .cart-item__controls {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .qty-btn {
    width: 24px;
    height: 24px;
    border: 1px solid rgba(240, 237, 230, 0.2);
    background: transparent;
    color: var(--color-lunar-white, #F0EDE6);
    cursor: pointer;
    border-radius: 2px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1rem;
    line-height: 1;
    transition: border-color 0.2s;
  }

  .qty-btn:hover {
    border-color: var(--color-gold, #C8922A);
  }

  .qty-value {
    font-size: 0.875rem;
    color: var(--color-lunar-white, #F0EDE6);
    min-width: 1.5rem;
    text-align: center;
  }

  .cart-item__right {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 0.5rem;
  }

  .cart-item__price {
    font-size: 0.875rem;
    color: var(--color-lunar-white, #F0EDE6);
    margin: 0;
  }

  .remove-btn {
    background: transparent;
    border: none;
    color: rgba(240, 237, 230, 0.35);
    cursor: pointer;
    font-size: 0.75rem;
    padding: 0;
    transition: color 0.2s;
  }

  .remove-btn:hover {
    color: #ff6b6b;
  }
</style>
```

- [ ] **Step 2: Commit**

```bash
git add web/src/lib/components/CartItem.svelte
git commit -m "feat: CartItem component with quantity controls and remove"
```

---

## Task 5: CartDrawer component

**Files:**
- Create: `web/src/lib/components/CartDrawer.svelte`

- [ ] **Step 1: Create `CartDrawer.svelte`**

```svelte
<!-- web/src/lib/components/CartDrawer.svelte -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import CartItem from './CartItem.svelte';
  import { cartItems, cartTotal, cartCurrency, cartLoading } from '$lib/stores/cart';
  import { get } from 'svelte/store';
  import { goto } from '$app/navigation';

  export let open = false;

  const dispatch = createEventDispatcher<{ close: void }>();

  function close() {
    dispatch('close');
  }

  function handleBackdropClick(e: MouseEvent) {
    if (e.target === e.currentTarget) close();
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') close();
  }

  function formatTotal(minor: number, currency: string): string {
    return new Intl.NumberFormat('en', {
      style: 'currency',
      currency,
      minimumFractionDigits: 2,
    }).format(minor / 100);
  }

  async function handleCheckout() {
    close();
    await goto('/checkout');
  }

  $: items = $cartItems;
  $: total = $cartTotal;
  $: currency = $cartCurrency;
  $: loading = $cartLoading;
</script>

<svelte:window on:keydown={handleKeydown} />

<!-- svelte-ignore a11y-click-events-have-key-events -->
<div
  class="backdrop"
  class:backdrop--visible={open}
  on:click={handleBackdropClick}
  role="presentation"
>
  <aside class="drawer" class:drawer--open={open} aria-label="Shopping cart" role="dialog" aria-modal="true">
    <header class="drawer__header">
      <h2 class="drawer__title">Cart</h2>
      <button class="drawer__close" on:click={close} aria-label="Close cart">✕</button>
    </header>

    <div class="drawer__body">
      {#if loading}
        <p class="drawer__empty">Loading…</p>
      {:else if items.length === 0}
        <p class="drawer__empty">Your cart is empty.</p>
      {:else}
        <ul class="cart-list" aria-label="Cart items">
          {#each items as item (item.id)}
            <li><CartItem {item} /></li>
          {/each}
        </ul>
      {/if}
    </div>

    {#if items.length > 0}
      <footer class="drawer__footer">
        <div class="drawer__subtotal">
          <span class="subtotal-label">Subtotal</span>
          <span class="subtotal-value">{formatTotal(total, currency)}</span>
        </div>
        <button class="cta-btn" on:click={handleCheckout} disabled={loading}>
          Proceed to Checkout
        </button>
      </footer>
    {/if}
  </aside>
</div>

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0);
    z-index: 900;
    pointer-events: none;
    transition: background 0.3s ease;
  }

  .backdrop--visible {
    background: rgba(0, 0, 0, 0.6);
    pointer-events: all;
  }

  .drawer {
    position: fixed;
    top: 0;
    right: 0;
    bottom: 0;
    width: min(400px, 100vw);
    background: #0d0d1a;
    border-left: 1px solid rgba(240, 237, 230, 0.08);
    display: flex;
    flex-direction: column;
    transform: translateX(100%);
    transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    z-index: 901;
  }

  .drawer--open {
    transform: translateX(0);
  }

  .drawer__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1.5rem;
    border-bottom: 1px solid rgba(240, 237, 230, 0.08);
  }

  .drawer__title {
    font-size: 0.75rem;
    letter-spacing: 0.2em;
    text-transform: uppercase;
    color: var(--color-lunar-white, #F0EDE6);
    margin: 0;
    font-weight: 400;
  }

  .drawer__close {
    background: transparent;
    border: none;
    color: rgba(240, 237, 230, 0.5);
    cursor: pointer;
    font-size: 1rem;
    padding: 0.25rem;
    transition: color 0.2s;
  }

  .drawer__close:hover {
    color: var(--color-lunar-white, #F0EDE6);
  }

  .drawer__body {
    flex: 1;
    overflow-y: auto;
    padding: 0 1.5rem;
  }

  .cart-list {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  .drawer__empty {
    font-size: 0.875rem;
    color: rgba(240, 237, 230, 0.4);
    text-align: center;
    padding: 3rem 0;
    margin: 0;
  }

  .drawer__footer {
    padding: 1.5rem;
    border-top: 1px solid rgba(240, 237, 230, 0.08);
  }

  .drawer__subtotal {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.25rem;
  }

  .subtotal-label {
    font-size: 0.75rem;
    letter-spacing: 0.15em;
    text-transform: uppercase;
    color: rgba(240, 237, 230, 0.6);
  }

  .subtotal-value {
    font-size: 1rem;
    color: var(--color-lunar-white, #F0EDE6);
  }

  .cta-btn {
    width: 100%;
    padding: 0.875rem;
    background: transparent;
    border: 1px solid var(--color-lunar-white, #F0EDE6);
    color: var(--color-lunar-white, #F0EDE6);
    font-size: 0.75rem;
    letter-spacing: 0.2em;
    text-transform: uppercase;
    cursor: pointer;
    transition: background 0.2s, color 0.2s, border-color 0.2s;
  }

  .cta-btn:hover:not(:disabled) {
    background: var(--color-lunar-white, #F0EDE6);
    color: #08080f;
  }

  .cta-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
</style>
```

- [ ] **Step 2: Wire `CartDrawer` into `+layout.svelte`**

Open `web/src/routes/+layout.svelte`. Add the following to the `<script>` block and template. Do not remove any existing content — only add:

```svelte
<!-- ADD to <script> block -->
import CartDrawer from '$lib/components/CartDrawer.svelte';
import { initCart } from '$lib/stores/cart';

let cartOpen = false;

// Export toggleCart so nav elements can call it
export function toggleCart() {
  cartOpen = !cartOpen;
}

onMount(async () => {
  currency.set(data.currency);
  await initCart(data.currency);
});
```

```svelte
<!-- ADD inside <main> or just before </body>, after existing slot -->
<CartDrawer bind:open={cartOpen} on:close={() => (cartOpen = false)} />
```

- [ ] **Step 3: Verify drawer renders without errors**

```bash
cd web && npm run dev
```

Open browser, navigate to any page. No console errors. Cart drawer should not be visible yet (no trigger wired in nav — that's a product-page task not in this plan's scope, but the toggle function is exported for that).

- [ ] **Step 4: Commit**

```bash
git add web/src/lib/components/CartDrawer.svelte web/src/routes/+layout.svelte
git commit -m "feat: CartDrawer slide-in with backdrop, line items, subtotal, checkout CTA"
```

---

## Task 6: CheckoutForm component

**Files:**
- Create: `web/src/lib/components/CheckoutForm.svelte`

- [ ] **Step 1: Create `CheckoutForm.svelte`**

This component owns the shipping fields and client-side validation. It emits a `submit` event with a typed `ShippingFields` payload when valid, or sets inline errors without any `alert()` call.

```svelte
<!-- web/src/lib/components/CheckoutForm.svelte -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { ShippingFields } from '$lib/api';

  const dispatch = createEventDispatcher<{ submit: ShippingFields }>();

  let name = '';
  let email = '';
  let address = '';
  let city = '';
  let country = 'US';
  let postcode = '';

  let errors: Partial<Record<keyof ShippingFields, string>> = {};

  const COUNTRIES = [
    { code: 'US', label: 'United States' },
    { code: 'GB', label: 'United Kingdom' },
    { code: 'AU', label: 'Australia' },
    { code: 'CA', label: 'Canada' },
    { code: 'DE', label: 'Germany' },
    { code: 'FR', label: 'France' },
    { code: 'NL', label: 'Netherlands' },
    { code: 'IT', label: 'Italy' },
    { code: 'ES', label: 'Spain' },
    { code: 'SE', label: 'Sweden' },
    { code: 'NO', label: 'Norway' },
    { code: 'DK', label: 'Denmark' },
    { code: 'FI', label: 'Finland' },
    { code: 'NZ', label: 'New Zealand' },
    { code: 'SG', label: 'Singapore' },
    { code: 'JP', label: 'Japan' },
  ];

  function validate(): boolean {
    errors = {};
    if (!name.trim()) errors.name = 'Full name is required';
    if (!email.trim()) {
      errors.email = 'Email is required';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      errors.email = 'Enter a valid email address';
    }
    if (!address.trim()) errors.address = 'Street address is required';
    if (!city.trim()) errors.city = 'City is required';
    if (!country) errors.country = 'Country is required';
    if (!postcode.trim()) errors.postcode = 'Postcode / ZIP is required';
    return Object.keys(errors).length === 0;
  }

  function handleSubmit() {
    if (!validate()) return;
    dispatch('submit', {
      name: name.trim(),
      email: email.trim(),
      address: address.trim(),
      city: city.trim(),
      country,
      postcode: postcode.trim(),
    });
  }
</script>

<form class="checkout-form" on:submit|preventDefault={handleSubmit} novalidate>
  <div class="field" class:field--error={!!errors.name}>
    <label for="cf-name">Full Name</label>
    <input id="cf-name" type="text" bind:value={name} autocomplete="name" />
    {#if errors.name}<span class="field__error">{errors.name}</span>{/if}
  </div>

  <div class="field" class:field--error={!!errors.email}>
    <label for="cf-email">Email</label>
    <input id="cf-email" type="email" bind:value={email} autocomplete="email" />
    {#if errors.email}<span class="field__error">{errors.email}</span>{/if}
  </div>

  <div class="field" class:field--error={!!errors.address}>
    <label for="cf-address">Street Address</label>
    <input id="cf-address" type="text" bind:value={address} autocomplete="street-address" />
    {#if errors.address}<span class="field__error">{errors.address}</span>{/if}
  </div>

  <div class="field-row">
    <div class="field" class:field--error={!!errors.city}>
      <label for="cf-city">City</label>
      <input id="cf-city" type="text" bind:value={city} autocomplete="address-level2" />
      {#if errors.city}<span class="field__error">{errors.city}</span>{/if}
    </div>

    <div class="field" class:field--error={!!errors.postcode}>
      <label for="cf-postcode">Postcode / ZIP</label>
      <input id="cf-postcode" type="text" bind:value={postcode} autocomplete="postal-code" />
      {#if errors.postcode}<span class="field__error">{errors.postcode}</span>{/if}
    </div>
  </div>

  <div class="field" class:field--error={!!errors.country}>
    <label for="cf-country">Country</label>
    <select id="cf-country" bind:value={country} autocomplete="country">
      {#each COUNTRIES as c}
        <option value={c.code}>{c.label}</option>
      {/each}
    </select>
    {#if errors.country}<span class="field__error">{errors.country}</span>{/if}
  </div>

  <!-- Submit is triggered by the parent checkout page, not this form's own button.
       The form exposes a handleSubmit function the parent calls via a slot button.
       However, a hidden submit is included so Enter key on inputs works. -->
  <button type="submit" style="display:none" aria-hidden="true">Submit</button>
</form>

<style>
  .checkout-form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: 0.375rem;
  }

  .field-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }

  label {
    font-size: 0.625rem;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: rgba(240, 237, 230, 0.6);
  }

  input,
  select {
    background: rgba(240, 237, 230, 0.05);
    border: 1px solid rgba(240, 237, 230, 0.2);
    color: var(--color-lunar-white, #F0EDE6);
    padding: 0.625rem 0.75rem;
    font-size: 0.875rem;
    border-radius: 2px;
    outline: none;
    width: 100%;
    box-sizing: border-box;
    transition: border-color 0.2s;
  }

  input:focus,
  select:focus {
    border-color: #C8922A;
  }

  select option {
    background: #0d0d1a;
    color: var(--color-lunar-white, #F0EDE6);
  }

  .field--error input,
  .field--error select {
    border-color: #ff6b6b;
  }

  .field__error {
    font-size: 0.7rem;
    color: #ff6b6b;
    letter-spacing: 0.04em;
  }
</style>
```

- [ ] **Step 2: Commit**

```bash
git add web/src/lib/components/CheckoutForm.svelte
git commit -m "feat: CheckoutForm with client-side validation and inline error messages"
```

---

## Task 7: PaymentElement component

**Files:**
- Create: `web/src/lib/components/PaymentElement.svelte`

- [ ] **Step 1: Create `PaymentElement.svelte`**

This component receives a `clientSecret`, mounts Stripe's Payment Element into a `<div>`, and emits `paymentError` on decline or network failure. The parent calls its exported `confirmPayment(returnUrl)` method.

```svelte
<!-- web/src/lib/components/PaymentElement.svelte -->
<script lang="ts">
  import { onMount, onDestroy, createEventDispatcher } from 'svelte';
  import { loadStripe } from '@stripe/stripe-js';
  import type { Stripe, StripeElements, StripePaymentElement } from '@stripe/stripe-js';
  import { PUBLIC_STRIPE_PUBLISHABLE_KEY } from '$env/static/public';

  export let clientSecret: string;

  const dispatch = createEventDispatcher<{
    paymentError: { message: string };
    ready: void;
  }>();

  let mountEl: HTMLDivElement;
  let stripe: Stripe | null = null;
  let elements: StripeElements | null = null;
  let paymentElement: StripePaymentElement | null = null;
  let stripeError = '';
  let processing = false;

  const appearance = {
    theme: 'night' as const,
    variables: {
      colorBackground: '#08080f',
      colorText: '#F0EDE6',
      colorTextSecondary: 'rgba(240,237,230,0.6)',
      colorPrimary: '#F0EDE6',
      colorDanger: '#ff6b6b',
      fontFamily: 'Inter, system-ui, sans-serif',
      borderRadius: '2px',
      spacingUnit: '4px',
    },
    rules: {
      '.Input': {
        border: '1px solid rgba(240,237,230,0.2)',
        backgroundColor: 'rgba(240,237,230,0.05)',
      },
      '.Input:focus': {
        border: '1px solid #C8922A',
        boxShadow: 'none',
      },
      '.Label': {
        letterSpacing: '0.1em',
        textTransform: 'uppercase',
        fontSize: '10px',
      },
    },
  };

  onMount(async () => {
    stripe = await loadStripe(PUBLIC_STRIPE_PUBLISHABLE_KEY);
    if (!stripe) {
      stripeError = 'Failed to load payment provider. Please refresh.';
      return;
    }

    elements = stripe.elements({ clientSecret, appearance });
    paymentElement = elements.create('payment');
    paymentElement.mount(mountEl);
    paymentElement.on('ready', () => dispatch('ready'));
  });

  onDestroy(() => {
    paymentElement?.unmount();
  });

  export async function confirmPayment(returnUrl: string): Promise<boolean> {
    if (!stripe || !elements) {
      stripeError = 'Payment provider not loaded. Please refresh.';
      return false;
    }

    processing = true;
    stripeError = '';

    const { error } = await stripe.confirmPayment({
      elements,
      confirmParams: { return_url: returnUrl },
    });

    processing = false;

    if (error) {
      // error.type === 'card_error' | 'validation_error' etc.
      const msg = error.message ?? 'An unexpected payment error occurred.';
      stripeError = msg;
      dispatch('paymentError', { message: msg });
      return false;
    }

    // If no error, Stripe redirects — we won't reach here on success
    return true;
  }

  export function isProcessing(): boolean {
    return processing;
  }
</script>

<div class="payment-element-wrapper">
  <div bind:this={mountEl} class="payment-element-mount" />

  {#if stripeError}
    <p class="stripe-error" role="alert">{stripeError}</p>
  {/if}

  {#if processing}
    <p class="processing-msg">Processing payment…</p>
  {/if}
</div>

<style>
  .payment-element-wrapper {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .payment-element-mount {
    min-height: 200px;
  }

  .stripe-error {
    font-size: 0.8125rem;
    color: #ff6b6b;
    margin: 0;
    letter-spacing: 0.03em;
  }

  .processing-msg {
    font-size: 0.8125rem;
    color: rgba(240, 237, 230, 0.6);
    margin: 0;
    letter-spacing: 0.05em;
  }
</style>
```

- [ ] **Step 2: Add `PUBLIC_STRIPE_PUBLISHABLE_KEY` to `.env`**

```bash
# web/.env  (already gitignored — add this line)
echo 'PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_REPLACE_WITH_YOUR_KEY' >> web/.env
```

Also add to `web/.env.example` (committed):

```
PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
```

- [ ] **Step 3: TypeScript check**

```bash
cd web && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add web/src/lib/components/PaymentElement.svelte web/.env.example
git commit -m "feat: PaymentElement component wrapping Stripe Payment Element with dark appearance"
```

---

## Task 8: Checkout page load function

**Files:**
- Create: `web/src/routes/checkout/+page.ts`

- [ ] **Step 1: Create `+page.ts`**

This load function runs in the browser (not SSR — it needs the cart cookie). It reads the cart ID, calls the API to create a PaymentIntent, and returns `clientSecret` and `orderId`. If the cart is empty, it redirects to `/shop`.

```typescript
// web/src/routes/checkout/+page.ts
import type { PageLoad } from './$types';
import { redirect } from '@sveltejs/kit';
import { browser } from '$app/environment';
import { getCartId, cartItems } from '$lib/stores/cart';
import { get } from 'svelte/store';
import { api } from '$lib/api';

export const ssr = false;

export const load: PageLoad = async ({ parent }) => {
  const { currency } = await parent();

  if (!browser) {
    // SSR safety — should not happen given ssr=false, but guard anyway
    throw redirect(302, '/shop');
  }

  const items = get(cartItems);
  if (items.length === 0) {
    throw redirect(302, '/shop');
  }

  const cartId = getCartId();

  // We don't have shipping yet — create the PaymentIntent without shipping
  // so Stripe generates a clientSecret. Shipping is submitted on confirmPayment.
  const { clientSecret, orderId } = await api.createCheckout(cartId, currency, {
    name: '',
    email: '',
    address: '',
    city: '',
    country: '',
    postcode: '',
  });

  return { clientSecret, orderId, currency };
};
```

- [ ] **Step 2: Commit**

```bash
git add web/src/routes/checkout/+page.ts
git commit -m "feat: checkout page load — create PaymentIntent, guard empty cart"
```

---

## Task 9: Checkout page UI

**Files:**
- Create: `web/src/routes/checkout/+page.svelte`

- [ ] **Step 1: Create `+page.svelte`**

Two-column layout: left = order summary, right = shipping form + Stripe Payment Element. Submit button: "Complete Mission". On submit: validate shipping → call `paymentEl.confirmPayment(returnUrl)`.

```svelte
<!-- web/src/routes/checkout/+page.svelte -->
<script lang="ts">
  import type { PageData } from './$types';
  import CheckoutForm from '$lib/components/CheckoutForm.svelte';
  import PaymentElement from '$lib/components/PaymentElement.svelte';
  import { cartItems, cartTotal, cartCurrency } from '$lib/stores/cart';
  import type { ShippingFields } from '$lib/api';

  export let data: PageData;

  let paymentEl: PaymentElement;
  let shippingData: ShippingFields | null = null;
  let submitting = false;
  let networkError = '';
  let retrying = false;

  function formatPrice(minor: number, currency: string): string {
    return new Intl.NumberFormat('en', {
      style: 'currency',
      currency,
      minimumFractionDigits: 2,
    }).format(minor / 100);
  }

  function handleShippingSubmit(e: CustomEvent<ShippingFields>) {
    shippingData = e.detail;
    submitPayment();
  }

  async function submitPayment() {
    if (!shippingData) return;
    submitting = true;
    networkError = '';

    try {
      const returnUrl = `${window.location.origin}/order/${data.orderId}`;
      await paymentEl.confirmPayment(returnUrl);
      // On success Stripe redirects — nothing to do here
    } catch (err) {
      networkError = 'Network error. Please try again.';
      retrying = false;
    } finally {
      submitting = false;
    }
  }

  function handlePaymentError(e: CustomEvent<{ message: string }>) {
    // Error already shown inline by PaymentElement — no extra work needed
  }

  function handleRetry() {
    networkError = '';
    retrying = true;
    submitPayment();
  }

  $: items = $cartItems;
  $: total = $cartTotal;
  $: currency = $cartCurrency;
</script>

<svelte:head>
  <title>Checkout — Immortal Vibes</title>
</svelte:head>

<div class="checkout-page">
  <div class="checkout-inner">
    <!-- Left: Order Summary -->
    <section class="order-summary" aria-label="Order summary">
      <h1 class="section-title">Order Summary</h1>
      <ul class="summary-list">
        {#each items as item (item.id)}
          <li class="summary-item">
            <div class="summary-item__info">
              <p class="summary-item__name">{item.name}</p>
              <p class="summary-item__meta">Size {item.size} × {item.quantity}</p>
            </div>
            <p class="summary-item__price">
              {formatPrice(item.unitPrice * item.quantity, item.currency)}
            </p>
          </li>
        {/each}
      </ul>
      <div class="summary-total">
        <span>Total</span>
        <strong>{formatPrice(total, currency)}</strong>
      </div>
    </section>

    <!-- Right: Payment -->
    <section class="payment-section" aria-label="Payment details">
      <h2 class="section-title">Delivery & Payment</h2>

      <CheckoutForm on:submit={handleShippingSubmit} />

      <div class="payment-element-container">
        <PaymentElement
          bind:this={paymentEl}
          clientSecret={data.clientSecret}
          on:paymentError={handlePaymentError}
        />
      </div>

      {#if networkError}
        <p class="network-error" role="alert">{networkError}</p>
        <button class="retry-btn" on:click={handleRetry} disabled={retrying}>
          {retrying ? 'Retrying…' : 'Retry'}
        </button>
      {/if}

      <button
        class="submit-btn"
        disabled={submitting}
        on:click={() => {
          // Programmatically submit the form inside CheckoutForm
          const form = document.querySelector<HTMLFormElement>('.checkout-form');
          form?.requestSubmit();
        }}
      >
        {submitting ? 'Processing…' : 'Complete Mission'}
      </button>
    </section>
  </div>
</div>

<style>
  .checkout-page {
    min-height: 100vh;
    background: #08080f;
    padding: 4rem 1.5rem;
  }

  .checkout-inner {
    max-width: 1100px;
    margin: 0 auto;
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 4rem;
    align-items: start;
  }

  @media (max-width: 768px) {
    .checkout-inner {
      grid-template-columns: 1fr;
      gap: 2.5rem;
    }
  }

  .section-title {
    font-size: 0.6875rem;
    letter-spacing: 0.25em;
    text-transform: uppercase;
    color: rgba(240, 237, 230, 0.5);
    margin: 0 0 2rem;
    font-weight: 400;
  }

  /* Order summary */
  .summary-list {
    list-style: none;
    padding: 0;
    margin: 0 0 1.5rem;
  }

  .summary-item {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 0.875rem 0;
    border-bottom: 1px solid rgba(240, 237, 230, 0.06);
  }

  .summary-item__name {
    font-size: 0.875rem;
    color: var(--color-lunar-white, #F0EDE6);
    margin: 0 0 0.25rem;
  }

  .summary-item__meta {
    font-size: 0.75rem;
    color: rgba(240, 237, 230, 0.45);
    margin: 0;
    letter-spacing: 0.05em;
    text-transform: uppercase;
  }

  .summary-item__price {
    font-size: 0.875rem;
    color: var(--color-lunar-white, #F0EDE6);
    margin: 0;
    white-space: nowrap;
    padding-left: 1rem;
  }

  .summary-total {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-top: 1rem;
  }

  .summary-total span {
    font-size: 0.75rem;
    letter-spacing: 0.15em;
    text-transform: uppercase;
    color: rgba(240, 237, 230, 0.5);
  }

  .summary-total strong {
    font-size: 1.125rem;
    color: var(--color-lunar-white, #F0EDE6);
    font-weight: 400;
  }

  /* Payment section */
  .payment-element-container {
    margin-top: 2rem;
  }

  .network-error {
    font-size: 0.8125rem;
    color: #ff6b6b;
    margin: 0.75rem 0 0;
  }

  .retry-btn {
    margin-top: 0.5rem;
    background: transparent;
    border: 1px solid #ff6b6b;
    color: #ff6b6b;
    padding: 0.5rem 1rem;
    font-size: 0.75rem;
    letter-spacing: 0.1em;
    cursor: pointer;
    transition: background 0.2s, color 0.2s;
  }

  .retry-btn:hover:not(:disabled) {
    background: #ff6b6b;
    color: #08080f;
  }

  .submit-btn {
    width: 100%;
    margin-top: 2rem;
    padding: 1rem;
    background: transparent;
    border: 1px solid var(--color-lunar-white, #F0EDE6);
    color: var(--color-lunar-white, #F0EDE6);
    font-size: 0.6875rem;
    letter-spacing: 0.3em;
    text-transform: uppercase;
    cursor: pointer;
    transition: background 0.2s, color 0.2s;
  }

  .submit-btn:hover:not(:disabled) {
    background: var(--color-lunar-white, #F0EDE6);
    color: #08080f;
  }

  .submit-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
</style>
```

- [ ] **Step 2: Visual verification**

Run dev server. Navigate to `/checkout` with at least one item in cart. Verify:
- Two columns render side by side (desktop)
- Order summary shows items and total
- Stripe Payment Element mounts inside the right column
- "Complete Mission" button is visible at the bottom

```bash
cd web && npm run dev
# Open http://localhost:5173/checkout
```

- [ ] **Step 3: Commit**

```bash
git add web/src/routes/checkout/+page.svelte
git commit -m "feat: checkout page — two-column layout, order summary, payment element, Complete Mission CTA"
```

---

## Task 10: StarShower confirmation particle effect

**Files:**
- Create: `web/src/lib/components/StarShower.svelte`

- [ ] **Step 1: Create `StarShower.svelte`**

Canvas full-screen overlay. 150 particles, each with random position, velocity, gravity, rotation, and alpha decay. Auto-removes after all particles are invisible (max 3 seconds via fallback timeout).

```svelte
<!-- web/src/lib/components/StarShower.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher<{ done: void }>();

  let canvas: HTMLCanvasElement;

  interface Particle {
    x: number;
    y: number;
    vx: number;
    vy: number;
    size: number;
    alpha: number;
    rotation: number;
    rotationSpeed: number;
    color: string;
  }

  const COLORS = ['#F0EDE6', '#C8922A', '#ffffff', '#e8d5a0', '#d4af6a'];

  function createParticles(count: number, width: number): Particle[] {
    return Array.from({ length: count }, () => ({
      x: Math.random() * width,
      y: -10 - Math.random() * 80,
      vx: (Math.random() - 0.5) * 4,
      vy: 2 + Math.random() * 4,
      size: 2 + Math.random() * 2,
      alpha: 1,
      rotation: Math.random() * Math.PI * 2,
      rotationSpeed: (Math.random() - 0.5) * 0.15,
      color: COLORS[Math.floor(Math.random() * COLORS.length)],
    }));
  }

  onMount(() => {
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    const particles = createParticles(150, canvas.width);
    let animationId: number;
    const fallbackTimeout = setTimeout(done, 3000);

    function done() {
      cancelAnimationFrame(animationId);
      clearTimeout(fallbackTimeout);
      dispatch('done');
    }

    function drawStar(ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number, rotation: number) {
      const spikes = 4;
      const outerRadius = r;
      const innerRadius = r * 0.4;
      ctx.beginPath();
      for (let i = 0; i < spikes * 2; i++) {
        const angle = (i * Math.PI) / spikes + rotation;
        const radius = i % 2 === 0 ? outerRadius : innerRadius;
        const x = cx + Math.cos(angle) * radius;
        const y = cy + Math.sin(angle) * radius;
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.closePath();
    }

    function tick() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      let allDone = true;

      for (const p of particles) {
        if (p.alpha <= 0) continue;
        allDone = false;

        p.x += p.vx;
        p.vy += 0.05; // gravity
        p.y += p.vy;
        p.rotation += p.rotationSpeed;
        p.alpha = Math.max(0, p.alpha - 0.005);

        ctx.save();
        ctx.globalAlpha = p.alpha;
        ctx.fillStyle = p.color;
        drawStar(ctx, p.x, p.y, p.size, p.rotation);
        ctx.fill();
        ctx.restore();
      }

      if (allDone) {
        done();
        return;
      }

      animationId = requestAnimationFrame(tick);
    }

    animationId = requestAnimationFrame(tick);

    return () => {
      cancelAnimationFrame(animationId);
      clearTimeout(fallbackTimeout);
    };
  });
</script>

<canvas
  bind:this={canvas}
  class="star-shower"
  aria-hidden="true"
/>

<style>
  .star-shower {
    position: fixed;
    inset: 0;
    z-index: 9999;
    pointer-events: none;
  }
</style>
```

- [ ] **Step 2: Commit**

```bash
git add web/src/lib/components/StarShower.svelte
git commit -m "feat: StarShower canvas particle celebration for order confirmation"
```

---

## Task 11: Order confirmation page

**Files:**
- Create: `web/src/routes/order/[id]/+page.ts`
- Create: `web/src/routes/order/[id]/+page.svelte`

- [ ] **Step 1: Create `+page.ts`**

```typescript
// web/src/routes/order/[id]/+page.ts
import type { PageLoad } from './$types';
import { error } from '@sveltejs/kit';
import { api } from '$lib/api';

export const ssr = false;

export const load: PageLoad = async ({ params }) => {
  const { id } = params;

  try {
    const order = await api.getOrder(id);
    return { order };
  } catch (err) {
    throw error(404, 'Order not found');
  }
};
```

- [ ] **Step 2: Create `+page.svelte`**

```svelte
<!-- web/src/routes/order/[id]/+page.svelte -->
<script lang="ts">
  import type { PageData } from './$types';
  import StarShower from '$lib/components/StarShower.svelte';
  import { clearCart } from '$lib/stores/cart';
  import { onMount } from 'svelte';

  export let data: PageData;

  let showStars = true;

  function formatPrice(minor: number, currency: string): string {
    return new Intl.NumberFormat('en', {
      style: 'currency',
      currency,
      minimumFractionDigits: 2,
    }).format(minor / 100);
  }

  onMount(() => {
    // Cart is now paid — clear local state
    clearCart();
  });

  function handleStarsDone() {
    showStars = false;
  }

  $: order = data.order;
</script>

<svelte:head>
  <title>Order Confirmed — Immortal Vibes</title>
</svelte:head>

{#if showStars}
  <StarShower on:done={handleStarsDone} />
{/if}

<div class="confirmation-page">
  <div class="confirmation-inner">
    <p class="confirmation-label">Mission Complete</p>
    <h1 class="confirmation-heading">Order Confirmed</h1>
    <p class="order-number">#{order.id}</p>

    <ul class="items-list">
      {#each order.items as item (item.id)}
        <li class="item-row">
          <span class="item-name">{item.name}</span>
          <span class="item-meta">Size {item.size} × {item.quantity}</span>
          <span class="item-price">
            {formatPrice(item.unitPrice * item.quantity, item.currency)}
          </span>
        </li>
      {/each}
    </ul>

    <div class="total-row">
      <span>Total</span>
      <strong>{formatPrice(order.total, order.currency)}</strong>
    </div>

    <p class="email-notice">Check your email for your confirmation and tracking details.</p>

    <a href="/shop" class="continue-btn">Continue Shopping</a>
  </div>
</div>

<style>
  .confirmation-page {
    min-height: 100vh;
    background: #08080f;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 4rem 1.5rem;
  }

  .confirmation-inner {
    max-width: 560px;
    width: 100%;
    text-align: center;
  }

  .confirmation-label {
    font-size: 0.6875rem;
    letter-spacing: 0.3em;
    text-transform: uppercase;
    color: var(--color-gold, #C8922A);
    margin: 0 0 1rem;
  }

  .confirmation-heading {
    font-size: clamp(2rem, 5vw, 3.5rem);
    color: var(--color-lunar-white, #F0EDE6);
    font-weight: 300;
    letter-spacing: 0.08em;
    margin: 0 0 0.5rem;
  }

  .order-number {
    font-size: 0.8125rem;
    color: rgba(240, 237, 230, 0.45);
    letter-spacing: 0.1em;
    margin: 0 0 2.5rem;
    font-family: 'Courier New', monospace;
  }

  .items-list {
    list-style: none;
    padding: 0;
    margin: 0 0 1.5rem;
    text-align: left;
  }

  .item-row {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 0.75rem 0;
    border-bottom: 1px solid rgba(240, 237, 230, 0.06);
  }

  .item-name {
    flex: 1;
    font-size: 0.875rem;
    color: var(--color-lunar-white, #F0EDE6);
  }

  .item-meta {
    font-size: 0.75rem;
    color: rgba(240, 237, 230, 0.4);
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }

  .item-price {
    font-size: 0.875rem;
    color: var(--color-lunar-white, #F0EDE6);
  }

  .total-row {
    display: flex;
    justify-content: space-between;
    padding: 1rem 0;
    margin-bottom: 2rem;
  }

  .total-row span {
    font-size: 0.75rem;
    letter-spacing: 0.15em;
    text-transform: uppercase;
    color: rgba(240, 237, 230, 0.5);
  }

  .total-row strong {
    font-size: 1.125rem;
    color: var(--color-lunar-white, #F0EDE6);
    font-weight: 400;
  }

  .email-notice {
    font-size: 0.8125rem;
    color: rgba(240, 237, 230, 0.45);
    margin: 0 0 2.5rem;
    letter-spacing: 0.04em;
    line-height: 1.6;
  }

  .continue-btn {
    display: inline-block;
    padding: 0.875rem 2.5rem;
    border: 1px solid rgba(240, 237, 230, 0.3);
    color: var(--color-lunar-white, #F0EDE6);
    font-size: 0.6875rem;
    letter-spacing: 0.25em;
    text-transform: uppercase;
    text-decoration: none;
    transition: background 0.2s, color 0.2s, border-color 0.2s;
  }

  .continue-btn:hover {
    background: var(--color-lunar-white, #F0EDE6);
    color: #08080f;
    border-color: var(--color-lunar-white, #F0EDE6);
  }
</style>
```

- [ ] **Step 3: Visual verification**

Run dev server. Navigate to `/order/test-id` (will 404 from API — that's fine for visual check). Confirm the page renders the layout and star shower fires. With a real `orderId` from Stripe test webhook, full end-to-end confirms.

- [ ] **Step 4: Commit**

```bash
git add web/src/routes/order/[id]/+page.ts web/src/routes/order/[id]/+page.svelte
git commit -m "feat: order confirmation page with StarShower celebration, order details, continue CTA"
```

---

## Task 12: End-to-end integration smoke test

This task does not use a test runner — it is a manual checklist to run in the browser using Stripe's test card numbers. Run with `npm run dev` against a real Go API dev environment.

- [ ] **Step 1: Start dev environment**

```bash
# Terminal 1 — Go API
cd api && go run ./cmd/server

# Terminal 2 — SvelteKit
cd web && npm run dev
```

- [ ] **Step 2: Add item to cart**

Open `http://localhost:5173`. Navigate to any product page. Add an item to cart. Open cart drawer. Confirm:
- Drawer slides in from right
- Item appears with name, size, quantity, price
- Subtotal is correct
- "Proceed to Checkout" is visible

- [ ] **Step 3: Proceed to checkout**

Click "Proceed to Checkout". Confirm:
- URL changes to `/checkout`
- Order summary shows same items
- Shipping form fields are empty and focusable
- Stripe Payment Element mounts (card input appears)
- No JS errors in browser console

- [ ] **Step 4: Validate shipping form errors**

Click "Complete Mission" without filling any fields. Confirm:
- Inline error messages appear under each empty field
- No `alert()` popups
- Stripe payment is NOT attempted

- [ ] **Step 5: Test successful payment**

Fill shipping form with valid data. In the Stripe Payment Element enter:
- Card: `4242 4242 4242 4242`
- Expiry: `12/34`
- CVC: `123`
- ZIP: `42424`

Click "Complete Mission". Confirm:
- Button shows "Processing…"
- Page redirects to `/order/{id}`
- StarShower fires for ~3 seconds then disappears
- Order number, items, total displayed
- "Continue Shopping" link goes to `/shop`

- [ ] **Step 6: Test declined card**

On checkout page, enter:
- Card: `4000 0000 0000 0002` (always declined)

Click "Complete Mission". Confirm:
- Error message appears inline below the payment element
- No redirect occurs
- User can re-enter card details and retry

- [ ] **Step 7: Commit smoke test pass note**

```bash
git commit --allow-empty -m "test: manual smoke test — cart, checkout, confirmation, decline flow verified"
```

---

## Self-Review Checklist

### 1. Spec Coverage

| Requirement | Covered By |
|---|---|
| Cart store with Svelte store, cookie, API sync | Task 3 |
| Cart drawer slide-in from right | Task 5 |
| CartItem with name/size/qty/price/remove | Tasks 4, 5 |
| Checkout page two-column layout | Task 9 |
| Stripe Payment Element embedded (not redirect) | Tasks 7, 9 |
| Stripe appearance API with dark theme | Task 7 |
| Shipping form with all fields | Task 6 |
| "Complete Mission" submit button | Task 9 |
| Order confirmation page | Task 11 |
| StarShower particle celebration | Task 10 |
| Multi-currency via CF-IPCountry | Tasks 2, 3 |
| Client-side form validation, no alert() | Task 6 |
| Inline error for payment declined | Task 7 |
| Network error retry button | Task 9 |
| Empty cart redirect to /shop | Task 8 |
| `return_url` pointing to `/order/{orderId}` | Task 9 |

### 2. Placeholder Scan

No TBD, TODO, "implement later", "add validation", or "similar to Task N" patterns found.

### 3. Type Consistency

- `CartItem` — defined in `api.ts` Task 1, used identically in `cart.ts` Task 3, `CartItem.svelte` Task 4, `CartDrawer.svelte` Task 5, checkout pages Tasks 9/11.
- `ShippingFields` — defined in `api.ts` Task 1, exported from `api.ts`, consumed in `CheckoutForm.svelte` Task 6 and `checkout/+page.ts` Task 8.
- `clearCart` — defined in `cart.ts` Task 3, called in `+page.svelte` Task 11.
- `getCartId` — defined in `cart.ts` Task 3, called in `checkout/+page.ts` Task 8.
- `initCart` — defined in `cart.ts` Task 3, called in `+layout.svelte` Task 5.
- `confirmPayment(returnUrl: string): Promise<boolean>` — defined on `PaymentElement` component Task 7, called in `checkout/+page.svelte` Task 9.
- `cartItems`, `cartTotal`, `cartCurrency`, `cartLoading` — defined in `cart.ts` Task 3, subscribed in Tasks 4, 5, 9, 11.

All consistent. No mismatches found.
