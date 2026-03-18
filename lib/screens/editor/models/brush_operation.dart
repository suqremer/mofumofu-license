import 'dart:ui';

// ---------------------------------------------------------------------------
// 編集モード
// ---------------------------------------------------------------------------

/// 編集モード
enum EditorMode { outfit, brush, deco, color }

/// ブラシツール種別
enum BrushTool { eraser, restore, lasso }

// ---------------------------------------------------------------------------
// ブラシ操作モデル
// ---------------------------------------------------------------------------

sealed class BrushOperation {
  const BrushOperation();

  Map<String, dynamic> toMap();

  static BrushOperation fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    final points = (map['points'] as List)
        .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();
    return switch (type) {
      'eraser' => EraserStroke(points, (map['brushSize'] as num).toDouble()),
      'restore' => RestoreStroke(points, (map['brushSize'] as num).toDouble()),
      'lasso' => LassoOperation(points),
      _ => throw ArgumentError('Unknown BrushOperation type: $type'),
    };
  }
}

class EraserStroke extends BrushOperation {
  final List<Offset> points;
  final double brushSize;
  const EraserStroke(this.points, this.brushSize);

  @override
  Map<String, dynamic> toMap() => {
    'type': 'eraser',
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    'brushSize': brushSize,
  };
}

class RestoreStroke extends BrushOperation {
  final List<Offset> points;
  final double brushSize;
  const RestoreStroke(this.points, this.brushSize);

  @override
  Map<String, dynamic> toMap() => {
    'type': 'restore',
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    'brushSize': brushSize,
  };
}

class LassoOperation extends BrushOperation {
  final List<Offset> points;
  const LassoOperation(this.points);

  @override
  Map<String, dynamic> toMap() => {
    'type': 'lasso',
    'points': points.map((p) => [p.dx, p.dy]).toList(),
  };
}
