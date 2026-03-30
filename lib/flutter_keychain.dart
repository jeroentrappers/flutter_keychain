import 'dart:async';

import 'package:flutter/services.dart';

class FlutterKeychain {
  static const MethodChannel _channel =
      MethodChannel('plugin.appmire.be/flutter_keychain');

  // configure - optional iOS-specific settings. No-op on Android.
  //
  // [accessGroup] sets kSecAttrAccessGroup, enabling shared keychain access
  // between apps in the same App Group (e.g. "group.com.example.shared").
  // Pass null to use the default app-specific access group.
  //
  // [label] sets kSecAttrLabel, which controls how the item appears in the
  // iOS Passwords app (Settings > Passwords). Pass null to omit the label.
  //
  // Must be called before the first get/put/remove/clear if non-default
  // values are desired.
  static Future<void> configure({
    String? accessGroup,
    String? label,
  }) async =>
      _channel.invokeMethod('configure', {
        'accessGroup': accessGroup,
        'label': label,
      });

  // put - store the value for a key
  static Future<void> put({required String key, required String value}) async =>
      _channel.invokeMethod('put', {'key': key, 'value': value});

  // get - get the value for a given key; returns null when the key is absent
  // or when the stored value can no longer be decrypted (Android).
  static Future<String?> get({required String key}) async =>
      await _channel.invokeMethod('get', {'key': key});

  // remove - remove entry for a given key
  static Future<void> remove({required String key}) async =>
      await _channel.invokeMethod('remove', {'key': key});

  // clear - clear all keychain entries (preserves the Android AES key)
  static Future<void> clear() async => await _channel.invokeMethod('clear');
}
