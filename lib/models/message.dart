// ============================================================
// 消息模型
// msg_type: 0=文字, 1=群名片, 2=图片, 3=语音
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
  final int duration; // 语音时长(秒)，图片可存0
  final int senderIsVip;
  final String? senderBadge;

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
    this.duration = 0,
    this.senderIsVip = 0,
    this.senderBadge,
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
      duration: json['duration'] ?? 0,
      senderIsVip: (json['sender_is_vip'] ?? json['senderIsVip'] ?? 0) as int,
      senderBadge: json['sender_badge'] as String?,
    );
  }

  bool get isImage => msgType == 2;
  bool get isVoice => msgType == 3;
  bool get isText => msgType == 0;
  bool get isGroupCard => msgType == 1;

  bool isMine(int myId) => senderId == myId;
}

class GroupMessage {
  final int id;
  final int senderId;
  final String senderNickname;
  final String senderAvatar;
  final String content;
  final String createTime;
  bool isRetracted;
  final int msgType;
  final int duration;
  final int senderIsVip;
  final String? senderBadge;

  GroupMessage({
    required this.id,
    required this.senderId,
    required this.senderNickname,
    this.senderAvatar = '',
    required this.content,
    required this.createTime,
    this.isRetracted = false,
    this.msgType = 0,
    this.duration = 0,
    this.senderIsVip = 0,
    this.senderBadge,
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
      msgType: json['msg_type'] ?? json['msgType'] ?? 0,
      duration: json['duration'] ?? 0,
      senderIsVip: (json['sender_is_vip'] ?? json['senderIsVip'] ?? 0) as int,
      senderBadge: json['sender_badge'] as String?,
    );
  }

  bool get isImage => msgType == 2;
  bool get isVoice => msgType == 3;

  bool isMine(int myId) => senderId == myId;
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

// ============================================================
// 动态/朋友圈模型
// ============================================================
class Moment {
  final int id;
  final int userId;
  final String nickname;
  final String avatar;
  final String content;
  final List<String> images;
  final String location;
  final String createTime;
  final int likeCount;
  final bool isLiked;
  final int commentCount;

  Moment({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.content,
    required this.images,
    required this.location,
    required this.createTime,
    required this.likeCount,
    required this.isLiked,
    required this.commentCount,
  });

  factory Moment.fromJson(Map<String, dynamic> json) {
    final imagesRaw = json['images'];
    List<String> images = [];
    if (imagesRaw is List) {
      images = imagesRaw.map((e) => e.toString()).toList();
    } else if (imagesRaw is String && imagesRaw.isNotEmpty) {
      try {
        final decoded = imagesRaw.replaceAll(RegExp(r'[^\x00-\x7F]+'), '');
        // 简单处理：后端已解析好
      } catch (_) {}
    }
    return Moment(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      content: json['content'] ?? '',
      images: images,
      location: json['location'] ?? '',
      createTime: json['createTime'] ?? json['create_time'] ?? '',
      likeCount: json['likeCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      commentCount: json['commentCount'] ?? 0,
    );
  }
}

class MomentComment {
  final int id;
  final int userId;
  final String nickname;
  final String avatar;
  final String content;
  final int? replyToUserId;
  final String? replyToNickname;
  final String createTime;

  MomentComment({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.content,
    this.replyToUserId,
    this.replyToNickname,
    required this.createTime,
  });

  factory MomentComment.fromJson(Map<String, dynamic> json) {
    return MomentComment(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      content: json['content'] ?? '',
      replyToUserId: json['replyToUserId'],
      replyToNickname: json['replyToNickname'],
      createTime: json['createTime'] ?? '',
    );
  }
}
