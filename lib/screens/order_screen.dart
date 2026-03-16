import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/colors.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            const SizedBox(height: 16),

            // 商品スライドショー
            const ProductGallery(
              photos: kAllProductPhotos,
              height: 180,
            ),
            const SizedBox(height: 24),

            // --- PVCカード ---
            _ProductCard(
              title: 'PVCカード',
              subtitle: '本格的なクレジットカードサイズ',
              price: '¥1,980',
              icon: Icons.credit_card,
              iconColor: AppColors.secondary,
              features: const [
                'PVC製の高品質カード',
                'クレジットカードサイズ',
                'NFC + QRコード付き',
              ],
              onTap: () => context.push('/order/card'),
            ),
            const SizedBox(height: 16),

            // --- レジンタグ ---
            _ProductCard(
              title: 'レジンタグ',
              subtitle: '首輪に付ける丸型タグ',
              price: '¥1,980',
              icon: Icons.pets,
              iconColor: AppColors.primary,
              features: const [
                'レジン製ハンドメイドタグ',
                '直径25mm・首輪取り付け可能',
                'NFC機能付き（迷子対策）',
              ],
              onTap: () => context.push('/order/tag'),
            ),
            const SizedBox(height: 16),

            // --- セット ---
            _ProductCard(
              title: 'カード＋タグ セット',
              subtitle: 'お得なセット価格！',
              price: '¥2,980',
              icon: Icons.card_giftcard,
              iconColor: AppColors.accent,
              badge: '¥980お得！',
              features: const [
                'PVCカード + レジンタグ',
                '単品合計¥3,960 → ¥2,980',
                '同じ写真でまとめて注文',
              ],
              onTap: () => context.push('/order/set'),
            ),
            const SizedBox(height: 24),

            // 注意事項
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 8),
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
            const SizedBox(height: 32),
          ],
        ),
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
          borderRadius: BorderRadius.circular(16),
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMedium,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
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
                ),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 特徴リスト
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 15, color: iconColor.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
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
                    borderRadius: BorderRadius.circular(24),
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
