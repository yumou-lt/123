// ============================================================
// 好友申请模型
// ============================================================

class FriendApply {
  final int applicantId; // 申请发起者的用户ID
  final String nickname;
  final String avatar;
  final String createTime;

  FriendApply({
    required this.applicantId,
    required this.nickname,
    required this.avatar,
    required this.createTime,
  });

  factory FriendApply.fromJson(Map<String, dynamic> json) {
    return FriendApply(
      applicantId: json['applicant_id'] ?? json['applicantId'] ?? 0,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      createTime: json['create_time'] ?? '',
    );
  }
}
