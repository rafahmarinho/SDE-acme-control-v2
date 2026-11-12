# Mobile IPC / entry-point inventory

Re-check against the merged Android manifest and built iOS Info.plist/entitlements every release.

| Platform | Endpoint | Exposure | Data accepted |
|----------|----------|----------|---------------|
| Android | `MainActivity` LAUNCHER | exported (required) | none |
| Android | App Link `https://<web-host>/auth/callback` | verified (`autoVerify`) | `code` only |
| iOS | Universal Link `/auth/callback` (associated domain) | AASA-restricted | `code` only |
| Both | MethodChannel `acme/backup` | in-process only | file path inside app home |

Not present (and not allowed without review): exported services, broadcast receivers, content
providers, AIDL/Binder services, custom URL schemes, share targets, CloudKit/iCloud containers.
Deep links may open only read-only screens (`app/lib/app/navigation_guards.dart`); control
actions always require explicit in-app interaction and a server-side authorized API call.
Biometric unlock is not implemented; if added it must use LocalAuthentication + Keychain-bound
secrets with password fallback, and never replace server-side checks.
