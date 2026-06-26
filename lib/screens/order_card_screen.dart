import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/license_card.dart';
import '../models/order_record.dart';
import '../providers/database_provider.dart';
import '../services/database_service.dart';
import '../services/order_upload_service.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/photo_crop_preview.dart';
import '../widgets/product_gallery.dart';

/// カード注文画面: 免許証を選んで注文内容を組み立て、Stripe Payment Link へ遷移。
///
/// 刷新フロー（v1.1.2・アプリ内完結方式）:
///  ① ここで注文内容（免許証選択／セットは丸形画像作成／NFC代行／備考）を組み立てる
///  ②「お支払いに進む」で受付番号を発番しローカル保存（pending）→ Stripe決済へ
///  ③ 決済後にアプリへ戻り `/order/upload` で写真を Firebase へ送る
class OrderCardScreen extends ConsumerStatefulWidget {
  /// セット注文の場合 true（タグも同時注文）
  final bool isSet;

  const OrderCardScreen({super.key, this.isSet = false});

  @override
  ConsumerState<OrderCardScreen> createState() => _OrderCardScreenState();
}

class _OrderCardScreenState extends ConsumerState<OrderCardScreen> {
  final List<LicenseCard> _selectedCards = [];

  /// セット注文時: カードID → タグ用丸形画像のアプリ内保存パス
  final Map<int, String> _tagImagePaths = {};

  /// NFC書き込み代行の希望
  bool _nfcProxy = false;

  /// 「お支払いに進む」を押して決済ページを開いた後 true。
  /// 決済から戻ってきた人向けに「写真を送る」導線を表示する。
  bool _orderPlaced = false;

  /// 発番してローカル保存した注文（写真送付画面へ渡す）
  OrderRecord? _pendingOrder;

  /// 「お支払いに進む」処理中フラグ（二度押しで受付番号が二重発番されるのを防ぐ）
  bool _launching = false;

  String get _paymentUrl => widget.isSet
      ? 'https://buy.stripe.com/7sY6oGcwCdmKgV007T5os02'
      : 'https://buy.stripe.com/dRm3cu9kq96u8ou7Al5os01';

  String get _title => widget.isSet ? 'セット注文' : 'カード注文';
  int get _unitPrice => widget.isSet ? 3980 : 2280;
  String get _productType => widget.isSet ? 'set' : 'card';
  String get _description => widget.isSet
      ? 'カード＋タグのセット'
      : 'クレジットカードサイズの本格カード';

  Color get _accentColor =>
      widget.isSet ? AppColors.accent : AppColors.secondary;

  String _formatPrice(int yen) => '¥${yen.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  bool _isSelected(LicenseCard card) =>
      _selectedCards.any((c) => c.id == card.id);

  /// 全選択カードのカード画像（完成画像）が揃っているか
  bool get _allCardImagesReady =>
      _selectedCards.isNotEmpty &&
      _selectedCards.every((c) => c.resolvedSavedImagePath != null);

  /// セット注文時: 全カードのタグ用丸形画像が作成済みか
  bool get _allTagImagesReady =>
      !widget.isSet ||
      (_selectedCards.isNotEmpty &&
          _selectedCards.every((c) => _tagImagePaths[c.id] != null));

  bool get _canOrder =>
      _selectedCards.isNotEmpty && _allCardImagesReady && _allTagImagesReady;

  void _toggleSelection(LicenseCard card) {
    setState(() {
      if (_isSelected(card)) {
        _selectedCards.removeWhere((c) => c.id == card.id);
        _tagImagePaths.remove(card.id);
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
                  photos: widget.isSet ? kAllProductPhotos : kCardPhotos,
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

                // 選択済み免許証の確認プレビュー
                if (_selectedCards.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildSelectedPreview(),
                ],
                const SizedBox(height: AppSpacing.lg),

                // Step 2（セットのみ）: タグ用丸形画像作成
                if (widget.isSet) ...[
                  _buildStepHeader(stepNum++, 'タグ用の丸形画像を作成'),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'セットにはタグ用の丸形画像も必要です。\n'
                    '免許証ごとに、写真の位置・サイズを丸形に合わせて作成してください。',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textMedium, height: 1.5),
                  ),
                  if (_selectedCards.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._selectedCards.map(_buildTagDesignButton),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Step: NFC書き込み代行
                _buildStepHeader(stepNum++, 'NFC書き込み代行（任意）'),
                const SizedBox(height: AppSpacing.sm),
                _buildNfcProxyTile(),
                const SizedBox(height: AppSpacing.lg),

                // Step: 決済
                _buildStepHeader(stepNum, 'お支払いに進む'),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '「お支払いに進む」を押すと外部の決済ページ（Stripe）が開きます。\n'
                  'お届け先・メールアドレスは決済ページで入力してください。',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
                ),
                if (_selectedCards.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoNote(
                    'お支払いが完了したら、この画面に戻ってお写真を送信してください。'
                    'お写真の送付がないと制作を開始できません。',
                  ),
                ],

                // 決済後: 写真送付への導線
                if (_orderPlaced && _pendingOrder != null) ...[
                  const SizedBox(height: 20),
                  _buildUploadPrompt(),
                ],
              ],
            ),
          ),
        ),

        // フッター（お支払いに進むボタン）
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

  Widget _buildTagDesignButton(LicenseCard card) {
    final done = _tagImagePaths[card.id] != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _openTagDesign(card),
          icon: done
              ? const Icon(Icons.check_circle, size: 18, color: AppColors.success)
              : const Icon(Icons.crop, size: 18),
          label: Text(
            done
                ? '${card.petName}の丸形画像を作成済み（変更する）'
                : '${card.petName}の丸形画像を作成',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: done ? AppColors.success : AppColors.primary,
            side: BorderSide(
              color: done ? AppColors.success : AppColors.primary,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNfcProxyTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SwitchListTile(
        value: _nfcProxy,
        onChanged: (v) => setState(() => _nfcProxy = v),
        activeThumbColor: AppColors.primary,
        title: const Text(
          'NFC書き込みをお願いする',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'ご希望の場合、書き込み内容を後ほどメールで確認します。別途¥500（税込）をメールにてご請求します。',
          style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.4),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildInfoNote(String text) {
    return Container(
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
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMedium,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 決済後に表示する「写真を送る」プロンプト
  Widget _buildUploadPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, size: 20, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'お支払いありがとうございます',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '受付番号: ${_pendingOrder!.orderNumber}\n'
            'お支払いはブラウザで完了しています（お写真の送信は無料です）。'
            '下のボタンからお写真を送ってください。',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textMedium, height: 1.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _goToUpload,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('お写真を送る'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
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

  /// 選択済み免許証の確認プレビュー（送信前サムネ確認）
  Widget _buildSelectedPreview() {
    final count = _selectedCards.length;
    final total = _unitPrice * count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'この写真で作ります（$count枚）',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const Spacer(),
            Text(
              count > 1
                  ? '${_formatPrice(_unitPrice)} x $count = ${_formatPrice(total)}'
                  : _formatPrice(total),
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
    } else if (!_allTagImagesReady) {
      buttonLabel = '丸形画像を作成してください';
    } else if (!_allCardImagesReady) {
      buttonLabel = 'カード画像を準備できません';
    } else {
      buttonLabel = 'お支払いに進む（${_formatPrice(total)}・$count枚）';
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
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: (_canOrder && !_launching) ? _launchPayment : null,
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
            elevation: _canOrder ? 2 : 0,
          ),
        ),
      ),
    );
  }

  Future<void> _openTagDesign(LicenseCard card) async {
    final result = await context.push<String>('/order/tag-design', extra: card);
    if (result != null && mounted) {
      setState(() => _tagImagePaths[card.id!] = result);
    }
  }

  /// アップロード対象の画像パスを集める。
  ///  - カード: 各カードの完成画像
  ///  - セット: 各カードの完成画像＋丸形画像（カードごとにペアで並べる）
  List<String> _collectImagePaths() {
    final paths = <String>[];
    for (final card in _selectedCards) {
      final cardPath = card.resolvedSavedImagePath;
      if (cardPath != null) paths.add(cardPath);
      if (widget.isSet) {
        final tagPath = _tagImagePaths[card.id];
        if (tagPath != null) paths.add(tagPath);
      }
    }
    return paths;
  }

  Future<void> _launchPayment() async {
    if (_launching) return; // 二度押しガード
    setState(() => _launching = true);
    try {
      final count = _selectedCards.length;
      final orderNumber = OrderRecord.generateOrderNumber();
      final order = OrderRecord(
        orderNumber: orderNumber,
        productType: _productType,
        petNames: _selectedCards.map((c) => c.petName).toList(),
        quantity: count,
        nfcProxy: _nfcProxy,
        note: null,
        imagePaths: _collectImagePaths(),
        amount: _unitPrice * count,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
      );

      // 決済往復後のアップロードに備え匿名認証を「温める」だけ（待たない＝決済ページ起動を遅らせない）。
      // 失敗してもアップロード時に再試行するので無視。
      unawaited(
        OrderUploadService.instance.ensureSignedIn().catchError((_) => ''),
      );

      // 受付番号を client_reference_id として Stripe に渡し、Webhook と突合できるようにする
      final uri = Uri.parse('$_paymentUrl?client_reference_id=$orderNumber');
      if (!await canLaunchUrl(uri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('決済ページを開けませんでした')),
          );
        }
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      // 決済ページを開けた後にだけ pending を保存する。
      // （開けなかった場合に幽霊pendingを残さない。setHasOrdered は写真送付完了時に行う）
      await DatabaseService().upsertOrder(order);
      // ホームの未送信バナーを即時更新（どの画面から注文しても反映される）
      ref.invalidate(pendingOrdersProvider);

      if (mounted) {
        setState(() {
          _orderPlaced = true;
          _pendingOrder = order;
        });
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  void _goToUpload() {
    if (_pendingOrder == null) return;
    context.push('/order/upload', extra: _pendingOrder);
  }
}
