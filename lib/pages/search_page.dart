// ============================================================
// 全局消息搜索页
// ============================================================

import 'package:flutter/material.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/pages/chat_page.dart';
import 'package:chat_app/pages/group_chat_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final resp = await ApiService().searchMessages(keyword);
      setState(() {
        _results = List<Map<String, dynamic>>.from(resp['data'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<TextSpan> _highlightText(String text, String keyword) {
    if (keyword.isEmpty) return [TextSpan(text: text)];
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final lowerKw = keyword.toLowerCase();
    int start = 0;
    while (true) {
      final idx = lower.indexOf(lowerKw, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
      spans.add(TextSpan(
        text: text.substring(idx, idx + keyword.length),
        style: const TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.w600),
      ));
      start = idx + keyword.length;
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Container(
          height: 36,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(18)),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: const InputDecoration(
              icon: Icon(Icons.search, size: 20, color: Colors.black38),
              hintText: '搜索消息内容...',
              hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _search,
            child: const Text('搜索', style: TextStyle(color: Colors.black87, fontSize: 14)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _searched && _results.isEmpty
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off, size: 48, color: Colors.black26),
                  SizedBox(height: 12),
                  Text('没有找到相关消息', style: TextStyle(color: Colors.black45)),
                ]))
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 0.5, thickness: 0.5, indent: 72, color: Color(0xFFEEEEEE)),
                  itemBuilder: (_, i) {
                    final item = _results[i];
                    final isGroup = item['targetType'] == 2;
                    final name = item['peerName'] ?? item['groupName'] ?? '';
                    final content = item['content'] ?? '';
                    final keyword = _controller.text.trim();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade100,
                        child: Icon(isGroup ? Icons.group : Icons.person, color: Colors.black54, size: 22),
                      ),
                      title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
                      subtitle: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                          children: _highlightText(content, keyword),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        item['createTime'] ?? item['create_time'] ?? '',
                        style: const TextStyle(color: Colors.black38, fontSize: 11),
                      ),
                      onTap: () {
                        if (isGroup) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => GroupChatPage(groupId: item['groupId'] ?? item['targetId'], groupName: name),
                          ));
                        } else {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ChatPage(friendId: item['friendId'] ?? item['targetId'], friendName: name),
                          ));
                        }
                      },
                    );
                  },
                ),
    );
  }
}
