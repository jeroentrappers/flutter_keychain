import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_keychain_method_channel.dart';

abstract class FlutterKeychainPlatform extends PlatformInterface {
  /// Constructs a FlutterKeychainPlatform.
  FlutterKeychainPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterKeychainPlatform _instance = MethodChannelFlutterKeychain();

  /// The default instance of [FlutterKeychainPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterKeychain].
  static FlutterKeychainPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterKeychainPlatform] when
  /// they register themselves.
  static set instance(FlutterKeychainPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Clears the keychain.
  ///
  /// The [keyChainName] value can be used on iOS to specify the keychain service name.
  Future<void> clear({String? keyChainName}) {
    throw UnimplementedError('clear() has not been implemented.');
  }

  /// Get the value for the given [key].
  ///
  /// The [keyChainName] value can be used on iOS to specify the keychain service name.
  Future<String?> get({required String key, String? keyChainName}) {
    throw UnimplementedError('get() has not been implemented.');
  }

  /// Set the [value] for the given [key].
  ///
  /// The [keyChainName] value can be used on iOS to specify the keychain service name.
  Future<void> put({
    required String key,
    required String value,
    String? keyChainName,
  }) {
    throw UnimplementedError('put() has not been implemented.');
  }

  /// Remove the value for the given [key].
  ///
  /// The [keyChainName] value can be used on iOS to specify the keychain service name.
  Future<void> remove({required String key, String? keyChainName}) {
    throw UnimplementedError('remove() has not been implemented.');
  }
}
