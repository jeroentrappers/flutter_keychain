# flutter_keychain

A Flutter plugin for supporting secure storage of strings via Keychain and Keystore

If you have other types you want to store, you need to serialize to and from UTF-8 strings.

* [Keychain](https://developer.apple.com/library/content/documentation/Security/Conceptual/keychainServConcepts/01introduction/introduction.html#//apple_ref/doc/uid/TP30000897-CH203-TP1) is used for iOS
* AES encryption is used for Android. AES secret key is encrypted with RSA and RSA key is stored in [KeyStore](https://developer.android.com/training/articles/keystore.html)

*Note* KeyStore was introduced in Android 4.3 (API level 18). The plugin does not work on earlier versions.


## Getting Started
```dart

import 'package:flutter_keychain/flutter_keychain.dart';
...

// Get value
var value = await FlutterKeychain.get(key: "key");

// Put value
await FlutterKeychain.put(key: "key", value: "value");

// Remove item
await FlutterKeychain.remove(key: "key");

// Clear the secure store
await FlutterKeychain.clear();

```

### iOS configuration (optional)

Call `configure` before the first read/write when you need non-default Keychain behaviour.
`accessGroup`, `label`, `accessible`, and `accessibilityMigration` are iOS-only.

```dart
await FlutterKeychain.configure(
  accessGroup: 'group.com.example.shared',
  label: 'My App Credentials',
  accessible: FlutterKeychainAccessible.afterFirstUnlock,
  // Default: do not change existing items (reads stay compatible).
  accessibilityMigration: FlutterKeychainAccessibilityMigration.none,
);
```

`accessible` is applied when **adding** new Keychain items. Reads and deletes do not filter by
`accessible`, so data written before you changed the setting remains readable.

To upgrade older items (for example from the system default `whenUnlocked` to
`afterFirstUnlock`), opt in to lazy migration:

```dart
await FlutterKeychain.configure(
  accessible: FlutterKeychainAccessible.afterFirstUnlock,
  accessibilityMigration: FlutterKeychainAccessibilityMigration.automatic,
);
```

With `automatic`, a successful `get` or `put` update attempts to migrate that item's
`kSecAttrAccessible`. Migration failures are logged and do not affect the returned value.

On Android, `configure` is a no-op. Android does not expose a per-item equivalent of
`kSecAttrAccessible`; stored values use the plugin's existing Keystore-backed encryption.

### Configure Android version
In `[project]/android/app/build.gradle` set `minSdkVersion` to >= 18.
```
android {
    ...
    defaultConfig {
        ...
        minSdkVersion 18
        ...
    }
}
```

## Contributing

For help on editing plugin code, view the [documentation](https://flutter.io/developing-packages/#edit-plugin-package).
