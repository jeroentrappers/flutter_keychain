import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_keychain/flutter_keychain.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _firstStart = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      var firstStart = await FlutterKeychain.get(key: "firstStart");

      if (null == firstStart) {
        await FlutterKeychain.put(
            key: "firstStart", value: DateTime.now().toIso8601String());
      }

      // If the widget was removed from the tree while the asynchronous platform
      // message was in flight, we want to discard the reply rather than calling
      // setState to update our non-existent appearance.
      if (!mounted) return;

      setState(() {
        if (null == firstStart) {
          _firstStart = "Was never started before. Restart and see .";
        } else {
          _firstStart = firstStart;
        }
      });
    } on Exception catch (ae) {
      print("Exception: " + ae.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: const Text('Plugin example app'),
        ),
        body: new Center(
          child: new Text('First Start: $_firstStart\n'),
        ),
      ),
    );
  }
}
