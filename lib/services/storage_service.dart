// ============================================================
// 本地存储服务：封装 SharedPreferences
// 存 token、用户ID、昵称、头像等登录后需要持久化的信息
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---------- Token ----------
  static Future<void> saveToken(String token) async {
    await _prefs?.setString('token', token);
  }

  static String? getToken() => _prefs?.getString('token');

  static Future<void> removeToken() async {
    await _prefs?.remove('token');
  }

  // ---------- 用户ID ----------
  static Future<void> saveUserId(int userId) async {
    await _prefs?.setInt('userId', userId);
  }

  static int? getUserId() => _prefs?.getInt('userId');

  static Future<void> removeUserId() async {
    await _prefs?.remove('userId');
  }

  // ---------- 昵称 ----------
  static Future<void> saveNickname(String nickname) async {
    await _prefs?.setString('nickname', nickname);
  }

  static String? getNickname() => _prefs?.getString('nickname');

  static Future<void> removeNickname() async {
    await _prefs?.remove('nickname');
  }

  // ---------- 头像路径 ----------
  static Future<void> saveAvatar(String avatar) async {
    await _prefs?.setString('avatar', avatar);
  }

  static String? getAvatar() => _prefs?.getString('avatar');

  static Future<void> removeAvatar() async {
    await _prefs?.remove('avatar');
  }

  // ---------- 登出：清除所有 ----------
  static Future<void> clearAll() async {
    await _prefs?.clear();
  }

  // ---------- 用户守则确认状态 ----------
  static Future<void> saveAgreementAcknowledged(bool v) async {
    await _prefs?.setBool('agreement_ack', v);
  }

  static bool get agreementAcknowledged => _prefs?.getBool('agreement_ack') ?? false;

  // ---------- 是否已登录 ----------
  static bool get isLoggedIn => getToken() != null && getUserId() != null;
}
