# ACME Control

Industrial supervisory/control system for two (demo) water-treatment plants: two tanks, pumps,
valves, level, pressure and flow, with a dark Material 3 UI and an animated (optionally 3D)
process diagram. Source spec: [docs/specs/PRD.md](docs/specs/PRD.md).

> **Status: scaffold only.** Files are placeholders. Implement features by following the
> security task recipes in [AGENTS.md](AGENTS.md) and `skills/**/SKILL.md`.

## Architecture (from PRD)

| Part | Tech | Folder |
|------|------|--------|
| Client (web, Android, iOS) | Flutter + Dart, Material 3, Riverpod, go_router | `app/` |
| Command & simulation API | TypeScript on Vercel (pnpm) | `api/` |
| Backend services | Supabase: PostgreSQL, email/password auth, Storage, Realtime | `supabase/` |

Client layout (PRD: "telas, componentes, serviços e acesso ao banco"):
`app/lib/screens`, `app/lib/components`, `app/lib/services`, `app/lib/data`.

## Features (from PRD)

- Login, password recovery, profile, settings, search, filters, loading and error states
- Pages: plants, process view, equipment, alarms, trends, commands, setpoints, maintenance, shift handover
- Commands: pumps on/off, valves open/close, manual/automatic mode; requested vs. actual state
- Interlocks: a pump cannot run if its tank is empty or the equipment is in maintenance
- Roles: operator, engineer, supervisor, maintenance; setpoint change proposals reviewed by a supervisor
- Simulation area: choose scenario, step simulation, browse events, reset data
- Mobile: adapted diagram, tabs (plant, alarms, assets, more), touch-friendly forms,
  background pause, offline read-only of last data; control actions require connectivity
- Demo data with two plants; external integrations simulated

## Getting started (to be completed during implementation)

1. `supabase/`: create a Supabase project, apply `migrations/`, run `seed.sql`.
2. `api/`: `pnpm install`, copy `.env.example` to `.env`, `pnpm dev`; deploy with `vercel`.
3. `app/`: `flutter create . --platforms=web,android,ios` (generates native folders),
   `flutter pub get`, run with `--dart-define` values from `app/.env.example`.
4. Native packages: `flutter build apk|appbundle|ipa`; web: `flutter build web` then deploy to Vercel.
