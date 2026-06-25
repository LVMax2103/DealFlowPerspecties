# DealFlow Perspectives — Phase 3 Design Document

**Version:** 2.1 (Final)
**Status:** Approved by TRON — ready for Claude Code handoff
**Date:** June 1, 2026
**Target branch:** `main`
**Depends on:** Phase 1/2 auth contract (commit `9cdd2d6`), `/docs/AUTH_FLOW.md`, `/docs/REFRESH_LOGOUT_DESIGN.md`

---

## Changelog from v1

**v2.0 → v2.1:** LinkedIn CTA points to the company page (`https://www.linkedin.com/company/dealflow-perspectives`), not the founder's personal LinkedIn. Secret renamed `FOUNDER_LINKEDIN_URL` → `COMPANY_LINKEDIN_URL`. Keeps DFP inquiries separate from personal channel and aligns with the team-signature voice on most lead-facing emails.

**v1 → v2:**

- **Language rule locked**: 100% English across all UI, emails, error messages, and form labels (no Spanish, no bilingual).
- **Expiration clock**: starts at **approval time**, not first login.
- **Rejection emails**: now sent (previously silent). Polite institutional tone, signed by team.
- **Email signatures**: personal signature ("Maximiliano Elenes, Founder") only on the credentials email. All other emails signed by "The DealFlow Perspectives Team".
- **Form fields**: organization type added as a required dropdown; AUM, Ticket Size, and Fund Stage are conditional fields.
- **Extension messaging**: lead is directed to LinkedIn DM (not in-app form) to request an extension.
- **Form placement**: "Request Access" CTA in navbar, positioned just before the existing "Subscribe to our newsletter" item.

---

## 1. Objective

Phase 3 introduces controlled access to DFP.com via a manual approval flow with time-bound demo credentials. The entire system is self-hosted: no new SaaS dependencies beyond Supabase (already in stack) and Gmail SMTP via the founder's existing Gmail account.

## 2. In Scope

- Public demo request form with conditional fields (modal accessible from landing)
- Admin inbox at `/admin/requests` with realtime updates
- Approve / reject flow with auto-generated temporary credentials
- 7-day expiration on demo accounts (clock starts at approval)
- Email notifications via Gmail SMTP (founder's Gmail + app password)
- CLU role (second admin, operational tier)
- Data foundation for future paid client tier (model only, no UI)

## 3. Out of Scope — Parking Lot

- Paid client tier UI and billing
- Self-service signup (always manual approval)
- Password recovery for demo accounts (regenerate manually if needed)
- CLU UI for editing public content (Phase 4+)
- Automated lead scoring / qualification
- Multi-language UI
- "DFP in Action" Bloomberg-style interface (Phase 4)
- In-app extension requests (handled via LinkedIn DM by design)

## 4. Closed Decisions

1. **Email transport:** Gmail SMTP using `elenesmaximiliano@gmail.com` with app password. No external SaaS (no Resend, SendGrid, Mailgun).
2. **Notifications:** both email to TRON AND realtime in-app dashboard.
3. **Credential delivery:** hybrid — system auto-emails credentials to lead, TRON sees them once in the UI for record.
4. **CLU implementation:** single account today, but built as a `role='admin'` field that supports multiple admins in the future without refactor.
5. **TRON migration:** TRON account stays as-is. New fields default to NULL = "no expiration, autocreated".
6. **Admin creation:** only TRON can create other admins; CLU cannot.
7. **Expiration clock:** starts at approval, runs 7 days regardless of whether lead logs in.
8. **Extensions:** default +7 days per extension, performed manually by admin after lead requests via LinkedIn DM.
9. **Language:** 100% English everywhere user-facing.

---

## 5. Data Model

### 5.1 Table: `demo_requests` (NEW)

| Column | Type | Notes |
|---|---|---|
| `id` | uuid (pk) | default `gen_random_uuid()` |
| `created_at` | timestamptz | default `now()` |
| `full_name` | text | required |
| `email` | text | required, lowercase, indexed |
| `company` | text | required |
| `role_title` | text | required (e.g., "Director of M&A") |
| `linkedin_url` | text | optional |
| `country` | text | required |
| `organization_type` | text | required, enum: `mfo` \| `fund` \| `corporate` \| `individual` \| `other` |
| `aum_range` | text | conditional: required if `organization_type IN ('mfo', 'fund')` |
| `ticket_size_range` | text | conditional: required if `organization_type IN ('mfo', 'fund')` |
| `fund_stage` | text | conditional: required only if `organization_type='fund'` |
| `motivation` | text | required, min length 20 chars |
| `status` | text | enum: `pending` \| `approved` \| `rejected` — default `pending` |
| `reviewed_by` | uuid (fk profiles.id) | nullable until reviewed |
| `reviewed_at` | timestamptz | nullable |
| `internal_notes` | text | TRON/CLU only |
| `created_profile_id` | uuid (fk profiles.id) | populated when approved |

**Enums:**

- `aum_range`: `under_1m`, `1m_5m`, `5m_10m`, `10m_20m`, `over_20m`
- `ticket_size_range`: `under_100k`, `100k_500k`, `500k_1m`, `1m_5m`, `over_5m`
- `fund_stage`: `seed`, `growth`, `buyout`, `mezzanine`, `distressed`, `multi_strategy`, `other`

**Constraints:**

- Unique partial index: `(email) WHERE status='pending'` — prevents duplicate pending requests
- Email format check via regex
- `motivation` minimum length 20 chars
- Check constraint: `aum_range` and `ticket_size_range` must be NOT NULL when `organization_type IN ('mfo', 'fund')`
- Check constraint: `fund_stage` must be NOT NULL when `organization_type='fund'`

### 5.2 Table: `profiles` (EXTEND existing)

New columns:

| Column | Type | Notes |
|---|---|---|
| `role` | text | enum: `admin` \| `demo` \| `client` — default `demo` |
| `expires_at` | timestamptz | NULL = never expires (admins only) |
| `is_active` | boolean | default `true` |
| `approved_by` | uuid (fk profiles.id) | NULL for TRON (autocreated) |
| `approved_at` | timestamptz | NULL for TRON |
| `demo_request_id` | uuid (fk demo_requests.id) | NULL for TRON |
| `first_login_at` | timestamptz | NULL until lead first logs in (analytics only — does NOT control expiration) |
| `expiry_warning_sent_at` | timestamptz | NULL until day-6 warning email fires |

**TRON migration SQL:**

```sql
UPDATE profiles
SET role = 'admin', is_active = true
WHERE email = '<TRON_email>';
-- expires_at, approved_by, approved_at, demo_request_id, first_login_at stay NULL
```

### 5.3 Table: `audit_log` (NEW)

| Column | Type | Notes |
|---|---|---|
| `id` | uuid (pk) | |
| `created_at` | timestamptz | default `now()` |
| `actor_id` | uuid (fk profiles.id) | who did it, NULL for system actions |
| `action` | text | enum (see below) |
| `target_type` | text | enum: `demo_request` \| `profile` |
| `target_id` | uuid | |
| `metadata` | jsonb | extra context |

Action enum: `request_submitted`, `request_approved`, `request_rejected`, `account_extended`, `account_revoked`, `account_expired`, `login_success`, `login_blocked_expired`.

Indexed by `actor_id`, `target_id`, `created_at`.

---

## 6. State Machine: Demo Request Lifecycle

```
[lead submits form]
        |
        v
   +---------+
   | pending | <-- visible in /admin/requests, TRON receives email
   +----+----+
        |
        +--- TRON rejects ---> rejection email to lead --> +----------+
        |                                                  | rejected |
        |                                                  +----------+
        |
        +--- TRON approves ---> creates profile, generates password,
                                expires_at = now() + 7 days,
                                credentials email to lead
                                       |
                                       v
                                  +----------+
                                  | approved |
                                  +----------+
                                       |
                                       v
                               [profile lifecycle begins]
```

## 7. State Machine: Profile Lifecycle (demo accounts)

```
   [approval moment]
          |
          |  expires_at = approval_time + 7 days
          |  first_login_at = NULL
          v
   +--------------+
   | active       |
   +------+-------+
          |
          +-- first login                  --> first_login_at = now() (tracking only)
          +-- 24h before expiration        --> warning email to lead
          +-- admin extends (+7 days)      --> expires_at += 7 days
          +-- admin revokes                --> is_active = false
          +-- expires_at < now()           --> pg_cron sets is_active = false
                                                login blocked with LinkedIn DM CTA
```

**Belt-and-suspenders:** `is_active = false` AND `expires_at < now()` both independently block login.

---

## 8. Permission Matrix

| Action | TRON | CLU | Demo | Guest |
|---|---|---|---|---|
| View public landing | yes | yes | yes | yes |
| Submit demo request | — | — | — | yes |
| Login | yes | yes | yes (until expired) | — |
| View demo content | yes | yes | yes | — |
| Access `/admin/requests` | yes | yes | — | — |
| Approve / reject requests | yes | yes | — | — |
| Extend account expiration | yes | yes | — | — |
| Revoke account | yes | yes | — | — |
| Manage other admins (create CLU) | yes | — | — | — |
| View audit log | yes | yes (read-only) | — | — |
| Edit Supabase config | yes | — | — | — |
| Edit code / deploy | yes | — | — | — |

TRON-only dev/infra powers live outside the app — enforced by GitHub repo access, Supabase project access, Cloudflare credentials. Not by app code.

---

## 9. Public Demo Request Form

### 9.1 Placement

CTA button labeled **"Request Access"** added to the navbar, positioned immediately before the existing "Subscribe to our newsletter" item (which is currently last). Clicking opens a centered modal overlaying the landing page.

### 9.2 Fields & Conditional Logic

**Always-required fields (in this order):**

1. Full Name — text input
2. Email — email input, lowercase normalization
3. Company — text input
4. Role / Title — text input (placeholder: *"e.g. Director of M&A"*)
5. LinkedIn URL — text input (optional, placeholder: *"https://linkedin.com/in/..."*)
6. Country — text input or dropdown
7. **Organization Type** — required dropdown:
   - Multi-Family Office
   - Investment Fund / Asset Manager
   - Corporate
   - Individual / Family Office
   - Other

**Conditional fields (appear when Organization Type = "Multi-Family Office" OR "Investment Fund / Asset Manager"):**

8. AUM — required dropdown:
   - Under $1M
   - $1M – $5M
   - $5M – $10M
   - $10M – $20M
   - Over $20M

9. Typical Ticket Size — required dropdown:
   - Under $100K
   - $100K – $500K
   - $500K – $1M
   - $1M – $5M
   - Over $5M

**Conditional field (appears only when Organization Type = "Investment Fund / Asset Manager"):**

10. Fund Stage — required dropdown:
    - Seed
    - Growth
    - Buyout
    - Mezzanine
    - Distressed
    - Multi-strategy
    - Other

**Always-required final field:**

11. Motivation — textarea, min 20 characters, placeholder: *"Briefly describe why you're interested in DealFlow Perspectives and how you plan to use the platform."*

### 9.3 Post-Submit Confirmation

After successful submit, the modal swaps to a success screen with this exact copy:

> **Thanks, we received your request.**
> We'll review your information and get back to you soon.

A close button dismisses the modal and returns to the landing page.

### 9.4 Error Handling

- Email format invalid → inline error: *"Please enter a valid email address."*
- Duplicate pending request → inline error: *"We already have a pending request from this email."*
- Motivation under 20 chars → inline error: *"Please provide a brief description (minimum 20 characters)."*
- Missing required conditional field → inline error per field
- Network/server error → modal-level error: *"Something went wrong. Please try again in a moment."*

---

## 10. Architecture: Email via Gmail SMTP

### Why this approach

GitHub Pages is static hosting (no server). To send email, we need a server-side runtime. Supabase Edge Functions (Deno-based, hosted by Supabase) fill that role without adding a new vendor.

### Components

1. **Supabase Database Webhook** — triggers on insert to `demo_requests`.
2. **Supabase Edge Function** `send-request-notification` — receives the webhook, formats and sends two emails (TRON + lead auto-reply).
3. **Supabase Edge Function** `send-approval-email` — called when TRON approves; sends credentials to lead.
4. **Supabase Edge Function** `send-rejection-email` — called when TRON rejects; sends rejection notice to lead.
5. **Supabase Edge Function** `send-expiry-warning` — called by `pg_cron`; sends 24h warning to lead.
6. **Gmail SMTP** — `smtp.gmail.com:465` with app password authentication.
7. **Secrets** — stored in Supabase Vault: `GMAIL_USER`, `GMAIL_APP_PASSWORD`, `COMPANY_LINKEDIN_URL`.

### One-time setup (founder)

1. Enable 2FA on `elenesmaximiliano@gmail.com` if not already.
2. Generate Gmail App Password at https://myaccount.google.com/apppasswords (name it "DFP.com").
3. Copy the 16-char password.
4. Set Supabase secrets:
   ```bash
   supabase secrets set GMAIL_USER=elenesmaximiliano@gmail.com
   supabase secrets set GMAIL_APP_PASSWORD=<paste-16-char>
   supabase secrets set COMPANY_LINKEDIN_URL=https://www.linkedin.com/company/dealflow-perspectives
   ```
5. Deploy Edge Functions:
   ```bash
   supabase functions deploy send-request-notification
   supabase functions deploy send-approval-email
   supabase functions deploy send-rejection-email
   supabase functions deploy send-expiry-warning
   ```

### Email signature policy

| Email | Signature |
|---|---|
| Auto-reply to lead (request received) | *The DealFlow Perspectives Team* |
| Internal alert to TRON | *— DFP System* (austere, internal) |
| Credentials to lead (approved) | *Maximiliano Elenes, Founder* |
| Rejection to lead | *The DealFlow Perspectives Team* |
| 24h expiration warning to lead | *The DealFlow Perspectives Team* |

Personal signature is reserved for the moment a door is being opened. All other touchpoints carry the team signature.

### 10.1 Email Templates (all in English)

**Email A — Internal alert to TRON when new request arrives:**

```
Subject: [DFP] New access request: <full_name> (<company>)

A new demo request just came in:

Name:             <full_name>
Email:            <email>
Company:          <company>
Role / Title:     <role_title>
Country:          <country>
LinkedIn:         <linkedin_url or "—">
Organization:     <organization_type label>
AUM:              <aum_range label or "—">
Ticket size:      <ticket_size_range label or "—">
Fund stage:       <fund_stage label or "—">

Motivation:
<motivation>

Review: https://dealflowperspectives.com/admin/requests/<id>

— DFP System
```

**Email B — Auto-reply to lead (request received):**

```
Subject: We received your request — DealFlow Perspectives

Dear <first_name>,

Thanks, we received your request. We'll review your
information and get back to you soon.

Best regards,
The DealFlow Perspectives Team
```

**Email C — Credentials to lead (approved):**

```
Subject: Access approved — DealFlow Perspectives

Dear <first_name>,

Your access to DealFlow Perspectives has been approved.
Your temporary credentials are valid for 7 days starting today:

Username:    <email>
Password:    <generated_password>

Sign in at: https://dealflowperspectives.com

Best regards,
Maximiliano Elenes
Founder, DealFlow Perspectives
```

**Email D — Rejection to lead:**

```
Subject: Update on your DealFlow Perspectives access request

Dear <first_name>,

Thank you for your interest in DealFlow Perspectives.
After reviewing your request, we are unable to offer access
at this time.

We hope to stay in touch and look forward to opportunities
to add value to your work in the future.

We appreciate the time you took to reach out and wish you
continued success.

Best regards,
The DealFlow Perspectives Team
```

**Email E — 24h expiration warning to lead:**

```
Subject: Your DFP access expires tomorrow

Dear <first_name>,

This is a reminder that your demo access to DealFlow Perspectives
will expire in approximately 24 hours.

If you'd like to extend your access, please reach out to us
on LinkedIn:
<COMPANY_LINKEDIN_URL>

Best regards,
The DealFlow Perspectives Team
```

### Why not Resend / SendGrid / etc.

Founder requirement: minimal external dependencies. Gmail SMTP via app password is officially supported by Google for this exact use case, free, and gives ~500 emails/day — more than sufficient through 2030 given DFP's expected volume. When `info@dealflowperspectives.com` exists (post-Workspace), only the two env vars change. Zero code refactor.

---

## 11. Architecture: Expiration Logic

### Two layers of enforcement

**Layer 1 — Real-time check on login:**

```js
// After Supabase auth succeeds, before redirect:
if (!profile.is_active) {
  return blockWithMessage(
    "Your account is not active. Please reach out via LinkedIn to reactivate."
  );
}
if (profile.expires_at && new Date(profile.expires_at) < new Date()) {
  return blockWithMessage(
    "Your demo access has expired. To request an extension, please reach out directly via LinkedIn."
  );
}
```

The blocked screen displays the company LinkedIn page as a CTA button (sourced from `COMPANY_LINKEDIN_URL` secret, surfaced in the frontend via a public config endpoint). The company page (`https://www.linkedin.com/company/dealflow-perspectives`) is the canonical contact channel for extensions and reactivation — keeps inquiries separate from the founder's personal LinkedIn and scales as CLU takes over operations.

**Layer 2 — Batch cleanup via `pg_cron` (runs hourly):**

```sql
-- Mark expired demo accounts inactive
UPDATE profiles
SET is_active = false
WHERE expires_at IS NOT NULL
  AND expires_at < now()
  AND is_active = true
  AND role != 'admin';  -- admins NEVER auto-deactivate

-- Trigger 24h warning email for accounts expiring soon
-- (calls send-expiry-warning Edge Function for each match, only once per account)
SELECT trigger_expiry_warning(id)
FROM profiles
WHERE expires_at IS NOT NULL
  AND expires_at BETWEEN now() + interval '23 hours' AND now() + interval '25 hours'
  AND role = 'demo'
  AND expiry_warning_sent_at IS NULL;
```

### Clock-start semantics

The 7-day clock starts at **approval time**, not first login.

```js
// In approval handler, when TRON clicks "Approve":
const approvalTime = new Date();
const expiresAt = new Date(approvalTime.getTime() + 7 * 24 * 60 * 60 * 1000);

// Create profile with:
//   role = 'demo'
//   is_active = true
//   approved_at = approvalTime
//   expires_at = expiresAt
//   first_login_at = null  (filled later for analytics only)
```

`first_login_at` is still tracked for analytics purposes (knowing if/when a lead actually engaged) but does NOT influence expiration timing.

---

## 12. Row-Level Security (RLS)

All new tables get RLS enabled from day one.

### `demo_requests`

| Operation | Who |
|---|---|
| INSERT | anyone (anonymous) — required for public form |
| SELECT | only admins (`role='admin'`) |
| UPDATE | only admins |
| DELETE | nobody (audit trail) |

### `profiles` (with new columns)

| Operation | Who |
|---|---|
| SELECT | own row (`auth.uid() = id`) OR admin |
| UPDATE | own row for non-sensitive fields; admin for all fields |
| INSERT | only via Edge Function with service role |
| DELETE | nobody |

### `audit_log`

| Operation | Who |
|---|---|
| INSERT | only via service role (server-side functions) |
| SELECT | only admins |
| UPDATE / DELETE | nobody |

---

## 13. Frontend Components (within existing `index.html`)

New components:

1. **`<RequestAccessButton>`** — navbar CTA, placed before "Subscribe to our newsletter".
2. **`<RequestDemoModal>`** — opens from `<RequestAccessButton>`, contains the form with conditional fields.
3. **`<RequestSubmittedScreen>`** — success state inside the modal post-submit.
4. **`<AdminRequestsInbox>`** — table view at `/admin/requests`, realtime via Supabase channel.
5. **`<RequestDetailDrawer>`** — slide-out panel showing full request + approve/reject actions + internal notes.
6. **`<ApprovalConfirmModal>`** — confirms approval, shows generated password once (copy-to-clipboard button).
7. **`<RejectionConfirmModal>`** — confirms rejection (with safety: "Are you sure? This action cannot be undone.").
8. **`<ExtendAccountModal>`** — preset buttons for +7 / +14 / +30 days; custom date picker.
9. **`<LoginBlockedScreen>`** — shown when expired or inactive user attempts login; surfaces LinkedIn CTA.

All components follow existing styling conventions in `index.html` — no new CSS framework introduced.

---

## 14. Implementation Order — 12 Atomic Steps

Each step is a single commit on `main`, with manual testing before moving forward.

| # | Step | What it does | Testing |
|---|---|---|---|
| 1 | Schema migration | Create `demo_requests` (with conditional field constraints), `audit_log`, alter `profiles` | Run migration, verify in Supabase UI |
| 2 | RLS policies | Apply RLS to all new tables | Test as anon + as TRON via SQL |
| 3 | Public demo form | Modal with conditional fields, validation, insert to `demo_requests` | Submit one of each org type, verify rows in DB |
| 4 | Edge Function: notify + auto-reply | Webhook on insert → email TRON + auto-reply to lead | Submit form → both emails arrive |
| 5 | Admin inbox + realtime | List view + Supabase channel subscription | Insert from another tab → see in inbox live |
| 6 | Request detail drawer | Full request view + internal notes editor | Open, save notes, refresh |
| 7 | Approve action | Generate password, create profile with `expires_at = now() + 7d`, show password once | Approve test request, verify profile + audit_log |
| 8 | Edge Function: credentials email | Send Email C to lead on approval | Approve → lead inbox gets credentials |
| 9 | Reject action + email | Reject button + Edge Function for Email D | Reject test request → lead gets rejection email |
| 10 | Login expiration enforcement | Block expired/inactive at login with LinkedIn CTA | Set `expires_at` past → can't login, see CTA |
| 11 | pg_cron + 24h warning | Hourly job + Edge Function for Email E | Set test row 23h out → warning email arrives |
| 12 | Extend / revoke actions | Admin UI for extension and revocation | Extend +7d → new `expires_at`; revoke → blocked |

After step 12: end-to-end test with a real (or simulated) lead from form submission to expiration, covering all 5 email templates.

---

## 15. Manual Testing Checklist — Pre-Launch

- [ ] Anonymous user submits demo request with each organization type → conditional fields appear correctly
- [ ] Form validation: missing required fields blocked, motivation under 20 chars blocked, invalid email blocked
- [ ] Email A arrives to TRON inbox within 60 seconds of submission
- [ ] Email B (auto-reply) arrives to lead within 60 seconds
- [ ] Same email cannot submit a second request while one is pending
- [ ] TRON sees request in `/admin/requests` in realtime (no refresh needed)
- [ ] TRON adds internal notes, persists on refresh
- [ ] TRON rejects → Email D arrives to lead, status updates
- [ ] TRON approves → creates `profiles` row with `role='demo'`, `expires_at = now() + 7d`, generates password
- [ ] Email C arrives to lead with credentials
- [ ] Lead logs in → can access demo content; `first_login_at` populates
- [ ] Day 6: Email E arrives to lead with LinkedIn CTA
- [ ] Day 7: lead login blocked with clear message + LinkedIn CTA button visible
- [ ] TRON extends +7d → lead can log in again, new `expires_at` reflected
- [ ] TRON revokes → lead cannot log in even before original expiry
- [ ] TRON's own account: zero impact from any of the above flows
- [ ] All actions appear in `audit_log` with correct actor and metadata
- [ ] Every user-facing string is in English (no Spanish artifacts)

---

## 16. Known Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Gmail SMTP throttling at scale | <50 emails/day expected. If hit, swap to Workspace SMTP (same code, two env var changes). |
| App password leaked | Stored only in Supabase Vault. Rotate quarterly or on suspicion. |
| `pg_cron` job fails silently | Layer 1 (login check) catches anything Layer 2 misses. |
| Lead never logs in but expires anyway | By design: clock starts at approval. Communicated implicitly via the credentials email. |
| Same email tries multiple pending requests | Unique partial index `(email) WHERE status='pending'`. |
| Phase 2 contract (refresh = logout) interaction with demos | Logout flow already handles all roles equally. No special case needed. |
| Demo content scope creep | Out of scope here — defined separately in content access doc. |
| Lead spams LinkedIn DMs for extensions | TRON controls the gate manually; no automation pressure. |
| Spanish strings slip into the codebase | All PR reviews check the English-only rule; linter could be added later. |

---

## 17. References

- `/docs/AUTH_FLOW.md` — existing auth contract
- `/docs/REFRESH_LOGOUT_DESIGN.md` — refresh = clean logout contract
- `/docs/STORAGE_INVENTORY.md` — current storage state
- `/docs/REPO_INVENTORY.md` — file structure
- Supabase Edge Functions: https://supabase.com/docs/guides/functions
- Gmail SMTP setup: https://support.google.com/mail/answer/7126229
- Supabase pg_cron: https://supabase.com/docs/guides/database/extensions/pg_cron
- Supabase Vault: https://supabase.com/docs/guides/database/vault

---

**End of design document.**

Handoff: Claude Code with `superpowers` + `systematic-debugging` skills loaded.
Execution path: Section 14, steps 1 through 12 sequentially, each as an atomic commit on `main`.
Founder review before deploy: Section 15 checklist must pass 100%.
