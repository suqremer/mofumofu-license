import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/license_template.dart';
import '../models/costume.dart';
import '../models/costume_overlay.dart';

/// 免許証を Canvas に描画する CustomPainter
///
/// 全寸法は 1024×646 の基準サイズで設計し、実際の描画サイズに応じて
/// スケールファクタ (s) で自動調整される。
class LicensePainter extends CustomPainter {
  final LicenseTemplate template;
  final String frameColorId;
  final ui.Image? photoImage;
  final List<CostumeOverlay> costumeOverlays;
  final Map<String, ui.Image> costumeImages;
  final String petName;
  final String species;
  final String? breed;
  final DateTime? birthDate;
  final bool birthDateUnknown;
  final String? gender;
  final String? specialty;
  final String? specialtyId;
  final String? customCondition;
  final String? customAddress;
  final String licenseTypeLabel;
  final String validityText;

  /// 写真の拡大率（1.0 = デフォルト、2.0 = 2倍拡大）
  final double photoScale;

  /// 写真の水平オフセット（-0.5〜0.5、写真幅に対する比率）
  final double photoOffsetX;

  /// 写真の垂直オフセット（-0.5〜0.5、写真高さに対する比率）
  final double photoOffsetY;

  /// 顔ハメコスチュームID
  final String? outfitId;

  /// 顔ハメコスチュームの画像（最終合成用）
  final ui.Image? outfitImage;

  /// 証明写真の背景色
  final Color photoBgColor;

  late final String _licenseNumber;

  LicensePainter({
    required this.template,
    required this.frameColorId,
    this.photoImage,
    this.costumeOverlays = const [],
    this.costumeImages = const {},
    this.photoScale = 1.0,
    this.photoOffsetX = 0.0,
    this.photoOffsetY = 0.0,
    this.outfitId,
    this.outfitImage,
    this.photoBgColor = const Color(0xFFFFFFFF),
    required this.petName,
    required this.species,
    this.breed,
    this.birthDate,
    this.birthDateUnknown = false,
    this.gender,
    this.specialty,
    this.specialtyId,
    this.customCondition,
    this.customAddress,
    required this.licenseTypeLabel,
    required this.validityText,
  }) {
    _licenseNumber = _generateLicenseNumber();
  }

  // ---------------------------------------------------------------------------
  // 色定数
  // ---------------------------------------------------------------------------
  static const Color _labelBlue = Color(0xFF3B7CB8);
  static const Color _sealRed = Color(0xFFC62828);
  static const Color _bgCream = Color(0xFFF5F0E8);
  static const Color _textBlack = Color(0xFF333333);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _gridLine = Color(0xFF555555);

  static const double _refW = 1024.0;

  @override
  void paint(Canvas canvas, Size size) {
    switch (template.type) {
      case TemplateType.japan:
        _paintJapanTemplate(canvas, size);
        break;
      case TemplateType.usa:
        _paintUsaTemplate(canvas, size);
        break;
    }
    // コスチュームオーバーレイ（最終合成時のみ描画される）
    if (costumeOverlays.isNotEmpty) {
      _paintCostumeOverlays(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant LicensePainter oldDelegate) {
    return oldDelegate.petName != petName ||
        oldDelegate.frameColorId != frameColorId ||
        oldDelegate.costumeOverlays.length != costumeOverlays.length ||
        _overlaysChanged(oldDelegate.costumeOverlays) ||
        oldDelegate.template.type != template.type ||
        oldDelegate.photoImage != photoImage ||
        oldDelegate.validityText != validityText ||
        oldDelegate.customAddress != customAddress ||
        oldDelegate.outfitId != outfitId ||
        oldDelegate.outfitImage != outfitImage ||
        oldDelegate.photoScale != photoScale ||
        oldDelegate.photoOffsetX != photoOffsetX ||
        oldDelegate.photoOffsetY != photoOffsetY ||
        oldDelegate.photoBgColor != photoBgColor;
  }

  bool _overlaysChanged(List<CostumeOverlay> old) {
    for (var i = 0; i < costumeOverlays.length && i < old.length; i++) {
      final a = costumeOverlays[i];
      final b = old[i];
      if (a.uid != b.uid ||
          a.cx != b.cx ||
          a.cy != b.cy ||
          a.scale != b.scale ||
          a.rotation != b.rotation) {
        return true;
      }
    }
    return false;
  }

  // ===========================================================================
  // 日本風テンプレート（なめ猫オマージュ）
  // ===========================================================================

  void _paintJapanTemplate(Canvas canvas, Size size) {
    final s = size.width / _refW;

    _paintBackground(canvas, size, s);
    _paintFrame(canvas, size, s);

    // ── グリッド定義（441×271 参照画像 → 1024×646 キャンバス）──
    final double gL = 18 * s;           // 左マージン
    final double gT = 24 * s;           // 上マージン
    final double gB = size.height - 12 * s; // 下端 (~634)
    final double fR = size.width - 12 * s;  // 右端 (~1012)
    final double lW = 84 * s;           // ラベル列幅
    final double vL = gL + lW;          // 値の左端 (102*s)
    final double ugR = 699 * s;         // 写真左端 / 上部グリッド右端

    // 行 Y 座標（各行の下端）
    final double r1 = 79 * s;           // 氏名 bottom
    final double r1b = 115 * s;         // 住所 top（氏名との間に15px相当の間隔）
    final double r2 = 167 * s;          // 住所 bottom = 写真 top
    final double r3 = 212 * s;          // 交付 bottom = 緑バンド top
    final double r4 = 272 * s;          // 緑バンド bottom = 条件 top
    final double r5 = 439 * s;          // 条件 bottom = 番号 top
    final double r6 = 491 * s;          // 番号 bottom = 下部グリッド top

    // 写真
    final photoRect = Rect.fromLTWH(722 * s, 167 * s, 290 * s, 372 * s);

    final lp = Paint()
      ..color = _gridLine
      ..strokeWidth = 1.5 * s;
    final thickBorder = Paint()
      ..color = _gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s;

    // ══════════ Row 0: 氏名 (gT → r1, full width gL→fR) ══════════
    _drawText(canvas, '氏名',
        Offset(gL + lW / 2 - 10 * s, gT + (r1 - gT) / 2 - 20 * s),
        fontSize: 25 * s,
        color: _textBlack,
        bold: true,
        center: true,
        maxWidth: lW - 10 * s);
    // 名前と生年月日の区切り線位置（参考: x=270/441 → 627*s）
    final double birthSep = 627 * s;
    // 名前（左揃え、縦中央）
    _drawText(canvas, petName,
        Offset(vL + 10 * s, gT + (r1 - gT) / 2 - 27 * s),
        fontSize: 34 * s,
        color: _textBlack,
        bold: true,
        maxWidth: birthSep - vL - 16 * s,
        letterSpacing: 4 * s);
    // 生年月日（漢字は通常、数字は太字で描画）
    final birthNoPad = _formatBirthDateWarekiNoPad();
    if (birthNoPad.isNotEmpty) {
      final birthMaxW = fR - birthSep - 10 * s;
      _drawBirthMixed(canvas, birthNoPad,
          Offset((birthSep + fR) / 2 - 7 * s, gT + (r1 - gT) / 2 - 27 * s),
          fontSize: 34 * s,
          maxWidth: (birthDateUnknown || birthDate == null) ? birthMaxW * 0.65 : birthMaxW,
          letterSpacing: 5 * s,
          justify: birthDateUnknown || birthDate == null);
    }
    canvas.drawLine(Offset(birthSep, gT), Offset(birthSep, r1), lp);

    // ── 品種（氏名行と住所行の間に小さく表示）──
    if (breed != null && breed!.isNotEmpty && breed != '不明') {
      _drawText(canvas, breed!,
          Offset(vL + 10 * s, r1 + (r1b - r1) / 2 - 15 * s),
          fontSize: 18 * s,
          color: _textBlack);
    }

    // ══════════ Row 1: 住所 (r1b → r2, full width gL→fR) ══════════
    _drawText(canvas, '住所',
        Offset(gL + lW / 2 - 10 * s, r1b + (r2 - r1b) / 2 - 20 * s),
        fontSize: 25 * s,
        color: _textBlack,
        bold: true,
        center: true,
        maxWidth: lW - 10 * s);
    _drawText(
        canvas, _generateJapanAddressSingle(), Offset(vL + 10 * s, r1b + (r2 - r1b) / 2 - 27 * s),
        fontSize: 34 * s,
        color: _textBlack,
        bold: true,
        maxWidth: fR - vL - 16 * s);

    // ══════════ Row 2: 交付 (r2 → r3, narrow gL→ugR) ══════════
    _drawText(canvas, '交付',
        Offset(gL + lW / 2 - 10 * s, r2 + (r3 - r2) / 2 - 20 * s),
        fontSize: 25 * s,
        color: _textBlack,
        bold: true,
        center: true,
        maxWidth: lW - 10 * s);
    final now = DateTime.now();
    final wy = now.year - 2018;
    final issued = '令和 ${wy.toString().padLeft(2, '0')} 年'
        ' ${now.month.toString().padLeft(2, '0')} 月'
        ' ${now.day.toString().padLeft(2, '0')} 日';
    final code = Random(petName.hashCode + 7).nextInt(9000) + 1000;
    _drawText(canvas, '$issued    $code', Offset(vL + 10 * s, r2 + (r3 - r2) / 2 - 27 * s),
        fontSize: 32 * s,
        color: _textBlack,
        bold: true,
        maxWidth: ugR - vL - 16 * s);

    // ── 上部グリッド外枠 ──
    // 氏名: 太枠 gL→fR, gT→r1（角丸）
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(gL, gT, fR, r1), Radius.circular(25 * s)),
        thickBorder);
    // 住所〜二種: 連続した外枠
    // 住所: 上角丸の太枠（下辺r2がfR幅で右辺ステップを接続）
    canvas.drawRRect(
        RRect.fromRectAndCorners(
            Rect.fromLTRB(gL, r1b, fR, r2),
            topLeft: Radius.circular(25 * s),
            topRight: Radius.circular(25 * s)),
        thickBorder);
    // 左辺: r2 → r6 連続（r1b→r2は住所RRectでカバー）
    canvas.drawLine(Offset(gL, r2), Offset(gL, r6), thickBorder);
    // 内部横線（交付底）
    canvas.drawLine(Offset(gL, r3), Offset(ugR, r3), lp);
    // ラベル列縦線: 氏名内 gT → r1
    canvas.drawLine(Offset(vL, gT), Offset(vL, r1), lp);
    // ラベル列縦線: 住所+交付 r1b → r3
    canvas.drawLine(Offset(vL, r1b), Offset(vL, r3), lp);

    // ══════════ 縦書き「運転免許証」（写真の左側）══════════
    _paintVerticalText(
        canvas, '運転免許証', Offset(670 * s, r4 - 32 * s), 36 * s, _labelBlue,
        spacing: 1.43);

    // ══════════ 緑バンド（r3 → r4, gL→ugR） ══════════
    final double greenR = 654 * s;  // 緑バンド右端
    canvas.drawRect(
      Rect.fromLTRB(gL, r3, greenR, r4),
      Paint()..color = _labelBlue,
    );
    // バンド枠線: 上辺・左辺は黒、下辺・右辺は水色
    final blueBorder = Paint()
      ..color = _labelBlue
      ..strokeWidth = 3 * s;
    canvas.drawLine(Offset(gL, r3), Offset(greenR, r3), thickBorder);   // 上辺（黒）
    canvas.drawLine(Offset(gL, r3), Offset(gL, r4), thickBorder);       // 左辺（黒）
    canvas.drawLine(Offset(gL, r4), Offset(greenR, r4), blueBorder);    // 下辺（水色）
    canvas.drawLine(Offset(greenR, r3), Offset(greenR, r4), blueBorder); // 右辺（水色）
    // 文字数に応じて左オフセット調整（10文字=0, 7文字=35, 5文字=80）
    final double validityDx = validityText.length <= 5
        ? 96 * s
        : validityText.length <= 7
            ? 63 * s
            : 0;
    _drawText(canvas, validityText,
        Offset((gL + greenR) / 2 - 112 * s - validityDx, r3 + (r4 - r3) / 2 - 24 * s),
        fontSize: 38 * s,
        color: _textBlack,
        bold: true,
        center: true,
        maxWidth: greenR - gL - 20 * s);

    // ══════════ 条件 (r4 → r5, gL→ugR) ══════════
    // ラベル: 「免許の」+「条件等」（2行）
    _drawText(canvas, '免許の',
        Offset(gL + lW / 2 - 9 * s, r4 + (r5 - r4) / 2 - 53 * s),
        fontSize: 17 * s,
        color: _textBlack,
        bold: true,
        center: true,
        maxWidth: lW - 10 * s);
    _drawText(canvas, '条件等',
        Offset(gL + lW / 2 - 9 * s, r4 + (r5 - r4) / 2 - 29 * s),
        fontSize: 17 * s,
        color: _textBlack,
        bold: true,
        center: true,
        maxWidth: lW - 10 * s);

    final conds = _generateConditions();
    _drawText(canvas, conds[0], Offset(vL + 43 * s, r4 + 29 * s),
        fontSize: 24 * s, color: _textBlack, bold: true, maxWidth: ugR - vL - 60 * s);
    _drawText(canvas, conds[1], Offset(vL + 43 * s, r4 + 65 * s),
        fontSize: 24 * s, color: _textBlack, bold: true, maxWidth: ugR - vL - 60 * s);

    // 特技（条件欄の3行目に表示）
    if (specialty != null && specialty!.isNotEmpty) {
      _drawText(canvas, '特技: ${specialty!}',
          Offset(vL + 43 * s, r4 + 101 * s),
          fontSize: 24 * s, color: _textBlack, bold: true, maxWidth: ugR - vL - 60 * s);
    }

    // 条件エリア上辺は削除（バンド下辺の水色を活かすため）

    // ── 優良バッジ（プレミアムフレーム色のみ表示）──
    const premiumFrames = {'gold', 'silver', 'rose_gold', 'holographic'};
    if (premiumFrames.contains(frameColorId)) {
      final double badgeW = 60 * s;
      final double badgeH = 38 * s;
      final double badgeX = vL + 13 * s - 52 * s;
      final double badgeY = r5 - badgeH - 12 * s;
      final badgeRect = Rect.fromLTWH(badgeX, badgeY, badgeW, badgeH);
      final badgeRRect = RRect.fromRectAndRadius(badgeRect, Radius.circular(4 * s));
      canvas.drawRRect(badgeRRect, Paint()
        ..color = _textBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * s);
      _drawText(canvas, '優良',
          Offset(badgeX + badgeW / 2 - 5 * s, badgeY + badgeH / 2 - 17 * s),
          fontSize: 24 * s, color: _textBlack, bold: true, center: true,
          maxWidth: badgeW);
    }

    // ══════════ 番号行 (r5 → r6, gL→ugR) ══════════
    // 番号ラベル縦線を下部グリッドのdateColと揃える（dateCol = gL + 100*s → 27px左 = gL + 73*s）
    final double numLabelRight = gL + 73 * s;
    _drawText(canvas, '番号',
        Offset(gL + (numLabelRight - gL) / 2 - 12 * s, r5 + (r6 - r5) / 2 - 17 * s),
        fontSize: 20 * s,
        color: _textBlack,
        bold: true,
        center: true,
        maxWidth: numLabelRight - gL - 6 * s);
    _paintLicenseNumber(canvas, s, numLabelRight + 10 * s, r5 - 5 * s, ugR - numLabelRight - 20 * s);

    canvas.drawLine(Offset(numLabelRight, r5), Offset(numLabelRight, r6), lp);
    // 番号行下辺（ラベル列のみ）
    canvas.drawLine(Offset(gL, r6), Offset(numLabelRight, r6), thickBorder);

    // ══════════ 下部グリッド (r6 → gB) ══════════
    _paintJapanBottomGrid(canvas, s, gL, r6, ugR, gB, lW, fR);

    // 写真（日本風は水色背景）
    _paintPhoto(canvas, photoRect, s,
        bgColor: photoBgColor);

    // 右辺+底辺+角丸（写真より上に表示）
    final cornerR = 20 * s;
    canvas.drawLine(Offset(fR, r2), Offset(fR, gB - cornerR), thickBorder);  // 右辺（角丸手前まで）
    canvas.drawLine(Offset(ugR, gB), Offset(fR - cornerR, gB), thickBorder); // 底辺（角丸手前まで）
    final cornerPath = Path()
      ..moveTo(fR - cornerR, gB)
      ..arcToPoint(Offset(fR, gB - cornerR),
          radius: Radius.circular(cornerR), clockwise: false);
    canvas.drawPath(cornerPath, thickBorder);

    // 住所下辺（写真より上に再描画）
    canvas.drawLine(Offset(gL, r2), Offset(fR, r2), thickBorder);

    // 朱印（写真・枠線より上に表示）
    final double sealRadius = 30 * s;
    final double sealCX = fR - 44 * s;
    final double sealCY = gB - sealRadius - 16 * s - 2 * s;
    final double textCX = sealCX - sealRadius - 175 * s;
    _drawText(canvas, 'うちの子',
        Offset(textCX - 8 * s - 2 * s, sealCY - 46 * s + 10 * s),
        fontSize: 20 * s, color: _sealRed, bold: true, center: true, maxWidth: 120 * s);
    _drawText(canvas, '公安委員会',
        Offset(textCX, sealCY - 24 * s + 10 * s),
        fontSize: 20 * s, color: _sealRed, bold: true, center: true, maxWidth: 120 * s);
    _paintSeal(canvas, Offset(sealCX, sealCY), sealRadius);
  }

  /// 下部グリッド描画（二・小・原 / 他 / 二種 + カテゴリ + 朱印）
  void _paintJapanBottomGrid(Canvas canvas, double s, double gL, double startY,
      double ugR, double bottom, double lW, double fR) {
    final lp = Paint()
      ..color = _gridLine
      ..strokeWidth = 1.5 * s;
    final thickBorder = Paint()
      ..color = _gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s;

    final double rowH = (bottom - startY) / 3;

    // 日付列の左端（行ラベルの右、27px左へ移動）
    final double dateCol = gL + 73 * s;

    // 日付データ
    final now = DateTime.now();
    final wy = now.year - 2018;
    final dateStr = '令和${wy.toString().padLeft(2, '0')}年'
        '${now.month.toString().padLeft(2, '0')}月'
        '${now.day.toString().padLeft(2, '0')}日';
    // Row 0: 二・小・原
    _drawText(canvas, '二・小・原', Offset(gL + 7 * s, startY + rowH / 2 - 8 * s),
        fontSize: 12 * s, color: _textBlack, bold: true, maxWidth: 65 * s);
    _drawText(canvas, dateStr, Offset(dateCol + 6 * s, startY + rowH / 2 - 23 * s),
        fontSize: 30 * s, color: _textBlack, bold: true, maxWidth: 300 * s);
    final double catLeft = ugR - 316 * s;
    // 行間横線（ラベル列のみ）
    canvas.drawLine(Offset(gL, startY + rowH), Offset(dateCol, startY + rowH), lp);

    // Row 1: 他
    final y1 = startY + rowH;
    _drawText(canvas, '他', Offset(gL + 31 * s, y1 + rowH / 2 - 8 * s),
        fontSize: 12 * s, color: _textBlack, bold: true, maxWidth: 65 * s);
    _drawText(canvas, dateStr, Offset(dateCol + 6 * s, y1 + rowH / 2 - 23 * s),
        fontSize: 30 * s, color: _textBlack, bold: true, maxWidth: 300 * s);
    canvas.drawLine(Offset(gL, startY + rowH * 2), Offset(dateCol, startY + rowH * 2), lp);

    // Row 2: 二種
    final y2 = startY + rowH * 2;
    _drawText(canvas, '二種', Offset(gL + 24 * s, y2 + rowH / 2 - 8 * s),
        fontSize: 12 * s, color: _textBlack, bold: true, maxWidth: 65 * s);
    _drawText(canvas, dateStr, Offset(dateCol + 6 * s, y2 + rowH / 2 - 23 * s),
        fontSize: 30 * s, color: _textBlack, bold: true, maxWidth: 300 * s);

    // 日付列の縦線（カテゴリグリッド領域まで）
    canvas.drawLine(Offset(dateCol, startY), Offset(dateCol, bottom), lp);
    // カテゴリとの境界線（catLeftからbottomまで dateCol上の線を遮るため描画不要）

    // ── 右側: カテゴリグリッド（写真左端より100px左から開始） ──
    final double catRight = fR - 90 * s;
    _paintJapanCategoryGrid(canvas, s, catLeft, startY, catRight, bottom, rowH);

    // ── 左側外枠（上辺なし、左辺+底辺+左下角丸） ──
    final double cR = 20 * s;
    canvas.drawLine(Offset(gL, startY), Offset(gL, bottom - cR), thickBorder); // 左辺
    canvas.drawLine(Offset(gL + cR, bottom), Offset(ugR, bottom), thickBorder); // 底辺
    final blPath = Path()
      ..moveTo(gL, bottom - cR)
      ..arcToPoint(Offset(gL + cR, bottom),
          radius: Radius.circular(cR), clockwise: false); // 左下角丸
    canvas.drawPath(blPath, thickBorder);
    // 底辺 ugR→fR + 角丸は _paintJapanLayout 末尾で描画（写真より上）

  }

  /// カテゴリグリッド描画（縦書きカテゴリ名 + 赤斜線背景）
  void _paintJapanCategoryGrid(Canvas canvas, double s, double left,
      double top, double right, double bottom, double rowH) {
    final lp = Paint()
      ..color = _gridLine
      ..strokeWidth = 1.0 * s;

    final categories = _getPetCategories();
    final colCount = categories.length;

    // 列幅すべて25px固定、上辺12px下げ
    final double colW = 25 * s;
    final double labelW = 25 * s;
    final double gridLeft = left + labelW;
    final double gridRight = gridLeft + colCount * colW;
    final double gridTop = top + 12 * s;
    final double gridBottom = bottom - 12 * s;
    final double midY = gridTop + (gridBottom - gridTop) / 2;

    // 赤斜線背景（カテゴリ列全体）
    _paintRedDiagonalLines(canvas, Rect.fromLTRB(gridLeft, gridTop, gridRight, gridBottom), s);

    // 「種類」ラベル（縦書き、2行にまたがる）
    _paintVerticalText(canvas, '種類', Offset(left + labelW / 2 - 8 * s, gridTop + 25 * s),
        16 * s, _textBlack, spacing: 2.5);

    // 14セル（7列×2行）からランダムに3つ選択（同じ列の重複なし）
    final rng = Random(petName.hashCode);
    final allCells = List.generate(colCount * 2, (i) => i)..shuffle(rng);
    final activeCells = <int>{};
    final usedCols = <int>{};
    for (final cell in allCells) {
      final col = cell % colCount;
      if (!usedCols.contains(col)) {
        activeCells.add(cell);
        usedCols.add(col);
        if (activeCells.length == 3) break;
      }
    }

    // 伸ばし棒を縦棒に変換するヘルパー
    String verticalChar(String ch) {
      return (ch == 'ー' || ch == 'ｰ' || ch == '-') ? '｜' : ch;
    }

    // 各カテゴリ列
    for (var i = 0; i < colCount; i++) {
      final cx = gridLeft + i * colW;
      final centerX = cx + colW / 2 - 6 * s;

      // 文字数による縦位置オフセット
      double _charYOffset(int len) {
        if (len <= 2) return 11 * s;
        if (len >= 4) return -4 * s;
        return 0;
      }

      // 1行目
      if (activeCells.contains(i)) {
        final catText = categories[i];
        var cy = gridTop + 4 * s + _charYOffset(catText.length);
        for (final char in catText.runes) {
          _drawText(canvas, verticalChar(String.fromCharCode(char)), Offset(centerX, cy),
              fontSize: 11 * s,
              color: _textBlack,
              bold: true,
              center: true,
              maxWidth: colW);
          cy += 14 * s;
        }
      } else {
        _drawText(canvas, 'ー', Offset(centerX, gridTop + (midY - gridTop) / 2 - 8 * s),
            fontSize: 14 * s, color: _textBlack, bold: true, center: true, maxWidth: colW);
      }

      // 2行目
      if (activeCells.contains(i + colCount)) {
        final catText = categories[i];
        var cy = midY + 4 * s + _charYOffset(catText.length);
        for (final char in catText.runes) {
          _drawText(canvas, verticalChar(String.fromCharCode(char)), Offset(centerX, cy),
              fontSize: 11 * s,
              color: _textBlack,
              bold: true,
              center: true,
              maxWidth: colW);
          cy += 14 * s;
        }
      } else {
        _drawText(canvas, 'ー', Offset(centerX, midY + (gridBottom - midY) / 2 - 8 * s),
            fontSize: 14 * s, color: _textBlack, bold: true, center: true, maxWidth: colW);
      }

      // 列の右に縦線
      if (i < colCount - 1) {
        canvas.drawLine(Offset(cx + colW, gridTop), Offset(cx + colW, gridBottom), lp);
      }
    }

    // 行間横線（ラベル列の右側からのみ）
    canvas.drawLine(Offset(gridLeft, midY), Offset(gridRight, midY), lp);
    // ラベル列とカテゴリ列の境界縦線
    canvas.drawLine(Offset(gridLeft, gridTop), Offset(gridLeft, gridBottom), lp);
    // 外枠（上辺・右辺・下辺）
    canvas.drawLine(Offset(left, gridTop), Offset(gridRight, gridTop), lp);
    canvas.drawLine(Offset(gridRight, gridTop), Offset(gridRight, gridBottom), lp);
    canvas.drawLine(Offset(left, gridBottom), Offset(gridRight, gridBottom), lp);
    canvas.drawLine(Offset(left, gridTop), Offset(left, gridBottom), lp);
  }

  // ===========================================================================
  // 海外風テンプレート（アメリカ州発行DLパロディ）
  // ===========================================================================

  void _paintUsaTemplate(Canvas canvas, Size size) {
    final s = size.width / _refW;

    _paintBackground(canvas, size, s);
    _paintUsaDlBackground(canvas, size, s);
    _paintFrame(canvas, size, s);

    final margin = 30 * s;
    final headerColor = _speciesHeaderColor();
    final headerH = 90 * s;

    // ── 1. ヘッダー帯（濃色バナー）──
    final headerRect = Rect.fromLTWH(
        8 * s, 8 * s, size.width - 16 * s, headerH);
    final headerRRect = RRect.fromRectAndCorners(headerRect,
        topLeft: Radius.circular(14 * s),
        topRight: Radius.circular(14 * s));
    canvas.drawRRect(headerRRect, Paint()..color = headerColor);

    // 肉球紋章（左端）
    _paintUsaCrest(canvas, Offset(72 * s, 8 * s + headerH / 2 - 2 * s), 38 * s, s);

    // ── ヘッダー2段構成（左寄せ）──
    final textL = 120 * s; // 紋章の右隣
    final classLetter = _speciesClassLetter();

    // 1段目: "STATE OF MOFUMOFU" (左) + "CLASS D" (右)
    _drawText(canvas, 'STATE OF MOFUMOFU',
        Offset(textL, 14 * s),
        fontSize: 26 * s, color: const Color(0xFFFFFDF5), bold: true,
        maxWidth: size.width - textL - 150 * s);
    _drawText(canvas, 'CLASS  $classLetter',
        Offset(size.width - margin - 130 * s, 16 * s),
        fontSize: 22 * s, color: const Color(0xFFFFFDF5), bold: true,
        maxWidth: 120 * s);

    // 2段目: "DRIVER LICENSE" (左) + "Dept of..." (右)
    _drawText(canvas, 'DRIVER LICENSE',
        Offset(textL, 48 * s),
        fontSize: 18 * s, color: const Color(0xFFFFFDF5), bold: true,
        maxWidth: 300 * s);
    _drawText(canvas, 'Dept. of Mofumofu Vehicles',
        Offset(size.width - margin - 200 * s, 54 * s),
        fontSize: 13 * s, color: const Color(0xFFFFFFFF).withValues(alpha: 0.9),
        bold: true, maxWidth: 190 * s);

    // 薄い区切り線
    canvas.drawLine(
      Offset(margin, 8 * s + headerH - 1 * s),
      Offset(size.width - margin, 8 * s + headerH - 1 * s),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.3)
        ..strokeWidth = s,
    );

    // ── 3. 写真（左側、ヘッダー下）──
    final photoTop = 8 * s + headerH + 12 * s;
    final photoW = 280 * s;
    final photoH = 400 * s;
    final photoRect = Rect.fromLTWH(margin, photoTop, photoW, photoH);
    _paintPhoto(canvas, photoRect, s, bgColor: photoBgColor);

    // 写真枠（角丸なし、実線）
    canvas.drawRect(photoRect, Paint()
      ..color = _textBlack.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s);

    // "NO SMILING" テキスト（写真下）
    _drawText(canvas, 'NO SMILING',
        Offset(margin + photoW / 2, photoTop + photoH + 4 * s),
        fontSize: 11 * s, color: _textGrey.withValues(alpha: 0.8),
        center: true, maxWidth: photoW, bold: true);

    // ── 4. データフィールド（写真の右側）──
    final fL = margin + photoW + 24 * s; // フィールド左端
    final fW = size.width - fL - margin; // フィールド幅
    var y = photoTop;

    // 列揃え用の定数（全フィールドで統一）
    final labelL = fL;
    final valueL = fL + 42 * s;
    final labelR = fL + 230 * s;
    final valueR = fL + 280 * s;

    // LN (Last Name = petName)
    _drawText(canvas, 'LN', Offset(labelL, y),
        fontSize: 15 * s, color: headerColor, bold: true);
    _drawText(canvas, petName.toUpperCase(), Offset(valueL, y - 4 * s),
        fontSize: 28 * s, color: _textBlack, bold: true, maxWidth: fW - 45 * s);
    y += 46 * s;

    // FN (First Name = breed/species)
    final fnText = _usaBreedText();
    final fnSize = fnText.length <= 10 ? 28.0 : (fnText.length <= 20 ? 24.0 : 20.0);
    _drawText(canvas, 'FN', Offset(labelL, y),
        fontSize: 15 * s, color: headerColor, bold: true);
    _drawText(canvas, fnText,
        Offset(valueL, y - 4 * s),
        fontSize: fnSize * s, color: _textBlack, bold: true, maxWidth: fW - 45 * s);
    y += 44 * s;

    // DOB + EYES（横並び）
    _drawText(canvas, 'DOB', Offset(labelL, y),
        fontSize: 15 * s, color: headerColor, bold: true);
    _drawText(canvas, _formatBirthDateUsa(), Offset(valueL, y - 2 * s),
        fontSize: 20 * s, color: _textBlack, bold: true, maxWidth: 180 * s);
    _drawText(canvas, 'EYES', Offset(labelR, y),
        fontSize: 15 * s, color: headerColor, bold: true);
    _drawText(canvas, _speciesEyesText(), Offset(valueR, y - 2 * s),
        fontSize: 20 * s, color: _textBlack, bold: true, maxWidth: 150 * s);
    y += 40 * s;

    // ISS + EXP（横並び）
    final now = DateTime.now();
    _drawText(canvas, 'ISS', Offset(labelL, y),
        fontSize: 15 * s, color: headerColor, bold: true);
    _drawText(canvas,
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}',
        Offset(valueL, y - 2 * s),
        fontSize: 20 * s, color: _textBlack, bold: true, maxWidth: 180 * s);
    _drawText(canvas, 'EXP', Offset(labelR, y),
        fontSize: 15 * s, color: headerColor, bold: true);
    _drawText(canvas, validityText.toUpperCase(),
        Offset(valueR, y - 2 * s),
        fontSize: 18 * s, color: _sealRed, bold: true, maxWidth: 180 * s);
    y += 40 * s;

    // HT + WT（横並び、ジョークフィールド）
    _drawText(canvas, 'HT', Offset(labelL, y),
        fontSize: 15 * s, color: headerColor, bold: true);
    _drawText(canvas, _speciesHeightText(), Offset(valueL, y - 2 * s),
        fontSize: 20 * s, color: _textBlack, bold: true, maxWidth: 180 * s);
    _drawText(canvas, 'WT', Offset(labelR, y),
        fontSize: 15 * s, color: headerColor, bold: true);
    _drawText(canvas, 'PERFECT', Offset(valueR, y - 2 * s),
        fontSize: 20 * s, color: _textBlack, bold: true, maxWidth: 150 * s);
    y += 40 * s;

    // SEX（ジョークフィールド）
    _drawText(canvas, 'SEX', Offset(labelL, y),
        fontSize: 15 * s, color: headerColor, bold: true);
    _drawText(canvas, _speciesSexText(), Offset(valueL, y - 2 * s),
        fontSize: 20 * s, color: _textBlack, bold: true, maxWidth: 180 * s);
    y += 40 * s;

    // ADDRESS
    _drawText(canvas, 'ADDRESS', Offset(labelL, y),
        fontSize: 15 * s, color: headerColor, bold: true);
    y += 20 * s;
    _drawText(canvas, _generateUsaAddress().toUpperCase(),
        Offset(labelL, y),
        fontSize: 18 * s, color: _textBlack, bold: true, maxWidth: fW);
    y += 24 * s;
    _drawText(canvas, 'MOFUVILLE, MF 90210',
        Offset(labelL, y),
        fontSize: 18 * s, color: _textBlack, bold: true, maxWidth: fW);
    y += 28 * s;

    // RESTRICTIONS + DONOR（横並び）
    _drawText(canvas, 'RESTRICTIONS', Offset(labelL, y),
        fontSize: 13 * s, color: headerColor, bold: true);
    _drawText(canvas, 'NONE', Offset(labelL + 114 * s, y - 1 * s),
        fontSize: 17 * s, color: _textBlack, bold: true, maxWidth: 130 * s);
    _drawText(canvas, 'DONOR', Offset(labelR, y),
        fontSize: 14 * s, color: headerColor, bold: true);
    _drawText(canvas, 'YES - UNLIMITED CUDDLES',
        Offset(valueR, y - 1 * s),
        fontSize: 15 * s, color: _textBlack, bold: true, maxWidth: 200 * s);

    // データフィールドとフッターの区切り線
    y += 28 * s;
    canvas.drawLine(
      Offset(fL, y),
      Offset(size.width - margin, y),
      Paint()
        ..color = headerColor.withValues(alpha: 0.15)
        ..strokeWidth = s,
    );

    // ── 5. フッター ──
    final footerY = size.height - 60 * s;

    // 肉球署名（左下）
    canvas.save();
    canvas.translate(margin + 25 * s, footerY + 4 * s);
    _drawPawPrint(canvas, 35 * s,
        Paint()..color = _textBlack.withValues(alpha: 0.6));
    canvas.restore();
    // ペット名サイン
    _drawText(canvas, petName, Offset(margin + 65 * s, footerY + 0 * s),
        fontSize: 14 * s, color: _textBlack, italic: true, maxWidth: 200 * s);
    // 署名ライン
    canvas.drawLine(
      Offset(margin + 55 * s, footerY + 22 * s),
      Offset(margin + 260 * s, footerY + 22 * s),
      Paint()
        ..color = _textGrey.withValues(alpha: 0.4)
        ..strokeWidth = s,
    );
    _drawText(canvas, 'SIGNATURE', Offset(margin + 157 * s, footerY + 25 * s),
        fontSize: 11 * s, color: _textGrey.withValues(alpha: 0.8),
        center: true, maxWidth: 200 * s);

    // License番号（中央下）
    _drawText(canvas, 'DL  $_licenseNumber',
        Offset(size.width / 2, footerY - 2 * s),
        fontSize: 18 * s, color: _textBlack, bold: true,
        center: true, maxWidth: 280 * s);

    // "VALID IN ALL 50 STATES OF MOFUMOFU"
    _drawText(canvas,
        'THIS LICENSE IS VALID IN ALL 50 STATES OF MOFUMOFU',
        Offset(size.width / 2, footerY + 38 * s),
        fontSize: 8 * s, color: _textGrey.withValues(alpha: 0.5),
        center: true, maxWidth: size.width - 100 * s);

    // 1Dバーコード（右下）
    _paintBarcode(canvas,
        Offset(size.width - margin - 210 * s, footerY - 2 * s),
        200 * s, 45 * s, s);

    // QRコード削除（パロディ免許に不要）

    // ── 6. ゴーストイメージ（写真の薄いコピー、ADDRESS付近の右下）──
    if (photoImage != null) {
      final ghostSize = 80 * s;
      final ghostRect = Rect.fromLTWH(
          size.width - margin - ghostSize - 10 * s,
          size.height - 180 * s,
          ghostSize, ghostSize * 1.2);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(
          ghostRect, Radius.circular(4 * s)));
      canvas.drawRect(ghostRect,
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.3));
      final imgW = photoImage!.width.toDouble();
      final imgH = photoImage!.height.toDouble();
      final imgAspect = imgW / imgH;
      final rectAspect = ghostRect.width / ghostRect.height;
      Rect srcRect;
      if (imgAspect > rectAspect) {
        final cropW = imgH * rectAspect;
        srcRect = Rect.fromLTWH((imgW - cropW) / 2, 0, cropW, imgH);
      } else {
        final cropH = imgW / rectAspect;
        srcRect = Rect.fromLTWH(0, (imgH - cropH) / 2, imgW, cropH);
      }
      canvas.drawImageRect(photoImage!, srcRect, ghostRect,
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.12));
      canvas.restore();
    }
  }

  /// 動物種別のヘッダー色（州ごとに色が違うDLのパロディ）
  Color _speciesHeaderColor() {
    if (species.contains('猫')) return const Color(0xFF2B5C8A); // ネイビーブルー
    if (species.contains('犬')) return const Color(0xFF3D7A4F); // フォレストグリーン
    if (species.contains('うさぎ')) return const Color(0xFF7B5EA7); // パープル
    if (species.contains('ハムスター')) return const Color(0xFFC17F24); // アンバー
    if (species.contains('鳥')) return const Color(0xFF2A8B8B); // ティール
    return const Color(0xFF5A6A8A); // スレートブルー
  }

  /// 動物種別のギョーシェ色
  Color _speciesGuillocheColor() {
    if (species.contains('猫')) return const Color(0xFF4A7FB5);
    if (species.contains('犬')) return const Color(0xFF5A9E6F);
    if (species.contains('うさぎ')) return const Color(0xFF9B7EC7);
    if (species.contains('ハムスター')) return const Color(0xFFD4A04A);
    if (species.contains('鳥')) return const Color(0xFF4AABAB);
    return const Color(0xFF7A8AAA);
  }

  /// CLASS 1文字（動物種別）
  String _speciesClassLetter() {
    if (species.contains('猫')) return 'C';
    if (species.contains('犬')) return 'D';
    if (species.contains('うさぎ')) return 'R';
    if (species.contains('ハムスター')) return 'H';
    if (species.contains('鳥')) return 'B';
    return 'P';
  }

  /// 海外テンプレート用の品種テキスト（品種名そのまま表示）
  String _usaBreedText() {
    if (breed != null && breed!.isNotEmpty && breed != '不明') {
      return breed!;
    }
    return _speciesEnglish();
  }

  /// 動物種の英語名（海外テンプレート用）
  String _speciesEnglish() {
    if (species.contains('猫')) return 'CAT';
    if (species.contains('犬')) return 'DOG';
    if (species.contains('うさぎ')) return 'RABBIT';
    if (species.contains('ハムスター')) return 'HAMSTER';
    if (species.contains('鳥')) return 'BIRD';
    return 'PET';
  }

  /// SEX フィールドのジョークテキスト
  String _speciesSexText() {
    if (species.contains('猫')) return 'ROYALTY';
    if (species.contains('犬')) {
      if (gender == '♂') return 'GOOD BOY';
      if (gender == '♀') return 'GOOD GIRL';
      return 'GOOD PET';
    }
    if (species.contains('うさぎ')) return 'FLUFFBALL';
    if (species.contains('ハムスター')) return 'TINY LEGEND';
    if (species.contains('鳥')) return 'FEATHERED';
    return 'ADORABLE';
  }

  /// EYES フィールドのジョークテキスト
  String _speciesEyesText() {
    if (species.contains('猫')) return 'MYSTERIOUS';
    if (species.contains('犬')) return 'ADORABLE';
    if (species.contains('うさぎ')) return 'ROUND';
    if (species.contains('ハムスター')) return 'SPARKLY';
    if (species.contains('鳥')) return 'SHARP';
    return 'CUTE';
  }

  /// HT フィールドのジョークテキスト
  String _speciesHeightText() {
    if (species.contains('猫')) return 'LOAF-SIZE';
    if (species.contains('犬')) return 'GOOD BOY';
    if (species.contains('うさぎ')) return 'SMOL';
    if (species.contains('ハムスター')) return 'TINY';
    if (species.contains('鳥')) return 'FLOOFY';
    return 'JUST RIGHT';
  }

  /// 肉球紋章（DLの州紋章パロディ）
  void _paintUsaCrest(Canvas canvas, Offset center, double radius, double s) {
    const white = Color(0xFFFFFFFF);

    // 1. 塗りつぶし白円（背景）
    canvas.drawCircle(center, radius, Paint()
      ..color = white.withValues(alpha: 0.25));

    // 2. 外円（太い白線）
    canvas.drawCircle(center, radius, Paint()
      ..color = white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s);

    // 3. 内円
    canvas.drawCircle(center, radius - 6 * s, Paint()
      ..color = white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s);

    // 4. 中央に肉球（白、大きくくっきり）
    canvas.save();
    canvas.translate(center.dx, center.dy);
    _drawPawPrint(canvas, radius * 1.2,
        Paint()..color = white.withValues(alpha: 0.9));
    canvas.restore();
  }

  /// 1Dバーコード描画（DL裏面風）
  void _paintBarcode(Canvas canvas, Offset topLeft,
      double width, double height, double s) {
    final rng = Random(petName.hashCode + species.hashCode + 42);
    final paint = Paint()..color = _textBlack.withValues(alpha: 0.8);
    var x = topLeft.dx;
    final endX = topLeft.dx + width;

    while (x < endX) {
      final barW = (1 + rng.nextInt(3)) * s;
      final gapW = (1 + rng.nextInt(2)) * s;
      if (rng.nextDouble() > 0.3) {
        canvas.drawRect(
          Rect.fromLTWH(x, topLeft.dy, barW, height),
          paint,
        );
      }
      x += barW + gapW;
    }
  }

  /// USA DL 背景（ギョーシェ模様 + ゴースト肉球 + マイクロプリント）
  void _paintUsaDlBackground(Canvas canvas, Size size, double s) {
    final innerRect =
        Rect.fromLTWH(8 * s, 8 * s, size.width - 16 * s, size.height - 16 * s);
    final innerRRect =
        RRect.fromRectAndRadius(innerRect, Radius.circular(14 * s));

    canvas.save();
    canvas.clipRRect(innerRRect);

    // 背景グラデーション（動物種別の色）
    final guillocheColor = _speciesGuillocheColor();
    final bgGradient = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.width, size.height),
        [
          guillocheColor.withValues(alpha: 0.10),
          const Color(0xFFFFFDF5),
          guillocheColor.withValues(alpha: 0.06),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(innerRect, bgGradient);

    // ギョーシェ模様（紙幣/パスポート風の精密曲線）
    _paintGuilloche(canvas, size, s);

    // ゴースト肉球（右側に大きく薄く）
    canvas.save();
    canvas.translate(size.width * 0.72, size.height * 0.55);
    _drawPawPrint(canvas, 200 * s,
        Paint()..color = guillocheColor.withValues(alpha: 0.07));
    canvas.restore();

    canvas.restore();
  }

  /// ギョーシェ模様（紙幣/パスポート風の精密幾何学曲線）
  void _paintGuilloche(Canvas canvas, Size size, double s) {
    final color = _speciesGuillocheColor();
    final paint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * s;

    // 水平方向の波線パターン（軽量化: 10行、ステップ4*s）
    for (var row = 0; row < 10; row++) {
      final baseY = size.height * (row / 10.0);
      final path = Path();
      path.moveTo(0, baseY);

      for (var x = 0.0; x < size.width; x += 4 * s) {
        final y1 = baseY + sin(x * 0.03 + row * 0.5) * 16 * s;
        final y2 = baseY + sin(x * 0.05 + row * 0.8) * 10 * s;
        path.lineTo(x, y1 + y2);
      }
      canvas.drawPath(path, paint);
    }

    // 同心円パターン（カード中央付近に薄く、軽量化: 間隔16）
    final cx = size.width * 0.55;
    final cy = size.height * 0.5;
    for (var r = 30.0; r < 250; r += 16) {
      canvas.drawCircle(
        Offset(cx, cy),
        r * s,
        Paint()
          ..color = color.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * s,
      );
    }
  }

  // ── ウォーターマーク・モチーフ描画 ──

  /// 肉球
  void _drawPawPrint(Canvas canvas, double sz, Paint paint) {
    final r = sz * 0.5;
    // メインパッド（楕円）
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.35), width: r * 1.0, height: r * 0.75),
      paint,
    );
    // 4つの指パッド
    // 外側2つ: メインパッドの横に寄せる
    // 内側2つ: メインパッドに近づける
    final toeR = r * 0.20;
    canvas.drawCircle(Offset(-r * 0.50, -r * 0.05), toeR, paint); // 左外
    canvas.drawCircle(Offset(-r * 0.20, -r * 0.30), toeR, paint); // 左内
    canvas.drawCircle(Offset(r * 0.20, -r * 0.30), toeR, paint);  // 右内
    canvas.drawCircle(Offset(r * 0.50, -r * 0.05), toeR, paint);  // 右外
  }

  // ===========================================================================
  // 共通描画メソッド
  // ===========================================================================

  /// 背景描画（角丸の外枠色＋内側クリーム色）
  void _paintBackground(Canvas canvas, Size size, double s) {
    final frameColor = FrameColor.findById(frameColorId);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(20 * s)),
      Paint()..color = frameColor.color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(4 * s, 4 * s, size.width - 8 * s, size.height - 8 * s),
          Radius.circular(18 * s)),
      Paint()..color = _bgCream,
    );
  }

  /// フレーム（外枠線）描画
  void _paintFrame(Canvas canvas, Size size, double s) {
    final frameColor = FrameColor.findById(frameColorId);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final radius = Radius.circular(20 * s);

    if (frameColor.id == 'holographic') {
      final gradient = ui.Gradient.sweep(
        Offset(size.width / 2, size.height / 2),
        [
          const Color(0xFF88DDFF),
          const Color(0xFFFF88DD),
          const Color(0xFFDDFF88),
          const Color(0xFF88DDFF),
        ],
        [0.0, 0.33, 0.66, 1.0],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..shader = gradient
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * s,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..color = frameColor.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * s,
      );
    }
  }

  /// 写真 + コスチューム合成描画
  /// [bgColor] 写真の透過部分に見せる背景色
  void _paintPhoto(Canvas canvas, Rect photoRect, double s,
      {Color bgColor = const Color(0xFFFFFFFF)}) {
    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(photoRect, Radius.circular(6 * s)));

    // 写真の背景色（テンプレートごとに異なる）
    canvas.drawRect(photoRect, Paint()..color = bgColor);

    if (photoImage != null) {
      final imgW = photoImage!.width.toDouble();
      final imgH = photoImage!.height.toDouble();
      final imgAspect = imgW / imgH;
      final rectAspect = photoRect.width / photoRect.height;

      Rect srcRect;
      if (imgAspect > rectAspect) {
        final cropW = imgH * rectAspect;
        srcRect = Rect.fromLTWH((imgW - cropW) / 2, 0, cropW, imgH);
      } else {
        final cropH = imgW / rectAspect;
        srcRect = Rect.fromLTWH(0, (imgH - cropH) / 2, imgW, cropH);
      }

      // photoScale/Offset を適用（canvas変換で自由スクロール+ズーム）
      canvas.save();
      canvas.clipRect(photoRect);
      canvas.translate(
        photoOffsetX * photoRect.width,
        photoOffsetY * photoRect.height,
      );
      if (photoScale != 1.0) {
        canvas.translate(photoRect.left + photoRect.width / 2,
            photoRect.top + photoRect.height / 2);
        canvas.scale(photoScale);
        canvas.translate(-(photoRect.left + photoRect.width / 2),
            -(photoRect.top + photoRect.height / 2));
      }
      canvas.drawImageRect(photoImage!, srcRect, photoRect, Paint());
      canvas.restore();
    } else {
      canvas.drawRect(photoRect, Paint()..color = const Color(0xFFFFFFFF));
      _drawText(
        canvas,
        '📷',
        Offset(photoRect.center.dx, photoRect.center.dy - 10 * s),
        fontSize: 30 * s,
        color: _textGrey,
        center: true,
        maxWidth: photoRect.width,
      );
    }

    // 顔ハメオーバーレイ（写真エリア下部に大きく表示）
    if (outfitId != null && outfitImage != null) {
      final costume = Costume.findById(outfitId!);
      final oImgW = outfitImage!.width.toDouble();
      final oImgH = outfitImage!.height.toDouble();
      final cropRatio = switch (costume.id) {
        'sailor' => 0.90,
        'gakuran' => 0.90,
        _ => 0.50,
      };
      final srcRect = Rect.fromLTWH(0, 0, oImgW, oImgH * cropRatio);
      final srcAspect = srcRect.width / srcRect.height;
      // コスチュームごとの描画倍率
      final drawWidth = photoRect.width * costume.defaultScale;
      final drawHeight = drawWidth / srcAspect;
      // 海外テンプレ(280x400)は日本(290x372)より縦長 → 衣装位置を補正
      final isOverseas = photoRect.height / photoRect.width > 1.35;
      final heightScale = isOverseas ? (400.0 / 372.0) : 1.0;
      // コスチュームごとの縦位置調整（大きいほど上に表示）
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
      // コスチュームごとの横オフセット（正=右、負=左）
      final horizontalShift = switch (costume.id) {
        'pirate' => 0.0,
        'sailor' => photoRect.width * 0.002,
        'gakuran' => photoRect.width * 0.005,
        'kimono' => photoRect.width * 0.02,
        'police' => photoRect.width * 0.01,
        _ => 0.0,
      };
      final drawLeft = photoRect.left + (photoRect.width - drawWidth) / 2 + horizontalShift;
      final drawTop = photoRect.bottom - drawHeight * verticalRatio * heightScale;
      final fitRect = Rect.fromLTWH(drawLeft, drawTop, drawWidth, drawHeight);
      canvas.save();
      canvas.clipRect(photoRect);
      canvas.drawImageRect(outfitImage!, srcRect, fitRect, Paint());
      canvas.restore();
    }

    canvas.restore();

    // コスチュームオーバーレイ（最終合成用）
    // 編集画面では Flutter Widget として描画するため、ここは空になる
    // LicenseComposer 経由の最終レンダリング時に costumeOverlays が渡される

  }

  /// 全コスチュームオーバーレイを描画（最終合成用）
  void _paintCostumeOverlays(Canvas canvas, Size size) {
    final s = size.width / _refW;
    // 写真エリアの比率（座標変換用）
    final pr = template.photoRectRatio;
    final photoRect = Rect.fromLTWH(
      pr.left * size.width, pr.top * size.height,
      pr.width * size.width, pr.height * size.height,
    );
    final photoW = photoRect.width;

    // 写真エリア内に制限（photoScale/Offsetは適用しない：
    // エディタでWidgetとして配置した座標がそのまま写真エリア内の位置を表すため、
    // Canvas変換を適用すると二重変換でズレる）
    canvas.save();
    canvas.clipRect(photoRect);

    for (final overlay in costumeOverlays) {
      final costume = Costume.findById(overlay.costumeId);
      final costumeImg = costumeImages[overlay.costumeId];

      if (costumeImg != null) {
        // 実画像を描画（アスペクト比を維持）
        final imgW = costumeImg.width.toDouble();
        final imgH = costumeImg.height.toDouble();
        final aspect = imgW / imgH;

        // サイズ: 写真エリア基準
        final baseW = photoW * costume.defaultScale * overlay.scale;
        final baseH = baseW / aspect;
        // 位置: 写真ローカル座標→カード座標に変換
        final cx = (pr.left + overlay.cx * pr.width) * size.width;
        final cy = (pr.top + overlay.cy * pr.height) * size.height;

        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(overlay.rotation);
        final src = Rect.fromLTWH(0, 0, imgW, imgH);
        final dst = Rect.fromLTWH(-baseW / 2, -baseH / 2, baseW, baseH);
        canvas.drawImageRect(costumeImg, src, dst, Paint());
        canvas.restore();
      } else {
        // アセット未ロード時はプレースホルダ
        final baseW = photoW * costume.defaultScale * overlay.scale;
        final baseH = baseW;
        final cx = (pr.left + overlay.cx * pr.width) * size.width;
        final cy = (pr.top + overlay.cy * pr.height) * size.height;

        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(overlay.rotation);
        final rect = Rect.fromLTWH(-baseW / 2, -baseH / 2, baseW, baseH);

        final color = _overlayPlaceholderColor(costume.type);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(4 * s)),
          Paint()..color = color.withValues(alpha: 0.3),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(4 * s)),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * s,
        );
        _drawText(
          canvas,
          costume.name,
          Offset(0, -8 * s),
          fontSize: 12 * s,
          color: color,
          center: true,
          maxWidth: baseW,
        );
        canvas.restore();
      }
    }
    canvas.restore(); // 写真スケール/オフセット変換を解除
  }

  /// コスチュームタイプ別のプレースホルダ色
  static Color _overlayPlaceholderColor(CostumeType type) {
    switch (type) {
      case CostumeType.accessory:
        return const Color(0xFF2196F3); // blue
      case CostumeType.stamp:
        return const Color(0xFFE91E63); // pink
      case CostumeType.outfit:
        return const Color(0xFF4CAF50); // green
    }
  }

  /// 朱印スタンプ描画（印鑑風）
  void _paintSeal(Canvas canvas, Offset center, double radius) {
    final sealColor = _sealRed.withValues(alpha: 0.9);
    final double side = radius * 2;
    final rect = Rect.fromCenter(center: center, width: side, height: side);

    // 外枠（四角）
    canvas.drawRect(
      rect,
      Paint()
        ..color = sealColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.14,
    );
    // 内枠（四角）
    final innerRect = Rect.fromCenter(center: center, width: side * 0.78, height: side * 0.78);
    canvas.drawRect(
      innerRect,
      Paint()
        ..color = sealColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.05,
    );
    // 中央にカタカナ「ウチノ子」縦書き2列（右→左）
    final double sc = radius / 30; // スケール係数
    final double fontSize = radius * 0.72;
    final double colSpacing = fontSize * 1.15;
    final double topY = center.dy - fontSize * 0.9 - 9 * sc;
    final double shiftX = -5 * sc;
    // 右列「ウチ」
    _paintVerticalText(canvas, 'ウチ',
        Offset(center.dx + colSpacing * 0.25 + shiftX, topY),
        fontSize, sealColor, spacing: 1.1);
    // 左列「ノ子」
    _paintVerticalText(canvas, 'ノ子',
        Offset(center.dx - colSpacing * 0.75 + shiftX, topY),
        fontSize, sealColor, spacing: 1.1);
  }

  /// 縦書きテキスト描画
  void _paintVerticalText(Canvas canvas, String text, Offset start,
      double fontSize, Color color, {double spacing = 1.2}) {
    var y = start.dy;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      _drawText(
        canvas,
        char,
        Offset(start.dx, y),
        fontSize: fontSize,
        color: color,
        bold: true,
        center: true,
        maxWidth: fontSize * 2,
      );
      y += fontSize * spacing;
    }
  }




  // ===========================================================================
  // テキスト描画ユーティリティ
  // ===========================================================================

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 14,
    Color color = const Color(0xFF333333),
    bool bold = false,
    bool italic = false,
    bool center = false,
    double maxWidth = 500,
    double letterSpacing = 0,
  }) {
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: center ? TextAlign.center : TextAlign.left,
      maxLines: 2,
      ellipsis: '...',
    );
    final textStyle = ui.TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: letterSpacing > 0 ? letterSpacing : null,
    );

    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));

    if (center) {
      final dx = offset.dx - paragraph.maxIntrinsicWidth / 2;
      canvas.drawParagraph(paragraph, Offset(dx, offset.dy));
    } else {
      canvas.drawParagraph(paragraph, offset);
    }
  }

  /// 生年月日を漢字=通常/数字=太字の混合スタイルで中央描画
  ///
  /// [justify] が true の場合、各文字を等間隔に配置（均等配置）する。
  void _drawBirthMixed(
    Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 34,
    double maxWidth = 500,
    double letterSpacing = 0,
    bool justify = false,
  }) {
    final kanjiPattern = RegExp(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]');

    // 均等配置: 各文字を個別に描画して等間隔に配置
    if (justify) {
      final charParagraphs = <ui.Paragraph>[];
      final charWidths = <double>[];

      for (int i = 0; i < text.length; i++) {
        final ch = text[i];
        final isBold = birthDateUnknown || birthDate == null || !kanjiPattern.hasMatch(ch);
        final style = ui.TextStyle(
            color: _textBlack,
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal);
        final b = ui.ParagraphBuilder(ui.ParagraphStyle())
          ..pushStyle(style)
          ..addText(ch);
        final p = b.build();
        p.layout(const ui.ParagraphConstraints(width: double.infinity));
        charParagraphs.add(p);
        charWidths.add(p.maxIntrinsicWidth);
      }

      final n = text.length;
      final totalCharW = charWidths.fold(0.0, (s, w) => s + w);
      final gap = n > 1 ? (maxWidth - totalCharW) / (n - 1) : 0.0;
      final totalW = totalCharW + gap * (n - 1);
      double x = offset.dx - totalW / 2;

      for (int i = 0; i < n; i++) {
        canvas.drawParagraph(charParagraphs[i], Offset(x, offset.dy));
        x += charWidths[i] + gap;
      }
      return;
    }

    // 通常描画: ParagraphBuilderで混合スタイル
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      maxLines: 1,
    );
    final boldStyle = ui.TextStyle(
      color: _textBlack,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      letterSpacing: letterSpacing > 0 ? letterSpacing : null,
    );
    final normalStyle = ui.TextStyle(
      color: _textBlack,
      fontSize: fontSize,
      fontWeight: FontWeight.normal,
      letterSpacing: letterSpacing > 0 ? letterSpacing : null,
    );

    final builder = ui.ParagraphBuilder(paragraphStyle);
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (kanjiPattern.hasMatch(ch)) {
        builder.pushStyle(normalStyle);
      } else {
        builder.pushStyle(boldStyle);
      }
      builder.addText(ch);
      builder.pop();
    }

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    final dx = offset.dx - paragraph.maxIntrinsicWidth / 2;
    canvas.drawParagraph(paragraph, Offset(dx, offset.dy));
  }

  // ===========================================================================
  // データ生成ヘルパー
  // ===========================================================================

  /// 免許番号を生成（12桁連続数字）
  String _generateLicenseNumber() {
    final rng = Random(petName.hashCode + species.hashCode);
    String fourDigits() => rng.nextInt(10000).toString().padLeft(4, '0');
    return '${fourDigits()}${fourDigits()}${fourDigits()}';
  }

  /// 住所を1行で生成（動物種ごとに10パターンからランダム選択）
  String _generateJapanAddressSingle() {
    // 自由入力住所があれば全種別で優先
    if (customAddress != null && customAddress!.isNotEmpty) {
      return customAddress!;
    }

    final rng = Random(petName.hashCode + 42);
    List<String> addresses;
    if (species.contains('猫')) {
      addresses = const [
        '北海道しゃけ市いくら町1-3',
        '東京都こたつ区みかん丁目2-8',
        '大阪府かつお市たたき町3-5',
        '愛知県ちゅーる市おかわり町4-2',
        '福岡県にくきゅう市どや顔町5-89',
        '京都府まぐろ市おさしみ町6-1',
        '宮城県つきあかり市おさかな横丁1-9',
        '静岡県だんぼーる市すっぽり町8-4',
        '沖縄県ひなた市まどべ町9-6',
        '広島県ごろごろ市ひざうえ町1-5',
      ];
    } else if (species.contains('犬')) {
      addresses = const [
        '東京都おさんぽ区しっぽ丁目1-8',
        '北海道ジャーキー市おやつ町2-3',
        '大阪府ボール市もってこい町3-6',
        '愛知県くんくん市たんけん町4-7',
        '福岡県おて市おすわり町5-1',
        '京都府なでなで市おなか町6-9',
        '大阪府ボール市ぜったい取る町3-16',
        '静岡県ほねっこ市かみかみ町8-5',
        '沖縄県みずあそび市どろんこ町9-4',
      ];
    } else if (species.contains('うさぎ')) {
      addresses = const [
        '北海道にんじん市まるかじり町3-8',
        '東京都ぴょんぴょん区おはな丁目1-4',
        '大阪府もぐもぐ市はっぱ町5-22',
        '山形県こはる市草むら町3-8',
        '京都府うさんぽ市しろつめ町2-9',
        '福岡県もふもふ市たれみみ町4-1',
        '広島県ほっぺ市ぷくぷく町1-12',
        '静岡県ごろん市へそ天町8-7',
        '秋田県しろみみ市月見町1-6',
        '広島県なでなで市ほっぺ町1-2',
      ];
    } else if (species.contains('ハムスター')) {
      addresses = const [
        '北海道ひまわり市たね町1-1',
        '新潟県ほおぶく市秘密基地2-6',
        '大阪府ほっぺ市ぱんぱん町5-7',
        '愛知県もぐもぐ市かくし町2-6',
        '香川県たねっこ市倉庫裏5-3',
        '北海道ひまわり市たね泥棒町1-11',
        '神奈川県かりかり市ペレット町6-2',
        '山口県くるり市木箱前6-8',
        '沖縄県てちてち市おてて町9-8',
      ];
    } else if (species.contains('鳥')) {
      addresses = const [
        '北海道さえずり市おうた町2-5',
        '東京都おそら区ひこうき丁目4-8',
        '千葉県あおぞら市風待ち町1-5',
        '愛媛県さえずり市朝ひかり町3-3',
        '京都府ちゅんちゅん市とまり木町3-9',
        '福岡県ぴよぴよ市たまご町5-4',
        '神奈川県くちばし市つんつん町8-1',
        '静岡県ふわり市おひさま町6-7',
        '沖縄県ぱたぱた市あおぞら町9-2',
        '広島県おしゃべり市かがみ町4-5',
      ];
    } else {
      return 'もふもふ都ふわふわ市なかよし町1-1';
    }
    return addresses[rng.nextInt(addresses.length)];
  }

  /// 条件テキスト2行を生成（特技選択に連動）
  List<String> _generateConditions() {
    // 1行目: 特技連動の条件テキスト
    String line1;
    if (specialtyId == 'custom' && customCondition != null && customCondition!.isNotEmpty) {
      // 自由記述（○○ + 固定suffix）
      line1 = '${customCondition!}運転しないこと';
    } else if (specialtyId != null && specialtyId != 'custom') {
      // 選択肢から条件テキストを取得
      final options = SpecialtyOption.forSpecies(species);
      final match = options.where((o) => o.id == specialtyId);
      line1 = match.isNotEmpty ? match.first.conditionText : _defaultConditionLine1();
    } else {
      line1 = _defaultConditionLine1();
    }

    // 2行目: 動物種ごとのランダム固定
    final line2 = _defaultConditionLine2();
    return [line1, line2];
  }

  String _defaultConditionLine1() {
    if (species.contains('猫')) return '魚のアプリをダウンロードしない事';
    if (species.contains('犬')) return 'シッポでハンドルを握らない事';
    if (species.contains('うさぎ')) return 'コードをかじらない事';
    if (species.contains('ハムスター')) return '回し車から飛び出さない事';
    if (species.contains('鳥')) return '室内飛行時は窓に注意する事';
    return 'おやつをおねだりしすぎない事';
  }

  String _defaultConditionLine2() {
    if (species.contains('猫')) return 'マタタビを吸って運転しない事';
    if (species.contains('犬')) return 'リードを引っ張らない事';
    if (species.contains('うさぎ')) return 'にんじんを食べながら運転しない事';
    if (species.contains('ハムスター')) return 'ほっぺに物を詰めすぎない事';
    if (species.contains('鳥')) return '歌いながら運転しない事';
    return 'ご主人様の言うことを聞く事';
  }

  /// ペットの免許カテゴリを返す
  List<String> _getPetCategories() {
    if (species.contains('猫')) {
      return ['段ボール', 'ルンバ', '肩乗り', 'スケボー', '紙袋', 'キャリー', 'こたつ'];
    }
    if (species.contains('犬')) {
      return ['カート', '自転車', '抱っこ', 'ドライブ', 'ソリ', 'バギー', '散歩'];
    }
    // TODO: 他の動物パターンを追加
    return ['段ボール', 'ルンバ', '肩乗り', 'スケボー', '紙袋', 'キャリー', 'こたつ'];
  }

  /// 生年月日を和暦でフォーマット（スペースパディング + 「生」サフィックス）
  ///
  /// 例: "平成26年 2月 4日生"
  String _formatBirthDateWarekiNoPad() {
    if (birthDateUnknown) return 'ひ・み・つ';
    if (birthDate == null) return 'ひ・み・つ';
    final y = birthDate!.year;
    String era;
    int eraYear;
    if (y >= 2019) {
      era = '令和';
      eraYear = y - 2018;
    } else if (y >= 1989) {
      era = '平成';
      eraYear = y - 1988;
    } else {
      era = '昭和';
      eraYear = y - 1925;
    }
    final eraYearStr = eraYear.toString().padLeft(2, ' ');
    final monthStr = birthDate!.month.toString().padLeft(2, ' ');
    final dayStr = birthDate!.day.toString().padLeft(2, ' ');
    return '$era$eraYearStr年$monthStr月$dayStr日生';
  }

  /// 免許証番号を「第XXXXXXXXXXXX号」形式で描画
  ///
  /// 中央4桁（g2）の背景に赤い斜線を描画する
  void _paintLicenseNumber(
      Canvas canvas, double s, double x, double y, double maxW) {
    // 12桁の番号を3グループに分割
    final g1 = _licenseNumber.substring(0, 4);
    final g2 = _licenseNumber.substring(4, 8);
    final g3 = _licenseNumber.substring(8, 12);

    final double kanjiSize = 31 * s;
    final double numSize = 40 * s;

    // 単一スタイルでテキスト幅を計測するヘルパー
    double measure(String text, double fontSize) {
      final ps = ui.ParagraphStyle(textAlign: TextAlign.left);
      final ts = ui.TextStyle(
          color: _textBlack, fontSize: fontSize, fontWeight: FontWeight.bold);
      final b = ui.ParagraphBuilder(ps)..pushStyle(ts)..addText(text);
      final p = b.build();
      p.layout(ui.ParagraphConstraints(width: maxW));
      return p.maxIntrinsicWidth;
    }

    // 赤斜線の位置計算（「第  」+ g1 の後から g2 の幅分）
    final prefixW = measure('第   ', kanjiSize);
    final g1W = measure(g1, numSize);
    final g2W = measure(g2, numSize);
    final g2Rect = Rect.fromLTWH(x + prefixW + g1W, y, g2W, numSize * 1.3);
    _paintRedDiagonalLines(canvas, g2Rect, s);

    // 混合スタイルで描画（第・号=32*s, 数字=40*s）
    final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.left, maxLines: 1);
    final kanjiStyle = ui.TextStyle(
        color: _textBlack, fontSize: kanjiSize, fontWeight: FontWeight.bold);
    final numStyle = ui.TextStyle(
        color: _textBlack, fontSize: numSize, fontWeight: FontWeight.bold);
    final builder = ui.ParagraphBuilder(paragraphStyle);
    builder.pushStyle(kanjiStyle);
    builder.addText('第   ');
    builder.pop();
    builder.pushStyle(numStyle);
    builder.addText('$g1$g2$g3');
    builder.pop();
    builder.pushStyle(kanjiStyle);
    builder.addText('号');
    builder.pop();
    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxW));
    canvas.drawParagraph(paragraph, Offset(x, y));
  }

  /// 赤い斜線パターンを描画（指定された矩形内）
  ///
  /// canvas.save / clipRect / restore で矩形にクリップし、
  /// 左下→右上方向の斜線を等間隔で描画する
  void _paintRedDiagonalLines(Canvas canvas, Rect rect, double s) {
    canvas.save();
    canvas.clipRect(rect);

    final paint = Paint()
      ..color = const Color(0xFFE57373).withValues(alpha: 0.4)
      ..strokeWidth = 1.5 * s;

    final spacing = 6 * s;
    final totalLen = rect.width + rect.height;
    for (double d = 0; d < totalLen; d += spacing) {
      // 左下→右上の斜線
      final x0 = rect.left + d;
      final y0 = rect.bottom;
      final x1 = rect.left + d - rect.height;
      final y1 = rect.top;
      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), paint);
    }

    canvas.restore();
  }

  /// USA風住所を生成
  String _generateUsaAddress() {
    final rng = Random(petName.hashCode);
    final streets = [
      'Wag Street',
      'Purr Avenue',
      'Fluffy Lane',
      'Biscuit Blvd',
      'Snuggle Road',
    ];
    return '${rng.nextInt(999) + 1} ${streets[rng.nextInt(streets.length)]}';
  }

  /// 生年月日フォーマット（USA用: MM/DD/YYYY）
  String _formatBirthDateUsa() {
    if (birthDateUnknown) return "It's a secret!";
    if (birthDate == null) return "It's a secret!";
    return '${birthDate!.month.toString().padLeft(2, '0')}/'
        '${birthDate!.day.toString().padLeft(2, '0')}/'
        '${birthDate!.year}';
  }
}
