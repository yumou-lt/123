// ============================================================
// 自动更新服务：检查版本 → 下载 APK → 校验 → 调起安装
// 支持 Android/iOS，iOS 跳 App Store
// 状态机: idle → checking → downloading → installing → done/failed
// ============================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_app/config/global_config.dart';

enum UpdateStatus { idle, checking, downloading, installing, done, failed, noUpdate }

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  UpdateStatus _status = UpdateStatus.idle;
  UpdateStatus get status => _status;

  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Map<String, dynamic>? _latestVersionInfo;
  Map<String, dynamic>? get latestVersionInfo => _latestVersionInfo;

  PackageInfo? _currentPackage;
  String get currentVersionName => _currentPackage?.version ?? '0.0.0';
  String get currentVersionCode => _currentPackage?.buildNumber ?? '0';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // 状态变化回调
  final List<Function(UpdateStatus)> _statusListeners = [];
  void addStatusListener(Function(UpdateStatus) cb) => _statusListeners.add(cb);
  void removeStatusListener(Function(UpdateStatus) cb) => _statusListeners.remove(cb);

  final List<Function(double)> _progressListeners = [];
  void addProgressListener(Function(double) cb) => _progressListeners.add(cb);
  void removeProgressListener(Function(double) cb) => _progressListeners.remove(cb);

  void _emitStatus(UpdateStatus s) {
    _status = s;
    for (final fn in _statusListeners) {
      try { fn(s); } catch (_) {}
    }
  }

  void _emitProgress(double p) {
    _downloadProgress = p;
    for (final fn in _progressListeners) {
      try { fn(p); } catch (_) {}
    }
  }

  // ============================================================
  // 1. 初始化（读当前版本）
  // ============================================================
  Future<void> init() async {
    try {
      _currentPackage = await PackageInfo.fromPlatform();
    } catch (_) {}
  }

  // ============================================================
  // 2. 检查更新
  // ============================================================
  Future<bool> checkUpdate() async {
    _emitStatus(UpdateStatus.checking);
    _errorMessage = null;

    try {
      final resp = await _dio.get(
        '${GlobalConfig.apiBaseUrl}/version',
        options: Options(headers: {'Authorization': 'none'}), // 公开接口
      );
      final data = resp.data;
      if (data is Map<String, dynamic> && data['code'] == 0 && data['data'] != null) {
        _latestVersionInfo = data['data'];
        return _compareVersion();
      }
      _emitStatus(UpdateStatus.noUpdate);
      return false;
    } catch (e) {
      _errorMessage = '检查更新失败: $e';
      _emitStatus(UpdateStatus.failed);
      return false;
    }
  }

  // ============================================================
  // 3. 版本对比
  // ============================================================
  bool _compareVersion() {
    if (_latestVersionInfo == null) return false;
    final latestCode = _latestVersionInfo!['versionCode'] as int? ?? 0;
    final minSupportedCode = _latestVersionInfo!['minSupportedCode'] as int? ?? 0;

    int currentCode;
    try {
      currentCode = int.parse(_currentPackage?.buildNumber ?? '0');
    } catch (_) {
      currentCode = 0;
    }

    // 低于最低支持版本 → 强制更新
    if (currentCode < minSupportedCode) {
      _emitStatus(UpdateStatus.done); // done 但有更新
      return true;
    }

    // 有新版
    if (latestCode > currentCode) {
      _emitStatus(UpdateStatus.done);
      return true;
    }

    _emitStatus(UpdateStatus.noUpdate);
    return false;
  }

  // 是否强制更新
  bool get isForceUpdate {
    if (_latestVersionInfo == null) return false;
    if (_latestVersionInfo!['forceUpdate'] == true) return true;
    final minSupportedCode = _latestVersionInfo!['minSupportedCode'] as int? ?? 0;
    int currentCode = 0;
    try {
      currentCode = int.parse(_currentPackage?.buildNumber ?? '0');
    } catch (_) {}
    return currentCode < minSupportedCode;
  }

  String get updateUrl => _latestVersionInfo!['downloadUrl'] ?? '';
  String get latestVersionName => _latestVersionInfo!['versionName'] ?? '';
  List<String> get updateLog {
    final log = _latestVersionInfo!['updateLog'];
    if (log is List) return List<String>.from(log);
    return [];
  }

  // ============================================================
  // 4. 下载 APK
  // ============================================================
  Future<File?> downloadApk() async {
    if (updateUrl.isEmpty) {
      _errorMessage = '下载地址为空';
      _emitStatus(UpdateStatus.failed);
      return null;
    }

    _emitProgress(0);
    _emitStatus(UpdateStatus.downloading);

    try {
      // Android 13+ 需要动态申请安装未知应用权限
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          _errorMessage = '请允许安装未知应用';
          _emitStatus(UpdateStatus.failed);
          return null;
        }
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'LengTingYu_${latestVersionName}_update.apk';
      final savePath = '${dir.path}/$fileName';

      final file = File(savePath);
      if (await file.exists()) await file.delete();

      // 节流进度回调（每 5% 推送一次）
      double lastEmit = -1;
      await _dio.download(
        updateUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final progress = received / total;
          final rounded = (progress * 20).roundToDouble() / 20; // 5% 粒度
          if ((rounded - lastEmit).abs() >= 0.05) {
            lastEmit = rounded;
            _emitProgress(progress);
          }
        },
      );

      _emitProgress(1);
      _emitStatus(UpdateStatus.installing);

      return file;
    } catch (e) {
      _errorMessage = '下载失败: $e';
      _emitStatus(UpdateStatus.failed);
      return null;
    }
  }

  // ============================================================
  // 5. 安装（Android 调起系统安装器，iOS 跳 App Store）
  // ============================================================
  Future<void> installApk(File file) async {
    _emitStatus(UpdateStatus.installing);
    try {
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result != ResultType.done) {
        _errorMessage = '安装启动失败';
        _emitStatus(UpdateStatus.failed);
      }
    } catch (e) {
      _errorMessage = '安装失败: $e';
      _emitStatus(UpdateStatus.failed);
    }
  }

  // ============================================================
  // 获取缓存大小（清除缓存用）
  // ============================================================
  Future<String> getCacheSizeText() async {
    try {
      final dir = await getTemporaryDirectory();
      int total = await _dirSize(dir);
      return _formatSize(total);
    } catch (_) {
      return '0 KB';
    }
  }

  Future<void> clearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      await _deleteDirContents(dir);
    } catch (_) {}
  }

  Future<int> _dirSize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try { total += await entity.length(); } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _deleteDirContents(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        try { await entity.delete(recursive: true); } catch (_) {}
      }
    } catch (_) {}
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
