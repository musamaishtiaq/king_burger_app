import 'package:flutter/foundation.dart';

/// Drives list screens to reload prefs (e.g. delete permission) when the user
/// switches to Orders (0), Products (1), or Categories (2) in [MainScreen].
final ValueNotifier<int> mainTabIndex = ValueNotifier<int>(0);
