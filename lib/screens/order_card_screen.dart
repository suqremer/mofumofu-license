import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/license_card.dart';
import '../providers/database_provider.dart';
import '../services/app_preferences.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/photo_crop_preview.dart';
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
  final List<LicenseCard> _selectedCards = [];

  /// カードID → カード画像カメラロール保存済みか
  final Map<int, bool> _cardSavedStatus = {};

  /// セット注文時: カードID → タグ用丸形画像保存済みか
  final Map<int, bool> _tagSavedStatus = {};

  String get _paymentUrl => widget.isSet
      ? 'https://buy.stripe.com/7sY6oGcwCdmKgV007T5os02'
      : 'https://buy.stripe.com/dRm3cu9kq96u8ou7Al5os01';

  static const _formUrl = 'https://docs.google.com/forms/d/e/1FAIpQLSfSkYTQgcdnhExlgoIGxQLj_dvnTSgTbDGlpIK3Xarx6QHk-g/viewform';

  String get _title => widget.isSet ? 'セット注文' : 'カード注文';
  int get _unitPrice => widget.isSet ? 3980 : 2280;
  String get _description => widget.isSet
      ? 'カード＋タグのセット'
      : 'クレジットカードサイズの本格カード';

  Color get _accentColor =>
      widget.isSet ? AppColors.accent : AppColors.secondary;

  String _formatPrice(int yen) => '¥${yen.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  bool _isSelected(LicenseCard card) =>
      _selectedCards.any((c) => c.id == card.id);

  /// 全カードの画像がカメラロールに保存済みか
  bool get _allCardImagesSaved =>
      _selectedCards.isNotEmpty &&
      _selectedCards.every((c) => _cardSavedStatus[c.id] == true);

  /// セット注文時: 全カードのタグ画像が保存済みか
  bool get _allTagImagesSaved =>
      !widget.isSet ||
      (_selectedCards.isNotEmpty &&
          _selectedCards.every((c) => _tagSavedStatus[c.id] == true));

  /// 全画像保存済みか（カード画像 + タグ画像）
  bool get _allImagesSaved => _allCardImagesSaved && _allTagImagesSaved;

  bool get _canOrder =>
      _selectedCards.isNotEmpty && _allImagesSaved;

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
    int stepNum = 1;
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
                const SizedBox(height: AppSpacing.md),

                // 商品情報
                Row(
                  children: [
                    Icon(
                      widget.isSet ? Icons.card_giftcard : Icons.credit_card,
                      color: _accentColor,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ),
                    Text(
                      '${_formatPrice(_unitPrice)} / 枚',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Step 1: 免許証を選択（複数選択可）
                _buildStepHeader(stepNum++, '印刷する免許証を選んでください（複数可）'),
                const SizedBox(height: 12),
                _buildLicenseGrid(licenses),

                // 選択済み免許証の横スクロールプレビュー
                if (_selectedCards.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildSelectedPreview(),
                ],
                const SizedBox(height: AppSpacing.lg),

                // Step 2: カード用画像をカメラロールに保存
                _buildStepHeader(stepNum++, 'カード画像をカメラロールに保存'),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'フォームで画像を送付するため、カメラロールに保存してください。',
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
                        onPressed: _cardSavedStatus[card.id] == true
                            ? null
                            : () => _saveCardToGallery(card),
                        icon: _cardSavedStatus[card.id] == true
                            ? const Icon(Icons.check_circle, size: 18, color: AppColors.success)
                            : const Icon(Icons.save_alt, size: 18),
                        label: Text(
                          _cardSavedStatus[card.id] == true
                              ? '${card.petName}のカード画像を保存済み'
                              : '${card.petName}のカード画像を保存',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _cardSavedStatus[card.id] == true
                              ? AppColors.success
                              : AppColors.primary,
                          side: BorderSide(
                            color: _cardSavedStatus[card.id] == true
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

                // セット注文時: タグ用丸形画像作成ステップ
                if (widget.isSet) ...[
                  _buildStepHeader(stepNum++, 'タグ用の丸形画像を作成'),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'セット注文にはタグ用の丸形画像も必要です。\n'
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
                          icon: _tagSavedStatus[card.id] == true
                              ? const Icon(Icons.check_circle, size: 18, color: AppColors.success)
                              : const Icon(Icons.crop, size: 18),
                          label: Text(
                            _tagSavedStatus[card.id] == true
                                ? '${card.petName}のタグ画像を保存済み'
                                : '${card.petName}の丸形画像を作成',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _tagSavedStatus[card.id] == true
                                ? AppColors.success
                                : AppColors.primary,
                            side: BorderSide(
                              color: _tagSavedStatus[card.id] == true
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
                ],

                // 決済ステップ
                _buildStepHeader(stepNum++, '決済ページで支払い'),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '「注文する」を押すと外部の決済ページ（Stripe）が開きます。\n'
                  '配送先はStripeの画面で入力してください。',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: AppColors.accent),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            widget.isSet
                                ? '決済完了後、次のステップのフォームから免許証画像と'
                                  'タグ用の丸形画像を送ってください。画像の送付がないと制作を開始できません。'
                                : '決済完了後、次のステップのフォームから免許証の画像を'
                                  '送ってください。画像の送付がないと制作を開始できません。',
                            style: const TextStyle(
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

                // 写真送付ステップ（常時表示）
                _buildStepHeader(stepNum, '専用フォームから写真を送付'),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.isSet
                      ? 'Googleフォームで免許証画像とタグ用画像を送ってください。\n'
                        'カメラロールに保存した画像をアップロードしてね！'
                      : 'Googleフォームで免許証の画像を送ってください。\n'
                        'カメラロールに保存した画像をアップロードしてね！',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
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

        // 注文ボタン（固定フッター）
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
                        child: const Icon(Icons.check, size: 14, color: Colors.white),
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

  /// 選択済み免許証の横スクロールプレビュー
  Widget _buildSelectedPreview() {
    final count = _selectedCards.length;
    final total = _unitPrice * count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '選択中: $count枚',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const Spacer(),
            if (count > 1)
              Text(
                '${_formatPrice(_unitPrice)} x $count = ${_formatPrice(total)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                ),
              )
            else
              Text(
                _formatPrice(total),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedCards.length,
            itemBuilder: (context, index) {
              final card = _selectedCards[index];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: PhotoCropPreview(
                        key: ValueKey(card.id),
                        card: card,
                        size: 70,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      width: 70,
                      child: Text(
                        card.petName,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMedium,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
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

  Widget _buildOrderButton() {
    final count = _selectedCards.length;
    final total = _unitPrice * count;

    String buttonLabel;
    if (count == 0) {
      buttonLabel = '免許証を選択してください';
    } else if (!_allImagesSaved) {
      buttonLabel = '画像を保存してください';
    } else {
      buttonLabel = '注文する（${_formatPrice(total)}・$count枚）';
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
          if (count > 0 && !_allImagesSaved)
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
              onPressed: _canOrder ? _launchPayment : null,
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
                elevation: _canOrder ? 2 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCardToGallery(LicenseCard card) async {
    final path = card.savedImagePath;
    if (path == null || !File(path).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像ファイルが見つかりません')),
        );
      }
      return;
    }

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
      await Gal.putImage(path, album: 'うちの子免許証');
      if (mounted) {
        setState(() => _cardSavedStatus[card.id!] = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${card.petName}のカード画像を保存しました'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openTagDesign(LicenseCard card) async {
    final result = await context.push<bool>('/order/tag-design', extra: card);
    if (result == true && mounted) {
      setState(() => _tagSavedStatus[card.id!] = true);
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
            Text(
              widget.isSet
                  ? '専用フォームから免許証画像とタグ用の丸形画像を送ってください。\n\n'
                    'カメラロールに保存した画像をアップロードしてね！'
                  : '専用フォームから免許証の画像を送ってください。\n\n'
                    'カメラロールに保存した画像をアップロードしてね！',
              style: const TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5),
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
