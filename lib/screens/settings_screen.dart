import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/dev_config.dart';
import '../providers/database_provider.dart';
import '../services/app_preferences.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';

/// 画面9: 設定
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _supportEmail = 'uchino.ko.license@gmail.com';
  static const _privacyPolicyUrl =
      'https://suqremer.github.io/mofumofu-license/privacy-policy';
  static const _termsUrl =
      'https://suqremer.github.io/mofumofu-license/terms';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = AppPreferences.remainingCreations;
    final totalCount = AppPreferences.totalCreationCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // ── アプリ情報ヘッダー ──
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.pets,
                      size: 48, color: AppColors.secondary),
                  const SizedBox(width: 16),
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
                          'v1.0.0',
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
                              borderRadius: BorderRadius.circular(4),
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
          ListTile(
            leading: const Icon(Icons.confirmation_number_outlined),
            title: const Text('作成数'),
            trailing: Text(
              kDevMode
                  ? '$totalCount枚（無制限）'
                  : '$totalCount / ${AppPreferences.freeCreationLimit}枚',
              style: const TextStyle(color: AppColors.textMedium),
            ),
          ),
          if (!kDevMode && remaining == 0) ...[
            const Divider(height: 1),
            ListTile(
              leading:
                  Icon(Icons.lock_outline, color: Colors.red.shade400),
              title: Text(
                '今月の無料枠を使い切りました',
                style: TextStyle(color: Colors.red.shade400),
              ),
              subtitle: const Text('プレミアムで無制限に作れます'),
            ),
          ],

          // ── アカウント・プラン ──
          _sectionHeader('アカウント・プラン'),
          ListTile(
            leading: const Icon(Icons.card_membership),
            title: const Text('現在のプラン'),
            trailing: Text(
              kDevMode ? '開発モード' : '無料',
              style: const TextStyle(color: AppColors.textMedium),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.workspace_premium,
                color: Colors.amber),
            title: const Text('プレミアムにアップグレード'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSnack(context, '準備中です'),
          ),

          // ── サポート ──
          _sectionHeader('サポート'),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('お問い合わせ'),
            subtitle: Text(_supportEmail,
                style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _launchEmail(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('レビューを書く'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _showSnack(context, 'ストア公開後にリンクします'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('不具合を報告'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _launchBugReport(context),
          ),

          // ── 法的情報 ──
          _sectionHeader('法的情報'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _launchUrl(context, _privacyPolicyUrl),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('利用規約'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _launchUrl(context, _termsUrl),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.source_outlined),
            title: const Text('オープンソースライセンス'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'うちの子免許証',
              applicationVersion: '1.0.0',
            ),
          ),

          // ── その他 ──
          _sectionHeader('その他'),
          if (kDevMode) ...[
            ListTile(
              leading: Icon(Icons.restore,
                  color: Colors.orange.shade400),
              title: Text(
                'FTUEをリセット（開発用）',
                style:
                    TextStyle(color: Colors.orange.shade400),
              ),
              onTap: () async {
                await AppPreferences.setFtueCompleted();
                // SharedPreferences を直接操作してリセット
                // （AppPreferences には reset メソッドがないので snack で案内）
                _showSnack(context,
                    'SharedPreferencesを手動クリアしてアプリを再起動してください');
              },
            ),
            const Divider(height: 1),
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

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── ヘルパー ──

  static Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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
