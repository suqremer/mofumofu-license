import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeMore;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeMore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.headingSmall),
          if (onSeeMore != null)
            TextButton(
              onPressed: onSeeMore,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('もっと見る', style: AppTypography.caption),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
