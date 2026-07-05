# REPO_INVENTORY — Auditoría del repo

Raíz del repo: `DealFlowPerspecties_website/`. Clasificación basada en `grep` contra `index.html`, `docs/` y `supabase/` para cada archivo.

**Leyenda**:
- ✅ **ACTIVO**: referenciado por `index.html`, por `CNAME`/config, por las migraciones, o es documentación viva.
- ⚙️ **INFRA**: tooling / configuración del repo (git, npm, gitignore).
- 🔒 **IGNORADO**: existe en disco pero fuera de git a propósito (deps, secretos en runtime).

---

## Changelog

- **2026-07-05 — Auditoría de limpieza completa.** Se revisó cada archivo trackeado y en disco contra `index.html` y `docs/`. **Resultado: el repo ya estaba limpio — 0 bytes eliminados.** No había basura de OS/editor, ni assets duplicados, ni archivos huérfanos trackeados. La limpieza pesada ya la habían hecho commits previos: `0d1c755` (borra 16 assets huérfanos, ~4 MB) y `9cdd2d6` (borra código muerto). Tag de seguridad para rollback: **`pre-cleanup-20260705`** (apunta a `9cdd2d6`). Cambios de higiene aplicados en esta pasada: se trackeó `docs/MULTIPLE_CLIENT_BUG.md` (antes sin commitear), se dejó de trackear `.claude/settings.local.json` (config personal, ahora gitignored), y se reescribió este inventario.
- _(previo)_ Estado anterior de este doc listaba 16 huérfanos como candidatos a borrar; todos fueron eliminados en `0d1c755`. `migration_002_access_control.sql` fue creado en `971d178`.

---

## 1. Archivos del root

| Archivo | Tamaño | Estado | Razón |
|---|---|---|---|
| `index.html` | 243 KB | ✅ ACTIVO | Entry point único del sitio. **Fuera de scope de limpieza.** |
| `CNAME` | 24 B | ✅ ACTIVO | GitHub Pages custom domain (`dealflowperspectives.com`). Borrarlo tumba el dominio. |
| `favicon-192x192.png` | 3.3 KB | ✅ ACTIVO | Referenciado en `index.html` (×3) |
| `logo-horizontal-white.png` | 35.7 KB | ✅ ACTIVO | Referenciado en `index.html` (×4) |
| `hero-setup-transparent.png` | 999 KB | ✅ ACTIVO | Hero image actual — `index.html` (×1) |
| `Top-Performing Private Equity Funds (IRR) — Active Investing Status (1).pdf` | 2.6 MB | ✅ ACTIVO | Descarga desde la sección PE Funds — `index.html` (×1) |
| `package.json` | 91 B | ⚙️ INFRA | Declara deps (`@supabase/supabase-js`, `xlsx`) usadas por el seeder local |
| `package-lock.json` | 9.1 KB | ⚙️ INFRA | Lockfile de npm |
| `.gitignore` | ~0.3 KB | ⚙️ INFRA | Ignora `node_modules/`, `.env*`, `supabase/seed.js`, droppings de OS/editor, `.claude/settings.local.json` |
| `.gitattributes` | 66 B | ⚙️ INFRA | Normalización LF |

Sin huérfanos ni duplicados en el root. Todos los assets están referenciados por `index.html`.

---

## 2. `docs/` — contratos de diseño vivos (untouchable)

| Archivo | Propósito |
|---|---|
| `ARCHITECTURE.md` | Arquitectura general del sitio single-file + Supabase |
| `AUTH_FLOW.md` | Flujo de autenticación |
| `DATA_MODEL.md` | Modelo de datos / tablas Supabase |
| `LOCAL_FOLDER_AUDIT.md` | Auditoría de la carpeta local de trabajo (fuera del repo) |
| `MULTIPLE_CLIENT_BUG.md` | Notas del bug de múltiples clientes Supabase (trackeado el 2026-07-05) |
| `REFRESH_LOGOUT_DESIGN.md` | Contrato refresh-as-logout |
| `REPO_INVENTORY.md` | Este documento |
| `STORAGE_INVENTORY.md` | Inventario de localStorage / sessionStorage |
| `TRON_BUG_NOTES.md` | Notas del bug "TRON" (deadlock del navbar) |

---

## 3. `supabase/`

| Archivo | Estado | Razón |
|---|---|---|
| `migration.sql` | ✅ ACTIVO | Schema base (tracked) |
| `migration_002_access_control.sql` | ✅ ACTIVO | Schema de access control: `admin_accounts`, `demo_requests`, etc. (tracked) |
| `seed.js` | 🔒 IGNORADO | Contiene el service_role key en runtime → gitignored. **Nunca commiteado** (verificado en historial). |

---

## 4. Carpetas y archivos fuera de git

| Item | Estado | Razón |
|---|---|---|
| `.git/` | ⚙️ INFRA | Metadata git |
| `.claude/settings.local.json` | 🔒 IGNORADO | Config personal de Claude Code. En disco, ya no trackeado (desde 2026-07-05). |
| `node_modules/` | 🔒 IGNORADO | Deps npm. Reinstalable con `npm install`. |
| `data/` | — | Carpeta **vacía** en disco. Git no trackea carpetas vacías, así que no está en el repo. El seeder (`supabase/seed.js`) lee JSON de aquí en runtime; los JSON viven en la carpeta local de trabajo, no en el repo. Sin impacto en producción. |

---

## 5. Chequeo de secretos

✅ Sin secretos commiteados. `supabase/seed.js` (service_role key en runtime) está gitignored y nunca entró al historial. La palabra `service_role` sólo aparece como texto en `.gitignore` y en docs. No hay `.env` ni JWT hardcodeado en `index.html`.

---

> Este documento sólo clasifica e inventaría. Cualquier borrado o cambio queda pendiente de confirmación explícita del owner.
