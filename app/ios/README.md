# iOS

Run `flutter create . --platforms=ios` from `app/`; existing hardened files are kept:

- `Runner/Info.plist` - no ATS exceptions; no location / Face ID / camera usage keys.
- `Runner/Runner.entitlements` - Data Protection `NSFileProtectionComplete`, no iCloud/CloudKit,
  Associated Domains for the password-recovery Universal Link (replace `REPLACE_WITH_WEB_HOST`).
- `Runner/AppDelegate.swift` - `acme/backup` channel that excludes the offline cache from backups.

In Xcode set `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` for Runner, and publish
`/.well-known/apple-app-site-association` on the web host allowing only `/auth/callback`.
Release builds: `flutter build ipa --release --obfuscate --split-debug-info=build/symbols`.
