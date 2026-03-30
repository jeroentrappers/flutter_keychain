import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_keychain/flutter_keychain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugin.appmire.be/flutter_keychain');

  // In-memory store that simulates the native keychain/keystore.
  final Map<String, String> store = {};

  setUp(() {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'configure':
          return null;
        case 'put':
          final key = call.arguments['key'] as String;
          final value = call.arguments['value'] as String;
          store[key] = value;
          return null;
        case 'get':
          final key = call.arguments['key'] as String;
          return store[key]; // null when missing
        case 'remove':
          final key = call.arguments['key'] as String;
          store.remove(key);
          return null;
        case 'clear':
          store.clear();
          return null;
        default:
          throw PlatformException(
              code: 'NOT_IMPLEMENTED', message: 'method not implemented');
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // ---------------------------------------------------------------------------
  // put
  // ---------------------------------------------------------------------------
  group('FlutterKeychain.put', () {
    test('stores a string value for a given key', () async {
      await FlutterKeychain.put(key: 'token', value: 'abc123');
      expect(store['token'], 'abc123');
    });

    test('overwrites an existing value', () async {
      await FlutterKeychain.put(key: 'k', value: 'first');
      await FlutterKeychain.put(key: 'k', value: 'second');
      expect(store['k'], 'second');
    });

    test('stores an empty string', () async {
      await FlutterKeychain.put(key: 'empty', value: '');
      expect(store['empty'], '');
    });

    test('stores a unicode value', () async {
      const v = '日本語テスト 🔑 àéîõü';
      await FlutterKeychain.put(key: 'unicode', value: v);
      expect(store['unicode'], v);
    });

    test('stores a long string (10 000 chars)', () async {
      final v = 'A' * 10000;
      await FlutterKeychain.put(key: 'long', value: v);
      expect(store['long'], v);
    });

    test('stores special/punctuation characters', () async {
      const v = r'!@#$%^&*()_+-=[]{}|;:",.<>?/\`~';
      await FlutterKeychain.put(key: 'special', value: v);
      expect(store['special'], v);
    });

    test('stores a newline and tab', () async {
      const v = 'line1\nline2\ttabbed';
      await FlutterKeychain.put(key: 'whitespace', value: v);
      expect(store['whitespace'], v);
    });

    test('stores a JSON-formatted string', () async {
      const v = '{"user":"alice","token":"abc","active":true}';
      await FlutterKeychain.put(key: 'json', value: v);
      expect(store['json'], v);
    });

    test('stores a key whose name contains spaces', () async {
      await FlutterKeychain.put(key: 'my key name', value: 'v');
      expect(store['my key name'], 'v');
    });

    test('multiple distinct keys are stored independently', () async {
      await FlutterKeychain.put(key: 'a', value: '1');
      await FlutterKeychain.put(key: 'b', value: '2');
      await FlutterKeychain.put(key: 'c', value: '3');
      expect(store['a'], '1');
      expect(store['b'], '2');
      expect(store['c'], '3');
    });

    test('completes without throwing', () async {
      await expectLater(
          FlutterKeychain.put(key: 'k', value: 'v'), completes);
    });
  });

  // ---------------------------------------------------------------------------
  // get
  // ---------------------------------------------------------------------------
  group('FlutterKeychain.get', () {
    test('returns the stored value', () async {
      await FlutterKeychain.put(key: 'token', value: 'secret');
      expect(await FlutterKeychain.get(key: 'token'), 'secret');
    });

    test('returns null for a key that was never stored', () async {
      expect(await FlutterKeychain.get(key: 'ghost'), isNull);
    });

    test('returns the latest value after an overwrite', () async {
      await FlutterKeychain.put(key: 'k', value: 'old');
      await FlutterKeychain.put(key: 'k', value: 'new');
      expect(await FlutterKeychain.get(key: 'k'), 'new');
    });

    test('returns an empty string when stored as empty', () async {
      await FlutterKeychain.put(key: 'e', value: '');
      expect(await FlutterKeychain.get(key: 'e'), '');
    });

    test('returns unicode characters intact', () async {
      const v = '日本語テスト 🔑 àéîõü';
      await FlutterKeychain.put(key: 'u', value: v);
      expect(await FlutterKeychain.get(key: 'u'), v);
    });

    test('returns a long string intact', () async {
      final v = 'B' * 10000;
      await FlutterKeychain.put(key: 'long', value: v);
      expect(await FlutterKeychain.get(key: 'long'), v);
    });

    test('returns correct value for each key when many are stored', () async {
      await FlutterKeychain.put(key: 'x', value: 'alpha');
      await FlutterKeychain.put(key: 'y', value: 'beta');
      await FlutterKeychain.put(key: 'z', value: 'gamma');
      expect(await FlutterKeychain.get(key: 'x'), 'alpha');
      expect(await FlutterKeychain.get(key: 'y'), 'beta');
      expect(await FlutterKeychain.get(key: 'z'), 'gamma');
    });

    test('returns null after the key was removed', () async {
      await FlutterKeychain.put(key: 'gone', value: 'present');
      await FlutterKeychain.remove(key: 'gone');
      expect(await FlutterKeychain.get(key: 'gone'), isNull);
    });

    test('returns null after clear', () async {
      await FlutterKeychain.put(key: 'k', value: 'v');
      await FlutterKeychain.clear();
      expect(await FlutterKeychain.get(key: 'k'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // remove
  // ---------------------------------------------------------------------------
  group('FlutterKeychain.remove', () {
    test('removes a key so it no longer exists in the store', () async {
      await FlutterKeychain.put(key: 'del', value: 'data');
      await FlutterKeychain.remove(key: 'del');
      expect(store.containsKey('del'), isFalse);
    });

    test('get returns null after removal', () async {
      await FlutterKeychain.put(key: 'del', value: 'data');
      await FlutterKeychain.remove(key: 'del');
      expect(await FlutterKeychain.get(key: 'del'), isNull);
    });

    test('removing a non-existent key completes without throwing', () async {
      await expectLater(FlutterKeychain.remove(key: 'ghost'), completes);
    });

    test('only removes the specified key, not others', () async {
      await FlutterKeychain.put(key: 'keep', value: 'safe');
      await FlutterKeychain.put(key: 'del', value: 'bye');
      await FlutterKeychain.remove(key: 'del');
      expect(await FlutterKeychain.get(key: 'keep'), 'safe');
      expect(await FlutterKeychain.get(key: 'del'), isNull);
    });

    test('can re-add a value after its key was removed', () async {
      await FlutterKeychain.put(key: 'k', value: 'v1');
      await FlutterKeychain.remove(key: 'k');
      await FlutterKeychain.put(key: 'k', value: 'v2');
      expect(await FlutterKeychain.get(key: 'k'), 'v2');
    });

    test('removes all listed keys correctly', () async {
      for (var i = 0; i < 5; i++) {
        await FlutterKeychain.put(key: 'key$i', value: 'val$i');
      }
      for (var i = 0; i < 5; i++) {
        await FlutterKeychain.remove(key: 'key$i');
      }
      for (var i = 0; i < 5; i++) {
        expect(await FlutterKeychain.get(key: 'key$i'), isNull);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // clear
  // ---------------------------------------------------------------------------
  group('FlutterKeychain.clear', () {
    test('removes all stored entries', () async {
      await FlutterKeychain.put(key: 'a', value: '1');
      await FlutterKeychain.put(key: 'b', value: '2');
      await FlutterKeychain.put(key: 'c', value: '3');
      await FlutterKeychain.clear();
      expect(store.isEmpty, isTrue);
    });

    test('get returns null for every key after clear', () async {
      await FlutterKeychain.put(key: 'a', value: '1');
      await FlutterKeychain.put(key: 'b', value: '2');
      await FlutterKeychain.clear();
      expect(await FlutterKeychain.get(key: 'a'), isNull);
      expect(await FlutterKeychain.get(key: 'b'), isNull);
    });

    test('clear on an empty store completes without throwing', () async {
      await expectLater(FlutterKeychain.clear(), completes);
    });

    test('can store and retrieve values after clear', () async {
      await FlutterKeychain.put(key: 'k', value: 'before');
      await FlutterKeychain.clear();
      await FlutterKeychain.put(key: 'k', value: 'after');
      expect(await FlutterKeychain.get(key: 'k'), 'after');
    });

    test('double clear is idempotent', () async {
      await FlutterKeychain.put(key: 'k', value: 'v');
      await FlutterKeychain.clear();
      await expectLater(FlutterKeychain.clear(), completes);
      expect(store.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // configure
  // ---------------------------------------------------------------------------
  group('FlutterKeychain.configure', () {
    test('sends correct method name with accessGroup and label', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      await FlutterKeychain.configure(
          accessGroup: 'group.com.example', label: 'My App');
      expect(captured?.method, 'configure');
      expect(captured?.arguments['accessGroup'], 'group.com.example');
      expect(captured?.arguments['label'], 'My App');
    });

    test('sends null values when called without arguments', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      await FlutterKeychain.configure();
      expect(captured?.method, 'configure');
      expect(captured?.arguments['accessGroup'], isNull);
      expect(captured?.arguments['label'], isNull);
    });

    test('completes without throwing', () async {
      await expectLater(FlutterKeychain.configure(), completes);
    });

    test('configure with only accessGroup sets label to null', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      await FlutterKeychain.configure(accessGroup: 'group.com.example');
      expect(captured?.arguments['accessGroup'], 'group.com.example');
      expect(captured?.arguments['label'], isNull);
    });

    test('configure with only label sets accessGroup to null', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      await FlutterKeychain.configure(label: 'My Credentials');
      expect(captured?.arguments['accessGroup'], isNull);
      expect(captured?.arguments['label'], 'My Credentials');
    });
  });

  // ---------------------------------------------------------------------------
  // method channel contract
  // ---------------------------------------------------------------------------
  group('Method channel contract', () {
    test('put sends correct method name and arguments', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      await FlutterKeychain.put(key: 'myKey', value: 'myValue');
      expect(captured?.method, 'put');
      expect(captured?.arguments['key'], 'myKey');
      expect(captured?.arguments['value'], 'myValue');
    });

    test('get sends correct method name and key argument', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      await FlutterKeychain.get(key: 'myKey');
      expect(captured?.method, 'get');
      expect(captured?.arguments['key'], 'myKey');
    });

    test('remove sends correct method name and key argument', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      await FlutterKeychain.remove(key: 'myKey');
      expect(captured?.method, 'remove');
      expect(captured?.arguments['key'], 'myKey');
    });

    test('clear sends correct method name with no key argument', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      await FlutterKeychain.clear();
      expect(captured?.method, 'clear');
    });

    test('PlatformException from native side propagates to caller', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'NATIVE_ERROR', message: 'keychain locked');
      });

      expect(
        () async => await FlutterKeychain.get(key: 'k'),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
