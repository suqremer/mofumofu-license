import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/license_card.dart';
import '../providers/database_provider.dart';
import '../services/app_preferences.dart';
import '../theme/colors.dart';
import '../widgets/product_gallery.dart';

/// カード注文画面: 免許証を選んで Stripe Payment Link へ遷移
class OrderCardScreen extends ConsumerStatefulWidget {
  /// セット注文の場合 true（タグも同時注文）
  final bool isSet;

  const OrderCardScreen({super.key, this.isSet = false});

  @override
  ConsumerState<OrderCardScreen> createState() => _OrderCardScreenState();
}

class _OrderCardScreenState extends ConsumerState<OrderCardScreen> {
  LicenseCard? _selectedCard;

  // TODO: しゅーとが Stripe Payment Links 作成後に差し替え
  String get _paymentUrl => widget.isSet
      ? 'https://buy.stripe.com/SET_PLACEHOLDER'
      : 'https://buy.stripe.com/CARD_PLACEHOLDER';

  String get _title => widget.isSet ? 'セット注文' : 'PVCカード注文';
  String get _price => widget.isSet ? '¥2,980' : '¥1,980';
  String get _description => widget.isSet
      ? 'PVCカード + レジンタグのセット'
      : 'PVC製クレジットカードサイズの免許証';

  @override
  Widget build(BuildContext context) {
    final licensesAsync = ref.watch(licensesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: licensesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (licenses) {
          if (licenses.isEmpty) return _buildNoLicenses();
          return _buildBody(licenses);
        },
      ),
    );
  }

  Widget _buildNoLicenses() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 64, color: AppColors.textLight),
            SizedBox(height: 16),
            Text(
              '免許証がまだありません',
              style: TextStyle(fontSize: 16, color: AppColors.textMedium),
            ),
            SizedBox(height: 8),
            Text(
              '先に免許証を作成してください',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<LicenseCard> licenses) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 商品スライドショー
                ProductGallery(
                  photos: widget.isSet
                      ? kAllProductPhotos
                      : kCardPhotos,
                  height: 160,
                  compact: true,
                ),
                const SizedBox(height: 16),

                // 商品情報
                Row(
                  children: [
                    Icon(
                      widget.isSet ? Icons.card_giftcard : Icons.credit_card,
                      color: widget.isSet ? AppColors.accent : AppColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMedium,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _price,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.isSet ? AppColors.accent : AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Step 1: 免許証を選択
                _buildStepHeader(1, '印刷する免許証を選んでください'),
                const SizedBox(height: 12),
                _buildLicenseGrid(licenses),
                const SizedBox(height: 24),

                // Step 2: 注文フロー説明
                _buildStepHeader(2, '決済ページで支払い'),
                const SizedBox(height: 8),
                const Text(
                  '「注文する」を押すと外部の決済ページ（Stripe）が開きます。\n'
                  '配送先はStripeの画面で入力してください。',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
                ),
                const SizedBox(height: 20),

                // Step 3: 写真送付
                _buildStepHeader(3, '専用フォームから写真を送付'),
                const SizedBox(height: 8),
                const Text(
                  '決済完了後、Googleフォームで免許証の画像を送っていただきます。\n'
                  '注文番号とお名前を入力し、完成画像をアップロードしてください。',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
                ),

                if (widget.isSet) ...[
                  const SizedBox(height: 20),
                  _buildStepHeader(4, 'タグ用写真も送付'),
                  const SizedBox(height: 8),
                  const Text(
                    'セット注文の場合、カード用とタグ用の2つの画像が必要です。\n'
                    'タグ用は丸形にトリミングした写真をフォームで送ってください。',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textMedium, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 注文ボタン（固定フッター）
        _buildOrderButton(),
      ],
    );
  }

  Widget _buildStepHeader(int step, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: const TextStyle(
                  fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseGrid(List<LicenseCard> licenses) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: licenses.length,
      itemBuilder: (context, index) {
        final card = licenses[index];
        final isSelected = _selectedCard?.id == card.id;
        final imagePath = card.savedImagePath ?? card.photoPath;

        return GestureDetector(
          onTap: () => setState(() => _selectedCard = card),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 免許証画像
                File(imagePath).existsSync()
                    ? Image.file(File(imagePath), fit: BoxFit.cover)
                    : Container(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        child: Icon(Icons.pets,
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                // 選択チェック
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                  ),
                // ペット名
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    child: Text(
                      card.petName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderButton() {
    final isEnabled = _selectedCard != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: isEnabled ? _launchPayment : null,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(
            '注文する（$_price）',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: isEnabled ? 2 : 0,
          ),
        ),
      ),
    );
  }

  Future<void> _launchPayment() async {
    await AppPreferences.setHasOrdered();
    final uri = Uri.parse(_paymentUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        // 決済ページを開いた後、フォーム案内ダイアログを表示
        _showPostPaymentDialog();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('決済ページを開けませんでした')),
        );
      }
    }
  }

  void _showPostPaymentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 24),
            SizedBox(width: 8),
            Text('決済は完了しましたか？', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: const Text(
          '決済が完了したら、専用フォームから写真を送ってください。\n'
          '注文番号はStripeからのメールに記載されています。',
          style: TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('あとで送る'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchPhotoForm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('写真を送る'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPhotoForm() async {
    // TODO: しゅーとが Google フォーム作成後に差し替え
    const formUrl = 'https://forms.gle/PLACEHOLDER';
    final uri = Uri.parse(formUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
