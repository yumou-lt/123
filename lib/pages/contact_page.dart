// ============================================================
// 联系人 Tab：好友列表 + 待处理申请
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/ws_service.dart';
import 'package:chat_app/pages/add_friend_page.dart';
import 'package:chat_app/pages/friend_profile_page.dart';
import 'package:chat_app/pages/chat_page.dart';
import 'package:chat_app/theme/app_theme.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();

    // 监听 WebSocket 实时刷新
    WsService().on('friend_apply_notify', (_) => _loadData());
    WsService().on('friend_apply_accepted', (_) => _loadData());
    WsService().on('friend_apply_rejected', (_) => _loadData());
  }

  @override
  void dispose() {
    WsService().off('friend_apply_notify');
    WsService().off('friend_apply_accepted');
    WsService().off('friend_apply_rejected');
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final friendResp = await ApiService().getFriendList();
      final pendingResp = await ApiService().getPendingApplies();
      setState(() {
        _friends = List<Map<String, dynamic>>.from(friendResp['data'] ?? []);
        _pending = List<Map<String, dynamic>>.from(pendingResp['data'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('联系人', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.black),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddFriendPage()));
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AppTheme.contentMaxWidth(context)),
          child: RefreshIndicator(
            color: AppTheme.kAccent,
            onRefresh: _loadData,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // 待处理申请入口
                      if (_pending.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: InkWell(
                            onTap: _showPendingSheet,
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppTheme.kDivider, width: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(color: AppTheme.kSurface, shape: BoxShape.circle),
                                    child: const Icon(Icons.person_add, color: Colors.black54, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(child: Text('新的朋友', style: TextStyle(color: AppTheme.kBlack, fontSize: 15, fontWeight: FontWeight.w500))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: AppTheme.kBadge, borderRadius: BorderRadius.circular(10)),
                                    child: Text('${_pending.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // 好友标题
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('我的好友', style: TextStyle(color: AppTheme.kSubText, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                      // 好友列表
                      ..._friends.isEmpty
                          ? [const Padding(padding: EdgeInsets.all(32), child: Text('暂无好友，点击右上角添加', style: TextStyle(color: AppTheme.kSubText), textAlign: TextAlign.center))]
                          : _friends.map((f) => _buildFriendItem(f)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendItem(Map<String, dynamic> f) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FriendProfilePage(
              friendId: f['id'],
              nickname: f['nickname'] ?? '',
              avatar: f['avatar'] ?? '',
            ),
          ),
        );
      },
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.kDivider, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppTheme.kSurface, shape: BoxShape.circle),
              child: (f['avatar'] != null && f['avatar'].toString().isNotEmpty)
                  ? ClipOval(child: Image.network(GlobalConfig.avatarUrl(f['avatar']), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.black54, size: 20)))
                  : const Icon(Icons.person, color: Colors.black54, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(f['nickname'] ?? '', style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500))),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.black54, size: 20),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatPage(friendId: f['id'], friendName: f['nickname'] ?? '', friendAvatar: f['avatar'] ?? ''),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPendingSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Text('新朋友申请', style: TextStyle(color: AppTheme.kBlack, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            SizedBox(
              height: 300,
              child: _pending.isEmpty
                  ? const Center(child: Text('暂无申请', style: TextStyle(color: AppTheme.kLightBlack)))
                  : ListView.builder(
                      itemCount: _pending.length,
                      itemBuilder: (_, i) {
                        final apply = _pending[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppTheme.kDivider, width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.kBlack, width: 1),
                                ),
                                child: (apply['avatar'] != null && apply['avatar'].toString().isNotEmpty)
                                    ? ClipOval(child: Image.network(GlobalConfig.avatarUrl(apply['avatar']), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: AppTheme.kBlack, size: 20)))
                                    : const Icon(Icons.person, color: AppTheme.kBlack, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(apply['nickname'] ?? '', style: const TextStyle(color: AppTheme.kBlack, fontSize: 15))),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.kBlack,
                                  side: const BorderSide(color: AppTheme.kBlack, width: 1),
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                onPressed: () async {
                                  await ApiService().handleFriendApply(apply['applicant_id'] ?? apply['applicantId'] ?? 0, 'accept');
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    _loadData();
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已添加好友')));
                                  }
                                },
                                child: const Text('同意', style: TextStyle(fontSize: 13)),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: AppTheme.kLightBlack, minimumSize: const Size(0, 32)),
                                onPressed: () async {
                                  await ApiService().handleFriendApply(apply['applicant_id'] ?? apply['applicantId'] ?? 0, 'reject');
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    _loadData();
                                  }
                                },
                                child: const Text('拒绝', style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
