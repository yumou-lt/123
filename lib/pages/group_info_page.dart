// ============================================================
// 群信息页：成员列表 + 分享群名片 + 退群/解散
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/pages/add_friend_page.dart';
import 'package:chat_app/pages/chat_page.dart';
import 'package:chat_app/theme/app_theme.dart';

class GroupInfoPage extends StatefulWidget {
  final int groupId;
  final String groupName;
  const GroupInfoPage({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  Map<String, dynamic> _group = {};
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  int get _myId => StorageService.getUserId() ?? 0;
  bool get _isOwner => _group['owner_id'] == _myId || _group['ownerId'] == _myId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final resp = await ApiService().getGroupInfo(widget.groupId);
      if (resp['code'] == 0) {
        final d = resp['data'];
        setState(() {
          _group = {
            ...d,
            'owner_id': d['owner_id'] ?? d['ownerId'],
          };
          _members = List<Map<String, dynamic>>.from(d['members'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // 分享群名片 → 选择好友 → 发送
  Future<void> _shareCard() async {
    // 简化：弹出好友列表，点击某个好友发送
    final friendResp = await ApiService().getFriendList();
    final friends = List<Map<String, dynamic>>.from(friendResp['data'] ?? []);

    final selectedFriend = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppTheme.kWhite,
      builder: (_) => SizedBox(
        height: 400,
        child: friends.isEmpty
            ? const Center(child: Text('暂无好友', style: TextStyle(color: AppTheme.kLightBlack)))
            : ListView.builder(
                itemCount: friends.length,
                itemBuilder: (_, i) {
                  final f = friends[i];
                  return InkWell(
                    onTap: () => Navigator.pop(context, f),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.kBlack, width: 1)),
                            child: const Icon(Icons.person, color: AppTheme.kBlack, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(f['nickname'] ?? '', style: const TextStyle(color: AppTheme.kBlack)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );

    if (selectedFriend != null) {
      final resp = await ApiService().shareGroupCard(widget.groupId, selectedFriend['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? '')));
      }
    }
  }

  Future<void> _leaveOrDismiss() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.kWhite,
        title: Text(_isOwner ? '解散群聊' : '退出群聊', style: const TextStyle(color: AppTheme.kBlack)),
        content: Text(_isOwner ? '你是群主，确定解散该群吗？' : '确定退出该群吗？', style: const TextStyle(color: AppTheme.kBlack)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消', style: TextStyle(color: AppTheme.kBlack))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定', style: TextStyle(color: AppTheme.kBlack))),
        ],
      ),
    );
    if (confirm == true) {
      final resp = _isOwner
          ? await ApiService().dismissGroup(widget.groupId)
          : await ApiService().leaveGroup(widget.groupId);
      if (mounted) {
        Navigator.of(context).pop(); // 退出群信息页
        Navigator.of(context).pop(); // 退出群聊页
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? '')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kWhite,
      appBar: AppBar(title: const Text('群信息')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.kBlack))
          : ListView(
              children: [
                // 群名 + 成员数
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.kDivider, width: 0.5))),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.kBlack, width: 1)),
                        child: const Icon(Icons.group, color: AppTheme.kBlack, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.groupName, style: const TextStyle(color: AppTheme.kBlack, fontSize: 17, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${_members.length}人', style: const TextStyle(color: AppTheme.kLightBlack, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 分享群名片
                InkWell(
                  onTap: _shareCard,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.kDivider, width: 0.5))),
                    child: const Row(
                      children: [
                        Icon(Icons.share, color: AppTheme.kBlack, size: 20),
                        SizedBox(width: 12),
                        Expanded(child: Text('分享群名片', style: TextStyle(color: AppTheme.kBlack, fontSize: 15))),
                        Icon(Icons.chevron_right, color: AppTheme.kLightBlack),
                      ],
                    ),
                  ),
                ),
                // 成员标题
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('群成员', style: TextStyle(color: AppTheme.kLightBlack, fontSize: 12)),
                ),
                // 成员列表
                ..._members.map((m) {
                  final isOwner = (m['user_id'] ?? m['userId']) == _group['owner_id'];
                  return Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.kDivider, width: 0.5))),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.kBlack, width: 1)),
                          child: const Icon(Icons.person, color: AppTheme.kBlack, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Text(m['nickname'] ?? '', style: const TextStyle(color: AppTheme.kBlack, fontSize: 15)),
                              if (isOwner) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.kBlack,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('群主', style: TextStyle(color: AppTheme.kWhite, fontSize: 10)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 32),
                // 退群/解散按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton(
                    onPressed: _leaveOrDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.kBlack,
                      side: const BorderSide(color: AppTheme.kBlack, width: 1),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(_isOwner ? '解散群聊' : '退出群聊'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
