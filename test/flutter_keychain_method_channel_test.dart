import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_keychain/flutter_keychain_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // TODO: test get/put/remove/clear

  MethodChannelFlutterKeychain platform = MethodChannelFlutterKeychain();
  const MethodChannel channel = MethodChannel('plugin.appmire.be/flutter_keychain');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
}
