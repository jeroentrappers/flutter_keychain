library crypt_local_data;

import 'dart:convert';
import 'dart:io';
import 'package:crypt_local_data/flutter_keychain.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';


abstract class ICryptedLocalData{
  Future<void> initialize ();
  Future<String> getEncryptedString ({required String dataKey});
  Future<void> setCryptedString ({required String dataKey, required String dataValue});
  Future<void> deleteData ({required String dataKey});
  Future<void> deleteAllData ();
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
/// The "initialize" method where we initialize the package. In this method, we ensure that the .env file that we keep the passwords for is loaded with the dotenv package.
///
/// The "getEncryptedString" method, where we retrieve and parse the data we saved as encrypted. With this function, we first get the encrypted data. Then we decrypt it again with the key that we encrypted. We retrieve the final version (analyzed version) of the data
///
/// The "setCryptedString" method, where we take the unencrypted data and encrypt it. With this function we get the data from the user. Then we encrypt it with the key we specified. Finally, we save the encrypted data to the local storage together with the dataKey we received from the user.
///
/// The "deleteData" function where we delete the value associated with the local storage keyValue we received from the user.
///
/// The "deleteAllData" method where we delete all the data we keep in local
///
/// -
///
/// SharedPreferences, Encrypt and Flutter Keychain packages were used in the package.
///
/// It was created by forking from the Flutter Keychain package.
///
/// On the iOS side, the Flutter Keychain package is used entirely.

class CryptLocalData extends ICryptedLocalData{


  /// In this method, we ensure that the .env file that we keep the passwords for is loaded with the dotenv package.
  @override
  Future<void> initialize () async{
    await dotenv.load(fileName: '.env');
  }


  ///With this function, we first get the encrypted data.
  ///Then we decrypt it again with the key that we encrypted.
  ///We retrieve the final version (analyzed version) of the data
  @override
  Future<String> getEncryptedString ({required String dataKey}) async{
    if(Platform.isIOS){
      String localData = await FlutterKeychain.get(key: dataKey) ?? "";

      return localData;
    } else {

      SharedPreferences _prefs = await SharedPreferences.getInstance();

      String localValue = _prefs.getString(dataKey) ?? "";

      Encrypted encryptedValue = Encrypted.from64(localValue);

      final encrypter = Encrypter(AES(Key.fromUtf8(dotenv.env["privateKey"] ?? "")));
      final String decrypted = encrypter.decrypt(encryptedValue, iv: IV.fromUtf8(utf8.decode((dotenv.env["privateINV"] ?? '').codeUnits)));

      return decrypted;
    }
  }


  /// With this function we get the data from the user.
  /// Then we encrypt it with the key we specified.
  /// Finally, we save the encrypted data to the local storage together with the dataKey we received from the user.
  @override
  Future<void> setCryptedString ({required String dataKey, required String dataValue}) async{
    if(Platform.isIOS){
     await FlutterKeychain.put(key: dataKey, value: dataValue);
    }else{
      final encrypter = Encrypter(AES(Key.fromUtf8(dotenv.env["privateKey"] ?? "")));

      final encryptedValue = encrypter.encrypt(dataValue, iv: IV.fromUtf8(utf8.decode((dotenv.env["privateINV"] ?? '').codeUnits)));

      SharedPreferences _prefs = await SharedPreferences.getInstance();
      await _prefs.setString(dataKey, encryptedValue.base64);
    }
  }


  /// The "deleteData" function where we delete the value associated with the local storage keyValue we received from the user.
  @override
  Future<void> deleteData ({required String dataKey}) async{
    if(Platform.isIOS){
     await FlutterKeychain.remove(key: dataKey);
    }else {
      SharedPreferences _prefs = await SharedPreferences.getInstance();
      await _prefs.remove(dataKey);
    }
  }


  /// The "deleteAllData" method where we delete all the data we keep in local
  @override
  Future<void> deleteAllData () async{
    if(Platform.isIOS){
      await FlutterKeychain.clear();
    } else {
      SharedPreferences _prefs = await SharedPreferences.getInstance();
      await _prefs.clear();
    }
  }
}
