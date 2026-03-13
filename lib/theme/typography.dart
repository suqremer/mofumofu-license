import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// アプリ全体のタイポグラフィ
abstract final class AppTypography {
  // --- アプリ UI 用（Zen Maru Gothic + Noto Sans JP） ---
  static TextStyle get headingLarge => GoogleFonts.zenMaruGothic(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
    height: 1.3,
  );

  static TextStyle get headingMedium => GoogleFonts.zenMaruGothic(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
    height: 1.3,
  );

  static TextStyle get headingSmall => GoogleFonts.zenMaruGothic(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    height: 1.3,
  );

  static TextStyle get bodyLarge => GoogleFonts.notoSansJp(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textDark,
    height: 1.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.notoSansJp(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textDark,
    height: 1.5,
  );

  static TextStyle get caption => GoogleFonts.notoSansJp(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    height: 1.4,
  );

  static TextStyle get buttonText => GoogleFonts.notoSansJp(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  // --- 免許証テンプレート用（公文書風）--- 変更しない ---
  static const licenseTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    letterSpacing: 4.0,
  );

  static const licenseField = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    letterSpacing: 1.0,
  );

  static const licenseValue = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    letterSpacing: 0.5,
  );

  static const licenseNumber = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
    fontFamily: 'monospace',
    letterSpacing: 2.0,
  );

  static const licenseSeal = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    color: AppColors.licenseSealRed,
  );
}
