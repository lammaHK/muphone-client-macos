import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/platform_bridge.dart';
import '../services/wheel_gesture_mapper.dart';
import '../theme/muphone_theme.dart';
import 'nav_bar.dart';
import 'shortcut_bar.dart';

class DeviceCard extends StatefulWidget {
  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.onDoubleTap,
  });

  final DeviceState device;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _isDragging = false;
  late WheelGestureMapper _wheelMapper;

  @override
  void initState() {
    super.initState();
    _wheelMapper = WheelGestureMapper(widget.device.deviceId);
  }

  @override
  void didUpdateWidget(covariant DeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.deviceId != widget.device.deviceId) {
      _wheelMapper.dispose(physicalHeight: oldWidget.device.physicalHeight);
      _wheelMapper = WheelGestureMapper(widget.device.deviceId);
    }
  }

  // Map widget coordinate to device physical coordinate
  int _toDevX(double wx, double widgetW) {
    final phys = widget.device.physicalWidth > 0 ? widget.device.physicalWidth : 1080;
    return (wx / widgetW * phys).round().clamp(0, phys);
  }

  int _toDevY(double wy, double widgetH) {
    final phys = widget.device.physicalHeight > 0 ? widget.device.physicalHeight : 2400;
    return (wy / widgetH * phys).round().clamp(0, phys);
  }

  @override
  void dispose() {
    _wheelMapper.dispose(physicalHeight: widget.device.physicalHeight);
    super.dispose();
  }

  void _handleScroll(double cx, double cy, double dy) {
    final handled = _executeTriggerActions(
      'mouse_wheel',
      cx,
      cy,
      scrollDelta: dy,
    );
    if (!handled) {
      _wheelMapper.handle(
        x: cx,
        y: cy,
        deltaY: dy,
        physicalHeight: widget.device.physicalHeight,
      );
    }
  }

  void _finishDrag(double ww, double wh) {
    if (_dragStart == null) return;
    final pos = _dragCurrent ?? _dragStart!;
    final x = _toDevX(pos.dx, ww).toDouble();
    final y = _toDevY(pos.dy, wh).toDouble();
    PlatformBridge.instance.sendTouchUp(widget.device.deviceId, x, y);
    _dragStart = null;
    _dragCurrent = null;
    _isDragging = false;
  }

  void _sendTap(double wx, double wy, double widgetW, double widgetH) {
    final x = _toDevX(wx, widgetW).toDouble();
    final y = _toDevY(wy, widgetH).toDouble();
    PlatformBridge.instance.sendTap(widget.device.deviceId, x, y);
  }

  void _sendSwipe(Offset from, Offset to, double widgetW, double widgetH, int durationMs) {
    PlatformBridge.instance.sendSwipe(
      widget.device.deviceId,
      _toDevX(from.dx, widgetW).toDouble(),
      _toDevY(from.dy, widgetH).toDouble(),
      _toDevX(to.dx, widgetW).toDouble(),
      _toDevY(to.dy, widgetH).toDouble(),
      durationMs,
    );
  }

  bool _executeTriggerActions(
    String trigger,
    double x,
    double y, {
    double? scrollDelta,
  }) {
    final actions = context
        .read<AppState>()
        .resolveControlActionsByTrigger(trigger);
    if (actions.isEmpty) return false;
    for (final action in actions) {
      final cmd = action.command.trim();
      if (cmd == CustomControlAction.cmdTouchDrag) continue;
      _executeControlCommand(
        cmd,
        x: x,
        y: y,
        scrollDelta: scrollDelta,
      );
    }
    return true;
  }

  bool _hasTouchDragBinding() {
    final actions = context
        .read<AppState>()
        .resolveControlActionsByTrigger('mouse_left');
    if (actions.isEmpty) return true;
    return actions.any(
      (action) => action.command.trim() == CustomControlAction.cmdTouchDrag,
    );
  }

  void _executeControlCommand(
    String command, {
    required double x,
    required double y,
    double? scrollDelta,
  }) {
    final cmd = command.trim();
    final lower = cmd.toLowerCase();
    if (lower == CustomControlAction.cmdTapHere) {
      PlatformBridge.instance.sendTap(widget.device.deviceId, x, y);
      return;
    }
    if (lower == CustomControlAction.cmdDoubleTapHere) {
      PlatformBridge.instance.sendTap(widget.device.deviceId, x, y);
      Future.delayed(const Duration(milliseconds: 80), () {
        PlatformBridge.instance.sendTap(widget.device.deviceId, x, y);
      });
      return;
    }
    if (lower == CustomControlAction.cmdScrollNative) {
      final delta = scrollDelta ?? 0;
      if (delta.abs() > 0.1) {
        PlatformBridge.instance.sendScroll(widget.device.deviceId, x, y, delta);
      }
      return;
    }
    if (lower.startsWith('key:')) {
      final keyCode = int.tryParse(lower.substring(4));
      if (keyCode != null && keyCode > 0) {
        PlatformBridge.instance.sendKey(widget.device.deviceId, keyCode);
      }
      return;
    }
    if (lower.startsWith('adb:')) {
      final adbCommand = cmd.substring(4).trim();
      if (adbCommand.isEmpty) return;
      PlatformBridge.instance.sendInput({
        'type': 'run_action',
        'device_id': widget.device.deviceId,
        'action_type': ShortcutAction.adbCommand,
        'command': adbCommand,
      });
      return;
    }
    PlatformBridge.instance.sendInput({
      'type': 'run_action',
      'device_id': widget.device.deviceId,
      'action_type': ShortcutAction.adbCommand,
      'command': cmd,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MUPhoneColors.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _borderColor, width: _borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            children: [
              ShortcutBar(deviceId: widget.device.deviceId, device: widget.device),
              Expanded(child: _buildVideoSurface()),
              NavBar(deviceId: widget.device.deviceId, serial: widget.device.serial),
            ],
          ),
          if (widget.device.phase == DevicePhase.starting && !widget.device.hasFrames)
            Positioned.fill(child: _buildRestartingOverlay()),
          if (widget.device.isDetached)
            Positioned.fill(child: _buildDetachedOverlay()),
          if (widget.device.isQualitySwitching)
            Positioned.fill(child: _buildSwitchingOverlay()),
        ],
      ),
    );
  }

  Widget _buildVideoSurface() {
    final tid = widget.device.textureId;
    if (tid != null && tid >= 0) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final ww = constraints.maxWidth;
          final wh = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              // ALL input via Listener (bypasses GestureDetector arena issues)
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    final cx = _toDevX(event.localPosition.dx, ww).toDouble();
                    final cy = _toDevY(event.localPosition.dy, wh).toDouble();
                    final dy = event.scrollDelta.dy;
                    if (dy.abs() > 0.5) {
                      _handleScroll(cx, cy, dy);
                    }
                  }
                },
                onPointerDown: (e) {
                  debugPrint('[DeviceCard] onPointerDown buttons=${e.buttons} dev=${widget.device.deviceId}');
                  context.read<AppState>().setActiveSerial(widget.device.serial);
                  final x = _toDevX(e.localPosition.dx, ww).toDouble();
                  final y = _toDevY(e.localPosition.dy, wh).toDouble();
                  if (e.buttons == kSecondaryMouseButton) {
                    if (_executeTriggerActions('mouse_right', x, y)) return;
                    PlatformBridge.instance.sendKey(widget.device.deviceId, 4);
                  } else if (e.buttons == kMiddleMouseButton) {
                    if (_executeTriggerActions('mouse_middle', x, y)) return;
                    PlatformBridge.instance.sendTap(widget.device.deviceId, x, y);
                    Future.delayed(const Duration(milliseconds: 80), () {
                      PlatformBridge.instance.sendTap(widget.device.deviceId, x, y);
                    });
                  } else if ((e.buttons & kPrimaryMouseButton) != 0) {
                    _executeTriggerActions('mouse_left', x, y);
                    if (!_hasTouchDragBinding()) return;
                    _wheelMapper.release(physicalHeight: widget.device.physicalHeight);
                    _dragStart = e.localPosition;
                    _dragCurrent = e.localPosition;
                    _isDragging = false;
                    // Send touch down immediately
                    PlatformBridge.instance.sendTouchDown(widget.device.deviceId, x, y);
                  }
                },
                onPointerMove: (e) {
                  if (_dragStart != null && (e.buttons & kPrimaryMouseButton) != 0) {
                    _dragCurrent = e.localPosition;
                    _isDragging = true;
                    final x = _toDevX(e.localPosition.dx, ww).toDouble();
                    final y = _toDevY(e.localPosition.dy, wh).toDouble();
                    PlatformBridge.instance.sendTouchMove(widget.device.deviceId, x, y);
                  }
                },
                onPointerUp: (_) => _finishDrag(ww, wh),
                onPointerCancel: (_) => _finishDrag(ww, wh),
                child: Texture(textureId: widget.device.textureId!),
              ),
              if (!widget.device.hasFrames)
                Positioned.fill(
                  child: Container(
                    color: MUPhoneColors.card,
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 22, height: 22, child: Stack(alignment: Alignment.center, children: [
                          const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: MUPhoneColors.primary)),
                          Icon(Icons.videocam_outlined, size: 10, color: MUPhoneColors.primary.withValues(alpha: 0.6)),
                        ])),
                        const SizedBox(height: 6),
                        const Text('建構畫面中...', style: TextStyle(fontSize: 10, color: MUPhoneColors.textSecondary)),
                      ]),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    final phase = widget.device.phase;
    final (icon, text, color, animate) = switch (phase) {
      DevicePhase.starting => (Icons.phone_android, '啟動中...', MUPhoneColors.statusLockedOther, true),
      DevicePhase.online || DevicePhase.locked => (Icons.sync, '連接中...', MUPhoneColors.primary, true),
      DevicePhase.failed => (Icons.error_outline, '連接失敗', MUPhoneColors.statusFailed, false),
      DevicePhase.offline => (Icons.phone_android, widget.device.displayName, MUPhoneColors.textDisabled, false),
    };
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (animate)
              SizedBox(width: 24, height: 24, child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 1.5, color: color.withValues(alpha: 0.4))),
                Icon(icon, size: 14, color: color),
              ]))
            else
              Icon(icon, size: 26, color: color.withValues(alpha: 0.5)),
            const SizedBox(height: 6),
            Text(text, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
              overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        color: _statusColor, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: _statusColor.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1)],
      ),
    );
  }

  Widget _buildSwitchingOverlay() {
    return Container(
      color: MUPhoneColors.background.withValues(alpha: 0.75),
      child: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
            strokeWidth: 2, color: MUPhoneColors.primary)),
          SizedBox(height: 8),
          Text('切換畫質中...', style: TextStyle(fontSize: 10, color: MUPhoneColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildRestartingOverlay() {
    return Container(
      color: MUPhoneColors.background.withValues(alpha: 0.85),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 22, height: 22, child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
              strokeWidth: 1.5, color: MUPhoneColors.statusLockedOther.withValues(alpha: 0.6))),
            Icon(Icons.restart_alt, size: 12, color: MUPhoneColors.statusLockedOther),
          ])),
          const SizedBox(height: 6),
          const Text('裝置啟動中...', style: TextStyle(fontSize: 10, color: MUPhoneColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildDetachedOverlay() {
    return Container(
      color: MUPhoneColors.background.withValues(alpha: 0.7),
      child: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.open_in_new, size: 24, color: MUPhoneColors.textDisabled),
          SizedBox(height: 6),
          Text('已分離', style: TextStyle(fontSize: 11, color: MUPhoneColors.textDisabled)),
        ]),
      ),
    );
  }

  Color get _borderColor => switch (widget.device.phase) {
    DevicePhase.online => MUPhoneColors.border,
    DevicePhase.locked => widget.device.isLockedByMe
        ? MUPhoneColors.statusLockedMine
        : MUPhoneColors.statusLockedOther,
    DevicePhase.failed => MUPhoneColors.statusFailed,
    _ => MUPhoneColors.statusOffline,
  };

  double get _borderWidth => widget.device.phase == DevicePhase.locked ? 2 : 1;

  Color get _statusColor => switch (widget.device.phase) {
    DevicePhase.online => MUPhoneColors.statusOnline,
    DevicePhase.locked => widget.device.isLockedByMe
        ? MUPhoneColors.statusLockedMine
        : MUPhoneColors.statusLockedOther,
    DevicePhase.failed => MUPhoneColors.statusFailed,
    _ => MUPhoneColors.statusOffline,
  };
}
