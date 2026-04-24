# DATA_MODEL — Supabase backend

Project ref: `hmrtcvxcdgcuvbmvpetd` (visible en `index.html:L3310`).

8 tablas. Las 4 "core" (deals, players, pe_funds, user_preferences) están definidas en `supabase/migration.sql`. Las 4 "access-control" (demo_requests, demo_surveys, admin_accounts, blocked_email_domains) **no están en el repo** — fueron creadas a mano en el dashboard de Supabase, y su esquema se infiere del uso en `index.html`.

---

## 1. Tablas core — `supabase/migration.sql`

### `deals` (≈277 filas según brief)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | SERIAL PRIMARY KEY | |
| `deal_name` | TEXT NOT NULL | |
| `category` | TEXT | PE / VC / M&A / Real Assets / Private Credit |
| `investor_buyer` | TEXT | |
| `target_company` | TEXT | |
| `country` | TEXT | |
| `sector` | TEXT | |
| `deal_value_usd_m` | NUMERIC | nullable |
| `local_currency` | TEXT | |
| `notes` | TEXT | |
| `period` | TEXT | |
| `created_at` | TIMESTAMPTZ | default NOW() |

**Índices**: `category`, `country`, `deal_value_usd_m DESC NULLS LAST` (`migration.sql:L109–L111`).

**RLS**: `"Authenticated users can read deals"` — `SELECT` para rol `authenticated`, `USING (true)`. Sin INSERT/UPDATE/DELETE públicos.

**Frontend consumers**:
- `loadData()` en `index.html:L3923–L3926` — SELECT * ordenado por `deal_value_usd_m DESC`, mapeado a camelCase en `allDeals`.
- Dashboard KPIs, Category Breakdown, Country Grid, Top Deals, Deal Database table, 3D globe, 2D map, Country drilldown modal — todos leen de `allDeals` en memoria.

---

### `players` (≈591 filas)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | SERIAL PRIMARY KEY | |
| `name` | TEXT NOT NULL | |
| `aum_display` | TEXT | e.g. `"$2.3B"` |
| `aum_numeric` | NUMERIC | en millones USD |
| `active_funds` | INTEGER | |
| `total_funds` | INTEGER | |
| `active_holdings` | INTEGER | |
| `total_holdings` | INTEGER | |
| `addresses` | INTEGER | |
| `created_at` | TIMESTAMPTZ | default NOW() |

**Índices**: `name`, `aum_numeric DESC NULLS LAST`.

**RLS**: `SELECT` para `authenticated`, `USING (true)`.

**Frontend consumers**:
- `loadPlayers()` en `index.html:L5264–L5267` — lazy, al entrar a sección `players`.
- Populates `allPlayers`, consumido por tabla + Player Modal (Bloomberg DES).

---

### `pe_funds` (≈1094 filas)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | SERIAL PRIMARY KEY | |
| `fund` | TEXT NOT NULL | |
| `gp` | TEXT | general partner |
| `vintage` | INTEGER | año |
| `size` | TEXT | e.g. `"500M"` |
| `status` | TEXT | active / fully realized / etc. |
| `irr` | NUMERIC | |
| `quartile` | TEXT | Q1 / Q2 / ... |
| `countries` | TEXT[] | array de países |
| `created_at` | TIMESTAMPTZ | default NOW() |

**Índices**: `irr DESC NULLS LAST`, `gp`.

**RLS**: `SELECT` para `authenticated`, `USING (true)`.

**Frontend consumers**:
- `loadPEFunds()` en `index.html:L5567–L5570` — lazy, al entrar a sección `pefunds`. Ordena por `irr DESC`.
- Pobla `allFunds`, consumido por tabla, KPIs, tabs (All / Top Quartile / ...), charts canvas.

---

### `user_preferences`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | UUID PK | default `gen_random_uuid()` |
| `user_id` | UUID FK `auth.users(id) ON DELETE CASCADE` NOT NULL | UNIQUE |
| `panel_layout` | JSONB | default `'{}'` — layout del dashboard resizable |
| `market_favorites` | TEXT[] | default `'{}'` — tickers favoritos |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

**Índice**: `user_id`.

**RLS** (estrictas, por usuario):
- `"Users can read own preferences"` — `SELECT` con `auth.uid() = user_id`.
- `"Users can insert own preferences"` — `INSERT` con `auth.uid() = user_id`.
- `"Users can update own preferences"` — `UPDATE` con `auth.uid() = user_id`.
- **No hay DELETE policy.** (cascade desde `auth.users` cubre eliminación de cuenta).

**Frontend consumers**:
- `loadPreferencesFromSupabase()` — `index.html:L6188–L6192` — SELECT donde `user_id = auth.uid()`, `.maybeSingle()`.
- `syncPreferencesToSupabase()` — `index.html:L6161–L6166` — UPSERT con `onConflict: 'user_id'`.
- Disparos: después de toggle de favorito (L6144), después de resize de panel (L4944), al logout (L3663), al login (L3530).

---

## 2. Tablas de acceso / compliance (inferidas del código cliente)

Estas 4 tablas **no están en `supabase/migration.sql`**. Viven solo en el proyecto de Supabase. El esquema documentado abajo es el **inferido** del uso.

### `admin_accounts` — whitelist de admins

**Columnas mínimas inferidas** (`index.html:L3351–L3357`):
- `email` TEXT (PK o UNIQUE) — clave de lookup
- `codename` TEXT — e.g. `"TRON"`
- `role` TEXT — e.g. `"developer"`

**RLS observable**: la query `supabase.from('admin_accounts').select('codename, role').eq('email', user.email)` con el ANON_KEY + sesión de usuario autenticado devuelve el row del propio usuario. Esto implica **una de**:
- RLS enabled con policy `authenticated` que hace `USING (email = auth.jwt()->>'email')`.
- RLS enabled con policy permisiva `USING (true)` para `authenticated`.
- RLS disabled (público).

> **Riesgo**: si la policy es `USING (true)`, cualquier usuario autenticado puede listar todos los admins — p.ej. filtrando por email de otro. No auditable desde el código cliente.

**Frontend consumers**:
- `checkDemoAccess(user)` — `index.html:L3350–L3358` (único lookup).

---

### `demo_requests` — solicitudes de acceso al demo

**Columnas mínimas inferidas**:

Leídas (`index.html:L3361–L3365`):
- `email` TEXT — clave de lookup (probablemente UNIQUE)
- `status` TEXT — `'pending'` / `'approved'` / `'expired'` (observados)
- `expires_at` TIMESTAMPTZ
- `approved_at` TIMESTAMPTZ

Escritas en el request-demo form (`index.html:L6528–L6546`):
- `email`, `name`, `country`, `role_title`, `request_type` (`'individual'` | `'institutional'`), `company`, `company_url`, `num_accounts`, `industry`

**RLS observable**:
- `INSERT` abierto con ANON_KEY (el form público funciona sin sesión).
- `SELECT` que devuelve al propio usuario autenticado (por `email = user.email`), probablemente `USING (email = auth.jwt()->>'email')`.
- Conflict por duplicado manejado con código `23505` (`index.html:L6549`).

> **Riesgo**: INSERT abierto sin rate-limit server-side permite spam. Mitigado débilmente por `blocked_email_domains` y el `rateLimitCheck` del cliente (bypasseable).

**Frontend consumers**:
- `checkDemoAccess` — `index.html:L3361–L3365` — SELECT.
- Request Demo form submit — `index.html:L6546` — INSERT.

---

### `demo_surveys` — feedback al expirar acceso

**Columnas mínimas inferidas** (`index.html:L6608–L6616`):
- `user_id` UUID — FK a `auth.users.id`
- `email` TEXT
- `rating` INTEGER (1–5 estrellas)
- `sections_used` TEXT[] — array de secciones marcadas en el form
- `desired_data` TEXT
- `comments` TEXT
- `privacy_accepted` BOOLEAN

**RLS observable**: `INSERT` para `authenticated` (el form está dentro del `expiredOverlay`, visible solo cuando hay sesión). No se hace SELECT desde el cliente.

**Frontend consumers**:
- Survey form submit — `index.html:L6608`.

---

### `blocked_email_domains` — lista negra de proveedores de email desechables

**Columnas mínimas inferidas** (`index.html:L6511–L6515`):
- `domain` TEXT (PK o UNIQUE)

**RLS observable**: `SELECT` público (el lookup corre **antes** del INSERT a `demo_requests`, sin sesión). Probablemente `USING (true)` con rol `anon`.

**Frontend consumers**:
- Request Demo form pre-check — `index.html:L6511–L6515` — SELECT por `domain`.

---

## 3. Mapa tabla → sección UI

| Tabla | Home | Dashboard | Database | Players | PE Funds | Heatmap | Markets | Auth / Modales |
|---|---|---|---|---|---|---|---|---|
| `deals` | stats | ✓ (KPIs, Category, Country, Top) | ✓ | | | ✓ (globe + map + drill) | | |
| `players` | | | | ✓ | | | | |
| `pe_funds` | | | | | ✓ | | | |
| `user_preferences` | | layout, watchlist | | | | | favoritos | sync en sign-in |
| `admin_accounts` | | | | | | | | `_updateNavBrand` → `checkDemoAccess` |
| `demo_requests` | | | | | | | | gate de sección + `_updateNavBrand` + form insert |
| `demo_surveys` | | | | | | | | `expiredOverlay` form |
| `blocked_email_domains` | | | | | | | | pre-check del request-demo form |

---

## 4. Auth — `auth.users` (managed por Supabase)

No se lee directamente desde el cliente. Las columnas relevantes accesibles via `supabase.auth.getUser()`:

- `id` UUID
- `email` TEXT
- `user_metadata.first_name`, `user_metadata.last_name` — set en sign-up (`index.html:L3624–L3628`)
- Session / token fields manejados por Supabase JS en `localStorage` con key `sb-hmrtcvxcdgcuvbmvpetd-auth-token`.

---

## 5. Gaps / dudas del modelo

1. **`admin_accounts`, `demo_requests`, `demo_surveys`, `blocked_email_domains` no tienen migration versionada** — vivir solo en la UI de Supabase es un riesgo de drift. Propuesta: crear `supabase/migration_002_access_control.sql` con el schema real (requiere `pg_dump` o revisar el Table Editor).
2. **`expires_at` computation** — el código cliente asume `expires_at` es set server-side (probablemente por un trigger al cambiar `status → 'approved'`). No verificable desde el cliente.
3. **¿Quién cambia `demo_requests.status`?** — el cliente solo hace INSERT. `status` cambia a `'approved'` manualmente en el dashboard de Supabase, o vía una Edge Function no visible en el repo.
4. **Emails de aprobación** — el mensaje del form dice "You will receive an invitation email once approved" (L6568), pero no hay código de email en el repo. Probablemente una Supabase Auth invite link generada en el dashboard.
5. **`ADMIN_EMAILS` array dead** — `index.html:L3423` declara `['elenesmaximiliano@gmail.com']` pero nunca se lee. Mantener sincronizado con `admin_accounts` o eliminar.
