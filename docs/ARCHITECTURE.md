# ARCHITECTURE — DealFlow Perspectives

Vive-documentación del monolito `index.html` (6,646 líneas, 242 KB en disco, commit `f0c68a5`).
Todo el sitio es un único archivo: HTML + CSS inline + JS inline, servido estáticamente desde GitHub Pages vía el dominio `dealflowperspectives.com` (CNAME en `/CNAME`). DNS por Cloudflare. Backend por Supabase (REST vía `@supabase/supabase-js` UMD bundle, cargado por CDN).

> Las referencias `index.html:Lxxxx` apuntan al commit actual; si edit es el archivo, los rangos se corren.

---

## 1. Layout macro del archivo

| Bloque | Rango | Notas |
|---|---|---|
| `<head>` + meta + favicons | L1–L10 | Carga `favicon-192x192.png` (L7–L9) |
| `<style>` bloque único | L11–L2460 | 2,450 líneas de CSS inline. Sin preprocesador, sin critical-CSS split |
| `</style>` cierre | L2460 | |
| `<body>` abierto (implícito) | L2461–L2466 | |
| `<nav class="navbar">` | L2470–L2548 | Navbar sticky con dropdowns. **`#navBrandText` con default literal "Guest v1.0"** en L2473 |
| `<main class="main-content">` | L2553–L3007 | Contiene las 7 secciones SPA |
| Modales (auth, demo request, expired/survey) | L3010–L3193 | Overlays posicionados fuera de `<main>` |
| Footer | L3288 | |
| `<script>` externos (CDNs) | L3295–L3299 | Supabase, anime.js, three.js, topojson, d3 |
| `<script>` IIFE inline | L3300–L6644 | 3,344 líneas de JS que pilotean todo |
| `</body></html>` | L6645–L6646 | |

### Dependencias externas (CDN)

- `@supabase/supabase-js@2` (UMD) — **L3295** — cliente auth + REST
- `anime.js 3.2.2` — **L3296** — usado opcionalmente por las animaciones de stats del home (se invoca condicionalmente; no rompe si falta)
- `three.js r128` — **L3297** — globo 3D de heatmap
- `topojson-client@3` — **L3298** — parseo del atlas mundial para el 3D globe y el 2D map
- `d3@7.8.5` — **L3299** — projection helpers para el mapa 2D Mercator

Ninguno está pinneado vía SRI; un downtime del CDN tumba secciones completas.

---

## 2. Secciones HTML dentro de `<main>`

Todas son `<section class="section">` con un `id` ligado al `data-section` de la navbar. SPA por hide/show con clase `.active` (ver `navigateTo` en **L4302**).

| Sección | `id` | Rango HTML | Supabase tables | Render JS |
|---|---|---|---|---|
| Home / Landing | `home` | L2556–L2660 | (ninguna directa) | stats contador via `updateHomeStats`, `initHomeScroll` |
| Dashboard | `dashboard` | L2663–L2727 | `deals`, `user_preferences` | `renderKPIs`, `renderCategoryBreakdown`, `renderCountryGrid`, `renderTopDeals`, `renderWatchlist` |
| Deal Database | `database` | L2731–L2769 | `deals` (indirecto vía `allDeals` cache) | `applyFiltersAndSort`, `renderTable`, `renderPagination` |
| Players | `players` | L2772–L2823 | `players` | `loadPlayers` → `initPlayers` — lazy |
| PE Funds | `pefunds` | L2826–L2927 | `pe_funds` | `loadPEFunds` → `initPEFunds` — lazy |
| Heatmap (3D / 2D) | `heatmap` | L2930–L2961 | `deals` (reutiliza `allDeals`) | `initGlobe` (three.js), `init2DMap` (d3 + topojson) |
| Markets | `markets` | L2964–L2981 | `user_preferences` (favoritos) | `initMarkets` — lazy, TradingView widgets |
| Category Drilldown | `categoryDrilldown` | L2984–L3005 | (reusa `allDeals`) | inyectado por `showCategoryDrilldown` |

Además hay una sección oculta `#home` como viewport de scroll distinto, y las secciones Home/Heatmap/Markets tienen renderizado condicional por `currentUser` (gate de "Request demo access").

---

## 3. Modales y overlays (fuera de `<main>`)

| Modal | `id` | Rango | Disparadores |
|---|---|---|---|
| Auth (sign in / sign up) | `loginModal` | L3012–L3065 | botón `#btnSignIn` (L2542), `initAuth` (L3478) |
| Request Demo | `requestDemoModal` | L3067–L3130 | `#btnRequestDemo` (L2539) y todos los auth-gates dentro de secciones |
| Expired / Survey | `expiredOverlay` + `surveyThankYou` | L3132–L3193 | `_updateNavBrand` cuando `access.status === 'expired'` (L3453–L3456) |
| Deal detail | `dealModal` | L3195–L3239 | click en row de `database` |
| Player detail (Bloomberg-DES-style) | `playerModal` | L3241–L3283 | click en row de `players` |
| Country deals modal | `countryDealsModal` | L3257–L3283 | click en país del 2D/3D map |

---

## 4. Arquitectura del `<script>` inline (L3300–L6644)

IIFE `(function () { 'use strict'; ... })()`. Sin `DOMContentLoaded` wrapper — corre sincrónicamente al parsear el `<script>`, que está al final de `<body>`, por lo que el DOM ya existe. **No hay manejo de errores top-level: si cualquier `querySelector` devuelve `null` antes de `initAuth()` (L6380), el IIFE entero se rompe y ningún listener queda registrado.**

### Bloques funcionales

| Bloque | Rango | Propósito |
|---|---|---|
| SUPABASE CLIENT | **L3307–L3341** | `createClient` con `SUPABASE_URL` y `SUPABASE_ANON_KEY` hardcoded (L3310–L3312). `clearSupabaseStorage()` (L3314–L3324) fue el fix defensivo añadido. `renderAuthGate` (L3326) y `rateLimitCheck` (L3333) |
| DEMO ACCESS | **L3343–L3402** | `checkDemoAccess(user)` (L3346–L3378) — consulta `admin_accounts` y `demo_requests` |
| SECURITY UTILITIES | **L3404–L3412** | `sanitizeInput` (XSS escaping via textNode) |
| AUTH | **L3414–L3671** | Estado global (`currentUser`, `isAdmin`, `demoExpiresAt`, `demoStatus`), `_updateNavBrand` (L3430), `_initAuth` (L3478) con listeners de `onAuthStateChange`, sign in, sign up, logout |
| NEWSLETTER | **L3673–L3687** | Form stub — TODO marcado en L3683 |
| `initHomeScroll`, `animateHomeCounters`, `updateHomeStats` | L3689–L3808 | Parallax del watermark, counters animados |
| CONSTANTS & STATE | **L3809–L3840** | Globales: `allDeals`, `allPlayers`, `allFunds`, flags `playersLoaded`, `pefLoaded`, `marketsLoaded` |
| DOM REFS | **L3841–L3846** | Shorthand `$` y `$$` |
| UTILITIES | **L3847–L3906** | Helpers de formateo (`fmtUSD`, `fmtCompact`, etc.) |
| DATA LOADING (Supabase) | **L3907–L3952** | `loadData()` — carga `deals`, gate por `auth.getUser()`. Dispara `init()` |
| INIT | **L3954–L3970** | Orquesta el render inicial |
| DASHBOARD — KPIs / Category / Country / Top Deals | L3971–L4101 | |
| DATABASE — Filtros / Tabla / Paginación | L4103–L4240 | |
| DEAL DETAIL MODAL | L4242–L4297 | |
| NAVIGATION | **L4299–L4437** | `navigateTo(sectionId)` — SPA switcher, lazy-loads players/pefunds/markets, y renderiza auth-gates para secciones protegidas |
| EVENT BINDINGS | L4439–L4536 | |
| CATEGORY DRILLDOWN | L4538–L4589 | |
| 3D GLOBE HEATMAP | **L4591–L4924** | three.js globo con puntos por país |
| DASHBOARD — RESIZABLE PANELS | L4926–L4972 | `localStorage` para layout del dashboard, sync a `user_preferences` |
| 2D MAP (Mercator d3) | L4974–L5141 | |
| HEATMAP — 2D/3D Toggle | L5143–L5176 | |
| COUNTRY DEALS MODAL | L5178–L5226 | |
| PLAYERS SECTION | **L5228–L5435** | `loadPlayers`, filtros, tabla |
| PLAYER MODAL (Bloomberg DES) | L5437–L5539 | |
| PE FUNDS SECTION | **L5541–L6094** | `loadPEFunds`, charts canvas, tabs (All / Top-quartile / ...) |
| MARKETS (TradingView + Favoritos) | **L6096–L6337** | `initMarkets`, `getFavorites`, `addFavorite`, sync a `user_preferences` |
| BOOT | **L6339–L6643** | Entry point — listeners del navbar, `initAuth()`, modales, `getSession().then` |

---

## 5. Flujo de render

### En page load (síncrono, sin `DOMContentLoaded`)

1. L3310 — `supabase` cliente se inicializa.
2. L6343 — click listener en `#navBrandLink`.
3. L6349–L6373 — listeners del navbar (secciones, dropdowns).
4. L6376 — listener del mobile toggle.
5. L6380 — **`initAuth()`** → registra `onAuthStateChange` (L3522) y llama `_updateNavBrand()` (L3669) *sin await* — el navbar queda en estado transitorio mientras la promesa resuelve.
6. L6381–L6384 — `initNewsletter`, `initHomeScroll`, `initHeatmapToggle`, `renderWatchlist`.
7. L6386–L6405 — listeners modales + anti-DevTools.
8. L6445 — `initScrollReveal`.
9. L6456 — `updateHomeStats` (counters del home).
10. L6496–L6630 — binds del request-demo-form y survey.
11. L6633–L6642 — **`supabase.auth.getSession().then(...)`** — si hay sesión: setea `currentUser`, dispara `_updateNavBrand()` y `loadPreferencesFromSupabase()`; en todo caso dispara `loadData()`.

### Paralelismo en arranque → 3 caminos que escriben `navBrandText`

Con una sesión válida ya en `localStorage`, se disparan **tres** llamadas concurrentes a `_updateNavBrand()`:

- (a) L3669 — dentro de `_initAuth`, sincrónica, sin espera de sesión.
- (b) L3523 — por `onAuthStateChange` con evento `INITIAL_SESSION` (Supabase JS v2 lo emite al hidratar).
- (c) L6636 — dentro del `.then` de `getSession()`.

Las tres disparan `supabase.auth.getUser()` + `checkDemoAccess()`. La última en resolver gana; y cada una puede throw silenciosamente. Esta es la raíz probable del bug TRON (ver `TRON_BUG_NOTES.md`).

### Lazy vs eager

| Data / feature | Cuándo se carga |
|---|---|
| `deals` → `allDeals` | Eager: en `loadData()` al boot (si hay sesión) |
| `players` → `allPlayers` | Lazy: al entrar a la sección `players` (`loadPlayers` en L5260) |
| `pe_funds` → `allFunds` | Lazy: al entrar a la sección `pefunds` (`loadPEFunds` en L5563) |
| 3D globe (three.js scene) | Lazy: primera visita a `heatmap` (L4336 con `setTimeout 50ms`) |
| 2D map (d3 + topojson) | Lazy: al togglear a 2D en heatmap |
| Markets widgets (TradingView) | Lazy: primera visita a `markets` (L4419) |
| `user_preferences` | Después de `SIGNED_IN` (L3530) o en `getSession().then` (L6637) |

### Rate-limits cliente

`rateLimitCheck(key, cooldownMs)` en **L3334** — simple gate de timestamps por key. Aplicado en `loadData` (2000ms, L3911), `loadPlayers` (L5262), `loadPEFunds` (L5565). Útil para prevenir re-disparos durante navegación rápida.

---

## 6. Ausencias notables

- **No hay build step** ni transpilación. Navegadores modernos únicamente; ES2017+.
- **No hay CSP**. Cualquier inline-script inyectado sería ejecutable.
- **No hay SRI** en los `<script src="https://cdn...">` (L3295–L3299).
- **No hay service worker / offline fallback.**
- **`SUPABASE_ANON_KEY` hardcoded** en el cliente (L3311). Es por diseño (es "anon", pública), pero combinado con RLS permisivo sobre `blocked_email_domains` (INSERT/SELECT público en `demo_requests`) abre superficie de abuso.
- **Anti-DevTools (L6392–L6405)** — bloquea F12 y Ctrl+Shift+I en producción. Security-by-obscurity; cualquier usuario con proxy ve los datos.
- **`data/` está vacío**. El seeder (`supabase/seed.js`) lee de `data/deals.json`, `players.json`, `pe-funds.json` — que viven en la carpeta local (ver `LOCAL_FOLDER_AUDIT.md`), no en el repo.
