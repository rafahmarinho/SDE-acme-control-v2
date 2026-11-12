---
name: t5637-location-data-handling-ios
description: The PRD does not need device location; ship the iOS app without location permissions, and apply minimal, when-in-use, approximate location rules if it is ever added.
---

# T5637: Implement best practices for handling location data (iOS)

**Category:** CODE_FIX
**SD Elements:** [T5637](https://sde-ent-echo.sdelab.net/bunits/afrika-sc-labs/acme-control-v2/acme-control-v2/tasks/phase/development/33-T5637/)
**Priority:** 7

**Spec Context:**
> "Crie páginas de plantas" / "Prepare dados de demonstração com duas plantas industriais."
> Source: docs/specs/PRD.md, paragraphs 4 and 5 (plant locations are data, not device location)

**What the spec implies (naive approach):**
Request "Always" location to show the nearest plant or to log where an operator issued a command.

**Secure Implementation Pattern:**
```text
ios/Runner/Info.plist: no NSLocation*UsageDescription keys
If ever needed: NSLocationWhenInUseUsageDescription only, request on user action,
use reduced accuracy, never store raw coordinates with user identity.
```

**Implementation Guidance:**
- Plant coordinates (if shown) come from the database, not the device.
- Audit plugin dependencies so none adds location usage silently.

**Success Criteria:**
- [ ] Built Info.plist contains no location usage keys (or only WhenInUse with justification).

**Status:** Pending
