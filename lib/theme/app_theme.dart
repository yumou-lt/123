// ============================================================
// 应用主题：QQ 风 —— 白底 / 黑字做区分 / 蓝(0xFF1296DB)作辅助色
// 简约干净、导航栏小巧、按设备宽度自适应
// ============================================================

import 'package:flutter/material.dart';

class AppTheme {
  // ---------- 浅色基础色板 ----------
  static const Color kWhite = Color(0xFFFFFFFF);
  static const Color kBlack = Color(0xFF1A1A1A);      // 主文字 / 区分主色（近黑，比纯黑柔和）
  static const Color kSubText = Color(0xFF8A9099);     // 次级文字（时间、说明）
  static const Color kSubText2 = Color(0xFFB4BAC1);    // 更弱的文字
  static const Color kLightBlack = Color(0xFF8A9099);   // 兼容旧引用（= kSubText）
  static const Color kDivider = Color(0xFFEDEEF0);     // 浅分割线
  static const Color kSurface = Color(0xFFF5F6F8);     // 局部浅灰底（列表/卡片间隙）
  static const Color kHover = Color(0xFFF2F3F5);       // 列表项按压底色

  // ---------- 品牌蓝（辅助色） ----------
  static const Color kAccent = Color(0xFF1296DB);      // QQ 蓝：选中态、链接、主按钮
  static const Color kAccentSoft = Color(0xFFEAF4FD);  // 蓝的浅底：我方消息气泡
  static const Color kAccentBorder = Color(0xFFC9E6F8);// 蓝的浅描边

  // ---------- 红：未读 / 重点提示 ----------
  static const Color kBadge = Color(0xFFF5222D);       // 未读消息红点
  static const Color kWarn = Color(0xFFFA5151);        // 撤回 / 危险操作

  // ---------- 深色（保持统一蓝色） ----------
  static const Color kDarkBg = Color(0xFF121212);
  static const Color kDarkSurface = Color(0xFF1E1E1E);
  static const Color kDarkText = Color(0xFFE6E6E6);
  static const Color kDarkSubText = Color(0xFF888888);
  static const Color kDarkBorder = Color(0x33FFFFFF);

  // ---------- 响应式辅助 ----------
  /// 内容最大宽度：平板/大屏居中收窄，手机铺满
  static double contentMaxWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w > 900) return 680;
    if (w > 600) return 560;
    return double.infinity;
  }

  /// 列表左右内边距：大屏留白更多
  static double listHorizontalPadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w > 600) return 24;
    return 0;
  }

  /// 聊天区左右内边距（随设备缩放）
  static double chatHorizontalPadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w > 600) return 24;
    return 12;
  }

  // ---------- 浅色 ThemeData ----------
  static ThemeData get light {
    const bg = kWhite;
    const text = kBlack;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      primaryColor: kAccent,
      colorScheme: const ColorScheme.light(
        primary: kAccent,
        onPrimary: kWhite,
        surface: bg,
        onSurface: text,
        error: kWarn,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: text, size: 22),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kWarn, width: 1),
        ),
        hintStyle: const TextStyle(color: kSubText),
        labelStyle: const TextStyle(color: kSubText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccent,
          foregroundColor: kWhite,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kBlack,
          side: const BorderSide(color: kDivider, width: 1),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kAccent,
          textStyle: const TextStyle(fontSize: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: kDivider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        minLeadingWidth: 0,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: text, fontSize: 15),
        bodyMedium: TextStyle(color: text, fontSize: 14),
        titleLarge: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(color: text, fontSize: 14),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: kAccent),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w600),
        contentTextStyle: const TextStyle(color: text, fontSize: 14),
      ),
    );
  }

  // ---------- 深色 ThemeData ----------
  static ThemeData get dark {
    const text = kDarkText;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kDarkBg,
      primaryColor: kAccent,
      colorScheme: const ColorScheme.dark(
        primary: kAccent,
        onPrimary: kWhite,
        surface: kDarkSurface,
        onSurface: text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kDarkSurface,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kDarkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAccent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: kDarkSubText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccent,
          foregroundColor: kWhite,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: kDarkBorder, thickness: 1, space: 1),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: text, fontSize: 15),
        bodyMedium: TextStyle(color: text, fontSize: 14),
        titleLarge: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(color: text, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: kDarkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: kDarkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
