import 'package:flutter/material.dart';
import 'package:serialize/views/device_list.dart';

void main() {
  runApp(const SerializeApp());
}

class SerializeApp extends StatelessWidget {
  const SerializeApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serialize',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DeviceList(),
    );
  }
}
