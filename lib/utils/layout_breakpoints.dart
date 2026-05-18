import 'package:flutter/material.dart';

/// Width buckets aligned with common phone / tablet / large tablet breakpoints.
enum AppLayoutWidthClass {
  /// Phone portrait & small phones (< 600dp).
  compact,

  /// Large phones, small tablets (600–839dp).
  medium,

  /// Tablets (840–1199dp).
  expanded,

  /// Large tablets, unfolded fold, desktop (≥ 1200dp).
  extraLarge,
}

AppLayoutWidthClass layoutWidthClassOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1200) return AppLayoutWidthClass.extraLarge;
  if (w >= 840) return AppLayoutWidthClass.expanded;
  if (w >= 600) return AppLayoutWidthClass.medium;
  return AppLayoutWidthClass.compact;
}

/// Max width for centered content; parent width applies when smaller than this cap.
double contentMaxWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  switch (layoutWidthClassOf(context)) {
    case AppLayoutWidthClass.extraLarge:
      return 1280;
    case AppLayoutWidthClass.expanded:
      return 1120;
    case AppLayoutWidthClass.medium:
      return 900;
    case AppLayoutWidthClass.compact:
      return w;
  }
}

bool isTabletOrWider(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600;

/// Side navigation instead of bottom bar (typical from 600dp up).
bool useNavigationRailLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600;

double horizontalScreenPadding(BuildContext context) {
  switch (layoutWidthClassOf(context)) {
    case AppLayoutWidthClass.compact:
      return 12;
    case AppLayoutWidthClass.medium:
      return 16;
    case AppLayoutWidthClass.expanded:
      return 20;
    case AppLayoutWidthClass.extraLarge:
      return 24;
  }
}

/// Bottom padding for tab-root scrollables: FAB + optional bottom nav + safe area.
double rootTabBodyBottomScrollPadding(BuildContext context) {
  final safe = MediaQuery.paddingOf(context).bottom;
  if (useNavigationRailLayout(context)) {
    return 88 + safe;
  }
  return 96 + safe;
}

/// Product / order-item picker grids: more columns on wider screens.
int catalogGridCrossAxisCount(BuildContext context) {
  switch (layoutWidthClassOf(context)) {
    case AppLayoutWidthClass.compact:
      return 2;
    case AppLayoutWidthClass.medium:
      return 3;
    case AppLayoutWidthClass.expanded:
      return 4;
    case AppLayoutWidthClass.extraLarge:
      return 5;
  }
}

/// [GridView] childAspectRatio (width / height) for product catalog cards.
double catalogGridChildAspectRatio(BuildContext context) {
  switch (layoutWidthClassOf(context)) {
    case AppLayoutWidthClass.compact:
      return 0.62;
    case AppLayoutWidthClass.medium:
      return 0.64;
    case AppLayoutWidthClass.expanded:
      return 0.68;
    case AppLayoutWidthClass.extraLarge:
      return 0.72;
  }
}

/// Grids with extra controls (e.g. qty steppers) need a taller cell.
double orderItemsGridChildAspectRatio(BuildContext context) {
  switch (layoutWidthClassOf(context)) {
    case AppLayoutWidthClass.compact:
      return 0.66;
    case AppLayoutWidthClass.medium:
      return 0.68;
    case AppLayoutWidthClass.expanded:
      return 0.72;
    case AppLayoutWidthClass.extraLarge:
      return 0.76;
  }
}

/// Legacy name: single-column product strip on very narrow layouts is unused;
/// catalog grids use [catalogGridCrossAxisCount] instead.
int productCrossAxisCount(BuildContext context) =>
    catalogGridCrossAxisCount(context);

/// Category picker tile: left image, right label.
const double categoryPickerImageSize = 56;

const double categoryPickerTileHeight = 72;

/// Outer height of the horizontal category [ListView] strip.
const double categoryPickerListHeight = 88;
