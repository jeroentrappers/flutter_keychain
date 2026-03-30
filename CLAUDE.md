# flutter_keychain

A Flutter plugin for secure string storage using native Keychain (iOS) and Keystore (Android).

## Project Overview

- **Package:** `flutter_keychain` v2.3.0
- **Author:** Jeroen Trappers (Copyright 2018, BSD 3-Clause)
- **Pub:** https://pub.dev/packages/flutter_keychain
- **Platforms:** iOS (Objective-C) and Android (Kotlin)
- **Method channel:** `plugin.appmire.be/flutter_keychain`

## Repository Structure

```
flutter_keychain/
├── lib/flutter_keychain.dart     # Dart public API (MethodChannel)
├── android/                      # Kotlin implementation (AES + RSA/KeyStore)
├── ios/Classes/                  # Objective-C implementation (native Keychain)
├── example/                      # Demo Flutter app
│   ├── lib/main.dart
│   └── test/widget_test.dart
├── pubspec.yaml
└── CHANGELOG.md
```

## Public API (Dart)

Four static methods, all async:

```dart
FlutterKeychain.put(key: String, value: String)
FlutterKeychain.get(key: String) → Future<String?>
FlutterKeychain.remove(key: String)
FlutterKeychain.clear()
```

## Platform Requirements

- **iOS:** 8.0+ — uses `kSecClassGenericPassword` Keychain APIs, service name `flutter_keychain`
- **Android:** API 18+ (4.3+) — required for AndroidKeyStore; AES-128-CBC with RSA-2048-wrapped key stored in SharedPreferences

## Development Commands

```bash
# Run example app
cd example && flutter run

# Run tests
cd example && flutter test

# Analyze Dart code
flutter analyze

# Format Dart code
dart format lib/
```

## Dependencies

- No external Dart packages — only Flutter SDK
- Android: `kotlin-stdlib-jdk7` (1.6.10), compileSdk 31, minSdk 16
- iOS: Flutter framework only, no CocoaPods dependencies

## Key Implementation Details

**Android encryption flow:**
1. RSA key pair generated in AndroidKeyStore (alias: `{packageName}.FlutterKeychain`, 2048-bit, 25-year expiry)
2. AES-128 key generated, RSA-encrypted, stored in SharedPreferences under key `W0n5hlJtrAH0K8mIreDGxtG`
3. Data encrypted with AES/CBC/PKCS7; random 16-byte IV prepended; Base64 encoded
4. API < M uses `AndroidOpenSSL` provider; API >= M uses default provider

**iOS:** Values stored directly as UTF-8 NSData via Keychain; OS handles encryption transparently.

## No CI/CD

No automated pipelines configured. Tests and releases are manual.
