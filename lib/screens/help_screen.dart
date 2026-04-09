import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/help_contents.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// ヘルプ・よくある質問の一覧画面
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('ヘルプ・よくある質問')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          for (final category in kHelpCategories) ...[
            _sectionHeader(category),
            _sectionCard(
              children: _buildItemsForCategory(context, category),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  /// 指定カテゴリのヘルプ項目をListTileリストとして構築
  List<Widget> _buildItemsForCategory(
      BuildContext context, String category) {
    final items =
        kHelpItems.where((item) => item.category == category).toList();
    final widgets = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      if (i > 0) widgets.add(_thinDivider());
      final item = items[i];
      widgets.add(
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(item.title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/help/detail', extra: item),
        ),
      );
    }
    return widgets;
  }

  /// セクション見出し
  static Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.lg, 4, AppSpacing.sm),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textMedium,
        ),
      ),
    );
  }

  /// セクションをCardで囲むウィジェット
  static Widget _sectionCard({required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  /// Card内の項目間の薄い区切り線
  static Widget _thinDivider() {
    return const Divider(
      height: 0,
      thickness: 0.5,
      indent: 56,
      color: AppColors.surfaceVariant,
    );
  }
}
