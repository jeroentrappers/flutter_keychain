import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_keychain/flutter_keychain.dart';
import 'package:flutter_keychain/flutter_keychain_platform_interface.dart';
import 'package:flutter_keychain/flutter_keychain_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// TODO: add tests for get/put/remove/clear

class MockFlutterKeychainPlatform with MockPlatformInterfaceMixin implements FlutterKeychainPlatform {
  final Map<String, String> _cache = {};

  @override
  Future<void> clear({String? keyChainName}) async {
    _cache.clear();
  }

  @override
  Future<String?> get({required String key, String? keyChainName}) async {
    return _cache[key];
  }

  @override
  Future<void> put({
    required String key,
    required String value,
    String? keyChainName,
  }) async {
    _cache[key] = value;
  }

  @override
  Future<void> remove({required String key, String? keyChainName}) {
    _cache.remove(key);

    return Future<void>.value();
  }
}

void main() {
  final FlutterKeychainPlatform initialPlatform = FlutterKeychainPlatform.instance;

  test('$MethodChannelFlutterKeychain is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterKeychain>());
  });

  /*
  test('getPlatformVersion', () async {
    FlutterKeychain flutterKeychainPlugin = FlutterKeychain();
    MockFlutterKeychainPlatform fakePlatform = MockFlutterKeychainPlatform();
    FlutterKeychainPlatform.instance = fakePlatform;

    expect(await flutterKeychainPlugin.getPlatformVersion(), '42');
  });*/
}
