import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// App Typography System
/// Uses Plus Jakarta Sans for Latin text and Amiri for Arabic
class AppTypography {
  AppTypography._();

  // Font Families
  static String get primaryFontFamily =>
      GoogleFonts.plusJakartaSans().fontFamily!;
  static String get arabicFontFamily => GoogleFonts.amiri().fontFamily!;

  // Display Styles (Headers, Hero sections)
  static TextStyle displayLarge(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 57,
    fontWeight: FontWeight.bold,
    height: 1.1,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  static TextStyle displayMedium(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 45,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  static TextStyle displaySmall(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  // Heading Styles
  static TextStyle headingLarge(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  static TextStyle headingMedium(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  static TextStyle headingSmall(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  // Body Styles
  static TextStyle bodyLarge(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  static TextStyle bodyMedium(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  static TextStyle bodySmall(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
  );

  // Label Styles
  static TextStyle labelLarge(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  static TextStyle labelMedium(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
  );

  static TextStyle labelSmall(bool isDark) => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
  );

  // Arabic Text Styles - Optimized for Quranic text
  static TextStyle arabicLarge(bool isDark) => GoogleFonts.amiri(
    fontSize: 28,
    fontWeight: FontWeight.normal,
    height: 2.2,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  static TextStyle arabicMedium(bool isDark) => GoogleFonts.amiri(
    fontSize: 24,
    fontWeight: FontWeight.normal,
    height: 2.0,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  static TextStyle arabicSmall(bool isDark) => GoogleFonts.amiri(
    fontSize: 20,
    fontWeight: FontWeight.normal,
    height: 2.0,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );

  // Arabic Counter (for Tasbih)
  static TextStyle arabicCounter(bool isDark) => GoogleFonts.amiri(
    fontSize: 72,
    fontWeight: FontWeight.bold,
    height: 1.0,
    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
  );
}
