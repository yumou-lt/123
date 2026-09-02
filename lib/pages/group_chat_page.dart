// ============================================================
// 群聊页：图片 + 语音 + 动画 + 额外面板
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/services/ws_service.dart';
import 'package:chat_app/services/voice_service.dart';
import 'package:chat_app/models/message.dart';
import 'package:chat_app/pages/group_info_page.dart';
import 'package:chat_app/widgets/chat_widgets.dart';
import 'package:chat_app/widgets/vip_icon.dart';
import 'package:chat_app/widgets/mj_effect.dart';
import 'package:chat_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class GroupChatPage extends StatefulWidget {
  final int groupId;
  final String groupName;
  const GroupChatPage({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final List<GroupMessage> _messages = [];
  final List<WsMessage> _pendingWsMessages = [];
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingHistory = true;
  final Set<int> _seenMsgIds = {};

  bool _isTyping = false;
  Timer? _typingDebounce;
  final List<int> _pinnedMsgIds = []; // 已撤回消息的 msgId 列表（简单方案：标记为撤回过的可以重新编辑）

  bool _showExtraPanel = false;
  bool _showRecordIndicator = false;

  int get _myId => StorageService.getUserId() ?? 0;
  String get _myAvatar => StorageService.getAvatar() ?? '';

  @override
  void initState() {
    super.initState();
    WsService().on('group_message', _onWsMessage);
    WsService().on('typing', _onWsTyping);
    WsService().on('group_message_retract', _onGroupMessageRetract);
    WsService().on('read_receipt', _onWsReadReceipt);
    WsService().on('group_send_fail', (WsMessage msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.data['message'] ?? '发送失败')),
      );
    });
    _loadHistory();
  }

  @override
  void dispose() {
    WsService().off('group_message', _onWsMessage);
    WsService().off('typing', _onWsTyping);
    WsService().off('group_message_retract', _onGroupMessageRetract);
    WsService().off('read_receipt', _onWsReadReceipt);
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    VoiceRecordService().dispose();
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
            senderAvatar: d['avatar'] ?? d['senderAvatar'] ?? '',
            content: d['content'] ?? '',
            createTime: d['createTime'] ?? '',
            msgType: d['msgType'] ?? 0,
            duration: d['duration'] ?? 0,
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
        senderAvatar: data['avatar'] ?? data['senderAvatar'] ?? '',
        content: data['content'] ?? '',
        createTime: data['createTime'] ?? '',
        msgType: data['msgType'] ?? 0,
        duration: data['duration'] ?? 0,
        senderIsVip: (data['senderIsVip'] ?? 0) as int,
        senderBadge: data['senderBadge'] as String?,
      ));
      _messages.sort((a, b) => _timeOf(a).compareTo(_timeOf(b)));
    });
    _scrollToBottom();

    // MJ 特效
    if ((data['msgType'] ?? 0) == 0 && mounted) {
      final text = (data['content'] ?? '').trim().toLowerCase();
      if (text == 'mj') {
        MjEffect().trigger(context: context, senderId: data['senderId'] ?? 0);
      }
    }
  }

  void _onWsTyping(WsMessage msg) {
    final data = msg.data;
    if (data is Map<String, dynamic> && data['fromId'] != null) {
      setState(() => _isTyping = true);
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }
  }

  void _onGroupMessageRetract(WsMessage msg) {
    final data = msg.data;
    if (data is Map<String, dynamic>) {
      setState(() {
        for (final m in _messages) {
          if (m.id == data['msgId']) {
            m.isRetracted = true;
            break;
          }
        }
      });
    }
  }

  void _onWsReadReceipt(WsMessage msg) {
    // 群聊已读暂不处理，复杂
  }

  void _sendTyping() {
    WsService().sendTyping(targetId: widget.groupId, targetType: 2);
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {});
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip', 'rar', 'txt', 'mp4', 'apk', 'epub', 'csv']);
    if (result == null || result.files.single.path == null) return;
    setState(() => _showExtraPanel = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发送中...'), duration: Duration(seconds: 1)));
    try {
      final resp = await ApiService().uploadChatFile(File(result.files.single.path!));
      if (resp['code'] == 0) {
        final data = resp['data'];
        final content = jsonEncode({
          'url': data['url'],
          'fileName': data['originalName'] ?? '',
          'fileSize': data['fileSize'] ?? 0,
          'fileExt': data['fileExt'] ?? '',
        });
        WsService().sendGroupMessage(groupId: widget.groupId, content: content, msgType: 4);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? '文件上传失败')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误')));
    }
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

  // ---------- 长按菜单 ----------
  void _showLongPressMenu(GroupMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.isMine(_myId) && !msg.isRetracted) ...[
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.orange),
                title: const Text('撤回', style: TextStyle(color: Colors.orange)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final resp = await ApiService().retractGroupMessage(widget.groupId, msg.id);
                    if (resp['code'] == 0) {
                      WsService().sendGroupRetract(msgId: msg.id);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已撤回')));
                    } else {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? '撤回失败')));
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误')));
                  }
                },
              ),
            ],
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

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    WsService().sendGroupMessage(groupId: widget.groupId, content: text);
    _inputController.clear();
    setState(() => _showExtraPanel = false);
    // 等渲染完再请求 focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_inputFocusNode);
    });
  }

  // ---------- 发送图片 ----------
  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _showExtraPanel = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('发送中...'), duration: Duration(seconds: 1)),
    );

    try {
      final resp = await ApiService().uploadChatImage(File(picked.path));
      if (resp['code'] == 0) {
        final url = resp['data']['url'];
        WsService().sendGroupMessage(
          groupId: widget.groupId,
          content: url,
          msgType: 2,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resp['message'] ?? '图片上传失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络错误')),
      );
    }
  }

  // ---------- 语音 ----------
  Future<void> _startRecord() async {
    setState(() {
      _showRecordIndicator = true;
      _showExtraPanel = false;
    });
    await VoiceRecordService().startRecord();
  }

  Future<void> _stopRecordAndSend() async {
    setState(() => _showRecordIndicator = false);
    final result = await VoiceRecordService().stopRecord();
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('录音太短，取消发送')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('发送中 ${result.duration}″语音...'), duration: const Duration(seconds: 1)),
    );

    try {
      final resp = await ApiService().uploadChatVoice(result.file, duration: result.duration);
      if (resp['code'] == 0) {
        final url = resp['data']['url'];
        WsService().sendGroupMessage(
          groupId: widget.groupId,
          content: url,
          msgType: 3,
          duration: result.duration,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resp['message'] ?? '语音上传失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络错误')),
      );
    }
  }

  void _cancelRecord() {
    VoiceRecordService().stopRecord();
    setState(() => _showRecordIndicator = false);
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
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.groupName, style: const TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w700)),
                        if (_isTyping) const Text('有人正在输入...', style: TextStyle(color: Colors.black45, fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.black54),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GroupInfoPage(groupId: widget.groupId, groupName: widget.groupName),
                      ));
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: AppTheme.kSurface,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
                  : _messages.isEmpty
                      ? const Center(child: Text('暂无消息', style: TextStyle(color: Colors.black38)))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) => _buildMessageItem(_messages[i], i),
                        ),
            ),
          ),
          _buildInputBar(),
          if (_showExtraPanel) ChatExtraPanel(
            onPickImage: _sendImage,
            onRecordVoice: _startRecord,
            onPickFile: _sendFile,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(GroupMessage msg, int index) {
    final isMine = msg.senderId == _myId;

    return Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        MessageAnimatedBubble(
          isMine: isMine,
          index: index,
          child: GestureDetector(
            onLongPress: () => _showLongPressMenu(msg),
            child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine) ...[
                  Stack(
                    children: [
                      _buildAvatar(msg.senderAvatar),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: VipIcon(size: 14, isVip: msg.senderIsVip == 1, badge: msg.senderBadge),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(msg.senderNickname, style: const TextStyle(color: Colors.black38, fontSize: 11)),
                              const SizedBox(width: 3),
                              VipIcon(size: 12, isVip: msg.senderIsVip == 1, badge: msg.senderBadge),
                            ],
                          ),
                        ),
                        _buildBubbleContent(msg, false),
                      ],
                    ),
                  ),
                ],
                if (isMine) ...[
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildBubbleContent(msg, true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildAvatar(_myAvatar),
                ],
              ],
            ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleContent(GroupMessage msg, bool isMine) {
    // 图片
    if (msg.isImage) {
      return ImageBubble(imageUrl: msg.content, isMine: isMine);
    }
    // 语音
    if (msg.isVoice) {
      return VoiceBubble(voiceUrl: msg.content, duration: msg.duration, isMine: isMine);
    }

    // 文字
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      constraints: BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: isMine ? AppTheme.kAccentSoft : AppTheme.kWhite,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        border: isMine ? null : Border.all(color: AppTheme.kDivider, width: 0.5),
      ),
      child: Text(msg.content, style: TextStyle(color: AppTheme.kBlack, fontSize: 15)),
    );
  }

  Widget _buildAvatar(String? avatarUrl) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
      child: (avatarUrl != null && avatarUrl.isNotEmpty)
          ? ClipOval(child: Image.network(GlobalConfig.avatarUrl(avatarUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.black45, size: 18)))
          : const Icon(Icons.person, color: Colors.black45, size: 18),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showRecordIndicator)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('正在录音...松开发送', style: TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
              ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showExtraPanel = !_showExtraPanel),
                  child: Container(
                    width: 38, height: 38,
                    child: Icon(Icons.add, color: _showExtraPanel ? AppTheme.kAccent : AppTheme.kSubText, size: 24),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.kSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      focusNode: _inputFocusNode,
                      controller: _inputController,
                      onChanged: (_) => _sendTyping(),
                      decoration: const InputDecoration(
                        hintText: '输入消息...', hintStyle: TextStyle(color: Colors.black38),
                        isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      maxLines: null, textInputAction: TextInputAction.newline,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onLongPress: _startRecord,
                  onLongPressEnd: (_) => _stopRecordAndSend(),
                  onLongPressCancel: _cancelRecord,
                  child: const SizedBox(
                    width: 38, height: 38,
                    child: Icon(Icons.mic_none, color: Colors.black54, size: 22),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 40, height: 40,
                  child: ElevatedButton(
                    onPressed: _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.kAccent,
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
}
