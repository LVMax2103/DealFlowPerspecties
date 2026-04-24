# REPO_INVENTORY — Auditoría del repo

Raíz del repo: `DealFlowPerspecties_website/`. Clasificación basada en `grep` contra `index.html` y `supabase/` para cada archivo.

**Leyenda**:
- ✅ **ACTIVO**: referenciado por `index.html`, por `CNAME`/config, o por el script de seed.
- 🗑️ **HUÉRFANO**: no hay referencia en el código servido. Candidato a borrar.
- ❓ **DUDA**: requiere decisión del owner antes de tocar.

---

## 1. Archivos del root

| Archivo | Tamaño | Estado | Razón |
|---|---|---|---|
| `index.html` | 242 KB | ✅ ACTIVO | Entry point único del sitio |
| `CNAME` | 24 B | ✅ ACTIVO | GitHub Pages custom domain (`dealflowperspectives.com`) |
| `.gitattributes` | 66 B | ✅ ACTIVO | Normalización LF |
| `.gitignore` | 222 B | ✅ ACTIVO | Incluye `node_modules/`, `.env`, `supabase/seed.js` |
| `package.json` | 91 B | ✅ ACTIVO | Declara deps (`@supabase/supabase-js`, `xlsx`) usadas por el seeder |
| `package-lock.json` | 9.1 KB | ✅ ACTIVO | Lockfile de npm |
| `favicon-192x192.png` | 3.3 KB | ✅ ACTIVO | Referenciado en `index.html:L7–L9` |
| `logo-horizontal-white.png` | 35.7 KB | ✅ ACTIVO | Referenciado en `index.html:L1616, L2472, L3018, L3073` |
| `hero-setup-transparent.png` | 999 KB | ✅ ACTIVO | Hero image actual — `index.html:L2578` |
| `Top-Performing Private Equity Funds (IRR) — Active Investing Status (1).pdf` | 2.6 MB | ✅ ACTIVO | Descarga desde la sección PE Funds — `index.html:L2838`. **Comprimir antes de push** si cabe con reducción >30% |
| | | | |
| `icon-white.png` | 2.8 KB | 🗑️ HUÉRFANO | No referenciado en `index.html` |
| `icon-white_1.png` | 2.8 KB | 🗑️ HUÉRFANO | **Duplicado exacto de `icon-white.png`** (mismo tamaño byte-a-byte). Tampoco se usa |
| `logo-horizontal-dark.png` | 19.9 KB | 🗑️ HUÉRFANO | Solo la variante `-white` se referencia |
| `logo-light.png` | 1.4 MB | 🗑️ HUÉRFANO | Grandisísimo y no referenciado. Probablemente asset de marca viejo |
| `hero-dashboard.png` | 125 KB | 🗑️ HUÉRFANO | Reemplazado por `hero-setup-transparent.png`. Sin referencias |
| `hero-database.png` | 222 KB | 🗑️ HUÉRFANO | Reemplazado por `hero-setup-transparent.png`. Sin referencias |
| `option-A-dashboard-heatmap-master.jpg` | 509 KB | 🗑️ HUÉRFANO | Boceto de hero antiguo |
| `option-A-dashboard-heatmap-web.jpg` | 127 KB | 🗑️ HUÉRFANO | Versión web del anterior |
| `option-B-dashboard-database-master.jpg` | 582 KB | 🗑️ HUÉRFANO | Boceto de hero antiguo |
| `option-B-dashboard-database-web.jpg` | 154 KB | 🗑️ HUÉRFANO | Versión web del anterior |
| `Dashboard.png` | 186 KB | 🗑️ HUÉRFANO | Screenshot / preview, no referenciado |
| `Deal Database.png` | 251 KB | 🗑️ HUÉRFANO | Screenshot / preview, no referenciado |
| `Heatmap 2D.png` | 217 KB | 🗑️ HUÉRFANO | Screenshot / preview, no referenciado |
| `Heatmap 3D.png` | 198 KB | 🗑️ HUÉRFANO | Screenshot / preview, no referenciado |
| `GP Players.xlsx` | 20 KB | 🗑️ HUÉRFANO | Source data antigua — ahora vive en Supabase |
| `Players PE Funds.xlsx` | 109 KB | 🗑️ HUÉRFANO | Source data antigua — ahora vive en Supabase |

Total probable a liberar si se borran todos los huérfanos: **~4.2 MB** (principalmente `logo-light.png`, `option-*-master.jpg`, y el PDF si se decide comprimir).

---

## 2. Carpetas

| Carpeta | Estado | Razón |
|---|---|---|
| `.git/` | ✅ ACTIVO | Metadata git |
| `.claude/` | ❓ DUDA | Config local de Claude Code (`settings.local.json`). **Debería estar en `.gitignore`** y no tracked. Checar `git ls-files .claude` |
| `data/` | ❓ DUDA | **Vacía** actualmente. El seeder (`supabase/seed.js:L44, L74, L101`) lee de `data/deals.json`, `data/players.json`, `data/pe-funds.json` — esos archivos viven en la carpeta local (`DealFlow Perspectives/deals.json`, etc.). Decidir: (a) mover los JSON al repo bajo `data/` y gitignorar, (b) borrar la carpeta si el seeding ya es histórico |
| `node_modules/` | ✅ (gitignored) | Existe en disco, ignorado por git. Puede reinstalarse con `npm install` |
| `supabase/` | ✅ ACTIVO | Contiene `migration.sql` (tracked) y `seed.js` (gitignored por contener service_role key en runtime) |

---

## 3. Items en `.gitignore` — revisar

Archivo (`.gitignore`):
```
node_modules/
.DS_Store
Thumbs.db
.env
.env.local
supabase/seed.js
.vscode/
.idea/
dealflowperspectives.com
```

Notas:
- **`dealflowperspectives.com`** está gitignored pero **no existe en disco** — parece un leftover del scaffolding. Seguro borrar la línea.
- `.claude/` **no está gitignored**. Si `settings.local.json` se subió al remote, puede estar exponiendo config del usuario. Verificar con `git ls-files .claude`.

---

## 4. Acciones sugeridas (NO ejecutadas en este audit)

1. **Eliminar los 16 huérfanos listados arriba** — liberan ~4 MB del repo y reducen confusión.
2. **Decidir `data/`** — si se va a re-seedear o si los JSON son sacrosantos, moverlos al repo bajo `data/` gitignored; sino borrar la carpeta vacía.
3. **Añadir `.claude/` a `.gitignore`** si `git ls-files .claude` devuelve algo.
4. **Comprimir el PDF de 2.6 MB** — prueba con `gs -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook` o similar, suele bajar 40–60% en PDFs con imágenes.
5. **Consolidar logos** — decidir si mantener `logo-horizontal-white.png` (en uso) + una variante dark, y eliminar los demás.
6. **Versionar las migrations de access-control** — crear `supabase/migration_002_access_control.sql` con `admin_accounts`, `demo_requests`, `demo_surveys`, `blocked_email_domains` (ver `DATA_MODEL.md` §2).

> Todos los cambios quedan pendientes de confirmación explícita. Este doc solo clasifica.
