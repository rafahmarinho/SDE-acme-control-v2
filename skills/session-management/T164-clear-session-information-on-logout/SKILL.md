---
name: t164-clear-session-information-on-logout
description: On logout, session error or expiry, remove tokens, the offline cache and in-memory Riverpod state on web, Android and iOS so shared shift devices leak nothing.
---

# T164: Clear session information from client upon logout

**Category:** CODE_FIX
**SD Elements:** [T164](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/requirements/33-T164/)
**Priority:** 7

**Spec Context:**
> "mostre os últimos dados como leitura offline" / "passagem de turno"
> Source: docs/specs/PRD.md, paragraphs 4 and 6

**What the spec implies (naive approach):**
Logout only navigates to the login screen; the cached plant data, realtime channels and refresh token remain on a device shared between shifts.

**Secure Implementation Pattern:**
```dart
Future<void> logout(WidgetRef ref) async {
  await supabase.removeAllChannels();            // stop realtime
  await supabase.auth.signOut();                 // revoke refresh token server-side
  await offlineCache.wipe();                     // delete cached plant data + its key
  await secureStorage.deleteAll();
  ref.invalidate(sessionScopedProviders);        // clear Riverpod state
  router.go('/login');
}
// Also call logout() when the API returns 401 or onAuthStateChange emits signedOut.
```

**Implementation Guidance:**
- Trigger cleanup on explicit logout, on 401/invalid session responses and on token expiry.
- Wipe the offline read cache (T148) and any encryption key for it.
- Make providers holding user data depend on the auth state so they reset automatically.

**Success Criteria:**
- [ ] After logout, no tokens remain in secure storage / localStorage.
- [ ] After logout, offline mode shows no previous user's data.
- [ ] A 401 from the API triggers the same cleanup.

**Status:** Applied
