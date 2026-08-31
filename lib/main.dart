// ============================================================
// 极简文字聊天IM 安卓端入口
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/theme/app_theme.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/ws_service.dart';
import 'package:chat_app/pages/splash_page.dart';
import 'package:chat_app/pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化服务
  await StorageService.init();
  ApiService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '冷亭雨',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashPage(),
      routes: {
        '/login': (_) => const LoginPage(),
      },
    );
  }
}
