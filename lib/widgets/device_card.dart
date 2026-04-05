import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/platform_bridge.dart';
import '../theme/muphone_theme.dart';
import 'nav_bar.dart';

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

  // Map widget coordinate to device physical coordinate
  int _toDevX(double wx, double widgetW) {
    final phys = widget.device.physicalWidth > 0 ? widget.device.physicalWidth : 1080;
    return (wx / widgetW * phys).round().clamp(0, phys);
  }

  int _toDevY(double wy, double widgetH) {
    final phys = widget.device.physicalHeight > 0 ? widget.device.physicalHeight : 2400;
    return (wy / widgetH * phys).round().clamp(0, phys);
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
              Expanded(child: _buildVideoSurface()),
              NavBar(deviceId: widget.device.deviceId, serial: widget.device.serial),
            ],
          ),
          if (widget.device.isDetached)
            Positioned.fill(child: _buildDetachedOverlay()),
          if (widget.device.isQualitySwitching)
            Positioned.fill(child: _buildSwitchingOverlay()),
        ],
      ),
    );
  }

  Widget _buildVideoSurface() {
    if (widget.device.textureId != null && widget.device.textureId! >= 0) {
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
                    if (dy.abs() > 1) {
                      PlatformBridge.instance.sendScroll(widget.device.deviceId, cx, cy, dy);
                    }
                  }
                },
                onPointerDown: (e) {
                  debugPrint('[DeviceCard] onPointerDown buttons=${e.buttons} dev=${widget.device.deviceId}');
                  context.read<AppState>().setActiveSerial(widget.device.serial);
                  if (e.buttons == kSecondaryMouseButton) {
                    PlatformBridge.instance.sendKey(widget.device.deviceId, 4);
                  } else if (e.buttons == kMiddleMouseButton) {
                    _sendTap(e.localPosition.dx, e.localPosition.dy, ww, wh);
                    Future.delayed(const Duration(milliseconds: 80), () {
                      _sendTap(e.localPosition.dx, e.localPosition.dy, ww, wh);
                    });
                  } else if (e.buttons == kPrimaryMouseButton) {
                    _dragStart = e.localPosition;
                    _dragCurrent = e.localPosition;
                    _isDragging = false;
                    // Send touch down immediately
                    final x = _toDevX(e.localPosition.dx, ww).toDouble();
                    final y = _toDevY(e.localPosition.dy, wh).toDouble();
                    PlatformBridge.instance.sendTouchDown(widget.device.deviceId, x, y);
                  }
                },
                onPointerMove: (e) {
                  if (_dragStart != null && e.buttons == kPrimaryMouseButton) {
                    _dragCurrent = e.localPosition;
                    _isDragging = true;
                    final x = _toDevX(e.localPosition.dx, ww).toDouble();
                    final y = _toDevY(e.localPosition.dy, wh).toDouble();
                    PlatformBridge.instance.sendTouchMove(widget.device.deviceId, x, y);
                  }
                },
                onPointerUp: (e) {
                  if (_dragStart != null) {
                    final pos = _dragCurrent ?? _dragStart!;
                    final x = _toDevX(pos.dx, ww).toDouble();
                    final y = _toDevY(pos.dy, wh).toDouble();
                    PlatformBridge.instance.sendTouchUp(widget.device.deviceId, x, y);
                    _dragStart = null; _dragCurrent = null; _isDragging = false;
                  }
                },
                child: Texture(textureId: widget.device.textureId!),
              ),
              // Device name overlay
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: Colors.black54,
                  child: Text(widget.device.displayName,
                    style: const TextStyle(fontSize: 9, color: MUPhoneColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          );
        },
      );
    }

    final isOnline = widget.device.phase == DevicePhase.online ||
                     widget.device.phase == DevicePhase.locked;
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOnline)
              const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: MUPhoneColors.primary))
            else
              Icon(Icons.phone_android, size: 28,
                color: MUPhoneColors.textDisabled.withValues(alpha: 0.5)),
            const SizedBox(height: 6),
            Text(isOnline ? 'å»ºæ??«é¢ä¸?..' : widget.device.displayName,
              style: const TextStyle(fontSize: 10, color: MUPhoneColors.textSecondary),
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
          Text('?‡æ??«è³ªä¸?..', style: TextStyle(fontSize: 10, color: MUPhoneColors.textSecondary)),
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
          Text('å·²å???, style: TextStyle(fontSize: 11, color: MUPhoneColors.textDisabled)),
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
