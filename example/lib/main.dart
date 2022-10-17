import 'package:crypt_local_data/crypt_local_data.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async{
  await _init();
  runApp(const MyApp());
}

///First, we initialize our package for the flutter_dotenv package.
Future<void> _init() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CryptLocalData().initialize();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {


    return MaterialApp(
      title: 'Crypted Local Data',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  ///There is no function in the package content that we receive encrypted data.
  ///For this, we write a function that we take manually.
  void getItEncrypted() async{
    SharedPreferences _prefs = await SharedPreferences.getInstance();

    encryptedData = _prefs.getString("newData") ?? "";

    setState(() {
    });
  }

  //We define variables that we will encrypt, encrypt, and hold data that has been decrypted.

  String? dataToBeEncrypted = "";
  String? encryptedData = "";
  String? decodedData = "";

  TextEditingController textController = TextEditingController();


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body:  SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              //We place a textfield on the screen. We save the text entered in this textfield to the locale.
              SizedBox(
                width: 300,
                child: TextField(
                  controller: textController,
                ),
              ),

              const SizedBox(height: 70,),
              //Where we show unencrypted data
              const Text(
                "Data to be encrypted:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              Text(
                dataToBeEncrypted ?? "",
              ),
              const SizedBox(height: 20,),
              //Where we show the encrypted version of the data
              const Text(
                "Encrypted data:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                encryptedData ?? "",
              ),
              const SizedBox(height: 20,),
              //Where we show the decrypted version of the encrypted data.
              const Text(
                "Decoded data:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                decodedData ?? "",
              ),

              const SizedBox(height: 75,),
              //When we press the button, we encrypt the data entered in the textfield and save it to the locale.
              CupertinoButton(child: const SizedBox(width: 300, height: 20,child: Text("Save With Encryption", textAlign: TextAlign.center, ),), color: Colors.black12, padding: EdgeInsets.zero, onPressed: ()async{
                setState(() {
                  dataToBeEncrypted = textController.text;
                });
                await CryptLocalData().write(key: "newData", value: dataToBeEncrypted ?? "");
              },),
              const SizedBox(height: 10,),
              //By pressing the button, we bring the encrypted data from the local without decrypting it (in encrypted form).
              CupertinoButton(child: const SizedBox(width: 300,child: Text("Get It Encrypted", textAlign: TextAlign.center,),), padding: EdgeInsets.zero, color: Colors.black12, onPressed: ()async{


                getItEncrypted();
              }),
              const SizedBox(height: 10,),
              //When we press the button, we bring the data that we keep encrypted locally by decoding it.
              CupertinoButton(child: const SizedBox(width: 300, height: 20,child: Text("Save With Encryption", textAlign: TextAlign.center, ),), color: Colors.black12, padding: EdgeInsets.zero, onPressed: ()async{
                decodedData = await CryptLocalData().read(key: "newData");
                setState(()  {
                });
              }),
            ],
          ),
        ),
      ),
    );
  }
}
