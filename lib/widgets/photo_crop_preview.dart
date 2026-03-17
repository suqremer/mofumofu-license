import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/license_card.dart';
import '../models/license_template.dart';
import '../theme/colors.dart';

/// 免許証画像から証明写真エリアだけを切り出して表示するウィジェット。
///
/// [savedImagePath] が存在する場合は [photoRectRatio] で証明写真部分をクロップ表示。
/// 存在しない場合は [photoPath]（生のペット写真）をそのまま表示。
class PhotoCropPreview extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final savedPath = card.savedImagePath;
    final hasSavedImage = savedPath != null && File(savedPath).existsSync();

    Widget content;
    if (hasSavedImage) {
      content = _buildCroppedImage(File(savedPath));
    } else {
      content = _buildFallbackImage();
    }

    if (circular) {
      return ClipOval(child: content);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }

  /// savedImagePath から photoRectRatio 領域を切り出して表示
  Widget _buildCroppedImage(File file) {
    final template = LicenseTemplate.fromId(card.templateType);
    final r = template.photoRectRatio;
    final outputSize = template.outputSize;

    // クロップ領域の実ピクセルサイズ
    final cropPixelW = r.width * outputSize.width;
    final cropPixelH = r.height * outputSize.height;

    // cover: クロップ領域が size x size を完全に埋めるスケール
    final scale = math.max(size / cropPixelW, size / cropPixelH);

    // スケール後の画像全体サイズ
    final imgW = outputSize.width * scale;
    final imgH = outputSize.height * scale;

    // クロップ領域の中心が widget 中心に来るようオフセット
    final tx = size / 2 - (r.center.dx * imgW);
    final ty = size / 2 - (r.center.dy * imgH);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(tx, ty),
            child: SizedBox(
              width: imgW,
              height: imgH,
              child: Image.file(file, fit: BoxFit.fill),
            ),
          ),
        ),
      ),
    );
  }

  /// savedImagePath がない場合のフォールバック
  Widget _buildFallbackImage() {
    final photoFile = File(card.photoPath);
    if (photoFile.existsSync()) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.file(photoFile, fit: BoxFit.cover),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        color: AppColors.primary.withValues(alpha: 0.08),
        child: Icon(Icons.pets, color: AppColors.primary.withValues(alpha: 0.3)),
      ),
    );
  }
}
