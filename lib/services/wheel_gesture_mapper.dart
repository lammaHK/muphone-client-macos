import 'dart:async';
import 'platform_bridge.dart';

class WheelGestureMapper {
  WheelGestureMapper(this._deviceId);

  final int _deviceId;
  Timer? _releaseTimer;
  bool _active = false;
  double _anchorX = 0;
  double _anchorY = 0;
  double _accumulatedY = 0;
  double _smoothedStep = 0;

  bool get isActive => _active;

  void handle({
    required double x,
    required double y,
    required double deltaY,
    required int physicalHeight,
  }) {
    if (deltaY.abs() < 0.5) return;
    final height = physicalHeight > 0 ? physicalHeight : 2400;
    final direction = deltaY > 0 ? -1.0 : 1.0;
    final magnitude = deltaY.abs().clamp(1.0, 180.0);
    final baseStep = height * 0.028;
    final linearStep = baseStep * (magnitude / 60.0).clamp(0.6, 2.4);
    _smoothedStep = (_smoothedStep * 0.55) + (direction * linearStep * 0.45);

    if (!_active) {
      _anchorX = x;
      _anchorY = y;
      _accumulatedY = 0;
      PlatformBridge.instance.sendTouchDown(_deviceId, _anchorX, _anchorY);
      _active = true;
    }

    _accumulatedY += _smoothedStep;
    final nextY = (_anchorY + _accumulatedY).clamp(0.0, height.toDouble());
    PlatformBridge.instance.sendTouchMove(_deviceId, _anchorX, nextY);
    _armRelease(height);
  }

  void _armRelease(int height) {
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(milliseconds: 90), () {
      release(physicalHeight: height);
    });
  }

  void release({int physicalHeight = 2400}) {
    if (!_active) return;
    final height = physicalHeight > 0 ? physicalHeight : 2400;
    final endY = (_anchorY + _accumulatedY).clamp(0.0, height.toDouble());
    PlatformBridge.instance.sendTouchUp(_deviceId, _anchorX, endY);
    _active = false;
    _accumulatedY = 0;
    _smoothedStep = 0;
  }

  void dispose({int physicalHeight = 2400}) {
    _releaseTimer?.cancel();
    release(physicalHeight: physicalHeight);
  }
}
