// ============================================================
// 主页面：简约白底 + 底部导航 + 强制用户守则检查
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/pages/message_page.dart';
import 'package:chat_app/pages/contact_page.dart';
import 'package:chat_app/pages/mine_page.dart';
import 'package:chat_app/pages/user_agreement_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  bool _checking = true;

  final List<Widget> _pages = const [
    MessagePage(),
    ContactPage(),
    MinePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAgreement();
    });
  }

  Future<void> _checkAgreement() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!StorageService.agreementAcknowledged && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UserAgreementPage(enforce: true)),
        (route) => false,
      );
    } else {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: Colors.black)));
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black.withOpacity(0.08), width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _buildItem(0, Icons.chat_bubble_outline, Icons.chat_bubble, '消息'),
              _buildItem(1, Icons.contacts_outlined, Icons.contacts, '联系人'),
              _buildItem(2, Icons.person_outline, Icons.person, '我'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index, IconData icon, IconData activeIcon, String label) {
    final selected = index == _currentIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, color: selected ? Colors.black : Colors.black45, size: 24),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(color: selected ? Colors.black : Colors.black45, fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}
