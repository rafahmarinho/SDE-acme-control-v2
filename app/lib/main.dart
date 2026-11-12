/// ACME Control - application entry point (placeholder).
///
/// Responsibilities (from PRD):
/// - Initialise Supabase (PostgreSQL, email/password auth, Storage, Realtime) using PUBLIC config
///   from --dart-define (never the service-role key).
/// - Wrap the app in a Riverpod ProviderScope and a dark Material 3 theme.
/// - Mount the go_router configuration from `app/router.dart`.
///
/// Security: see AGENTS.md (session-management, crypto-secrets, mobile-* domains).
void main() {
  // TODO: implement following AGENTS.md task recipes.
}
