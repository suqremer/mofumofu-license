import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/purchase_manager.dart';
import '../theme/colors.dart';

class PaywallBottomSheet extends StatefulWidget {
  const PaywallBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PaywallBottomSheet(),
    );
  }

  @override
  State<PaywallBottomSheet> createState() => _PaywallBottomSheetState();
}

class _PaywallBottomSheetState extends State<PaywallBottomSheet> {
  @override
  void initState() {
    super.initState();
    PurchaseManager.instance.premiumActive.addListener(_onPurchaseChanged);
  }

  @override
  void dispose() {
    PurchaseManager.instance.premiumActive.removeListener(_onPurchaseChanged);
    super.dispose();
  }

  void _onPurchaseChanged() {
    if (PurchaseManager.instance.isPremium && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('プレミアムにアップグレードしました!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _purchase(Package package) async {
    final success = await PurchaseManager.instance.purchasePackage(package);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('購入できませんでした。もう一度試してね'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _restore() async {
    final success = await PurchaseManager.instance.restorePurchases();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '購入を復元しました!' : '復元できる購入が見つかりませんでした',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pm = PurchaseManager.instance;
    final offering = pm.currentOffering;
    final package = offering?.availablePackages.isNotEmpty == true
        ? offering!.availablePackages.first
        : null;
    final price = package?.storeProduct.priceString ?? '¥300';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ドラッグハンドル
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'もっと楽しもう!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'プレミアムでもふもふを解放',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // プレミアムカード
          if (package == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '商品情報を読み込めませんでした',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            )
          else
            ValueListenableBuilder<bool>(
              valueListenable: pm.isPurchasing,
              builder: (context, purchasing, _) {
                return GestureDetector(
                  onTap: purchasing ? null : () => _purchase(package),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'プレミアム',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              price,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '買い切り',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _featureRow(Icons.all_inclusive, '作成枚数の制限なし'),
                        const SizedBox(height: 8),
                        _featureRow(Icons.block, '広告の非表示'),
                        const SizedBox(height: 8),
                        _featureRow(Icons.checkroom, '全コスチューム解放'),
                        const SizedBox(height: 8),
                        _featureRow(Icons.palette, '全フレームカラー解放'),
                        if (purchasing)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          // 購入を復元
          TextButton(
            onPressed: () => _restore(),
            child: Text(
              '購入を復元',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          const SizedBox(height: 4),
          // 逃げ道ボタン
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '無料で続ける',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
