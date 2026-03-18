import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/license_card.dart';
import '../models/license_template.dart';
import '../theme/colors.dart';

/// 免許証画像から証明写真エリアだけを切り出して表示するウィジェット。
///
/// [savedImagePath] が存在する場合は [photoRectRatio] で証明写真部分をクロップ表示。
/// 存在しない場合は [photoPath]（生のペット写真）をそのまま表示。
class PhotoCropPreview extends StatefulWidget {
  final LicenseCard card;

  /// 丸形にクリップするか（タグ注文用）
  final bool circular;

  /// ウィジェットのサイズ（circular=true の場合は直径）
  final double size;

  const PhotoCropPreview({
    super.key,
    required this.card,
    this.circular = false,
    this.size = 120,
  });

  @override
  State<PhotoCropPreview> createState() => _PhotoCropPreviewState();
}

class _PhotoCropPreviewState extends State<PhotoCropPreview> {
  ui.Image? _image;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(PhotoCropPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.savedImagePath != widget.card.savedImagePath ||
        oldWidget.card.photoPath != widget.card.photoPath) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final savedPath = widget.card.savedImagePath;
    if (savedPath != null && File(savedPath).existsSync()) {
      final bytes = await File(savedPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _image = frame.image;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_loading) {
      content = SizedBox(
        width: widget.size,
        height: widget.size,
        child: Container(
          color: AppColors.primary.withValues(alpha: 0.08),
        ),
      );
    } else if (_image != null) {
      content = _buildCroppedImage();
    } else {
      content = _buildFallbackImage();
    }

    if (widget.circular) {
      return ClipOval(child: content);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }

  /// dart:ui Image から photoRectRatio 領域を直接クロップ描画
  Widget _buildCroppedImage() {
    final template = LicenseTemplate.fromId(widget.card.templateType);
    final r = template.photoRectRatio;
    final image = _image!;

    // 実画像サイズから写真領域のピクセル矩形を計算
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final srcRect = Rect.fromLTWH(
      r.left * imgW,
      r.top * imgH,
      r.width * imgW,
      r.height * imgH,
    );

    // srcRect を size×size に cover で描画するための src 調整
    // （写真領域が正方形でない場合、短辺に合わせて中心クロップ）
    final srcAspect = srcRect.width / srcRect.height;
    Rect adjustedSrc;
    if (srcAspect > 1) {
      // 横長 → 高さに合わせ、幅を中央クロップ
      final newW = srcRect.height;
      adjustedSrc = Rect.fromCenter(
        center: srcRect.center,
        width: newW,
        height: srcRect.height,
      );
    } else {
      // 縦長 → 幅に合わせ、高さを中央クロップ
      final newH = srcRect.width;
      adjustedSrc = Rect.fromCenter(
        center: srcRect.center,
        width: srcRect.width,
        height: newH,
      );
    }

    final dstRect = Rect.fromLTWH(0, 0, widget.size, widget.size);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _CropPainter(image, adjustedSrc, dstRect),
      ),
    );
  }

  /// savedImagePath がない場合のフォールバック
  Widget _buildFallbackImage() {
    final photoFile = File(widget.card.photoPath);
    if (photoFile.existsSync()) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image.file(photoFile, fit: BoxFit.cover),
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Container(
        color: AppColors.primary.withValues(alpha: 0.08),
        child: Icon(Icons.pets, color: AppColors.primary.withValues(alpha: 0.3)),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect;
  final Rect dstRect;

  _CropPainter(this.image, this.srcRect, this.dstRect);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.srcRect != srcRect;
}
