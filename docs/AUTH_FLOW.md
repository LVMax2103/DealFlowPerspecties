# AUTH_FLOW — DealFlow Perspectives

Documento crítico. Traza todo el camino: login → sesión → role resolution → navbar update. Todos los pointers tienen line number exacto en `index.html`.

---

## 1. Estado global del módulo de auth

Declarado en **L3417–L3420**:

```js
let currentUser = null;
let isAdmin = false;
let demoExpiresAt = null;   // (escrito pero nunca leído — dead var)
let demoStatus = null;
```

Y un array `ADMIN_EMAILS = ['elenesmaximiliano@gmail.com']` en **L3423**.

> ⚠️ `ADMIN_EMAILS` está declarado pero **nunca se lee en todo el archivo**. La única fuente de verdad para `isAdmin` es la tabla Supabase `admin_accounts` (ver L3351).

---

## 2. Default HTML del navbar — dónde vive "Guest v1.0"

**L2473**:

```html
<span id="navBrandText">Guest v1.0</span>
```

Es el estado **inicial estático** antes de que corra JS. Si `_updateNavBrand()` nunca completa, el usuario ve este texto para siempre. El JS **nunca escribe el string "Guest v1.0"** — el único string literal equivalente está en **L3468**:

```js
brandText.textContent = 'DFP · Pre-MVP Demo';  // usado cuando user === null
```

**→ Conclusión clave**: ver "Guest v1.0" implica que `_updateNavBrand()` nunca alcanzó una rama que escriba `textContent`. No es un estado que produzca la lógica; es el default crudo del HTML.

---

## 3. Flujo paso a paso — login exitoso

### 3.1. Entrada — click en "Sign In" (L2542)

`#btnSignIn` click listener en **L3545–L3548** → abre `#loginModal`.

### 3.2. Submit del sign-in form (L3558–L3598)

```js
var { data, error } = await supabase.auth.signInWithPassword({ email, password });
```

Si error incluye `"Invalid"` o `"expired"`, se dispara `clearSupabaseStorage()` (L3574) y se reintenta una vez (L3576–L3580). Este es el fix defensivo reciente. En éxito, el comentario **L3597** dice: `"Success handled by onAuthStateChange"`.

### 3.3. `onAuthStateChange` listener (L3522–L3543)

```js
supabase.auth.onAuthStateChange(async function(event, session) {
  _updateNavBrand();                              // L3523 — siempre
  if (event === 'SIGNED_IN') {
    loginModal.classList.remove('open');
    signInForm.reset();
    ...
    loadData();                                   // L3529
    if (typeof loadPreferencesFromSupabase === 'function')
      loadPreferencesFromSupabase();              // L3530
    renderWatchlist();                            // L3531
    var access = await checkDemoAccess(session.user);  // L3533
    if (access.status === 'expired') {
      showExpiredOverlay();                       // L3535
    }
  }
  if (event === 'SIGNED_OUT') {
    currentUser = null;                           // L3539
    localStorage.removeItem(FAVORITES_KEY);       // L3540
    localStorage.removeItem(getDashboardLayoutKey());  // L3541
  }
});
```

### 3.4. `_updateNavBrand` (L3430–L3475) — punto crítico

```js
async function _updateNavBrand() {
  var brandText = document.getElementById('navBrandText');    // L3431
  var btnSignIn = document.getElementById('btnSignIn');
  var navLogout = document.getElementById('navLogout');
  var navRequestDemo = document.getElementById('navRequestDemo');
  var user = await getUser();                                 // L3435 — NETWORK CALL
  currentUser = user;                                          // L3436

  if (user) {
    var access = await checkDemoAccess(user);                 // L3439 — 2 queries
    isAdmin = access.isAdmin;
    demoStatus = access.status;

    if (access.isAdmin) {                                     // L3443
      brandText.textContent = access.codename + ' · ' + access.role;  // ← "TRON · developer"
      removeDemoBar();
      hideExpiredOverlay();
    } else if (access.status === 'active') {                  // L3447
      ...
      brandText.textContent = sanitizeInput(displayName);
      showDemoBar(access.daysLeft);
    } else if (access.status === 'expired') {                 // L3453
      brandText.textContent = 'Demo Expired';
      showExpiredOverlay();
    } else {                                                  // L3457
      brandText.textContent = sanitizeInput(dn);              // displayName o email
    }

    btnSignIn.style.display = 'none';
    navLogout.style.display = '';
  } else {
    brandText.textContent = 'DFP · Pre-MVP Demo';             // L3468
    btnSignIn.style.display = '';
    navLogout.style.display = 'none';
  }
}
```

**No tiene `try / catch`. Cualquier throw en `getUser()` o `checkDemoAccess()` deja el navbar en el estado HTML inicial `"Guest v1.0"`.**

### 3.5. `getUser` (L3425–L3428)

```js
async function getUser() {
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}
```

`supabase.auth.getUser()` en la v2 del cliente **hace network call** a `/auth/v1/user` con el access_token actual. Si el token expiró, intenta refresh vía refresh_token. Si el refresh_token también falla, devuelve `{ user: null, error }` **sin throw** por default. Sin embargo, el destructuring `const { data: { user } } = ...` asume que `data` existe — si la promesa se rechaza (no solo retorna error), **propaga el throw**.

### 3.6. `checkDemoAccess` (L3346–L3378)

```js
async function checkDemoAccess(user) {
  if (!user) return { status: 'none', isAdmin: false };

  var { data: adminData } = await supabase
    .from('admin_accounts')
    .select('codename, role')
    .eq('email', user.email)
    .maybeSingle();                               // L3354

  if (adminData) {
    return { status: 'admin', isAdmin: true, codename: adminData.codename, role: adminData.role };
  }

  var { data: demoData } = await supabase
    .from('demo_requests')
    .select('status, expires_at, approved_at')
    .eq('email', user.email)
    .maybeSingle();

  if (!demoData) return { status: 'none', isAdmin: false };
  if (demoData.status === 'approved' && demoData.expires_at) { ... }
  return { status: demoData.status, isAdmin: false };
}
```

**Comportamiento silencioso**: si `admin_accounts` falla por RLS (401/403), `{ data: null, error: {...} }` → el destructuring descarta el error → `adminData = null` → cae a la rama `demo_requests`. Si TRON no está en `demo_requests` (lo esperado — está en `admin_accounts`), retorna `{ status: 'none', isAdmin: false }` → `_updateNavBrand` entra al else de L3457 y escribe `user.email` o `first_name+last_name` — **NO "Guest v1.0"**.

---

## 4. Tres puntos de escritura de localStorage/sessionStorage relacionados con auth

### 4.1. Escrituras (auto por Supabase JS)

Supabase JS v2 guarda el token de sesión en `localStorage` con la key `sb-hmrtcvxcdgcuvbmvpetd-auth-token` (derivada del project ref `hmrtcvxcdgcuvbmvpetd`, L3310). Esto es automático cuando `supabase.auth.signInWithPassword` tiene éxito.

### 4.2. Lecturas / limpieza manuales

| Línea | Acción |
|---|---|
| L3314–L3324 | `clearSupabaseStorage()` — borra todas las keys con prefijo `sb-` en `localStorage` **y** `sessionStorage` |
| L3540 | En `SIGNED_OUT`: `localStorage.removeItem(FAVORITES_KEY)` (`'dfp_market_favorites'`) |
| L3541 | En `SIGNED_OUT`: `localStorage.removeItem(getDashboardLayoutKey())` (`'dfp_dashboard_layout'`) |
| L3574 | Si el sign-in falla con `Invalid`/`expired`, limpia y reintenta una vez |
| L3665 | En logout: `clearSupabaseStorage()` después del `signOut()` |

### 4.3. Otros usos de storage (no auth pero tocan flujo autenticado)

| Línea | Key / uso |
|---|---|
| L4943, L4949 | `dfp_dashboard_layout` — layout de paneles del dashboard |
| L6100, L6127, L6135, L6208 | `FAVORITES_KEY = 'dfp_market_favorites'` — favoritos del Markets section |

---

## 5. Consultas a `admin_accounts` — único lugar

Solo hay **un** lookup a `admin_accounts` en todo el archivo: **L3350–L3354**, dentro de `checkDemoAccess`. Se invoca en:

- **L3439** — `_updateNavBrand` (3 disparos posibles al boot; ver ARCHITECTURE.md §5)
- **L3533** — dentro del listener `onAuthStateChange` cuando `event === 'SIGNED_IN'`, para redundancia de `showExpiredOverlay`

Si esta query devuelve error (RLS, red, CORS, timeout), se descarta silenciosamente y la app trata al usuario como no-admin.

---

## 6. Todos los puntos donde se dispara `_updateNavBrand`

| Sitio | Línea | Contexto |
|---|---|---|
| Dentro de `_initAuth` | **L3523** | handler de `onAuthStateChange` — dispara por SIGNED_IN, SIGNED_OUT, TOKEN_REFRESHED, USER_UPDATED, INITIAL_SESSION |
| Final de `_initAuth` | **L3669** | sincrónico al arrancar `initAuth()`, sin await |
| Dentro del `.then` de `getSession()` | **L6636** | al resolver la sesión hidratada desde localStorage |

**Los tres corren en paralelo al arrancar** con una sesión válida. No hay sincronización; la última en completar gana. Sin `try / catch` en ninguna.

---

## 7. Race conditions — inventario

### R1 — Carrera de escritura de `navBrandText` (tres writers)

Los tres disparos (§6) ejecutan en orden no determinista. Ninguno lee el estado previo. No hay `AbortController`, no hay versionado (`brand_token`), no hay `Promise.race` con el último wins. **Si el último en completar falla (throw), los dos anteriores podrían haber escrito correctamente "TRON · developer" y ese último throw no lo revierte — el navbar permanece correcto.** Pero si los tres fallan, el HTML `"Guest v1.0"` queda.

### R2 — `_updateNavBrand` → `getUser` antes de hidratar sesión

`initAuth` dispara `_updateNavBrand()` (L3669) síncronamente. Supabase JS puede no haber terminado de leer `localStorage` en ese preciso microtick (el cliente corre ciclos de validación en promesas internas). Si `getUser` devuelve `null` en ese momento aunque haya sesión válida en disco, se escribe "DFP · Pre-MVP Demo" hasta que (b) o (c) lo sobrescriban. Este no produce "Guest v1.0" por sí solo.

### R3 — Token corrupto / firmado con proyecto viejo

Si el `localStorage` tiene un token con `iss` o `aud` de un Supabase anterior (cambió `SUPABASE_URL` entre deploys), `supabase.auth.getUser()` en la v2 puede **throw** en lugar de retornar `{ user: null }`. Como `_updateNavBrand` no tiene try/catch, se traga el throw, deja el HTML default "Guest v1.0", y el SIGN_IN event reemplaza el token — pero si el usuario venía con estado previo válido, el listener NO dispara SIGNED_IN al cargar (solo dispara INITIAL_SESSION), y el navbar queda roto hasta refrescar en modo incógnito o limpiar manualmente.

### R4 — `clearSupabaseStorage` corre solo en "Invalid/expired" path del login

El fix defensivo solo limpia storage en la rama **error de login** (L3573–L3574). **No limpia en boot si detecta un token malformed**. Por eso el fix no resuelve la raíz — al abrir en ventana normal, el bug ya ocurrió antes de cualquier login (porque hay sesión previa).

### R5 — `loadData` llama a `getUser` de nuevo (L3914)

En el `.then` del boot (L6639, L6641), `loadData()` también llama `supabase.auth.getUser()`. Si esto throw, se captura en el `catch` de `loadData` (L3948) y muestra empty-state — no afecta navbar directamente, pero puede dejar el dashboard en estado inconsistente.

---

## 8. Dónde aparece literal la string "Guest v1.0"

```
index.html:L2473   <span id="navBrandText">Guest v1.0</span>
```

**Una sola aparición**, en el HTML estático. Ningún JS la escribe. La única forma de mostrarla es que `_updateNavBrand` nunca alcance `brandText.textContent = ...` en ninguno de sus tres disparos, O que el navbar renderice antes de que el `<script>` inline llegue a ejecutar (imposible dado que el script es síncrono al final del body, a menos que el script entero crashee antes de `initAuth()`).

---

## 9. Checklist de puntos de falla en la cadena login → TRON · developer

1. **Click "Sign In"** → modal abre (L3545). ✅ No falla.
2. **`signInWithPassword`** → éxito vía Supabase (L3568). ✅ (si las credenciales son correctas).
3. **`onAuthStateChange` event=SIGNED_IN** → dispara `_updateNavBrand()` sin await (L3523). ⚠️ Sin error handling.
4. **Dentro de `_updateNavBrand`**: `await getUser()` (L3435). ⚠️ Puede throw; puede devolver user=null por race.
5. **`await checkDemoAccess(user)`** (L3439). ⚠️ `admin_accounts` RLS silenciosamente falla → no-admin path.
6. **Write `brandText.textContent = access.codename + ' · ' + access.role`** (L3444). Requiere (1) user válido y (2) `admin_accounts` devuelva row para `user.email`.
7. **Paralelo**: segundo disparo desde `getSession().then` (L6636) también corre `_updateNavBrand` → mismo flujo.
8. **Paralelo**: `onAuthStateChange` con `INITIAL_SESSION` en recarga posterior → mismo flujo.

**Cualquier throw silencioso o race entre los 3 writers deja el navbar en el HTML default "Guest v1.0"**.

---

## 10. Instrumentación sugerida (NO se aplica en este audit)

Para diagnóstico del bug TRON se necesitaría añadir:

- `try/catch` en `_updateNavBrand` con `console.error('[nav] update failed', e)` antes del return.
- `console.log('[nav]', new Error().stack.split('\n')[2], user?.email, access?.status)` al inicio y antes de cada `textContent = ...`.
- Verificar en Supabase dashboard si `admin_accounts` tiene una policy `SELECT` para `authenticated`, o si es `anon` y solo tiene WHERE restrictivo.

Ver `TRON_BUG_NOTES.md` para las hipótesis priorizadas.
