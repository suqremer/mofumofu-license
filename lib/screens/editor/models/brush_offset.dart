import 'package:flutter/material.dart';

/// ブラシオフセット方向
enum BrushOffsetDirection {
  center,       // オフセットなし
  topRight,     // ↗
  bottomRight,  // ↘
  bottomLeft,   // ↙
  topLeft,      // ↖
}

extension BrushOffsetDirectionX on BrushOffsetDirection {
  /// 次の方向に進む（サイクル）
  BrushOffsetDirection get next => BrushOffsetDirection.values[
    (index + 1) % BrushOffsetDirection.values.length
  ];

  /// オフセットベクトル（単位ベクトル）
  Offset get unitOffset => switch (this) {
    BrushOffsetDirection.center => Offset.zero,
    BrushOffsetDirection.topRight => const Offset(-0.707, 0.707),
    BrushOffsetDirection.bottomRight => const Offset(-0.707, -0.707),
    BrushOffsetDirection.bottomLeft => const Offset(0.707, -0.707),
    BrushOffsetDirection.topLeft => const Offset(0.707, 0.707),
  };

  /// アイコン表示用
  IconData get icon => switch (this) {
    BrushOffsetDirection.center => Icons.center_focus_strong,
    BrushOffsetDirection.topRight => Icons.north_east,
    BrushOffsetDirection.bottomRight => Icons.south_east,
    BrushOffsetDirection.bottomLeft => Icons.south_west,
    BrushOffsetDirection.topLeft => Icons.north_west,
  };

  /// 表示ラベル
  String get label => switch (this) {
    BrushOffsetDirection.center => '中央',
    BrushOffsetDirection.topRight => '右上',
    BrushOffsetDirection.bottomRight => '右下',
    BrushOffsetDirection.bottomLeft => '左下',
    BrushOffsetDirection.topLeft => '左上',
  };
}
