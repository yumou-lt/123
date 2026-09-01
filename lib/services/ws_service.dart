// ============================================================
// WebSocket 服务：封装 web_socket_channel，支持重连、心跳、消息分发
// 经验教训：连接时必须带 token 做 JWT 鉴权！
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/services/storage_service.dart';

// 全局导航 key，用于从任意地方跳回登录页
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class WsMessage {
  final String type;
  final dynamic data;
  WsMessage({required this.type, required this.data});
  factory WsMessage.fromJson(String json) {
    final map = jsonDecode(json);
    return WsMessage(type: map['type'] ?? '', data: map['data']);
  }
}

class WsService {
  static final WsService _instance = WsService._internal();
  factory WsService() => _instance;
  WsService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectCount = 0;
  static const int _maxReconnectDelay = 30; // 最大重连间隔（秒）

  // 消息回调集合
  final Map<String, List<Function(WsMessage)>> _listeners = {};

  bool get isConnected => _isConnected;

  // ---------- 连接 ----------
  Future<void> connect() async {
    final token = StorageService.getToken();
    if (token == null) return;

    final url = GlobalConfig.wsUrl(token);
    print('[WS] 连接 $url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      _reconnectCount = 0;

      // 监听消息
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // 启动心跳（每30秒发一次 ping）
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_isConnected) {
          send({'type': 'ping'});
        }
      });

      // 派发 reconnected 事件（重连成功后通知页面刷新数据）
      // 如果是重连（不是首次连接），会触发已注册的 reconnect 回调
      _emitReconnected();
    } catch (e) {
      print('[WS] 连接失败: $e');
      _scheduleReconnect();
    }
  }

  // ---------- 重连成功后派发事件（让页面能刷新会话/历史消息） ----------
  final List<Function()> _reconnectListeners = [];
  void onReconnected(Function() callback) => _reconnectListeners.add(callback);
  void offReconnected(Function() callback) => _reconnectListeners.remove(callback);
  void _emitReconnected() {
    for (final fn in _reconnectListeners) {
      try {
        fn();
      } catch (e) {
        print('[WS] reconnect回调异常: $e');
      }
    }
  }

  // ---------- 断开 ----------
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _reconnectCount = 0;
  }

  // ---------- 重连 ----------
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    _isConnected = false;

    _reconnectCount++;
    final delay = _reconnectCount < _maxReconnectDelay ? _reconnectCount : _maxReconnectDelay;
    print('[WS] ${delay}秒后第$_reconnectCount次重连');

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      connect();
    });
  }

  // ---------- 发消息 ----------
  void send(Map<String, dynamic> data) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(data));
    } catch (e) {
      print('[WS] 发送失败: $e');
    }
  }

  // ---------- 收消息 ----------
  void _onMessage(dynamic raw) {
    try {
      final msg = WsMessage.fromJson(raw.toString());
      print('[WS] 收到: ${msg.type}');

      // 心跳响应不派发
      if (msg.type == 'pong' || msg.type == 'hello') return;

      // 强制下线：账号被管理员删除
      if (msg.type == 'account_deleted' || msg.type == 'server_shutdown') {
        final reason = msg.data is Map ? (msg.data['message'] ?? '账号已被强制下线') : '账号已被强制下线';
        _forceLogout(reason);
        return;
      }

      // 派发监听
      final listeners = _listeners[msg.type];
      if (listeners != null) {
        for (final fn in listeners) {
          try {
            fn(msg);
          } catch (e) {
            print('[WS] 回调异常: $e');
          }
        }
      }
    } catch (e) {
      print('[WS] 解析消息失败: $e');
    }
  }

  // ---------- 强制退出登录 ----------
  void _forceLogout(String reason) async {
    print('[WS] 强制退出: $reason');
    await disconnect();
    await StorageService.clearAll();
    // 跳到登录页
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      // 先尝试用 dialog 提示
      try {
        showDialog(
          context: ctx,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('提示'),
            content: Text(reason),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      } catch (_) {
        // dialog 不行就直接跳
        Navigator.of(ctx).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _onError(dynamic error) {
    print('[WS] 错误: $error');
  }

  void _onDone() {
    print('[WS] 连接关闭');
    _heartbeatTimer?.cancel();
    _isConnected = false;
    _scheduleReconnect();
  }

  // ---------- 事件监听 ----------
  void on(String type, Function(WsMessage) callback) {
    _listeners.putIfAbsent(type, () => []).add(callback);
  }

  void off(String type, [Function(WsMessage)? callback]) {
    if (callback == null) {
      _listeners.remove(type);
    } else {
      _listeners[type]?.remove(callback);
    }
  }

  // ---------- 发送单聊消息 ----------
  void sendChatMessage({required int receiverId, required String content, int msgType = 0, int? replyToId, String? replyContent, int duration = 0}) {
    final data = {
      'type': 'chat_message',
      'receiverId': receiverId,
      'content': content,
      'msgType': msgType,
      'duration': duration,
    };
    if (replyToId != null) data['replyToId'] = replyToId;
    if (replyContent != null) data['replyContent'] = replyContent;
    send(data);
  }

  // ---------- 发送群聊消息 ----------
  void sendGroupMessage({required int groupId, required String content, int msgType = 0, int duration = 0}) {
    send({
      'type': 'group_message',
      'groupId': groupId,
      'content': content,
      'msgType': msgType,
      'duration': duration,
    });
  }

  // ---------- 撤回单聊消息 ----------
  void sendRetract({required int msgId}) {
    send({
      'type': 'chat_message_retract',
      'msgId': msgId,
    });
  }

  // ---------- 撤回群聊消息 ----------
  void sendGroupRetract({required int msgId}) {
    send({
      'type': 'group_message_retract',
      'msgId': msgId,
    });
  }

  // ---------- 打字中提示 ----------
  void sendTyping({required int targetId, int targetType = 1}) {
    send({
      'type': 'typing',
      'targetId': targetId,
      'targetType': targetType,
    });
  }

  // ---------- 已读回执 ----------
  void sendReadReceipt({required int friendId, int targetType = 1, int? readUpToMsgId}) {
    send({
      'type': 'read_receipt',
      'friendId': friendId,
      'targetType': targetType,
      if (readUpToMsgId != null) 'readUpToMsgId': readUpToMsgId,
    });
  }

  // ---------- 发送带 @mention 的群聊消息 ----------
  void sendGroupMessageWithMention({
    required int groupId,
    required String content,
    int msgType = 0,
    int duration = 0,
  }) {
    send({
      'type': 'group_message',
      'groupId': groupId,
      'content': content,
      'msgType': msgType,
      'duration': duration,
    });
  }
}
