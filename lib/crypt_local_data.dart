library crypt_local_data;

import 'dart:convert';
import 'dart:io';
import 'package:crypt_local_data/flutter_keychain.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ICryptedLocalData {
  Future<void> initialize();
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}

/// Package that allows us to save data in local storage in an encrypted way.
///
/// -
///
/// We use AES methodology for encryption. For this, we get help from the Encrypt package.
///
/// For AES methodology, two passwords with 32 characters for Key and 16 characters for IV are required.
///
/// I use the commands "openssl rand -base64 12" and "openssl rand -base64 24" to set these passwords.
///
/// We create an .env file with the passwords we have determined; We place it inside by using the "privateKey" key for the 32-character password, and using the "privateINV" key for the 16-character one.
///
/// Using the Flutter dotenv package, we can access the passwords in our .env file.
///
/// With the Shared preferences package, we can save the data we encrypted to local storage.
///
/// -
///
/// We have a total of five methods.
///
/// The [initialize] method where we initialize the package. In this method, we ensure that the .env file that we keep the passwords for is loaded with the dotenv package.
///
/// The [read] method, where we retrieve and parse the data we saved as encrypted. With this function, we first get the encrypted data. Then we decrypt it again with the key that we encrypted. We retrieve the final version (analyzed version) of the data
///
/// The [write] method, where we take the unencrypted data and encrypt it. With this function we get the data from the user. Then we encrypt it with the key we specified. Finally, we save the encrypted data to the local storage together with the key we received from the user.
///
/// The [delete] function where we delete the value associated with the local storage keyValue we received from the user.
///
/// The [deleteAll] method where we delete all the data we keep in local
///
/// -
///
/// SharedPreferences, Encrypt and Flutter Keychain packages were used in the package.
///
/// It was created by forking from the Flutter Keychain package.
///
/// On the iOS side, the Flutter Keychain package is used entirely.

class CryptLocalData extends ICryptedLocalData {
  /// In this method, we ensure that the .env file that we keep the passwords for is loaded with the dotenv package.
  @override
  Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
  }

  ///With this function, we first get the encrypted data.
  ///Then we decrypt it again with the key that we encrypted.
  ///We retrieve the final version (analyzed version) of the data
  @override
  Future<String?> read({required String key}) async {
    if (Platform.isIOS) {
      String localData = await FlutterKeychain.get(key: key) ?? "";

      return localData;
    } else {
      SharedPreferences _prefs = await SharedPreferences.getInstance();

      String? localValue = _prefs.getString(key);

      if (localValue != null) {
        Encrypted encryptedValue = Encrypted.from64(localValue);

        final encrypter = Encrypter(AES(Key.fromUtf8(dotenv.env["privateKey"] ?? "")));
        final String decrypted = encrypter.decrypt(encryptedValue, iv: IV.fromUtf8(utf8.decode((dotenv.env["privateINV"] ?? '').codeUnits)));

        return decrypted;
      } else {
        return null;
      }
    }
  }

  /// With this function we get the data from the user.
  /// Then we encrypt it with the key we specified.
  /// Finally, we save the encrypted data to the local storage together with the key we received from the user.
  @override
  Future<void> write({required String key, required String value}) async {
    if (Platform.isIOS) {
      await FlutterKeychain.put(key: key, value: value);
    } else {
      final encrypter = Encrypter(AES(Key.fromUtf8(dotenv.env["privateKey"] ?? "")));

      final encryptedValue = encrypter.encrypt(value, iv: IV.fromUtf8(utf8.decode((dotenv.env["privateINV"] ?? '').codeUnits)));

      SharedPreferences _prefs = await SharedPreferences.getInstance();
      await _prefs.setString(key, encryptedValue.base64);
    }
  }

  /// The [delete] function where we delete the value associated with the local storage keyValue we received from the user.
  @override
  Future<void> delete({required String key}) async {
    if (Platform.isIOS) {
      await FlutterKeychain.remove(key: key);
    } else {
      SharedPreferences _prefs = await SharedPreferences.getInstance();
      await _prefs.remove(key);
    }
  }

  /// The [deleteAll] method where we delete all the data we keep in local
  @override
  Future<void> deleteAll() async {
    if (Platform.isIOS) {
      await FlutterKeychain.clear();
    } else {
      SharedPreferences _prefs = await SharedPreferences.getInstance();
      await _prefs.clear();
    }
  }
}
