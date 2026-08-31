// ============================================================
// 用户守则页
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:chat_app/pages/main_page.dart';

class UserAgreementPage extends StatefulWidget {
  final bool enforce; // 强制模式：无法跳过、无法返回
  const UserAgreementPage({super.key, this.enforce = false});

  @override
  State<UserAgreementPage> createState() => _UserAgreementPageState();
}

class _UserAgreementPageState extends State<UserAgreementPage> {
  final _inputController = TextEditingController();
  bool _acknowledged = false;
  bool _confirmed = false;

  static const _requiredText = '已看完守则 保证守规守矩不做任何违法行为';

  @override
  void initState() {
    super.initState();
    _confirmed = StorageService.agreementAcknowledged;
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget page = Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.enforce,
        leading: widget.enforce
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          widget.enforce ? '⚠️ 必须同意才能使用' : '用户守则',
          style: const TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题警告
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _confirmed ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _confirmed ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.2), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(_confirmed ? Icons.verified_user : Icons.warning_amber_rounded, color: _confirmed ? Colors.green : Colors.red, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _confirmed ? '✓ 已确认遵守用户守则，感谢你的配合' : '使用前请务必仔细阅读以下全部内容',
                            style: TextStyle(color: _confirmed ? Colors.green.shade700 : Colors.red.shade700, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 1. 软件性质
                  _section('一、软件性质', [
                    '1. 冷亭雨是一款仅为娱乐测试用途的即时通讯软件，暂未进行 ICP 备案。',
                    '2. 本软件未向任何公开社交平台发布，仅用于好友之间的内部测试与交流。',
                    '3. 软件为免费使用，无任何盈利行为，开发者不从中获取任何经济利益。',
                    '4. 软件开发者不对本软件的稳定性、安全性做任何承诺。',
                  ]),

                  // 2. 用户责任
                  _section('二、用户行为规范', [
                    '1. 用户在使用本软件过程中，必须严格遵守中华人民共和国相关法律法规。',
                    '2. 严禁利用本软件从事任何违法违规活动，包括但不限于：',
                    '   · 传播淫秽色情、暴力恐怖、赌博诈骗等违法内容',
                    '   · 发布危害国家安全、破坏社会稳定的言论',
                    '   · 侵犯他人隐私、名誉权、知识产权等合法权益',
                    '   · 其他任何违反法律法规的行为',
                  ]),

                  // 3. 违规后果
                  _section('三、违规处理', [
                    '1. 服务器管理员有权随时封禁涉嫌违规的账号，无需提前通知。',
                    '2. 一旦发现违法行为，服务器将被立即停止运行，所有数据将被永久删除。',
                    '3. 开发者将积极配合有关部门的调查取证工作。',
                    '4. 用户需对自己在本软件中的一切行为承担全部法律责任。',
                  ]),

                  // 4. 免责声明
                  _section('四、免责声明', [
                    '1. 本软件仅供娱乐测试使用，使用者需自行承担使用本软件产生的一切后果。',
                    '2. 软件中所传播的内容不代表开发者立场，由内容发布者本人负责。',
                    '3. 开发者不对因使用本软件而产生的任何直接或间接损失承担责任。',
                  ]),

                  // 5. 传播限制与数据留存
                  _section('五、传播限制与数据留存', [
                    '1. 本软件仅做极小范围测试，不欢迎外部网友扩散。',
                    '2. 安装包仅由开发者直接发放，任何使用者不得进行第三方传播、分享或公开分发。',
                    '3. 本项目留存全部聊天日志记录，包括但不限于消息内容、发送时间、发送方与接收方信息。',
                    '4. 如有任何违法行为情形，开发者有权直接关停全部服务器，并配合国家有关机关进行调查取证。',
                  ]),

                  const SizedBox(height: 16),

                  // 提示
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚠️ 本页为软件内置提醒，不构成任何形式的功能限制。用户自觉遵守即可。',
                      style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 打字验证
                  const Text('打字确认', style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text(
                    '请完整输入以下文字以确认你已阅读并理解以上守则：',
                    style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 10),

                  // 显示要输入的文字（灰色提示）
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _requiredText,
                      style: TextStyle(
                        color: Colors.black38,
                        fontSize: 13,
                        height: 1.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _inputController,
                    onChanged: (v) {
                      setState(() {
                        _acknowledged = v.trim() == _requiredText;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: '在此输入...',
                      hintStyle: const TextStyle(color: Colors.black26),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _acknowledged ? Colors.green : const Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _acknowledged ? Colors.green : const Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _acknowledged ? Colors.green : Colors.black87),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: _acknowledged
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _acknowledged ? '✓ 内容匹配，点击下方按钮确认提交' : '软件仅做提醒，不强制要求',
                    style: TextStyle(color: _acknowledged ? Colors.green : Colors.black38, fontSize: 11),
                  ),
                  const SizedBox(height: 14),

                  // 确认提交按钮
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: (_acknowledged && !_confirmed)
                          ? () async {
                              setState(() => _confirmed = true);
                              await StorageService.saveAgreementAcknowledged(true);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已确认遵守用户守则'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                              );
                              // 强制模式：跳回主页面；普通模式：正常 pop
                              if (widget.enforce) {
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  if (mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (_) => const MainPage()),
                                      (route) => false,
                                    );
                                  }
                                });
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _confirmed ? Colors.green : Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        _confirmed ? '✓ 已确认提交' : '确认提交',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.enforce) {
      return PopScope(
        canPop: false,
        child: page,
      );
    }
    return page;
  }

  Widget _section(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...items.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(text, style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.7)),
            ),
          ),
        ],
      ),
    );
  }
}
