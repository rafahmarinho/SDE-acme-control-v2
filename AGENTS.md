<!-- SDE-SECURITY-HARDENING-START -->
## Security Hardening Execution Contract

When implementing any feature in this repository, open the skill files for the domains that feature touches
and satisfy every Success Criteria item. Recipes reference spec text in `docs/specs/PRD.md`.

## Project Overview
| Property | Value |
|----------|-------|
| Application | acme-control-v2 |
| SD Elements Project | [ACME Control v2](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/) |
| Project ID | 33 |
| Risk Policy | On-Boarding Policy (ID 1) |
| Total Countermeasures | 79 (risk-relevant) |
| Source | Spec files (PRD) - docs/specs/PRD.md |

## Countermeasure Summary by Category

| Category | Count | Description |
|----------|-------|-------------|
| CODE_FIX | 64 | Secure implementation needed in application code |
| INFRA | 6 | External infrastructure |
| **FILE-TRACKED TOTAL** | **70** | Countermeasures with local skill files |

> **PROCESS countermeasures (9) are noted in SD Elements only -- not tracked locally:** T2348, CT1, CT2, T755, T2128, T2170, T1386, T544, T744.

## Skill Files

| Domain | Countermeasures |
|--------|----------------|
| authentication | 5 |
| session-management | 3 |
| authorization | 5 |
| database-security | 5 |
| web-security | 6 |
| api-security | 6 |
| crypto-secrets | 6 |
| mobile-android | 7 |
| mobile-ios | 4 |
| mobile-general | 5 |
| client-data-protection | 4 |
| privacy | 4 |
| logging-audit | 2 |
| release-supply-chain | 2 |
| infrastructure | 6 |

### authentication
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T558 | Authenticate all other components before any network communication with them | [skills/authentication/T558-authenticate-components-before-network-communication/SKILL.md](./skills/authentication/T558-authenticate-components-before-network-communication/SKILL.md) | 9 | CODE_FIX | Pending |
| T70 | Implement account lockout or authentication throttling for system accounts | [skills/authentication/T70-account-lockout-authentication-throttling/SKILL.md](./skills/authentication/T70-account-lockout-authentication-throttling/SKILL.md) | 8 | CODE_FIX | Pending |
| T2 | Secure the password reset mechanism | [skills/authentication/T2-secure-password-reset/SKILL.md](./skills/authentication/T2-secure-password-reset/SKILL.md) | 9 | CODE_FIX | Pending |
| T143 | Apply minimum password standards for mobile environments | [skills/authentication/T143-minimum-password-standards-mobile/SKILL.md](./skills/authentication/T143-minimum-password-standards-mobile/SKILL.md) | 7 | CODE_FIX | Pending |
| T5633 | Implement best practices for Biometric authentication (iOS) | [skills/authentication/T5633-biometric-authentication-ios/SKILL.md](./skills/authentication/T5633-biometric-authentication-ios/SKILL.md) | 7 | CODE_FIX | Pending |

### session-management
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T20 | Generate unique session IDs and reset old IDs after authentication | [skills/session-management/T20-unique-session-ids-reset-after-auth/SKILL.md](./skills/session-management/T20-unique-session-ids-reset-after-auth/SKILL.md) | 9 | CODE_FIX | Pending |
| T164 | Clear session information from client upon logout | [skills/session-management/T164-clear-session-information-on-logout/SKILL.md](./skills/session-management/T164-clear-session-information-on-logout/SKILL.md) | 7 | CODE_FIX | Pending |
| T1539 | Clear browser data on user logout | [skills/session-management/T1539-clear-browser-data-on-logout/SKILL.md](./skills/session-management/T1539-clear-browser-data-on-logout/SKILL.md) | 8 | CODE_FIX | Pending |

### authorization
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T17 | Do not only rely on client-side authorization | [skills/authorization/T17-do-not-rely-on-client-side-authorization/SKILL.md](./skills/authorization/T17-do-not-rely-on-client-side-authorization/SKILL.md) | 8 | CODE_FIX | Pending |
| T145 | Avoid client-side authorization for mobile clients | [skills/authorization/T145-avoid-client-side-authorization-mobile/SKILL.md](./skills/authorization/T145-avoid-client-side-authorization-mobile/SKILL.md) | 8 | CODE_FIX | Pending |
| T378 | Authorize every request for data objects | [skills/authorization/T378-authorize-every-request-for-data-objects/SKILL.md](./skills/authorization/T378-authorize-every-request-for-data-objects/SKILL.md) | 8 | CODE_FIX | Pending |
| T338 | Control access to resources through user authentication and authorization | [skills/authorization/T338-control-access-through-authn-authz/SKILL.md](./skills/authorization/T338-control-access-through-authn-authz/SKILL.md) | 7 | CODE_FIX | Pending |
| T50 | Use indirect object reference maps if accessing files | [skills/authorization/T50-indirect-object-references-for-files/SKILL.md](./skills/authorization/T50-indirect-object-references-for-files/SKILL.md) | 8 | CODE_FIX | Pending |

### database-security
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T38 | Bind variables in SQL statements | [skills/database-security/T38-bind-variables-in-sql/SKILL.md](./skills/database-security/T38-bind-variables-in-sql/SKILL.md) | 10 | CODE_FIX | Pending |
| T2599 | Protect against connection string parameter pollution | [skills/database-security/T2599-connection-string-parameter-pollution/SKILL.md](./skills/database-security/T2599-connection-string-parameter-pollution/SKILL.md) | 9 | CODE_FIX | Pending |
| T2598 | Implement query-level access control | [skills/database-security/T2598-query-level-access-control/SKILL.md](./skills/database-security/T2598-query-level-access-control/SKILL.md) | 8 | CODE_FIX | Pending |
| T19 | Restrict Application's Access to Database | [skills/database-security/T19-restrict-application-access-to-database/SKILL.md](./skills/database-security/T19-restrict-application-access-to-database/SKILL.md) | 8 | CODE_FIX | Pending |
| T2600 | Control the result set size returned by a query | [skills/database-security/T2600-control-query-result-set-size/SKILL.md](./skills/database-security/T2600-control-query-result-set-size/SKILL.md) | 7 | CODE_FIX | Pending |

### web-security
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T36 | Escape untrusted data in HTML, HTML attributes, CSS, and JavaScript | [skills/web-security/T36-escape-untrusted-data-html-css-js/SKILL.md](./skills/web-security/T36-escape-untrusted-data-html-css-js/SKILL.md) | 8 | CODE_FIX | Pending |
| T37 | Avoid DOM-based Cross-Site Scripting (XSS) | [skills/web-security/T37-avoid-dom-based-xss/SKILL.md](./skills/web-security/T37-avoid-dom-based-xss/SKILL.md) | 8 | CODE_FIX | Pending |
| T257 | Secure cross origin resource sharing (CORS) | [skills/web-security/T257-secure-cors/SKILL.md](./skills/web-security/T257-secure-cors/SKILL.md) | 8 | CODE_FIX | Pending |
| T29 | Use anti-Cross-Site Request Forgery (CSRF) tokens | [skills/web-security/T29-anti-csrf-tokens/SKILL.md](./skills/web-security/T29-anti-csrf-tokens/SKILL.md) | 7 | CODE_FIX | Pending |
| T66 | Prevent web pages from being loaded inside iFrame | [skills/web-security/T66-prevent-iframe-loading/SKILL.md](./skills/web-security/T66-prevent-iframe-loading/SKILL.md) | 7 | CODE_FIX | Pending |
| T1144 | Prevent Server-Side Template Injection (SSTI) | [skills/web-security/T1144-prevent-server-side-template-injection/SKILL.md](./skills/web-security/T1144-prevent-server-side-template-injection/SKILL.md) | 8 | CODE_FIX | Pending |

### api-security
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T42 | Avoid relying on untrusted data for server-side selection | [skills/api-security/T42-avoid-untrusted-data-for-server-side-selection/SKILL.md](./skills/api-security/T42-avoid-untrusted-data-for-server-side-selection/SKILL.md) | 10 | CODE_FIX | Pending |
| T536 | Restrict the size of incoming messages in services | [skills/api-security/T536-restrict-incoming-message-size/SKILL.md](./skills/api-security/T536-restrict-incoming-message-size/SKILL.md) | 8 | CODE_FIX | Pending |
| T35 | Fine-tune HTTP server settings | [skills/api-security/T35-fine-tune-http-server-settings/SKILL.md](./skills/api-security/T35-fine-tune-http-server-settings/SKILL.md) | 9 | CODE_FIX | Pending |
| T1362 | Perform message throttling in Web APIs | [skills/api-security/T1362-message-throttling-web-apis/SKILL.md](./skills/api-security/T1362-message-throttling-web-apis/SKILL.md) | 8 | CODE_FIX | Pending |
| T2139 | Prevent information exposure through APIs | [skills/api-security/T2139-prevent-information-exposure-through-apis/SKILL.md](./skills/api-security/T2139-prevent-information-exposure-through-apis/SKILL.md) | 7 | CODE_FIX | Pending |
| T1365 | Mitigate Server Side Request Forgery | [skills/api-security/T1365-mitigate-server-side-request-forgery/SKILL.md](./skills/api-security/T1365-mitigate-server-side-request-forgery/SKILL.md) | 8 | CODE_FIX | Pending |

### crypto-secrets
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T248 | Protect secret keys and passwords in the application | [skills/crypto-secrets/T248-protect-secret-keys-and-passwords/SKILL.md](./skills/crypto-secrets/T248-protect-secret-keys-and-passwords/SKILL.md) | 8 | CODE_FIX | Pending |
| T76 | Do not hardcode passwords | [skills/crypto-secrets/T76-do-not-hardcode-passwords/SKILL.md](./skills/crypto-secrets/T76-do-not-hardcode-passwords/SKILL.md) | 10 | CODE_FIX | Pending |
| T59 | Use standard libraries for cryptography | [skills/crypto-secrets/T59-use-standard-cryptography-libraries/SKILL.md](./skills/crypto-secrets/T59-use-standard-cryptography-libraries/SKILL.md) | 8 | CODE_FIX | Pending |
| T60 | Use correct and approved cryptographic algorithms, parameters, and key lengths | [skills/crypto-secrets/T60-approved-cryptographic-algorithms-and-key-lengths/SKILL.md](./skills/crypto-secrets/T60-approved-cryptographic-algorithms-and-key-lengths/SKILL.md) | 8 | CODE_FIX | Pending |
| T151 | Use cryptographically secure random numbers | [skills/crypto-secrets/T151-cryptographically-secure-random-numbers/SKILL.md](./skills/crypto-secrets/T151-cryptographically-secure-random-numbers/SKILL.md) | 7 | CODE_FIX | Pending |
| T156 | Validate certificate and its chain of trust properly | [skills/crypto-secrets/T156-validate-certificate-chain-of-trust/SKILL.md](./skills/crypto-secrets/T156-validate-certificate-chain-of-trust/SKILL.md) | 7 | CODE_FIX | Pending |

### mobile-android
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T5657 | Validate Incoming Messenger Messages (Android) | [skills/mobile-android/T5657-validate-incoming-messenger-messages-android/SKILL.md](./skills/mobile-android/T5657-validate-incoming-messenger-messages-android/SKILL.md) | 8 | CODE_FIX | Pending |
| T270 | Follow best practices for storing application data on Android devices | [skills/mobile-android/T270-secure-android-data-storage/SKILL.md](./skills/mobile-android/T270-secure-android-data-storage/SKILL.md) | 7 | CODE_FIX | Pending |
| T5646 | Implement secure services (Android) | [skills/mobile-android/T5646-secure-android-services/SKILL.md](./skills/mobile-android/T5646-secure-android-services/SKILL.md) | 10 | CODE_FIX | Pending |
| T170 | Secure IPC endpoints used in clients | [skills/mobile-android/T170-secure-ipc-endpoints-in-clients/SKILL.md](./skills/mobile-android/T170-secure-ipc-endpoints-in-clients/SKILL.md) | 7 | CODE_FIX | Pending |
| T5645 | Implement secure Binder communication (Android) | [skills/mobile-android/T5645-secure-binder-communication-android/SKILL.md](./skills/mobile-android/T5645-secure-binder-communication-android/SKILL.md) | 10 | CODE_FIX | Pending |
| T273 | Avoid permission re-delegation by considering caller's permissions | [skills/mobile-android/T273-avoid-permission-re-delegation/SKILL.md](./skills/mobile-android/T273-avoid-permission-re-delegation/SKILL.md) | 8 | CODE_FIX | Pending |
| T5660 | Implement secure data control options for users (Android) | [skills/mobile-android/T5660-secure-data-control-options-android/SKILL.md](./skills/mobile-android/T5660-secure-data-control-options-android/SKILL.md) | 7 | CODE_FIX | Pending |

### mobile-ios
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T5637 | Implement best practices for handling location data (iOS) | [skills/mobile-ios/T5637-location-data-handling-ios/SKILL.md](./skills/mobile-ios/T5637-location-data-handling-ios/SKILL.md) | 7 | CODE_FIX | Pending |
| T5635 | Follow best practices for handling CloudKit Storage (iOS) | [skills/mobile-ios/T5635-cloudkit-storage-ios/SKILL.md](./skills/mobile-ios/T5635-cloudkit-storage-ios/SKILL.md) | 9 | CODE_FIX | Pending |
| T5634 | Securely integrate iCloud storage into iOS applications (iOS) | [skills/mobile-ios/T5634-icloud-storage-ios/SKILL.md](./skills/mobile-ios/T5634-icloud-storage-ios/SKILL.md) | 9 | CODE_FIX | Pending |
| T2133 | Protect the security of data in iOS | [skills/mobile-ios/T2133-protect-data-security-ios/SKILL.md](./skills/mobile-ios/T2133-protect-data-security-ios/SKILL.md) | 8 | CODE_FIX | Pending |

### mobile-general
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T146 | Use encryption for network communications in mobile environments | [skills/mobile-general/T146-encrypt-mobile-network-communications/SKILL.md](./skills/mobile-general/T146-encrypt-mobile-network-communications/SKILL.md) | 8 | CODE_FIX | Pending |
| T160 | Avoid relying on jailbreak or root detection as a strong security measure | [skills/mobile-general/T160-do-not-rely-on-root-jailbreak-detection/SKILL.md](./skills/mobile-general/T160-do-not-rely-on-root-jailbreak-detection/SKILL.md) | 7 | CODE_FIX | Pending |
| T161 | Treat unique device IDs as personal information | [skills/mobile-general/T161-treat-device-ids-as-personal-information/SKILL.md](./skills/mobile-general/T161-treat-device-ids-as-personal-information/SKILL.md) | 8 | CODE_FIX | Pending |
| T165 | Do not rely on Unique Device ID values in security controls | [skills/mobile-general/T165-do-not-rely-on-device-ids-in-security-controls/SKILL.md](./skills/mobile-general/T165-do-not-rely-on-device-ids-in-security-controls/SKILL.md) | 9 | CODE_FIX | Pending |
| T316 | Prevent unauthorized access to information through keyboard caches | [skills/mobile-general/T316-prevent-keyboard-cache-leaks/SKILL.md](./skills/mobile-general/T316-prevent-keyboard-cache-leaks/SKILL.md) | 7 | CODE_FIX | Pending |

### client-data-protection
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T148 | Avoid caching confidential data on client | [skills/client-data-protection/T148-avoid-caching-confidential-data-on-client/SKILL.md](./skills/client-data-protection/T148-avoid-caching-confidential-data-on-client/SKILL.md) | 7 | CODE_FIX | Pending |
| T295 | Avoid storing unencrypted confidential data without access control mechanisms | [skills/client-data-protection/T295-no-unencrypted-confidential-data-without-access-control/SKILL.md](./skills/client-data-protection/T295-no-unencrypted-confidential-data-without-access-control/SKILL.md) | 7 | CODE_FIX | Pending |
| T1468 | Encrypt sensitive data at rest in the browser | [skills/client-data-protection/T1468-encrypt-sensitive-data-at-rest-in-browser/SKILL.md](./skills/client-data-protection/T1468-encrypt-sensitive-data-at-rest-in-browser/SKILL.md) | 9 | CODE_FIX | Pending |
| T214 | Protect confidential files on operating system or server | [skills/client-data-protection/T214-protect-confidential-files-on-server/SKILL.md](./skills/client-data-protection/T214-protect-confidential-files-on-server/SKILL.md) | 9 | CODE_FIX | Pending |

### privacy
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T178 | Obtain consent from users prior to collecting personal information | [skills/privacy/T178-obtain-consent-before-collecting-personal-information/SKILL.md](./skills/privacy/T178-obtain-consent-before-collecting-personal-information/SKILL.md) | 10 | CODE_FIX | Pending |
| T604 | Implement a consent withdrawal mechanism | [skills/privacy/T604-consent-withdrawal-mechanism/SKILL.md](./skills/privacy/T604-consent-withdrawal-mechanism/SKILL.md) | 10 | CODE_FIX | Pending |
| T742 | Implement technical measures to ensure the accuracy of personal information | [skills/privacy/T742-ensure-accuracy-of-personal-information/SKILL.md](./skills/privacy/T742-ensure-accuracy-of-personal-information/SKILL.md) | 7 | CODE_FIX | Pending |
| T754 | Enable the restriction of processing personal information for a specific purpose | [skills/privacy/T754-restrict-processing-of-personal-information/SKILL.md](./skills/privacy/T754-restrict-processing-of-personal-information/SKILL.md) | 8 | CODE_FIX | Pending |

### logging-audit
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T349 | Protect audit information and logs against unauthorized access | [skills/logging-audit/T349-protect-audit-information-and-logs/SKILL.md](./skills/logging-audit/T349-protect-audit-information-and-logs/SKILL.md) | 7 | CODE_FIX | Pending |
| T2602 | Log typical database and server activities and related metadata | [skills/logging-audit/T2602-log-database-and-server-activities/SKILL.md](./skills/logging-audit/T2602-log-database-and-server-activities/SKILL.md) | 8 | CODE_FIX | Pending |

### release-supply-chain
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T49 | Disable and remove debug capabilities and code/data, and prepare application for release | [skills/release-supply-chain/T49-disable-debug-capabilities-for-release/SKILL.md](./skills/release-supply-chain/T49-disable-debug-capabilities-for-release/SKILL.md) | 7 | CODE_FIX | Pending |
| T186 | Use recommended settings and the latest patches for third party libraries and software | [skills/release-supply-chain/T186-third-party-library-patches-and-secure-settings/SKILL.md](./skills/release-supply-chain/T186-third-party-library-patches-and-secure-settings/SKILL.md) | 10 | CODE_FIX | Pending |

### infrastructure
| ID | Title | Skill File | Priority | Category | Status |
|----|-------|-----------|----------|----------|--------|
| T374 | Offload HTTP request handling to dedicated modules | [skills/infrastructure/T374-offload-http-request-handling/SKILL.md](./skills/infrastructure/T374-offload-http-request-handling/SKILL.md) | 7 | INFRA | Documented |
| T4595 | Protect processes with high privileges | [skills/infrastructure/T4595-protect-high-privilege-processes/SKILL.md](./skills/infrastructure/T4595-protect-high-privilege-processes/SKILL.md) | 8 | INFRA | Documented |
| T4593 | Monitor the behaviour on endpoint | [skills/infrastructure/T4593-monitor-endpoint-behaviour/SKILL.md](./skills/infrastructure/T4593-monitor-endpoint-behaviour/SKILL.md) | 7 | INFRA | Documented |
| T21 | Ensure all data in transit is encrypted using a secure TLS channel | [skills/infrastructure/T21-encrypt-data-in-transit-tls/SKILL.md](./skills/infrastructure/T21-encrypt-data-in-transit-tls/SKILL.md) | 8 | INFRA | Documented |
| T69 | Strong password requirements for server-to-server system accounts | [skills/infrastructure/T69-strong-credentials-for-system-accounts/SKILL.md](./skills/infrastructure/T69-strong-credentials-for-system-accounts/SKILL.md) | 8 | INFRA | Documented |
| T2157 | Secure email and messaging in web applications | [skills/infrastructure/T2157-secure-email-and-messaging/SKILL.md](./skills/infrastructure/T2157-secure-email-and-messaging/SKILL.md) | 7 | INFRA | Documented |

## Completion Requirements

**ALL 70 file-tracked countermeasures must be addressed. No exceptions.**

## Progress Tracking

| Domain | Total | Implemented | Documented | Remaining |
|--------|-------|-------------|------------|-----------|
| authentication | 5 | 0 | 0 | 5 |
| session-management | 3 | 0 | 0 | 3 |
| authorization | 5 | 0 | 0 | 5 |
| database-security | 5 | 0 | 0 | 5 |
| web-security | 6 | 0 | 0 | 6 |
| api-security | 6 | 0 | 0 | 6 |
| crypto-secrets | 6 | 0 | 0 | 6 |
| mobile-android | 7 | 0 | 0 | 7 |
| mobile-ios | 4 | 0 | 0 | 4 |
| mobile-general | 5 | 0 | 0 | 5 |
| client-data-protection | 4 | 0 | 0 | 4 |
| privacy | 4 | 0 | 0 | 4 |
| logging-audit | 2 | 0 | 0 | 2 |
| release-supply-chain | 2 | 0 | 0 | 2 |
| infrastructure | 6 | 0 | 0 | 6 |
| **TOTAL** | **70** | **0** | **0** | **70** |

**Remaining MUST reach 0 before completion.**

## Verification Checklist

- [ ] All CODE_FIX countermeasures have secure implementations
- [ ] All non-code items documented with justification
- [ ] Total addressed = 70
<!-- SDE-SECURITY-HARDENING-END -->
