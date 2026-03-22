import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:image_background_remover/image_background_remover.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/costume.dart';
import '../../models/costume_overlay.dart';
import '../../models/license_template.dart';
import '../../services/license_painter.dart';
import '../../services/purchase_manager.dart';
import '../../theme/colors.dart';

import 'models/brush_operation.dart';
import 'models/brush_offset.dart';
import 'painters/photo_only_painter.dart';
import 'painters/brush_overlay_painter.dart';
import 'painters/guide_overlay_painter.dart';

/// フルスクリーン統合エディタ
///
/// frame_select_screen から証明写真タップで遷移。
/// 証明写真エリアだけを大きく表示し、
/// 顔ハメ選択・写真調整、背景削除、デコ配置を1画面で操作できる。
class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  // === 受け取りデータ ===
  String? _photoPath;
  String? _originalPhotoPath; // 背景削除前の元画像パス
  TemplateType _templateType = TemplateType.japan;

  // === 写真調整パラメータ ===
  double _photoScale = 1.0;
  double _photoOffsetX = 0.0;
  double _photoOffsetY = 0.0;
  bool _gestureIsPhotoMove = false; // ジェスチャー中に2本指→写真移動モード

  // === 写真色調整（明るさ/コントラスト/彩度） ===
  double _photoBrightness = 0.0;
  double _photoContrast = 0.0;
  double _photoSaturation = 0.0;

  // === ブラシ作業用ビューズーム（写真のサイズ/位置は変えない） ===
  double _viewScale = 1.0;
  double _viewOffsetX = 0.0; // ピクセル単位
  double _viewOffsetY = 0.0;
  double _gestureStartViewScale = 1.0;
  Offset _gestureStartViewOffset = Offset.zero;
  Offset _gestureFocalPoint = Offset.zero; // ピンチ開始時の焦点

  // === コスチューム（デコ: accessory + stamp） ===
  final List<CostumeOverlay> _costumeOverlays = [];
  String? _selectedOverlayUid;
  double _dragStartScale = 1.0;
  double _dragStartRotation = 0.0;
  Offset? _decoLastFocal; // デコドラッグ用: 前回のフォーカルポイント
  bool _isDraggingOverlay = false; // ゴミ箱表示用
  bool _isOverTrash = false; // ゴミ箱ホバー中
  CostumeType _selectedCostumeTab = CostumeType.accessory;

  // === 顔ハメ（outfit） ===
  String? _selectedOutfitId;
  ui.Image? _outfitUiImage; // Canvas描画用のoutfit画像

  // === 写真画像 ===
  ui.Image? _photoImage;
  /// 復元ブラシ用: エディタ起動時の元画像（自動削除前のオリジナル）
  ui.Image? _originalPhotoImage;

  // === 編集モード ===
  EditorMode _mode = EditorMode.outfit;

  // === ジェスチャー用 ===
  double _gestureStartScale = 1.0;

  // === ブラシ関連 ===
  BrushTool? _brushTool;
  double _brushSize = 30.0;
  final List<BrushOperation> _brushOps = [];
  final List<BrushOperation> _brushRedoStack = [];
  List<Offset>? _currentStrokePoints;
  List<Offset>? _currentLassoPoints;
  bool _isExporting = false;
  bool _isAutoRemoving = false;
  bool _hasAutoRemoved = false;

  // === ブラシオフセット ===
  BrushOffsetDirection _brushOffset = BrushOffsetDirection.center;
  /// ブラシ描画中の指の位置（プレビュー座標、オフセット表示用）
  Offset? _currentFingerPosition;

  // === ガイド表示 ===
  bool _showGuide = true;

  /// モード別ガイドメッセージ
  String get _guideMessage => switch (_mode) {
    EditorMode.outfit => 'ガイドにお顔を合わせてコスチュームを選んでください',
    EditorMode.brush => '背景を削除してください',
    EditorMode.deco => '',
    EditorMode.color => '',
  };

  /// マスク適用前の画像パス履歴（undo用）
  final List<String> _undoImageStack = [];
  /// 画像レベルのredo用スタック
  final List<String> _redoImageStack = [];

  bool _initialized = false;

  /// 写真エリアのアスペクト比（photoRectRatioから自動計算して一致させる）
  double get _photoAspect {
    final template = LicenseTemplate.fromType(_templateType);
    final pr = template.photoRectRatio;
    return (pr.width * template.outputSize.width) /
        (pr.height * template.outputSize.height);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final extra =
        GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    _photoPath = extra['photoPath'] as String?;
    final templateStr = extra['templateType'] as String?;
    _templateType = templateStr != null
        ? TemplateType.fromId(templateStr)
        : TemplateType.japan;

    _photoScale = (extra['photoScale'] as num?)?.toDouble() ?? 1.0;
    _photoOffsetX = (extra['photoOffsetX'] as num?)?.toDouble() ?? 0.0;
    _photoOffsetY = (extra['photoOffsetY'] as num?)?.toDouble() ?? 0.0;
    _photoBrightness = (extra['photoBrightness'] as num?)?.toDouble() ?? 0.0;
    _photoContrast = (extra['photoContrast'] as num?)?.toDouble() ?? 0.0;
    _photoSaturation = (extra['photoSaturation'] as num?)?.toDouble() ?? 0.0;

    // コスチュームオーバーレイ復元
    final overlayMaps = extra['costumeOverlays'] as List<dynamic>?;
    if (overlayMaps != null) {
      for (final map in overlayMaps) {
        _costumeOverlays
            .add(CostumeOverlay.fromMap(map as Map<String, dynamic>));
      }
    }

    // 顔ハメ復元
    _selectedOutfitId = extra['outfitId'] as String?;

    // 背景削除の操作履歴を復元
    _originalPhotoPath = extra['originalPhotoPath'] as String?;

    if (_originalPhotoPath != null && _photoPath != null) {
      // 2回目起動: 加工済み画像表示 + 元画像をundo/復元ブラシ用に保持
      _restoreBrushState(_originalPhotoPath!);
    } else if (_photoPath != null) {
      // 初回起動: 通常ロード
      _loadPhoto(_photoPath!, saveAsOriginal: true);
      _originalPhotoPath ??= _photoPath;
    }
    // 顔ハメ画像の初期ロード
    if (_selectedOutfitId != null) {
      _loadOutfitImage(Costume.findById(_selectedOutfitId!).assetPath);
    }
  }

  Future<void> _loadPhoto(String path, {bool saveAsOriginal = false}) async {
    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _photoImage?.dispose();
        _photoImage = frame.image;
      });
      // 復元ブラシ用にオリジナルを保持（初回のみ）
      if (saveAsOriginal) {
        final codec2 = await ui.instantiateImageCodec(bytes);
        final frame2 = await codec2.getNextFrame();
        _originalPhotoImage?.dispose();
        _originalPhotoImage = frame2.image;
      }
    }
  }

  /// 2回目起動時: 加工済み画像を表示し、元画像をundo/復元ブラシ用に保持
  Future<void> _restoreBrushState(String originalPath) async {
    // 加工済み画像をメインとしてロード（既にマスク適用済み）
    if (_photoPath != null) {
      await _loadPhoto(_photoPath!);
    }
    // 元画像を復元ブラシ用にロード
    final origFile = File(originalPath);
    if (await origFile.exists()) {
      final bytes = await origFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _originalPhotoImage?.dispose();
      _originalPhotoImage = frame.image;
    }
    // undoで元画像に戻れるようにする
    _undoImageStack.add(originalPath);
    if (mounted) setState(() {});
  }

  /// アセットからoutfit画像をui.Imageとして読み込み
  Future<void> _loadOutfitImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _outfitUiImage?.dispose();
        _outfitUiImage = frame.image;
      });
    }
  }

  @override
  void dispose() {
    _photoImage?.dispose();
    _originalPhotoImage?.dispose();
    _outfitUiImage?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 完了 — ブラシ操作があればマスク適用してから返す
  // ---------------------------------------------------------------------------

  void _showPremiumDialog() {
    final pm = PurchaseManager.instance;
    final package = pm.currentOffering?.availablePackages.firstOrNull;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'プレミアムコスチューム',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: const Text(
          '全47種類のコスチュームが使い放題！\n枚数制限も解除されます。\n\n¥300（買い切り）',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('あとで', style: TextStyle(color: Colors.grey)),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: pm.isPurchasing,
            builder: (_, purchasing, __) => ElevatedButton(
              onPressed: purchasing || package == null
                  ? null
                  : () async {
                      final success = await pm.purchasePackage(package);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (success && mounted) setState(() {});
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: purchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('購入する', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showTutorialDialog() {
    final (title, steps) = switch (_mode) {
      EditorMode.outfit => (
        'コスチューム選択',
        [
          _buildTutorialStepWithGif(1, 'assets/tutorial/guide_costume.gif', 'ガイドにお顔を合わせて\nコスチュームを選択してください'),
        ],
      ),
      EditorMode.brush => (
        '背景削除の使い方',
        [
          _buildTutorialStepWithGif(1, 'assets/tutorial/guide_brush_auto.gif', 'ボタンひとつで背景を自動削除できます\n※ 背景によってはうまく抜けないことがあります'),
          const SizedBox(height: 12),
          _buildTutorialStepWithGif(2, 'assets/tutorial/guide_brush_offset.gif', 'タップまたは長押しでオフセットの位置を\n変更できます。指からずらしてブラシ操作が可能です'),
          const SizedBox(height: 12),
          _buildTutorialStepWithGif(3, 'assets/tutorial/guide_brush_lasso.gif', '線で囲むことで、その周りの\n背景をまとめて削除できます'),
          const SizedBox(height: 12),
          _buildTutorialStepWithGif(4, 'assets/tutorial/guide_brush_finish.gif', '消しゴムと復元で微調整して\n仕上げましょう'),
        ],
      ),
      EditorMode.deco => ('', <Widget>[]),
      EditorMode.color => ('', <Widget>[]),
    };

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...steps,
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BCD4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialStepWithGif(int step, String gifPath, String text) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF00BCD4),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$step',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            gifPath,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------

  Future<void> _finish() async {
    if (_brushOps.isNotEmpty && _photoImage != null) {
      await _applyBrushMask();
    }

    // 現在の _photoImage を必ずファイルに保存して返す
    // （auto-remove やブラシ適用後の状態を確実に渡すため）
    String? finalPath = _photoPath;
    if (_photoImage != null) {
      try {
        final pngData = await _photoImage!.toByteData(format: ui.ImageByteFormat.png);
        if (pngData != null) {
          final tempDir = await getTemporaryDirectory();
          final ts = DateTime.now().millisecondsSinceEpoch;
          final outFile = File('${tempDir.path}/editor_final_$ts.png');
          await outFile.writeAsBytes(Uint8List.view(pngData.buffer));
          finalPath = outFile.path;
        }
      } catch (_) {
        // 失敗したら元のパスのまま返す
      }
    }

    if (!mounted) return;
    final result = {
      'photoPath': finalPath,
      'photoScale': _photoScale,
      'photoOffsetX': _photoOffsetX,
      'photoOffsetY': _photoOffsetY,
      'photoBrightness': _photoBrightness,
      'photoContrast': _photoContrast,
      'photoSaturation': _photoSaturation,
      'costumeOverlays': _costumeOverlays.map((o) => o.toMap()).toList(),
      'outfitId': _selectedOutfitId,
      'originalPhotoPath': _originalPhotoPath,
    };
    context.pop(result);
  }

  /// ストロークを Canvas に描画するヘルパー
  void _drawStrokeOnCanvas(Canvas canvas, List<Offset> points, double brushSize, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = brushSize
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (points.length == 1) {
      canvas.drawCircle(points[0], brushSize / 2, paint..style = PaintingStyle.fill);
    } else {
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  /// ブラシ操作をマスクとして適用し、新しいPNGに保存
  ///
  /// 2マスク方式:
  /// - 消去マスク (白=消す): 該当ピクセルを透明化
  /// - 復元マスク (白=復元): オリジナル画像のピクセルを復元
  Future<void> _applyBrushMask() async {
    if (_photoImage == null || _isExporting) return;
    setState(() => _isExporting = true);

    // 適用前の画像パスを履歴に保存（undo用）
    if (_photoPath != null) {
      _undoImageStack.add(_photoPath!);
      _redoImageStack.clear(); // 新操作が入ったのでredoは無効化
    }

    try {
      final img = _photoImage!;
      final w = img.width;
      final h = img.height;

      // 現在の画像のピクセルデータ
      final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) throw Exception('画像データの取得に失敗');
      final pixels = Uint8List.view(byteData.buffer);

      // オリジナル画像のピクセルデータ（復元用）
      Uint8List? originalPixels;
      if (_originalPhotoImage != null &&
          _originalPhotoImage!.width == w &&
          _originalPhotoImage!.height == h) {
        final origByteData = await _originalPhotoImage!.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (origByteData != null) {
          originalPixels = Uint8List.view(origByteData.buffer);
        }
      }

      // --- 消去マスク生成 ---
      final eraseRec = ui.PictureRecorder();
      final eraseCanvas = Canvas(eraseRec);
      eraseCanvas.drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = const Color(0xFF000000),
      );
      for (final op in _brushOps) {
        if (op is EraserStroke) {
          _drawStrokeOnCanvas(eraseCanvas, op.points, op.brushSize, const Color(0xFFFFFFFF));
        } else if (op is LassoOperation) {
          // 投げ縄: 全体を白（消す）→ 囲み内部を黒（残す）
          if (op.points.length >= 3) {
            eraseCanvas.drawRect(
              Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
              Paint()..color = const Color(0xFFFFFFFF),
            );
            final path = Path()..moveTo(op.points[0].dx, op.points[0].dy);
            for (int i = 1; i < op.points.length; i++) {
              path.lineTo(op.points[i].dx, op.points[i].dy);
            }
            path.close();
            eraseCanvas.drawPath(
              path,
              Paint()
                ..color = const Color(0xFF000000)
                ..style = PaintingStyle.fill,
            );
          }
        }
      }
      final erasePicture = eraseRec.endRecording();
      final eraseImage = await erasePicture.toImage(w, h);
      final eraseByteData = await eraseImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      eraseImage.dispose();
      if (eraseByteData == null) throw Exception('消去マスク生成に失敗');
      final eraseMask = Uint8List.view(eraseByteData.buffer);

      // --- 復元マスク生成 ---
      final restoreRec = ui.PictureRecorder();
      final restoreCanvas = Canvas(restoreRec);
      restoreCanvas.drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = const Color(0xFF000000),
      );
      for (final op in _brushOps) {
        if (op is RestoreStroke) {
          _drawStrokeOnCanvas(restoreCanvas, op.points, op.brushSize, const Color(0xFFFFFFFF));
        }
      }
      final restorePicture = restoreRec.endRecording();
      final restoreImage = await restorePicture.toImage(w, h);
      final restoreByteData = await restoreImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      restoreImage.dispose();
      if (restoreByteData == null) throw Exception('復元マスク生成に失敗');
      final restoreMask = Uint8List.view(restoreByteData.buffer);

      // --- ピクセル単位でマスク適用 ---
      for (int i = 0; i < w * h; i++) {
        final mi = i * 4;
        final isRestore = restoreMask[mi] > 128;
        final isErase = eraseMask[mi] > 128;

        if (isRestore && originalPixels != null) {
          // 復元: オリジナル画像のピクセルをコピー
          pixels[mi + 0] = originalPixels[mi + 0];
          pixels[mi + 1] = originalPixels[mi + 1];
          pixels[mi + 2] = originalPixels[mi + 2];
          pixels[mi + 3] = originalPixels[mi + 3];
        } else if (isErase) {
          // 消去: 透明化
          pixels[mi + 0] = 0;
          pixels[mi + 1] = 0;
          pixels[mi + 2] = 0;
          pixels[mi + 3] = 0;
        }
      }

      // ピクセルデータから ui.Image を再構築
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, completer.complete);
      final resultImage = await completer.future;

      // PNGエンコード
      final pngByteData = await resultImage.toByteData(format: ui.ImageByteFormat.png);
      resultImage.dispose();
      if (pngByteData == null) throw Exception('PNG変換に失敗');

      // 一時ファイルに保存
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outFile = File('${tempDir.path}/editor_masked_$timestamp.png');
      await outFile.writeAsBytes(Uint8List.view(pngByteData.buffer));

      // 写真パスを更新＆画像リロード
      _photoPath = outFile.path;
      _brushOps.clear();
      _brushRedoStack.clear();
      await _loadPhoto(outFile.path);

      if (mounted) setState(() => _isExporting = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像の書き出しに失敗しました: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ブラシ操作
  // ---------------------------------------------------------------------------

  void _brushUndo() {
    // 未適用のブラシ操作がある → 操作を取り消し
    if (_brushOps.isNotEmpty) {
      setState(() {
        _brushRedoStack.add(_brushOps.removeLast());
      });
      return;
    }
    // 適用済みの操作を巻き戻し（画像履歴から復元）
    if (_undoImageStack.isNotEmpty) {
      // 現在の画像をredoスタックに保存
      if (_photoPath != null) {
        _redoImageStack.add(_photoPath!);
      }
      final prevPath = _undoImageStack.removeLast();
      _photoPath = prevPath;
      _hasAutoRemoved = false; // 背景除去をundoした場合、再実行可能にする
      _loadPhoto(prevPath);
    }
  }

  void _brushRedo() {
    // ブラシ操作のredoがあればそちらを優先
    if (_brushRedoStack.isNotEmpty) {
      setState(() {
        _brushOps.add(_brushRedoStack.removeLast());
      });
      return;
    }
    // 画像レベルのredo
    if (_redoImageStack.isNotEmpty) {
      // 現在の画像をundoスタックに戻す
      if (_photoPath != null) {
        _undoImageStack.add(_photoPath!);
      }
      final nextPath = _redoImageStack.removeLast();
      _photoPath = nextPath;
      _hasAutoRemoved = true; // redo = 背景除去を再適用した状態
      _loadPhoto(nextPath);
    }
  }

  /// 画像のベースクロップ領域を計算（photoScale/Offset適用前）
  Rect _baseCropRect() {
    final imgW = _photoImage!.width.toDouble();
    final imgH = _photoImage!.height.toDouble();
    final imgAspect = imgW / imgH;
    if (imgAspect > _photoAspect) {
      final cropW = imgH * _photoAspect;
      return Rect.fromLTWH((imgW - cropW) / 2, 0, cropW, imgH);
    } else {
      final cropH = imgW / _photoAspect;
      return Rect.fromLTWH(0, (imgH - cropH) / 2, imgW, cropH);
    }
  }

  /// プレビュー座標 → 元画像座標に変換（canvas.translate方式対応）
  /// ブラシオフセットが有効な場合、指の位置からオフセット分ずらした位置を返す
  Offset _toImageCoords(Offset local, Size previewSize) {
    if (_photoImage == null) return local;

    // ブラシオフセット適用: 指の位置からオフセット距離だけずらす
    Offset adjusted = local;
    if (_brushOffset != BrushOffsetDirection.center) {
      final offsetDistance = _brushSize * 2;
      adjusted = Offset(
        local.dx - _brushOffset.unitOffset.dx * offsetDistance,
        local.dy - _brushOffset.unitOffset.dy * offsetDistance,
      );
    }

    // ビューズームの逆変換（タッチ座標→元のプレビュー座標に戻す）
    double vx = (adjusted.dx - _viewOffsetX) / _viewScale;
    double vy = (adjusted.dy - _viewOffsetY) / _viewScale;

    final base = _baseCropRect();
    // オフセットの逆変換
    double px = vx - _photoOffsetX * previewSize.width;
    double py = vy - _photoOffsetY * previewSize.height;
    // スケールの逆変換（中心基準）
    if (_photoScale != 1.0) {
      px = previewSize.width / 2 + (px - previewSize.width / 2) / _photoScale;
      py = previewSize.height / 2 + (py - previewSize.height / 2) / _photoScale;
    }
    // プレビュー座標 → 画像座標
    final relX = px / previewSize.width;
    final relY = py / previewSize.height;
    return Offset(base.left + relX * base.width, base.top + relY * base.height);
  }

  /// ブラシサイズをプレビュー座標 → 画像座標にスケーリング
  double _brushSizeToImage(Size previewSize) {
    if (_photoImage == null) return _brushSize;
    final base = _baseCropRect();
    // ビューズームも考慮: 拡大するとブラシが細かくなる
    return _brushSize * (base.width / previewSize.width) / _photoScale / _viewScale;
  }

  // ---------------------------------------------------------------------------
  // ビルド
  // ---------------------------------------------------------------------------

  /// モード名のテキスト
  String get _modeName => switch (_mode) {
    EditorMode.outfit => 'コスチューム',
    EditorMode.brush => '背景削除',
    EditorMode.deco => 'デコ',
    EditorMode.color => '色調整',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            // カスタムAppBar
            _buildAppBar(),
            // プレビューエリア
            Expanded(child: _buildPreview()),
            // ボトムセクション（モードタブ + パネル）
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  /// カスタムAppBar（薄型48px）
  Widget _buildAppBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _modeName,
              key: ValueKey(_mode),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: _finish,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '完了',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Undo/Redoピルボタン
  Widget _buildUndoRedoButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // プレビューエリア（証明写真のみ拡大表示）
  // ---------------------------------------------------------------------------

  Widget _buildPreview() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: AspectRatio(
          aspectRatio: _photoAspect,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final previewSize =
                  Size(constraints.maxWidth, constraints.maxHeight);

              return Stack(
                clipBehavior: Clip.none,
                children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                // 写真移動/ブラシ統合ジェスチャー
                // outfit: 常に写真移動 / brush: 1本指→ブラシ, 2本指→ビューズーム
                onScaleStart: (details) {
                        _gestureStartScale = _photoScale;
                        _gestureStartViewScale = _viewScale;
                        _gestureStartViewOffset = Offset(_viewOffsetX, _viewOffsetY);
                        _gestureFocalPoint = details.localFocalPoint;
                        // 2本指以上で開始 → 最初からズーム/移動モード
                        _gestureIsPhotoMove = details.pointerCount >= 2;
                        // ブラシモードで1本指の場合のみブラシ開始
                        if (_mode == EditorMode.brush && _brushTool != null && details.pointerCount == 1) {
                          final imgCoord = _toImageCoords(
                              details.localFocalPoint, previewSize);
                          setState(() {
                            _currentFingerPosition = details.localFocalPoint;
                            if (_brushTool == BrushTool.lasso) {
                              _currentLassoPoints = [imgCoord];
                            } else {
                              _currentStrokePoints = [imgCoord];
                            }
                          });
                        }
                      },
                onScaleUpdate: (details) {
                        // 2本指以上 → モードに応じて切り替え
                        if (details.pointerCount >= 2) {
                          if (!_gestureIsPhotoMove) {
                            _gestureIsPhotoMove = true;
                            // ブラシ描画中だったらキャンセル
                            _currentStrokePoints = null;
                            _currentLassoPoints = null;
                          }
                        }

                        // デコ・色調整モードでは写真を動かさない
                        if (_mode == EditorMode.deco || _mode == EditorMode.color) return;

                        if (_gestureIsPhotoMove && _mode == EditorMode.brush) {
                          // ブラシモード: ビューズーム（写真の位置・サイズは変えない）
                          // フォーカルポイント基準でズーム
                          setState(() {
                            final newScale = (_gestureStartViewScale * details.scale)
                                .clamp(1.0, 5.0);
                            // 焦点を中心にスケール変化分のオフセットを計算
                            final focalX = _gestureFocalPoint.dx;
                            final focalY = _gestureFocalPoint.dy;
                            _viewOffsetX = _gestureStartViewOffset.dx +
                                (focalX - _gestureStartViewOffset.dx) * (1 - newScale / _gestureStartViewScale) +
                                (details.localFocalPoint.dx - _gestureFocalPoint.dx);
                            _viewOffsetY = _gestureStartViewOffset.dy +
                                (focalY - _gestureStartViewOffset.dy) * (1 - newScale / _gestureStartViewScale) +
                                (details.localFocalPoint.dy - _gestureFocalPoint.dy);
                            _viewScale = newScale;
                          });
                        } else if (_mode == EditorMode.outfit) {
                          // outfitモードのみ: 写真の移動・ズーム
                          setState(() {
                            _photoScale = (_gestureStartScale * details.scale)
                                .clamp(0.3, 3.0);
                            _photoOffsetX = (_photoOffsetX +
                                    details.focalPointDelta.dx /
                                        previewSize.width)
                                .clamp(-1.5, 1.5);
                            _photoOffsetY = (_photoOffsetY +
                                    details.focalPointDelta.dy /
                                        previewSize.height)
                                .clamp(-1.5, 1.5);
                          });
                        } else if (_mode == EditorMode.brush) {
                          // 1本指ブラシ描画
                          final imgCoord = _toImageCoords(
                              details.localFocalPoint, previewSize);
                          setState(() {
                            _currentFingerPosition = details.localFocalPoint;
                            if (_brushTool == BrushTool.lasso) {
                              _currentLassoPoints?.add(imgCoord);
                            } else {
                              _currentStrokePoints?.add(imgCoord);
                            }
                          });
                        }
                      },
                onScaleEnd: (details) {
                        // デコモード: ピンチ終了
                        if (_mode == EditorMode.deco) {
                          _gestureIsPhotoMove = false;
                          return;
                        }
                        // 写真移動 or 色調整は何もしない
                        if (_gestureIsPhotoMove || _mode == EditorMode.outfit || _mode == EditorMode.color) {
                          _gestureIsPhotoMove = false;
                          return;
                        }
                        _gestureIsPhotoMove = false;
                        _currentFingerPosition = null;
                        // ブラシストローク確定
                        bool hasNewOp = false;
                        if (_brushTool == BrushTool.lasso) {
                          if (_currentLassoPoints != null &&
                              _currentLassoPoints!.length >= 3) {
                            setState(() {
                              _brushOps.add(LassoOperation(
                                  List.from(_currentLassoPoints!)));
                              _brushRedoStack.clear();
                              _currentLassoPoints = null;
                            });
                            hasNewOp = true;
                          } else {
                            setState(() => _currentLassoPoints = null);
                          }
                        } else if (_currentStrokePoints != null &&
                            _currentStrokePoints!.length >= 2) {
                          final imgBrushSize =
                              _brushSizeToImage(previewSize);
                          setState(() {
                            if (_brushTool == BrushTool.eraser) {
                              _brushOps.add(EraserStroke(
                                  List.from(_currentStrokePoints!),
                                  imgBrushSize));
                            } else {
                              _brushOps.add(RestoreStroke(
                                  List.from(_currentStrokePoints!),
                                  imgBrushSize));
                            }
                            _brushRedoStack.clear();
                            _currentStrokePoints = null;
                          });
                          hasNewOp = true;
                        } else {
                          setState(() => _currentStrokePoints = null);
                        }
                        if (hasNewOp && _photoImage != null) {
                          _applyBrushMask();
                        }
                      },
                onTap: _mode == EditorMode.deco
                    ? () {
                        setState(() => _selectedOverlayUid = null);
                      }
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Transform(
                    transform: Matrix4.diagonal3Values(_viewScale, _viewScale, 1)
                      ..setTranslationRaw(
                        _viewOffsetX,
                        _viewOffsetY,
                        0,
                      ),
                    child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 証明写真の描画（顔ハメオーバーレイ含む）
                      CustomPaint(
                        painter: PhotoOnlyPainter(
                          photoImage: _photoImage,
                          photoScale: _photoScale,
                          photoOffsetX: _photoOffsetX,
                          photoOffsetY: _photoOffsetY,
                          photoAspect: _photoAspect,
                          outfitImage: _selectedOutfitId != null ? _outfitUiImage : null,
                          outfitId: _selectedOutfitId,
                          photoColorFilter: LicensePainter.buildPhotoColorFilter(
                            brightness: _photoBrightness,
                            contrast: _photoContrast,
                            saturation: _photoSaturation,
                          ),
                        ),
                        size: Size.infinite,
                      ),
                      // ブラシモード時のオーバーレイ描画
                      if (_mode == EditorMode.brush && _photoImage != null)
                        CustomPaint(
                          painter: BrushOverlayPainter(
                            photoImage: _photoImage!,
                            photoAspect: _photoAspect,
                            photoScale: _photoScale,
                            photoOffsetX: _photoOffsetX,
                            photoOffsetY: _photoOffsetY,
                            operations: _brushOps,
                            currentPoints: _currentStrokePoints,
                            currentLassoPoints: _currentLassoPoints,
                            currentBrushSize:
                                _brushSizeToImage(previewSize),
                            currentTool: _brushTool ?? BrushTool.eraser,
                          ),
                          size: Size.infinite,
                        ),
                      // コスチュームオーバーレイ表示（全タブで表示・操作可能）
                      if (_costumeOverlays.isNotEmpty)
                        ..._costumeOverlays.map(
                          (overlay) => _buildDraggableOverlay(
                            overlay,
                            previewSize,
                            interactive: true,
                          ),
                        ),
                      // ゴミ箱ゾーン（ドラッグ中のみ表示）
                      if (_isDraggingOverlay)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: _isOverTrash ? 64 : 52,
                              height: _isOverTrash ? 64 : 52,
                              decoration: BoxDecoration(
                                color: _isOverTrash
                                    ? Colors.red
                                    : Colors.red.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.delete,
                                size: _isOverTrash ? 32 : 26,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ),
              ),
              // ブラシオフセットのビジュアルフィードバック
              if (_mode == EditorMode.brush &&
                  _brushOffset != BrushOffsetDirection.center &&
                  _currentFingerPosition != null &&
                  _brushTool != null &&
                  _brushTool != BrushTool.lasso)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _OffsetVisualPainter(
                        fingerPosition: _currentFingerPosition!,
                        offsetDirection: _brushOffset,
                        brushSize: _brushSize,
                      ),
                    ),
                  ),
                ),
              // ガイドオーバーレイ（ペット型シルエット）— コスチュームモードのみ
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: (_showGuide && _mode == EditorMode.outfit) ? 1.0 : 0.0,
                    child: CustomPaint(
                      painter: GuideOverlayPainter(),
                    ),
                  ),
                ),
              ),
              // ガイド説明バナー + ？ボタン（コスチューム・背景削除のみ）
              if (_showGuide && (_mode == EditorMode.outfit || _mode == EditorMode.brush))
                Positioned(
                  top: 8,
                  left: 8,
                  right: 100,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _guideMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _showTutorialDialog(),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.help_outline,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // ガイド表示トグルボタン（チップ型）— コスチューム・背景削除のみ
              if (_mode == EditorMode.outfit || _mode == EditorMode.brush)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _showGuide = !_showGuide),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _showGuide
                            ? const Color(0xDD00BCD4)
                            : const Color(0x80000000),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showGuide ? Icons.person : Icons.person_outline,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'ガイド',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // ビューズーム中のリセットボタン（ブラシモード時）
              if (_mode == EditorMode.brush && _viewScale > 1.01)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _viewScale = 1.0;
                      _viewOffsetX = 0.0;
                      _viewOffsetY = 0.0;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x80000000),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.zoom_out_map, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${_viewScale.toStringAsFixed(1)}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // コスチュームオーバーレイ（デコ用: ドラッグ可能）
  // ---------------------------------------------------------------------------

  Widget _buildDraggableOverlay(CostumeOverlay overlay, Size previewSize,
      {bool interactive = true}) {
    final costume = Costume.findById(overlay.costumeId);
    final baseW = previewSize.width * costume.defaultScale * overlay.scale;
    final baseH = baseW;
    final left = overlay.cx * previewSize.width - baseW / 2;
    final top = overlay.cy * previewSize.height - baseH / 2;
    final isSelected = interactive && _selectedOverlayUid == overlay.uid;
    final typeColor = _costumeTypeColor(costume.type);

    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        costume.assetPath,
        width: baseW,
        height: baseH,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.primary : typeColor,
              width: isSelected ? 2.5 : 1.5,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _costumeIcon(overlay.costumeId),
                  size: baseW * 0.35,
                  color: typeColor.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 2),
                Text(
                  costume.name,
                  style: TextStyle(
                    fontSize: (baseW * 0.12).clamp(8.0, 14.0),
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 選択枠 + 回転適用
    final content = Transform.rotate(
      angle: overlay.rotation,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          imageWidget,
          if (isSelected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // 選択中のデコ: Positioned.fillでプレビュー全体をカバー
    // → 2本目の指がデコ外でもピンチを検知可能（インスタストーリー風）
    if (isSelected && interactive) {
      return Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            setState(() => _selectedOverlayUid = null);
          },
          onScaleStart: (details) {
            setState(() {
              _selectedOverlayUid = overlay.uid;
              _dragStartScale = overlay.scale;
              _dragStartRotation = overlay.rotation;
              _decoLastFocal = details.localFocalPoint;
              _isDraggingOverlay = true;
              _isOverTrash = false;
            });
          },
          onScaleUpdate: (details) {
            final lastFocal = _decoLastFocal ?? details.localFocalPoint;
            final delta = details.localFocalPoint - lastFocal;
            _decoLastFocal = details.localFocalPoint;
            setState(() {
              if (details.pointerCount >= 2) {
                // 2本指: 拡大縮小 + 回転のみ（移動しない → ハンチング防止）
                overlay.scale =
                    (_dragStartScale * details.scale).clamp(0.3, 4.0);
                var newRotation =
                    _dragStartRotation + details.rotation;
                const snapAngles = [0.0, 1.5708, 3.1416, 4.7124, 6.2832, -1.5708, -3.1416];
                const snapThreshold = 0.087;
                for (final snap in snapAngles) {
                  if ((newRotation - snap).abs() < snapThreshold) {
                    newRotation = snap;
                    break;
                  }
                }
                overlay.rotation = newRotation;
              } else {
                // 1本指: 移動のみ（自前差分で計算、focalPointDeltaのジャンプ回避）
                overlay.cx += delta.dx / previewSize.width;
                overlay.cy += delta.dy / previewSize.height;
              }
              _isOverTrash = overlay.cy > 0.85;
            });
          },
          onScaleEnd: (_) {
            if (_isOverTrash) {
              setState(() {
                _costumeOverlays
                    .removeWhere((o) => o.uid == overlay.uid);
                _selectedOverlayUid = null;
              });
            }
            setState(() {
              _isDraggingOverlay = false;
              _isOverTrash = false;
              _decoLastFocal = null;
            });
          },
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: baseW,
                height: baseH,
                child: content,
              ),
            ],
          ),
        ),
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: baseW,
      height: baseH,
      child: interactive
          ? GestureDetector(
              onTap: () {
                setState(() {
                  _selectedOverlayUid = overlay.uid;
                });
              },
              onScaleStart: (details) {
                setState(() {
                  _selectedOverlayUid = overlay.uid;
                  _dragStartScale = overlay.scale;
                  _dragStartRotation = overlay.rotation;
                  _isDraggingOverlay = true;
                  _isOverTrash = false;
                });
              },
              onScaleUpdate: (details) {
                setState(() {
                  overlay.cx +=
                      details.focalPointDelta.dx / previewSize.width;
                  overlay.cy +=
                      details.focalPointDelta.dy / previewSize.height;
                  _isOverTrash = overlay.cy > 0.85;
                });
              },
              onScaleEnd: (_) {
                if (_isOverTrash) {
                  setState(() {
                    _costumeOverlays
                        .removeWhere((o) => o.uid == overlay.uid);
                    _selectedOverlayUid = null;
                  });
                }
                setState(() {
                  _isDraggingOverlay = false;
                  _isOverTrash = false;
                });
              },
              child: content,
            )
          : IgnorePointer(child: content),
    );
  }

  // ---------------------------------------------------------------------------
  // ボトムセクション（モードタブ + パネル）
  // ---------------------------------------------------------------------------

  Widget _buildBottomSection() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドルバー
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // モード切替セグメントコントロール
          _buildModeSegment(),
          const SizedBox(height: 8),
          // モード別パネル
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildActivePanel(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// セグメントコントロール（4モード）
  Widget _buildModeSegment() {
    const modes = [
      (EditorMode.outfit, Icons.checkroom, 'コスチューム'),
      (EditorMode.brush, Icons.content_cut, '背景削除'),
      (EditorMode.deco, Icons.auto_awesome, 'デコ'),
      (EditorMode.color, Icons.tune, '色調整'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: modes.map((m) {
          final (mode, icon, label) = m;
          final isActive = _mode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => _switchMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        size: 14,
                        color: isActive ? Colors.white : Colors.grey[600]),
                    const SizedBox(width: 3),
                    Text(
                      label,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey[600],
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// モード切替ロジック
  Future<void> _switchMode(EditorMode mode) async {
    if (_mode == mode) return;
    // ブラシモードから離れる時、未適用の操作があれば自動適用
    if (_mode == EditorMode.brush &&
        mode != EditorMode.brush &&
        _brushOps.isNotEmpty &&
        _photoImage != null) {
      await _applyBrushMask();
    }
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _selectedOverlayUid = null;
      // ブラシモードから離れたらビューズームをリセット
      if (mode != EditorMode.brush) {
        _viewScale = 1.0;
        _viewOffsetX = 0.0;
        _viewOffsetY = 0.0;
      }
    });
  }

  /// 現在のモードに対応するパネルを返す
  Widget _buildActivePanel() {
    return switch (_mode) {
      EditorMode.outfit => _buildOutfitTools(),
      EditorMode.brush => _buildBrushTools(),
      EditorMode.deco => _buildDecoTools(),
      EditorMode.color => _buildColorTools(),
    };
  }

  // ---------------------------------------------------------------------------
  // 顔ハメモードのツール
  // ---------------------------------------------------------------------------

  Widget _buildOutfitTools() {
    final outfits = Costume.byType(CostumeType.outfit);
    return Padding(
      key: const ValueKey('outfit_panel'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 横スクロール outfit 一覧
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: outfits.length + 1,
              itemBuilder: (context, index) {
                // index 0 = 「なし」ボタン
                if (index == 0) {
                  final isNone = _selectedOutfitId == null;
                  return GestureDetector(
                    onTap: isNone
                        ? null
                        : () {
                            setState(() {
                              _selectedOutfitId = null;
                            });
                            _outfitUiImage?.dispose();
                            _outfitUiImage = null;
                          },
                    child: AnimatedScale(
                      scale: isNone ? 1.0 : 0.95,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.elasticOut,
                      child: Container(
                        width: 72,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isNone
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isNone
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.block,
                              size: 28,
                              color: isNone ? Colors.white : Colors.grey[500],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'なし',
                              style: TextStyle(
                                fontSize: 10,
                                color: isNone ? Colors.white : Colors.grey[500],
                                fontWeight: isNone ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final costume = outfits[index - 1];
                final isSelected = _selectedOutfitId == costume.id;
                final isLocked = costume.isPremium && !PurchaseManager.instance.isPremium;

                return GestureDetector(
                  onTap: isSelected
                      ? null
                      : isLocked
                          ? () => _showPremiumDialog()
                          : () {
                              setState(() {
                                _selectedOutfitId = costume.id;
                              });
                              _loadOutfitImage(Costume.findById(costume.id).assetPath);
                            },
                  child: AnimatedScale(
                    scale: isSelected ? 1.0 : 0.95,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.elasticOut,
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isLocked)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Icon(Icons.lock, size: 12, color: Colors.grey[600]),
                            ),
                          Image.asset(
                            costume.thumbnailPath,
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              _costumeIcon(costume.id),
                              size: 28,
                              color: isLocked
                                  ? Colors.grey[600]
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            costume.name,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[500],
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // ズームスライダー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(Icons.zoom_out, color: Colors.grey[600], size: 16),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: Colors.white.withValues(alpha: 0.5),
                      inactiveTrackColor: Colors.grey[800],
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _photoScale,
                      min: 0.3,
                      max: 3.0,
                      onChanged: (v) => setState(() => _photoScale = v),
                    ),
                  ),
                ),
                Icon(Icons.zoom_in, color: Colors.grey[600], size: 16),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _photoScale = 1.0;
                      _photoOffsetX = 0.0;
                      _photoOffsetY = 0.0;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.restart_alt, color: Colors.grey[500], size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ブラシモードのツール（背景削除）
  // ---------------------------------------------------------------------------

  Widget _buildBrushTools() {
    return Padding(
      key: const ValueKey('brush_panel'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 上段: 自動削除 + ツールグループ + オフセット
          Row(
            children: [
              // 自動背景削除ボタン
              _buildAutoRemoveButton(),
              const SizedBox(width: 6),
              // ツールグループ（連結セグメント風）
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBrushSegment(BrushTool.eraser, '消しゴム',
                          Icons.auto_fix_high, const Color(0xFFFF6B6B)),
                      _buildBrushSegment(BrushTool.restore, '復元',
                          Icons.healing, const Color(0xFF4CAF50)),
                      _buildBrushSegment(BrushTool.lasso, '投げ縄',
                          Icons.gesture, const Color(0xFF42A5F5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // オフセットボタン
              _buildOffsetButton(),
            ],
          ),
          const SizedBox(height: 8),
          // ブラシサイズスライダー or ヒントテキスト
          if (_brushTool != null && _brushTool != BrushTool.lasso)
            Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[500]!, width: 1.5),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: _brushTool == BrushTool.eraser
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF4CAF50),
                      inactiveTrackColor: Colors.grey[800],
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _brushSize,
                      min: 10,
                      max: 80,
                      onChanged: (v) => setState(() => _brushSize = v),
                    ),
                  ),
                ),
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[500]!, width: 1.5),
                  ),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _brushTool == BrushTool.lasso
                    ? '指でペットの輪郭をなぞってね'
                    : 'ツールを選んでください',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          const SizedBox(height: 4),
          // Undo/Redo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildUndoRedoButton(
                icon: Icons.undo,
                label: '戻す',
                enabled: _brushOps.isNotEmpty || _undoImageStack.isNotEmpty,
                onPressed: _brushUndo,
              ),
              const SizedBox(width: 12),
              _buildUndoRedoButton(
                icon: Icons.redo,
                label: '進む',
                enabled: _brushRedoStack.isNotEmpty || _redoImageStack.isNotEmpty,
                onPressed: _brushRedo,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ブラシツールのセグメントボタン（トグルOFF対応: 再タップでnull）
  Widget _buildBrushSegment(
      BrushTool tool, String label, IconData icon, Color color) {
    final isActive = _brushTool == tool;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _brushTool = _brushTool == tool ? null : tool;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isActive ? color : Colors.grey[600]),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? color : Colors.grey[600],
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 自動背景削除ボタン（グラデーションピル）
  Widget _buildAutoRemoveButton() {
    return GestureDetector(
      onTap: _isAutoRemoving ? null : _autoRemoveBackground,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAutoRemoving)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.auto_fix_high, size: 16, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              _isAutoRemoving ? '処理中…' : '自動削除',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ブラシオフセットボタン（タップサイクル + ロングプレス放射メニュー）
  Widget _buildOffsetButton() {
    final isActive = _brushOffset != BrushOffsetDirection.center;
    return GestureDetector(
      onTap: () => setState(() => _brushOffset = _brushOffset.next),
      onLongPress: () => _showRadialOffsetMenu(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.15)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: Colors.white30, width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_brushOffset.icon, size: 18, color: Colors.white),
            if (isActive)
              Text(
                _brushOffset.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 7,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 放射状メニューでオフセット方向を選択
  void _showRadialOffsetMenu() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _RadialOffsetMenu(
        currentDirection: _brushOffset,
        onSelect: (dir) {
          setState(() => _brushOffset = dir);
          entry.remove();
        },
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _autoRemoveBackground() async {
    if (_photoPath == null || _photoImage == null) return;
    if (_hasAutoRemoved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('自動削除は1回のみ実行できます。消しゴムや投げ縄で微調整してね'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isAutoRemoving = true);

    // 背景除去前の画像パスをundoスタックに保存（「戻す」で戻れるように）
    _undoImageStack.add(_photoPath!);
    _redoImageStack.clear(); // 新操作が入ったのでredoは無効化

    try {
      final inputBytes = await File(_photoPath!).readAsBytes();

      // ML モデルで背景削除（PNG バイト列で返る）
      // エミュレータでは非常に遅いため60秒タイムアウト
      final resultBytes = await BackgroundRemover.instance
          .removeBgBytes(inputBytes, threshold: 0.5)
          .timeout(const Duration(seconds: 60),
              onTimeout: () => throw TimeoutException('背景削除がタイムアウトしました'));

      // 結果を新ファイルに保存
      final dir = await getTemporaryDirectory();
      final outFile = File(
        '${dir.path}/auto_bg_removed_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outFile.writeAsBytes(resultBytes);

      // 画像を再読み込み
      final codec = await ui.instantiateImageCodec(resultBytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _photoImage?.dispose();
          _photoImage = frame.image;
          _photoPath = outFile.path;
          _isAutoRemoving = false;
          _hasAutoRemoved = true;
        });
      }
    } on TimeoutException {
      _undoImageStack.removeLast(); // 失敗時はスタックから除去
      if (mounted) {
        setState(() => _isAutoRemoving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('背景削除がタイムアウトしました。実機での実行をお試しください。'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _undoImageStack.removeLast(); // 失敗時はスタックから除去
      if (mounted) {
        setState(() => _isAutoRemoving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('背景削除に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 色調整パネル
  // ---------------------------------------------------------------------------

  Widget _buildColorTools() {
    final hasAdjustment =
        _photoBrightness != 0.0 || _photoContrast != 0.0 || _photoSaturation != 0.0;

    return Padding(
      key: const ValueKey('color_panel'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildColorSlider(
            label: '明るさ',
            icon: Icons.brightness_6,
            value: _photoBrightness,
            onChanged: (v) => setState(() => _photoBrightness = v),
          ),
          _buildColorSlider(
            label: 'コントラスト',
            icon: Icons.contrast,
            value: _photoContrast,
            onChanged: (v) => setState(() => _photoContrast = v),
          ),
          _buildColorSlider(
            label: '彩度',
            icon: Icons.palette_outlined,
            value: _photoSaturation,
            onChanged: (v) => setState(() => _photoSaturation = v),
          ),
          if (hasAdjustment)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => setState(() {
                  _photoBrightness = 0.0;
                  _photoContrast = 0.0;
                  _photoSaturation = 0.0;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'リセット',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorSlider({
    required String label,
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 6),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white.withValues(alpha: 0.5),
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: value,
                min: -1.0,
                max: 1.0,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                color: value != 0 ? Colors.white : Colors.grey[600],
                fontWeight: value != 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // デコモードのツール
  // ---------------------------------------------------------------------------

  Widget _buildDecoTools() {
    // outfit を除外した CostumeType のリスト
    final decoTypes = CostumeType.values
        .where((t) => t != CostumeType.outfit)
        .toList();

    return Padding(
      key: const ValueKey('deco_panel'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // カテゴリタブ（ピル型）
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: decoTypes.map((type) {
                final isActive = _selectedCostumeTab == type;
                final color = _costumeTypeColor(type);
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCostumeTab = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? color.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isActive ? color : Colors.grey[600],
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // コスチュームカード横スクロール
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: Costume.byType(_selectedCostumeTab).map((costume) {
                final isLocked = costume.isPremium && !PurchaseManager.instance.isPremium;
                final color = _costumeTypeColor(costume.type);

                return GestureDetector(
                  onTap: isLocked
                      ? () => _showPremiumDialog()
                      : () {
                          setState(() {
                            _costumeOverlays.add(CostumeOverlay(
                              costumeId: costume.id,
                              cx: 0.5,
                              cy: 0.5,
                            ));
                          });
                        },
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isLocked)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Icon(Icons.lock, size: 14, color: Colors.grey[600]),
                          ),
                        Image.asset(
                          costume.thumbnailPath,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            _costumeIcon(costume.id),
                            size: 32,
                            color: isLocked
                                ? Colors.grey[600]
                                : color.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          costume.name,
                          style: TextStyle(
                            fontSize: 10,
                            color: isLocked ? Colors.grey[600] : Colors.grey[400],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ヘルパー
  // ---------------------------------------------------------------------------

  Color _costumeTypeColor(CostumeType type) {
    switch (type) {
      case CostumeType.accessory:
        return const Color(0xFF2196F3);
      case CostumeType.stamp:
        return const Color(0xFFE91E63);
      case CostumeType.outfit:
        return const Color(0xFF4CAF50);
    }
  }

  IconData _costumeIcon(String costumeId) {
    switch (costumeId) {
      case 'cap':
        return Icons.sports_baseball;
      case 'sunglasses':
        return Icons.visibility;
      case 'bowtie':
        return Icons.dry_cleaning;
      case 'heart':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'speech':
        return Icons.chat_bubble;
      case 'pawprint':
        return Icons.pets;
      case 'gakuran':
        return Icons.school;
      case 'sailor':
        return Icons.anchor;
      case 'kimono':
        return Icons.local_florist;
      case 'tuxedo':
        return Icons.business_center;
      case 'pirate':
        return Icons.sailing;
      default:
        return Icons.auto_awesome;
    }
  }
}

// =============================================================================
// ブラシオフセット ビジュアルフィードバック
// =============================================================================

class _OffsetVisualPainter extends CustomPainter {
  final Offset fingerPosition;
  final BrushOffsetDirection offsetDirection;
  final double brushSize;

  _OffsetVisualPainter({
    required this.fingerPosition,
    required this.offsetDirection,
    required this.brushSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final offsetDist = brushSize * 2;
    final brushPos = Offset(
      fingerPosition.dx - offsetDirection.unitOffset.dx * offsetDist,
      fingerPosition.dy - offsetDirection.unitOffset.dy * offsetDist,
    );

    // 接続点線（指→ブラシ位置）
    final dashPaint = Paint()
      ..color = const Color(0x80FFFFFF)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    _drawDashedLine(canvas, fingerPosition, brushPos, dashPaint, 4, 3);

    // ゴーストサークル（実際のブラシ位置）
    canvas.drawCircle(
      brushPos,
      brushSize / 2,
      Paint()
        ..color = const Color(0x4DFFFFFF)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      brushPos,
      brushSize / 2,
      Paint()
        ..color = const Color(0x80FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 十字線カーソル（指の位置）
    const crossSize = 12.0;
    final crossPaint = Paint()
      ..color = const Color(0xB3FFFFFF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(fingerPosition.dx - crossSize, fingerPosition.dy),
      Offset(fingerPosition.dx + crossSize, fingerPosition.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(fingerPosition.dx, fingerPosition.dy - crossSize),
      Offset(fingerPosition.dx, fingerPosition.dy + crossSize),
      crossPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p0, Offset p1,
      Paint paint, double dashLen, double gapLen) {
    final dx = p1.dx - p0.dx;
    final dy = p1.dy - p0.dy;
    final dist = (Offset(dx, dy)).distance;
    if (dist == 0) return;
    final ux = dx / dist;
    final uy = dy / dist;
    double travelled = 0;
    bool drawing = true;
    while (travelled < dist) {
      final segLen = (drawing ? dashLen : gapLen).clamp(0, dist - travelled);
      if (drawing) {
        canvas.drawLine(
          Offset(p0.dx + ux * travelled, p0.dy + uy * travelled),
          Offset(p0.dx + ux * (travelled + segLen), p0.dy + uy * (travelled + segLen)),
          paint,
        );
      }
      travelled += segLen;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(covariant _OffsetVisualPainter old) => true;
}

// =============================================================================
// 放射状オフセットメニュー
// =============================================================================

class _RadialOffsetMenu extends StatefulWidget {
  final BrushOffsetDirection currentDirection;
  final ValueChanged<BrushOffsetDirection> onSelect;
  final VoidCallback onDismiss;

  const _RadialOffsetMenu({
    required this.currentDirection,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_RadialOffsetMenu> createState() => _RadialOffsetMenuState();
}

class _RadialOffsetMenuState extends State<_RadialOffsetMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black38,
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x60000000),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 中央: center
                  _dirButton(BrushOffsetDirection.center, 0, 0),
                  // 4方向
                  _dirButton(BrushOffsetDirection.topRight, 45, -45),
                  _dirButton(BrushOffsetDirection.bottomRight, 45, 45),
                  _dirButton(BrushOffsetDirection.bottomLeft, -45, 45),
                  _dirButton(BrushOffsetDirection.topLeft, -45, -45),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dirButton(BrushOffsetDirection dir, double dx, double dy) {
    final isActive = widget.currentDirection == dir;
    return Positioned(
      left: 90 + dx - 22,
      top: 90 + dy - 22,
      child: GestureDetector(
        onTap: () => widget.onSelect(dir),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: Colors.white54, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(dir.icon, size: 20, color: Colors.white),
              Text(
                dir.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
