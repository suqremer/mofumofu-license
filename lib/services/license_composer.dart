import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/license_template.dart';
import '../models/costume.dart';
import '../models/costume_overlay.dart';
import '../models/license_card.dart';
import 'license_painter.dart';

/// 免許証画像合成のリクエストパラメータ
///
/// LicenseCard から生成しやすい構造になっている。
/// [LicenseComposeRequest.fromCard] ファクトリで簡単に変換可能。
class LicenseComposeRequest {
  /// ペット名（免許証に印字）
  final String petName;

  /// 動物種（犬, 猫, うさぎ 等）
  final String species;

  /// 品種（任意）
  final String? breed;

  /// 生年月日（任意）
  final DateTime? birthDate;

  /// 生年月日不明フラグ
  final bool birthDateUnknown;

  /// 性別（任意）
  final String? gender;

  /// 特技（任意）
  final String? specialty;

  /// 特技ID（SpecialtyOption.id に対応）
  final String? specialtyId;

  /// カスタム条件テキスト（自由記述時）
  final String? customCondition;

  /// カスタム住所（その他の動物用、任意）
  final String? customAddress;

  /// 免許種別ID（LicenseType.id に対応）
  final String licenseType;

  /// トリミング済みペット写真のバイトデータ
  final Uint8List photoBytes;

  /// コスチュームID（Costume.id に対応）
  final String costumeId;

  /// フレーム色ID（FrameColor.id に対応）
  final String frameColor;

  /// テンプレートタイプ（'japan' or 'usa'）
  final String templateType;

  /// 有効期限テキストID（ValidityOption.id に対応）
  final String validityId;

  /// コスチュームオーバーレイ（配置済みコスチュームのリスト）
  final List<CostumeOverlay> costumeOverlays;

  /// 写真の拡大率（1.0 = デフォルト）
  final double photoScale;

  /// 写真の水平オフセット（-0.5〜0.5）
  final double photoOffsetX;

  /// 写真の垂直オフセット（-0.5〜0.5）
  final double photoOffsetY;

  /// 写真の回転（ラジアン）
  final double photoRotation;

  /// 顔ハメコスチュームID（任意）
  final String? outfitId;

  /// 証明写真の背景色（intでColor.value）
  final int? photoBgColor;

  /// 写真の明るさ調整（-1.0〜1.0、0.0=変更なし）
  final double photoBrightness;

  /// 写真のコントラスト調整（-1.0〜1.0、0.0=変更なし）
  final double photoContrast;

  /// 写真の彩度調整（-1.0〜1.0、0.0=変更なし）
  final double photoSaturation;

  const LicenseComposeRequest({
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
    required this.licenseType,
    required this.photoBytes,
    this.costumeId = 'gakuran',
    this.frameColor = 'black',
    this.templateType = 'japan',
    this.validityId = 'nap',
    this.costumeOverlays = const [],
    this.photoScale = 1.0,
    this.photoOffsetX = 0.0,
    this.photoOffsetY = 0.0,
    this.photoRotation = 0.0,
    this.outfitId,
    this.photoBgColor,
    this.photoBrightness = 0.0,
    this.photoContrast = 0.0,
    this.photoSaturation = 0.0,
  });

  /// LicenseCard + 写真バイトデータからリクエストを生成
  ///
  /// DB に保存済みの LicenseCard と、別途読み込んだ写真データを
  /// 合成リクエストに変換するユーティリティ。
  factory LicenseComposeRequest.fromCard(
    LicenseCard card,
    Uint8List photoBytes,
  ) {
    final extra = card.extraData ?? {};
    final overlayMaps = extra['costumeOverlays'] as List<dynamic>?;
    final overlays = overlayMaps != null
        ? overlayMaps
            .map((m) => CostumeOverlay.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList()
        : <CostumeOverlay>[];

    return LicenseComposeRequest(
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
      validityId: extra['validityId'] as String? ?? 'nap',
      costumeOverlays: overlays,
      photoScale: (extra['photoScale'] as num?)?.toDouble() ?? 1.0,
      photoOffsetX: (extra['photoOffsetX'] as num?)?.toDouble() ?? 0.0,
      photoOffsetY: (extra['photoOffsetY'] as num?)?.toDouble() ?? 0.0,
      photoRotation: (extra['photoRotation'] as num?)?.toDouble() ?? 0.0,
      outfitId: extra['outfitId'] as String?,
      photoBgColor: extra['photoBgColor'] as int?,
      photoBrightness: (extra['photoBrightness'] as num?)?.toDouble() ?? 0.0,
      photoContrast: (extra['photoContrast'] as num?)?.toDouble() ?? 0.0,
      photoSaturation: (extra['photoSaturation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// 免許証画像合成サービス
///
/// [LicenseComposeRequest] を受け取り、Canvas API で免許証画像を生成する。
/// 内部で [LicensePainter] を使ってレイアウトを描画し、
/// PNG バイトデータとして返す。
///
/// 使い方:
/// ```dart
/// final composer = LicenseComposer();
/// final imageBytes = await composer.compose(request);
/// final filePath = await composer.saveToFile(imageBytes);
/// ```
class LicenseComposer {
  /// 免許証画像を合成して PNG バイトデータを返す
  ///
  /// [request] に含まれる写真・コスチューム・テンプレート情報をもとに
  /// 完成した免許証画像を生成する。
  ///
  /// 処理の流れ:
  /// 1. テンプレート設定を解決
  /// 2. 写真バイトデータを ui.Image にデコード
  /// 3. コスチュームアセットを ui.Image にロード
  /// 4. LicensePainter で Canvas に描画
  /// 5. Canvas の内容を PNG エンコードして返す
  /// [scale] を指定すると出力解像度が倍率分アップする。
  /// - 1.0（デフォルト）: 1024×646 — 画面表示・SNSシェア用
  /// - 2.0: 2048×1292 — PVCカード印刷用（350dpi超）
  Future<Uint8List> compose(
    LicenseComposeRequest request, {
    double scale = 2.0,
  }) async {
    // テンプレート設定を取得
    final template = LicenseTemplate.fromId(request.templateType);
    final licenseType = LicenseType.findById(request.licenseType);

    // 写真バイトデータを ui.Image にデコード
    final ui.Image photoImage = await _decodeImage(request.photoBytes);

    // コスチューム画像をロード
    final costumeImages = await _loadCostumeImages(request.costumeOverlays);

    // 顔ハメ画像をロード
    ui.Image? outfitImage;
    if (request.outfitId != null) {
      final costume = Costume.findById(request.outfitId!);
      try {
        final data = await rootBundle.load(costume.assetPath);
        outfitImage = await _decodeImage(data.buffer.asUint8List());
      } catch (_) {
        // アセットが見つからない場合はスキップ
      }
    }

    // 出力サイズを scale 倍に拡大
    final outputWidth = (template.outputSize.width * scale).toInt();
    final outputHeight = (template.outputSize.height * scale).toInt();

    // PictureRecorder + Canvas で描画を実行
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
    );

    // Canvas 全体をスケーリング（ベクター描画がそのまま高解像度化）
    if (scale != 1.0) {
      canvas.scale(scale, scale);
    }

    // 有効期限テキストをテンプレートタイプに応じて解決
    final validityOption = ValidityOption.findById(request.validityId);
    final validityText = validityOption.textForTemplate(template.type);

    final photoColorFilter = LicensePainter.buildPhotoColorFilter(
      brightness: request.photoBrightness,
      contrast: request.photoContrast,
      saturation: request.photoSaturation,
    );

    // USA テンプレートのゴーストイメージ用に合成済み写真を生成
    ui.Image? composedPhoto;
    if (template.type == TemplateType.usa) {
      final composedBytes = await composePhotoPreview(request, scale: 1.0);
      composedPhoto = await _decodeImage(composedBytes);
    }

    final painter = LicensePainter(
      template: template,
      frameColorId: request.frameColor,
      photoImage: photoImage,
      costumeOverlays: request.costumeOverlays,
      costumeImages: costumeImages,
      photoScale: request.photoScale,
      photoOffsetX: request.photoOffsetX,
      photoOffsetY: request.photoOffsetY,
      photoRotation: request.photoRotation,
      outfitId: request.outfitId,
      outfitImage: outfitImage,
      photoBgColor: request.photoBgColor != null
          ? Color(request.photoBgColor!)
          : const Color(0xFFFFFFFF),
      photoColorFilter: photoColorFilter,
      composedPhotoImage: composedPhoto,
      petName: request.petName,
      species: request.species,
      breed: request.breed,
      birthDate: request.birthDate,
      birthDateUnknown: request.birthDateUnknown,
      gender: request.gender,
      specialty: request.specialty,
      specialtyId: request.specialtyId,
      customCondition: request.customCondition,
      customAddress: request.customAddress,
      licenseTypeLabel: licenseType.label,
      validityText: validityText,
    );

    // LicensePainter は元の outputSize でレイアウト計算（canvas.scale が拡大を担当）
    painter.paint(canvas, template.outputSize);

    final picture = recorder.endRecording();
    final image = await picture.toImage(outputWidth, outputHeight);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 印刷用の高解像度画像（2048×1292）を合成して PNG バイトデータを返す
  Future<Uint8List> composeHighRes(LicenseComposeRequest request) {
    return compose(request, scale: 2.0);
  }

  /// 写真エリアだけ（写真+顔ハメ+コスチューム、フレーム/テキストなし）を合成
  ///
  /// ホーム画面のプレビュー用。テキストやフレームが重ならないクリーンな写真。
  /// [scale] で出力解像度を倍率指定（タグ用高解像度出力など）。
  Future<Uint8List> composePhotoPreview(
    LicenseComposeRequest request, {
    double scale = 1.0,
  }) async {
    final template = LicenseTemplate.fromId(request.templateType);
    final pr = template.photoRectRatio;
    // 出力サイズ = 写真エリアのピクセルサイズ × scale
    final baseW = template.outputSize.width * pr.width;
    final baseH = template.outputSize.height * pr.height;
    final outW = (baseW * scale).toInt();
    final outH = (baseH * scale).toInt();

    final ui.Image photoImage = await _decodeImage(request.photoBytes);
    final costumeImages = await _loadCostumeImages(request.costumeOverlays);

    // 顔ハメ画像をロード
    ui.Image? outfitImage;
    if (request.outfitId != null) {
      final costume = Costume.findById(request.outfitId!);
      try {
        final data = await rootBundle.load(costume.assetPath);
        outfitImage = await _decodeImage(data.buffer.asUint8List());
      } catch (_) {}
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
    );

    // scale倍率でCanvas全体をスケーリング（レイアウト計算はbase座標系で行う）
    if (scale != 1.0) {
      canvas.scale(scale, scale);
    }

    final photoRect = Rect.fromLTWH(0, 0, baseW, baseH);

    // 背景色
    final bgColor = request.photoBgColor != null
        ? Color(request.photoBgColor!)
        : const Color(0xFFFFFFFF);
    canvas.drawRect(photoRect, Paint()..color = bgColor);

    // 写真を描画
    {
      final imgW = photoImage.width.toDouble();
      final imgH = photoImage.height.toDouble();
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

      canvas.save();
      canvas.clipRect(photoRect);
      canvas.translate(
        request.photoOffsetX * photoRect.width,
        request.photoOffsetY * photoRect.height,
      );
      if (request.photoRotation != 0.0) {
        canvas.translate(
            photoRect.width / 2, photoRect.height / 2);
        canvas.rotate(request.photoRotation);
        canvas.translate(
            -photoRect.width / 2, -photoRect.height / 2);
      }
      if (request.photoScale != 1.0) {
        canvas.translate(
            photoRect.width / 2, photoRect.height / 2);
        canvas.scale(request.photoScale);
        canvas.translate(
            -photoRect.width / 2, -photoRect.height / 2);
      }
      final photoPaint = Paint();
      final pFilter = LicensePainter.buildPhotoColorFilter(
        brightness: request.photoBrightness,
        contrast: request.photoContrast,
        saturation: request.photoSaturation,
      );
      if (pFilter != null) photoPaint.colorFilter = pFilter;
      canvas.drawImageRect(photoImage, srcRect, photoRect, photoPaint);
      canvas.restore();
    }

    // 顔ハメ描画
    if (request.outfitId != null && outfitImage != null) {
      final costume = Costume.findById(request.outfitId!);
      final oImgW = outfitImage.width.toDouble();
      final oImgH = outfitImage.height.toDouble();
      final cropRatio = switch (costume.id) {
        'sailor' => 0.90,
        'gakuran' => 0.90,
        _ => 0.50,
      };
      final srcRect = Rect.fromLTWH(0, 0, oImgW, oImgH * cropRatio);
      final srcAspect = srcRect.width / srcRect.height;
      final drawWidth = photoRect.width * costume.defaultScale;
      final drawHeight = drawWidth / srcAspect;
      final isOverseas = photoRect.height / photoRect.width > 1.35;
      final heightScale = isOverseas ? (400.0 / 372.0) : 1.0;
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
        'sailor' => photoRect.width * 0.002,
        'gakuran' => photoRect.width * 0.005,
        'kimono' => photoRect.width * 0.02,
        'police' => photoRect.width * 0.01,
        _ => 0.0,
      };
      final drawLeft =
          (photoRect.width - drawWidth) / 2 + horizontalShift;
      final drawTop =
          photoRect.height - drawHeight * verticalRatio * heightScale;
      final fitRect =
          Rect.fromLTWH(drawLeft, drawTop, drawWidth, drawHeight);
      canvas.save();
      canvas.clipRect(photoRect);
      canvas.drawImageRect(outfitImage, srcRect, fitRect, Paint());
      canvas.restore();
    }

    // コスチュームオーバーレイ（写真エリア内に制限、photoScale/Offsetは適用しない：
    // エディタでWidgetとして配置した座標がそのまま位置を表すため）
    canvas.save();
    canvas.clipRect(photoRect);
    for (final overlay in request.costumeOverlays) {
      final costume = Costume.findById(overlay.costumeId);
      final costumeImg = costumeImages[overlay.costumeId];
      if (costumeImg == null) continue;

      final cImgW = costumeImg.width.toDouble();
      final cImgH = costumeImg.height.toDouble();
      final aspect = cImgW / cImgH;
      // エディタと同じ正方形ベース（BoxFit.contain相当）
      final baseW =
          photoRect.width * costume.defaultScale * overlay.scale;
      final baseH = baseW;
      // contain: 正方形内にアスペクト比を維持して収める
      double drawW, drawH;
      if (aspect >= 1) {
        drawW = baseW;
        drawH = baseW / aspect;
      } else {
        drawH = baseH;
        drawW = baseH * aspect;
      }
      // overlay.cx/cy は写真エリア内の比率座標
      final cx = overlay.cx * photoRect.width;
      final cy = overlay.cy * photoRect.height;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(overlay.rotation);
      final src = Rect.fromLTWH(0, 0, cImgW, cImgH);
      final dst = Rect.fromLTWH(-drawW / 2, -drawH / 2, drawW, drawH);
      canvas.drawImageRect(costumeImg, src, dst, Paint());
      canvas.restore();
    }
    canvas.restore();

    final picture = recorder.endRecording();
    final resultImage = await picture.toImage(outW, outH);
    final byteData =
        await resultImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 完成画像をアプリのローカルストレージに保存し、ファイルパスを返す
  ///
  /// 保存先: アプリドキュメントディレクトリ/licenses/license_(timestamp).png
  Future<String> saveToFile(Uint8List imageBytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final licensesDir = Directory(p.join(directory.path, 'licenses'));
    if (!await licensesDir.exists()) {
      await licensesDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = p.join(licensesDir.path, 'license_$timestamp.png');
    final file = File(filePath);
    await file.writeAsBytes(imageBytes);

    return filePath;
  }

  /// SNSシェア用の正方形画像を生成
  ///
  /// 免許証画像を正方形のキャンバスに中央配置し、
  /// 余白にウォーターマークを追加する。
  /// Instagram 等のシェアに最適なフォーマット。
  Future<Uint8List> composeShareImage(Uint8List licenseImage) async {
    // 免許証画像を ui.Image にデコード
    final ui.Image license = await _decodeImage(licenseImage);

    // 1080x1080 の正方形キャンバスを作成
    const double size = 1080.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    // 背景色: クリームホワイト(#FFF8F0)
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = const Color(0xFFFFF8F0),
    );

    // 中央に免許証画像を配置（パディング付き）
    const double padding = 60.0;
    final double availableWidth = size - padding * 2;
    final double availableHeight = size - padding * 2 - 80; // 下部にウォーターマーク分の余白

    // アスペクト比を維持してフィット
    final double imageAspect = license.width / license.height;
    double drawWidth;
    double drawHeight;
    if (imageAspect > availableWidth / availableHeight) {
      // 横長 → 幅に合わせる
      drawWidth = availableWidth;
      drawHeight = availableWidth / imageAspect;
    } else {
      // 縦長 → 高さに合わせる
      drawHeight = availableHeight;
      drawWidth = availableHeight * imageAspect;
    }

    final double drawX = (size - drawWidth) / 2;
    final double drawY = (size - 80 - drawHeight) / 2; // ウォーターマーク分を考慮して上寄せ

    final src = Rect.fromLTWH(
      0,
      0,
      license.width.toDouble(),
      license.height.toDouble(),
    );
    final dst = Rect.fromLTWH(drawX, drawY, drawWidth, drawHeight);
    canvas.drawImageRect(license, src, dst, Paint());

    // 下部フッター帯（アプリ名 + DLリンク）
    // 帯の背景
    const footerHeight = 80.0;
    canvas.drawRect(
      Rect.fromLTWH(0, size - footerHeight, size, footerHeight),
      Paint()..color = const Color(0xFFF5EDE0),
    );
    // 区切り線
    canvas.drawLine(
      Offset(60, size - footerHeight),
      Offset(size - 60, size - footerHeight),
      Paint()
        ..color = const Color(0xFFDDD0C0)
        ..strokeWidth = 1.0,
    );

    // アプリ名
    final appNamePainter = TextPainter(
      text: const TextSpan(
        text: 'うちの子免許証',
        style: TextStyle(
          fontSize: 28,
          color: Color(0xFF5C4833),
          fontWeight: FontWeight.w700,
          letterSpacing: 3.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    appNamePainter.layout(maxWidth: size);
    appNamePainter.paint(
      canvas,
      Offset(
        (size - appNamePainter.width) / 2,
        size - footerHeight + 10,
      ),
    );

    // DLリンク（ストアURL確定後に差し替え）
    final linkPainter = TextPainter(
      text: const TextSpan(
        text: 'App Store で検索',
        style: TextStyle(
          fontSize: 18,
          color: Color(0xFF7A6650),
          fontWeight: FontWeight.w400,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    linkPainter.layout(maxWidth: size);
    linkPainter.paint(
      canvas,
      Offset(
        (size - linkPainter.width) / 2,
        size - footerHeight + 46,
      ),
    );

    // PNG としてエンコードして返す
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ---------------------------------------------------------------------------
  // プライベートヘルパー
  // ---------------------------------------------------------------------------

  /// コスチュームオーバーレイで使用する画像をアセットからロード
  ///
  /// 各コスチュームIDに対応する透過PNGをロードし、Map で返す。
  /// アセットが見つからない場合はスキップ（プレースホルダ表示にフォールバック）。
  Future<Map<String, ui.Image>> _loadCostumeImages(
    List<CostumeOverlay> overlays,
  ) async {
    final Map<String, ui.Image> images = {};
    final loadedIds = <String>{}; // 同じIDの重複ロード防止

    for (final overlay in overlays) {
      if (loadedIds.contains(overlay.costumeId)) continue;
      loadedIds.add(overlay.costumeId);

      final costume = Costume.findById(overlay.costumeId);
      try {
        final data = await rootBundle.load(costume.assetPath);
        final bytes = data.buffer.asUint8List();
        final image = await _decodeImage(bytes);
        images[overlay.costumeId] = image;
      } catch (e) {
        debugPrint('Costume asset not found: ${costume.assetPath}');
      }
    }
    return images;
  }

  /// バイトデータから ui.Image にデコード
  ///
  /// 写真や保存済み画像のバイトデータを Flutter の ui.Image に変換する。
  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

}
