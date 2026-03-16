import 'package:flutter/material.dart';

/// フレーム色の定義
///
/// 免許証の外枠カラー。LicenseCard.frameColor と ID で紐づく。
class FrameColor {
  final String id;
  final String label;
  final Color color;
  final Color textColor; // フレーム上の文字色
  final bool isPremium;

  const FrameColor({
    required this.id,
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.isPremium = false,
  });

  /// 全フレーム色の定義
  static const List<FrameColor> all = [
    // === 無料 ===
    FrameColor(
      id: 'black',
      label: 'ブラック',
      color: Color(0xFF2C2C2C),
    ),
    FrameColor(
      id: 'blue',
      label: 'ブルー',
      color: Color(0xFF1E90FF),
    ),
    // === プレミアム ===
    FrameColor(
      id: 'gold',
      label: 'ゴールド',
      color: Color(0xFFD4A017),
      isPremium: true,
    ),
    FrameColor(
      id: 'silver',
      label: 'シルバー',
      color: Color(0xFFC0C0C0),
      textColor: Color(0xFF333333),
      isPremium: true,
    ),
    FrameColor(
      id: 'rose_gold',
      label: 'ローズゴールド',
      color: Color(0xFFB76E79),
      isPremium: true,
    ),
    FrameColor(
      id: 'holographic',
      label: 'ホログラム',
      color: Color(0xFF88DDFF), // 代表色（実際はグラデーション描画）
      isPremium: true,
    ),
  ];

  /// 無料フレーム色だけを返す
  static List<FrameColor> get freeOnly =>
      all.where((c) => !c.isPremium).toList();

  /// IDからフレーム色を取得（見つからなければゴールドをデフォルト返却）
  static FrameColor findById(String id) {
    return all.firstWhere(
      (c) => c.id == id,
      orElse: () => all.first, // gold
    );
  }
}

/// 免許種別の定義
///
/// LicenseCard.licenseType と id で紐づく。
/// 動物の種類に合った免許タイトルを提供する。
class LicenseType {
  final String id;
  final String label; // 免許証に印字される名称
  final String description; // UI説明文
  final String targetSpecies; // 対象の動物種（'all' は全種共通）
  final bool isPremium;

  const LicenseType({
    required this.id,
    required this.label,
    this.description = '',
    this.targetSpecies = 'all',
    this.isPremium = false,
  });

  /// 全免許種別の定義
  static const List<LicenseType> all = [
    // === 無料 ===
    LicenseType(
      id: 'nyanten',
      label: 'にゃん転免許',
      description: '猫ちゃん向けの基本免許',
      targetSpecies: '猫',
    ),
    LicenseType(
      id: 'wanten',
      label: 'わん転免許',
      description: 'ワンちゃん向けの基本免許',
      targetSpecies: '犬',
    ),
    LicenseType(
      id: 'mofumofu',
      label: 'うちの子免許',
      description: '全動物対応の基本免許',
      targetSpecies: 'all',
    ),
    // === プレミアム ===
    LicenseType(
      id: 'kokusai',
      label: 'うちの子国際免許',
      description: '国際仕様のスペシャル免許',
      targetSpecies: 'all',
      isPremium: true,
    ),
    LicenseType(
      id: 'gold_menky',
      label: 'ゴールド免許',
      description: '優良ペットのゴールド免許',
      targetSpecies: 'all',
      isPremium: true,
    ),
  ];

  /// 無料の免許種別だけを返す
  static List<LicenseType> get freeOnly =>
      all.where((t) => !t.isPremium).toList();

  /// 指定した動物種に合った免許種別を返す（'all' 対象も含む）
  static List<LicenseType> forSpecies(String species) {
    return all
        .where((t) => t.targetSpecies == 'all' || t.targetSpecies == species)
        .toList();
  }

  /// IDから免許種別を取得（見つからなければ「うちの子免許」をデフォルト返却）
  static LicenseType findById(String id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => all.firstWhere((t) => t.id == 'mofumofu'),
    );
  }
}

/// テンプレートタイプ（国別レイアウト）
enum TemplateType {
  japan('japan', '日本風'),
  usa('usa', '海外風');

  final String id;
  final String label;
  const TemplateType(this.id, this.label);

  /// 文字列IDから enum を取得
  static TemplateType fromId(String id) {
    return TemplateType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => TemplateType.japan,
    );
  }
}

/// 免許証テンプレート設定
///
/// テンプレートタイプごとのレイアウト情報をまとめたモデル。
/// Canvas 描画時にこの値を参照してレイアウトを決定する。
class LicenseTemplate {
  final TemplateType type;

  /// 免許証画像の出力サイズ（ピクセル）
  final Size outputSize;

  /// 写真エリアの位置・サイズ（outputSize に対する比率 0.0〜1.0）
  final Rect photoRectRatio;

  /// 発行元テキスト
  final String issuerText;

  /// 公安委員会テキスト（ヘッダー）
  final String headerText;

  /// 有効期限テキスト
  final String validityText;

  /// 条件テキスト
  final String conditionText;

  const LicenseTemplate({
    required this.type,
    required this.outputSize,
    required this.photoRectRatio,
    required this.issuerText,
    required this.headerText,
    this.validityText = '',
    this.conditionText = '',
  });

  /// 日本風テンプレート
  ///
  /// なめ猫オマージュの免許証レイアウト。
  /// 出力サイズは一般的な免許証比率（横:縦 = 約 85.6:54mm → 1024:646px）
  static const LicenseTemplate japan = LicenseTemplate(
    type: TemplateType.japan,
    outputSize: Size(1024, 646),
    // 右側中段に写真を配置（_paintJapanTemplate の 722,167,290,372 と一致）
    photoRectRatio: Rect.fromLTWH(722 / 1024, 167 / 646, 290 / 1024, 372 / 646),
    issuerText: 'うちの子免許センター',
    headerText: 'うちの子公安委員会',
    validityText: 'うたた寝するまで有効',
    conditionText: '魚のアプリをDLしない事',
  );

  /// 海外風テンプレート
  ///
  /// アメリカンなドライバーズライセンス風レイアウト。
  static const LicenseTemplate usa = LicenseTemplate(
    type: TemplateType.usa,
    outputSize: Size(1024, 646),
    // 左側に写真を配置（_paintUsaTemplate の 30,110,280,400 と一致）
    photoRectRatio: Rect.fromLTWH(30 / 1024, 110 / 646, 280 / 1024, 400 / 646),
    issuerText: 'MOFUMOFU LICENSE CENTER',
    headerText: 'STATE OF MOFUMOFU',
    validityText: 'Valid until nap time',
    conditionText: 'Must not download fish apps',
  );

  /// テンプレートタイプから定義を取得
  static LicenseTemplate fromType(TemplateType type) {
    switch (type) {
      case TemplateType.japan:
        return japan;
      case TemplateType.usa:
        return usa;
    }
  }

  /// 文字列IDからテンプレートを取得
  static LicenseTemplate fromId(String id) {
    return fromType(TemplateType.fromId(id));
  }

  /// photoRectRatio を実ピクセルの Rect に変換
  Rect get photoRect => Rect.fromLTWH(
        photoRectRatio.left * outputSize.width,
        photoRectRatio.top * outputSize.height,
        photoRectRatio.width * outputSize.width,
        photoRectRatio.height * outputSize.height,
      );
}

/// 有効期限テキストの選択肢
///
/// ユーザーがフレーム選択画面で選ぶ「○○まで有効」のユーモアテキスト。
/// 日本風・海外風テンプレートそれぞれに対応するテキストを持つ。
class ValidityOption {
  final String id;
  final String text; // 日本語（表示・日本風テンプレート用）
  final String usaText; // 英語（海外風テンプレート用）

  const ValidityOption({
    required this.id,
    required this.text,
    required this.usaText,
  });

  /// テンプレートタイプに応じたテキストを返す
  String textForTemplate(TemplateType type) {
    return type == TemplateType.usa ? usaText : text;
  }

  /// 全選択肢
  static const List<ValidityOption> all = [
    ValidityOption(
      id: 'nap',
      text: 'うたた寝するまで有効',
      usaText: 'UNTIL NAP TIME',
    ),
    ValidityOption(
      id: 'snack',
      text: 'おやつが届くまで有効',
      usaText: 'UNTIL TREATS ARRIVE',
    ),
    ValidityOption(
      id: 'paw',
      text: '肉球ぷにぷにの間有効',
      usaText: 'WHILE PAWS SQUISHY',
    ),
    ValidityOption(
      id: 'fluffy',
      text: 'もふもふし放題',
      usaText: 'UNLIMITED FLUFF',
    ),
    ValidityOption(
      id: 'forever',
      text: 'ずっと有効',
      usaText: 'FUREVER',
    ),
  ];

  /// IDから取得（見つからなければ最初の選択肢を返す）
  static ValidityOption findById(String id) {
    return all.firstWhere((v) => v.id == id, orElse: () => all.first);
  }
}

/// 特技の選択肢（動物種ごとに定義）
///
/// 選択すると対応する「免許の条件等」テキストが自動生成される。
/// 「自分で書く」を選ぶと自由入力モードになる。
class SpecialtyOption {
  final String id;
  final String label;        // 特技名（表示用）
  final String conditionText; // 条件テキスト1行目

  const SpecialtyOption({
    required this.id,
    required this.label,
    required this.conditionText,
  });

  /// 「自分で書く」オプション
  static const custom = SpecialtyOption(
    id: 'custom',
    label: '自分で書く',
    conditionText: '',
  );

  /// 動物種ごとの選択肢を返す
  static List<SpecialtyOption> forSpecies(String species) {
    if (species.contains('猫')) return _cat;
    if (species.contains('犬')) return _dog;
    if (species.contains('うさぎ')) return _rabbit;
    if (species.contains('ハムスター')) return _hamster;
    if (species.contains('鳥')) return _bird;
    return _other;
  }

  static const _cat = [
    SpecialtyOption(id: 'purr', label: 'ゴロゴロ', conditionText: 'ゴロゴロしながら運転しない事'),
    SpecialtyOption(id: 'groom', label: '毛づくろい', conditionText: '毛づくろい中はハンドルを離さない事'),
    SpecialtyOption(id: 'zoomies', label: '夜の運動会', conditionText: '深夜の暴走運転は禁止する事'),
    SpecialtyOption(id: 'liquid', label: '液体化', conditionText: '液体化して座席から流れない事'),
    SpecialtyOption(id: 'box', label: '箱入り', conditionText: '段ボールに入ったまま運転しない事'),
  ];

  static const _dog = [
    SpecialtyOption(id: 'shake', label: 'おて', conditionText: 'おてでハンドルを叩かない事'),
    SpecialtyOption(id: 'fetch', label: 'ボール遊び', conditionText: 'ボールを追って車線変更しない事'),
    SpecialtyOption(id: 'dig', label: '穴掘り', conditionText: '車内で穴を掘らない事'),
    SpecialtyOption(id: 'tail', label: 'しっぽ振り', conditionText: 'しっぽでウインカーを操作しない事'),
    SpecialtyOption(id: 'wait', label: 'おすわり', conditionText: '信号待ちでおすわりしすぎない事'),
  ];

  static const _rabbit = [
    SpecialtyOption(id: 'binky', label: 'ビンキー', conditionText: 'ビンキーで跳ねて屋根に頭をぶつけない事'),
    SpecialtyOption(id: 'dig_r', label: 'ほりほり', conditionText: 'シートをほりほりしない事'),
    SpecialtyOption(id: 'chin', label: 'あごすりすり', conditionText: 'ハンドルにマーキングしない事'),
    SpecialtyOption(id: 'flop', label: 'ごろん', conditionText: '運転中にごろんと寝転がらない事'),
    SpecialtyOption(id: 'stand', label: 'うたっち', conditionText: 'うたっちでペダルを踏まない事'),
  ];

  static const _hamster = [
    SpecialtyOption(id: 'wheel', label: '回し車', conditionText: '回し車感覚でハンドルを回さない事'),
    SpecialtyOption(id: 'cheek', label: 'ほお袋', conditionText: 'ほお袋におやつを詰めながら運転しない事'),
    SpecialtyOption(id: 'escape', label: '脱走', conditionText: '走行中に脱走しない事'),
    SpecialtyOption(id: 'hide', label: 'かくれんぼ', conditionText: 'ダッシュボードの裏に隠れない事'),
    SpecialtyOption(id: 'store', label: 'ため込み', conditionText: '車内にエサをため込まない事'),
  ];

  static const _bird = [
    SpecialtyOption(id: 'sing', label: 'さえずり', conditionText: 'さえずりでカーナビの音をかき消さない事'),
    SpecialtyOption(id: 'fly', label: '飛行', conditionText: '窓を開けて飛び立たない事'),
    SpecialtyOption(id: 'mimic', label: 'ものまね', conditionText: 'クラクションのものまねをしない事'),
    SpecialtyOption(id: 'preen', label: '羽づくろい', conditionText: '羽づくろい中は前を見る事'),
    SpecialtyOption(id: 'head', label: 'カキカキ', conditionText: '頭カキカキでよそ見しない事'),
  ];

  static const _other = [
    SpecialtyOption(id: 'nap', label: 'おひるね', conditionText: '運転中におひるねしない事'),
    SpecialtyOption(id: 'eat', label: 'もぐもぐ', conditionText: 'もぐもぐしながら運転しない事'),
    SpecialtyOption(id: 'play', label: 'あそび', conditionText: '遊びに夢中で運転を忘れない事'),
    SpecialtyOption(id: 'cuddle', label: 'あまえ', conditionText: 'あまえて運転をサボらない事'),
    SpecialtyOption(id: 'explore', label: 'たんけん', conditionText: 'たんけん中に道を間違えない事'),
  ];
}
