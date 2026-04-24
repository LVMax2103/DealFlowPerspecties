# LOCAL_FOLDER_AUDIT — `DealFlow Perspectives/`

Carpeta padre fuera del repo: `C:\Users\maxel\OneDrive\Escritorio\Proyectos\DealFlow Perspectives\`.

Propósito: documentar qué hay y proponer estructura. **Nada se mueve ni borra en este audit**.

---

## 1. Inventario actual (top level)

### Archivos sueltos

| Archivo | Tamaño | Categoría sugerida |
|---|---|---|
| `Agenda de players.xlsx` | 8.6 KB | research-raw |
| `Banco de preguntas Daniel Adquiere.Co.docx` | 18 KB | comms / invitados |
| `Bloque 3 de Noticias.docx` | 57.8 KB | content-blocks |
| `Bloque 4 Noticias.docx` | 16.3 KB | content-blocks |
| `Bloque 5.docx` | 20.3 KB | content-blocks |
| `Bloque 6.docx` | 19.2 KB | content-blocks |
| `Bloque 7.docx` | 18.1 KB | content-blocks |
| `DFP_LinkedIn_Posts_EN_FINAL_Bloque 7.docx` | 48.9 KB | content-blocks / linkedin |
| `DealFlow_Perspectives_Database.xlsx` | 33.9 KB | dataset-versions |
| `DealFlow_Perspectives_Database_Updated.xlsx` | 48.2 KB | dataset-versions |
| `DealFlow_Perspectives_Database_Updated_B7.xlsx` | 50.98 KB | dataset-versions |
| `DealFlow_Perspectives_Database_V9.xlsx` | 73.5 KB | dataset-versions **(último / actual?)** |
| `Fondo LinkledIn.png` | 2.6 MB | assets-brand |
| `Logo Noticas 2.png` | 2.4 MB | assets-brand |
| `Logo Noticias.png` | 2.3 MB | assets-brand |
| `Long Term Capital Assumptions 2026 JPM Asset M.pdf` | 7.1 MB | research-raw |
| `Noticas Bloque 1 DealFlow Perspectives.docx` | 22.6 KB | content-blocks |
| `Perfil LinkedIn.png` | 1.5 MB | assets-brand |
| `Presentation_Deck_for_Mexico_City_Event_on_December_10th_20.pdf` | 6.8 MB | events |
| `Publicación 1 Scotia DFP.xlsx` | 33.1 KB | linkedin / scotia |
| `SF IESE 2016.pdf` | 429 KB | research-searchfund |
| `Scotia EcoPack 1.png` … `Scotia EcoPack 4.png` | 63–95 KB c/u | linkedin / scotia |
| `Top-Performing Private Equity Funds (IRR) — Active Investing Status (1).zip` | **205 MB** | exports / zips |
| `Top-Performing Private Equity Funds (IRR) — Active Investing Status.zip` | **205 MB** | exports / zips **(duplicado del anterior?)** |
| `UBS Year Ahead 2026.pdf` | 3.8 MB | research-raw |
| `deals.json` | 95 KB | seed-data (consumido por `supabase/seed.js`) |
| `demo-access-frontend.md` | 27 KB | docs-dev |
| `demo-access-migration.sql` | 5 KB | **supabase-migrations (no está en el repo, DEBERÍA)** |
| `desktop.ini` | 330 B | OneDrive meta — gitignore natural |
| `dfp-home-prototype-v2.zip` | 1 MB | prototypes |
| `favicon-192x192.png`, `favicon.png` | 3.3 KB | assets-brand (duplicados con repo) |
| `fix-logout-watchlist.md` | 6 KB | docs-dev |
| `fix-watchlist-logo-macro.md` | 13.6 KB | docs-dev |
| `hero-dashboard.png` | 125 KB | assets-brand (= repo huérfano) |
| `hero-database.png` | 222 KB | assets-brand (= repo huérfano) |
| `hero-setup-transparent Master.png` | 999 KB | assets-brand (master version del activo) |
| `hero-setup-transparent.png` | 999 KB | assets-brand (duplicado del repo) |
| `home-redesign.md` | 20.6 KB | docs-dev |
| `icon-white.png`, `icon-white_1.png` | 2.8 KB | assets-brand (duplicados) |
| `is-it-a-bubble.pdf` | 651 KB | research-raw |
| `logo-dark.png` | 1.4 MB | assets-brand |
| `logo-horizontal-dark.png`, `logo-horizontal-white.png` | 20–36 KB | assets-brand |
| `logo-light.png` | 1.4 MB | assets-brand |
| `navbar-dropdowns.md` | 13.3 KB | docs-dev |
| `new-chat-context.md` | 7.1 KB | docs-dev / prompt-history |
| `option-A-*.jpg`, `option-B-*.jpg` | 127–582 KB c/u | assets-brand (propuestas viejas) |
| `pe-funds.json` | 258 KB | seed-data |
| `phase1-claude-code-prompt.md` | 6.3 KB | docs-dev / prompt-history |
| `phase2-supabase-migration.md` | 28.9 KB | docs-dev |
| `phase2.5-security-hardening.md` | 28.9 KB | docs-dev |
| `players.json` | 130.7 KB | seed-data |

### Subcarpetas

| Carpeta | Contenido | Categoría |
|---|---|---|
| `FO UBS 2025/` | 12 imágenes PNG + Excel + PDF + DOCX sobre el reporte UBS Family Office 2025 | research-raw |
| `GitHub/` | **El repo activo** — `DealFlowPerspecties_website/` | code |
| `Invitados/` | Bios de speakers, PDFs y DOCX con preguntas | comms / invitados |
| `Post LinkedIn/` | 201 PNG numerados (1.png…202.png) | linkedin / posts |
| `Post PE funds IRR/` | 17 imágenes de una publicación específica | linkedin / posts |
| `SS de DFP/` | 4 screenshots de la UI (Dashboard, Database, Heatmap 2D/3D) + desktop.ini | assets-screenshots |
| `Search Fund/` | PDFs IESE, análisis, fotos | research-searchfund |

---

## 2. Duplicaciones y riesgos

1. **ZIPs de 205 MB × 2** = 410 MB en duplicados probables. Confirmar con checksum antes de decidir (`certutil -hashfile <file> MD5`).
2. **`demo-access-migration.sql` (local) no está en el repo**. Este archivo probablemente contiene las migraciones de `admin_accounts`, `demo_requests`, `demo_surveys`, `blocked_email_domains` que `DATA_MODEL.md` §2 marca como "no versionadas en repo". **Revisar y versionar**.
3. **Varios `.md` de fixes históricos** (`fix-logout-watchlist.md`, `fix-watchlist-logo-macro.md`, `home-redesign.md`, `phase2-*.md`) — documentación de sprints pasados. Útil para histórico, no para vida-activa.
4. **Duplicados brand asset** entre local y repo (`favicon*.png`, `hero-setup-transparent.png`, `icon-white.png`, `logo-*.png`). La carpeta local es la "fuente cruda" y el repo la "producción". OK mientras sea explícito.
5. **4 versiones del Excel** `DealFlow_Perspectives_Database_*.xlsx` — confirmar cuál es el activo (probablemente `_V9.xlsx`) y archivar las anteriores.
6. **`Scotia EcoPack 1–4.png` + `Publicación 1 Scotia DFP.xlsx`** — parecen de un cliente/sponsor; revisar si deben aislarse por confidencialidad.
7. **201 PNGs sueltos en `Post LinkedIn/`** — ya están en carpeta, OK. Podrían subordinarse a `linkedin/posts/` para consistencia con la nueva estructura.

---

## 3. Estructura propuesta (plan, nada se mueve aún)

```
DealFlow Perspectives/
├── GitHub/                          # intacto, repo + sibling repos
│   └── DealFlowPerspecties_website/
│
├── research/                        # todo lo consumido, no producido, por DFP
│   ├── ubs-fo-2025/                 # = "FO UBS 2025/" renombrado
│   ├── search-fund/                 # = "Search Fund/"
│   ├── jpm/
│   │   └── long-term-capital-assumptions-2026.pdf
│   ├── ubs/
│   │   └── year-ahead-2026.pdf
│   └── pe-irr-report/
│       ├── full-report-v1.zip       # decidir cuál de los dos zips queda
│       └── sf-iese-2016.pdf
│
├── content/                         # producido por DFP
│   ├── news-blocks/                 # = "Bloque 1…7.docx"
│   └── linkedin/
│       ├── posts/                   # = "Post LinkedIn/" (201 PNGs)
│       ├── pe-funds-irr-post/       # = "Post PE funds IRR/"
│       ├── scotia-ecopack/          # = los 4 PNG + Publicación 1 Scotia.xlsx
│       └── bloque-7-final/          # = "DFP_LinkedIn_Posts_EN_FINAL_Bloque 7.docx"
│
├── assets-raw/                      # imágenes master, fuentes, logos
│   ├── logos/                       # logo-dark/light/horizontal-*/
│   ├── hero/                        # hero-setup-transparent Master.png, option-A/B-*
│   ├── brand/                       # Fondo LinkedIn, Perfil LinkedIn, Logo Noticias
│   └── icons/                       # favicon, icon-white
│
├── screenshots/                     # = "SS de DFP/" renombrado
│
├── data/                            # fuentes de datos del producto
│   ├── seed/                        # deals.json, players.json, pe-funds.json
│   ├── database-versions/           # DealFlow_Perspectives_Database_*.xlsx (histórico)
│   └── misc/                        # GP Players.xlsx, Players PE Funds.xlsx
│
├── comms/
│   ├── invitados/                   # = "Invitados/"
│   └── eventos/                     # Presentation_Deck_for_Mexico_City_*.pdf
│
├── docs-dev/                        # notas técnicas de sprints
│   ├── phase1-claude-code-prompt.md
│   ├── phase2-supabase-migration.md
│   ├── phase2.5-security-hardening.md
│   ├── home-redesign.md
│   ├── navbar-dropdowns.md
│   ├── fix-logout-watchlist.md
│   ├── fix-watchlist-logo-macro.md
│   ├── demo-access-frontend.md
│   ├── demo-access-migration.sql   ← MOVER AL REPO `supabase/migration_002.sql`
│   └── new-chat-context.md
│
├── prototypes/
│   └── dfp-home-prototype-v2.zip
│
└── archive/                         # todo lo viejo / no seguro de borrar
    └── (cosas que no sabemos si descartar)
```

---

## 4. Reglas que propongo antes de ejecutar mudanzas

1. **No borrar nada en esta fase**. Mover es reversible; borrar no.
2. **Checksum antes de decidir duplicados** — sobre todo los dos ZIPs de 205 MB.
3. **Extraer `demo-access-migration.sql` al repo** como `supabase/migration_002_access_control.sql` antes de mover — es el único que realmente cambia de ubicación crítica.
4. **Mantener OneDrive-friendly** (los `desktop.ini` son metadata de OneDrive; ignorarlos pero no borrarlos).
5. **Confirmar `_V9.xlsx` es el activo** antes de mover las 3 versiones anteriores a `archive/`.
