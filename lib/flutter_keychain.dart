import 'flutter_keychain_platform_interface.dart';

/// The Flutter Keychain plugin.
class FlutterKeychain {
  /// Clears the keychain.
  ///
  /// The [keyChainName] value can be used on iOS to specify the keychain service name.
  static Future<void> clear({String? keyChainName}) {
    return FlutterKeychainPlatform.instance.clear(
      keyChainName: keyChainName,
    );
  }

  /// Get the value for the given [key].
  ///
  /// The [keyChainName] value can be used on iOS to specify the keychain service name.
  static Future<String?> get({required String key, String? keyChainName}) {
    return FlutterKeychainPlatform.instance.get(
      key: key,
      keyChainName: keyChainName,
    );
  }

  /// Set the [value] for the given [key].
  ///
  /// The [keyChainName] value can be used on iOS to specify the keychain service name.
  static Future<void> put({
    required String key,
    required String value,
    String? keyChainName,
  }) {
    return FlutterKeychainPlatform.instance.put(
      key: key,
      value: value,
      keyChainName: keyChainName,
    );
  }

  /// Remove the value for the given [key].
  ///
  /// The [keyChainName] value can be used on iOS to specify the keychain service name.
  static Future<void> remove({required String key, String? keyChainName}) {
    return FlutterKeychainPlatform.instance.remove(
      key: key,
      keyChainName: keyChainName,
    );
  }
}
