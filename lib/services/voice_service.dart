// ============================================================
// 语音录制服务（使用 record 6.x 包）
// ============================================================

import 'dart:io';
import 'package:record/record.dart';

class VoiceRecordService {
  static final VoiceRecordService _instance = VoiceRecordService._();
  factory VoiceRecordService() => _instance;
  VoiceRecordService._();

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;
  int _startTime = 0;

  // 开始录音，返回录制文件路径
  Future<String?> startRecord() async {
    if (await _recorder.hasPermission()) {
      final dir = await Directory.systemTemp;
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentPath = path;
      _startTime = DateTime.now().millisecondsSinceEpoch;
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: path,
      );
      return path;
    }
    return null;
  }

  // 停止录音，返回 File 和时长(秒)
  Future<VoiceRecordResult?> stopRecord() async {
    final path = await _recorder.stop();
    if (path == null) return null;

    final endTime = DateTime.now().millisecondsSinceEpoch;
    final duration = ((endTime - _startTime) / 1000).round();

    if (!File(path).existsSync()) return null;
    if (duration < 1) return null; // 太短了不算

    return VoiceRecordResult(
      file: File(path),
      duration: duration,
    );
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

class VoiceRecordResult {
  final File file;
  final int duration; // 秒
  VoiceRecordResult({required this.file, required this.duration});
}
