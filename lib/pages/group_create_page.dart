// ============================================================
// 创建群聊页：从好友列表勾选成员
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/pages/group_chat_page.dart';
import 'package:chat_app/theme/app_theme.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key});

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  List<Map<String, dynamic>> _friends = [];
  final Set<int> _selectedIds = {};
  final _groupNameController = TextEditingController();
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final resp = await ApiService().getFriendList();
      setState(() {
        _friends = List<Map<String, dynamic>>.from(resp['data'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 19) {
        _selectedIds.add(id); // 群主自己占1个位置，最多选19个
      }
    });
  }

  Future<void> _create() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少选择1个好友')));
      return;
    }
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入群名')));
      return;
    }
    if (name.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('群名不能超过20个字符')));
      return;
    }

    setState(() => _creating = true);
    try {
      final resp = await ApiService().createGroup(
        groupName: name,
        memberIds: _selectedIds.toList(),
      );
      if (mounted) {
        setState(() => _creating = false);
        if (resp['code'] == 0) {
          final groupId = resp['data']['groupId'];
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => GroupChatPage(groupId: groupId, groupName: name)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? '创建失败')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kWhite,
      appBar: AppBar(
        title: Text('创建群聊 (${_selectedIds.length}/19)'),
        actions: [
          TextButton(
            onPressed: (_selectedIds.isEmpty || _creating) ? null : _create,
            child: _creating
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: AppTheme.kBlack, strokeWidth: 2))
                : const Text('创建', style: TextStyle(color: AppTheme.kBlack, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 群名输入
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(labelText: '群名称', hintText: '请输入群名（最多20字符）'),
              maxLength: 20,
            ),
          ),
          const Divider(height: 1),
          // 好友列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.kBlack))
                : _friends.isEmpty
                    ? const Center(child: Text('暂无好友，先去添加好友吧', style: TextStyle(color: AppTheme.kLightBlack)))
                    : ListView.builder(
                        itemCount: _friends.length,
                        itemBuilder: (_, i) {
                          final f = _friends[i];
                          final selected = _selectedIds.contains(f['id']);
                          return InkWell(
                            onTap: () => _toggleSelect(f['id']),
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.kDivider, width: 0.5))),
                              child: Row(
                                children: [
                                  Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: selected ? AppTheme.kBlack : AppTheme.kLightBlack),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.kBlack, width: 1)),
                                    child: const Icon(Icons.person, color: AppTheme.kBlack, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(f['nickname'] ?? '', style: const TextStyle(color: AppTheme.kBlack))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
