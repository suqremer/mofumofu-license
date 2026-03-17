/// マスク編集画面 — 写真の背景を手動で消す
///
/// ## 使い方
/// go_router の extra に画像ファイルパス(String)を渡して遷移する。
/// ```dart
/// context.push('/create/mask', extra: imagePath);
/// ```
/// 完了ボタンを押すと、マスク適用済み画像の一時ファイルパス(String)を
/// `context.pop(outFilePath)` で呼び出し元に返す。
/// 透明にした部分は青(0xFF3B7CB8)に置換される。
///
/// ## 機能
/// - 消しゴムモード: なぞった部分を透明にする（ブラシサイズ調整可）
/// - 投げ縄モード: ペットの輪郭を囲み、外側を透明にする
/// - InteractiveViewer でズーム・パン（2本指操作中は描画無効）
/// - Undo / リセット
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/colors.dart';

// ---------------------------------------------------------------------------
// データモデル
// ---------------------------------------------------------------------------

/// マスク操作の基底クラス（sealed）
sealed class MaskOperation {
  const MaskOperation();
}

/// 消しゴムストローク
class EraserStroke extends MaskOperation {
  final List<Offset> points;
  final double brushSize;
  const EraserStroke(this.points, this.brushSize);
}

/// 投げ縄パス（囲んだ外側を消す）
class LassoPath extends MaskOperation {
  final List<Offset> points;
  const LassoPath(this.points);
}

/// 復元ブラシストローク（消した部分を元に戻す）
class RestoreStroke extends MaskOperation {
  final List<Offset> points;
  final double brushSize;
  const RestoreStroke(this.points, this.brushSize);
}

/// 編集ツール種別
enum _EditTool { eraser, lasso, restore }

// ---------------------------------------------------------------------------
// MaskEditScreen
// ---------------------------------------------------------------------------

class MaskEditScreen extends StatefulWidget {
  const MaskEditScreen({super.key});

  @override
  State<MaskEditScreen> createState() => _MaskEditScreenState();
}

class _MaskEditScreenState extends State<MaskEditScreen> {
  // -- 入力画像 --
  String? _imagePath;
  ui.Image? _originalImage;
  bool _isLoading = true;
  String? _error;

  // -- ツール状態 --
  _EditTool _currentTool = _EditTool.eraser;
  double _brushSize = 30.0;
  bool _offsetMode = false;
  int _offsetDirection = 0; // 0=左上, 1=右上, 2=左下, 3=右下
  Offset? _cursorImagePos; // クロスヘア表示用（画像座標系）

  /// オフセット方向ごとの補正量（画面座標系、斜め45度で約50px距離）
  static const List<Offset> _offsetDirections = [
    Offset(-35, -35), // ↖ 左上
    Offset(35, -35),  // ↗ 右上
    Offset(-35, 35),  // ↙ 左下
    Offset(35, 35),   // ↘ 右下
  ];
  static const List<String> _offsetLabels = ['↖', '↗', '↙', '↘'];

  // -- 操作履歴 --
  final List<MaskOperation> _operations = [];
  final List<MaskOperation> _redoStack = [];

  // -- 現在描画中のストローク / 投げ縄 --
  List<Offset>? _currentStrokePoints;
  List<Offset>? _currentLassoPoints;

  // -- ズーム・パン制御 --
  final TransformationController _transformController =
      TransformationController();
  int _activePointers = 0;

  // -- 完了処理中フラグ --
  bool _isExporting = false;

  // -- データ取得済みフラグ --
  bool _dataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      _dataLoaded = true;
      final extra = GoRouterState.of(context).extra;
      if (extra is String && extra.isNotEmpty) {
        _imagePath = extra;
        _loadImage();
      } else {
        setState(() {
          _error = '画像パスが指定されていません';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    _originalImage?.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // 画像読み込み
  // -----------------------------------------------------------------------

  Future<void> _loadImage() async {
    try {
      final file = File(_imagePath!);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _originalImage = frame.image;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '画像の読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  // -----------------------------------------------------------------------
  // ジェスチャー処理
  // -----------------------------------------------------------------------

  /// 画像座標系への変換（InteractiveViewer のズーム・パンを考慮）
  Offset _toImageCoords(Offset localPosition, Size widgetSize) {
    if (_originalImage == null) return localPosition;

    // オフセットモード: 指から斜め方向にずらした位置を操作点にする
    final adjusted = _offsetMode
        ? localPosition + _offsetDirections[_offsetDirection]
        : localPosition;

    final matrix = _transformController.value;
    // InteractiveViewer の逆変換
    final inverseMatrix = Matrix4.inverted(matrix);
    final transformed = MatrixUtils.transformPoint(inverseMatrix, adjusted);

    // ウィジェット内での画像の表示領域を計算（BoxFit.contain 相当）
    final imgW = _originalImage!.width.toDouble();
    final imgH = _originalImage!.height.toDouble();
    final scaleX = widgetSize.width / imgW;
    final scaleY = widgetSize.height / imgH;
    final scale = math.min(scaleX, scaleY);
    final renderW = imgW * scale;
    final renderH = imgH * scale;
    final offsetX = (widgetSize.width - renderW) / 2;
    final offsetY = (widgetSize.height - renderH) / 2;

    // ウィジェット座標 → 画像ピクセル座標
    return Offset(
      (transformed.dx - offsetX) / scale,
      (transformed.dy - offsetY) / scale,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers = math.max(0, _activePointers - 1);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers = math.max(0, _activePointers - 1);
  }

  void _onPanStart(DragStartDetails details, Size widgetSize) {
    if (_activePointers >= 2) return; // 2本指操作中は描画しない
    final pt = _toImageCoords(details.localPosition, widgetSize);
    setState(() {
      _cursorImagePos = _offsetMode ? pt : null;
      if (_currentTool == _EditTool.eraser || _currentTool == _EditTool.restore) {
        _currentStrokePoints = [pt];
      } else {
        _currentLassoPoints = [pt];
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size widgetSize) {
    if (_activePointers >= 2) return;
    final pt = _toImageCoords(details.localPosition, widgetSize);
    setState(() {
      _cursorImagePos = _offsetMode ? pt : null;
      if ((_currentTool == _EditTool.eraser || _currentTool == _EditTool.restore)
          && _currentStrokePoints != null) {
        _currentStrokePoints!.add(pt);
      } else if (_currentTool == _EditTool.lasso &&
          _currentLassoPoints != null) {
        _currentLassoPoints!.add(pt);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentTool == _EditTool.eraser && _currentStrokePoints != null) {
      if (_currentStrokePoints!.length >= 2) {
        _redoStack.clear();
        _operations.add(
          EraserStroke(List.of(_currentStrokePoints!), _brushSize),
        );
      }
      setState(() {
        _currentStrokePoints = null;
        _cursorImagePos = null;
      });
    } else if (_currentTool == _EditTool.restore && _currentStrokePoints != null) {
      if (_currentStrokePoints!.length >= 2) {
        _redoStack.clear();
        _operations.add(
          RestoreStroke(List.of(_currentStrokePoints!), _brushSize),
        );
      }
      setState(() {
        _currentStrokePoints = null;
        _cursorImagePos = null;
      });
    } else if (_currentTool == _EditTool.lasso && _currentLassoPoints != null) {
      if (_currentLassoPoints!.length >= 3) {
        _redoStack.clear();
        _operations.add(LassoPath(List.of(_currentLassoPoints!)));
      }
      setState(() {
        _currentLassoPoints = null;
        _cursorImagePos = null;
      });
    }
  }

  // -----------------------------------------------------------------------
  // 操作
  // -----------------------------------------------------------------------

  void _undo() {
    if (_operations.isEmpty) return;
    setState(() {
      _redoStack.add(_operations.removeLast());
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _operations.add(_redoStack.removeLast());
    });
  }

  void _reset() {
    if (_operations.isEmpty) return;
    setState(() {
      _operations.clear();
      _redoStack.clear();
    });
  }

  // -----------------------------------------------------------------------
  // 完了 — マスク適用 + エクスポート
  // -----------------------------------------------------------------------

  Future<void> _finish() async {
    if (_originalImage == null || _isExporting) return;
    setState(() => _isExporting = true);

    try {
      final img = _originalImage!;
      final w = img.width;
      final h = img.height;

      // 元画像のピクセルデータを取得
      final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) throw Exception('画像データの取得に失敗');
      final pixels = Uint8List.view(byteData.buffer);

      // マスクをビットマップとして描画（true = 消す）
      // マスク用のオフスクリーンキャンバスで操作を再生
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 背景を黒（0=残す）で塗りつぶし
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = const Color(0xFF000000),
      );

      // 各操作を白（=消す）または黒（=復元）で描画
      for (final op in _operations) {
        switch (op) {
          case EraserStroke(:final points, :final brushSize):
            final paint = Paint()
              ..color = const Color(0xFFFFFFFF)
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
          case RestoreStroke(:final points, :final brushSize):
            final paint = Paint()
              ..color = const Color(0xFF000000)
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
          case LassoPath(:final points):
            if (points.length < 3) continue;
            // 投げ縄: 全体を白で塗り、囲み内部を黒で塗る（= 外側を消す）
            canvas.drawRect(
              Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
              Paint()..color = const Color(0xFFFFFFFF),
            );
            final path = Path()..moveTo(points[0].dx, points[0].dy);
            for (int i = 1; i < points.length; i++) {
              path.lineTo(points[i].dx, points[i].dy);
            }
            path.close();
            canvas.drawPath(
              path,
              Paint()
                ..color = const Color(0xFF000000)
                ..style = PaintingStyle.fill,
            );
        }
      }

      final maskPicture = recorder.endRecording();
      final maskImage = await maskPicture.toImage(w, h);
      final maskByteData =
          await maskImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      maskImage.dispose();
      if (maskByteData == null) throw Exception('マスク生成に失敗');
      final maskRgba = Uint8List.view(maskByteData.buffer);

      // ピクセル単位でマスク適用: 白ピクセル(R>128)の部分を透明にする
      for (int i = 0; i < w * h; i++) {
        final mi = i * 4;
        if (maskRgba[mi] > 128) {
          // この部分は消す → 完全透明
          pixels[mi + 0] = 0;
          pixels[mi + 1] = 0;
          pixels[mi + 2] = 0;
          pixels[mi + 3] = 0;
        }
      }

      // ピクセルデータからui.Imageを再構築
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        w,
        h,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final resultImage = await completer.future;

      // PNGエンコード
      final pngByteData =
          await resultImage.toByteData(format: ui.ImageByteFormat.png);
      resultImage.dispose();
      if (pngByteData == null) throw Exception('PNG変換に失敗');

      // 一時ファイルに保存（元画像名ベースで固定 → 同じ写真なら同じパス）
      final tempDir = await getTemporaryDirectory();
      final srcName = _imagePath!.split('/').last.split('.').first;
      final outFile = File('${tempDir.path}/masked_$srcName.png');
      await outFile.writeAsBytes(Uint8List.view(pngByteData.buffer));

      if (!mounted) return;
      setState(() => _isExporting = false);
      // 呼び出し元（PhotoEditorScreen）に結果を返す
      context.pop(outFile.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('画像の書き出しに失敗しました: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool showTools =
        !_isLoading && _error == null && _originalImage != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('背景を消す'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
          tooltip: 'キャンセル',
        ),
        actions: [
          // 完了ボタン
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isExporting ? null : _finish,
            tooltip: '完了',
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _buildBody(),
      ),
      bottomNavigationBar: showTools
          ? SafeArea(
              child: Container(
                color: AppColors.background,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToolbar(),
                    _buildOffsetToggle(),
                    if (_currentTool != _EditTool.lasso) _buildBrushSlider(),
                    _buildActionButtons(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    // ローディング
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('画像を読み込み中...', style: TextStyle(color: AppColors.textMedium)),
          ],
        ),
      );
    }

    // エラー
    if (_error != null || _originalImage == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _error ?? '画像を読み込めませんでした',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade400, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return _buildEditArea();
  }

  /// 編集エリア（InteractiveViewer + GestureDetector）
  Widget _buildEditArea() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widgetSize =
              Size(constraints.maxWidth, constraints.maxHeight);
          return Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 5.0,
              panEnabled: _activePointers >= 2,
              scaleEnabled: true,
              child: GestureDetector(
                dragStartBehavior: DragStartBehavior.down,
                onPanStart: _activePointers < 2
                    ? (d) => _onPanStart(d, widgetSize)
                    : null,
                onPanUpdate: _activePointers < 2
                    ? (d) => _onPanUpdate(d, widgetSize)
                    : null,
                onPanEnd: _activePointers < 2 ? _onPanEnd : null,
                child: CustomPaint(
                  size: widgetSize,
                  painter: _MaskPainter(
                    image: _originalImage!,
                    operations: _operations,
                    currentStroke: _currentStrokePoints,
                    currentLasso: _currentLassoPoints,
                    currentBrushSize: _brushSize,
                    currentTool: _currentTool,
                    cursorImagePos: _cursorImagePos,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// ツール切り替え（消しゴム / 復元 / 投げ縄）
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: SegmentedButton<_EditTool>(
        segments: const [
          ButtonSegment(
            value: _EditTool.eraser,
            icon: Icon(Icons.auto_fix_high),
            label: Text('消す'),
          ),
          ButtonSegment(
            value: _EditTool.restore,
            icon: Icon(Icons.brush),
            label: Text('復元'),
          ),
          ButtonSegment(
            value: _EditTool.lasso,
            icon: Icon(Icons.gesture),
            label: Text('投げ縄'),
          ),
        ],
        selected: {_currentTool},
        onSelectionChanged: (set) {
          setState(() => _currentTool = set.first);
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary.withValues(alpha: 0.15);
            }
            return null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return Colors.black54;
          }),
        ),
      ),
    );
  }

  /// オフセットモードトグル + 4方向選択
  Widget _buildOffsetToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: Row(
        children: [
          // ON/OFFチェックボックス
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _offsetMode,
              onChanged: (v) => setState(() => _offsetMode = v ?? false),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _offsetMode = !_offsetMode),
            child: Text(
              '指ずらし',
              style: TextStyle(
                fontSize: 12,
                color: _offsetMode ? AppColors.primary : AppColors.textMedium,
                fontWeight: _offsetMode ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // 4方向ボタン（ONの時だけ表示）
          if (_offsetMode) ...[
            const SizedBox(width: 12),
            for (int i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              _buildDirectionButton(i),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDirectionButton(int index) {
    final isSelected = _offsetDirection == index;
    return GestureDetector(
      onTap: () => setState(() => _offsetDirection = index),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.textLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _offsetLabels[index],
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? AppColors.primary : AppColors.textMedium,
          ),
        ),
      ),
    );
  }

  /// ブラシサイズスライダー
  Widget _buildBrushSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.brush, size: 16, color: AppColors.textMedium),
          const SizedBox(width: 8),
          const Text('細', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
          Expanded(
            child: Slider(
              value: _brushSize,
              min: 10,
              max: 80,
              divisions: 14,
              activeColor: AppColors.primary,
              label: _brushSize.round().toString(),
              onChanged: (v) => setState(() => _brushSize = v),
            ),
          ),
          const Text('太', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
        ],
      ),
    );
  }

  /// アクションボタン（undo + リセット）
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Undo（アイコンのみ）
          Tooltip(
            message: '元に戻す',
            child: _IconActionChip(
              icon: Icons.undo,
              onTap: _operations.isNotEmpty ? _undo : null,
            ),
          ),
          const SizedBox(width: 12),
          // Redo（アイコンのみ）
          Tooltip(
            message: 'やり直す',
            child: _IconActionChip(
              icon: Icons.redo,
              onTap: _redoStack.isNotEmpty ? _redo : null,
            ),
          ),
          const SizedBox(width: 16),
          // リセット
          _ActionChip(
            icon: Icons.refresh,
            label: 'リセット',
            onTap: _operations.isNotEmpty ? _reset : null,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// アクションチップ（小さいボタン）
// ---------------------------------------------------------------------------

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: enabled ? AppColors.textDark : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// アイコンのみアクションチップ（undo/redo用）
// ---------------------------------------------------------------------------

class _IconActionChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _IconActionChip({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.primary : Colors.grey,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CustomPainter — 画像 + マスクオーバーレイ
// ---------------------------------------------------------------------------

class _MaskPainter extends CustomPainter {
  final ui.Image image;
  final List<MaskOperation> operations;
  final List<Offset>? currentStroke;
  final List<Offset>? currentLasso;
  final double currentBrushSize;
  final _EditTool currentTool;
  final Offset? cursorImagePos;

  _MaskPainter({
    required this.image,
    required this.operations,
    required this.currentStroke,
    required this.currentLasso,
    required this.currentBrushSize,
    required this.currentTool,
    this.cursorImagePos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // -- 画像を BoxFit.contain で描画 --
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final scaleX = size.width / imgW;
    final scaleY = size.height / imgH;
    final scale = math.min(scaleX, scaleY);
    final renderW = imgW * scale;
    final renderH = imgH * scale;
    final offsetX = (size.width - renderW) / 2;
    final offsetY = (size.height - renderH) / 2;

    final src = Rect.fromLTWH(0, 0, imgW, imgH);
    final dst = Rect.fromLTWH(offsetX, offsetY, renderW, renderH);
    canvas.drawImageRect(image, src, dst, Paint());

    // -- 画像座標系でのクリッピング＆スケーリング --
    canvas.save();
    canvas.clipRect(dst);
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    // 赤半透明のマスクオーバーレイペイント
    final maskPaint = Paint()
      ..color = const Color(0x66FF0000)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 復元ブラシ用の緑半透明ペイント
    final restorePaint = Paint()
      ..color = const Color(0x6600CC00)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // -- 確定済み操作を描画 --
    for (final op in operations) {
      switch (op) {
        case EraserStroke(:final points, :final brushSize):
          maskPaint.style = PaintingStyle.stroke;
          maskPaint.strokeWidth = brushSize;
          if (points.length == 1) {
            canvas.drawCircle(
              points[0],
              brushSize / 2,
              maskPaint..style = PaintingStyle.fill,
            );
          } else {
            final path = Path()..moveTo(points[0].dx, points[0].dy);
            for (int i = 1; i < points.length; i++) {
              path.lineTo(points[i].dx, points[i].dy);
            }
            canvas.drawPath(path, maskPaint..style = PaintingStyle.stroke);
          }
        case RestoreStroke(:final points, :final brushSize):
          restorePaint.strokeWidth = brushSize;
          if (points.length == 1) {
            canvas.drawCircle(
              points[0],
              brushSize / 2,
              restorePaint..style = PaintingStyle.fill,
            );
          } else {
            final path = Path()..moveTo(points[0].dx, points[0].dy);
            for (int i = 1; i < points.length; i++) {
              path.lineTo(points[i].dx, points[i].dy);
            }
            canvas.drawPath(path, restorePaint..style = PaintingStyle.stroke);
          }
        case LassoPath(:final points):
          if (points.length < 3) continue;
          // 投げ縄: 外側をマスク（全体を赤で塗り、パス内部をくり抜く）
          final lassoPath = Path()..moveTo(points[0].dx, points[0].dy);
          for (int i = 1; i < points.length; i++) {
            lassoPath.lineTo(points[i].dx, points[i].dy);
          }
          lassoPath.close();

          // 全画面を覆う矩形から投げ縄パスをくり抜き
          final outerRect = Path()
            ..addRect(Rect.fromLTWH(0, 0, imgW, imgH));
          final combined = Path.combine(
            PathOperation.difference,
            outerRect,
            lassoPath,
          );
          canvas.drawPath(
            combined,
            Paint()
              ..color = const Color(0x66FF0000)
              ..style = PaintingStyle.fill,
          );
      }
    }

    // -- 描画中のストローク --
    if (currentStroke != null && currentStroke!.isNotEmpty) {
      final isRestore = currentTool == _EditTool.restore;
      final strokePaint = Paint()
        ..color = isRestore ? const Color(0x6600CC00) : const Color(0x66FF0000)
        ..strokeWidth = currentBrushSize
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (currentStroke!.length == 1) {
        canvas.drawCircle(
          currentStroke![0],
          currentBrushSize / 2,
          strokePaint..style = PaintingStyle.fill,
        );
      } else {
        final path = Path()
          ..moveTo(currentStroke![0].dx, currentStroke![0].dy);
        for (int i = 1; i < currentStroke!.length; i++) {
          path.lineTo(currentStroke![i].dx, currentStroke![i].dy);
        }
        canvas.drawPath(path, strokePaint);
      }
    }

    // -- 描画中の投げ縄（点線） --
    if (currentLasso != null && currentLasso!.length >= 2) {
      _drawDashedPath(canvas, currentLasso!);
    }

    // -- クロスヘアカーソル（オフセットモード時） --
    if (cursorImagePos != null) {
      final cp = cursorImagePos!;
      const crossSize = 12.0;
      final crossPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      final shadowPaint = Paint()
        ..color = Colors.black54
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      // 影
      canvas.drawLine(Offset(cp.dx - crossSize, cp.dy), Offset(cp.dx + crossSize, cp.dy), shadowPaint);
      canvas.drawLine(Offset(cp.dx, cp.dy - crossSize), Offset(cp.dx, cp.dy + crossSize), shadowPaint);
      // 白線
      canvas.drawLine(Offset(cp.dx - crossSize, cp.dy), Offset(cp.dx + crossSize, cp.dy), crossPaint);
      canvas.drawLine(Offset(cp.dx, cp.dy - crossSize), Offset(cp.dx, cp.dy + crossSize), crossPaint);
    }

    canvas.restore();
  }

  /// 点線で投げ縄パスを描画
  void _drawDashedPath(Canvas canvas, List<Offset> points) {
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

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
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
    if (points.length >= 3) {
      canvas.drawCircle(
        points[0],
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        points[0],
        5,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MaskPainter oldDelegate) {
    return true; // 常に再描画（操作中はフレームごとに更新）
  }
}
