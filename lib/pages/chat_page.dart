// ============================================================
// 单聊页：头像 + 撤回 + 引用 + 长按菜单
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/services/ws_service.dart';
import 'package:chat_app/models/message.dart';
import 'package:chat_app/pages/group_chat_page.dart';
import 'package:chat_app/pages/group_info_page.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final int friendId;
  final String friendName;
  final String friendAvatar;
  const ChatPage({super.key, required this.friendId, required this.friendName, this.friendAvatar = ''});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final List<WsMessage> _pendingWsMessages = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingHistory = true;
  final Set<int> _seenMsgIds = {};
  ChatMessage? _replyingTo;

  int get _myId => StorageService.getUserId() ?? 0;
  String get _myAvatar => StorageService.getAvatar() ?? '';

  @override
  void initState() {
    super.initState();
    WsService().on('chat_message', _onWsMessage);
    WsService().on('chat_message_sent', _onWsSent);
    WsService().on('chat_message_retracted', _onWsRetracted);
    WsService().onReconnected(_loadHistory);
    _loadHistory();
  }

  @override
  void dispose() {
    WsService().off('chat_message', _onWsMessage);
    WsService().off('chat_message_sent', _onWsSent);
    WsService().off('chat_message_retracted', _onWsRetracted);
    WsService().offReconnected(_loadHistory);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ChatMessage _wsToChatMessage(Map<String, dynamic> d, {bool fromSent = false}) {
    return ChatMessage(
      id: d['msgId'] ?? d['id'] ?? 0,
      senderId: d['senderId'] ?? 0,
      receiverId: fromSent ? widget.friendId : _myId,
      content: d['content'] ?? '',
      msgType: d['msgType'] ?? 0,
      isRead: 0,
      createTime: d['createTime'] ?? '',
      senderAvatar: d['senderAvatar'] ?? '',
      senderNickname: d['senderNickname'] ?? '',
      replyToId: d['replyToId'],
      replyContent: d['replyContent'],
    );
  }

  int _timeOf(ChatMessage m) {
    final t = m.createTime;
    if (t.isEmpty) return 0;
    try {
      String s = t.replaceFirst(' ', 'T');
      if (!s.contains('Z') && !s.contains('+') && !s.contains('-')) s = s + 'Z';
      return DateTime.parse(s).millisecondsSinceEpoch;
    } catch (_) { return 0; }
  }

  Future<void> _loadHistory() async {
    _loadingHistory = true;
    try {
      final resp = await ApiService().getHistory(widget.friendId);
      final list = List<Map<String, dynamic>>.from(resp['data'] ?? []);

      setState(() {
        _messages.clear();
        _seenMsgIds.clear();
        for (final m in list) {
          final msg = ChatMessage.fromJson(m);
          _seenMsgIds.add(msg.id);
          _messages.add(msg);
        }
        for (final ws in _pendingWsMessages) {
          final d = ws.data;
          if (d is! Map<String, dynamic>) continue;
          final chatMsg = _wsToChatMessage(d);
          if (_seenMsgIds.contains(chatMsg.id)) continue;
          _seenMsgIds.add(chatMsg.id);
          _messages.add(chatMsg);
        }
        _pendingWsMessages.clear();
        _messages.sort((a, b) {
          final ta = _timeOf(a), tb = _timeOf(b);
          return ta != tb ? ta.compareTo(tb) : a.id.compareTo(b.id);
        });
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _loading = false);
    } finally { _loadingHistory = false; }
  }

  void _onWsMessage(WsMessage msg) {
    final data = msg.data;
    if (data is! Map<String, dynamic>) return;
    if (data['senderId'] != widget.friendId) return;
    if (_loadingHistory) { _pendingWsMessages.add(msg); return; }
    final chatMsg = _wsToChatMessage(data);
    if (_seenMsgIds.contains(chatMsg.id)) return;
    _seenMsgIds.add(chatMsg.id);
    setState(() {
      _messages.add(chatMsg);
      _messages.sort((a, b) { final ta = _timeOf(a), tb = _timeOf(b); return ta != tb ? ta.compareTo(tb) : a.id.compareTo(b.id); });
    });
    _scrollToBottom();
  }

  void _onWsSent(WsMessage msg) {
    final data = msg.data;
    if (data is! Map<String, dynamic>) return;
    if (data['senderId'] != _myId) return;
    if (_loadingHistory) { _pendingWsMessages.add(msg); return; }
    final chatMsg = _wsToChatMessage(data, fromSent: true);
    if (_seenMsgIds.contains(chatMsg.id)) return;
    _seenMsgIds.add(chatMsg.id);
    setState(() {
      _messages.add(chatMsg);
      _messages.sort((a, b) { final ta = _timeOf(a), tb = _timeOf(b); return ta != tb ? ta.compareTo(tb) : a.id.compareTo(b.id); });
    });
    _scrollToBottom();
  }

  void _onWsRetracted(WsMessage msg) {
    final data = msg.data;
    if (data is! Map<String, dynamic>) return;
    final int retractedId = data['msgId'] ?? 0;
    setState(() {
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].id == retractedId) {
          _messages[i] = ChatMessage(
            id: _messages[i].id,
            senderId: _messages[i].senderId,
            receiverId: _messages[i].receiverId,
            content: _messages[i].content,
            msgType: _messages[i].msgType,
            isRead: _messages[i].isRead,
            createTime: _messages[i].createTime,
            isRetracted: true,
            senderAvatar: _messages[i].senderAvatar,
            senderNickname: _messages[i].senderNickname,
          );
        }
      }
    });
  }

  void _scrollToBottom() {
    void tryScroll() {
      if (!mounted || !_scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 200), tryScroll);
        return;
      }
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => Future.delayed(const Duration(milliseconds: 50), tryScroll));
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    WsService().sendChatMessage(
      receiverId: widget.friendId,
      content: text,
      replyToId: _replyingTo?.id,
      replyContent: _replyingTo?.content,
    );
    _inputController.clear();
    setState(() => _replyingTo = null);
  }

  void _showLongPressMenu(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.forward, color: Colors.black),
              title: const Text('引用该消息', style: TextStyle(color: Colors.black)),
              onTap: () { Navigator.pop(context); setState(() => _replyingTo = msg); },
            ),
            if (msg.isMine(_myId) && !msg.isRetracted)
              ListTile(
                leading: const Icon(Icons.undo_rounded, color: Colors.red),
                title: const Text('撤回（2分钟内）', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  WsService().sendRetract(msgId: msg.id);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已撤回')));
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.black54),
              title: const Text('复制内容', style: TextStyle(color: Colors.black)),
              onTap: () { Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.black54),
              title: const Text('删除本地记录', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _messages.removeWhere((m) => m.id == msg.id));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '';
    try {
      String s = t.replaceFirst(' ', 'T');
      if (!s.contains('Z') && !s.contains('+') && !s.contains('-')) s = s + 'Z';
      final dt = DateTime.parse(s).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return DateFormat('HH:mm').format(dt);
      return DateFormat('MM-dd HH:mm').format(dt);
    } catch (e) { return t; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20), onPressed: () => Navigator.of(context).pop()),
                  Expanded(child: Text(widget.friendName, style: const TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : _messages.isEmpty
                      ? const Center(child: Text('暂无消息', style: TextStyle(color: Colors.black38)))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) => _buildMessageItem(_messages[i]),
                        ),
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ---------- 头像组件 ----------
  Widget _buildAvatar(String? avatarUrl, {double size = 36}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
      child: (avatarUrl != null && avatarUrl.isNotEmpty)
          ? ClipOval(child: Image.network(GlobalConfig.avatarUrl(avatarUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.black45, size: size * 0.55)))
          : Icon(Icons.person, color: Colors.black45, size: size * 0.55),
    );
  }

  // ---------- 消息气泡（带头像 + 撤回 + 引用） ----------
  Widget _buildMessageItem(ChatMessage msg) {
    final isMine = msg.isMine(_myId);

    // 撤回态
    if (msg.isRetracted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.undo_rounded, color: Colors.black38, size: 14),
                const SizedBox(width: 6),
                Text('${isMine ? '你' : msg.senderNickname.isEmpty ? '对方' : msg.senderNickname}撤回了一条消息', style: const TextStyle(color: Colors.black38, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    // 引用的原消息在列表里找一下
    ChatMessage? replyMsg;
    if (msg.replyToId != null) {
      try { replyMsg = _messages.firstWhere((m) => m.id == msg.replyToId); } catch (_) {}
    }

    return GestureDetector(
      onLongPress: () => _showLongPressMenu(msg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 对方头像（左侧）
            if (!isMine) ...[
              _buildAvatar(msg.senderAvatar.isEmpty ? widget.friendAvatar : msg.senderAvatar),
              const SizedBox(width: 8),
            ],
            // 气泡
            Flexible(
              child: Align(
                alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                child: _buildBubbleContent(msg, isMine, replyMsg),
              ),
            ),
            // 我方头像（右侧）
            if (isMine) ...[
              const SizedBox(width: 8),
              _buildAvatar(_myAvatar),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleContent(ChatMessage msg, bool isMine, ChatMessage? replyMsg) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      constraints: BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFF2196F3) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4), bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        border: isMine ? null : Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 引用块
          if (replyMsg != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isMine ? Colors.white.withOpacity(0.2) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
                border: Border(left: BorderSide(color: isMine ? Colors.white54 : Colors.black26, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (replyMsg.isMine(_myId) ? '你' : (replyMsg.senderNickname.isEmpty ? widget.friendName : replyMsg.senderNickname)),
                    style: TextStyle(color: isMine ? Colors.white60 : Colors.black54, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    replyMsg.isRetracted ? '该消息已撤回' : replyMsg.content,
                    style: TextStyle(color: isMine ? Colors.white54 : Colors.black38, fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
          // 群名片
          if (msg.msgType == 1)
            _buildGroupCardBubble(msg, isMine)
          else
            Text(msg.content, style: TextStyle(color: isMine ? Colors.white : Colors.black, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildGroupCardBubble(ChatMessage msg, bool isMine) {
    GroupCardContent? card;
    try { card = GroupCardContent.fromJson(Map<String, dynamic>.from(jsonDecode(msg.content))); } catch (_) {}
    if (card == null) return Text(msg.content, style: TextStyle(color: isMine ? Colors.white : Colors.black, fontSize: 15));
    return GestureDetector(
      onTap: () => _onGroupCardTap(card!.groupId, card.groupName),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.group, color: isMine ? Colors.white : Colors.black54, size: 24),
          const SizedBox(height: 6),
          Text(card.groupName, style: TextStyle(color: isMine ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${card.memberCount}人', style: TextStyle(color: isMine ? Colors.white60 : Colors.black38, fontSize: 12)),
        ],
      ),
    );
  }

  void _onGroupCardTap(int groupId, String groupName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(groupName), content: const Text('是否加入该群聊？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final resp = await ApiService().joinGroupByCard(groupId);
              if (mounted) {
                Navigator.pop(context);
                if (resp['code'] == 0) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupChatPage(groupId: groupId, groupName: groupName)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? '加入失败')));
                }
              }
            },
            child: const Text('加入群聊'),
          ),
        ],
      ),
    );
  }

  // ---------- 输入栏（带引用预览） ----------
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null) _buildReplyPreview(),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: '输入消息...', hintStyle: TextStyle(color: Colors.black38),
                        isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      maxLines: null, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40, height: 40,
                  child: ElevatedButton(
                    onPressed: _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final msg = _replyingTo!;
    final isMine = msg.isMine(_myId);
    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(width: 3, height: 32, color: Colors.black26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isMine ? '你' : (msg.senderNickname.isEmpty ? widget.friendName : msg.senderNickname), style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(msg.isRetracted ? '该消息已撤回' : msg.content, style: const TextStyle(color: Colors.black45, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(onTap: () => setState(() => _replyingTo = null), child: const Icon(Icons.close, color: Colors.black38, size: 18)),
        ],
      ),
    );
  }
}
