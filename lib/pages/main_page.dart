// ============================================================
// 主页面：白底 + 5Tab 紧凑导航（消息/联系人/动态/活动/我）
// 活动页直接放入导航栏，导航栏小巧、QQ 风蓝选中态
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/theme/app_theme.dart';
import 'package:chat_app/pages/message_page.dart';
import 'package:chat_app/pages/contact_page.dart';
import 'package:chat_app/pages/moment_page.dart';
import 'package:chat_app/pages/activity_page.dart';
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
    MomentPage(),
    ActivityPage(),
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
      return const Scaffold(
        backgroundColor: AppTheme.kWhite,
        body: Center(child: CircularProgressIndicator(color: AppTheme.kAccent)),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.kWhite,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.kWhite,
          border: const Border(top: BorderSide(color: AppTheme.kDivider, width: 1)),
          // 顶部一缕极淡阴影，让导航栏与内容分离
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                _buildItem(0, Icons.chat_bubble_outline, Icons.chat_bubble, '消息'),
                _buildItem(1, Icons.contacts_outlined, Icons.contacts, '联系人'),
                _buildItem(2, Icons.public_outlined, Icons.public, '动态'),
                _buildItem(3, Icons.event_available_outlined, Icons.event_available, '活动'),
                _buildItem(4, Icons.person_outline, Icons.person, '我'),
              ],
            ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: selected ? AppTheme.kAccent : AppTheme.kSubText,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.kAccent : AppTheme.kSubText,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
