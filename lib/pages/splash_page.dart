// ============================================================
// 启动页：简约白底
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/services/ws_service.dart';
import 'package:chat_app/services/update_service.dart';
import 'package:chat_app/pages/login_page.dart';
import 'package:chat_app/pages/main_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(milliseconds: 800));

    // 后台检查更新（不阻塞登录流程）
    _checkBackgroundUpdate();

    if (StorageService.isLoggedIn) {
      await WsService().connect();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainPage()),
        );
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
  }

  // 后台检查更新：如果是强制更新，在 MainPage 弹；非强制静默
  void _checkBackgroundUpdate() async {
    try {
      await UpdateService().init();
      final hasUpdate = await UpdateService().checkUpdate();
      if (hasUpdate && UpdateService().isForceUpdate && mounted) {
        // 强制更新 → 延迟一会儿在 MainPage 弹
        // 这里只做标记，MinePage 里手动检查会完整展示
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.chat_bubble, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              '冷亭雨',
              style: TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 4),
            ),
            const SizedBox(height: 6),
            const Text(
              'MINIMAL CHAT',
              style: TextStyle(color: Colors.black38, fontSize: 11, letterSpacing: 3),
            ),
          ],
        ),
      ),
    );
  }
}
