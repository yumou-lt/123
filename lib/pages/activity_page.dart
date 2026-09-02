import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// 活动页 — 每日签到领会员
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool _loading = true;
  bool _signed = false;
  bool _isVip = false;
  String? _vipExpire;
  String _lastSignDate = '';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = await ApiService().getProfile();
      if (profile != null) {
        setState(() {
          _isVip = profile['is_vip'] == 1;
          _vipExpire = profile['vip_expire'];
        });
      }
      // 检查今日是否已签
      final today = DateTime.now().toString().substring(0, 10);
      final last = prefs.getString('last_sign_in') ?? '';
      setState(() {
        _lastSignDate = last;
        _signed = last == today;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _signIn() async {
    if (_signed) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().signIn();
      if (res['code'] == 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_sign_in', DateTime.now().toString().substring(0, 10));
        final data = res['data'];
        if (data?['gotVip'] == true) {
          setState(() {
            _signed = true;
            _isVip = true;
            _loading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('🎉 ${res['message']}'), backgroundColor: Colors.orange),
            );
          }
        } else {
          setState(() {
            _signed = true;
            _loading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✅ ${res['message']}')),
            );
          }
        }
      } else {
        setState(() => _loading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? '签到失败')));
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('活动中心'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 顶部会员状态卡片
                _buildVipCard(),
                const SizedBox(height: 16),
                // 签到卡片
                _buildSignCard(),
                const SizedBox(height: 16),
                // 活动说明
                _buildRules(),
              ],
            ),
    );
  }

  Widget _buildVipCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity( 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity( 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isVip ? '尊贵会员' : '普通用户',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _isVip && _vipExpire != null ? '到期：${_vipExpire.toString().substring(0, 10)}' : '签到领3天会员',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity( 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available, color: Color(0xFFFF8C00), size: 20),
              const SizedBox(width: 8),
              const Text('每日签到', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(_signed ? '今日已签到 ✓' : '去签到', style: TextStyle(color: _signed ? Colors.green : Color(0xFF2196F3), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _signed || _loading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: _signed ? Colors.grey.shade300 : const Color(0xFFFF8C00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              child: Text(
                _signed ? '已签到' : '立即签到',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRules() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('活动规则', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
            '1. 每天可签到 1 次\n2. 每连续签到 7 天可获得 3 天会员\n3. 获得的会员标识可在"背包"中装备\n4. 装备后聊天/资料页会显示会员图标',
            style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}
