import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_keychain_platform_interface.dart';

/// An implementation of [FlutterKeychainPlatform] that uses method channels.
class MethodChannelFlutterKeychain extends FlutterKeychainPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('plugin.appmire.be/flutter_keychain');

  @override
  Future<void> clear({String? keyChainName}) {
    return methodChannel.invokeMethod<void>(
      'clear',
      {'keyChainName': keyChainName},
    );
  }

  @override
  Future<String?> get({required String key, String? keyChainName}) {
    return methodChannel.invokeMethod<String>(
      'get',
      {'key': key, 'keyChainName': keyChainName},
    );
  }

  @override
  Future<void> put({required String key, required String value, String? keyChainName}) {
    return methodChannel.invokeMethod<void>(
      'put',
      {'key': key, 'value': value, 'keyChainName': keyChainName},
    );
  }

  @override
  Future<void> remove({required String key, String? keyChainName}) {
    return methodChannel.invokeMethod<void>(
      'remove',
      {'key': key, 'keyChainName': keyChainName},
    );
  }
}
