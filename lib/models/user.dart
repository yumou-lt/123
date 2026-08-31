// ============================================================
// 用户模型
// ============================================================

class User {
  final int id;
  final String nickname;
  final String avatar;

  User({required this.id, required this.nickname, required this.avatar});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
    );
  }
}

// 好友（含未读数、最后一条消息）
class ConversationFriend {
  final int userId;
  final String nickname;
  final String avatar;
  final int unread;
  final String lastMessage;
  final int lastMsgType;
  final String? lastTime;

  ConversationFriend({
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.unread,
    required this.lastMessage,
    required this.lastMsgType,
    this.lastTime,
  });

  factory ConversationFriend.fromJson(Map<String, dynamic> json) {
    return ConversationFriend(
      userId: json['userId'] ?? 0,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      unread: json['unread'] ?? 0,
      lastMessage: json['lastMessage'] ?? '',
      lastMsgType: json['lastMsgType'] ?? 0,
      lastTime: json['lastTime'],
    );
  }
}
