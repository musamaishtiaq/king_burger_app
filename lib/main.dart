import 'package:flutter/material.dart';

import 'helper/strings.dart' as string;
import 'screens/mainScreen.dart';
import 'services/catalog_seed_service.dart';
import 'utils/app_theme.dart';
import 'utils/app_theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CatalogSeedService.instance.seedIfNeeded();
  await AppThemeController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    AppThemeController.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final themeController = AppThemeController.instance;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: string.AppStrings.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeController.themeMode,
      home: MainScreen(),
    );
  }
}
