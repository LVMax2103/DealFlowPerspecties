# REFRESH_LOGOUT_DESIGN — Spec del contrato `refresh = logout limpio`

Estado base: `main` HEAD = `2c0c6e4`. Diseño previo a implementación; no toca código todavía.

---

## 1. Contrato

> Cualquier reload de página, cierre/reapertura de pestaña, o cierre/reapertura de navegador arranca al usuario como **guest**. La sesión sólo persiste mientras la pestaña sigue viva sin recargar.

Implicaciones operativas:

- En el primer paint tras boot, el navbar siempre muestra `'DFP · Pre-MVP Demo'`.
- `currentUser`, `isAdmin`, `demoStatus` arrancan en sus defaults (null/false/null).
- No hay rehidratación de sesión a partir de localStorage.
- El usuario debe hacer `signInWithPassword` para tener acceso autenticado.
- Tras login, los favoritos y panel_layout se restauran desde la tabla `user_preferences` en Supabase (no desde localStorage).

---

## 2. Estrategia de implementación (validar antes de codear)

### 2.1. Limpieza temprana en boot

Insertar un bloque al inicio de la IIFE, **antes de `window.supabase.createClient(...)` (L3312)**:

```js
// REFRESH = LOGOUT: clear any stale auth + cached user-pref state.
// Supabase tokens AND local user-pref caches are blown away on every page load.
// Source of truth for prefs is the user_preferences table; restored after login.
try {
  var dropPrefix = function(storage) {
    var keys = [];
    for (var i = 0; i < storage.length; i++) {
      var k = storage.key(i);
      if (k && (k.indexOf('sb-') === 0 || k.indexOf('supabase') === 0 || k.indexOf('dfp_') === 0)) {
        keys.push(k);
      }
    }
    keys.forEach(function(k) { storage.removeItem(k); });
  };
  dropPrefix(localStorage);
  dropPrefix(sessionStorage);
} catch (e) { /* storage unavailable, ignore */ }
```

Patrón regex equivalente: `^(sb-|supabase|dfp_)` (ver `docs/STORAGE_INVENTORY.md`).

Después de este bloque, `createClient(SUPABASE_URL, SUPABASE_ANON_KEY)` se ejecuta sobre storage limpio → no hay sesión que recuperar → no hay deadlock posible.

### 2.2. Reglas posteriores a la limpieza

Una vez que el storage arranca limpio, **varios parches defensivos dejan de tener razón de ser**:

| Parche actual | Línea | Decisión |
|---|------:|---|
| `auth: { lock: (n,t,fn) => fn() }` en createClient | 3315 | **ELIMINAR** — sin sesión cacheada no hay deadlock del navigator.locks. |
| `auth: { autoRefreshToken: false }` en createClient | 3314 | **ELIMINAR** — sin tokens persistidos no hay nada que refrescar al boot. |
| `getUser()` → `getSession()` en `loadData` (L3961), `syncPreferencesToSupabase` (L6196), `loadPreferencesFromSupabase` (L6227) | — | **No aplicado en main** (sólo existió en branch debug que borramos). En main siguen como `getUser()`. Tras login fresh ambos funcionan equivalente; la elección de `getUser` vs `getSession` ya no tiene impacto en el loop, pero `getSession` es estrictamente más barato (no hace HTTP). **Sí migrar a `getSession`** por eficiencia. |
| Reemplazo `getUser()` → `getSession()` en `_updateNavBrand` (L3465) | 3465 | **CONSERVAR** — es estrictamente mejor (sin HTTP en cada render). |
| Helper `clearSupabaseStorage()` L3319–3329 | — | **CONSERVAR** — sigue siendo útil para limpiezas defensivas (retry login, logout). La nueva limpieza al boot es independiente y vive antes del helper. |
| `clearSupabaseStorage()` defensivo en login retry (L3621) y logout (L3712) | — | **CONSERVAR** — no hace daño. |
| `_tronInspectNav` helper (L3440) y todos los `console.log/warn/error` con prefijo `[TRON-DEBUG]` | varias | **ELIMINAR** — instrumentación de debug ya no necesaria. |
| Boot block `getSession().then(...)` en L6680–6695 | — | **SIMPLIFICAR**: tras la limpieza al boot, `getSession()` siempre devuelve `{ data: { session: null } }`. La rama `if (result.data.session)` nunca se ejecuta. Reducir a `loadData()` directo (sin la rama if). Mantener un `_updateNavBrand()` por si hay race con el listener `INITIAL_SESSION`. |
| 3 entradas a `_updateNavBrand` por boot (call-1, call-2-INITIAL_SESSION, call-3-getSessionThen) | — | **REDUCIR** a una sola entrada efectiva. Tras la limpieza, las 3 entradas ven la misma realidad (no session) → la primera escribe guest y las dos siguientes son no-ops. Funciona pero es ruidoso; aceptable mientras los logs estén apagados. |

### 2.3. Bug colateral del key de panel layout

`getDashboardLayoutKey()` (L4976–4980) llama el helper async `getUser()` sin `await` → siempre devuelve `'dfp_layout_undefined'`. Esto significa que el panel layout es **compartido entre todos los usuarios** en localStorage.

Tras el contrato refresh = logout, ese key siempre arranca limpio. La fuente de verdad es `user_preferences.panel_layout` por user_id. Sin embargo, el bug del helper sigue produciendo un key incorrecto que escribe sobre `'dfp_layout_undefined'` en la sesión actual.

**Decisión**: cambiar `getDashboardLayoutKey()` para usar `currentUser` (la global) en vez de llamar `getUser()`. Stays síncrono, fixea el bug, no requiere awaits en sus call-sites. Si `currentUser` es null → key es `'dfp_layout_guest'` (consistente con el `'guest'` existente).

### 2.4. Race condition al boot

La IIFE corre síncrona hasta L6427 (`initAuth()`), que registra el listener (L3568) y llama `_updateNavBrand` (L3716, sin await). Después corre el bloque boot a L6680. Las 3 llamadas a `_updateNavBrand` corren en paralelo; con storage limpio todas resuelven a guest, así que la última que corra escribe el mismo texto → ok.

No requiere mutex ni serialización adicional.

---

## 3. Lo que NO se vuelve obsoleto

- Helper `clearSupabaseStorage()` (lo siguen usando login retry y logout).
- Listener `onAuthStateChange` (sigue siendo el motor del flujo post-login).
- `checkDemoAccess()` (sigue siendo necesario al entrar SIGNED_IN).
- Toda la lógica post-SIGNED_IN: cierre del modal, reset de forms, `loadData`, `loadPreferencesFromSupabase`.

---

## 4. Pendientes / preguntas que el audit destapó

1. **L4977 `getUser()` sin await** — el bug del key de panel layout. Recomendación: fixear al mismo tiempo, con `currentUser` (síncrono).
2. **`docs/MULTIPLE_CLIENT_BUG.md`, `docs/TRON_BUG_NOTES.md`** — son artefactos de la investigación previa. Después del fix definitivo se vuelven obsoletos pero documentan history. Sugerencia: dejarlos como `docs/archive/` o renombrarlos. **No se borran en este commit**.
3. **3 entradas a `_updateNavBrand` por boot** — funciona pero es subóptimo. Consolidar a 1 sola entrada queda como mejora futura, no bloqueante.
4. **`autoRefreshToken: false` removed**: eso reactivará el auto-refresh interno de Supabase mientras la pestaña vive — comportamiento normal y deseable, ya que la sesión sólo dura lo que dura la pestaña sin recargar.

---

## 5. Lista exacta de cambios para PASO 3

1. **Insertar** bloque de limpieza de storage al inicio de IIFE (antes de L3312).
2. **Modificar L3312** para quitar `autoRefreshToken: false` y `lock: ...`. Volver a la firma simple: `createClient(SUPABASE_URL, SUPABASE_ANON_KEY)`.
3. **Modificar `loadData` L3961, `syncPreferencesToSupabase` L6196, `loadPreferencesFromSupabase` L6227** para usar `getSession` en vez de `getUser` (port del fix H7 que vivía en el branch borrado).
4. **Modificar `getDashboardLayoutKey` L4976–4980** para usar `currentUser` en vez del helper `getUser()`.
5. **Eliminar todos los `console.log/warn/error` con `[TRON-DEBUG]`** y la función `_tronInspectNav` y sus call-sites.
6. **Simplificar boot block L6680–6695**: quitar logs y rama `if (result.data.session)`. Reducir a `loadData()` directo + un `_updateNavBrand()` defensivo.
7. **Conservar** `clearSupabaseStorage`, `onAuthStateChange` handler, `checkDemoAccess`, etc.

Esto cabe en un solo commit con mensaje:
`feat(auth): refresh-as-logout contract + cleanup deadlock workarounds`

Esperando confirmación del PASO 2 (esta spec) antes de aplicar PASO 3.
