// ============================================================
// 消息列表 Tab：最近会话 + 未读数
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/services/ws_service.dart';
import 'package:chat_app/models/message.dart';
import 'package:chat_app/pages/chat_page.dart';
import 'package:chat_app/pages/group_chat_page.dart';
import 'package:chat_app/pages/group_create_page.dart';
import 'package:chat_app/pages/search_page.dart';
import 'package:chat_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _myGroups = [];
  List<Map<String, dynamic>> _pinnedConvs = [];   // 置顶的会话
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();

    // 监听 WebSocket 新消息 → 刷新列表
    WsService().on('chat_message', (_) => _loadData());
    WsService().on('group_message', (_) => _loadData());
    WsService().on('chat_message_sent', (_) => _loadData());
    WsService().on('friend_apply_accepted', (_) => _loadData());
    WsService().on('friend_apply_rejected', (_) => _loadData());
    WsService().on('friend_apply_notify', (_) => _loadData());
    WsService().on('group_invited', (_) => _loadData());
    WsService().on('group_member_added', (_) => _loadData());
    WsService().on('group_dismissed', (_) => _loadData());

    // 监听后台广播的公共公告 → 弹窗显示
    WsService().on('public_announcement', (msg) {
      if (msg.data is Map<String, dynamic>) {
        _showAnnouncementDialog(msg.data as Map<String, dynamic>);
      }
    });

    // 重连成功后自动补拉离线期间的新会话/消息
    WsService().onReconnected(_loadData);

    // 启动时拉取最新公告（热更新入口）
    _fetchAnnouncement();
  }

  @override
  void dispose() {
    WsService().off('chat_message');
    WsService().off('group_message');
    WsService().off('chat_message_sent');
    WsService().off('friend_apply_accepted');
    WsService().off('friend_apply_rejected');
    WsService().off('friend_apply_notify');
    WsService().off('group_invited');
    WsService().off('group_member_added');
    WsService().off('group_dismissed');
    WsService().off('public_announcement');
    WsService().offReconnected(_loadData);
    super.dispose();
  }

  // ---------- 拉取并显示公告 ----------
  Future<void> _fetchAnnouncement() async {
    try {
      final resp = await ApiService().getAnnouncement();
      if (resp['code'] == 0 && resp['data'] != null && mounted) {
        _showAnnouncementDialog(Map<String, dynamic>.from(resp['data']));
      }
    } catch (_) {}
  }

  void _showAnnouncementDialog(Map<String, dynamic> data) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: Container(
          width: MediaQuery.of(ctx).size.width * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data['title'] ?? '📢 公告',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                data['content'] ?? '',
                style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  child: const Text('我知道了', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final convResp = await ApiService().getConversations();
      final groupResp = await ApiService().getMyGroups();
      final pinResp = await ApiService().getPinnedConversations();

      setState(() {
        _conversations = List<Map<String, dynamic>>.from(convResp['data'] ?? []);
        _myGroups = List<Map<String, dynamic>>.from(groupResp['data'] ?? []);
        final pins = List<Map<String, dynamic>>.from(pinResp['data'] ?? []);
        // 标记哪些会话被置顶了
        final pinnedIds = <String, int>{}; // key: "type_targetId" → pinId
        for (final p in pins) {
          pinnedIds['${p['targetType']}_${p['targetId']}'] = p['id'];
        }
        // 合并单聊+群聊，提取置顶的
        final all = <Map<String, dynamic>>[];
        for (final c in _conversations) {
          all.add({...c, '_isGroup': false, '_pinId': pinnedIds['1_${c['userId']}']});
        }
        for (final g in _myGroups) {
          all.add({...g, '_isGroup': true, '_pinId': pinnedIds['2_${g['id']}']});
        }
        // 置顶的排前面，再按时间倒序
        all.sort((a, b) {
          final aPinned = a['_pinId'] != null;
          final bPinned = b['_pinId'] != null;
          if (aPinned != bPinned) return aPinned ? -1 : 1;
          final aTime = a['lastTime'] ?? a['create_time'] ?? '';
          final bTime = b['lastTime'] ?? b['create_time'] ?? '';
          return bTime.toString().compareTo(aTime.toString());
        });
        _pinnedConvs = all.where((e) => e['_pinId'] != null).toList();
        _conversations = all.where((e) => e['_pinId'] == null).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      String s = timeStr.replaceFirst(' ', 'T');
      if (!s.contains('Z') && !s.contains('+') && !s.contains('-')) {
        s = s + 'Z';
      }
      final dt = DateTime.parse(s).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return DateFormat('HH:mm').format(dt);
      }
      if (dt.year == now.year) {
        return DateFormat('MM-dd HH:mm').format(dt);
      }
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (e) {
      return '';
    }
  }

  String _msgPreview(Map<String, dynamic> conv) {
    final lastMsg = conv['lastMessage'] ?? '';
    final msgType = conv['lastMsgType'] ?? 0;
    if (msgType == 1) {
      try {
        // 后端存的就是合法 JSON 字符串，直接用 dart:convert 解析
        final card = GroupCardContent.fromJson(jsonDecode(lastMsg.toString()) as Map<String, dynamic>);
        return '[群名片] ${card.groupName}';
      } catch (e) {
        return '[群名片]';
      }
    }
    return lastMsg.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('消息', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchPage())),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add, color: Colors.black),
            onSelected: (v) {
              if (v == 'create_group') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupCreatePage()));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'create_group', child: Text('创建群聊')),
            ],
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
                : (_conversations.isEmpty && _myGroups.isEmpty)
                    ? const Center(child: Text('暂无消息，快去添加好友吧', style: TextStyle(color: AppTheme.kSubText)))
                    : ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          // 置顶会话
                          ..._pinnedConvs.map((c) => _buildConversationItem(c, c['_isGroup'] == true, isPinned: true)),
                          if (_pinnedConvs.isNotEmpty && (_conversations.isNotEmpty || _myGroups.isNotEmpty))
                            const Divider(height: 1, thickness: 0.5, indent: 72),
                          // 普通会话
                          ..._conversations.map((c) => _buildConversationItem(c, c['_isGroup'] == true, isPinned: false)),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationItem(Map<String, dynamic> data, bool isGroup, {bool isPinned = false}) {
    final int unread;
    final String name;
    final String avatar;
    final String preview;
    final String time;

    if (isGroup) {
      unread = 0;
      name = data['group_name'] ?? data['groupName'] ?? '';
      avatar = '';
      preview = '群聊';
      time = '';
    } else {
      unread = data['unread'] ?? 0;
      name = data['nickname'] ?? '';
      avatar = data['avatar'] ?? '';
      preview = _msgPreview(data);
      time = _formatTime(data['lastTime']);
    }

    return InkWell(
      onLongPress: () => _showConvLongMenu(data, isGroup, isPinned),
      onTap: () {
        if (isGroup) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GroupChatPage(groupId: data['id'], groupName: name)),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatPage(
              friendId: data['userId'],
              friendName: name,
              friendAvatar: avatar,
              friendIsVip: data['is_vip'] == 1,
              friendEquippedBadge: data['equipped_badge'],
            )),
          );
        }
      },
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isPinned ? AppTheme.kHover : AppTheme.kWhite,
          border: const Border(bottom: BorderSide(color: AppTheme.kDivider, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.kSurface),
              child: avatar.isNotEmpty && !isGroup
                  ? ClipOval(child: Image.network(GlobalConfig.avatarUrl(avatar), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.black54)))
                  : Icon(isGroup ? Icons.group : Icons.person, color: Colors.black54, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (isPinned) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin, size: 12, color: Colors.black38)),
                      Text(time, style: const TextStyle(color: Colors.black38, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Text(preview, style: const TextStyle(color: Colors.black45, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.kBadge, borderRadius: BorderRadius.circular(10)),
                          child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 会话长按菜单（置顶 / 取消置顶）
  void _showConvLongMenu(Map<String, dynamic> data, bool isGroup, bool isPinned) {
    final targetId = isGroup ? data['id'] : data['userId'];
    final targetType = isGroup ? 2 : 1;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isPinned ? Icons.clear : Icons.push_pin),
              title: Text(isPinned ? '取消置顶' : '置顶聊天'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  if (isPinned) {
                    await ApiService().unpinConversation(targetId, targetType: targetType);
                  } else {
                    await ApiService().pinConversation(targetId, targetType: targetType);
                  }
                  _loadData();
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
    );
  }
}
