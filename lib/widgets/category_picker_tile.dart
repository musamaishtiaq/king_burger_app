import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../utils/layout_breakpoints.dart';
import '../utils/local_image.dart';

/// Horizontal category strip: image on the left, name on the right.
class CategoryPickerTile extends StatelessWidget {
  final String label;
  final String? imagePath;
  final bool selected;
  final VoidCallback onTap;
  final bool useListIcon;

  const CategoryPickerTile({
    super.key,
    required this.label,
    required this.imagePath,
    required this.selected,
    required this.onTap,
    this.useListIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: categoryPickerTileHeight,
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: categoryPickerImageSize,
                    height: categoryPickerImageSize,
                    child: useListIcon
                        ? ColoredBox(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            child: Icon(
                              Icons.grid_view_rounded,
                              size: categoryPickerImageSize * 0.48,
                              color: AppColors.primary,
                            ),
                          )
                        : LocalOrAssetImage(
                            path: imagePath,
                            entity: LocalImageEntity.category,
                            fit: BoxFit.cover,
                            width: categoryPickerImageSize,
                            height: categoryPickerImageSize,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
