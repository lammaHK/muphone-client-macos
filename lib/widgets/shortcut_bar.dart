import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/platform_bridge.dart';
import '../theme/muphone_theme.dart';

class ShortcutBar extends StatelessWidget {
  const ShortcutBar({
    super.key,
    required this.deviceId,
    required this.device,
  });

  final int deviceId;
  final DeviceState device;

  void _executeShortcut(ShortcutAction action) {
    PlatformBridge.instance.sendInput({
      'type': 'run_shortcut',
      'device_id': deviceId,
      'shortcut_type': action.type,
      'command': action.command,
    });
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = context.watch<AppState>().shortcuts;

    return Container(
      height: 22,
      decoration: const BoxDecoration(
        color: MUPhoneColors.card,
        border: Border(bottom: BorderSide(color: MUPhoneColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          ...shortcuts.map((s) => _ShortcutBtn(
            icon: ShortcutAction.iconData(s.icon),
            label: s.label,
            onPressed: () => _executeShortcut(s),
          )),
          const Spacer(),
          _InfoBtn(device: device),
        ],
      ),
    );
  }
}

class _ShortcutBtn extends StatelessWidget {
  const _ShortcutBtn({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        hoverColor: MUPhoneColors.hover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(icon, size: 12, color: MUPhoneColors.textSecondary),
        ),
      ),
    );
  }
}

class _InfoBtn extends StatelessWidget {
  const _InfoBtn({required this.device});
  final DeviceState device;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final quality = context.watch<AppState>().getDeviceQuality(d.serial);

    return Tooltip(
      richMessage: _buildRichContent(d, quality),
      preferBelow: true,
      verticalOffset: 14,
      waitDuration: const Duration(milliseconds: 300),
      showDuration: const Duration(seconds: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2630),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MUPhoneColors.border.withValues(alpha: 0.6)),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.info_outline, size: 12, color: MUPhoneColors.textSecondary),
      ),
    );
  }

  TextSpan _buildRichContent(DeviceState d, String quality) {
    final phaseColor = switch (d.phase) {
      DevicePhase.online => MUPhoneColors.statusOnline,
      DevicePhase.locked => MUPhoneColors.statusLockedMine,
      DevicePhase.failed => MUPhoneColors.statusFailed,
      _ => MUPhoneColors.statusOffline,
    };
    final phaseLabel = switch (d.phase) {
      DevicePhase.online => '線上',
      DevicePhase.starting => '啟動中',
      DevicePhase.locked => '已鎖定',
      DevicePhase.failed => '失敗',
      DevicePhase.offline => '離線',
    };

    const lbl = TextStyle(fontSize: 9, color: MUPhoneColors.textDisabled, height: 1.5);
    const val = TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: MUPhoneColors.textPrimary, height: 1.5);

    return TextSpan(children: [
      TextSpan(text: '● ${d.displayName}\n', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: phaseColor, height: 1.6)),
      const TextSpan(text: '─────────────\n', style: TextStyle(fontSize: 7, color: MUPhoneColors.border, height: 1.2)),
      const TextSpan(text: '序號  ', style: lbl), TextSpan(text: '${d.serial}\n', style: val),
      const TextSpan(text: '狀態  ', style: lbl), TextSpan(text: '$phaseLabel\n', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: phaseColor, height: 1.5)),
      const TextSpan(text: '畫質  ', style: lbl), TextSpan(text: '${quality.toUpperCase()}\n', style: val),
      const TextSpan(text: 'FPS   ', style: lbl), TextSpan(text: '${d.fps > 0 ? d.fps : "--"}\n', style: val),
      const TextSpan(text: '串流  ', style: lbl), TextSpan(text: '${d.width}×${d.height}\n', style: val),
      const TextSpan(text: '物理  ', style: lbl), TextSpan(text: '${d.physicalWidth}×${d.physicalHeight}', style: val),
    ]);
  }
}
