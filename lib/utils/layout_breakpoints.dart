import 'package:flutter/material.dart';

double contentMaxWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 900) return 1100;
  if (w >= 600) return 840;
  return w;
}

bool isTabletOrWider(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600;

/// Product area: more columns on wide layouts; single column falls back to horizontal list elsewhere.
int productCrossAxisCount(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1100) return 4;
  if (w >= 850) return 3;
  if (w >= 600) return 2;
  return 1;
}
