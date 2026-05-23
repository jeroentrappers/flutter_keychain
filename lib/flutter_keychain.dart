/// Flutter API for storing secrets in the iOS Keychain and Android Keystore.
library flutter_keychain;

import 'dart:async';

import 'package:flutter/services.dart';

/// iOS Keychain accessibility (`kSecAttrAccessible`) for stored items.
///
/// Has no effect on Android.
enum FlutterKeychainAccessible {
  /// `kSecAttrAccessibleWhenUnlocked`
  whenUnlocked('whenUnlocked'),

  /// `kSecAttrAccessibleAfterFirstUnlock`
  afterFirstUnlock('afterFirstUnlock'),

  /// `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`
  whenPasscodeSetThisDeviceOnly('whenPasscodeSetThisDeviceOnly'),

  /// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
  whenUnlockedThisDeviceOnly('whenUnlockedThisDeviceOnly'),

  /// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
  afterFirstUnlockThisDeviceOnly('afterFirstUnlockThisDeviceOnly');

  const FlutterKeychainAccessible(this.value);

  /// Stable string sent over the method channel to iOS.
  final String value;
}

/// How iOS should handle existing Keychain items whose `kSecAttrAccessible`
/// differs from the value passed to [FlutterKeychain.configure].
///
/// Has no effect on Android.
enum FlutterKeychainAccessibilityMigration {
  /// Do not change existing items. Reads remain compatible with older entries;
  /// only newly added items use the configured [FlutterKeychainAccessible].
  none('none'),

  /// After a successful read or update, attempt to migrate the item to the
  /// configured [FlutterKeychainAccessible]. Migration failures are logged and
  /// do not affect the operation result.
  automatic('automatic');

  const FlutterKeychainAccessibilityMigration(this.value);

  /// Stable string sent over the method channel to iOS.
  final String value;
}

/// Provides static helpers for storing and retrieving secure key-value pairs.
class FlutterKeychain {
  static const MethodChannel _channel =
      MethodChannel('plugin.appmire.be/flutter_keychain');

  /// Creates a [FlutterKeychain] instance.
  ///
  /// The plugin API is exposed through static methods, so creating an
  /// instance is usually unnecessary.
  FlutterKeychain();

  /// Configures optional iOS-specific keychain settings.
  ///
  /// This is a no-op on Android.
  ///
  /// [accessGroup] sets `kSecAttrAccessGroup`, enabling shared keychain access
  /// between apps in the same App Group.
  ///
  /// [label] sets `kSecAttrLabel`, which controls how the item appears in the
  /// iOS Passwords app.
  ///
  /// [accessible] sets `kSecAttrAccessible` for **new** items and for migration
  /// when [accessibilityMigration] is [FlutterKeychainAccessibilityMigration.automatic].
  /// Reads and deletes do not filter by this attribute, so older entries remain
  /// readable after you change the configured value.
  ///
  /// [accessibilityMigration] controls whether existing items are lazily migrated
  /// to [accessible] after a successful read or update. Defaults to
  /// [FlutterKeychainAccessibilityMigration.none].
  ///
  /// Call this before the first [get], [put], [remove], or [clear] when
  /// non-default values are required.
  static Future<void> configure({
    String? accessGroup,
    String? label,
    FlutterKeychainAccessible? accessible,
    FlutterKeychainAccessibilityMigration accessibilityMigration =
        FlutterKeychainAccessibilityMigration.none,
  }) async =>
      _channel.invokeMethod('configure', {
        'accessGroup': accessGroup,
        'label': label,
        'accessible': accessible?.value,
        'accessibilityMigration': accessibilityMigration.value,
      });

  /// Stores [value] for [key].
  static Future<void> put({required String key, required String value}) async =>
      _channel.invokeMethod('put', {'key': key, 'value': value});

  /// Returns the stored value for [key].
  ///
  /// Returns `null` when the key is absent or when the stored value can no
  /// longer be decrypted on Android.
  static Future<String?> get({required String key}) async =>
      await _channel.invokeMethod('get', {'key': key});

  /// Removes the stored value for [key].
  static Future<void> remove({required String key}) async =>
      await _channel.invokeMethod('remove', {'key': key});

  /// Removes all stored entries.
  ///
  /// On Android, this preserves the AES key used to encrypt stored values.
  static Future<void> clear() async => await _channel.invokeMethod('clear');
}
