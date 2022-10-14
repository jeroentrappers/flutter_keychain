<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages). 
-->

## crypt_local_data

Package that allows us to save data in local storage in an encrypted way.

We use AES methodology for encryption. For this, we get help from the Encrypt package. For AES methodology, two passwords with 32 characters for Key and 16 characters for IV are required. 
I use the commands "openssl rand -base64 12" and "openssl rand -base64 24" to set these passwords.
We create an .env file with the passwords we have determined; We place it inside by using the "privateKey" key for the 32-character password, and using the "privateINV" key for the 16-character one.
Using the Flutter dotenv package, we can access the passwords in our .env file.
With the Shared preferences package, we can save the data we encrypted to local storage.

SharedPreferences, Encrypt and Flutter Keychain packages were used in the package. It was created by forking from the Flutter Keychain package. On the iOS side, the Flutter Keychain package is used entirely.

## Getting started

To use the package, we need to add an .env file to the project directory. For AES methodology, two passwords with 32 characters for Key and 16 characters for IV are required.

![pic](https://i.imgur.com/2gfibnq.png)

For the 32 character Key password, paste the code below into the terminal and run it.

```terminal
openssl rand -base64 24
```

For the 16 character Key password, paste the code below into the terminal and run it.

```terminal
openssl rand -base64 12
```

We place it inside by using the "privateKey" key for the 32-character password, and using the "privateINV" key for the 16-character one as seen in the picture.
Don't forget to add your .env file under flutter>assets in your pubspec.yaml file

## Usage


```dart

import 'package:crypt_local_data/crypt_local_data.dart';
...

// initialize package
await CryptLocalData().initialize();

// Get value
String value = await CryptLocalData().getEncryptedString(dataKey: "newData");

// Set value
await CryptLocalData().setCryptedString(dataKey: "newData", dataValue: value);

// Delete data
await CryptLocalData().deleteData(dataKey: "newData");

// Delete all data
await CryptLocalData().deleteAllData();
```
