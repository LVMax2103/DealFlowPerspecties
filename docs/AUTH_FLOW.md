# AUTH_FLOW — Estado actual en `main`

Auditoría tomada con HEAD de `main` = `2c0c6e4`. Sobreescribe la versión anterior.

Método: greps exhaustivos sobre `index.html` para `localStorage|sessionStorage|supabase.auth.*|onAuthStateChange|signInWithPassword|signUp|signOut|getUser|getSession|setSession|refreshSession|addEventListener.*beforeunload|unload|pagehide|visibilitychange|storage` + lectura completa de las secciones AUTH (L3307–3719) y BOOT (L6679–6696).

---

## 1. Boot de la página (orden exacto)

`index.html` está envuelto en una IIFE única (`(function () {` en L3301 hasta `})();` en L6696).

| Orden | Línea | Acción |
|------:|------:|--------|
| 1 | 3312 | `const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { autoRefreshToken: false, lock: (n,t,fn) => fn() } })` — cliente creado. **Aún no toca storage**. |
| 2 | 3319–3329 | Define `clearSupabaseStorage()` (limpia keys que empiezan en `sb-` de localStorage y sessionStorage). |
| 3 | 3434–3437 | Define helper `async getUser()` que envuelve `supabase.auth.getUser()`. |
| 4 | 3454–3521 | Define `_updateNavBrand(callSite)`. Internamente: `await supabase.auth.getSession()` → si user, llama `checkDemoAccess(user)` que SELECTs `admin_accounts` + `demo_requests`; si no user, escribe `'DFP · Pre-MVP Demo'`. |
| 5 | 3524–3717 | Define `_initAuth()` que registra `onAuthStateChange` y los handlers signIn/signUp/logout. |
| 6 | 6427 | `initAuth()` se invoca → ejecuta `_initAuth()`. Esto: |
|   | 3568 | Registra **EL ÚNICO listener** `supabase.auth.onAuthStateChange(async (event, session) => …)`. Supabase v2 emite `INITIAL_SESSION` poco después del registro. |
|   | 3716 | Llama `_updateNavBrand('call-1-initAuth')` (sin await). |
| 7 | 6428–6429 | `initNewsletter()`, `initHomeScroll()`. |
| 8 | 6680 | **Boot block final**: `console.log('boot: calling supabase.auth.getSession()')` |
| 9 | 6681 | `supabase.auth.getSession().then(result => { if (result.data.session) { currentUser = result.data.session.user; _updateNavBrand('call-3-getSessionThen'); loadPreferencesFromSupabase(); } loadData(); })` |

**3 entradas a `_updateNavBrand` por boot**: `call-1-initAuth`, `call-2-onAuthStateChange:INITIAL_SESSION`, `call-3-getSessionThen` — cada una llama internamente `getSession()`.

---

## 2. Login (signInWithPassword)

L3604–3645 (handler del submit del form):

1. L3615 `await supabase.auth.signInWithPassword({email, password})`.
2. Si error contiene "Invalid"/"expired" → L3621 `clearSupabaseStorage()` → L3623 retry una vez.
3. Si éxito → L3644 comentario `"Success handled by onAuthStateChange"` (no hace nada más explícito).
4. Supabase emite `SIGNED_IN` → handler en L3568 dispara:
   - L3570 `_updateNavBrand('call-2-onAuthStateChange:SIGNED_IN')` (otra `getSession()`).
   - L3572 cierra modal, resetea forms, oculta lockout.
   - L3576 `loadData()` (sin await) → internamente `await supabase.auth.getUser()` en L3961 (HTTP).
   - L3577 `loadPreferencesFromSupabase()` (sin await) → L6227 `await supabase.auth.getUser()` (HTTP).
   - L3578 `renderWatchlist()`.
   - L3580 `await checkDemoAccess(session.user)` → SELECTs `admin_accounts` + `demo_requests`.
   - L3581 si expirado → `showExpiredOverlay()`.

⚠️ `getUser()` (HTTP en /auth/v1/user) dentro de un handler de `onAuthStateChange` provoca re-emisión de `SIGNED_IN` en Supabase v2 → loop documentado en `docs/MULTIPLE_CLIENT_BUG.md`.

---

## 3. Logout

L3708–3714 (click en btnLogout):

```js
btnLogout.addEventListener('click', async function() {
  if (!confirm('Are you sure you want to log out?')) return;
  await syncPreferencesToSupabase();    // upserts user_preferences
  await supabase.auth.signOut();         // borra sb-* y emite SIGNED_OUT
  clearSupabaseStorage();                // defensivo: borra sb-* otra vez
  window.location.reload();              // hard reload
});
```

`signOut()` emite `SIGNED_OUT` → handler L3585–3589 limpia `currentUser`, borra `FAVORITES_KEY` y `getDashboardLayoutKey()` de localStorage. Inmediatamente después, `window.location.reload()` recarga.

---

## 4. Refresh (estado actual — éste es el bug que vamos a fixear)

Lo que pasa hoy al refrescar la página estando logueado:

1. Browser carga `index.html` desde cero. localStorage **persiste** entre reloads (incluyendo `sb-*` tokens).
2. createClient (L3312) → cliente con `autoRefreshToken: false` y lock no-op.
3. `initAuth()` registra el listener (L3568) → Supabase emite `INITIAL_SESSION`.
4. Listener llama `_updateNavBrand` → `getSession()` lee localStorage → recupera la sesión cacheada → marca al user como logueado.
5. Boot block (L6681) llama `getSession()` otra vez → `_updateNavBrand('call-3-getSessionThen')` → `loadPreferencesFromSupabase()` → `loadData()`.
6. Si los tokens en localStorage están corruptos o el access_token expiró, los SELECTs a `admin_accounts`/`demo_requests` cuelgan o devuelven 401 → navbar queda en "guest" pero `sb-*` tokens permanecen → `signInWithPassword` posterior se confunde con la sesión inválida y falla hasta que el usuario borra cache manualmente.

**No hay listener de `beforeunload`/`unload`/`pagehide`/`visibilitychange`/`storage`** — verificado por grep negativo.

---

## 5. Inventario de auth listeners

| Listener | Línea | Tipo | Frecuencia |
|----------|------:|------|-----------|
| `supabase.auth.onAuthStateChange` | 3568 | Auth events (INITIAL_SESSION, SIGNED_IN, SIGNED_OUT, TOKEN_REFRESHED, USER_UPDATED) | 1 sólo registro, dentro de `_initAuth()` ejecutado una vez vía IIFE. |

Sin listeners de `window`/`document` para visibility/unload/storage.

---

## 6. Estado de las constantes globales auth

```
let currentUser = null;     // L3426
let isAdmin = false;        // L3427
let demoExpiresAt = null;   // L3428
let demoStatus = null;      // L3429
var ADMIN_EMAILS = ['elenesmaximiliano@gmail.com'];   // L3432
```

`currentUser` se setea en:
- `_updateNavBrand` L3472 (tras `getSession()`).
- Boot block L6687 (tras `getSession()`).
- Handler SIGNED_OUT L3586 (a `null`).

Nunca se sincroniza fuera de esos 3 sitios. Otras funciones (`loadData`, `syncPreferencesToSupabase`, `loadPreferencesFromSupabase`) llaman `supabase.auth.getUser()` directamente en vez de leer `currentUser`.

---

## 7. Lista completa de llamadas a `supabase.auth.*` en `index.html`

| Línea | Llamada | Función contenedora |
|------:|---------|---------------------|
| 3435 | `getUser()` | helper local `async getUser()` |
| 3465 | `getSession()` | `_updateNavBrand` |
| 3568 | `onAuthStateChange(...)` | `_initAuth` (registro) |
| 3615 | `signInWithPassword(...)` | submit signInForm |
| 3623 | `signInWithPassword(...)` (retry) | catch del L3615 |
| 3668 | `signUp(...)` | submit signUpForm |
| 3711 | `signOut()` | click btnLogout |
| 3961 | `getUser()` | `loadData()` |
| 6196 | `getUser()` | `syncPreferencesToSupabase()` |
| 6227 | `getUser()` | `loadPreferencesFromSupabase()` |
| 6681 | `getSession()` | boot block IIFE bottom |

Total: 4 `getUser`, 2 `getSession`, 2 `signInWithPassword`, 1 cada uno de signUp, signOut, onAuthStateChange.

Ver `docs/STORAGE_INVENTORY.md` para todas las keys de localStorage que tocamos.
