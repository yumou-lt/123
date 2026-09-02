// ============================================================
// API 服务：Dio 封装，统一处理 Token、错误、Multipart 上传
// 经验教训：Flutter MultipartFile 必须显式设置 contentType！
// ============================================================

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/services/storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: GlobalConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 拦截器：自动加 Token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = StorageService.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // 统一错误提示
        String msg = '网络错误';
        if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout) {
          msg = '无法连接到服务器，请检查网络';
        } else if (error.response != null) {
          final data = error.response?.data;
          if (data is Map<String, dynamic> && data['message'] != null) {
            msg = data['message'].toString();
          }
        }
        // DioException.response 是只读的，这里直接构造带 message 的错误响应
        final dioError = DioException(
          requestOptions: error.requestOptions,
          response: error.response,
          type: error.type,
          error: {'code': error.response?.statusCode ?? 500, 'message': msg},
          message: msg,
        );
        return handler.next(dioError);
      },
    ));
  }

  // ---------- 通用请求 ----------
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    final resp = await _dio.get(path, queryParameters: query);
    return resp.data;
  }

  Future<Map<String, dynamic>> post(String path, dynamic data) async {
    final resp = await _dio.post(path, data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> put(String path, dynamic data) async {
    final resp = await _dio.put(path, data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final resp = await _dio.delete(path);
    return resp.data;
  }

  // ---------- 头像上传（经验教训：MultipartFile 必须显式 contentType！） ----------
  Future<Map<String, dynamic>> uploadAvatar(File file) async {
    // 根据文件扩展名推导 contentType
    final ext = file.path.split('.').last.toLowerCase();
    String contentType;
    if (ext == 'png') {
      contentType = 'image/png';
    } else {
      contentType = 'image/jpeg'; // jpg/jpeg 统一
    }

    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        file.path,
        filename: 'avatar.$ext',
        contentType: DioMediaType.parse(contentType), // ⚠️ 显式设置！
      ),
    });

    final resp = await _dio.post('/user/avatar', data: formData);
    return resp.data;
  }

  // ====================================================================
  // 具体业务接口
  // ====================================================================

  // ---------- 认证 ----------
  Future<Map<String, dynamic>> register({
    required String nickname,
    required String password,
    required String confirmPassword,
  }) async {
    return post('/auth/register', {
      'nickname': nickname,
      'password': password,
      'confirmPassword': confirmPassword,
    });
  }

  Future<Map<String, dynamic>> login({
    required int userId,
    required String password,
  }) async {
    return post('/auth/login', {
      'userId': userId,
      'password': password,
    });
  }

  // ---------- 用户 ----------
  Future<Map<String, dynamic>> getProfile() async => get('/user/profile');

  Future<Map<String, dynamic>> updateNickname(String nickname) async {
    return put('/user/nickname', {'nickname': nickname});
  }

  Future<Map<String, dynamic>> updatePassword(String oldPwd, String newPwd) async {
    return put('/user/password', {'oldPassword': oldPwd, 'newPassword': newPwd});
  }

  // ---------- 好友 ----------
  Future<Map<String, dynamic>> searchFriend(String keyword) async {
    return get('/friend/search', query: {'keyword': keyword});
  }

  Future<Map<String, dynamic>> applyFriend(int friendId) async {
    return post('/friend/apply', {'friendId': friendId});
  }

  Future<Map<String, dynamic>> handleFriendApply(int applicantId, String action) async {
    return put('/friend/handle', {'applicantId': applicantId, 'action': action});
  }

  Future<Map<String, dynamic>> getFriendList() async => get('/friend/list');
  Future<Map<String, dynamic>> getPendingApplies() async => get('/friend/pending');
  Future<Map<String, dynamic>> deleteFriend(int friendId) async => delete('/friend/$friendId');

  // ---------- 单聊消息 ----------
  Future<Map<String, dynamic>> getConversations() async => get('/message/conversations');

  Future<Map<String, dynamic>> getHistory(int friendId, {int page = 1, int pageSize = 500}) async {
    return get('/message/history/$friendId', query: {'page': page, 'pageSize': pageSize});
  }

  Future<Map<String, dynamic>> sendMessage({
    required int receiverId,
    required String content,
    int msgType = 0,
  }) async {
    return post('/message/send', {'receiverId': receiverId, 'content': content, 'msgType': msgType});
  }

  // ---------- 群聊 ----------
  Future<Map<String, dynamic>> createGroup({
    required String groupName,
    required List<int> memberIds,
  }) async {
    return post('/group/create', {'groupName': groupName, 'memberIds': memberIds});
  }

  Future<Map<String, dynamic>> getMyGroups() async => get('/group/my');

  Future<Map<String, dynamic>> getGroupInfo(int groupId) async => get('/group/$groupId/info');

  Future<Map<String, dynamic>> getGroupHistory(int groupId, {int page = 1, int pageSize = 500}) async {
    return get('/group/$groupId/history', query: {'page': page, 'pageSize': pageSize});
  }

  Future<Map<String, dynamic>> sendGroupMessage(int groupId, String content) async {
    return post('/group/$groupId/send', {'content': content});
  }

  Future<Map<String, dynamic>> shareGroupCard(int groupId, int receiverId) async {
    return post('/group/share-card', {'groupId': groupId, 'receiverId': receiverId});
  }

  Future<Map<String, dynamic>> joinGroupByCard(int groupId) async {
    return post('/group/join-by-card', {'groupId': groupId});
  }

  Future<Map<String, dynamic>> leaveGroup(int groupId) async {
    return post('/group/$groupId/leave', {});
  }

  Future<Map<String, dynamic>> dismissGroup(int groupId) async {
    return post('/group/$groupId/dismiss', {});
  }

  // ---------- 公告（公开接口，不需要 token） ----------
  Future<Map<String, dynamic>> getAnnouncement() async {
    // 用不带 token 的 Dio 调公开接口
    final dio = Dio(BaseOptions(baseUrl: GlobalConfig.apiBaseUrl));
    final resp = await dio.get('/announcement/latest');
    return resp.data;
  }

  // ---------- 文件上传 ----------
  Future<Map<String, dynamic>> uploadChatImage(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    String contentType;
    if (ext == 'png') contentType = 'image/png';
    else if (ext == 'gif') contentType = 'image/gif';
    else contentType = 'image/jpeg';

    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        file.path,
        filename: 'chat_$ext',
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final resp = await _dio.post('/upload/chat-image', data: formData);
    return resp.data;
  }

  Future<Map<String, dynamic>> uploadChatVoice(File file, {required int duration}) async {
    final ext = file.path.split('.').last.toLowerCase();
    String contentType = 'audio/mp3';
    if (ext == 'amr') contentType = 'audio/amr';
    else if (ext == 'wav') contentType = 'audio/wav';
    else if (ext == 'm4a') contentType = 'audio/mp4';

    final formData = FormData.fromMap({
      'voice': await MultipartFile.fromFile(
        file.path,
        filename: 'voice_$ext',
        contentType: DioMediaType.parse(contentType),
      ),
      'duration': duration.toString(),
    });
    final resp = await _dio.post('/upload/chat-voice', data: formData);
    return resp.data;
  }

  Future<Map<String, dynamic>> uploadMomentImages(List<File> files) async {
    final formData = FormData();
    for (var i = 0; i < files.length; i++) {
      final ext = files[i].path.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      formData.files.add(MapEntry(
        'images',
        await MultipartFile.fromFile(
          files[i].path,
          filename: 'moment_$i.$ext',
          contentType: DioMediaType.parse(contentType),
        ),
      ));
    }
    final resp = await _dio.post('/upload/moment-images', data: formData);
    return resp.data;
  }

  // ---------- 动态/朋友圈 ----------
  Future<Map<String, dynamic>> publishMoment({required String content, List<String>? images, String? location}) async {
    return post('/moment/publish', {
      'content': content,
      'images': images ?? [],
      'location': location ?? '',
    });
  }

  Future<Map<String, dynamic>> getMomentFeed({int page = 1, int pageSize = 20}) async {
    return get('/moment/feed', query: {'page': page, 'pageSize': pageSize});
  }

  Future<Map<String, dynamic>> getUserMoments(int userId, {int page = 1, int pageSize = 20}) async {
    return get('/moment/user/$userId', query: {'page': page, 'pageSize': pageSize});
  }

  Future<Map<String, dynamic>> likeMoment(int momentId) async {
    return post('/moment/$momentId/like', {});
  }

  Future<Map<String, dynamic>> commentMoment(int momentId, {required String content, int? replyToUserId}) async {
    return post('/moment/$momentId/comment', {
      'content': content,
      'replyToUserId': replyToUserId,
    });
  }

  Future<Map<String, dynamic>> getMomentComments(int momentId) async {
    return get('/moment/$momentId/comments');
  }

  Future<Map<String, dynamic>> deleteMoment(int momentId) async {
    return delete('/moment/$momentId');
  }

  // ---------- 置顶聊天 ----------
  Future<Map<String, dynamic>> pinConversation(int targetId, {int targetType = 1}) async {
    return post('/message/pin', {'targetId': targetId, 'targetType': targetType});
  }

  Future<Map<String, dynamic>> unpinConversation(int targetId, {int targetType = 1}) async {
    return delete('/message/pin?targetId=$targetId&targetType=$targetType');
  }

  Future<Map<String, dynamic>> getPinnedConversations() async => get('/message/pins');

  // ---------- 消息搜索 ----------
  Future<Map<String, dynamic>> searchMessages(String keyword) async {
    return get('/message/search', query: {'keyword': keyword});
  }

  // ---------- 文件上传 ----------
  Future<Map<String, dynamic>> uploadChatFile(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    String contentType;
    if (ext == 'pdf') contentType = 'application/pdf';
    else if (ext == 'zip' || ext == 'rar') contentType = 'application/zip';
    else if (ext == 'doc' || ext == 'docx') contentType = 'application/msword';
    else if (ext == 'xls' || ext == 'xlsx') contentType = 'application/vnd.ms-excel';
    else if (ext == 'mp4' || ext == 'avi') contentType = 'video/mp4';
    else contentType = 'application/octet-stream';

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('\\').last.split('/').last, // 安全取文件名
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final resp = await _dio.post('/upload/chat-file', data: formData);
    return resp.data;
  }

  // ---------- 群聊增强 ----------
  Future<Map<String, dynamic>> getGroupAnnouncement(int groupId) async {
    return get('/group/$groupId/announcement');
  }

  Future<Map<String, dynamic>> setGroupAnnouncement(int groupId, String announcement) async {
    return put('/group/$groupId/announcement', {'announcement': announcement});
  }

  Future<Map<String, dynamic>> retractGroupMessage(int groupId, int msgId) async {
    return post('/group/$groupId/retract', {'msgId': msgId});
  }

  Future<Map<String, dynamic>> setGroupAdmin(int groupId, int userId, {int role = 1}) async {
    return post('/group/$groupId/admin', {'userId': userId, 'role': role});
  }

  Future<Map<String, dynamic>> muteGroupMember(int groupId, int userId, {int minutes = 5}) async {
    return post('/group/$groupId/mute', {'userId': userId, 'minutes': minutes});
  }

  Future<Map<String, dynamic>> kickGroupMember(int groupId, int userId) async {
    return post('/group/$groupId/kick', {'userId': userId});
  }

  // ---------- 会员/签到 ----------
  Future<Map<String, dynamic>> signIn() async => post('/user/sign-in', {});

  Future<List<dynamic>> getBadges() async {
    final r = await get('/user/badges');
    return (r['data'] as List<dynamic>);
  }

  Future<Map<String, dynamic>> equipBadge(String badgeId, bool equip) async {
    return post('/user/badges/equip', {'badgeId': badgeId, 'equip': equip});
  }
}
