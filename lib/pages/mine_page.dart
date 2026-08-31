// ============================================================
// 我的 Tab：个人信息 + 退出登录
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/services/ws_service.dart';
import 'package:chat_app/pages/edit_profile_page.dart';
import 'package:chat_app/pages/login_page.dart';
import 'package:chat_app/pages/user_agreement_page.dart';
import 'package:chat_app/theme/app_theme.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  String _nickname = '';
  String _avatar = '';
  int? _userId;
  bool _agreementAck = false;

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  void _loadLocal() {
    setState(() {
      _nickname = StorageService.getNickname() ?? '';
      _avatar = StorageService.getAvatar() ?? '';
      _userId = StorageService.getUserId();
      _agreementAck = StorageService.agreementAcknowledged;
    });
  }

  Future<void> _refreshFromServer() async {
    try {
      final resp = await ApiService().getProfile();
      if (resp['code'] == 0) {
        final d = resp['data'];
        await StorageService.saveNickname(d['nickname'] ?? '');
        await StorageService.saveAvatar(d['avatar'] ?? '');
        _loadLocal();
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.kWhite,
        title: const Text('退出登录', style: TextStyle(color: AppTheme.kBlack)),
        content: const Text('确定要退出登录吗？', style: TextStyle(color: AppTheme.kBlack)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消', style: TextStyle(color: AppTheme.kBlack))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定', style: TextStyle(color: AppTheme.kBlack))),
        ],
      ),
    );
    if (confirm == true) {
      await WsService().disconnect();
      await StorageService.clearAll();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        children: [
          // 头部资料
          Container(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                  ),
                  child: _avatar.isNotEmpty
                      ? ClipOval(child: Image.network(GlobalConfig.avatarUrl(_avatar), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.black54, size: 36)))
                      : const Icon(Icons.person, color: Colors.black54, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_nickname, style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('ID: $_userId', style: const TextStyle(color: Colors.black38, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 菜单
          Column(
            children: [
              _buildItem(Icons.person, '编辑资料', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage())).then((_) => _refreshFromServer());
              }),
              _buildDivider(),
              _buildItem(Icons.lock_outline, '修改密码', () => _showChangePwdDialog()),
              _buildDivider(),
              _buildItem(
                _agreementAck ? Icons.verified_user : Icons.gavel,
                '用户守则',
                () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserAgreementPage()));
                  _loadLocal();
                },
                highlight: !_agreementAck,
              ),
            ],
          ),
          const SizedBox(height: 32),
          // 退出登录
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black12, width: 0.5),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('退出登录', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(height: 1, color: Colors.black.withOpacity(0.06)),
    );
  }

  Widget _buildItem(IconData icon, String label, VoidCallback onTap, {bool highlight = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: highlight ? Colors.red : Colors.black54, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(color: highlight ? Colors.red : Colors.black, fontSize: 15))),
            if (highlight)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('未确认', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
          ],
        ),
      ),
    );
  }

  void _showChangePwdDialog() {
    final oldPwd = TextEditingController();
    final newPwd = TextEditingController();
    final confirmPwd = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.kWhite,
        title: const Text('修改密码', style: TextStyle(color: AppTheme.kBlack)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPwd, obscureText: true, decoration: const InputDecoration(labelText: '旧密码', labelStyle: TextStyle(color: AppTheme.kBlack))),
            TextField(controller: newPwd, obscureText: true, decoration: const InputDecoration(labelText: '新密码', labelStyle: TextStyle(color: AppTheme.kBlack))),
            TextField(controller: confirmPwd, obscureText: true, decoration: const InputDecoration(labelText: '确认新密码', labelStyle: TextStyle(color: AppTheme.kBlack))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppTheme.kBlack))),
          TextButton(
            onPressed: () async {
              if (newPwd.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('新密码至少4个字符')));
                return;
              }
              if (newPwd.text != confirmPwd.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次密码不一致')));
                return;
              }
              final resp = await ApiService().updatePassword(oldPwd.text, newPwd.text);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? '')));
              }
            },
            child: const Text('确定', style: TextStyle(color: AppTheme.kBlack)),
          ),
        ],
      ),
    );
  }
}
