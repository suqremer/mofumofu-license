import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/license_card.dart';
import '../providers/database_provider.dart';
import '../services/app_preferences.dart';
import '../theme/colors.dart';
import '../widgets/photo_crop_preview.dart';
import '../widgets/product_gallery.dart';

/// タグ注文画面: 免許証を選んで丸形プレビュー → Stripe Payment Link → フォーム案内
class OrderTagScreen extends ConsumerStatefulWidget {
  const OrderTagScreen({super.key});

  @override
  ConsumerState<OrderTagScreen> createState() => _OrderTagScreenState();
}

class _OrderTagScreenState extends ConsumerState<OrderTagScreen> {
  final List<LicenseCard> _selectedCards = [];

  // TODO: しゅーとが Stripe Payment Links 作成後に差し替え
  // TODO: 複数枚注文時の数量パラメータ対応（#46.5）
  static const _paymentUrl = 'https://buy.stripe.com/TAG_PLACEHOLDER';
  static const _unitPrice = 1980;

  String _formatPrice(int yen) => '¥${yen.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  bool _isSelected(LicenseCard card) =>
      _selectedCards.any((c) => c.id == card.id);

  void _toggleSelection(LicenseCard card) {
    setState(() {
      if (_isSelected(card)) {
        _selectedCards.removeWhere((c) => c.id == card.id);
      } else {
        _selectedCards.add(card);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final licensesAsync = ref.watch(licensesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('レジンタグ注文'),
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
                const ProductGallery(
                  photos: kTagPhotos,
                  height: 160,
                  compact: true,
                ),
                const SizedBox(height: 16),

                // 商品情報
                Row(
                  children: [
                    const Icon(Icons.pets, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ハンドメイドレジンタグ（Φ25mm）',
                        style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                      ),
                    ),
                    Text(
                      '${_formatPrice(_unitPrice)} / 個',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Step 1: 免許証を選択（複数可）
                _buildStepHeader(1, '写真に使う免許証を選んでください（複数可）'),
                const SizedBox(height: 12),
                _buildLicenseGrid(licenses),

                // 丸形プレビュー（選択済みの場合）
                if (_selectedCards.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildCircularPreview(),
                ],
                const SizedBox(height: 24),

                // Step 2: 丸形画像の作成
                _buildStepHeader(2, 'タグ用の丸形画像を作成'),
                const SizedBox(height: 8),
                const Text(
                  'タグに使う写真は丸形にトリミングする必要があります。\n'
                  '選択した免許証の写真から丸形画像を作成できます。',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMedium, height: 1.5),
                ),
                if (_selectedCards.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._selectedCards.map((card) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/order/tag-design', extra: card),
                        icon: const Icon(Icons.crop, size: 18),
                        label: Text('${card.petName}の丸形画像を作成'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  )),
                ],
                const SizedBox(height: 24),

                // Step 3: 決済
                _buildStepHeader(3, '決済ページで支払い'),
                const SizedBox(height: 8),
                const Text(
                  '「注文する」を押すと外部の決済ページ（Stripe）が開きます。\n'
                  '配送先はStripeの画面で入力してください。',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMedium, height: 1.5),
                ),
                const SizedBox(height: 20),

                // Step 4: 写真送付
                _buildStepHeader(4, '専用フォームから写真を送付'),
                const SizedBox(height: 8),
                const Text(
                  '決済完了後、Googleフォームでタグ用の丸形画像を送っていただきます。\n'
                  'Step 2で作成した画像をアップロードしてください。',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMedium, height: 1.5),
                ),
              ],
            ),
          ),
        ),
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

  /// 選択した免許証の証明写真を丸形でプレビュー（横スクロール）
  Widget _buildCircularPreview() {
    final count = _selectedCards.length;
    final total = _unitPrice * count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'タグ完成イメージ（$count個）',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textMedium,
              ),
            ),
            const Spacer(),
            if (count > 1)
              Text(
                '${_formatPrice(_unitPrice)} x $count = ${_formatPrice(total)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              )
            else
              Text(
                _formatPrice(total),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedCards.length,
            itemBuilder: (context, index) {
              final card = _selectedCards[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: PhotoCropPreview(
                        card: card,
                        circular: true,
                        size: 100,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      card.petName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Text(
                      'Φ25mm',
                      style: TextStyle(fontSize: 11, color: AppColors.textLight),
                    ),
                  ],
                ),
              );
            },
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
        final isSelected = _isSelected(card);

        return GestureDetector(
          onTap: () => _toggleSelection(card),
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
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
                  PhotoCropPreview(
                    card: card,
                    size: constraints.maxWidth,
                  ),
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
                        child:
                            const Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                    ),
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
          ),
        );
      },
    );
  }

  Widget _buildOrderButton() {
    final isEnabled = _selectedCards.isNotEmpty;
    final count = _selectedCards.length;
    final total = _unitPrice * count;
    final buttonLabel = count > 0
        ? '注文する（${_formatPrice(total)}・$count個）'
        : '免許証を選択してください';
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
            buttonLabel,
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
      if (mounted) _showPostPaymentDialog();
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
          '決済が完了したら、専用フォームからタグ用の写真を送ってください。\n\n'
          '丸形にトリミングした画像をアップロードしてね！\n'
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
