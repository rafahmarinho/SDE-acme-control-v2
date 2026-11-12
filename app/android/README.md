# Android

Run `flutter create . --platforms=android` from `app/` to generate the Gradle project. Existing
hardened files are kept (`flutter create` does not overwrite them):

- `app/src/main/AndroidManifest.xml` - only INTERNET/ACCESS_NETWORK_STATE, backups disabled,
  cleartext disabled, only the launcher activity exported, App Link limited to `/auth/callback`.
- `app/src/main/res/xml/network_security_config.xml` - HTTPS only, system CAs only.
- `app/src/main/res/xml/data_extraction_rules.xml` - excludes all data from backup/transfer.
- `app/src/debug/res/xml/network_security_config.xml` - debug-only cleartext to `10.0.2.2`.

After generating, add to `android/app/build.gradle.kts` `defaultConfig`:

```kotlin
manifestPlaceholders["appLinkHost"] = "<your-web-host>"
```

and publish `/.well-known/assetlinks.json` on the web host. Release builds:
`flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`.
Check the merged manifest for plugin-added permissions, services or providers before each release.
