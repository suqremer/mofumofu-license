import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/license_card.dart';
import '../models/license_template.dart';
import '../theme/colors.dart';

/// タグ用丸形デザイン画面:
/// ペット写真を Φ25mm（295px @ 300dpi）の円形にトリミングして PNG 書き出し
class TagDesignScreen extends StatefulWidget {
  final LicenseCard card;

  const TagDesignScreen({super.key, required this.card});

  @override
  State<TagDesignScreen> createState() => _TagDesignScreenState();
}

class _TagDesignScreenState extends State<TagDesignScreen> {
  /// 丸形キャプチャ用のキー
  final _captureKey = GlobalKey();

  /// 写真の位置とスケール
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  /// ドラッグ・ピンチ用の一時変数
  double _prevScale = 1.0;
  Offset _prevOffset = Offset.zero;
  Offset _focalStart = Offset.zero;

  bool _isSaving = false;
  String? _savedPath;

  /// savedImagePath から photoRect をクロップした画像ファイル
  File? _croppedPhotoFile;
  bool _isCropping = true;

  /// 出力サイズ: Φ25mm @ 300dpi ≈ 295px
  static const int _exportSize = 295;

  /// 画面上のプレビューサイズ
  static const double _previewSize = 240.0;

  @override
  void initState() {
    super.initState();
    _cropPhotoFromSavedImage();
  }

  /// savedImagePath から証明写真エリアをクロップしてテンポラリファイルに保存
  Future<void> _cropPhotoFromSavedImage() async {
    final savedPath = widget.card.savedImagePath;
    if (savedPath == null || !File(savedPath).existsSync()) {
      // savedImagePath がなければ生写真をそのまま使う
      if (mounted) setState(() => _isCropping = false);
      return;
    }

    try {
      // 画像をデコード
      final bytes = await File(savedPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // photoRect（ピクセル座標）でクロップ
      final template = LicenseTemplate.fromId(widget.card.templateType);
      final r = template.photoRect;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(r.left, r.top, r.width, r.height),
        Rect.fromLTWH(0, 0, r.width, r.height),
        Paint(),
      );

      final picture = recorder.endRecording();
      final croppedImage =
          await picture.toImage(r.width.toInt(), r.height.toInt());
      final byteData =
          await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      image.dispose();
      croppedImage.dispose();

      if (byteData == null) {
        if (mounted) setState(() => _isCropping = false);
        return;
      }

      // テンポラリファイルに保存
      final dir = await getApplicationDocumentsDirectory();
      final tempPath = '${dir.path}/tag_crop_temp.png';
      final file = File(tempPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) {
        setState(() {
          _croppedPhotoFile = file;
          _isCropping = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCropping = false);
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
        actions: [
          if (_savedPath != null)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('完了',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
        ],
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
    // クロップ済み画像 > 生写真 の優先順で使用
    final photoFile = _croppedPhotoFile ?? File(widget.card.photoPath);

    return Center(
      child: _isCropping
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
                  border: Border.all(color: AppColors.accent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: RepaintBoundary(
                  key: _captureKey,
                  child: Container(
                    width: _previewSize,
                    height: _previewSize,
                    color: Colors.white,
                    child: photoFile.existsSync()
                        ? Transform.translate(
                            offset: _offset,
                            child: Transform.scale(
                              scale: _scale,
                              child: Image.file(
                                photoFile,
                                fit: BoxFit.cover,
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
      child: Row(
        children: [
          // 保存ボタン
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _saveImage,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library, size: 18),
                label: Text(_isSaving ? '保存中...' : 'カメラロールに保存'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 共有ボタン
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _shareImage,
                icon: const Icon(Icons.share, size: 18),
                label: const Text('共有する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetPosition() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  /// RepaintBoundary を高解像度でキャプチャして PNG 書き出し
  Future<Uint8List?> _captureCircularImage() async {
    final boundary =
        _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    // 出力解像度 / プレビューサイズ = pixelRatio
    final pixelRatio = _exportSize / _previewSize;
    final image = await boundary.toImage(pixelRatio: pixelRatio);

    // 円形にクリップして書き出し
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = _exportSize.toDouble();

    // 円形クリッピング
    final path = Path()..addOval(Rect.fromLTWH(0, 0, size, size));
    canvas.clipPath(path);

    // キャプチャした画像を描画
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size, size),
      Paint(),
    );

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();
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
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _captureCircularImage();
      if (bytes == null) return;

      final path = await _saveToFile(bytes);
      if (path == null) return;

      setState(() => _savedPath = path);

      await Share.shareXFiles(
        [XFile(path)],
        text: '${widget.card.petName}のタグ用画像',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
