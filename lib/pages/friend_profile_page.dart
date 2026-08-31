// ============================================================
// 好友资料页
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/pages/chat_page.dart';
import 'package:chat_app/pages/add_friend_page.dart';
import 'package:chat_app/theme/app_theme.dart';

class FriendProfilePage extends StatelessWidget {
  final int friendId;
  final String nickname;
  final String avatar;

  const FriendProfilePage({super.key, required this.friendId, required this.nickname, this.avatar = ''});

  Future<void> _deleteFriend(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.kWhite,
        title: const Text('删除好友', style: TextStyle(color: AppTheme.kBlack)),
        content: const Text('确定要删除这个好友吗？', style: TextStyle(color: AppTheme.kBlack)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消', style: TextStyle(color: AppTheme.kBlack))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定', style: TextStyle(color: AppTheme.kBlack))),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService().deleteFriend(friendId);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除好友')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kWhite,
      appBar: AppBar(title: const Text('好友资料')),
      body: Column(
        children: [
          // 头像和昵称
          Container(
            height: 180,
            color: AppTheme.kWhite,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.kBlack, width: 2),
                    ),
                    child: avatar.isNotEmpty
                        ? ClipOval(child: Image.network(GlobalConfig.avatarUrl(avatar), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: AppTheme.kBlack, size: 40)))
                        : const Icon(Icons.person, color: AppTheme.kBlack, size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(nickname, style: const TextStyle(color: AppTheme.kBlack, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('ID: $friendId', style: const TextStyle(color: AppTheme.kLightBlack, fontSize: 12)),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => ChatPage(friendId: friendId, friendName: nickname, friendAvatar: avatar)),
                );
              },
              child: const Text('发消息'),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: OutlinedButton(
              onPressed: () => _deleteFriend(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.kBlack,
                side: const BorderSide(color: AppTheme.kBlack, width: 1),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('删除好友'),
            ),
          ),
        ],
      ),
    );
  }
}
