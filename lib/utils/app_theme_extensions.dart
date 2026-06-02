import 'package:flutter/material.dart';

/// Extra semantic colors for surfaces that are not covered by [ColorScheme].
@immutable
class AppExtras extends ThemeExtension<AppExtras> {
  final Color mutedFill;
  final Color chipFill;
  final Color panelFill;
  final Color progressTrack;
  final Color success;
  final Color shadow;

  const AppExtras({
    required this.mutedFill,
    required this.chipFill,
    required this.panelFill,
    required this.progressTrack,
    required this.success,
    required this.shadow,
  });

  static const light = AppExtras(
    mutedFill: Color(0xFFEFEFEF),
    chipFill: Color(0xFFF0F0F0),
    panelFill: Color(0xFFF7F7F7),
    progressTrack: Color(0xFFEAEAEA),
    success: Color(0xFF1B5E20),
    shadow: Color(0x14000000),
  );

  static const dark = AppExtras(
    mutedFill: Color(0xFF2A2A2A),
    chipFill: Color(0xFF2C2C2C),
    panelFill: Color(0xFF252525),
    progressTrack: Color(0xFF383838),
    success: Color(0xFF81C784),
    shadow: Color(0x40000000),
  );

  @override
  AppExtras copyWith({
    Color? mutedFill,
    Color? chipFill,
    Color? panelFill,
    Color? progressTrack,
    Color? success,
    Color? shadow,
  }) {
    return AppExtras(
      mutedFill: mutedFill ?? this.mutedFill,
      chipFill: chipFill ?? this.chipFill,
      panelFill: panelFill ?? this.panelFill,
      progressTrack: progressTrack ?? this.progressTrack,
      success: success ?? this.success,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppExtras lerp(ThemeExtension<AppExtras>? other, double t) {
    if (other is! AppExtras) return this;
    return AppExtras(
      mutedFill: Color.lerp(mutedFill, other.mutedFill, t)!,
      chipFill: Color.lerp(chipFill, other.chipFill, t)!,
      panelFill: Color.lerp(panelFill, other.panelFill, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
      success: Color.lerp(success, other.success, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  AppExtras get extras => Theme.of(this).extension<AppExtras>() ?? AppExtras.light;
}
