// ============================================================
// 添加好友页：简约白底
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/services/api_service.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  Future<void> _search() async {
    final kw = _searchController.text.trim();
    if (kw.isEmpty) return;

    setState(() {
      _searching = true;
      _results = [];
    });

    try {
      final resp = await ApiService().searchFriend(kw);
      setState(() {
        _results = List<Map<String, dynamic>>.from(resp['data'] ?? []);
        _searching = false;
      });
    } catch (e) {
      setState(() => _searching = false);
    }
  }

  Future<void> _apply(int friendId) async {
    final resp = await ApiService().applyFriend(friendId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp['message'] ?? '')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('添加好友', style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // 搜索框
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '输入昵称或用户ID搜索',
                hintStyle: const TextStyle(color: Colors.black38),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.black54),
                  onPressed: _search,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
          ),
          const Divider(height: 1),
          // 搜索结果
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _results.isEmpty
                    ? const Center(child: Text('输入关键字搜索用户', style: TextStyle(color: Colors.black38)))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final u = _results[i];
                          return Container(
                            height: 72,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                                  child: const Icon(Icons.person, color: Colors.black54, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u['nickname'] ?? '', style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text('ID: ${u['id']}', style: const TextStyle(color: Colors.black38, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _apply(u['id']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('添加', style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
