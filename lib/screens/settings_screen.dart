import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/dev_config.dart';
import '../providers/database_provider.dart';
import '../services/app_preferences.dart';
import '../services/database_service.dart';
import '../services/purchase_manager.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/paywall_bottom_sheet.dart';

/// 画面9: 設定
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _supportEmail = 'uchino.ko.license@gmail.com';
  static const _privacyPolicyUrl =
      'https://uchinoko-license.com/privacy-policy/';
  static const _termsUrl =
      'https://uchinoko-license.com/terms/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCount = AppPreferences.totalCreationCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('設定')),
      body: ValueListenableBuilder<bool>(
        valueListenable: PurchaseManager.instance.premiumActive,
        builder: (context, isPremium, _) {
          final effectivePremium = kDevMode || isPremium;
          final remaining = AppPreferences.remainingCreations;

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              // ── アプリ情報ヘッダー ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.pets,
                          size: 48, color: AppColors.secondary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'うちの子免許証',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'v1.0.9',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.textMedium),
                            ),
                            if (kDevMode) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius:
                                      BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: Text(
                                  '開発モード',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── 利用状況 ──
              _sectionHeader('利用状況'),
              _sectionCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.confirmation_number_outlined),
                    title: const Text('作成数'),
                    trailing: Text(
                      effectivePremium
                          ? '$totalCount枚（無制限）'
                          : '$totalCount / ${AppPreferences.freeCreationLimit}枚',
                      style: const TextStyle(color: AppColors.textMedium),
                    ),
                  ),
                  if (!effectivePremium && remaining == 0) ...[
                    _thinDivider(),
                    ListTile(
                      leading:
                          Icon(Icons.lock_outline, color: Colors.red.shade400),
                      title: Text(
                        '無料枠を使い切りました',
                        style: TextStyle(color: Colors.red.shade400),
                      ),
                      subtitle: const Text('プレミアムで無制限に作れます'),
                    ),
                  ],
                ],
              ),

              // ── アカウント・プラン ──
              _sectionHeader('アカウント・プラン'),
              _sectionCard(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.card_membership,
                      color: effectivePremium ? Colors.amber : null,
                    ),
                    title: const Text('現在のプラン'),
                    trailing: Text(
                      kDevMode
                          ? '開発モード'
                          : isPremium
                              ? 'プレミアム'
                              : '無料',
                      style: TextStyle(
                        color: isPremium
                            ? Colors.amber.shade700
                            : AppColors.textMedium,
                        fontWeight:
                            isPremium ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (!effectivePremium) ...[
                    _thinDivider(),
                    ListTile(
                      leading: const Icon(Icons.workspace_premium,
                          color: Colors.amber),
                      title: const Text('プレミアムにアップグレード'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => PaywallBottomSheet.show(context),
                    ),
                  ],
                ],
              ),

              // ── サポート ──
              _sectionHeader('サポート'),
              _sectionCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('ヘルプ・よくある質問'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/help'),
                  ),
                  _thinDivider(),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('サポートID'),
                    subtitle: FutureBuilder<String>(
                      future:
                          PurchaseManager.instance.getAppUserId(),
                      builder: (context, snapshot) {
                        final id = snapshot.data ?? '読み込み中...';
                        return Text(
                          id,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMedium),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () async {
                        final id = await PurchaseManager.instance
                            .getAppUserId();
                        await Clipboard.setData(ClipboardData(text: id));
                        if (context.mounted) {
                          _showSnack(context, 'サポートIDをコピーしました');
                        }
                      },
                    ),
                  ),
                  _thinDivider(),
                  ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('お問い合わせ'),
                    subtitle: Text(_supportEmail,
                        style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _launchEmail(context),
                  ),
                  _thinDivider(),
                  ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: const Text('レビューを書く'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final inAppReview = InAppReview.instance;
                      if (await inAppReview.isAvailable()) {
                        await inAppReview.requestReview();
                      } else {
                        await inAppReview.openStoreListing(
                          appStoreId: '6744202334',
                        );
                      }
                    },
                  ),
                  _thinDivider(),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('不具合を報告'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _launchBugReport(context),
                  ),
                ],
              ),

              // ── 法的情報 ──
              _sectionHeader('法的情報'),
              _sectionCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('プライバシーポリシー'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _launchUrl(context, _privacyPolicyUrl),
                  ),
                  _thinDivider(),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('利用規約'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _launchUrl(context, _termsUrl),
                  ),
                  _thinDivider(),
                  ListTile(
                    leading: const Icon(Icons.source_outlined),
                    title: const Text('オープンソースライセンス'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'うちの子免許証',
                      applicationVersion: '1.0.9',
                    ),
                  ),
                ],
              ),

              // ── その他 ──
              _sectionHeader('その他'),
              _sectionCard(
                children: [
                  if (kDevMode) ...[
                    ListTile(
                      leading: Icon(Icons.restore,
                          color: Colors.orange.shade400),
                      title: Text(
                        'FTUEをリセット（開発用）',
                        style: TextStyle(color: Colors.orange.shade400),
                      ),
                      onTap: () async {
                        await AppPreferences.setFtueCompleted();
                        _showSnack(context,
                            'SharedPreferencesを手動クリアしてアプリを再起動してください');
                      },
                    ),
                    _thinDivider(),
                  ],
                  ListTile(
                    leading:
                        Icon(Icons.delete_outline, color: Colors.red.shade400),
                    title: Text(
                      'データを全て削除',
                      style: TextStyle(color: Colors.red.shade400),
                    ),
                    onTap: () => _showDeleteDialog(context, ref),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }

  // ── ヘルパー ──

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

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'うちの子免許証 お問い合わせ',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        _showSnack(context, '$_supportEmail にメールしてください');
      }
    }
  }

  static Future<void> _launchBugReport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'うちの子免許証 不具合報告',
        'body': '【不具合の内容】\n\n【再現手順】\n\n【端末情報】\n',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        _showSnack(context, '$_supportEmail にメールしてください');
      }
    }
  }

  static Future<void> _launchUrl(
      BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        _showSnack(context, 'URLを開けませんでした');
      }
    }
  }

  static void _showDeleteDialog(
      BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('データを全て削除'),
        content: const Text(
            '本当に全てのデータを削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await DatabaseService().deleteAllData();
                ref.invalidate(licensesProvider);
                ref.invalidate(petsProvider);
                ref.invalidate(licenseCountProvider);
                if (!context.mounted) return;
                _showSnack(context, 'すべてのデータを削除しました');
              } catch (e) {
                if (!context.mounted) return;
                _showSnack(context, '削除に失敗しました: $e');
              }
            },
            child: Text(
              '削除する',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
