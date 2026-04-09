import 'package:flutter/material.dart';

import '../data/help_contents.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// ヘルプ詳細画面
class HelpDetailScreen extends StatelessWidget {
  final HelpItem item;

  const HelpDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(item.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectableText(
              item.content,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
