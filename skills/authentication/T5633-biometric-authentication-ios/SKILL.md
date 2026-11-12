---
name: t5633-biometric-authentication-ios
description: If biometric unlock is ever added to the iOS app, use LocalAuthentication with Keychain-bound secrets and a password fallback; never let it replace server-side checks for plant commands.
---

# T5633: Implement best practices for Biometric authentication (iOS)

**Category:** CODE_FIX
**SD Elements:** [T5633](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T5633/)
**Priority:** 7

**Spec Context:**
> "deve usar Flutter e Dart para web, Android e iOS" / "login por e-mail e senha" / "ações de controle exigem conexão"
> Source: docs/specs/PRD.md, paragraphs 2, 3 and 6 (biometrics are not explicitly requested)

**What the spec implies (naive approach):**
A "Face ID" toggle that skips login when `canCheckBiometrics` is true, with the refresh token kept in plain preferences.

**Secure Implementation Pattern:**
```dart
// Only if biometric unlock is implemented (local_auth + flutter_secure_storage)
final ok = await LocalAuthentication().authenticate(
  localizedReason: 'Unlock ACME Control',
  options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
);
if (ok) {
  token = await secure.read(
    key: 'refresh',
    iOptions: const IOSOptions(accessibility: KeychainAccessibility.passcode),
  ); // Keychain, this device only
}
```

**Implementation Guidance:**
- Default: do not implement biometrics (not in the PRD); this recipe is the rule if it is added later.
- If added: declare `NSFaceIDUsageDescription`, keep the secret in the Keychain, provide a password fallback.
- Biometric unlock never bypasses server-side authorization for commands or setpoint approvals.

**Success Criteria:**
- [ ] Either no biometric code / Info.plist key exists, or unlock reads the token only from the Keychain after LocalAuthentication succeeds.
- [ ] The server still validates the session for every control action.

**Status:** Applied
