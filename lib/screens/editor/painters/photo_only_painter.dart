import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../models/costume.dart';

/// 証明写真のみ描画する Painter
class PhotoOnlyPainter extends CustomPainter {
  final ui.Image? photoImage;
  final double photoScale;
  final double photoOffsetX;
  final double photoOffsetY;
  final double photoRotation;
  final double photoAspect;
  final ui.Image? outfitImage;
  final String? outfitId;
  final ColorFilter? photoColorFilter;

  PhotoOnlyPainter({
    this.photoImage,
    required this.photoScale,
    required this.photoOffsetX,
    required this.photoOffsetY,
    this.photoRotation = 0.0,
    required this.photoAspect,
    this.outfitImage,
    this.outfitId,
    this.photoColorFilter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 背景（白）
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    if (photoImage == null) return;

    final imgW = photoImage!.width.toDouble();
    final imgH = photoImage!.height.toDouble();
    final imgAspect = imgW / imgH;

    // 画像のアスペクトフィット: 写真エリアに収まるようにクロップ
    Rect srcRect;
    if (imgAspect > photoAspect) {
      final cropW = imgH * photoAspect;
      srcRect = Rect.fromLTWH((imgW - cropW) / 2, 0, cropW, imgH);
    } else {
      final cropH = imgW / photoAspect;
      srcRect = Rect.fromLTWH(0, (imgH - cropH) / 2, imgW, cropH);
    }

    // photoScale/Offset/Rotation を適用（canvas変換で自由スクロール+ズーム+回転）
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.save();
    canvas.clipRect(dstRect);
    // オフセットで写真をスライド
    canvas.translate(
      photoOffsetX * size.width,
      photoOffsetY * size.height,
    );
    // 回転（中心基準）
    if (photoRotation != 0.0) {
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(photoRotation);
      canvas.translate(-size.width / 2, -size.height / 2);
    }
    // ズーム（中心基準）
    if (photoScale != 1.0) {
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(photoScale);
      canvas.translate(-size.width / 2, -size.height / 2);
    }
    final photoPaint = Paint();
    if (photoColorFilter != null) {
      photoPaint.colorFilter = photoColorFilter;
    }
    canvas.drawImageRect(photoImage!, srcRect, dstRect, photoPaint);
    canvas.restore();

    // 顔ハメオーバーレイ描画（license_painterと同じロジック）
    if (outfitImage != null && outfitId != null) {
      final costume = Costume.findById(outfitId!);
      final oImgW = outfitImage!.width.toDouble();
      final oImgH = outfitImage!.height.toDouble();
      final cropRatio = switch (costume.id) {
        'sailor' => 0.90,
        'gakuran' => 0.90,
        _ => 0.50,
      };
      final oSrcRect = Rect.fromLTWH(0, 0, oImgW, oImgH * cropRatio);
      final oSrcAspect = oSrcRect.width / oSrcRect.height;
      final drawWidth = size.width * costume.defaultScale;
      final drawHeight = drawWidth / oSrcAspect;
      final verticalRatio = switch (costume.id) {
        'tuxedo' => 0.56,
        'pirate' => 0.56,
        'sailor' => 0.43,
        'gakuran' => 0.32,
        'kimono' => 0.57,
        'police' => 0.66,
        'fire' => 0.6,
        'astro' => 0.58,
        'angel' => 0.75,
        'santa' => 0.55,
        _ => 0.41,
      };
      final horizontalShift = switch (costume.id) {
        'pirate' => 0.0,
        'sailor' => size.width * 0.002,
        'gakuran' => size.width * 0.005,
        'kimono' => size.width * 0.02,
        'police' => size.width * 0.01,
        _ => 0.0,
      };
      final drawLeft = (size.width - drawWidth) / 2 + horizontalShift;
      final drawTop = size.height - drawHeight * verticalRatio;
      final oFitRect = Rect.fromLTWH(drawLeft, drawTop, drawWidth, drawHeight);
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawImageRect(outfitImage!, oSrcRect, oFitRect, Paint());
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant PhotoOnlyPainter oldDelegate) {
    return photoImage != oldDelegate.photoImage ||
        photoScale != oldDelegate.photoScale ||
        photoOffsetX != oldDelegate.photoOffsetX ||
        photoOffsetY != oldDelegate.photoOffsetY ||
        photoRotation != oldDelegate.photoRotation ||
        outfitImage != oldDelegate.outfitImage ||
        outfitId != oldDelegate.outfitId ||
        photoColorFilter != oldDelegate.photoColorFilter;
  }
}
