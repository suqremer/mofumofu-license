import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/product_gallery.dart';

/// 注文トップ画面: カード / タグ / セット の3つから選択
class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('実物グッズ注文'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー説明
            const Text(
              '作った免許証を実物グッズにしよう！',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 商品スライドショー
            const ProductGallery(
              photos: kAllProductPhotos,
              height: 180,
            ),
            const SizedBox(height: AppSpacing.lg),

            // --- うちの子免許証 ---
            _ProductCard(
              title: 'うちの子免許証',
              subtitle: '本格的なクレジットカードサイズ',
              price: '¥2,280',
              icon: Icons.credit_card,
              iconColor: AppColors.secondary,
              features: const [
                'PVC製の高品質カード',
                'クレジットカードサイズ',
                'NFC付き',
              ],
              onTap: () => context.push('/order/card'),
            ),
            const SizedBox(height: AppSpacing.md),

            // --- うちの子タグ ---
            _ProductCard(
              title: 'うちの子タグ',
              subtitle: '首輪に付ける丸型タグ',
              price: '¥2,480',
              icon: Icons.pets,
              iconColor: AppColors.primary,
              features: const [
                'レジン製ハンドメイドタグ',
                '直径25mm・首輪取り付け可能',
                'NFC機能付き（迷子対策）',
              ],
              onTap: () => context.push('/order/tag'),
            ),
            const SizedBox(height: AppSpacing.md),

            // --- セット ---
            _ProductCard(
              title: 'カード＋タグ セット',
              subtitle: 'お得なセット価格！',
              price: '¥3,980',
              icon: Icons.card_giftcard,
              iconColor: AppColors.accent,
              badge: '¥780お得！',
              features: const [
                'カード＋タグセット',
                '単品合計¥4,760 → ¥3,980',
                '同じ写真でまとめて注文',
              ],
              onTap: () => context.push('/order/set'),
            ),
            const SizedBox(height: AppSpacing.md),

            // NFC書き込みガイド
            _NfcGuideSection(),
            const SizedBox(height: AppSpacing.lg),

            // 注意事項
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      const Text(
                        'ご注文について',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    '• 決済は外部サイト（Stripe）で安全に処理されます\n'
                    '• 決済完了後、専用フォームから写真を送っていただきます\n'
                    '• 写真確認後、2〜3営業日で発送します',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// NFC書き込みガイド（アコーディオン展開式）
class _NfcGuideSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.nfc, color: AppColors.primary, size: 22),
          title: const Text(
            'NFC書き込みについて',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          children: [
            // 自分で書き込む方法
            _buildSubHeader('自分で書き込む方法'),
            const SizedBox(height: 6),
            const Text(
              'このアプリのNFC機能を使って、ご自身で'
              'カード/タグにペット情報を書き込めます。',
              style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
            ),
            const SizedBox(height: 8),
            _buildStep('1', 'コレクション画面で書き込みたいカードをタップ'),
            _buildStep('2', '「NFC」ボタン →「書き込み」を選択'),
            _buildStep('3', 'NTAG215タグをスマートフォンの上部にかざす'),
            _buildStep('4', '完了メッセージが出たら書き込み成功'),
            const SizedBox(height: 16),

            // 書き込み内容を確認する方法
            _buildSubHeader('書き込み内容を確認する方法'),
            const SizedBox(height: 6),
            _buildStep('1', 'コレクション画面で「NFC」ボタン →「読み取り」を選択'),
            _buildStep('2', '書き込み済みのタグをスマートフォンの上部にかざす'),
            _buildStep('3', 'ペット名や飼い主情報が正しく表示されればOK'),
            const SizedBox(height: 16),

            // 代行オプション
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build_circle_outlined,
                          size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                      const Text(
                        'NFC書き込み代行オプション',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '+¥500',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'NFCの書き込みが難しい方や、NFC非対応のスマホをお使いの方は、'
                    'こちらで書き込んだ状態で発送いたします。\n'
                    '注文フォームで「NFC書き込み代行」を選択してください。\n'
                    '※ 書き込み代行をご希望の場合、別途¥500をメールにて請求させていただきます。',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubHeader(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 商品カードウィジェット
class _ProductCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final IconData icon;
  final Color iconColor;
  final String? badge;
  final List<String> features;
  final VoidCallback onTap;

  const _ProductCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.icon,
    required this.iconColor,
    this.badge,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: badge != null
                ? AppColors.accent.withValues(alpha: 0.5)
                : Colors.grey.shade200,
            width: badge != null ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー行: アイコン + タイトル + 価格
            Row(
              children: [
                Container(
                  width: AppSpacing.xxl,
                  height: AppSpacing.xxl,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 特徴リスト
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 15, color: iconColor.withValues(alpha: 0.7)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 注文ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '注文する',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
