// ============================================================
// 单聊页：头像 + 撤回 + 引用 + 长按 + 图片 + 语音 + 动画
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/services/ws_service.dart';
import 'package:chat_app/services/voice_service.dart';
import 'package:chat_app/models/message.dart';
import 'package:chat_app/pages/group_chat_page.dart';
import 'package:chat_app/pages/group_info_page.dart';
import 'package:chat_app/widgets/chat_widgets.dart';
import 'package:chat_app/widgets/vip_icon.dart';
import 'package:chat_app/widgets/mj_effect.dart';
import 'package:chat_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final int friendId;
  final String friendName;
  final String friendAvatar;
  final bool friendIsVip;
  final String? friendEquippedBadge;
  const ChatPage({super.key, required this.friendId, required this.friendName, this.friendAvatar = '', this.friendIsVip = false, this.friendEquippedBadge});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final List<WsMessage> _pendingWsMessages = [];
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingHistory = true;
  bool _initialLoadDone = false;
  final Set<int> _seenMsgIds = {};
  final Set<int> _initialMsgIds = {}; // 初始加载的历史消息，不加动画
  ChatMessage? _replyingTo;

  // 新增：面板控制
  bool _showExtraPanel = false;
  bool _showRecordIndicator = false;
  bool _showEmojiPanel = false;
  final List<int> _sendingImageIds = []; // 正在发送的临时消息

  // typing / 已读 / 文件
  bool _isTyping = false;
  Timer? _typingDebounce;
  final Map<int, bool> _readReceipts = {};

  int get _myId => StorageService.getUserId() ?? 0;
  String get _myAvatar => StorageService.getAvatar() ?? '';

  @override
  void initState() {
    super.initState();
    WsService().on('chat_message', _onWsMessage);
    WsService().on('chat_message_sent', _onWsSent);
    WsService().on('chat_message_retracted', _onWsRetracted);
    WsService().on('typing', _onWsTyping);
    WsService().on('read_receipt', _onWsReadReceipt);
    WsService().onReconnected(_loadHistory);
    _loadHistory();
  }

  @override
  void dispose() {
    WsService().off('chat_message', _onWsMessage);
    WsService().off('chat_message_sent', _onWsSent);
    WsService().off('chat_message_retracted', _onWsRetracted);
    WsService().off('typing', _onWsTyping);
    WsService().off('read_receipt', _onWsReadReceipt);
    WsService().offReconnected(_loadHistory);
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    VoiceRecordService().dispose();
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
      duration: d['duration'] ?? 0,
      senderIsVip: (d['senderIsVip'] ?? 0) as int,
      senderBadge: d['senderBadge'] as String?,
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
        _initialMsgIds.clear();
        for (final m in list) {
          final msg = ChatMessage.fromJson(m);
          _seenMsgIds.add(msg.id);
          _initialMsgIds.add(msg.id); // 历史消息不加动画
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
        _initialLoadDone = true;
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
    // MJ 特效触发
    _checkMjEffect(chatMsg);
  }

  void _onWsSent(WsMessage msg) {
    final data = msg.data;
    if (data is! Map<String, dynamic>) return;
    if (data['senderId'] != _myId) return;
    if (_loadingHistory) { _pendingWsMessages.add(msg); return; }
    final chatMsg = _wsToChatMessage(data, fromSent: true);
    if (_seenMsgIds.contains(chatMsg.id)) return;
    _seenMsgIds.add(chatMsg.id);
    // 从发送中列表移除
    setState(() {
      _sendingImageIds.removeWhere((id) => id == chatMsg.id);
      _messages.add(chatMsg);
      _messages.sort((a, b) { final ta = _timeOf(a), tb = _timeOf(b); return ta != tb ? ta.compareTo(tb) : a.id.compareTo(b.id); });
    });
    _scrollToBottom();
    // 自己发 mj 也触发
    _checkMjEffect(chatMsg);
  }

  void _checkMjEffect(ChatMessage msg) {
    if (msg.msgType != 0) return; // 只对文字消息生效
    if (!mounted) return;
    if (msg.content.trim().toLowerCase() == 'mj') {
      MjEffect().trigger(context: context, senderId: msg.senderId);
    }
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

  // ---------- typing / 已读 WS 事件 ----------
  void _onWsTyping(WsMessage msg) {
    final data = msg.data;
    if (data is Map<String, dynamic> && data['fromId'] == widget.friendId) {
      setState(() => _isTyping = true);
      // 3秒后自动取消
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }
  }

  void _onWsReadReceipt(WsMessage msg) {
    final data = msg.data;
    if (data is Map<String, dynamic> && data['fromId'] == widget.friendId && data['friendId'] == _myId) {
      setState(() {
        // 把所有自己发的消息标记为已读
        for (final m in _messages) {
          if (m.senderId == _myId) {
            _readReceipts[m.id] = true;
          }
        }
      });
    }
  }

  // 发送 typing 事件（防抖2秒）
  void _sendTyping() {
    _typingDebounce?.cancel();
    WsService().sendTyping(targetId: widget.friendId, targetType: 1);
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      // 不再输入
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

  // ---------- 发送文字 ----------
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
    setState(() {
      _replyingTo = null;
      _showExtraPanel = false;
      _showEmojiPanel = false;
    });
    // 等 setState 渲染完再请求 focus，否则 TextField 重建后焦点丢失
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
        WsService().sendChatMessage(
          receiverId: widget.friendId,
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

  // ---------- 发送文件 ----------
  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip', 'rar', 'txt', 'mp4', 'apk', 'epub', 'csv']);
    if (result == null || result.files.single.path == null) return;
    setState(() => _showExtraPanel = false);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发送中...'), duration: Duration(seconds: 1)));
    try {
      final resp = await ApiService().uploadChatFile(File(result.files.single.path!));
      if (resp['code'] == 0) {
        final data = resp['data'];
        // 用 msgType=4 代表文件消息，content 存 JSON {url, fileName, fileSize}
        final content = jsonEncode({
          'url': data['url'],
          'fileName': data['originalName'] ?? '',
          'fileSize': data['fileSize'] ?? 0,
          'fileExt': data['fileExt'] ?? '',
        });
        WsService().sendChatMessage(receiverId: widget.friendId, content: content, msgType: 4);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? '文件上传失败')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误')));
    }
  }

  // ---------- 发送语音 ----------
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
        WsService().sendChatMessage(
          receiverId: widget.friendId,
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
    VoiceRecordService().stopRecord(); // 直接丢弃
    setState(() => _showRecordIndicator = false);
  }

  // ---------- 长按菜单 ----------
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
            if (msg.isMine(_myId) && !msg.isRetracted) ...[
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
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text('撤回并编辑', style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  WsService().sendRetract(msgId: msg.id);
                  _inputController.text = msg.content;
                  setState(() {});
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
                  Expanded(
                    child: _isTyping
                        ? const Text('对方正在输入...', style: TextStyle(color: Colors.black45, fontSize: 14, fontStyle: FontStyle.italic), textAlign: TextAlign.center)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(widget.friendName, style: const TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 4),
                              VipIcon(size: 14, isVip: widget.friendIsVip, badge: widget.friendEquippedBadge),
                            ],
                          ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: AppTheme.kSurface,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
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
            onRecordVoice: () async { await _startRecord(); },
            onPickFile: _sendFile,
          ),
          if (_showEmojiPanel) _buildEmojiPanel(),
        ],
      ),
    );
  }

  // ---------- 头像 ----------
  Widget _buildAvatar(String? avatarUrl, {double size = 36}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
      child: (avatarUrl != null && avatarUrl.isNotEmpty)
          ? ClipOval(child: Image.network(GlobalConfig.avatarUrl(avatarUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.black45, size: size * 0.55)))
          : Icon(Icons.person, color: Colors.black45, size: size * 0.55),
    );
  }

  // ---------- 消息气泡 ----------
  Widget _buildMessageItem(ChatMessage msg, int index) {
    final isMine = msg.isMine(_myId);
    // 只有初始加载完之后的新消息才动画
    final shouldAnimate = _initialLoadDone && !_initialMsgIds.contains(msg.id);

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

    ChatMessage? replyMsg;
    if (msg.replyToId != null) {
      try { replyMsg = _messages.firstWhere((m) => m.id == msg.replyToId); } catch (_) {}
    }

    return MessageAnimatedBubble(
      isMine: isMine,
      index: index,
      shouldAnimate: shouldAnimate,
      child: GestureDetector(
        onLongPress: () => _showLongPressMenu(msg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) ...[
                Stack(
                  children: [
                    _buildAvatar(msg.senderAvatar.isEmpty ? widget.friendAvatar : msg.senderAvatar),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: VipIcon(size: 14, isVip: msg.senderIsVip == 1, badge: msg.senderBadge),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: _buildBubbleContent(msg, isMine, replyMsg),
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 8),
                _buildAvatar(_myAvatar),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleContent(ChatMessage msg, bool isMine, ChatMessage? replyMsg) {
    // 适配不同机型：气泡最大宽度 = 屏幕宽度的 72%
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth * 0.72;
    // 图片消息
    if (msg.isImage) {
      return ImageBubble(imageUrl: msg.content, isMine: isMine);
    }
    // 语音消息
    if (msg.isVoice) {
      return VoiceBubble(voiceUrl: msg.content, duration: msg.duration, isMine: isMine);
    }
    // 文件消息（msgType == 4）
    if (msg.msgType == 4) {
      String fileName = '文件';
      String fileExt = '';
      try {
        final map = jsonDecode(msg.content) as Map<String, dynamic>;
        fileName = map['fileName'] ?? '文件';
        fileExt = map['fileExt'] ?? '';
      } catch (_) {}
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.kAccentSoft : AppTheme.kWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4), bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine ? null : Border.all(color: AppTheme.kDivider, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, color: isMine ? AppTheme.kBlack : AppTheme.kSubText, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName, style: TextStyle(color: AppTheme.kBlack, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (fileExt.isNotEmpty) Text(fileExt.toUpperCase(), style: TextStyle(color: AppTheme.kSubText, fontSize: 11)),
              ],
            )),
          ],
        ),
      );
    }
    // 群名片
    if (msg.isGroupCard) {
      return _buildGroupCardBubble(msg, isMine);
    }

    // 普通文字（带引用）
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      decoration: BoxDecoration(
        color: isMine ? AppTheme.kAccentSoft : AppTheme.kWhite,
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
          if (isMine)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(msg.content, style: const TextStyle(color: AppTheme.kBlack, fontSize: 15)),
                const SizedBox(height: 2),
                Icon(
                  (_readReceipts[msg.id] == true) ? Icons.done_all : Icons.done,
                  size: 14,
                  color: (_readReceipts[msg.id] == true) ? AppTheme.kAccent : AppTheme.kSubText,
                ),
              ],
            )
          else
            Text(msg.content, style: const TextStyle(color: Colors.black, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildGroupCardBubble(ChatMessage msg, bool isMine) {
    GroupCardContent? card;
    try {
      final map = jsonDecode(msg.content);
      if (map is Map<String, dynamic>) {
        card = GroupCardContent.fromJson(map);
      }
    } catch (_) {}
    if (card == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.kAccentSoft : AppTheme.kWhite,
          borderRadius: BorderRadius.circular(12),
          border: isMine ? null : Border.all(color: AppTheme.kDivider, width: 0.5),
        ),
        child: Text(msg.content, style: TextStyle(color: AppTheme.kBlack, fontSize: 15)),
      );
    }
    return GestureDetector(
      onTap: () => _onGroupCardTap(card!.groupId, card.groupName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.kAccentSoft : AppTheme.kWhite,
          borderRadius: BorderRadius.circular(12),
          border: isMine ? null : Border.all(color: AppTheme.kDivider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.group, color: isMine ? AppTheme.kBlack : AppTheme.kSubText, size: 24),
            const SizedBox(height: 6),
            Text(card.groupName, style: TextStyle(color: AppTheme.kBlack, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${card.memberCount}人', style: TextStyle(color: AppTheme.kSubText, fontSize: 12)),
          ],
        ),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加入成功')));
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

  // ---------- 输入栏 ----------
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
            if (_showRecordIndicator) _buildRecordIndicator(),
            if (_replyingTo != null) _buildReplyPreview(),
            Row(
              children: [
                // 表情按钮
                GestureDetector(
                  onTap: () => setState(() {
                    _showEmojiPanel = !_showEmojiPanel;
                    if (_showEmojiPanel) _showExtraPanel = false;
                  }),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _showEmojiPanel ? AppTheme.kAccent.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.sentiment_satisfied_alt_outlined, color: _showEmojiPanel ? AppTheme.kAccent : AppTheme.kSubText, size: 24),
                  ),
                ),
                const SizedBox(width: 4),
                // + 额外面板按钮
                GestureDetector(
                  onTap: () => setState(() {
                    _showExtraPanel = !_showExtraPanel;
                    if (_showExtraPanel) _showEmojiPanel = false;
                  }),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _showExtraPanel ? AppTheme.kAccent.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
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
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.mic_none, color: Colors.black54, size: 22),
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

  // ---------- emoji 面板 ----------
  Widget _buildEmojiPanel() {
    final emojis = ['😀','😂','😊','😍','😘','🤔','😢','😡','👍','👎','❤️','🔥','🎉','💯','🙏','😭'];
    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
      child: GridView.count(
        crossAxisCount: 8,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: emojis.map((e) => GestureDetector(
          onTap: () {
            _inputController.text += e;
            setState(() => _showEmojiPanel = false);
          },
          child: Container(
            alignment: Alignment.center,
            child: Text(e, style: const TextStyle(fontSize: 24)),
          ),
        )).toList(),
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

  Widget _buildRecordIndicator() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          const Text('正在录音... 松开发送，向上滑动取消', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
