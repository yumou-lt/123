// ============================================================
// 登录页：用自增ID + 密码登录
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/services/ws_service.dart';
import 'package:chat_app/pages/register_page.dart';
import 'package:chat_app/pages/main_page.dart';
import 'package:chat_app/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _pwdController = TextEditingController();
  bool _loading = false;
  bool _obscurePwd = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final resp = await ApiService().login(
        userId: int.parse(_idController.text.trim()),
        password: _pwdController.text.trim(),
      );

      if (resp['code'] == 0) {
        final data = resp['data'];
        await StorageService.saveToken(data['token']);
        await StorageService.saveUserId(data['userId']);
        await StorageService.saveNickname(data['nickname']);
        await StorageService.saveAvatar(data['avatar'] ?? '');

        if (mounted) {
          // 连接 WebSocket
          await WsService().connect();
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainPage()),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resp['message'] ?? '登录失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络错误，请检查服务器连接')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ---------- 背景图 ----------
          Positioned.fill(
            child: Image.asset(
              'assets/bg_reim.png',
              fit: BoxFit.cover,
            ),
          ),
          // ---------- 半透明遮罩（让上面的字看清） ----------
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),
          // ---------- 表单 ----------
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 蕾姆小头像
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/bg_reim.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '冷亭雨',
                          style: TextStyle(
                            color: AppTheme.kBlack,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '仅供娱乐学习 如有违法行为立即删除',
                          style: TextStyle(color: AppTheme.kLightBlack, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _idController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '用户ID（数字）',
                            hintText: '请输入你的登录ID',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return '请输入用户ID';
                            if (!RegExp(r'^\d+$').hasMatch(v)) return 'ID必须是数字';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _pwdController,
                          obscureText: _obscurePwd,
                          decoration: InputDecoration(
                            labelText: '密码',
                            hintText: '请输入密码',
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePwd ? Icons.visibility_off : Icons.visibility,
                                  color: AppTheme.kBlack),
                              onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty ? '请输入密码' : null,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: AppTheme.kWhite, strokeWidth: 2),
                                )
                              : const Text('登录'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RegisterPage()),
                            );
                          },
                          child: const Text('没有账号？去注册', style: TextStyle(color: AppTheme.kBlack)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
