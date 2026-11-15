# ACME Control

Industrial supervisory/control system for two (demo) water-treatment plants: two tanks, pumps,
valves, level, pressure and flow, with a dark Material 3 UI. Source spec: [docs/specs/PRD.md](docs/specs/PRD.md).

> **Status:** all PRD pages implemented end to end: plants, process view (animated 2.5D
> water-treatment diagram), equipment, alarms, trends, commands, setpoints (propose / review),
> maintenance (work orders + lockout), shift handover, simulation (scenarios, step, events,
> reset), plus login, password recovery, profile and settings.

## Screens and roles

| Page | Route | Who can act (enforced by API / RLS) |
|------|-------|--------------------------------------|
| Plants | `/plants` | all members (read) |
| Process view | `/plants/:id` | tap equipment for details; controls as below |
| Equipment (assets) | `/plants/:id/equipment` | search (RPC, bound params) + kind/status filters |
| Alarms | `/plants/:id/alarms` | acknowledge: operator, supervisor |
| Trends | `/plants/:id/trends` | read; ranges up to 7 days (server-enforced) |
| Commands | `/plants/:id/commands` | pumps/valves/mode: operator, supervisor |
| Setpoints | `/plants/:id/setpoints` | propose: engineer · review: supervisor (never own) |
| Maintenance | `/plants/:id/maintenance` | work orders + lockout: maintenance |
| Shift handover | `/plants/:id/handover` | all members |
| Simulation | `/simulation` | supervisor; only when `ENABLE_DEMO_TOOLS=true` |

Phones get bottom tabs **Plant / Alarms / Assets / More** and a vertical diagram; web/tablets
get a side rail. Navigation adapts to the user's role (UX only). Realtime updates pause in the
background and resume on return / reconnection; offline, the last encrypted snapshot is shown
read-only and control actions are disabled. Commands resolve the *actual* state through the
interlocks (empty source tank or maintenance keeps a pump off), so requested vs. actual is visible.

## Architecture

| Part | Tech | Folder |
|------|------|--------|
| Client (web, Android, iOS) | Flutter + Dart, Material 3, Riverpod, go_router | `app/` |
| Command & simulation API | TypeScript on Vercel (pnpm) | `api/` |
| Backend services | Supabase: PostgreSQL + RLS, email/password auth, Storage, Realtime | `supabase/` |

Security model: clients only **read** through Row Level Security (plus a few user-owned inserts);
every process change goes through the API, which authenticates the Supabase JWT, authorizes by
plant role, rate-limits, applies interlocks and writes an append-only, hash-chained audit log.
See [docs/security/access-matrix.md](docs/security/access-matrix.md),
[docs/security/crypto.md](docs/security/crypto.md) and [docs/security/ipc.md](docs/security/ipc.md).

## Run locally

1. **Supabase**: `supabase start` (applies `migrations/0001_init.sql`, `0002_screens.sql` and `seed.sql`; set `SITE_URL`,
   `WEB_RESET_REDIRECT_URL`, `MOBILE_RESET_REDIRECT_URL`, `SMTP_*` env vars first).
2. **Demo users**: `cd api && pnpm install && pnpm seed:users` - prints random passwords once.
3. **API**: copy `api/.env.example` to `api/.env` (set `ENABLE_DEMO_TOOLS=true` locally for the
   simulation area), then `pnpm dev`. Tests: `pnpm typecheck && pnpm test`.
4. **App**: `cd app && flutter create . --platforms=web,android,ios` (keeps the hardened files),
   `flutter pub get`, then `flutter run --dart-define-from-file=.env.dev.json` (add
   `"ENABLE_DEMO_TOOLS": true` for debug builds to show the simulation area).
   Checks: `flutter analyze && flutter test`.
5. **Demo flow**: sign in as the supervisor, open *Simulation*, apply *Normal operation*, open
   the inlet valve and start a pump (as operator or supervisor), then advance the simulation and
   watch levels, alarms and trends update. Sign in as engineer to propose a setpoint change and
   as supervisor to approve it; as maintenance to lock out a pump (it then refuses to start).

## Publish

- **API**: `cd api && vercel --prod`; set env vars in the Vercel project (mark secrets "Sensitive").
- **Web**: see [app/web/README.md](app/web/README.md) (prebuilt static deploy with CSP headers).
- **Android / iOS**: see [app/android/README.md](app/android/README.md) and [app/ios/README.md](app/ios/README.md).

## Release checklist

- [ ] `ENABLE_DEMO_TOOLS=false` for API and app (the app refuses to start in release otherwise)
- [ ] Release builds with `--release --obfuscate --split-debug-info`; no debug banner
- [ ] `pnpm audit --prod` and `flutter pub outdated` reviewed; lockfiles committed
- [ ] Merged Android manifest and iOS Info.plist/entitlements match `docs/security/ipc.md`
- [ ] CSP placeholders in `app/web/vercel.json` and entitlements host replaced
- [ ] Supabase security advisor clean; hosted Auth settings match `supabase/config.toml`
- [ ] No demo credentials or `.env` files in the build or repository (gitleaks)

## Platform-owned controls (configure outside this repository)

| Control | Where |
|---------|-------|
| Edge rate limiting / bot protection / DDoS (T374) | Vercel Firewall rules for `/api/*` |
| OS and privileged process protection (T4595) | Managed by Vercel and Supabase (shared responsibility) |
| Behavioural monitoring and alerting (T4593) | Vercel Log Drains + Supabase log export to a SIEM |
| System credentials: strong, rotated (T69) | Supabase DB password / API keys, Vercel env vars |
| TLS termination (T21) | Vercel / Supabase (verify with an SSL Labs scan); Supabase "Enforce SSL" |
| SPF / DKIM / DMARC for recovery emails (T2157) | DNS of the sending domain + SMTP provider |
