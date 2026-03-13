import 'package:flutter/material.dart';

/// アプリ全体のカラーパレット
abstract final class AppColors {
  // Primary（朱赤）/ Secondary（免許ブルー）
  static const primary = Color(0xFFD94032);
  static const primaryLight = Color(0xFFE8756A);
  static const primaryDark = Color(0xFFB02A20);
  static const secondary = Color(0xFF5B8FA8);
  static const secondaryLight = Color(0xFF8BB8CC);
  static const secondaryDark = Color(0xFF3D6B80);

  // Background（公文書クリーム）/ Surface
  static const background = Color(0xFFFFFDF5);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFFFF5E8);

  // Accent（レトロゴールド）
  static const accent = Color(0xFFC9A84C);
  static const accentDark = Color(0xFFA08530);

  // Text（墨色）
  static const textDark = Color(0xFF2C2C2C);
  static const textMedium = Color(0xFF607D8B);
  static const textLight = Color(0xFFB0BEC5);

  // Status
  static const success = Color(0xFF66BB6A);
  static const warning = Color(0xFFFFA726);
  static const error = Color(0xFFEF5350);

  // --- 免許証テンプレート専用 ---
  static const licenseRetroBlue = Color(0xFFB3D4E0);
  static const licenseSealRed = Color(0xFFC62828);
  static const licenseBackground = Color(0xFFF5F0E8);

  // フレーム色
  static const frameGold = Color(0xFFFFD700);
  static const frameSilver = Color(0xFFC0C0C0);
  static const frameBlue = Color(0xFF64B5F6);
  static const framePink = Color(0xFFF48FB1);
  static const frameGreen = Color(0xFF81C784);
}
