import 'package:flutter/material.dart';
import 'package:flutter_keychain/flutter_keychain.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TextEditingController controller = TextEditingController();

  final String preferencesKey = 'flutter_keychain_example';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter keychain example'),
        ),
        body: Center(
          child: Column(
            children: [
              TextFormField(
                controller: controller,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }

                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Enter a value',
                  labelText: 'Keychain input example',
                  suffix: ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      if (value.text.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () async {
                          await FlutterKeychain.put(key: preferencesKey, value: value.text);
                        },
                      );
                    },
                  ),
                ),
              ),
              ElevatedButton(
                child: const Text('Get value'),
                onPressed: () async {
                  final String? value = await FlutterKeychain.get(key: preferencesKey);

                  if (!mounted || value == null || value.isEmpty) {
                    return;
                  }

                  controller.text = value;
                },
              ),
              ElevatedButton(
                child: const Text('Remove value'),
                onPressed: () async {
                  await FlutterKeychain.remove(key: preferencesKey);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
