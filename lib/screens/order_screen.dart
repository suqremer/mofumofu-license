import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// 画面: 実物カード注文（Coming Soon ティーザー）
/// v1.0では未実装。発売予告と事前登録UIのみ表示する。
class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('実物カード注文'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // --- アイコンエリア: グラデーション円にカード＋配送アイコン ---
              _buildIconArea(),
              const SizedBox(height: 28),
              // --- タイトル ---
              const Text(
                '実物カード、近日登場！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              // --- 説明文 ---
              const Text(
                '作った免許証を本物のカードにして届けるで！',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'PVC製の高品質カード、サイズはクレジットカードと同じです',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // --- 機能リスト ---
              _buildFeatureCard(),
              const SizedBox(height: 32),
              // --- 通知登録ボタン ---
              _buildNotifyButton(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// グラデーション円の中にカード＋配送アイコンを配置
  Widget _buildIconArea() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.3),
            AppColors.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          // メインのカードアイコン
          Positioned(
            top: 28,
            child: Icon(Icons.credit_card, size: 52, color: Colors.white),
          ),
          // 配送アイコン（右下に小さく）
          Positioned(
            bottom: 22,
            right: 18,
            child: Icon(Icons.local_shipping, size: 30, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// 予告機能リスト（角丸カード内）
  Widget _buildFeatureCard() {
    const features = [
      'PVC製の本格カード',
      'クレジットカードサイズ',
      '2〜3営業日でお届け',
      '1枚 ¥990（税込）',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: features
            .map(
              (text) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  /// 通知登録ボタン（タップでSnackBar表示）
  Widget _buildNotifyButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登録しました！発売したらお知らせします'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 2,
        ),
        child: const Text(
          '届いたら教えて！',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
