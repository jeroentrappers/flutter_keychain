/// Flutter API for storing secrets in the iOS Keychain and Android Keystore.
library flutter_keychain;

import 'dart:async';

import 'package:flutter/services.dart';

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
  /// Call this before the first [get], [put], [remove], or [clear] when
  /// non-default values are required.
  static Future<void> configure({
    String? accessGroup,
    String? label,
  }) async =>
      _channel.invokeMethod('configure', {
        'accessGroup': accessGroup,
        'label': label,
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
