import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/brush_operation.dart';

/// ブラシ操作のオーバーレイ描画
class BrushOverlayPainter extends CustomPainter {
  final ui.Image photoImage;
  final double photoAspect;
  final double photoScale;
  final double photoOffsetX;
  final double photoOffsetY;
  final List<BrushOperation> operations;
  final List<Offset>? currentPoints;
  final List<Offset>? currentLassoPoints;
  final double currentBrushSize;
  final BrushTool currentTool;

  BrushOverlayPainter({
    required this.photoImage,
    required this.photoAspect,
    required this.photoScale,
    required this.photoOffsetX,
    required this.photoOffsetY,
    required this.operations,
    this.currentPoints,
    this.currentLassoPoints,
    required this.currentBrushSize,
    required this.currentTool,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imgW = photoImage.width.toDouble();
    final imgH = photoImage.height.toDouble();
    final imgAspect = imgW / imgH;

    // ベースクロップ領域
    Rect baseRect;
    if (imgAspect > photoAspect) {
      final cropW = imgH * photoAspect;
      baseRect = Rect.fromLTWH((imgW - cropW) / 2, 0, cropW, imgH);
    } else {
      final cropH = imgW / photoAspect;
      baseRect = Rect.fromLTWH(0, (imgH - cropH) / 2, imgW, cropH);
    }

    final Rect srcRect = baseRect;

    // 画像座標 → プレビュー座標
    Offset toPreview(Offset imgCoord) {
      final relX = (imgCoord.dx - srcRect.left) / srcRect.width;
      final relY = (imgCoord.dy - srcRect.top) / srcRect.height;
      double px = relX * size.width;
      double py = relY * size.height;
      if (photoScale != 1.0) {
        px = size.width / 2 + (px - size.width / 2) * photoScale;
        py = size.height / 2 + (py - size.height / 2) * photoScale;
      }
      px += photoOffsetX * size.width;
      py += photoOffsetY * size.height;
      return Offset(px, py);
    }

    double sizeToPreview(double imgSize) {
      return imgSize * (size.width / srcRect.width) * photoScale;
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // 確定済み操作を半透明で描画
    for (final op in operations) {
      switch (op) {
        case EraserStroke(:final points, :final brushSize):
          _drawStroke(canvas, points, sizeToPreview(brushSize),
              const Color(0x44FF0000), toPreview);
        case RestoreStroke(:final points, :final brushSize):
          _drawStroke(canvas, points, sizeToPreview(brushSize),
              const Color(0x4400FF00), toPreview);
        case LassoOperation(:final points):
          if (points.length >= 3) {
            _drawLassoMask(canvas, points, size, imgW, imgH, toPreview);
          }
      }
    }

    // 描画中のストローク
    if (currentPoints != null && currentPoints!.isNotEmpty) {
      final color = currentTool == BrushTool.eraser
          ? const Color(0x66FF0000)
          : const Color(0x6600FF00);
      _drawStroke(canvas, currentPoints!, sizeToPreview(currentBrushSize),
          color, toPreview);
    }

    // 描画中の投げ縄（点線）
    if (currentLassoPoints != null && currentLassoPoints!.length >= 2) {
      _drawDashedLasso(canvas, currentLassoPoints!, toPreview);
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, List<Offset> points, double brushSize,
      Color color, Offset Function(Offset) toPreview) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = brushSize
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final previewPoints = points.map(toPreview).toList();

    if (previewPoints.length == 1) {
      canvas.drawCircle(
          previewPoints[0], brushSize / 2, paint..style = PaintingStyle.fill);
    } else {
      final path = Path()
        ..moveTo(previewPoints[0].dx, previewPoints[0].dy);
      for (int i = 1; i < previewPoints.length; i++) {
        path.lineTo(previewPoints[i].dx, previewPoints[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  /// 確定済み投げ縄: 囲み外側を赤半透明でマスク表示
  void _drawLassoMask(Canvas canvas, List<Offset> points, Size size,
      double imgW, double imgH, Offset Function(Offset) toPreview) {
    final previewPoints = points.map(toPreview).toList();
    final lassoPath = Path()
      ..moveTo(previewPoints[0].dx, previewPoints[0].dy);
    for (int i = 1; i < previewPoints.length; i++) {
      lassoPath.lineTo(previewPoints[i].dx, previewPoints[i].dy);
    }
    lassoPath.close();

    final outerRect = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final combined = Path.combine(PathOperation.difference, outerRect, lassoPath);
    canvas.drawPath(
      combined,
      Paint()
        ..color = const Color(0x44FF0000)
        ..style = PaintingStyle.fill,
    );
  }

  /// 描画中の投げ縄を点線で表示
  void _drawDashedLasso(Canvas canvas, List<Offset> points,
      Offset Function(Offset) toPreview) {
    final previewPoints = points.map(toPreview).toList();
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final shadowPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const dashLen = 8.0;
    const gapLen = 5.0;

    for (int i = 0; i < previewPoints.length - 1; i++) {
      final p0 = previewPoints[i];
      final p1 = previewPoints[i + 1];
      final dx = p1.dx - p0.dx;
      final dy = p1.dy - p0.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist == 0) continue;
      final ux = dx / dist;
      final uy = dy / dist;

      double travelled = 0;
      bool drawing = true;
      while (travelled < dist) {
        final segLen =
            math.min(drawing ? dashLen : gapLen, dist - travelled);
        if (drawing) {
          final start = Offset(p0.dx + ux * travelled, p0.dy + uy * travelled);
          final end = Offset(
            p0.dx + ux * (travelled + segLen),
            p0.dy + uy * (travelled + segLen),
          );
          canvas.drawLine(start, end, shadowPaint);
          canvas.drawLine(start, end, paint);
        }
        travelled += segLen;
        drawing = !drawing;
      }
    }

    // 始点に小さな丸を描画（閉じるヒント）
    if (previewPoints.length >= 3) {
      canvas.drawCircle(
        previewPoints[0],
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        previewPoints[0],
        5,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BrushOverlayPainter oldDelegate) => true;
}
