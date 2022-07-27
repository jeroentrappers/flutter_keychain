import 'dart:async';

import 'package:flutter/services.dart';

class FlutterKeychain {
  static const MethodChannel _channel =
      const MethodChannel('plugin.appmire.be/flutter_keychain');

  // put - store the value for a key
  static Future<void> put({required String key, required String value}) async =>
      _channel.invokeMethod('put', {'key': key, 'value': value});

  // get - get the value for a given key
  static Future<String?> get({required String key}) async =>
      await _channel.invokeMethod('get', {'key': key});

  // remove - remove entry for a given key
  static Future<void> remove({required String key}) async =>
      await _channel.invokeMethod('remove', {'key': key});

  // clear - clear the keychain
  static Future<void> clear() async => await _channel.invokeMethod('clear');
}
