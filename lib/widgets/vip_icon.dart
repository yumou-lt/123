import 'package:flutter/material.dart';

/// 会员图标组件
/// [size] 默认 16，聊天气泡里用 12
/// [badge] 自定义徽章 ID，如果传了就是装备的徽章
/// [isVip] 是否是会员（用于名字旁显示）
class VipIcon extends StatelessWidget {
  final double size;
  final String? badge;
  final bool isVip;

  const VipIcon({super.key, this.size = 16, this.badge, this.isVip = false});

  @override
  Widget build(BuildContext context) {
    // 只要装备了徽章或者是会员就显示
    final showVip = badge == 'vip' || isVip;
    if (!showVip) return const SizedBox.shrink();

    return Image.asset(
      'assets/icons/vip.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // 加个红色边框突出显示
    );
  }
}
