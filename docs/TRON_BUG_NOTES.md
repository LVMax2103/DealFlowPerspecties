# TRON_BUG_NOTES — Admin navbar regresa a "Guest v1.0"

**Sin fix en este audit. Solo evidencia e hipótesis priorizadas.**

## Síntoma

Loguearse con `elenesmaximiliano@gmail.com` (TRON, admin) en ventana normal deja el navbar mostrando **"Guest v1.0"** en lugar de **"TRON · developer"**. Reparable solo con: (a) borrar cache de la pestaña, (b) ventana de incógnito.

Un fix defensivo añadió `clearSupabaseStorage()` en el path de logout y en el path de "error de login con reintento" (commit `f0c68a5`). **Ese fix no resuelve la raíz.**

## Dato clave del código

El string literal **"Guest v1.0"** aparece **una sola vez** en todo el archivo, en:

```
index.html:L2473   <span id="navBrandText">Guest v1.0</span>
```

Es el **default estático del HTML**. El JavaScript **nunca** lo escribe. La única forma de que se vea ese texto es que `_updateNavBrand()` jamás haya llegado a asignar `brandText.textContent`.

`_updateNavBrand` (ver `AUTH_FLOW.md` §3.4) se dispara desde 3 sitios en paralelo al arrancar (`index.html:L3523, L3669, L6636`). **Ninguno de los tres tiene `try/catch`**. Si los tres abortan silenciosamente, el HTML inicial persiste.

---

## Hipótesis priorizadas

### H1 — 🔴 ALTA: `supabase.auth.getUser()` hace throw con token corrupto/expired, y al no haber `try/catch` en `_updateNavBrand`, el navbar queda en default

**Evidencia**:
- `_updateNavBrand` (`index.html:L3430–L3475`) no tiene `try/catch`.
- `getUser()` (`index.html:L3425–L3428`) destructura `const { data: { user } } = await supabase.auth.getUser()`. Si la promesa **rechaza** (p.ej. network fail durante refresh token), Supabase JS v2 throw y el destructuring explota antes del return.
- Los 3 disparos paralelos (L3523, L3669, L6636) corren la misma función → los 3 crashean con el mismo error.
- En incógnito, no hay token en `localStorage` → `getUser()` devuelve `{ user: null }` limpiamente sin throw → `_updateNavBrand` entra al branch del else (L3468) → escribe `'DFP · Pre-MVP Demo'`. Luego el login exitoso dispara el SIGNED_IN event → escribe `'TRON · developer'`. ✅ Funciona en incógnito.
- En ventana normal, el token en `localStorage` es **válido** (el usuario acaba de loguearse). La explicación entonces no es "token corrupto" en el sentido literal — pero sí puede estar **firmado con un refresh token viejo** que el servidor ya rotó, causando 403 durante `refreshSession`.

**Contraprueba**: Si fuera solo token expired, Supabase JS típicamente devuelve `{ user: null, error }` sin throw. Pero durante **rotación de refresh token** concurrente (dos tabs abiertas disparando refresh al mismo tiempo) la respuesta puede ser un error de conexión/timeout que sí throw.

**Apunta a**: `AUTH_FLOW.md` §3.5 (getUser), §7 R3 (token corrupto), §9 punto 4.

---

### H2 — 🔴 ALTA: Carrera entre los 3 writers de `navBrandText` donde el "último en ganar" es el que lee una sesión **null transitorio**

**Evidencia**:
- `_initAuth` dispara `_updateNavBrand()` sincrónicamente (L3669) **antes** de que Supabase termine de hidratar la sesión desde `localStorage`.
- En ese microtick, `supabase.auth.getUser()` puede devolver `null` limpiamente → el código entra al branch "no user" y **escribe `'DFP · Pre-MVP Demo'`** (L3468). **Pero el usuario reporta `"Guest v1.0"`, no `'DFP · Pre-MVP Demo'`**. Entonces esta rama por sí sola no produce el síntoma.
- **A menos que** `brandText` sea `null` en ese momento — por ejemplo si el orden de parseo del DOM dejó `#navBrandText` no disponible. Muy improbable: el `<script>` está al final de `<body>`, y `#navBrandText` está en L2473.

**Reclasificación**: Como pura race no explica "Guest v1.0" (explicaría "DFP · Pre-MVP Demo" o "TRON · developer" alternando). Para producir exactamente "Guest v1.0" la race tiene que combinarse con un throw en al menos uno de los 3 writers (→ H1).

**Apunta a**: `AUTH_FLOW.md` §7 R1, R2.

---

### H3 — 🟡 MEDIA: Policy RLS de `admin_accounts` permite SELECT sin sesión pero *bloquea* cuando hay sesión incompleta

**Evidencia**:
- `checkDemoAccess` (`index.html:L3350–L3354`) hace `supabase.from('admin_accounts').select('codename, role').eq('email', user.email).maybeSingle()`.
- **Error handling silencioso**: `var { data: adminData } = await ...` — el destructuring descarta el objeto `error`. Si la policy retorna `{ data: null, error: {...403...} }` en lugar de la row, `adminData` queda `null` y el flujo trata a TRON como "no-admin".
- Entonces cae al branch de L3457–L3462 y escribe `user.user_metadata.first_name + ' ' + last_name || user.email` → debería verse el email de TRON o su nombre. **No "Guest v1.0"**.
- Esta hipótesis por sí sola no produce el síntoma exacto, pero degrada silenciosamente el UX. Vale documentarla.

**Contraprueba/refuerzo**: Combinada con H1 (throw durante `getUser`), podría reforzar. Descartable con un único console.error temporal en el `.maybeSingle()`.

**Apunta a**: `AUTH_FLOW.md` §3.6 (checkDemoAccess), `DATA_MODEL.md` §2 `admin_accounts`.

#### Update — confirmación parcial de H3 (grep del schema, 2026-04-24)

Grep de `admin_accounts` en `supabase/`, ahora que `migration_002_access_control.sql` está versionada:

```sql
-- migration_002_access_control.sql:L111–L114
CREATE POLICY "Authenticated users can check admin status"
  ON admin_accounts FOR SELECT
  TO authenticated
  USING (true);
```

**Lo que confirma**:
- **Hay policy SELECT para rol `authenticated`** → si la sesión YA está hidratada cuando se dispara `checkDemoAccess`, el query funciona (TRON es admin real).
- **No hay policy SELECT para rol `anon`** → si la sesión aún NO está hidratada y el cliente Supabase cae al rol por defecto `anon`, el SELECT devuelve `{ data: null, error: 'permission denied' }` silenciosamente. Esto combina con H1/H2: el throw + race + rol `anon` transitorio puede dejar al usuario como "no-admin" aunque lo sea en la tabla.
- La policy usa `USING (true)` — permisivamente expone toda la tabla a cualquier authenticated user. Es un leak separado (no relacionado con el bug), pero mala postura de seguridad. Fuera de scope de este audit; dejar nota.

**Lo que descarta**:
- **H3 en su forma original (RLS bloqueando a un authenticated)** queda descartada. La policy es permisiva para `authenticated`. El bloqueo solo ocurriría contra `anon`, y eso se reduce a la race condition H2.

**Nueva clasificación de H3**: sub-hipótesis de H2 (race de hidratación → query con rol `anon`). Ya no hipótesis independiente.

**No se ha modificado la policy**. Solo se documenta.

---

### H4 — 🟡 MEDIA: `onAuthStateChange` emite eventos que el handler no contempla y el último gana

**Evidencia**:
- Supabase JS v2 emite `INITIAL_SESSION`, `SIGNED_IN`, `TOKEN_REFRESHED`, `USER_UPDATED`, `SIGNED_OUT`.
- El handler (`index.html:L3522–L3543`) solo reacciona a `SIGNED_IN` (data load) y `SIGNED_OUT` (cleanup). Para todos los demás eventos dispara `_updateNavBrand()` y nada más — OK.
- **Pero si TOKEN_REFRESHED llega después de un SIGNED_IN**, vuelve a disparar `_updateNavBrand`, que vuelve a pegarle a `getUser`/`admin_accounts`. Si esa segunda llamada throw (red intermitente), **sobrescribe** el navbar ya correcto — pero el `textContent` no se actualiza porque el throw ocurre antes del write. Entonces el navbar **queda como estaba** (correcto).
- Esta hipótesis por sí sola no produce el bug, pero puede amplificar H1.

**Apunta a**: `AUTH_FLOW.md` §3.3, §7 R1.

---

### H5 — 🟠 BAJA: `loadData()` (L3910) consume el "turno" del auth y causa degradación en cascada

**Evidencia**:
- En `getSession().then` (L6639), después de `_updateNavBrand` se llama `loadData()`. `loadData` vuelve a hacer `supabase.auth.getUser()` (L3914). Si esa segunda llamada throw, cae al `catch` y solo muestra empty-state en `#kpiGrid`. No toca `navBrandText`. No produce "Guest v1.0".

**Descartable** aislada. Solo listada por completitud.

---

### H6 — 🟠 BAJA: `_initAuth` depende de elementos DOM que no existen (null deref) y el IIFE truena

**Evidencia**:
- `_initAuth` usa `document.getElementById('tabSignIn')`, `document.getElementById('tabSignUp')`, `document.getElementById('switchToSignUp')`. Grep en HTML confirma que esos IDs existen (L3028–L3042, L3047–L3055). ✅
- `BOOT` usa `#navBrandLink`, `#mobileToggle`, `#navMenu`, `#countryModalClose`, `#countryDealsModal` — todos existen.
- **Descartada** — no hay null deref en el path normal.

---

## Camino mínimo para distinguir H1 vs H3

Agregar estos 3 logs temporalmente en `_updateNavBrand`:

```js
async function _updateNavBrand() {
  console.log('[nav] start', new Date().toISOString());
  try {
    var brandText = document.getElementById('navBrandText');
    ...
    var user = await getUser();
    console.log('[nav] user =', user?.email || 'null');
    currentUser = user;
    if (user) {
      var access = await checkDemoAccess(user);
      console.log('[nav] access =', access);
      ...
    }
    ...
  } catch (e) {
    console.error('[nav] update failed', e);  // ← si esto se imprime, confirma H1
  }
}
```

Si al loguearse el console muestra `[nav] update failed`, es H1.
Si muestra `[nav] access = { status: 'none', isAdmin: false }` para TRON, es H3.
Si muestra `[nav] user = null` pero luego uno de los siguientes writers reporta `user = TRON` y `access.isAdmin = true` pero "Guest v1.0" persiste, hay un bug adicional en el orden de escritura.

---

## Interacciones con el fix defensivo reciente (commit f0c68a5)

El fix añadió `clearSupabaseStorage()` en:
1. Rama de error de login con retry (L3573–L3583).
2. Rama de logout (L3665).

**Por qué no resuelve el bug**: El bug ocurre al **abrir la página con sesión previa**, no durante un error de login. `clearSupabaseStorage` solo corre en el login-retry o en el logout — caminos que TRON no atraviesa al abrir la página ya autenticada.

Para que el fix fuera efectivo, tendría que correr **al detectar un throw de `getUser` durante el boot**, no al detectar un error de `signInWithPassword`.

---

## Recomendación (no se ejecuta en este audit)

1. Añadir `try/catch` en `_updateNavBrand` con `console.error` visible.
2. Añadir logs en los 3 sitios de disparo.
3. En una sesión de repro, abrir DevTools antes de loguear, loguear, y capturar el console completo.
4. Con ese log, elegir entre: (a) hacer `_updateNavBrand` idempotente y retrasable, (b) limpiar `sb-*` en boot si `getUser` throw, (c) bloquear los 3 disparos y que solo `getSession().then` sea el que escribe navbar (serialización).

Ver `AUTH_FLOW.md` §10 para la lista de instrumentación mínima.
