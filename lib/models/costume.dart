/// コスチュームのカテゴリ（無料 or プレミアム）
enum CostumeCategory {
  free,
  premium,
}

/// コスチュームのタイプ（配置方法の分類）
enum CostumeType {
  accessory('アクセサリー'), // A: 小物・装飾品
  stamp('スタンプ'), // B: スタンプ/デコ
  outfit('顔ハメ'); // C: 顔ハメパネル

  final String label;
  const CostumeType(this.label);
}

/// コスチュームデータモデル
///
/// ペット写真に重ねる衣装・小物の定義。
/// assetPath は assets/costumes/ 以下の透過PNG画像を指す。
class Costume {
  final String id;
  final String name;
  final CostumeCategory category;
  final CostumeType type;

  /// コスチューム画像のアセットパス（透過PNG）
  final String assetPath;

  /// 選択UI用サムネイルのアセットパス
  final String thumbnailPath;

  /// 表示順（小さいほど先頭）
  final int sortOrder;

  /// デフォルトサイズ（カード幅に対する比率、0.0〜1.0）
  final double defaultScale;

  const Costume({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.assetPath,
    required this.thumbnailPath,
    this.sortOrder = 0,
    this.defaultScale = 0.2,
  });

  bool get isFree => category == CostumeCategory.free;
  bool get isPremium => category == CostumeCategory.premium;

  /// 全コスチュームの初期データ
  static const List<Costume> all = [
    // === A: アクセサリー（16種） ===
    Costume(
      id: 'captain_hat',
      name: 'キャプテン帽',
      category: CostumeCategory.free,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_1.png',
      thumbnailPath: 'assets/costumes/thumb_acc_1.png',
      sortOrder: 0,
      defaultScale: 0.25,
    ),
    Costume(
      id: 'party_hat',
      name: 'パーティーハット',
      category: CostumeCategory.free,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_2.png',
      thumbnailPath: 'assets/costumes/thumb_acc_2.png',
      sortOrder: 1,
      defaultScale: 0.20,
    ),
    Costume(
      id: 'cowboy_hat',
      name: 'カウボーイ',
      category: CostumeCategory.premium,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_3.png',
      thumbnailPath: 'assets/costumes/thumb_acc_3.png',
      sortOrder: 2,
      defaultScale: 0.25,
    ),
    Costume(
      id: 'crown',
      name: '王冠',
      category: CostumeCategory.free,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_4.png',
      thumbnailPath: 'assets/costumes/thumb_acc_4.png',
      sortOrder: 3,
      defaultScale: 0.20,
    ),
    Costume(
      id: 'cat_ears',
      name: '猫耳',
      category: CostumeCategory.free,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_6.png',
      thumbnailPath: 'assets/costumes/thumb_acc_6.png',
      sortOrder: 4,
      defaultScale: 0.22,
    ),
    Costume(
      id: 'hachimaki',
      name: 'はちまき',
      category: CostumeCategory.premium,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_7.png',
      thumbnailPath: 'assets/costumes/thumb_acc_7.png',
      sortOrder: 5,
      defaultScale: 0.25,
    ),
    Costume(
      id: 'sunglasses',
      name: 'サングラス',
      category: CostumeCategory.free,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_8.png',
      thumbnailPath: 'assets/costumes/thumb_acc_8.png',
      sortOrder: 6,
      defaultScale: 0.20,
    ),
    Costume(
      id: 'tiara',
      name: 'ティアラ',
      category: CostumeCategory.premium,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_9.png',
      thumbnailPath: 'assets/costumes/thumb_acc_9.png',
      sortOrder: 7,
      defaultScale: 0.20,
    ),
    Costume(
      id: 'bunny_ears',
      name: 'うさ耳',
      category: CostumeCategory.premium,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_10.png',
      thumbnailPath: 'assets/costumes/thumb_acc_10.png',
      sortOrder: 8,
      defaultScale: 0.22,
    ),
    Costume(
      id: 'mustache',
      name: 'おひげ',
      category: CostumeCategory.premium,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_11.png',
      thumbnailPath: 'assets/costumes/thumb_acc_11.png',
      sortOrder: 9,
      defaultScale: 0.18,
    ),
    Costume(
      id: 'angel_wings',
      name: '天使の翼',
      category: CostumeCategory.premium,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_12.png',
      thumbnailPath: 'assets/costumes/thumb_acc_12.png',
      sortOrder: 10,
      defaultScale: 0.30,
    ),
    Costume(
      id: 'pearl_earring',
      name: 'パールイヤリング',
      category: CostumeCategory.premium,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_13.png',
      thumbnailPath: 'assets/costumes/thumb_acc_13.png',
      sortOrder: 11,
      defaultScale: 0.10,
    ),
    Costume(
      id: 'devil_horns',
      name: '悪魔の角',
      category: CostumeCategory.premium,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_14.png',
      thumbnailPath: 'assets/costumes/thumb_acc_14.png',
      sortOrder: 12,
      defaultScale: 0.22,
    ),
    Costume(
      id: 'gold_glasses',
      name: 'ゴールドメガネ',
      category: CostumeCategory.premium,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_15.png',
      thumbnailPath: 'assets/costumes/thumb_acc_15.png',
      sortOrder: 13,
      defaultScale: 0.20,
    ),
    Costume(
      id: 'ruby_earring',
      name: 'ルビーイヤリング',
      category: CostumeCategory.premium,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_16.png',
      thumbnailPath: 'assets/costumes/thumb_acc_16.png',
      sortOrder: 14,
      defaultScale: 0.10,
    ),
    Costume(
      id: 'bob_wig',
      name: 'おかっぱ',
      category: CostumeCategory.premium,
      type: CostumeType.accessory,
      assetPath: 'assets/costumes/acc_17.png',
      thumbnailPath: 'assets/costumes/thumb_acc_17.png',
      sortOrder: 15,
      defaultScale: 0.25,
    ),
    // === B: スタンプ/デコ（21種） ===
    Costume(
      id: 'heart',
      name: 'ハート',
      category: CostumeCategory.free,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/01_heart.png',
      thumbnailPath: 'assets/costumes/thumb_01_heart.png',
      sortOrder: 10,
      defaultScale: 0.12,
    ),
    Costume(
      id: 'sparkles',
      name: 'キラキラ',
      category: CostumeCategory.free,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/02_sparkles.png',
      thumbnailPath: 'assets/costumes/thumb_02_sparkles.png',
      sortOrder: 11,
      defaultScale: 0.12,
    ),
    Costume(
      id: 'paw_white',
      name: '白肉球',
      category: CostumeCategory.free,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/03_paw_white.png',
      thumbnailPath: 'assets/costumes/thumb_03_paw_white.png',
      sortOrder: 12,
      defaultScale: 0.10,
    ),
    Costume(
      id: 'paw_brown',
      name: '茶肉球',
      category: CostumeCategory.free,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/04_paw_brown.png',
      thumbnailPath: 'assets/costumes/thumb_04_paw_brown.png',
      sortOrder: 13,
      defaultScale: 0.10,
    ),
    Costume(
      id: 'carrot',
      name: 'にんじん',
      category: CostumeCategory.free,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/05_carrot.png',
      thumbnailPath: 'assets/costumes/thumb_05_carrot.png',
      sortOrder: 14,
      defaultScale: 0.12,
    ),
    Costume(
      id: 'seeds',
      name: 'たね',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/06_seeds.png',
      thumbnailPath: 'assets/costumes/thumb_06_seeds.png',
      sortOrder: 15,
      defaultScale: 0.12,
    ),
    Costume(
      id: 'feathers',
      name: '羽',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/07_feathers.png',
      thumbnailPath: 'assets/costumes/thumb_07_feathers.png',
      sortOrder: 16,
      defaultScale: 0.12,
    ),
    Costume(
      id: 'rabbit',
      name: 'うさぎ',
      category: CostumeCategory.free,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/08_rabbit.png',
      thumbnailPath: 'assets/costumes/thumb_08_rabbit.png',
      sortOrder: 17,
      defaultScale: 0.15,
    ),
    Costume(
      id: 'cat_calico',
      name: '三毛猫',
      category: CostumeCategory.free,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/09_cat_calico.png',
      thumbnailPath: 'assets/costumes/thumb_09_cat_calico.png',
      sortOrder: 18,
      defaultScale: 0.15,
    ),
    Costume(
      id: 'paw_charm',
      name: '肉球チャーム',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/10_paw_charm.png',
      thumbnailPath: 'assets/costumes/thumb_10_paw_charm.png',
      sortOrder: 19,
      defaultScale: 0.10,
    ),
    Costume(
      id: 'fish',
      name: 'おさかな',
      category: CostumeCategory.free,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/11_fish.png',
      thumbnailPath: 'assets/costumes/thumb_11_fish.png',
      sortOrder: 20,
      defaultScale: 0.12,
    ),
    Costume(
      id: 'cat_orange',
      name: '茶トラ',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/12_cat_orange.png',
      thumbnailPath: 'assets/costumes/thumb_12_cat_orange.png',
      sortOrder: 21,
      defaultScale: 0.15,
    ),
    Costume(
      id: 'dog_dalmatian',
      name: 'ダルメシアン',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/13_dog_dalmation.png',
      thumbnailPath: 'assets/costumes/thumb_13_dog_dalmation.png',
      sortOrder: 22,
      defaultScale: 0.15,
    ),
    Costume(
      id: 'duck',
      name: 'あひる',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/14_duck.png',
      thumbnailPath: 'assets/costumes/thumb_14_duck.png',
      sortOrder: 23,
      defaultScale: 0.15,
    ),
    Costume(
      id: 'frog',
      name: 'カエル',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/15_frog.png',
      thumbnailPath: 'assets/costumes/thumb_15_frog.png',
      sortOrder: 24,
      defaultScale: 0.15,
    ),
    Costume(
      id: 'dog_spot',
      name: 'ぶち犬',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/16_dog_spot.png',
      thumbnailPath: 'assets/costumes/thumb_16_dog_spot.png',
      sortOrder: 25,
      defaultScale: 0.15,
    ),
    Costume(
      id: 'soccer',
      name: 'サッカーボール',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/17_soccer_ball.png',
      thumbnailPath: 'assets/costumes/thumb_17_soccer_ball.png',
      sortOrder: 26,
      defaultScale: 0.12,
    ),
    Costume(
      id: 'beehive',
      name: 'はちの巣',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/18_beehive.png',
      thumbnailPath: 'assets/costumes/thumb_18_beehive.png',
      sortOrder: 27,
      defaultScale: 0.15,
    ),
    Costume(
      id: 'sushi',
      name: 'おすし',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/19_sushi.png',
      thumbnailPath: 'assets/costumes/thumb_19_sushi.png',
      sortOrder: 28,
      defaultScale: 0.12,
    ),
    Costume(
      id: 'cat_golden',
      name: '金猫',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/20_cat_golden.png',
      thumbnailPath: 'assets/costumes/thumb_20_cat_golden.png',
      sortOrder: 29,
      defaultScale: 0.15,
    ),
    Costume(
      id: 'broccoli',
      name: 'ブロッコリー',
      category: CostumeCategory.premium,
      type: CostumeType.stamp,
      assetPath: 'assets/costumes/21_broccoli.png',
      thumbnailPath: 'assets/costumes/thumb_21_broccoli.png',
      sortOrder: 30,
      defaultScale: 0.12,
    ),

    // === C: 顔ハメパネル（defaultScale = 描画倍率） ===
    Costume(
      id: 'gakuran',
      name: '学ラン',
      category: CostumeCategory.free,
      type: CostumeType.outfit,
      assetPath: 'assets/costumes/gakuran.png',
      thumbnailPath: 'assets/costumes/thumb_gakuran.png',
      sortOrder: 40,
      defaultScale: 2.1,
    ),
    Costume(
      id: 'sailor',
      name: 'セーラー服',
      category: CostumeCategory.free,
      type: CostumeType.outfit,
      assetPath: 'assets/costumes/sailor.png',
      thumbnailPath: 'assets/costumes/thumb_sailor.png',
      sortOrder: 41,
      defaultScale: 1.9,
    ),
    Costume(
      id: 'kimono',
      name: '着物',
      category: CostumeCategory.premium,
      type: CostumeType.outfit,
      assetPath: 'assets/costumes/kimono.png',
      thumbnailPath: 'assets/costumes/thumb_kimono.png',
      sortOrder: 42,
      defaultScale: 3.5,
    ),
    Costume(
      id: 'tuxedo',
      name: 'タキシード',
      category: CostumeCategory.premium,
      type: CostumeType.outfit,
      assetPath: 'assets/costumes/tuxedo.png',
      thumbnailPath: 'assets/costumes/thumb_tuxedo.png',
      sortOrder: 43,
      defaultScale: 2.5,
    ),
    Costume(
      id: 'pirate',
      name: '海賊',
      category: CostumeCategory.premium,
      type: CostumeType.outfit,
      assetPath: 'assets/costumes/pirate.png',
      thumbnailPath: 'assets/costumes/thumb_pirate.png',
      sortOrder: 44,
      defaultScale: 3.0,
    ),
    Costume(
      id: 'police',
      name: '警察官',
      category: CostumeCategory.premium,
      type: CostumeType.outfit,
      assetPath: 'assets/costumes/police.png',
      thumbnailPath: 'assets/costumes/thumb_police.png',
      sortOrder: 45,
      defaultScale: 2.5,
    ),
    Costume(
      id: 'fire',
      name: '消防士',
      category: CostumeCategory.premium,
      type: CostumeType.outfit,
      assetPath: 'assets/costumes/fire.png',
      thumbnailPath: 'assets/costumes/thumb_fire.png',
      sortOrder: 46,
      defaultScale: 2.5,
    ),
    Costume(
      id: 'astro',
      name: '宇宙飛行士',
      category: CostumeCategory.premium,
      type: CostumeType.outfit,
      assetPath: 'assets/costumes/astro.png',
      thumbnailPath: 'assets/costumes/thumb_astro.png',
      sortOrder: 47,
      defaultScale: 2.5,
    ),
    Costume(
      id: 'angel',
      name: '天使',
      category: CostumeCategory.premium,
      type: CostumeType.outfit,
      assetPath: 'assets/costumes/angel.png',
      thumbnailPath: 'assets/costumes/thumb_angel.png',
      sortOrder: 48,
      defaultScale: 2.5,
    ),
    Costume(
      id: 'santa',
      name: 'サンタクロース',
      category: CostumeCategory.premium,
      type: CostumeType.outfit,
      assetPath: 'assets/costumes/santa.png',
      thumbnailPath: 'assets/costumes/thumb_santa.png',
      sortOrder: 49,
      defaultScale: 2.5,
    ),
  ];

  /// 無料コスチュームだけを返す
  static List<Costume> get freeOnly =>
      all.where((c) => c.isFree).toList();

  /// プレミアムコスチュームだけを返す
  static List<Costume> get premiumOnly =>
      all.where((c) => c.isPremium).toList();

  /// タイプ別に返す
  static List<Costume> byType(CostumeType type) =>
      all.where((c) => c.type == type).toList();

  /// IDからコスチュームを取得（見つからなければ帽子をデフォルト返却）
  static Costume findById(String id) {
    return all.firstWhere(
      (c) => c.id == id,
      orElse: () => all.first,
    );
  }
}
