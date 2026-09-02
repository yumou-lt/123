// ============================================================
// MJ 特效 Overlay —— 全局单例
// 顶部飘 2 秒 + 连续发触发霸屏（不可关闭，需大退复活）
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// MJ 特效全局管理器
class MjEffect {
  MjEffect._();
  static final MjEffect _instance = MjEffect._();
  factory MjEffect() => _instance;

  /// 记录每个用户连续发 mj 的次数
  final Map<int, int> _userMjCount = {};

  /// 同一用户 2 秒内重复触发算连续，超时清零
  final Map<int, Timer?> _resetTimers = {};

  /// 当前是否已经霸屏（霸屏后不再响应，直到应用被大退）
  bool _chaoping = false;
  bool get isChaoping => _chaoping;

  /// 触发一次（传当前页面 context）
  /// [senderId] 发送者 userId，用于判断连续触发
  void trigger({required BuildContext context, required int senderId}) {
    if (_chaoping) return; // 已霸屏就不重复加了

    final count = (_userMjCount[senderId] ?? 0) + 1;
    _userMjCount[senderId] = count;

    // 重置计时器：2 秒内没再发就清零
    _resetTimers[senderId]?.cancel();
    _resetTimers[senderId] = Timer(const Duration(seconds: 2), () {
      _userMjCount.remove(senderId);
      _resetTimers.remove(senderId);
    });

    if (count >= 3) {
      _triggerChaoping(context);
    } else {
      _triggerNormal(context);
    }
  }

  /// 顶部飘一个（2 秒自动消失）
  void _triggerNormal(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _MjTopVideo(onDone: () {
        if (entry.mounted) entry.remove();
      }),
    );
    overlay.insert(entry);
  }

  /// 霸屏：8 个视频铺满全屏（不可关闭）
  void _triggerChaoping(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);

    _chaoping = true;

    final entry = OverlayEntry(
      builder: (_) => const _MjChaoping(),
    );
    overlay.insert(entry);
  }
}

// ---------- 顶部飘（2 秒） ----------
class _MjTopVideo extends StatefulWidget {
  final VoidCallback onDone;
  const _MjTopVideo({required this.onDone});

  @override
  State<_MjTopVideo> createState() => _MjTopVideoState();
}

class _MjTopVideoState extends State<_MjTopVideo> {
  VideoPlayerController? _controller;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.asset('assets/effects/mj.mp4');
    await _controller!.initialize();
    _controller!.setVolume(0); // 静音
    _controller!.setLooping(true);
    if (mounted) {
      setState(() {
        _controller!.play();
      });
      // 视频真正开始播放后再计时 2 秒，保证完整展示
      _autoClose = Timer(const Duration(seconds: 2), widget.onDone);
    }
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 50),
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 20)],
            ),
            clipBehavior: Clip.antiAlias,
            child: _controller != null && _controller!.value.isInitialized
                ? VideoPlayer(_controller!)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

// ---------- 霸屏（8 个视频铺满全屏，2 行 × 4 列） ----------
class _MjChaoping extends StatefulWidget {
  const _MjChaoping();

  @override
  State<_MjChaoping> createState() => _MjChaopingState();
}

class _MjChaopingState extends State<_MjChaoping> {
  final List<VideoPlayerController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _initVideos();
  }

  Future<void> _initVideos() async {
    // 创建 8 个 controller（2 行 × 4 列铺满全屏）
    for (int i = 0; i < 8; i++) {
      final c = VideoPlayerController.asset('assets/effects/mj.mp4');
      await c.initialize();
      c.setVolume(0); // 静音
      c.setLooping(true);
      c.play();
      _controllers.add(c);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 全屏黑底 + 8 个视频网格铺满（2 行 x 4 列），居中提示文字浮在最上层
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // 8 个视频铺满全屏
            Column(
              children: List.generate(2, (row) {
                return Expanded(
                  child: Row(
                    children: List.generate(4, (col) {
                      final idx = row * 4 + col;
                      final c = idx < _controllers.length ? _controllers[idx] : null;
                      return Expanded(
                        child: c != null && c.value.isInitialized
                            ? VideoPlayer(c)
                            : const ColoredBox(color: Colors.black),
                      );
                    }),
                  ),
                );
              }),
            ),
            // 浮层提示文字（不拦截点击）
            IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: 0.1,
                  child: const Text(
                    'MJ 霸屏！🎉',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.yellow, blurRadius: 12)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
