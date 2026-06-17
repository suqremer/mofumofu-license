// ignore: unnecessary_import
import 'dart:io'; // File を明示的に使用（analyzer の services 経由提案を無視）

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_record.dart';
import '../services/app_preferences.dart';
import '../services/database_service.dart';
import '../services/order_upload_service.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// 写真アップロード画面（刷新フロー③〜④）
///
/// 決済から戻ってきたユーザーが、注文した写真を Firebase Storage へ送る画面。
/// - 送信前にサムネを確認（誤写真の送付防止）
/// - 全画像のアップロード成功後に Firestore へ1回書き込み（[OrderUploadService] が担保）
/// - 成功したらローカルの注文を [OrderStatus.uploaded] に更新し、完了画面を表示
class OrderUploadScreen extends StatefulWidget {
  final OrderRecord order;

  const OrderUploadScreen({super.key, required this.order});

  @override
  State<OrderUploadScreen> createState() => _OrderUploadScreenState();
}

enum _UploadPhase { confirm, uploading, done, error }

class _OrderUploadScreenState extends State<OrderUploadScreen> {
  _UploadPhase _phase = _UploadPhase.confirm;
  String? _errorMessage;

  /// 問い合わせ先（受付番号を件名に入れる）
  static const _supportEmail = 'uchino.ko.license@gmail.com';

  String get _productLabel {
    switch (widget.order.productType) {
      case 'card':
        return 'カード';
      case 'tag':
        return 'タグ';
      case 'set':
        return 'カード＋タグセット';
      default:
        return '商品';
    }
  }

  String _formatPrice(int yen) => '¥${yen.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_phase == _UploadPhase.done ? '送信完了' : 'お写真の送信'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        automaticallyImplyLeading: _phase != _UploadPhase.uploading,
      ),
      body: switch (_phase) {
        _UploadPhase.confirm => _buildConfirm(),
        _UploadPhase.uploading => _buildUploading(),
        _UploadPhase.done => _buildDone(),
        _UploadPhase.error => _buildError(),
      },
    );
  }

  // === 送信前確認 ===
  Widget _buildConfirm() {
    final paths = widget.order.resolvedImagePaths;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummaryCard(),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'このお写真で送信します',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '内容をご確認ください。送信後、制作を開始します。',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMedium, height: 1.5),
                ),
                const SizedBox(height: 12),
                _buildThumbnails(paths),
              ],
            ),
          ),
        ),
        Container(
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
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: paths.isEmpty ? null : _startUpload,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text(
                    'このお写真を送信する',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
              // 未決済の注文を削除する導線（決済せず離脱した注文の救済用）
              TextButton(
                onPressed: _confirmDelete,
                child: const Text(
                  'お支払いしていない／この注文を削除',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnails(List<String> paths) {
    if (paths.isEmpty) {
      return _buildInfoBox(
        '送信する画像が見つかりませんでした。お手数ですが注文画面からやり直してください。',
        AppColors.error,
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: paths.map((path) {
        final file = File(path);
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: file.existsSync()
              ? Image.file(file, fit: BoxFit.cover)
              : const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppColors.textLight),
                ),
        );
      }).toList(),
    );
  }

  Widget _buildOrderSummaryCard() {
    final order = widget.order;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('受付番号', order.orderNumber, bold: true),
          const Divider(height: 20),
          _summaryRow('商品', _productLabel),
          _summaryRow('数量', '${order.quantity}点'),
          _summaryRow('お名前（ペット）', order.petNames.join('・')),
          if (order.nfcProxy) _summaryRow('NFC書き込み代行', 'あり'),
          if (order.note != null && order.note!.isNotEmpty)
            _summaryRow('備考', order.note!),
          const Divider(height: 20),
          _summaryRow('お支払い金額', _formatPrice(order.amount), bold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === アップロード中 ===
  Widget _buildUploading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: AppSpacing.lg),
          Text(
            '写真を送信しています...',
            style: TextStyle(fontSize: 15, color: AppColors.textMedium),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '画面を閉じずにお待ちください',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  // === 完了 ===
  Widget _buildDone() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const Icon(Icons.check_circle, size: 72, color: AppColors.success),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'お写真の送信が完了しました',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'ご注文ありがとうございます！\n'
            '心を込めて制作し、発送いたします。',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: AppColors.textMedium, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildOrderSummaryCard(),
          const SizedBox(height: AppSpacing.md),
          _buildInfoBox(
            '発送の目安は約1〜2週間です。ご不明な点は受付番号を添えてお問い合わせください。',
            AppColors.accent,
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: _contactSupport,
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('お問い合わせ'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
            ),
            child: const Text('ホームに戻る',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // === 失敗 ===
  Widget _buildError() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Icon(Icons.error_outline, size: 72, color: Colors.orange.shade700),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '送信に失敗しました',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _errorMessage ?? '通信環境をご確認のうえ、もう一度お試しください。',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textMedium, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'お支払い済みの場合は、二重に支払う必要はありません。\n'
            'お写真は何度でも送り直せます。',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: AppColors.textLight, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: _startUpload,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('もう一度送信する'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _contactSupport,
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('うまくいかない場合はお問い合わせ'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMedium,
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMedium, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startUpload() async {
    setState(() {
      _phase = _UploadPhase.uploading;
      _errorMessage = null;
    });

    try {
      await OrderUploadService.instance.uploadOrder(widget.order);
      // 写真送付の完了をもって「注文済み」とする（ホームUIの切替に使う）。
      // 決済前ではなくここで立てることで、決済せず離脱した人を「注文済み」にしない。
      await AppPreferences.setHasOrdered();
      // ローカルの控えを「写真送信済み」に更新
      await DatabaseService()
          .upsertOrder(widget.order.copyWith(status: OrderStatus.uploaded));
      if (mounted) setState(() => _phase = _UploadPhase.done);
    } on OrderUploadException catch (e) {
      if (mounted) {
        setState(() {
          _phase = _UploadPhase.error;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _UploadPhase.error;
          _errorMessage = '予期しないエラーが発生しました。';
        });
      }
    }
  }

  /// 未送信（pending）注文を削除してホームに戻る。
  /// 決済せず離脱した注文をこの画面からも消せるようにする救済導線。
  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この注文を削除しますか？'),
        content: Text(
          '受付番号 ${widget.order.orderNumber} の控えを削除します。\n'
          'お支払い済みの場合は削除しないでください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseService().deleteOrder(widget.order.orderNumber);
      if (mounted) context.go('/');
    }
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': '【お問い合わせ】受付番号 ${widget.order.orderNumber}',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(const ClipboardData(text: _supportEmail));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('メールアプリが見つかりませんでした。アドレスをコピーしました'),
          ),
        );
      }
    }
  }
}
