# STORAGE_INVENTORY — keys de browser storage tocadas por `index.html`

Auditoría sobre `main` HEAD = `2c0c6e4`. Generada con grep `localStorage\.|sessionStorage\.` y `_KEY\s*=|FAVORITES_KEY|LAYOUT_KEY|dfp_|getDashboardLayoutKey`.

## Convención de categorías

- **AUTH**: token o estado de sesión Supabase. Vive en localStorage/sessionStorage con prefijo `sb-`.
- **USER_PREF**: preferencia del usuario duplicada como caché local (Supabase `user_preferences` es la fuente de verdad).
- **OTHER**: cualquier otra cosa.

---

## 1. localStorage

| Key | Categoría | Línea write | Línea read | Línea remove | Notas |
|-----|-----------|------------:|-----------:|-------------:|-------|
| `sb-<projectref>-auth-token` (y variantes que Supabase v2 escribe) | **AUTH** | (Supabase internals; lo escribe `signInWithPassword`/`signUp`) | (Supabase internals via `getSession`/`getUser`) | 3322 (`clearSupabaseStorage`), 3621 (catch retry login), 3712 (post `signOut`) | El prefijo `sb-` es el contrato de Supabase JS v2. La sesión persiste cross-reload por defecto. |
| `dfp_market_favorites` | **USER_PREF** | 6182 (`toggleFavorite`), 6255 (restored from Supabase en `loadPreferencesFromSupabase`) | 6174 (`getFavorites`) | 3587 (handler SIGNED_OUT) | Constante `FAVORITES_KEY` declarada en L6147. Se sincroniza con Supabase tabla `user_preferences.market_favorites`. |
| `dfp_layout_<email>` o `dfp_layout_undefined` (bug) | **USER_PREF** | 4990 (`savePanelSizes`), 6271 (`loadPreferencesFromSupabase`) | 4996 (`restorePanelSizes`), 6204 (`syncPreferencesToSupabase`) | 3588 (handler SIGNED_OUT) | `getDashboardLayoutKey()` L4976–4980 llama al helper async `getUser()` síncronamente (sin `await`) → `user` es Promise → key resuelve a `'dfp_layout_undefined'` siempre. Bug preexistente. Se sincroniza con `user_preferences.panel_layout`. |

**Total de prefijos a borrar para `refresh = logout limpio`**:

- `sb-` (todos los tokens Supabase).
- `dfp_market_favorites` (clave fija).
- `dfp_layout_*` (todas las variantes — el wildcard `dfp_` cubre ambas).

Patrón regex propuesto: `^(sb-|supabase|dfp_)`.

---

## 2. sessionStorage

| Key | Categoría | Línea write | Línea read | Línea remove | Notas |
|-----|-----------|------------:|-----------:|-------------:|-------|
| `sb-*` (cualquier prefijo) | **AUTH** | (Supabase internals si `storage: sessionStorage` se configura — actualmente NO se configura) | (Supabase internals) | 3324 (`clearSupabaseStorage` defensivo) | En la config actual `clearSupabaseStorage` itera sessionStorage por seguridad, pero Supabase v2 default usa localStorage. |

No tocamos sessionStorage para nada de USER_PREF u OTHER.

---

## 3. Verificación negativa

Greps sin resultado (= ausencia confirmada):

- `addEventListener.*'(beforeunload|unload|pagehide|visibilitychange|storage)'` → ningún listener de ciclo de vida o de cambios cross-tab.
- Otras llaves localStorage fuera de las 3 listadas → no existen.
- `cookies` con `sb-` o `dfp_` → no manejamos cookies en el frontend.

---

## 4. Resumen ejecutivo para el fix

Limpieza de `refresh = logout` debe borrar:

```
^sb-          // todos los tokens Supabase
^supabase     // (defensivo; Supabase v2 actualmente no usa este prefijo, pero futuras versiones podrían)
^dfp_         // FAVORITES_KEY + dfp_layout_*
```

`sessionStorage`: aplicar mismo filtro `^sb-` por defensa, aunque con la config actual está vacío.

Las preferencias borradas (`dfp_market_favorites`, `dfp_layout_*`) se restauran desde Supabase en `loadPreferencesFromSupabase()` después de un nuevo login → no hay pérdida de datos.
