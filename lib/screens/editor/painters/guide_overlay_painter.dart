import 'package:flutter/material.dart';

/// 証明写真ガイド（ペット型シルエット）
class GuideOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x6000BCD4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final cx = size.width / 2;

    // 頭（楕円）— 衣装の首位置に合わせて配置
    final headCx = cx;
    final headCy = size.height * 0.397;
    final headRx = size.width * 0.329;
    final headRy = size.height * 0.254;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCx, headCy),
        width: headRx * 2,
        height: headRy * 2,
      ),
      paint,
    );

    // 耳（楕円・点線）— 顔の横、滑らかに接続
    final earPaint = Paint()
      ..color = const Color(0x6000BCD4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final earRx = headRx * 0.35;
    final earRy = headRy * 0.55;
    final earOffsetX = headRx * 0.9;
    final earOffsetY = headRy * -0.3;

    // 点線で楕円を描画（顔の内側部分をクリップで除外）
    void drawDashedOvalClipped(Offset center, double rx, double ry) {
      final path = Path()
        ..addOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2));
      final headPath = Path()
        ..addOval(Rect.fromCenter(
          center: Offset(headCx, headCy),
          width: headRx * 2,
          height: headRy * 2,
        ));
      final clippedPath = Path.combine(PathOperation.difference, path, headPath);
      final metrics = clippedPath.computeMetrics();
      const dashLen = 6.0;
      const gapLen = 4.0;
      for (final metric in metrics) {
        final total = metric.length;
        double dist = 0;
        while (dist < total) {
          final end = (dist + dashLen).clamp(0, total);
          final segment = metric.extractPath(dist, end.toDouble());
          canvas.drawPath(segment, earPaint);
          dist += dashLen + gapLen;
        }
      }
    }

    final leftEarCenter = Offset(headCx - earOffsetX, headCy + earOffsetY);
    final rightEarCenter = Offset(headCx + earOffsetX, headCy + earOffsetY);
    drawDashedOvalClipped(leftEarCenter, earRx, earRy);
    drawDashedOvalClipped(rightEarCenter, earRx, earRy);

    // 首（頭楕円の内側から開始して視覚的に接続）
    final neckTop = headCy + headRy * 0.92;
    final neckBottom = headCy + headRy + size.height * 0.06;
    final neckHalfW = size.width * 0.17;
    canvas.drawLine(
      Offset(cx - neckHalfW, neckTop),
      Offset(cx - neckHalfW, neckBottom),
      paint,
    );
    canvas.drawLine(
      Offset(cx + neckHalfW, neckTop),
      Offset(cx + neckHalfW, neckBottom),
      paint,
    );

    // 肩（台形）— 下端を画面最下部まで
    final shoulderTop = neckBottom;
    final shoulderBottom = size.height * 0.96;
    final shoulderOuterW = size.width * 0.48;
    final path = Path()
      ..moveTo(cx - neckHalfW, shoulderTop)
      ..lineTo(cx - shoulderOuterW, shoulderBottom)
      ..lineTo(cx + shoulderOuterW, shoulderBottom)
      ..lineTo(cx + neckHalfW, shoulderTop);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant GuideOverlayPainter oldDelegate) => false;
}
