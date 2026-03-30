# Repository Guidelines

## Project Structure & Module Organization
`lib/flutter_keychain.dart` exposes the public Flutter API. Native platform code lives in `android/src/main/kotlin/be/appmire/flutterkeychain/` and `ios/Classes/`. Package-level Dart tests are in `test/`, Android JVM tests are in `android/src/test/`, and Android device/emulator tests are in `android/src/androidTest/`. Use `example/` to validate plugin behavior in a real Flutter app. Do not commit generated output from `build/` or `example/build/`.

## Build, Test, and Development Commands
Use FVM in this repo; `.fvm/fvm_config.json` pins Flutter `3.41.4`.

- `fvm flutter pub get` installs package dependencies.
- `fvm flutter test` runs the Dart test suite in `test/`.
- `cd android && ./gradlew test` runs Android JVM tests such as `AesStringEncryptorTest`.
- `cd android && ./gradlew connectedAndroidTest` runs Android instrumentation tests on a connected emulator/device.
- `cd example && fvm flutter run` launches the example app for manual verification.
- `fvm flutter format lib test example` formats Dart sources before review.

## Coding Style & Naming Conventions
Follow standard Flutter and Kotlin style: 2-space indentation in Dart, 4-space indentation in Kotlin/Objective-C, and keep public APIs small and explicit. Use `UpperCamelCase` for classes, `lowerCamelCase` for methods and fields, and descriptive test names that state behavior, for example `encryptor_roundtrip_unicode`. Prefer targeted comments over restating the code.

## Testing Guidelines
Add or update tests with every behavior change. Put Dart API tests in `test/*_test.dart`; keep native Android unit tests in `android/src/test/...` and emulator-dependent coverage in `android/src/androidTest/...`. Favor round-trip, null-handling, and regression cases for storage/encryption changes. Run `fvm flutter test` before every PR; run Gradle tests when touching Android code.

## Commit & Pull Request Guidelines
Recent history mixes short summaries with conventional prefixes, for example `fix: symbol not found crash on Xcode 15` and `Bump dependencies`. Prefer concise, imperative commit subjects and use a `fix:` prefix for bug fixes when it adds clarity. PRs should describe the user-visible change, list tested commands, link related issues, and include screenshots only when the `example/` UI changes.

## Security & Configuration Tips
This package stores secrets via iOS Keychain and Android Keystore. Do not log stored values, test secrets, or keystore material. Keep Android `minSdkVersion >= 18`, and validate any changes to iOS access-group or label configuration through the example app before merging.
