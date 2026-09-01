// ============================================================
// 通用聊天组件：图片气泡、语音气泡、灵动动画
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:photo_view/photo_view.dart';

// ---------- 消息气泡动画：入场淡入+缩放 ----------
class MessageAnimatedBubble extends StatefulWidget {
  final Widget child;
  final bool isMine;
  final int index;

  const MessageAnimatedBubble({
    super.key,
    required this.child,
    required this.isMine,
    required this.index,
  });

  @override
  State<MessageAnimatedBubble> createState() => _MessageAnimatedBubbleState();
}

class _MessageAnimatedBubbleState extends State<MessageAnimatedBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _anim = Tween<double>(begin: 0, end: 1).animate(curve);
    // 延迟一点点，制造波浪效果
    Future.delayed(Duration(milliseconds: (widget.index % 10) * 30), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(widget.isMine ? 0.3 : -0.3, 0),
        end: Offset.zero,
      ).animate(_anim),
      child: FadeTransition(
        opacity: _anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(_anim),
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------- 图片气泡 ----------
class ImageBubble extends StatelessWidget {
  final String imageUrl;
  final bool isMine;
  final VoidCallback? onTap;

  const ImageBubble({
    super.key,
    required this.imageUrl,
    required this.isMine,
    this.onTap,
  });

  String _fullUrl(String path) {
    if (path.startsWith('http')) return path;
    return GlobalConfig.staticBaseUrl + path;
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = _fullUrl(imageUrl);
    return GestureDetector(
      onTap: onTap ?? () => _openFullScreen(context, fullUrl),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            fullUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 120,
                height: 120,
                color: Colors.grey.shade200,
                child: const Center(
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black26),
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              width: 120, height: 120,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.black26),
            ),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: PhotoView(
              imageProvider: NetworkImage(url),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
        transitionDuration: const Duration(milliseconds: 200),
        opaque: false,
      ),
    );
  }
}

// ---------- 语音气泡 ----------
class VoiceBubble extends StatefulWidget {
  final String voiceUrl;
  final int duration; // 秒
  final bool isMine;

  const VoiceBubble({
    super.key,
    required this.voiceUrl,
    required this.duration,
    required this.isMine,
  });

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  static final AudioPlayer _player = AudioPlayer();
  static String? _playingUrl;
  bool _playing = false;
  double _playProgress = 0;
  String? _currentUrl; // 当前正在播放的 URL

  String _fullUrl(String path) {
    if (path.startsWith('http')) return path;
    return GlobalConfig.staticBaseUrl + path;
  }

  @override
  void initState() {
    super.initState();
    // 只注册一次监听器
    _player.onPlayerComplete.listen((_) {
      if (mounted && _playingUrl == _currentUrl) {
        setState(() {
          _playing = false;
          _playProgress = 0;
        });
      }
    });

    _player.onPositionChanged.listen((pos) {
      if (widget.duration > 0 && mounted && _playingUrl == _currentUrl) {
        setState(() {
          _playProgress = pos.inSeconds / widget.duration;
          if (_playProgress > 1) _playProgress = 1;
        });
      }
    });
  }

  Future<void> _togglePlay() async {
    final url = _fullUrl(widget.voiceUrl);
    _currentUrl = url;

    if (_playing && _playingUrl == url) {
      await _player.pause();
      setState(() {
        _playing = false;
        _playProgress = 0;
      });
      return;
    }

    // 如果正在播别的，先停
    if (_playingUrl != null) {
      await _player.stop();
    }

    try {
      await _player.play(UrlSource(url));
      setState(() {
        _playing = true;
        _playingUrl = url;
        _playProgress = 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音播放失败')),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_playing) {
      _player.pause();
    }
    if (_playingUrl == _currentUrl) {
      _playingUrl = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.isMine ? const Color(0xFF2196F3) : Colors.white;
    final textColor = widget.isMine ? Colors.white : Colors.black;
    final iconColor = widget.isMine ? Colors.white : Colors.black54;
    final progressColor = widget.isMine ? Colors.white.withOpacity(0.3) : const Color(0xFFE0E0E0);

    // 根据时长决定气泡宽度
    final width = 100 + (widget.duration.clamp(1, 60) * 2.5);

    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: width.clamp(100.0, 220.0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.isMine ? 16 : 4),
            bottomRight: Radius.circular(widget.isMine ? 4 : 16),
          ),
          border: widget.isMine ? null : Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 播放按钮
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _playing
                  ? Icon(Icons.pause, color: iconColor, size: 20, key: const ValueKey('pause'))
                  : Icon(Icons.play_arrow, color: iconColor, size: 20, key: const ValueKey('play')),
            ),
            const SizedBox(width: 8),
            // 波形指示器
            Expanded(
              child: _playing
                  ? Row(
                      children: List.generate(12, (i) {
                        final active = (i / 12) <= _playProgress;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 2,
                          height: 6 + (i % 3) * 3.0,
                          decoration: BoxDecoration(
                            color: active
                                ? (widget.isMine ? Colors.white : Colors.black54)
                                : progressColor,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        );
                      }),
                    )
                  : Row(
                      children: List.generate(8, (i) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 2,
                          height: 6 + (i % 3) * 4.0,
                          decoration: BoxDecoration(
                            color: widget.isMine ? Colors.white54 : Colors.black26,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        );
                      }),
                    ),
            ),
            const SizedBox(width: 6),
            // 时长
            Text('${widget.duration}″', style: TextStyle(color: textColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ---------- 发送中的加载气泡 ----------
class SendingBubble extends StatelessWidget {
  final bool isMine;
  const SendingBubble({super.key, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFF2196F3).withOpacity(0.7) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        border: isMine ? null : Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isMine ? Colors.white : Colors.black45,
            ),
          ),
          const SizedBox(width: 8),
          Text('发送中...', style: TextStyle(color: isMine ? Colors.white : Colors.black45, fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------- 弹出式输入面板（图片/语音按钮） ----------
class ChatExtraPanel extends StatelessWidget {
  final VoidCallback onPickImage;
  final VoidCallback? onPickCamera;
  final VoidCallback onRecordVoice;
  final VoidCallback? onPickFile;

  const ChatExtraPanel({
    super.key,
    required this.onPickImage,
    this.onPickCamera,
    required this.onRecordVoice,
    this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFF5F5F5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('聊天功能', style: TextStyle(color: Colors.black38, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildItem(Icons.image_outlined, '图片', onPickImage),
              const SizedBox(width: 20),
              _buildItem(Icons.camera_alt_outlined, '拍照', onPickCamera ?? onPickImage),
              const SizedBox(width: 20),
              _buildItem(Icons.mic_none, '语音', onRecordVoice),
              if (onPickFile != null) ...[
                const SizedBox(width: 20),
                _buildItem(Icons.insert_drive_file_outlined, '文件', onPickFile!),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
            ),
            child: Icon(icon, color: const Color(0xFF2196F3), size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }
}
