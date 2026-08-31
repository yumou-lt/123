// ============================================================
// 编辑资料页：修改昵称 + 上传头像
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chat_app/config/global_config.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/theme/app_theme.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nicknameController = TextEditingController();
  String _avatar = '';
  File? _avatarFile;
  bool _loading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nicknameController.text = StorageService.getNickname() ?? '';
    _avatar = StorageService.getAvatar() ?? '';
  }

  Future<void> _pickAvatar() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      // 1. 如果头像有变化 → 先上传头像
      if (_avatarFile != null) {
        final avatarResp = await ApiService().uploadAvatar(_avatarFile!);
        if (avatarResp['code'] == 0) {
          _avatar = avatarResp['data']['avatar'];
          await StorageService.saveAvatar(_avatar);
        }
      }

      // 2. 如果昵称有变化 → 修改昵称
      final newNick = _nicknameController.text.trim();
      if (newNick != StorageService.getNickname()) {
        final resp = await ApiService().updateNickname(newNick);
        if (resp['code'] == 0) {
          await StorageService.saveNickname(newNick);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kWhite,
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: AppTheme.kBlack, strokeWidth: 2))
                : const Text('保存', style: TextStyle(color: AppTheme.kBlack, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 头像
          Container(
            height: 120,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.kBlack, width: 2),
                    ),
                    child: _avatarFile != null
                        ? ClipOval(child: Image.file(_avatarFile!, fit: BoxFit.cover))
                        : _avatar.isNotEmpty
                            ? ClipOval(child: Image.network(GlobalConfig.avatarUrl(_avatar), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: AppTheme.kBlack, size: 32)))
                            : const Icon(Icons.person, color: AppTheme.kBlack, size: 32),
                  ),
                  const SizedBox(height: 8),
                  const Text('点击更换头像', style: TextStyle(color: AppTheme.kLightBlack, fontSize: 12)),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // 昵称
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.kDivider, width: 0.5))),
            child: Row(
              children: [
                const Text('昵称', style: TextStyle(color: AppTheme.kBlack, fontSize: 15)),
                const SizedBox(width: 32),
                Expanded(
                  child: TextField(
                    controller: _nicknameController,
                    maxLength: 20,
                    style: const TextStyle(color: AppTheme.kBlack, fontSize: 15),
                    decoration: const InputDecoration(isDense: true, counterText: ''),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
