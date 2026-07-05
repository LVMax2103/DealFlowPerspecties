# MULTIPLE_CLIENT_BUG — Investigación

Rama: `debug/tron-navbar`
Estado: investigación, sin cambios de código.

## Síntomas observados (browser)

1. Warning Supabase: *"Multiple GoTrueClient instances detected in the same browser context… may produce undefined behavior when used concurrently under the same storage key."*
2. Loop de `onAuthStateChange event=SIGNED_IN` cada 1–2 s (timestamps 06:02:58, 06:03:00, 06:03:01, 06:03:14).
3. Cada SIGNED_IN entra a `_updateNavBrand` → llama `getSession()`. El log `getSession user=` rara vez aparece después → o se cuelga o el siguiente SIGNED_IN cancela.
4. Solo hay UNA llamada a `supabase.createClient(...)` en `index.html` (verificado por grep).

---

## 1. `createClient` en TODO el repo

```
index.html:3312:  const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
docs/ARCHITECTURE.md:78  (mención en doc, no código)
```

**Total ejecutable: 1 sola llamada.** No hay `createClient` en otros .html ni .js (excluyendo `node_modules` y el seed server-side).

`<script src="...supabase-js@2.../supabase.min.js"></script>` aparece **una sola vez** en `index.html:3295`. UMD bundle expone `window.supabase` como **namespace** (factory), no instancia preexistente.

`<script>` totales en `index.html`: 5 tags inline/CDN (líneas 3295–3300). Sin iframes (`<iframe>`), sin service workers (`serviceWorker`/`importScripts`), sin imports dinámicos.

→ **El segundo cliente NO viene de nuestro código.** Procedencia probable: pestaña hermana abierta del mismo sitio, browser extension, o el primer cliente "fantasma" persistido en BroadcastChannel desde una sesión previa de DevTools antes de hard reload.

---

## 2. Inventario de llamadas Supabase Auth en `index.html`

| Línea | Método | Dentro de | ¿Disparable por handler? |
|------:|--------|-----------|--------------------------|
| 3435 | `supabase.auth.getUser()` | helper `getUser()` | NO se usa desde `_updateNavBrand` ya |
| 3465 | `supabase.auth.getSession()` | `_updateNavBrand` | sí (handler L3570 lo llama) |
| 3568 | `supabase.auth.onAuthStateChange(…)` | `_initAuth` | (registro único) |
| 3615 | `supabase.auth.signInWithPassword` | submit handler signIn | usuario |
| 3623 | `supabase.auth.signInWithPassword` (retry) | catch del L3615 | reintento dentro del catch |
| 3668 | `supabase.auth.signUp` | submit handler signUp | usuario |
| 3711 | `supabase.auth.signOut` | btnLogout click | usuario |
| **3961** | **`supabase.auth.getUser()`** | **`loadData()`** | **🔴 SÍ — handler SIGNED_IN llama `loadData()` (L3576)** |
| **6196** | **`supabase.auth.getUser()`** | **`syncPreferencesToSupabase()`** | indirecto vía `applyFavorites`/logout |
| **6227** | **`supabase.auth.getUser()`** | **`loadPreferencesFromSupabase()`** | **🔴 SÍ — handler SIGNED_IN la llama (L3577)** |
| 6681 | `supabase.auth.getSession()` | boot IIFE bottom | (una vez al cargar) |

---

## 3. Handler de `onAuthStateChange` (L3568–3590)

```js
supabase.auth.onAuthStateChange(async function(event, session) {
  console.log('[TRON-DEBUG]', …, 'onAuthStateChange event=', event, …);
  _updateNavBrand('call-2-onAuthStateChange:' + event);   // → getSession (sync, OK)
  if (event === 'SIGNED_IN') {
    loginModal.classList.remove('open');
    signInForm.reset();
    signUpForm.reset();
    lockoutEl.style.display = 'none';
    loadData();                                            // ← L3961: getUser() 🔴
    if (typeof loadPreferencesFromSupabase === 'function')
      loadPreferencesFromSupabase();                       // ← L6227: getUser() 🔴
    renderWatchlist();
    var access = await checkDemoAccess(session.user);      // SELECT admin_accounts
    if (access.status === 'expired') showExpiredOverlay();
  }
  if (event === 'SIGNED_OUT') {
    currentUser = null;
    localStorage.removeItem(FAVORITES_KEY);
    localStorage.removeItem(getDashboardLayoutKey());
  }
});
```

Operaciones async dentro del handler que pueden re-disparar eventos auth:

| Llamada | Línea | Riesgo |
|---------|------:|--------|
| `_updateNavBrand` → `getSession()` | 3465 | bajo (sync read) |
| `loadData()` → `getUser()` | 3961 | **🔴 ALTO — getUser hace round-trip y emite SIGNED_IN/TOKEN_REFRESHED en v2** |
| `loadPreferencesFromSupabase()` → `getUser()` | 6227 | **🔴 ALTO — mismo motivo** |
| `checkDemoAccess(session.user)` → SELECT admin_accounts | 3357–3361 | medio (PostgREST con auth header; en teoría no emite eventos auth, pero la query queda colgada si el lock está tomado) |

`loadData()` se llama **sin `await`** (L3576) ⇒ corre en paralelo con `loadPreferencesFromSupabase()` (también sin await, L3577) y con `await checkDemoAccess(session.user)` (L3580). Tres operaciones de auth/db en paralelo cada vez que entra SIGNED_IN.

---

## 4. CDN `supabase-js`

```
3295:<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
```

**Una sola carga.** No hay duplicado, no hay dynamic import, no hay re-ejecución del bloque `<script>` (la IIFE termina al final del archivo).

---

## 5. Listeners de `onAuthStateChange`

`supabase.auth.onAuthStateChange(` aparece **exactamente 1 vez** en `index.html` (L3568). Sin duplicados.

`_initAuth` se invoca desde `initAuth()` (L3718) y `initAuth()` se llama **una vez** desde la IIFE (L6427). No hay re-registro.

---

## HIPÓTESIS PRINCIPAL: H7 (con matiz de H8)

### H7 confirmado — `getUser()` dentro del flujo del handler causa el loop

Supabase JS v2 `auth.getUser()` hace un **round-trip HTTP a `/auth/v1/user`**. Cuando responde, GoTrueClient compara el access token / user devuelto con el cacheado y, si difiere — o en algunas versiones sólo por confirmación válida — **emite `SIGNED_IN` (o `TOKEN_REFRESHED`) a todos los listeners**.

Cadena observable:

1. Handler SIGNED_IN dispara → llama `loadData()` (sin await) y `loadPreferencesFromSupabase()` (sin await).
2. Ambas llaman `supabase.auth.getUser()` (L3961, L6227).
3. Cada `getUser()` resuelve y GoTrue re-emite `SIGNED_IN`.
4. El handler vuelve a entrar → vuelve a llamar `loadData()` + `loadPreferencesFromSupabase()` → vuelve a `getUser()` → vuelve a emitir SIGNED_IN. **Loop.**
5. El intervalo de 1–2 s ≈ tiempo de round-trip a `*.supabase.co` desde el browser del usuario.

Esto explica además por qué `_updateNavBrand` "se cuelga" sin loggear `getSession user=`: cada nuevo SIGNED_IN dispara una nueva entrada a `_updateNavBrand` antes de que el `getSession()` de la anterior resuelva, y el navigator.locks workaround que aplicamos sólo elimina el deadlock interno, no la cascada de re-entradas.

### H8 (Multiple GoTrueClient) — síntoma secundario, no causa raíz

El warning *Multiple GoTrueClient instances* viene del cross-tab BroadcastChannel de GoTrue. Aparece cuando otro contexto (otra pestaña del mismo origen, o un cliente residual en memoria de DevTools/HMR) tiene un GoTrueClient con la misma `storageKey`. **Amplifica** el loop de H7 (cada `SIGNED_IN` se broadcastea a la otra pestaña, que también emite, que también dispara handlers locales) pero el motor del loop es la cadena `getUser()`-en-handler.

### H6 descartado

Sólo hay un `createClient` en el código. El segundo cliente NO se origina en este repositorio.

---

## Implicaciones para el fix (no aplicar todavía)

Para H7 (causa raíz):
- Reemplazar `getUser()` por `getSession()` en `loadData` (L3961), `syncPreferencesToSupabase` (L6196) y `loadPreferencesFromSupabase` (L6227). `getSession()` lee localStorage, no hace red, no re-emite SIGNED_IN.
- Alternativamente, usar la `session.user` que ya viene en el callback del handler en vez de re-pedir el user.

Para H8 (amplificador):
- Pedir al usuario cerrar pestañas hermanas del sitio durante la prueba.
- Si persiste, considerar `storageKey` único por pestaña (workaround agresivo, rompería persistencia entre pestañas) — sólo si H7 ya está fixeado y el warning sigue.

Reporte cerrado. A la espera de decisión sobre cuál fix aplicar.
