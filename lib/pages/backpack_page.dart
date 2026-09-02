import 'package:flutter/material.dart';
import '../services/api_service.dart';

class Badge {
  final String id;
  final String name;
  final String icon;
  bool equipped;
  Badge({required this.id, required this.name, required this.icon, required this.equipped});
  factory Badge.fromJson(Map<String, dynamic> j) => Badge(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String? ?? '',
        equipped: j['equipped'] as bool? ?? false,
      );
}

/// 背包页 — 管理徽章
class BackpackPage extends StatefulWidget {
  const BackpackPage({super.key});

  @override
  State<BackpackPage> createState() => _BackpackPageState();
}

class _BackpackPageState extends State<BackpackPage> {
  bool _loading = true;
  List<Badge> _badges = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService().getBadges();
      setState(() {
        _badges = list.map((e) => Badge.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _equip(Badge b) async {
    try {
      final res = await ApiService().equipBadge(b.id, !b.equipped);
      if (res['code'] == 0) {
        setState(() {
          // 先全部设为未装备，再更新当前状态
          for (var badge in _badges) {
            badge.equipped = false;
          }
          b.equipped = !b.equipped;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(b.equipped ? '✅ 已装备 ${b.name}' : '已卸下')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('我的背包'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _badges.isEmpty
              ? _buildEmpty()
              : _buildGrid(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('背包空空如也', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 4),
          Text('去活动中心签到领取吧', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _badges.length,
      itemBuilder: (ctx, i) {
        final b = _badges[i];
        return _BadgeCard(badge: b, onTap: () => _equip(b));
      },
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Badge badge;
  final VoidCallback onTap;
  const _BadgeCard({required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: badge.equipped ? Border.all(color: const Color(0xFFFF8C00), width: 2) : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            badge.icon == 'vip'
                ? Image.asset('assets/icons/vip.webp', width: 48, height: 48)
                : Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(badge.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: badge.equipped ? const Color(0xFFFF8C00) : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge.equipped ? '装备中' : '点击装备',
                style: TextStyle(color: badge.equipped ? Colors.white : Colors.black54, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
