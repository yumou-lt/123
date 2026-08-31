// ============================================================
// 群聊页：简约白底 + 蓝色/白色气泡
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/services/ws_service.dart';
import 'package:chat_app/models/message.dart';
import 'package:chat_app/pages/group_info_page.dart';

class GroupChatPage extends StatefulWidget {
  final int groupId;
  final String groupName;
  const GroupChatPage({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final List<dynamic> _messages = [];
  final List<WsMessage> _pendingWsMessages = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingHistory = true;
  final Set<int> _seenMsgIds = {};

  int get _myId => StorageService.getUserId() ?? 0;

  @override
  void initState() {
    super.initState();
    WsService().on('group_message', _onWsMessage);
    _loadHistory();
  }

  @override
  void dispose() {
    WsService().off('group_message', _onWsMessage);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    _loadingHistory = true;
    try {
      final resp = await ApiService().getGroupHistory(widget.groupId);
      final list = List<Map<String, dynamic>>.from(resp['data'] ?? []);

      setState(() {
        _messages.clear();
        _seenMsgIds.clear();

        for (final m in list) {
          final msg = GroupMessage.fromJson(m);
          _seenMsgIds.add(msg.id);
          _messages.add(msg);
        }

        for (final ws in _pendingWsMessages) {
          final d = ws.data;
          if (d is! Map<String, dynamic>) continue;
          if (d['groupId'] != widget.groupId) continue;

          final wsMsgId = d['msgId'] as int? ?? d['id'] as int?;
          if (wsMsgId != null && _seenMsgIds.contains(wsMsgId)) continue;

          final gm = GroupMessage(
            id: wsMsgId ?? 0,
            senderId: d['senderId'] ?? 0,
            senderNickname: d['senderNickname'] ?? '',
            senderAvatar: d['avatar'] ?? '',
            content: d['content'] ?? '',
            createTime: d['createTime'] ?? '',
          );
          _seenMsgIds.add(gm.id);
          _messages.add(gm);
        }
        _pendingWsMessages.clear();

        _messages.sort((a, b) => _timeOf(a).compareTo(_timeOf(b)));

        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _loading = false);
    } finally {
      _loadingHistory = false;
    }
  }

  int _timeOf(dynamic m) {
    String? t;
    if (m is GroupMessage) t = m.createTime;
    if (t == null || t.isEmpty) return 0;
    try {
      String s = t.replaceFirst(' ', 'T');
      if (!s.contains('Z') && !s.contains('+') && !s.contains('-')) s = s + 'Z';
      return DateTime.parse(s).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  void _onWsMessage(WsMessage msg) {
    final data = msg.data;
    if (data is! Map<String, dynamic>) return;
    if (data['groupId'] != widget.groupId) return;

    if (_loadingHistory) {
      _pendingWsMessages.add(msg);
      return;
    }

    final wsMsgId = data['msgId'] as int? ?? data['id'] as int? ?? 0;
    if (_seenMsgIds.contains(wsMsgId)) return;
    _seenMsgIds.add(wsMsgId);

    setState(() {
      _messages.add(GroupMessage(
        id: wsMsgId,
        senderId: data['senderId'] ?? 0,
        senderNickname: data['senderNickname'] ?? '',
        senderAvatar: data['avatar'] ?? '',
        content: data['content'] ?? '',
        createTime: data['createTime'] ?? '',
      ));
      _messages.sort((a, b) => _timeOf(a).compareTo(_timeOf(b)));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    WsService().sendGroupMessage(groupId: widget.groupId, content: text);
    _inputController.clear();
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(child: Text(widget.groupName, style: const TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.black54),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupInfoPage(groupId: widget.groupId, groupName: widget.groupName))),
                  ),
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

  Widget _buildMessageItem(dynamic msg) {
    bool isMine;
    String content;
    String senderNickname;

    if (msg is GroupMessage) {
      isMine = msg.senderId == _myId;
      content = msg.content;
      senderNickname = msg.senderNickname;
    } else {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isMine)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 2),
            child: Text(senderNickname, style: const TextStyle(color: Colors.black38, fontSize: 11)),
          ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          decoration: BoxDecoration(
            color: isMine ? const Color(0xFF2196F3) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            border: isMine ? null : Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
          ),
          child: Text(content, style: TextStyle(color: isMine ? Colors.white : Colors.black, fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
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
                    hintText: '输入消息...',
                    hintStyle: TextStyle(color: Colors.black38),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
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
      ),
    );
  }
}
