import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../models/costume_overlay.dart';
import '../models/license_card.dart';
import '../services/license_composer.dart';
import '../theme/colors.dart';

/// タグ用丸形デザイン画面:
/// 編集済みペット写真を高解像度の円形にトリミングして PNG 書き出し
class TagDesignScreen extends StatefulWidget {
  final LicenseCard card;

  const TagDesignScreen({super.key, required this.card});

  @override
  State<TagDesignScreen> createState() => _TagDesignScreenState();
}

class _TagDesignScreenState extends State<TagDesignScreen> {
  /// 写真の位置とスケール
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  /// ドラッグ・ピンチ用の一時変数
  double _prevScale = 1.0;
  Offset _prevOffset = Offset.zero;
  Offset _focalStart = Offset.zero;

  bool _isSaving = false;
  String? _savedPath;

  /// 高解像度元画像（Canvas直接描画用）
  ui.Image? _sourceImage;

  /// プレビュー用の合成済み画像バイト列
  Uint8List? _composedPreviewBytes;
  bool _isLoading = true;

  /// 出力サイズ: Φ25mm 高解像度（~1040dpi）
  static const int _exportSize = 1024;

  /// 画面上のプレビューサイズ
  static const double _previewSize = 240.0;

  @override
  void initState() {
    super.initState();
    _loadSourceImage();
  }

  /// composePhotoPreview で写真+コスチューム合成済み画像を生成し、
  /// それをソース画像として読み込む
  Future<void> _loadSourceImage() async {
    try {
      final card = widget.card;
      final photoFile = File(card.photoPath);
      if (!photoFile.existsSync()) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final photoBytes = await photoFile.readAsBytes();
      final extra = card.extraData ?? {};

      // extraData からコスチュームオーバーレイを復元
      final overlayMaps = extra['costumeOverlays'] as List<dynamic>? ?? [];
      final overlays = overlayMaps
          .map((m) => CostumeOverlay.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();

      final request = LicenseComposeRequest(
        petName: card.petName,
        species: card.species,
        breed: card.breed,
        birthDate: card.birthDate,
        gender: card.gender,
        specialty: card.specialty,
        licenseType: card.licenseType,
        photoBytes: photoBytes,
        costumeId: card.costumeId,
        frameColor: card.frameColor,
        templateType: card.templateType,
        costumeOverlays: overlays,
        outfitId: extra['outfitId'] as String?,
        photoScale: (extra['photoScale'] as num?)?.toDouble() ?? 1.0,
        photoOffsetX: (extra['photoOffsetX'] as num?)?.toDouble() ?? 0.0,
        photoOffsetY: (extra['photoOffsetY'] as num?)?.toDouble() ?? 0.0,
        photoRotation: (extra['photoRotation'] as num?)?.toDouble() ?? 0.0,
        photoBrightness: (extra['photoBrightness'] as num?)?.toDouble() ?? 0.0,
        photoContrast: (extra['photoContrast'] as num?)?.toDouble() ?? 0.0,
        photoSaturation: (extra['photoSaturation'] as num?)?.toDouble() ?? 0.0,
        photoBgColor: extra['photoBgColor'] as int?,
      );

      // scale=3.0 で高解像度合成（~870×1116px）
      final composedBytes =
          await LicenseComposer().composePhotoPreview(request, scale: 3.0);

      // 合成結果を ui.Image にデコード
      final codec = await ui.instantiateImageCodec(composedBytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _sourceImage = frame.image;
          _composedPreviewBytes = composedBytes;
          // 初期スケール: cover相当（円を隙間なく埋める）
          final imgW = frame.image.width.toDouble();
          final imgH = frame.image.height.toDouble();
          final containScale =
              imgW / imgH < 1.0 ? _previewSize / imgW : _previewSize / imgH;
          final displayW = imgW * containScale;
          final displayH = imgH * containScale;
          _scale = (_previewSize / displayW).clamp(1.0, 4.0);
          if (_previewSize / displayH > _scale) {
            _scale = (_previewSize / displayH).clamp(1.0, 4.0);
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('タグ用画像作成'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'ドラッグ・ピンチで写真の位置とサイズを調整してください',
                    style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // 丸形プレビュー（ジェスチャー操作可能）
                  _buildCircularEditor(),
                  const SizedBox(height: 8),
                  const Text(
                    'Φ25mm（実寸）',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 24),

                  // リセットボタン
                  TextButton.icon(
                    onPressed: _resetPosition,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('位置をリセット'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ガイド
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡 ポイント',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• ペットの顔が円の中心に来るように調整\n'
                          '• ピンチで拡大・縮小できます\n'
                          '• タグの表面にこの画像がそのまま印刷されます',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 保存済み表示
                  if (_savedPath != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'カメラロールに保存しました！\nフォームで送付する際にこの画像を使ってください',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textDark,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ボタンエリア
          _buildBottomButtons(),
        ],
      ),
    );
  }

  /// 丸形エディタ: ドラッグ＋ピンチで調整
  Widget _buildCircularEditor() {
    return Center(
      child: _isLoading
          ? const SizedBox(
              width: _previewSize,
              height: _previewSize,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : GestureDetector(
              onScaleStart: (details) {
                _prevScale = _scale;
                _prevOffset = _offset;
                _focalStart = details.focalPoint;
              },
              onScaleUpdate: (details) {
                setState(() {
                  _scale = (_prevScale * details.scale).clamp(0.5, 4.0);
                  _offset = _prevOffset + (details.focalPoint - _focalStart);
                });
              },
              child: Container(
                width: _previewSize,
                height: _previewSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: _previewSize,
                  height: _previewSize,
                  color: Colors.white,
                  child: _composedPreviewBytes != null
                      ? Transform.translate(
                          offset: _offset,
                          child: Transform.scale(
                            scale: _scale,
                            child: Image.memory(
                              _composedPreviewBytes!,
                              fit: BoxFit.contain,
                              width: _previewSize,
                              height: _previewSize,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.pets,
                              size: 60, color: AppColors.textLight),
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildBottomButtons() {
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
          onPressed: _isSaving || _savedPath != null ? null : _saveImage,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : _savedPath != null
                  ? const Icon(Icons.check_circle, size: 20)
                  : const Icon(Icons.save_alt, size: 20),
          label: Text(
            _isSaving
                ? '保存中...'
                : _savedPath != null
                    ? '保存済み ✓ 注文画面に戻ります'
                    : 'カメラロールに保存して次へ',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _savedPath != null ? AppColors.success : AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.success,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  void _resetPosition() {
    if (_sourceImage == null) {
      setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
      });
      return;
    }
    // cover相当の初期スケールに戻す
    final imgW = _sourceImage!.width.toDouble();
    final imgH = _sourceImage!.height.toDouble();
    final containScale =
        imgW / imgH < 1.0 ? _previewSize / imgW : _previewSize / imgH;
    final displayW = imgW * containScale;
    final displayH = imgH * containScale;
    var newScale = (_previewSize / displayW).clamp(1.0, 4.0);
    if (_previewSize / displayH > newScale) {
      newScale = (_previewSize / displayH).clamp(1.0, 4.0);
    }
    setState(() {
      _scale = newScale;
      _offset = Offset.zero;
    });
  }

  /// 元画像から直接 Canvas で高解像度円形画像を生成
  Future<Uint8List?> _captureCircularImage() async {
    if (_sourceImage == null) return null;

    final image = _sourceImage!;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final size = _exportSize.toDouble();
    final ratio = size / _previewSize;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 円形クリッピング
    final circlePath = Path()..addOval(Rect.fromLTWH(0, 0, size, size));
    canvas.clipPath(circlePath);

    // 白背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size, size),
      Paint()..color = Colors.white,
    );

    // ユーザーの操作を出力座標系に変換して適用
    canvas.translate(_offset.dx * ratio, _offset.dy * ratio);
    canvas.translate(size / 2, size / 2);
    canvas.scale(_scale);
    canvas.translate(-size / 2, -size / 2);

    // contain-fit: 元画像を出力サイズに収める
    final containScale =
        (size / imgW) < (size / imgH) ? size / imgW : size / imgH;
    final displayW = imgW * containScale;
    final displayH = imgH * containScale;
    final left = (size - displayW) / 2;
    final top = (size - displayH) / 2;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromLTWH(left, top, displayW, displayH),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(size.toInt(), size.toInt());
    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);

    finalImage.dispose();

    return byteData?.buffer.asUint8List();
  }

  Future<String?> _saveToFile(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${dir.path}/tag_${widget.card.petName}_$timestamp.png';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _captureCircularImage();
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('画像の生成に失敗しました')),
          );
        }
        return;
      }

      // まずファイルに書き出し（Gal はファイルパスが必要）
      final path = await _saveToFile(bytes);
      if (path == null) return;

      // カメラロールに保存
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
      await Gal.putImage(path, album: 'うちの子免許証');

      if (mounted) {
        setState(() => _savedPath = path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('カメラロールに保存しました'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // 1秒後に自動で注文画面に戻る
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
