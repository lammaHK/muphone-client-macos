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
    if (action.type == 'app') {
      PlatformBridge.instance.sendInput({
        'type': 'run_shortcut',
        'device_id': deviceId,
        'shortcut_type': 'app',
        'command': action.command,
      });
    } else {
      PlatformBridge.instance.sendInput({
        'type': 'run_shortcut',
        'device_id': deviceId,
        'shortcut_type': 'adb',
        'command': action.command,
      });
    }
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

class _InfoBtn extends StatefulWidget {
  const _InfoBtn({required this.device});
  final DeviceState device;

  @override
  State<_InfoBtn> createState() => _InfoBtnState();
}

class _InfoBtnState extends State<_InfoBtn> {
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();
  bool _hovering = false;

  void _show() {
    if (!_overlayController.isShowing) _overlayController.show();
  }

  void _hide() {
    if (_overlayController.isShowing) _overlayController.hide();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (_) => _buildTooltipOverlay(),
        child: MouseRegion(
          onEnter: (_) { _hovering = true; _show(); },
          onExit: (_) { _hovering = false; Future.delayed(const Duration(milliseconds: 120), () {
            if (!_hovering) _hide();
          }); },
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.info_outline, size: 12, color: MUPhoneColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTooltipOverlay() {
    final d = widget.device;
    final state = context.read<AppState>();
    final quality = state.getDeviceQuality(d.serial);

    final tooltip = MouseRegion(
      onEnter: (_) => _hovering = true,
      onExit: (_) { _hovering = false; Future.delayed(const Duration(milliseconds: 120), () {
        if (!_hovering) _hide();
      }); },
      child: Material(
        elevation: 6,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(6),
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MUPhoneColors.border.withValues(alpha: 0.6)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E2830), Color(0xFF172028)],
            ),
          ),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _phaseColor(d.phase),
                      boxShadow: [BoxShadow(color: _phaseColor(d.phase).withValues(alpha: 0.5), blurRadius: 3)],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(child: Text(
                    d.displayName,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: MUPhoneColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, color: MUPhoneColors.border)),
                _InfoRow(label: '序號', value: d.serial),
                if (d.alias.isNotEmpty)
                  _InfoRow(label: '別名', value: d.alias),
                _InfoRow(label: '狀態', value: _phaseLabel(d.phase), valueColor: _phaseColor(d.phase)),
                _InfoRow(label: '畫質', value: quality.toUpperCase(), valueColor: quality == 'fhd' ? MUPhoneColors.primary : MUPhoneColors.textSecondary),
                _InfoRow(label: 'FPS', value: d.fps > 0 ? '${d.fps}' : '--'),
                _InfoRow(label: '串流', value: '${d.width}×${d.height}'),
                _InfoRow(label: '物理', value: '${d.physicalWidth}×${d.physicalHeight}'),
              ],
            ),
          ),
        ),
      ),
    );

    return CompositedTransformFollower(
      link: _link,
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 4),
      child: tooltip,
    );
  }

  Color _phaseColor(DevicePhase p) => switch (p) {
    DevicePhase.online => MUPhoneColors.statusOnline,
    DevicePhase.locked => MUPhoneColors.statusLockedMine,
    DevicePhase.failed => MUPhoneColors.statusFailed,
    _ => MUPhoneColors.statusOffline,
  };

  String _phaseLabel(DevicePhase p) => switch (p) {
    DevicePhase.online => '線上',
    DevicePhase.starting => '啟動中',
    DevicePhase.locked => '已鎖定',
    DevicePhase.failed => '失敗',
    DevicePhase.offline => '離線',
  };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: Text(label, style: const TextStyle(fontSize: 9, color: MUPhoneColors.textDisabled)),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(value,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: valueColor ?? MUPhoneColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
