# ACME Control

Industrial supervisory/control system for two (demo) water-treatment plants: two tanks, pumps,
valves, level, pressure and flow, with a dark Material 3 UI. Source spec: [docs/specs/PRD.md](docs/specs/PRD.md).

> **Status:** security foundation implemented (database schema + RLS, hardened command/setpoint/
> simulation/attachment API, auth/session/offline-cache services, login, password recovery,
> profile, settings, shift handover, platform hardening). Plant, process diagram, equipment,
> alarms, trends, commands, setpoints, maintenance and simulation screens are still placeholders.

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

1. **Supabase**: `supabase start` (applies `migrations/` and `seed.sql`; set `SITE_URL`,
   `WEB_RESET_REDIRECT_URL`, `MOBILE_RESET_REDIRECT_URL`, `SMTP_*` env vars first).
2. **Demo users**: `cd api && pnpm install && pnpm seed:users` - prints random passwords once.
3. **API**: copy `api/.env.example` to `api/.env`, then `pnpm dev`. Tests: `pnpm typecheck && pnpm test`.
4. **App**: `cd app && flutter create . --platforms=web,android,ios` (keeps the hardened files),
   `flutter pub get`, then `flutter run --dart-define-from-file=.env.dev.json`.

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
