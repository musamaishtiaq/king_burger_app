import 'package:flutter/foundation.dart';

/// Drives tab screens to reload prefs when the user switches tabs in [MainScreen]:
/// Orders (0), Products (1), Profile (2).
final ValueNotifier<int> mainTabIndex = ValueNotifier<int>(0);
