## 3.0.1

* Update public API documentation comments for pub.dev scoring.

## 3.0.0

**Breaking changes**
* Android: `minSdk` raised from 16 to 18 (API 18 is the true minimum for AndroidKeyStore).
* Android: V1 plugin embedding (`registerWith(Registrar)`) removed.
* iOS: deployment target raised from 8.0 to 12.0.

**Bug fixes**
* Android: fix ANR caused by crypto initialisation blocking the main thread.
  All KeyStore and AES operations now run on `Dispatchers.IO` (fixes #57).
* Android: method calls that arrive before async init completes are queued
  and replayed once the crypto engine is ready.
* Android: `get` now returns `null` instead of throwing on `BadPaddingException`
  / `InvalidKeyException`, preventing crashes after key rotation or data
  corruption (fixes #37).
* iOS: fix `CFDataRef` memory leak in `get:` when `SecItemCopyMatching` returns
  a non-NULL reference on error.

**New features**
* Dart: new `FlutterKeychain.configure({accessGroup, label})` method.
* iOS: `accessGroup` sets `kSecAttrAccessGroup` for shared keychain access
  between apps in the same App Group (fixes #48).
* iOS: `label` sets `kSecAttrLabel` so items appear in iOS Passwords
  (Settings → Passwords) (fixes #43).
* iOS: Swift Package Manager support added via `ios/flutter_keychain/Package.swift`
  (fixes #58). CocoaPods remains supported during the transition period.

**Build / toolchain updates**
* Android: AGP 7.1.2 → 8.3.2; `namespace` declaration is now unconditional
  (fixes #46, #41).
* Android: Kotlin 1.6.10 → 1.9.25.
* Android: `compileSdk` / `targetSdk` 31 → 35.
* Android: `kotlinx-coroutines-android 1.7.3` added as a dependency.

## 2.3.0

* Update dependencies, gradle

## 2.2.1

* Update android deps
* Clean up

## 2.2.0

* Update android deps
* Clean up

## 2.1.0

* Android embedding thanks https://github.com/StanleyCocos for the PR!

## 2.0.1

* fix Nullability issue in the Kotlin code thanks https://github.com/wbusey0 for the PR.

## 2.0.0

* Migrate to null-safety
* Minimum Dart SDK 2.12.0 thanks https://github.com/wbusey0 for the PR.

## 1.0.1

* Removed `keys()`

## 1.0.0

* Bump kotlin, gradle and android version to support AndroidX.

## 0.0.8

* Fix small issue with Kotlin String? type

## 0.0.7

* Bump kotlin version to 1.2.51

## 0.0.6

* Added commit to delete and clear for android.
* Updated xcode example project, because of duplicate framework (new version of flutter)

## 0.0.3 - 0.0.5

* Bugfixes and hardening of the code

## 0.0.2

* Added iOS support (Objective-C for now)

## 0.0.1

* Intial release with only Android support. iOS support due to follow.
