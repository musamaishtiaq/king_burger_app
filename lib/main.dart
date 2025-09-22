import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helper/strings.dart' as string;
import '../screens/mainScreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: string.AppStrings.appName,
      theme: ThemeData(
        primarySwatch: Colors.blue,        
      ),
      home: MainScreen(),
    );
  }
}