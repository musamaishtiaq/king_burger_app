import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'helper/strings.dart' as string;
import 'screens/mainScreen.dart';
import 'utils/app_theme.dart';

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
      theme: AppTheme.light(),
      home: MainScreen(),
    );
  }
}