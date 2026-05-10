import 'dart:io';

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Whether to show [Icons.category_outlined] or [Icons.inventory_2_outlined] when there is no photo.
enum LocalImageEntity { category, product }

class LocalOrAssetImage extends StatelessWidget {
  final String? path;
  final LocalImageEntity entity;
  final BoxFit fit;
  final double? width;
  final double? height;

  const LocalOrAssetImage({
    super.key,
    required this.path,
    this.entity = LocalImageEntity.product,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  IconData get _fallbackIcon => entity == LocalImageEntity.category
      ? Icons.category_outlined
      : Icons.inventory_2_outlined;

  double _fallbackIconSize() {
    final w = width;
    final h = height;
    double s = 40;
    if (w != null && h != null) {
      s = (w < h ? w : h) * 0.38;
    } else if (w != null) {
      s = w * 0.38;
    } else if (h != null) {
      s = h * 0.38;
    }
    return s.clamp(20.0, 56.0);
  }

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p != null && p.isNotEmpty) {
      final file = File(p);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => _IconFallback(
            icon: _fallbackIcon,
            iconSize: _fallbackIconSize(),
            width: width,
            height: height,
          ),
        );
      }
    }
    return _IconFallback(
      icon: _fallbackIcon,
      iconSize: _fallbackIconSize(),
      width: width,
      height: height,
    );
  }
}

class _IconFallback extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final double? width;
  final double? height;

  const _IconFallback({
    required this.icon,
    required this.iconSize,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: iconSize,
        color: AppColors.primary,
      ),
    );
  }
}
