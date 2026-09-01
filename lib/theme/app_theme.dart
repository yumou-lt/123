// ============================================================
// 应用主题：严格白底黑字黑线条极简风，无任何彩色
// ============================================================

import 'package:flutter/material.dart';

class AppTheme {
  // 浅色常量
  static const Color kWhite = Color(0xFFFFFFFF);
  static const Color kBlack = Color(0xFF000000);
  static const Color kLightBlack = Color(0xFF999999);
  static const Color kDivider = Color(0x1A000000);

  // 深色常量
  static const Color kDarkBg = Color(0xFF121212);
  static const Color kDarkSurface = Color(0xFF1E1E1E);
  static const Color kDarkText = Color(0xFFE0E0E0);
  static const Color kDarkSubText = Color(0xFF888888);
  static const Color kDarkBorder = Color(0x33FFFFFF);

  // 品牌蓝（两种主题共用）
  static const Color kPrimaryBlue = Color(0xFF2196F3);

  // ThemeData
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: kWhite,
      colorScheme: const ColorScheme.light(
        primary: kBlack,
        onPrimary: kWhite,
        surface: kWhite,
        onSurface: kBlack,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kWhite,
        foregroundColor: kBlack,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: kBlack,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBlack, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBlack, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBlack, width: 1),
        ),
        hintStyle: const TextStyle(color: kLightBlack),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kBlack,
          foregroundColor: kWhite,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kBlack,
          side: const BorderSide(color: kBlack, width: 1),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: kDivider,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: kBlack, fontSize: 15),
        bodyMedium: TextStyle(color: kBlack, fontSize: 14),
        titleLarge: TextStyle(color: kBlack, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: kBlack, fontSize: 16, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(color: kBlack, fontSize: 14),
      ),
    );
  }

  // ThemeData - 深色
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kDarkBg,
      colorScheme: const ColorScheme.dark(
        primary: kPrimaryBlue,
        surface: kDarkSurface,
        onSurface: kDarkText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kDarkSurface,
        foregroundColor: kDarkText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: kDarkText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kDarkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kDarkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kDarkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimaryBlue, width: 1),
        ),
        hintStyle: const TextStyle(color: kDarkSubText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
          foregroundColor: kWhite,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: kDarkBorder,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: kDarkText, fontSize: 15),
        bodyMedium: TextStyle(color: kDarkText, fontSize: 14),
        titleLarge: TextStyle(color: kDarkText, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: kDarkText, fontSize: 16, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(color: kDarkText, fontSize: 14),
      ),
    );
  }
}
