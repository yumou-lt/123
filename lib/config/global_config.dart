// ============================================================
// 全局配置：集中管理所有服务地址（经验教训！）
// 正式部署时只需修改 SERVER_IP 为真实公网IP
// ============================================================

class GlobalConfig {
  // 服务器公网IP（占位符，部署时替换为真实IP）
  static const String SERVER_IP = '120.26.107.11';

  // 后端端口
  static const int SERVER_PORT = 3000;

  // HTTP API 根路径
  static String get apiBaseUrl => 'http://$SERVER_IP:$SERVER_PORT/api';

  // WebSocket 地址（带 token 参数用于鉴权，连接时动态拼接）
  static String wsUrl(String token) => 'ws://$SERVER_IP:$SERVER_PORT/ws?token=$token';

  // 静态资源根路径（头像）
  static String get staticBaseUrl => 'http://$SERVER_IP:$SERVER_PORT';

  // 头像完整URL拼接
  static String avatarUrl(String avatarPath) {
    if (avatarPath.isEmpty) return '';
    if (avatarPath.startsWith('http')) return avatarPath; // 已完整URL
    return '$staticBaseUrl$avatarPath';
  }

  // 用户登录ID（自增ID）
  static const String loginId = 'login_id';
}
