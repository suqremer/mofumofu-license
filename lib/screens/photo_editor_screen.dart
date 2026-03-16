import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:image_background_remover/image_background_remover.dart';
import 'package:path_provider/path_provider.dart';

import '../models/costume.dart';
import '../models/costume_overlay.dart';
import '../models/license_template.dart';
import '../config/dev_config.dart';
import '../services/purchase_manager.dart';
import '../theme/colors.dart';

// ---------------------------------------------------------------------------
// ブラシ操作モデル
// ---------------------------------------------------------------------------

sealed class _BrushOperation {
  const _BrushOperation();

  Map<String, dynamic> toMap();

  static _BrushOperation fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    final points = (map['points'] as List)
        .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();
    return switch (type) {
      'eraser' => _EraserStroke(points, (map['brushSize'] as num).toDouble()),
      'restore' => _RestoreStroke(points, (map['brushSize'] as num).toDouble()),
      'lasso' => _LassoOperation(points),
      _ => throw ArgumentError('Unknown BrushOperation type: $type'),
    };
  }
}

class _EraserStroke extends _BrushOperation {
  final List<Offset> points;
  final double brushSize;
  const _EraserStroke(this.points, this.brushSize);

  @override
  Map<String, dynamic> toMap() => {
    'type': 'eraser',
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    'brushSize': brushSize,
  };
}

class _RestoreStroke extends _BrushOperation {
  final List<Offset> points;
  final double brushSize;
  const _RestoreStroke(this.points, this.brushSize);

  @override
  Map<String, dynamic> toMap() => {
    'type': 'restore',
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    'brushSize': brushSize,
  };
}

class _LassoOperation extends _BrushOperation {
  final List<Offset> points;
  const _LassoOperation(this.points);

  @override
  Map<String, dynamic> toMap() => {
    'type': 'lasso',
    'points': points.map((p) => [p.dx, p.dy]).toList(),
  };
}

// ---------------------------------------------------------------------------
// 編集モード
// ---------------------------------------------------------------------------

/// 編集モード
enum EditorMode { outfit, brush, deco }

/// ブラシツール種別
enum BrushTool { eraser, restore, lasso }

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

  // === コスチューム（デコ: accessory + stamp） ===
  final List<CostumeOverlay> _costumeOverlays = [];
  String? _selectedOverlayUid;
  double _dragStartScale = 1.0;
  double _dragStartRotation = 0.0;
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
  final List<_BrushOperation> _brushOps = [];
  final List<_BrushOperation> _brushRedoStack = [];
  List<Offset>? _currentStrokePoints;
  List<Offset>? _currentLassoPoints;
  bool _isExporting = false;
  bool _isAutoRemoving = false;
  bool _hasAutoRemoved = false;

  // === ガイド表示 ===
  bool _showGuide = true;

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

  void _showTutorialDialog() {
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
                const Text(
                  '写真の切り抜き手順',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildTutorialStepWithGif(1, 'assets/tutorial/tutorial_step1.gif', 'ピンチで拡大・縮小して\nペットのお顔をガイドの丸に合わせます'),
                const SizedBox(height: 16),
                _buildTutorialStepWithGif(2, 'assets/tutorial/tutorial_step2.gif', 'お好みのコスチュームを選んで\nペットに着せましょう'),
                const SizedBox(height: 16),
                _buildTutorialStepWithGif(3, 'assets/tutorial/tutorial_step3.gif', '「背景削除」で不要な部分を消します\n自動削除・ブラシ・投げ縄ツールが使えます'),
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
        if (op is _EraserStroke) {
          _drawStrokeOnCanvas(eraseCanvas, op.points, op.brushSize, const Color(0xFFFFFFFF));
        } else if (op is _LassoOperation) {
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
        if (op is _RestoreStroke) {
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
  Offset _toImageCoords(Offset local, Size previewSize) {
    if (_photoImage == null) return local;

    final base = _baseCropRect();
    // オフセットの逆変換
    double px = local.dx - _photoOffsetX * previewSize.width;
    double py = local.dy - _photoOffsetY * previewSize.height;
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
    return _brushSize * (base.width / previewSize.width) / _photoScale;
  }

  // ---------------------------------------------------------------------------
  // ビルド
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('写真・デコ編集',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
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
            TextButton(
              onPressed: _finish,
              child: const Text('完了',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // プレビューエリア（証明写真のみ拡大表示）
          Expanded(child: _buildPreview()),
          // モード別ツールバー
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildUndoRedoButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.black.withValues(alpha: 0.7)
              : Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: enabled ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: _photoAspect,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final previewSize =
                  Size(constraints.maxWidth, constraints.maxHeight);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                // 写真移動/ブラシ統合ジェスチャー
                // outfit: 常に写真移動 / brush: 1本指→ブラシ, 2本指→写真移動
                onScaleStart: (_mode == EditorMode.outfit || _mode == EditorMode.brush)
                    ? (details) {
                        _gestureStartScale = _photoScale;
                        _gestureIsPhotoMove = false;
                        // ブラシモードで1本指の場合はブラシ開始
                        if (_mode == EditorMode.brush && _brushTool != null && details.pointerCount == 1) {
                          final imgCoord = _toImageCoords(
                              details.localFocalPoint, previewSize);
                          setState(() {
                            if (_brushTool == BrushTool.lasso) {
                              _currentLassoPoints = [imgCoord];
                            } else {
                              _currentStrokePoints = [imgCoord];
                            }
                          });
                        }
                      }
                    : null,
                onScaleUpdate: (_mode == EditorMode.outfit || _mode == EditorMode.brush)
                    ? (details) {
                        // 2本指以上 → 写真移動モードに切り替え（ブラシ中断）
                        if (details.pointerCount >= 2) {
                          if (!_gestureIsPhotoMove) {
                            _gestureIsPhotoMove = true;
                            // ブラシ描画中だったらキャンセル
                            _currentStrokePoints = null;
                            _currentLassoPoints = null;
                          }
                        }

                        if (_gestureIsPhotoMove || _mode == EditorMode.outfit) {
                          // 写真の移動・ズーム
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
                            if (_brushTool == BrushTool.lasso) {
                              _currentLassoPoints?.add(imgCoord);
                            } else {
                              _currentStrokePoints?.add(imgCoord);
                            }
                          });
                        }
                      }
                    : null,
                onScaleEnd: (_mode == EditorMode.outfit || _mode == EditorMode.brush)
                    ? (details) {
                        // 写真移動だった場合はブラシ処理不要
                        if (_gestureIsPhotoMove || _mode == EditorMode.outfit) {
                          _gestureIsPhotoMove = false;
                          return;
                        }
                        _gestureIsPhotoMove = false;
                        // ブラシストローク確定
                        bool hasNewOp = false;
                        if (_brushTool == BrushTool.lasso) {
                          if (_currentLassoPoints != null &&
                              _currentLassoPoints!.length >= 3) {
                            setState(() {
                              _brushOps.add(_LassoOperation(
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
                              _brushOps.add(_EraserStroke(
                                  List.from(_currentStrokePoints!),
                                  imgBrushSize));
                            } else {
                              _brushOps.add(_RestoreStroke(
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
                      }
                    : null,
                onTap: _mode == EditorMode.deco
                    ? () {
                        setState(() => _selectedOverlayUid = null);
                      }
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 証明写真の描画（顔ハメオーバーレイ含む）
                      CustomPaint(
                        painter: _PhotoOnlyPainter(
                          photoImage: _photoImage,
                          photoScale: _photoScale,
                          photoOffsetX: _photoOffsetX,
                          photoOffsetY: _photoOffsetY,
                          photoAspect: _photoAspect,
                          outfitImage: _selectedOutfitId != null ? _outfitUiImage : null,
                          outfitId: _selectedOutfitId,
                        ),
                        size: Size.infinite,
                      ),
                      // ブラシモード時のオーバーレイ描画
                      if (_mode == EditorMode.brush && _photoImage != null)
                        CustomPaint(
                          painter: _BrushOverlayPainter(
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
                      // ガイドオーバーレイ（人型シルエット）
                      if (_showGuide)
                        CustomPaint(
                          painter: _GuideOverlayPainter(),
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
                      // ガイド説明バナー + ？ボタン
                      if (_showGuide)
                        Positioned(
                          top: 8,
                          left: 8,
                          right: 100, // チップ型トグルボタンと被らないよう余白
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: const Text(
                                    'ガイドにお顔を合わせてください',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _showTutorialDialog(),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.help_outline,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // ガイド表示トグルボタン（チップ型）
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _showGuide = !_showGuide),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _showGuide
                                  ? const Color(0xDD00BCD4)
                                  : Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white54, width: 1),
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
                                Text(
                                  'ガイド',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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

    return Positioned(
      left: left,
      top: top,
      width: baseW,
      height: baseH,
      child: interactive
          ? GestureDetector(
              onTap: () {
                setState(() {
                  _selectedOverlayUid =
                      _selectedOverlayUid == overlay.uid ? null : overlay.uid;
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
                  // 1本指: 移動のみ
                  overlay.cx +=
                      details.focalPointDelta.dx / previewSize.width;
                  overlay.cy +=
                      details.focalPointDelta.dy / previewSize.height;
                  // 2本指: ピンチ拡大縮小 + 回転
                  if (details.pointerCount >= 2) {
                    overlay.scale =
                        (_dragStartScale * details.scale).clamp(0.3, 4.0);
                    var newRotation =
                        _dragStartRotation + details.rotation;
                    // 水平・垂直スナップ（0°/90°/180°/270°付近±5°で吸着）
                    const snapAngles = [0.0, 1.5708, 3.1416, 4.7124, 6.2832, -1.5708, -3.1416];
                    const snapThreshold = 0.087; // 約5°
                    for (final snap in snapAngles) {
                      if ((newRotation - snap).abs() < snapThreshold) {
                        newRotation = snap;
                        break;
                      }
                    }
                    overlay.rotation = newRotation;
                  }
                  // ゴミ箱判定: アイテム中心がプレビュー下端付近か
                  _isOverTrash = overlay.cy > 0.85;
                });
              },
              onScaleEnd: (_) {
                if (_isOverTrash) {
                  // ゴミ箱エリアでドロップ → 削除
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
  // ツールバー
  // ---------------------------------------------------------------------------

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // モード別のコンテンツ
            if (_mode == EditorMode.outfit) _buildOutfitTools(),
            if (_mode == EditorMode.deco) _buildDecoTools(),
            if (_mode == EditorMode.brush) _buildBrushTools(),
            const SizedBox(height: 8),
            // モード切替タブ
            _buildModeTabs(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: _buildModeTab(EditorMode.outfit, Icons.checkroom, 'コスチューム')),
          const SizedBox(width: 8),
          Flexible(child: _buildModeTab(EditorMode.brush, Icons.content_cut, '背景削除')),
          const SizedBox(width: 8),
          Flexible(child: _buildModeTab(EditorMode.deco, Icons.auto_awesome, 'デコ')),
        ],
      ),
    );
  }

  Widget _buildModeTab(EditorMode mode, IconData icon, String label) {
    final isActive = _mode == mode;
    return GestureDetector(
      onTap: () async {
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
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: isActive ? AppColors.primary : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 顔ハメモードのツール
  // ---------------------------------------------------------------------------

  Widget _buildOutfitTools() {
    final outfits = Costume.byType(CostumeType.outfit);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 横スクロール outfit 一覧
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: outfits.length,
            itemBuilder: (context, index) {
              final costume = outfits[index];
              final isSelected = _selectedOutfitId == costume.id;
              final isLocked = costume.isPremium && !PurchaseManager.instance.isPremium;

              return GestureDetector(
                onTap: isLocked || isSelected
                    ? null
                    : () {
                        setState(() {
                          _selectedOutfitId = costume.id;
                        });
                        _loadOutfitImage(Costume.findById(costume.id).assetPath);
                      },
                child: Container(
                  width: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.25)
                        : const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[700]!,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLocked)
                        Icon(Icons.lock, size: 12, color: Colors.grey[600]),
                      Image.asset(
                        costume.thumbnailPath,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          _costumeIcon(costume.id),
                          size: 22,
                          color: isLocked
                              ? Colors.grey[600]
                              : const Color(0xFF4CAF50),
                        ),
                      ),
                      Text(
                        costume.name,
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected
                              ? const Color(0xFF4CAF50)
                              : Colors.grey[400],
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
          // ズームスライダー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.zoom_out, color: Colors.grey, size: 16),
                Expanded(
                  child: Slider(
                    value: _photoScale,
                    min: 0.3,
                    max: 3.0,
                    activeColor: AppColors.primary,
                    inactiveColor: Colors.grey[700],
                    onChanged: (v) => setState(() => _photoScale = v),
                  ),
                ),
                const Icon(Icons.zoom_in, color: Colors.grey, size: 16),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _photoScale = 1.0;
                      _photoOffsetX = 0.0;
                      _photoOffsetY = 0.0;
                    });
                  },
                  icon: const Icon(Icons.restart_alt, color: Colors.grey, size: 20),
                  tooltip: 'リセット',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ],
      );
  }

  // ---------------------------------------------------------------------------
  // ブラシモードのツール（背景削除）
  // ---------------------------------------------------------------------------

  Widget _buildBrushTools() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          // ツール選択（横スクロール対応）
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 自動背景削除
                _buildAutoRemoveButton(),
                const SizedBox(width: 8),
                _buildBrushToolButton(
                  BrushTool.eraser,
                  Icons.auto_fix_high,
                  '消しゴム',
                  const Color(0xFFFF6B6B),
                ),
                const SizedBox(width: 8),
                _buildBrushToolButton(
                  BrushTool.restore,
                  Icons.healing,
                  '復元',
                  const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 8),
                _buildBrushToolButton(
                  BrushTool.lasso,
                  Icons.gesture,
                  '投げ縄',
                  const Color(0xFF1E88E5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 戻す / 進む
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildUndoRedoButton(
                icon: Icons.undo,
                label: '戻す',
                enabled: _brushOps.isNotEmpty || _undoImageStack.isNotEmpty,
                onPressed: _brushUndo,
              ),
              const SizedBox(width: 16),
              _buildUndoRedoButton(
                icon: Icons.redo,
                label: '進む',
                enabled: _brushRedoStack.isNotEmpty || _redoImageStack.isNotEmpty,
                onPressed: _brushRedo,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ブラシサイズスライダー（投げ縄以外）
          if (_brushTool != null && _brushTool != BrushTool.lasso)
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: Colors.grey[400]),
                Expanded(
                  child: Slider(
                    value: _brushSize,
                    min: 10,
                    max: 80,
                    divisions: 14,
                    activeColor: _brushTool == BrushTool.eraser
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF4CAF50),
                    inactiveColor: Colors.grey[700],
                    onChanged: (v) => setState(() => _brushSize = v),
                  ),
                ),
                Icon(Icons.circle, size: 24, color: Colors.grey[400]),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '指でペットの輪郭をなぞってね',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBrushToolButton(
      BrushTool tool, IconData icon, String label, Color color) {
    final isActive = _brushTool == tool;
    return GestureDetector(
      onTap: () => setState(() => _brushTool = tool),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : Colors.grey[600]!,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? color : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : Colors.grey,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoRemoveButton() {
    return GestureDetector(
      onTap: _isAutoRemoving ? null : _autoRemoveBackground,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
          ),
          borderRadius: BorderRadius.circular(16),
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
            const SizedBox(width: 4),
            Text(
              _isAutoRemoving ? '処理中…' : '自動削除',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
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
  // デコモードのツール
  // ---------------------------------------------------------------------------

  Widget _buildDecoTools() {
    // outfit を除外した CostumeType のリスト
    final decoTypes = CostumeType.values
        .where((t) => t != CostumeType.outfit)
        .toList();

    return SizedBox(
      height: 140,
      child: Column(
        children: [
          // カテゴリタブ（outfit 除外）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: decoTypes.map((type) {
                final isActive = _selectedCostumeTab == type;
                final color = _costumeTypeColor(type);
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCostumeTab = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isActive ? color : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        type.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isActive ? color : Colors.grey,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // コスチュームグリッド
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: Costume.byType(_selectedCostumeTab).map((costume) {
                final isLocked = costume.isPremium && !PurchaseManager.instance.isPremium;
                final color = _costumeTypeColor(costume.type);

                return GestureDetector(
                  onTap: isLocked
                      ? null
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
                    width: 72,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isLocked)
                          Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                        // サムネイル画像 or アイコン
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
                                : color.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          costume.name,
                          style: TextStyle(
                            fontSize: 10,
                            color: isLocked ? Colors.grey[600] : color,
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
// 証明写真のみ描画する Painter
// =============================================================================

class _PhotoOnlyPainter extends CustomPainter {
  final ui.Image? photoImage;
  final double photoScale;
  final double photoOffsetX;
  final double photoOffsetY;
  final double photoAspect;
  final ui.Image? outfitImage;
  final String? outfitId;

  _PhotoOnlyPainter({
    this.photoImage,
    required this.photoScale,
    required this.photoOffsetX,
    required this.photoOffsetY,
    required this.photoAspect,
    this.outfitImage,
    this.outfitId,
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

    // photoScale/Offset を適用（canvas変換で自由スクロール+ズーム）
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.save();
    canvas.clipRect(dstRect);
    // オフセットで写真をスライド
    canvas.translate(
      photoOffsetX * size.width,
      photoOffsetY * size.height,
    );
    // ズーム（中心基準）
    if (photoScale != 1.0) {
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(photoScale);
      canvas.translate(-size.width / 2, -size.height / 2);
    }
    canvas.drawImageRect(photoImage!, srcRect, dstRect, Paint());
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
  bool shouldRepaint(covariant _PhotoOnlyPainter oldDelegate) {
    return photoImage != oldDelegate.photoImage ||
        photoScale != oldDelegate.photoScale ||
        photoOffsetX != oldDelegate.photoOffsetX ||
        photoOffsetY != oldDelegate.photoOffsetY ||
        outfitImage != oldDelegate.outfitImage ||
        outfitId != oldDelegate.outfitId;
  }
}

// =============================================================================
// ブラシ操作のオーバーレイ描画
// =============================================================================

class _BrushOverlayPainter extends CustomPainter {
  final ui.Image photoImage;
  final double photoAspect;
  final double photoScale;
  final double photoOffsetX;
  final double photoOffsetY;
  final List<_BrushOperation> operations;
  final List<Offset>? currentPoints;
  final List<Offset>? currentLassoPoints;
  final double currentBrushSize;
  final BrushTool currentTool;

  _BrushOverlayPainter({
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

    // photoScale/Offset を適用（canvas.translate方式に合わせた座標変換）
    // baseRectは元画像の表示領域（アスペクト比クロップ後）
    final Rect srcRect = baseRect;

    // 画像座標 → プレビュー座標（canvas.translate方式対応）
    Offset toPreview(Offset imgCoord) {
      // まず基本変換（srcRect→プレビュー座標）
      final relX = (imgCoord.dx - srcRect.left) / srcRect.width;
      final relY = (imgCoord.dy - srcRect.top) / srcRect.height;
      double px = relX * size.width;
      double py = relY * size.height;
      // スケール適用（中心基準）
      if (photoScale != 1.0) {
        px = size.width / 2 + (px - size.width / 2) * photoScale;
        py = size.height / 2 + (py - size.height / 2) * photoScale;
      }
      // オフセット適用
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
        case _EraserStroke(:final points, :final brushSize):
          _drawStroke(canvas, points, sizeToPreview(brushSize),
              const Color(0x44FF0000), toPreview);
        case _RestoreStroke(:final points, :final brushSize):
          _drawStroke(canvas, points, sizeToPreview(brushSize),
              const Color(0x4400FF00), toPreview);
        case _LassoOperation(:final points):
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

    // 全画面から投げ縄パスをくり抜き → 外側を赤半透明
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
  bool shouldRepaint(covariant _BrushOverlayPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// 証明写真ガイド（人型シルエット）
// ---------------------------------------------------------------------------

class _GuideOverlayPainter extends CustomPainter {
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
      // 耳の楕円から顔の楕円を引く → 顔の外側だけ残る
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
  bool shouldRepaint(covariant _GuideOverlayPainter oldDelegate) => false;
}
