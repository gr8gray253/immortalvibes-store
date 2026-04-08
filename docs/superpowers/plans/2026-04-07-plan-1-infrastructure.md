# Infrastructure & Go API Skeleton — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a production-ready Go API on Fly.io, shielded by a Cloudflare Worker, with R2 and KV configured — enough infrastructure that Plans 2–5 can build on without touching config again.

**Architecture:** Go API (chi router) runs on Fly.io and accepts only requests carrying a shared proxy secret header. A Cloudflare Worker sits in front, injects the secret, and forwards traffic. R2 holds product images; two KV namespaces hold cart and session state.

**Tech Stack:** Go 1.22 · chi v5 · Fly.io · Cloudflare Worker (TypeScript) · Wrangler CLI · Cloudflare R2 · Cloudflare KV

---

## File Structure

```
immortalvibes/
├── api/                          # Go backend — all server code lives here
│   ├── main.go                   # Entry point, wires server together
│   ├── router.go                 # Route registration
│   ├── config/
│   │   └── config.go             # Env var loading with validation
│   ├── handlers/
│   │   └── health.go             # GET /health
│   ├── middleware/
│   │   ├── auth.go               # Validates X-Proxy-Secret header
│   │   └── cors.go               # CORS headers for CF Pages origin
│   ├── Dockerfile                # Multi-stage build for Fly.io
│   └── fly.toml                  # Fly.io app config
├── worker/                       # Cloudflare Worker shield
│   ├── src/
│   │   └── index.ts              # Proxy + rate limit logic
│   ├── wrangler.toml             # Worker config, KV + R2 bindings
│   └── package.json
└── .gitignore
```

---

## Task 1: Initialize Go project

**Files:**
- Create: `api/main.go`
- Create: `api/router.go`
- Create: `api/handlers/health.go`
- Create: `api/handlers/health_test.go`

- [ ] **Step 1: Create the Go module**

```bash
cd C:/Users/EricG/Desktop/immortalvibes
mkdir -p api
cd api
go mod init github.com/immortalvibes/api
go get github.com/go-chi/chi/v5
go get github.com/go-chi/chi/v5/middleware
```

Expected: `go.mod` and `go.sum` created in `api/`.

- [ ] **Step 2: Write the failing health handler test**

Create `api/handlers/health_test.go`:

```go
package handlers_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/immortalvibes/api/handlers"
)

func TestHealthHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()

	handlers.Health(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var body map[string]string
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatalf("could not decode response body: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("expected status=ok, got %q", body["status"])
	}
}
```

- [ ] **Step 3: Run test — verify it fails**

```bash
cd api
go test ./handlers/...
```

Expected: `FAIL — cannot find package "github.com/immortalvibes/api/handlers"`

- [ ] **Step 4: Write the health handler**

Create `api/handlers/health.go`:

```go
package handlers

import (
	"encoding/json"
	"net/http"
)

func Health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}
```

- [ ] **Step 5: Run test — verify it passes**

```bash
cd api
go test ./handlers/... -v
```

Expected:
```
--- PASS: TestHealthHandler (0.00s)
PASS
ok  	github.com/immortalvibes/api/handlers
```

- [ ] **Step 6: Write router**

Create `api/router.go`:

```go
package main

import (
	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/immortalvibes/api/handlers"
)

func newRouter() *chi.Mux {
	r := chi.NewRouter()
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Get("/health", handlers.Health)
	return r
}
```

- [ ] **Step 7: Write main.go**

Create `api/main.go`:

```go
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	r := newRouter()
	addr := fmt.Sprintf(":%s", port)
	log.Printf("server listening on %s", addr)
	if err := http.ListenAndServe(addr, r); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
```

- [ ] **Step 8: Run the server locally and verify**

```bash
cd api
go run .
```

In a separate terminal:
```bash
curl http://localhost:8080/health
```

Expected: `{"status":"ok"}`

Stop the server (Ctrl+C).

- [ ] **Step 9: Commit**

```bash
cd C:/Users/EricG/Desktop/immortalvibes
git init
git add api/
git commit -m "feat: go api skeleton with health endpoint"
```

---

## Task 2: Config loading

**Files:**
- Create: `api/config/config.go`
- Create: `api/config/config_test.go`
- Modify: `api/main.go`

- [ ] **Step 1: Write the failing config test**

Create `api/config/config_test.go`:

```go
package config_test

import (
	"os"
	"testing"

	"github.com/immortalvibes/api/config"
)

func TestLoad_defaults(t *testing.T) {
	os.Unsetenv("PORT")
	os.Unsetenv("PROXY_SECRET")
	os.Unsetenv("STRIPE_SECRET_KEY")
	os.Unsetenv("STRIPE_WEBHOOK_SECRET")
	os.Unsetenv("ADMIN_SECRET")

	cfg, err := config.Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.Port != "8080" {
		t.Errorf("expected default port 8080, got %q", cfg.Port)
	}
}

func TestLoad_missingRequired(t *testing.T) {
	os.Setenv("PORT", "8080")
	os.Unsetenv("PROXY_SECRET")

	_, err := config.Load()
	if err == nil {
		t.Fatal("expected error for missing PROXY_SECRET, got nil")
	}
}

func TestLoad_allSet(t *testing.T) {
	os.Setenv("PORT", "9090")
	os.Setenv("PROXY_SECRET", "test-secret")
	os.Setenv("STRIPE_SECRET_KEY", "sk_test_123")
	os.Setenv("STRIPE_WEBHOOK_SECRET", "whsec_123")
	os.Setenv("ADMIN_SECRET", "admin-secret")
	defer func() {
		os.Unsetenv("PORT")
		os.Unsetenv("PROXY_SECRET")
		os.Unsetenv("STRIPE_SECRET_KEY")
		os.Unsetenv("STRIPE_WEBHOOK_SECRET")
		os.Unsetenv("ADMIN_SECRET")
	}()

	cfg, err := config.Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.Port != "9090" {
		t.Errorf("expected port 9090, got %q", cfg.Port)
	}
	if cfg.ProxySecret != "test-secret" {
		t.Errorf("expected proxy secret, got %q", cfg.ProxySecret)
	}
}
```

- [ ] **Step 2: Run test — verify it fails**

```bash
cd api
go test ./config/...
```

Expected: `FAIL — cannot find package`

- [ ] **Step 3: Write config.go**

Create `api/config/config.go`:

```go
package config

import (
	"errors"
	"os"
)

type Config struct {
	Port                string
	ProxySecret         string
	StripeSecretKey     string
	StripeWebhookSecret string
	AdminSecret         string
}

func Load() (*Config, error) {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	proxySecret := os.Getenv("PROXY_SECRET")
	if proxySecret == "" {
		return nil, errors.New("PROXY_SECRET is required")
	}

	return &Config{
		Port:                port,
		ProxySecret:         proxySecret,
		StripeSecretKey:     os.Getenv("STRIPE_SECRET_KEY"),
		StripeWebhookSecret: os.Getenv("STRIPE_WEBHOOK_SECRET"),
		AdminSecret:         os.Getenv("ADMIN_SECRET"),
	}, nil
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
cd api
go test ./config/... -v
```

Expected: all three tests PASS.

- [ ] **Step 5: Wire config into main.go**

Replace `api/main.go` with:

```go
package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/immortalvibes/api/config"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config error: %v", err)
	}

	r := newRouter(cfg)
	addr := fmt.Sprintf(":%s", cfg.Port)
	log.Printf("server listening on %s", addr)
	if err := http.ListenAndServe(addr, r); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
```

- [ ] **Step 6: Update router to accept config**

Replace `api/router.go` with:

```go
package main

import (
	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/immortalvibes/api/config"
	"github.com/immortalvibes/api/handlers"
)

func newRouter(cfg *config.Config) *chi.Mux {
	r := chi.NewRouter()
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Get("/health", handlers.Health)
	return r
}
```

- [ ] **Step 7: Verify it compiles**

```bash
cd api
PROXY_SECRET=test go build .
```

Expected: no output (success). Delete the compiled binary: `rm api` (or `api.exe` on Windows).

- [ ] **Step 8: Commit**

```bash
cd C:/Users/EricG/Desktop/immortalvibes
git add api/
git commit -m "feat: environment config loading with validation"
```

---

## Task 3: Proxy secret middleware

**Files:**
- Create: `api/middleware/auth.go`
- Create: `api/middleware/auth_test.go`
- Modify: `api/router.go`

- [ ] **Step 1: Write failing middleware tests**

Create `api/middleware/auth_test.go`:

```go
package middleware_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/immortalvibes/api/middleware"
)

func okHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func TestProxyAuth_missingHeader(t *testing.T) {
	handler := middleware.ProxyAuth("correct-secret")(http.HandlerFunc(okHandler))
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d", w.Code)
	}
}

func TestProxyAuth_wrongSecret(t *testing.T) {
	handler := middleware.ProxyAuth("correct-secret")(http.HandlerFunc(okHandler))
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("X-Proxy-Secret", "wrong-secret")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d", w.Code)
	}
}

func TestProxyAuth_correctSecret(t *testing.T) {
	handler := middleware.ProxyAuth("correct-secret")(http.HandlerFunc(okHandler))
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("X-Proxy-Secret", "correct-secret")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestProxyAuth_healthBypassesAuth(t *testing.T) {
	handler := middleware.ProxyAuth("correct-secret")(http.HandlerFunc(okHandler))
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	// no secret header
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("/health should bypass auth, got %d", w.Code)
	}
}
```

- [ ] **Step 2: Run test — verify it fails**

```bash
cd api
go test ./middleware/...
```

Expected: `FAIL — cannot find package`

- [ ] **Step 3: Write auth middleware**

Create `api/middleware/auth.go`:

```go
package middleware

import (
	"crypto/subtle"
	"net/http"
)

// ProxyAuth validates the X-Proxy-Secret header injected by the CF Worker.
// /health is exempt so Fly.io health checks work without the secret.
func ProxyAuth(secret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path == "/health" {
				next.ServeHTTP(w, r)
				return
			}

			got := r.Header.Get("X-Proxy-Secret")
			if subtle.ConstantTimeCompare([]byte(got), []byte(secret)) != 1 {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
cd api
go test ./middleware/... -v
```

Expected: all four tests PASS.

- [ ] **Step 5: Wire middleware into router**

Replace `api/router.go` with:

```go
package main

import (
	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/immortalvibes/api/config"
	"github.com/immortalvibes/api/handlers"
	"github.com/immortalvibes/api/middleware"
)

func newRouter(cfg *config.Config) *chi.Mux {
	r := chi.NewRouter()
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Use(middleware.ProxyAuth(cfg.ProxySecret))
	r.Get("/health", handlers.Health)
	return r
}
```

- [ ] **Step 6: Verify full test suite passes**

```bash
cd api
go test ./... -v
```

Expected: all tests across handlers, config, middleware PASS.

- [ ] **Step 7: Commit**

```bash
cd C:/Users/EricG/Desktop/immortalvibes
git add api/
git commit -m "feat: proxy secret middleware — blocks requests without X-Proxy-Secret"
```

---

## Task 4: CORS middleware

**Files:**
- Create: `api/middleware/cors.go`
- Create: `api/middleware/cors_test.go`
- Modify: `api/router.go`

- [ ] **Step 1: Write failing CORS tests**

Create `api/middleware/cors_test.go`:

```go
package middleware_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/immortalvibes/api/middleware"
)

func TestCORS_setsHeaders(t *testing.T) {
	handler := middleware.CORS("https://theimmortalvibes.com")(http.HandlerFunc(okHandler))
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Origin", "https://theimmortalvibes.com")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	got := w.Header().Get("Access-Control-Allow-Origin")
	if got != "https://theimmortalvibes.com" {
		t.Errorf("expected CORS origin header, got %q", got)
	}
}

func TestCORS_preflight(t *testing.T) {
	handler := middleware.CORS("https://theimmortalvibes.com")(http.HandlerFunc(okHandler))
	req := httptest.NewRequest(http.MethodOptions, "/api/products", nil)
	req.Header.Set("Origin", "https://theimmortalvibes.com")
	req.Header.Set("Access-Control-Request-Method", "GET")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected 204 for preflight, got %d", w.Code)
	}
}

func TestCORS_unknownOriginBlocked(t *testing.T) {
	handler := middleware.CORS("https://theimmortalvibes.com")(http.HandlerFunc(okHandler))
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Origin", "https://evil.com")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	got := w.Header().Get("Access-Control-Allow-Origin")
	if got == "https://evil.com" {
		t.Error("should not allow unknown origin")
	}
}
```

- [ ] **Step 2: Run test — verify it fails**

```bash
cd api
go test ./middleware/... -run TestCORS
```

Expected: FAIL — `undefined: middleware.CORS`

- [ ] **Step 3: Write CORS middleware**

Create `api/middleware/cors.go`:

```go
package middleware

import (
	"net/http"
)

// CORS allows requests from the given origin (CF Pages URL).
// During local dev, also allows localhost origins.
func CORS(allowedOrigin string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")

			allowed := origin == allowedOrigin ||
				origin == "http://localhost:5173" ||
				origin == "http://localhost:4173"

			if allowed {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
				w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
				w.Header().Set("Access-Control-Allow-Credentials", "true")
			}

			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
cd api
go test ./middleware/... -v
```

Expected: all CORS and ProxyAuth tests PASS.

- [ ] **Step 5: Wire CORS into router**

Replace `api/router.go` with:

```go
package main

import (
	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/immortalvibes/api/config"
	"github.com/immortalvibes/api/handlers"
	"github.com/immortalvibes/api/middleware"
)

func newRouter(cfg *config.Config) *chi.Mux {
	r := chi.NewRouter()
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Use(middleware.CORS("https://theimmortalvibes.com"))
	r.Use(middleware.ProxyAuth(cfg.ProxySecret))
	r.Get("/health", handlers.Health)
	return r
}
```

- [ ] **Step 6: Run full test suite**

```bash
cd api
go test ./... -v
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
cd C:/Users/EricG/Desktop/immortalvibes
git add api/
git commit -m "feat: cors middleware — allows CF Pages and localhost origins"
```

---

## Task 5: Dockerfile + Fly.io deploy

**Files:**
- Create: `api/Dockerfile`
- Create: `api/fly.toml`
- Create: `api/.env.example`

- [ ] **Step 1: Install Fly CLI (if not already installed)**

```bash
# Windows (PowerShell)
pwsh -Command "iwr https://fly.io/install.ps1 -useb | iex"

# Verify
fly version
```

Expected: `fly v0.x.x`

- [ ] **Step 2: Create Dockerfile**

Create `api/Dockerfile`:

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o server .

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /root/
COPY --from=builder /app/server .
EXPOSE 8080
CMD ["./server"]
```

- [ ] **Step 3: Build and verify Docker image locally**

```bash
cd api
docker build -t immortalvibes-api .
docker run --rm -e PROXY_SECRET=test -p 8080:8080 immortalvibes-api &
sleep 2
curl http://localhost:8080/health
```

Expected: `{"status":"ok"}`

Stop the container: `docker stop $(docker ps -q --filter ancestor=immortalvibes-api)`

- [ ] **Step 4: Create fly.toml**

Create `api/fly.toml`:

```toml
app = "immortalvibes-api"
primary_region = "iad"

[build]
  dockerfile = "Dockerfile"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0

  [[http_service.checks]]
    grace_period = "10s"
    interval = "30s"
    method = "GET"
    path = "/health"
    timeout = "5s"

[vm]
  memory = "256mb"
  cpu_kind = "shared"
  cpus = 1
```

- [ ] **Step 5: Create .env.example**

Create `api/.env.example`:

```
PORT=8080
PROXY_SECRET=generate-a-long-random-string
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
ADMIN_SECRET=generate-a-long-random-string
```

- [ ] **Step 6: Launch app on Fly.io**

```bash
cd api
fly auth login
fly launch --name immortalvibes-api --region iad --no-deploy
```

When prompted "Would you like to copy your existing configuration?" → **Yes**.
When prompted "Would you like to set up a Postgresql database?" → **No**.
When prompted "Would you like to set up an Upstash Redis?" → **No**.

- [ ] **Step 7: Set secrets on Fly.io**

Generate a secure proxy secret first:
```bash
openssl rand -hex 32
```

Copy the output, then:
```bash
fly secrets set PROXY_SECRET=<output-from-above> --app immortalvibes-api
fly secrets set ADMIN_SECRET=$(openssl rand -hex 32) --app immortalvibes-api
```

Note: `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` will be set in Plan 2.

- [ ] **Step 8: Deploy to Fly.io**

```bash
cd api
fly deploy
```

Expected output ends with: `✓ Machine xxxxxxxx [app] update finished`

- [ ] **Step 9: Verify health endpoint on Fly.io**

```bash
curl https://immortalvibes-api.fly.dev/health
```

Expected: `{"status":"ok"}`

- [ ] **Step 10: Verify proxy auth blocks direct requests**

```bash
curl https://immortalvibes-api.fly.dev/api/products
```

Expected: `403 forbidden` (no X-Proxy-Secret header)

- [ ] **Step 11: Add .gitignore**

Create `.gitignore` at project root:

```gitignore
# Go
api/*.exe
api/server
api/.env

# Node / Worker
worker/node_modules/
worker/.wrangler/
worker/dist/

# SvelteKit (Plan 3)
web/node_modules/
web/.svelte-kit/
web/build/

# Brainstorm artifacts
.superpowers/

# OS
.DS_Store
Thumbs.db
```

- [ ] **Step 12: Commit**

```bash
cd C:/Users/EricG/Desktop/immortalvibes
git add api/Dockerfile api/fly.toml api/.env.example .gitignore
git commit -m "feat: dockerfile and fly.io deployment — api live at immortalvibes-api.fly.dev"
```

---

## Task 6: Cloudflare Worker shield

**Files:**
- Create: `worker/package.json`
- Create: `worker/wrangler.toml`
- Create: `worker/src/index.ts`
- Create: `worker/tsconfig.json`

- [ ] **Step 1: Install Wrangler CLI**

```bash
npm install -g wrangler
wrangler --version
```

Expected: `wrangler 3.x.x`

- [ ] **Step 2: Authenticate with Cloudflare**

```bash
wrangler login
```

This opens a browser. Log in and authorize.

- [ ] **Step 3: Create worker package.json**

Create `worker/package.json`:

```json
{
  "name": "immortalvibes-worker",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.0.0",
    "typescript": "^5.0.0",
    "wrangler": "^3.0.0"
  }
}
```

- [ ] **Step 4: Create tsconfig.json**

Create `worker/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2021",
    "lib": ["ES2021"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "types": ["@cloudflare/workers-types"],
    "strict": true,
    "noEmit": true
  },
  "include": ["src/**/*.ts"]
}
```

- [ ] **Step 5: Install worker dependencies**

```bash
cd worker
npm install
```

- [ ] **Step 6: Create wrangler.toml**

Create `worker/wrangler.toml`:

```toml
name = "immortalvibes-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[vars]
GO_API_URL = "https://immortalvibes-api.fly.dev"

# KV namespaces added in Task 8 after creation
# [[kv_namespaces]]
# binding = "CARTS"
# id = "..."

# [[kv_namespaces]]
# binding = "SESSIONS"
# id = "..."
```

- [ ] **Step 7: Write the worker**

Create `worker/src/index.ts`:

```typescript
export interface Env {
  GO_API_URL: string;
  PROXY_SECRET: string;
  RATE_LIMIT_KV: KVNamespace;
}

const RATE_LIMIT_WINDOW_MS = 60_000; // 1 minute
const RATE_LIMIT_MAX = 60;           // 60 requests per minute per IP

async function isRateLimited(kv: KVNamespace, ip: string): Promise<boolean> {
  const key = `ratelimit:${ip}`;
  const raw = await kv.get(key);
  const count = raw ? parseInt(raw, 10) : 0;

  if (count >= RATE_LIMIT_MAX) return true;

  // Increment — TTL resets the window
  await kv.put(key, String(count + 1), { expirationTtl: 60 });
  return false;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Health check on the worker itself — no forwarding needed
    if (url.pathname === "/worker-health") {
      return new Response(JSON.stringify({ status: "ok" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Rate limiting — skip for health checks
    if (url.pathname !== "/health" && env.RATE_LIMIT_KV) {
      const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
      const limited = await isRateLimited(env.RATE_LIMIT_KV, ip);
      if (limited) {
        return new Response("Too Many Requests", { status: 429 });
      }
    }

    // Forward to Go API with proxy secret injected
    const targetUrl = `${env.GO_API_URL}${url.pathname}${url.search}`;
    const headers = new Headers(request.headers);
    headers.set("X-Proxy-Secret", env.PROXY_SECRET);

    const response = await fetch(targetUrl, {
      method: request.method,
      headers,
      body: request.method !== "GET" && request.method !== "HEAD"
        ? request.body
        : undefined,
    });

    return response;
  },
};
```

- [ ] **Step 8: Set PROXY_SECRET on the worker**

Use the same value you set on Fly.io in Task 5:

```bash
cd worker
wrangler secret put PROXY_SECRET
```

Paste the same secret value when prompted.

- [ ] **Step 9: Deploy the worker**

```bash
cd worker
wrangler deploy
```

Expected output: `Published immortalvibes-worker (x.xx sec)`

Note the worker URL shown — it will be `https://immortalvibes-worker.<your-subdomain>.workers.dev`

- [ ] **Step 10: Test worker forwards correctly**

```bash
# Health through worker (no secret needed — /health bypasses auth)
curl https://immortalvibes-worker.<your-subdomain>.workers.dev/health
```

Expected: `{"status":"ok"}`

```bash
# API route through worker (Worker injects secret — should not get 403)
curl https://immortalvibes-worker.<your-subdomain>.workers.dev/api/products
```

Expected: `404` (route not implemented yet) — NOT `403`. 403 means the secret injection failed.

- [ ] **Step 11: Commit**

```bash
cd C:/Users/EricG/Desktop/immortalvibes
git add worker/
git commit -m "feat: cloudflare worker shield — rate limiting and proxy secret injection"
```

---

## Task 7: Cloudflare R2 bucket

**Files:**
- Modify: `worker/wrangler.toml`

- [ ] **Step 1: Create the R2 bucket**

```bash
cd worker
wrangler r2 bucket create immortalvibes-images
```

Expected: `Created bucket 'immortalvibes-images'`

- [ ] **Step 2: Enable public access on the bucket**

In the Cloudflare dashboard:
1. Go to **R2** → **immortalvibes-images** → **Settings**
2. Under **Public access**, click **Allow Access**
3. Copy the public URL — format: `https://pub-<hash>.r2.dev`

Save this URL — it will go into the Go API config in Plan 2 as `R2_PUBLIC_URL`.

- [ ] **Step 3: Add R2 binding to wrangler.toml**

Add to `worker/wrangler.toml`:

```toml
[[r2_buckets]]
binding = "IMAGES"
bucket_name = "immortalvibes-images"
```

- [ ] **Step 4: Test uploading an image**

```bash
# Upload a test file
echo "test" > test.txt
wrangler r2 object put immortalvibes-images/test.txt --file test.txt

# Verify it's accessible via public URL
curl https://pub-<hash>.r2.dev/test.txt
```

Expected: `test`

Clean up: `wrangler r2 object delete immortalvibes-images/test.txt`

- [ ] **Step 5: Re-deploy worker with R2 binding**

```bash
cd worker
wrangler deploy
```

- [ ] **Step 6: Commit**

```bash
cd C:/Users/EricG/Desktop/immortalvibes
git add worker/wrangler.toml
git commit -m "feat: r2 bucket for product images with public access"
```

---

## Task 8: Cloudflare KV namespaces

**Files:**
- Modify: `worker/wrangler.toml`

- [ ] **Step 1: Create CARTS KV namespace**

```bash
cd worker
wrangler kv namespace create CARTS
```

Expected output includes: `id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"`

Copy the `id` value.

- [ ] **Step 2: Create SESSIONS KV namespace**

```bash
wrangler kv namespace create SESSIONS
```

Copy the `id` value.

- [ ] **Step 3: Create RATE_LIMIT_KV namespace**

```bash
wrangler kv namespace create RATE_LIMIT_KV
```

Copy the `id` value.

- [ ] **Step 4: Add all three namespaces to wrangler.toml**

Replace the commented-out KV section in `worker/wrangler.toml` with (use your actual IDs):

```toml
[[kv_namespaces]]
binding = "CARTS"
id = "<carts-namespace-id>"

[[kv_namespaces]]
binding = "SESSIONS"
id = "<sessions-namespace-id>"

[[kv_namespaces]]
binding = "RATE_LIMIT_KV"
id = "<rate-limit-namespace-id>"
```

- [ ] **Step 5: Update worker Env interface**

Update `worker/src/index.ts` — the `Env` interface already has `RATE_LIMIT_KV`. Add CARTS and SESSIONS so they're available for future plans:

```typescript
export interface Env {
  GO_API_URL: string;
  PROXY_SECRET: string;
  RATE_LIMIT_KV: KVNamespace;
  CARTS: KVNamespace;
  SESSIONS: KVNamespace;
}
```

- [ ] **Step 6: Test KV read/write through wrangler**

```bash
wrangler kv key put --namespace-id=<carts-namespace-id> "test-key" "test-value"
wrangler kv key get --namespace-id=<carts-namespace-id> "test-key"
```

Expected: `test-value`

Clean up: `wrangler kv key delete --namespace-id=<carts-namespace-id> "test-key"`

- [ ] **Step 7: Re-deploy worker**

```bash
cd worker
wrangler deploy
```

- [ ] **Step 8: Set KV namespace IDs as env vars for Go**

These IDs will be needed by the Go API in Plan 2 to read/write KV via the Cloudflare API. Store them as Fly secrets now:

```bash
fly secrets set CF_ACCOUNT_ID=<your-cloudflare-account-id> --app immortalvibes-api
fly secrets set CF_KV_CARTS_ID=<carts-namespace-id> --app immortalvibes-api
fly secrets set CF_KV_SESSIONS_ID=<sessions-namespace-id> --app immortalvibes-api
fly secrets set CF_API_TOKEN=<cloudflare-api-token> --app immortalvibes-api
```

To get your CF Account ID: Cloudflare dashboard → right sidebar on any page.
To create a CF API Token: **My Profile** → **API Tokens** → **Create Token** → **Edit Cloudflare Workers** template, add KV permissions.

- [ ] **Step 9: Commit**

```bash
cd C:/Users/EricG/Desktop/immortalvibes
git add worker/wrangler.toml worker/src/index.ts
git commit -m "feat: cloudflare kv namespaces for carts, sessions, and rate limiting"
```

---

## Task 9: Connect custom domain + final verification

**Files:** No code changes — Cloudflare dashboard configuration.

- [ ] **Step 1: Add custom route to worker**

In Cloudflare dashboard:
1. Go to **Workers & Pages** → **immortalvibes-worker** → **Settings** → **Triggers**
2. Add route: `theimmortalvibes.com/api/*` → worker
3. Also add: `www.theimmortalvibes.com/api/*` → worker

Or via wrangler — add to `worker/wrangler.toml`:

```toml
routes = [
  { pattern = "theimmortalvibes.com/api/*", zone_name = "theimmortalvibes.com" },
  { pattern = "www.theimmortalvibes.com/api/*", zone_name = "theimmortalvibes.com" }
]
```

Then redeploy: `wrangler deploy`

- [ ] **Step 2: End-to-end security verification**

```bash
# 1. Direct hit to Go — should fail (no secret)
curl https://immortalvibes-api.fly.dev/api/products
# Expected: 403 forbidden

# 2. Through Worker — should NOT get 403 (Worker injects secret)
curl https://immortalvibes-worker.<subdomain>.workers.dev/health
# Expected: {"status":"ok"}

# 3. Wrong secret directly — should fail
curl -H "X-Proxy-Secret: wrong" https://immortalvibes-api.fly.dev/api/products
# Expected: 403 forbidden
```

- [ ] **Step 3: Run full Go test suite one final time**

```bash
cd api
go test ./... -v
```

Expected: all tests PASS.

- [ ] **Step 4: Final commit**

```bash
cd C:/Users/EricG/Desktop/immortalvibes
git add worker/wrangler.toml
git commit -m "feat: worker routes wired to custom domain — infrastructure complete"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered by |
|---|---|
| Go on Fly.io | Task 5 |
| CF Worker shield | Task 6 |
| Rate limiting | Task 6 (KV-backed rate limiter) |
| Go API only accepts CF traffic | Tasks 3 + 6 (proxy secret) |
| R2 for product images | Task 7 |
| KV for cart + session state | Task 8 |
| CF-IPCountry header available | Automatic — CF passes it; Go reads it in Plan 2 |
| Multi-currency (Stripe) | Plan 2 |
| Product management (Stripe) | Plan 2 |
| SvelteKit frontend | Plan 3 |

**Placeholder scan:** No TBDs, no "implement later", no vague steps. All code is complete.

**Type consistency:** `Config` struct defined in Task 2 used correctly in Tasks 3–5. `Env` interface in Worker extended in Task 8 without breaking Task 6 logic.

**One gap fixed:** `RATE_LIMIT_KV` binding was referenced in the worker code (Task 6) before the KV namespace was created (Task 8). The worker code guards against a missing binding with `if env.RATE_LIMIT_KV` — this is intentional and handles the window between deploy and KV setup correctly.
