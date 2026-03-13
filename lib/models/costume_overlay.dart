import 'dart:math';

/// 配置済みコスチュームの状態
///
/// frame_select_screen で編集中の各コスチュームの位置・サイズを保持。
/// cx/cy はカード幅/高さに対する比率（0.0〜1.0）。
class CostumeOverlay {
  final String uid;
  final String costumeId;
  double cx;
  double cy;
  double scale;
  double rotation;

  CostumeOverlay({
    String? uid,
    required this.costumeId,
    this.cx = 0.5,
    this.cy = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
  }) : uid = uid ??
            '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}';

  /// GoRouter extra 用のシリアライズ
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'costumeId': costumeId,
        'cx': cx,
        'cy': cy,
        'scale': scale,
        'rotation': rotation,
      };

  factory CostumeOverlay.fromMap(Map<String, dynamic> map) {
    return CostumeOverlay(
      uid: map['uid'] as String,
      costumeId: map['costumeId'] as String,
      cx: (map['cx'] as num).toDouble(),
      cy: (map['cy'] as num).toDouble(),
      scale: (map['scale'] as num).toDouble(),
      rotation: (map['rotation'] as num).toDouble(),
    );
  }
}
