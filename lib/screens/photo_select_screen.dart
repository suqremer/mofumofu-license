import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/colors.dart';

/// 画面1: 写真選択 → 即 情報入力へ
class PhotoSelectScreen extends StatefulWidget {
  const PhotoSelectScreen({super.key});

  @override
  State<PhotoSelectScreen> createState() => _PhotoSelectScreenState();
}

class _PhotoSelectScreenState extends State<PhotoSelectScreen> {
  bool _isProcessing = false;

  /// 写真を選択して即座に情報入力画面へ遷移
  Future<void> _pickImage(ImageSource source) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        setState(() => _isProcessing = false);
        return;
      }

      setState(() => _isProcessing = false);

      if (mounted) {
        await context.push('/create/info', extra: pickedFile.path);
      }
    } on PlatformException catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;

      // カメラ/写真ライブラリの権限拒否を検出
      if (e.code == 'camera_access_denied' ||
          e.code == 'photo_access_denied' ||
          (e.message?.contains('denied') ?? false) ||
          (e.message?.contains('permission') ?? false)) {
        _showPermissionDeniedDialog(source);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('写真の取得に失敗しました。もう一度試してね'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('写真の取得に失敗しました。もう一度試してね'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  /// 権限拒否時のダイアログ（設定画面への誘導）
  void _showPermissionDeniedDialog(ImageSource source) {
    final isCamera = source == ImageSource.camera;
    final permissionName = isCamera ? 'カメラ' : '写真ライブラリ';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionNameへのアクセスが必要です'),
        content: Text(
          isCamera
              ? 'ペットの写真を撮影するには、カメラへのアクセスを許可してください。\n\n設定アプリから「うちの子免許証」のカメラをオンにしてね。'
              : 'ペットの写真を選択するには、写真ライブラリへのアクセスを許可してください。\n\n設定アプリから「うちの子免許証」の写真をオンにしてね。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('あとで'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // iOSの設定アプリを開く
              launchUrl(Uri.parse('app-settings:'));
            },
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('写真を選ぶ'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            children: [
              const Spacer(flex: 1),
              _buildPlaceholder(),
              const SizedBox(height: 16),
              const Text(
                '証明写真窓口',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'かわいく撮れた写真を選んでね',
                style: TextStyle(fontSize: 14, color: AppColors.textMedium),
              ),
              const Spacer(flex: 1),
              _buildPickButtons(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// プレースホルダ（点線の丸 + カメラアイコン）
  Widget _buildPlaceholder() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: CustomPaint(
        painter: _DashedCirclePainter(color: Colors.grey.shade400),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_camera_outlined,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'タップして選択',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 写真選択ボタン群
  Widget _buildPickButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'カメラロールから選ぶ',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _isProcessing
                ? null
                : () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text(
              'カメラで撮影',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 点線の円を描画するカスタムペインター
class _DashedCirclePainter extends CustomPainter {
  final Color color;

  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashLength = 8.0;
    const gapLength = 6.0;
    final radius = (size.width / 2) - 4;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * 3.14159265 * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startAngle =
          (i * (dashLength + gapLength)) / radius;
      final sweepAngle = dashLength / radius;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
