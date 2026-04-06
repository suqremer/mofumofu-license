import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/license_card.dart';
import '../providers/database_provider.dart';
import '../services/app_preferences.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
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

  /// カードID → 丸形画像保存済みかどうか
  final Map<int, bool> _savedStatus = {};

  static const _paymentUrl = 'https://buy.stripe.com/7sY7sK8gm3MaeMS7Al5os00';
  static const _formUrl = 'https://docs.google.com/forms/d/e/1FAIpQLSfSkYTQgcdnhExlgoIGxQLj_dvnTSgTbDGlpIK3Xarx6QHk-g/viewform';
  static const _unitPrice = 2480;

  String _formatPrice(int yen) => '¥${yen.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  bool _isSelected(LicenseCard card) =>
      _selectedCards.any((c) => c.id == card.id);

  bool get _allImagesSaved =>
      _selectedCards.isNotEmpty &&
      _selectedCards.every((c) => _savedStatus[c.id] == true);

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
        title: const Text('うちの子タグ注文'),
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
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 64, color: AppColors.textLight),
            SizedBox(height: AppSpacing.md),
            Text(
              '免許証がまだありません',
              style: TextStyle(fontSize: 16, color: AppColors.textMedium),
            ),
            SizedBox(height: AppSpacing.sm),
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
                const SizedBox(height: AppSpacing.md),

                // 商品情報
                Row(
                  children: [
                    const Icon(Icons.pets, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text(
                        'ハンドメイドうちの子タグ（Φ25mm）',
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
                const SizedBox(height: AppSpacing.lg),

                // Step 2: 丸形画像の作成
                _buildStepHeader(2, 'タグ用の丸形画像を作成'),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'タグに使う写真は丸形にトリミングする必要があります。\n'
                  '作成した画像はカメラロールに保存されます。',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMedium, height: 1.5),
                ),
                if (_selectedCards.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._selectedCards.map((card) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openTagDesign(card),
                        icon: _savedStatus[card.id] == true
                            ? const Icon(Icons.check_circle, size: 18, color: AppColors.success)
                            : const Icon(Icons.crop, size: 18),
                        label: Text(
                          _savedStatus[card.id] == true
                              ? '${card.petName}の画像を保存済み'
                              : '${card.petName}の丸形画像を作成',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _savedStatus[card.id] == true
                              ? AppColors.success
                              : AppColors.primary,
                          side: BorderSide(
                            color: _savedStatus[card.id] == true
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                          ),
                        ),
                      ),
                    ),
                  )),
                ],
                const SizedBox(height: AppSpacing.lg),

                // Step 3: 決済
                _buildStepHeader(3, '決済ページで支払い'),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '「注文する」を押すと外部の決済ページ（Stripe）が開きます。\n'
                  '配送先はStripeの画面で入力してください。',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMedium, height: 1.5),
                ),
                // 注意書き
                if (_selectedCards.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: AppColors.accent),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '決済完了後、Step 4のフォームからカメラロールに保存した'
                            '画像を送ってください。画像の送付がないと制作を開始できません。',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMedium,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Step 4: 写真送付（常時表示）
                _buildStepHeader(4, '専用フォームから写真を送付'),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Googleフォームでタグ用の丸形画像を送ってください。\n'
                  'カメラロールに保存した画像をアップロードしてね！',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMedium, height: 1.5),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _launchPhotoForm,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('写真送付フォームを開く'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMedium,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      ),
                    ),
                  ),
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
          width: AppSpacing.lg,
          height: AppSpacing.lg,
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
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: PhotoCropPreview(
                        key: ValueKey(card.id),
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
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
                    key: ValueKey(card.id),
                    card: card,
                    size: constraints.maxWidth,
                  ),
                  if (isSelected)
                    Positioned(
                      top: AppSpacing.xs,
                      right: AppSpacing.xs,
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
                          const EdgeInsets.symmetric(horizontal: 6, vertical: AppSpacing.xs),
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
    final count = _selectedCards.length;
    final total = _unitPrice * count;

    // 画像未保存のカードがあれば決済ボタン無効
    final isEnabled = _allImagesSaved;
    String buttonLabel;
    if (count == 0) {
      buttonLabel = '免許証を選択してください';
    } else if (!_allImagesSaved) {
      buttonLabel = 'Step 2で丸形画像を保存してください';
    } else {
      buttonLabel = '注文する（${_formatPrice(total)}・$count個）';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, AppSpacing.xl),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0 && !isEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '全画像を保存してから注文に進めます',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isEnabled ? _launchPayment : null,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
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
        ],
      ),
    );
  }

  Future<void> _openTagDesign(LicenseCard card) async {
    final result = await context.push<bool>('/order/tag-design', extra: card);
    if (result == true && mounted) {
      setState(() => _savedStatus[card.id!] = true);
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 24),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('写真の送付はお済みですか？', style: TextStyle(fontSize: 17))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '専用フォームからタグ用の丸形画像を送ってください。\n\n'
              'カメラロールに保存した画像をアップロードしてね！',
              style: TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('あとで送る'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('送付済み'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _launchPhotoForm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('フォームを開く'),
              ),
            ),
          ],
        ),
        actions: const [],
      ),
    );
  }

  Future<void> _launchPhotoForm() async {
    final uri = Uri.parse(_formUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
