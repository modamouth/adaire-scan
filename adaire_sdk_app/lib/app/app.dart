import 'package:flutter/material.dart';

import '../features/sdk_showcase/sdk_showcase_page.dart';

class AdaireSdkApp extends StatelessWidget {
  const AdaireSdkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaire Scan: SDK Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SdkShowcasePage(),
    );
  }
}
