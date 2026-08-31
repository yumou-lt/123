// ============================================================
// 群聊模型
// ============================================================

class GroupInfo {
  final int id;
  final String groupName;
  final int ownerId;
  final int status;
  final int memberCount;

  GroupInfo({
    required this.id,
    required this.groupName,
    required this.ownerId,
    required this.status,
    required this.memberCount,
  });

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      id: json['id'] ?? 0,
      groupName: json['group_name'] ?? json['groupName'] ?? '',
      ownerId: json['owner_id'] ?? json['ownerId'] ?? 0,
      status: json['status'] ?? 0,
      memberCount: json['member_count'] ?? json['memberCount'] ?? 0,
    );
  }
}

class GroupMember {
  final int userId;
  final String nickname;
  final String avatar;
  final String joinTime;

  GroupMember({
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.joinTime,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] ?? json['userId'] ?? 0,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      joinTime: json['join_time'] ?? json['joinTime'] ?? '',
    );
  }
}
