// ============================================================
// 朋友圈/动态 列表页
// ============================================================

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/theme/app_theme.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/models/message.dart';
import 'package:chat_app/pages/publish_moment_page.dart';
import 'package:chat_app/widgets/chat_widgets.dart';
import 'package:intl/intl.dart';

class MomentPage extends StatefulWidget {
  const MomentPage({super.key});

  @override
  State<MomentPage> createState() => _MomentPageState();
}

class _MomentPageState extends State<MomentPage> with AutomaticKeepAliveClientMixin {
  final List<Moment> _moments = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = true;
      _page = 1;
    });
    try {
      final resp = await ApiService().getMomentFeed(page: 1);
      final list = List<Map<String, dynamic>>.from(resp['data'] ?? []);
      setState(() {
        _moments.clear();
        for (final m in list) {
          final imagesRaw = m['images'];
          List<String> images = [];
          if (imagesRaw is List) {
            images = imagesRaw.map((e) => e.toString()).toList();
          }
          _moments.add(Moment(
            id: m['id'] ?? 0,
            userId: m['userId'] ?? 0,
            nickname: m['nickname'] ?? '',
            avatar: m['avatar'] ?? '',
            content: m['content'] ?? '',
            images: images,
            location: m['location'] ?? '',
            createTime: m['createTime'] ?? '',
            likeCount: m['likeCount'] ?? 0,
            isLiked: m['isLiked'] ?? false,
            commentCount: m['commentCount'] ?? 0,
          ));
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加载失败')));
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      _page++;
      final resp = await ApiService().getMomentFeed(page: _page);
      final list = List<Map<String, dynamic>>.from(resp['data'] ?? []);
      if (list.isEmpty) {
        setState(() => _page--);
      } else {
        setState(() {
          for (final m in list) {
            final imagesRaw = m['images'];
            List<String> images = [];
            if (imagesRaw is List) {
              images = imagesRaw.map((e) => e.toString()).toList();
            }
            _moments.add(Moment(
              id: m['id'] ?? 0,
              userId: m['userId'] ?? 0,
              nickname: m['nickname'] ?? '',
              avatar: m['avatar'] ?? '',
              content: m['content'] ?? '',
              images: images,
              location: m['location'] ?? '',
              createTime: m['createTime'] ?? '',
              likeCount: m['likeCount'] ?? 0,
              isLiked: m['isLiked'] ?? false,
              commentCount: m['commentCount'] ?? 0,
            ));
          }
        });
      }
    } catch (_) {
      _page--;
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleLike(int index) async {
    final m = _moments[index];
    try {
      final resp = await ApiService().likeMoment(m.id);
      if (resp['code'] == 0) {
        final liked = resp['data']['liked'] ?? false;
        setState(() {
          _moments[index] = Moment(
            id: m.id,
            userId: m.userId,
            nickname: m.nickname,
            avatar: m.avatar,
            content: m.content,
            images: m.images,
            location: m.location,
            createTime: m.createTime,
            likeCount: liked ? m.likeCount + 1 : m.likeCount - 1,
            isLiked: liked,
            commentCount: m.commentCount,
          );
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.kSurface,
      body: Stack(
        children: [
            RefreshIndicator(
            color: AppTheme.kAccent,
            onRefresh: _loadFeed,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _moments.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('暂无动态，快去发布第一条吧！', style: TextStyle(color: Colors.black38))),
                        ],
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        itemCount: _moments.length,
                        itemBuilder: (_, i) => _buildMomentCard(_moments[i], i),
                      ),
          ),
          // 发布按钮
          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PublishMomentPage(),
                ));
                if (result == true) _loadFeed();
              },
              backgroundColor: AppTheme.kAccent,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMomentCard(Moment m, int index) {
    return MessageAnimatedBubble(
      isMine: m.userId == (StorageService.getUserId() ?? 0),
      index: index,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.kDivider, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：头像 + 昵称 + 时间
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                  child: (m.avatar.isNotEmpty)
                      ? ClipOval(child: Image.network(GlobalConfig.avatarUrl(m.avatar), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.black45)))
                      : const Icon(Icons.person, color: Colors.black45),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.nickname, style: const TextStyle(color: AppTheme.kAccent, fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(_formatTime(m.createTime), style: const TextStyle(color: Colors.black38, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 文字内容
            if (m.content.isNotEmpty)
              Text(m.content, style: const TextStyle(color: Colors.black, fontSize: 14, height: 1.5)),
            // 图片网格
            if (m.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildImageGrid(m.images),
            ],
            // 地点
            if (m.location.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.black38, size: 14),
                  const SizedBox(width: 3),
                  Text(m.location, style: const TextStyle(color: Colors.black38, fontSize: 12)),
                ],
              ),
            ],
            // 操作栏
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: m.isLiked ? Colors.red.withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          m.isLiked ? Icons.favorite : Icons.favorite_border,
                          color: m.isLiked ? Colors.red : Colors.black45,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text('${m.likeCount}', style: TextStyle(color: m.isLiked ? Colors.red : Colors.black45, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.black45, size: 16),
                    const SizedBox(width: 4),
                    Text('${m.commentCount}', style: const TextStyle(color: Colors.black45, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> images) {
    // 最多3列
    int crossAxisCount = 3;
    if (images.length == 1) crossAxisCount = 1;
    else if (images.length == 2 || images.length == 4) crossAxisCount = 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: images.length,
      itemBuilder: (_, i) {
        final url = images[i].startsWith('http') ? images[i] : GlobalConfig.staticBaseUrl + images[i];
        return GestureDetector(
          onTap: () => _openImagePreview(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(url, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.black26)),
            ),
          ),
        );
      },
    );
  }

  void _openImagePreview(String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: PhotoView(
              imageProvider: NetworkImage(url),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),
        ),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  String _formatTime(String t) {
    if (t.isEmpty) return '';
    try {
      String s = t.replaceFirst(' ', 'T');
      if (!s.contains('Z') && !s.contains('+') && !s.contains('-')) s = s + 'Z';
      final dt = DateTime.parse(s).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return DateFormat('MM-dd HH:mm').format(dt);
    } catch (_) { return t; }
  }
}
