// ============================================================
// 消息模型
// ============================================================

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final int msgType;
  final int isRead;
  final String createTime;
  final String senderAvatar;
  final String senderNickname;
  final bool isRetracted;
  final int? replyToId;
  final String? replyContent;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.msgType,
    required this.isRead,
    required this.createTime,
    this.senderAvatar = '',
    this.senderNickname = '',
    this.isRetracted = false,
    this.replyToId,
    this.replyContent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? json['msgId'] ?? 0,
      senderId: json['sender_id'] ?? json['senderId'] ?? 0,
      receiverId: json['receiver_id'] ?? 0,
      content: json['content'] ?? '',
      msgType: json['msg_type'] ?? json['msgType'] ?? 0,
      isRead: json['is_read'] ?? 0,
      createTime: json['create_time'] ?? json['createTime'] ?? '',
      senderAvatar: json['sender_avatar'] ?? json['senderAvatar'] ?? '',
      senderNickname: json['sender_nickname'] ?? json['senderNickname'] ?? '',
      isRetracted: (json['is_retracted'] ?? 0) == 1 || json['isRetracted'] == true,
      replyToId: json['reply_to_id'] ?? json['replyToId'],
      replyContent: json['reply_content'] ?? json['replyContent'],
    );
  }

  bool isMine(int myId) => senderId == myId;
}

class GroupMessage {
  final int id;
  final int senderId;
  final String senderNickname;
  final String senderAvatar;
  final String content;
  final String createTime;
  final bool isRetracted;

  GroupMessage({
    required this.id,
    required this.senderId,
    required this.senderNickname,
    this.senderAvatar = '',
    required this.content,
    required this.createTime,
    this.isRetracted = false,
  });

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    return GroupMessage(
      id: json['id'] ?? json['msgId'] ?? 0,
      senderId: json['sender_id'] ?? json['senderId'] ?? 0,
      senderNickname: json['sender_nickname'] ?? json['senderNickname'] ?? json['nickname'] ?? '',
      senderAvatar: json['sender_avatar'] ?? json['senderAvatar'] ?? json['avatar'] ?? '',
      content: json['content'] ?? '',
      createTime: json['create_time'] ?? json['createTime'] ?? '',
      isRetracted: (json['is_retracted'] ?? 0) == 1,
    );
  }
}

class GroupCardContent {
  final int groupId;
  final String groupName;
  final int memberCount;
  GroupCardContent({required this.groupId, required this.groupName, required this.memberCount});
  factory GroupCardContent.fromJson(Map<String, dynamic> json) {
    return GroupCardContent(
      groupId: json['groupId'] ?? 0,
      groupName: json['groupName'] ?? '',
      memberCount: json['memberCount'] ?? 0,
    );
  }
}
