import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformBridge {
  PlatformBridge._();
  static final PlatformBridge instance = PlatformBridge._();

  final _methodChannel = const MethodChannel('muphone_native');
  final _eventChannel = const EventChannel('muphone_native/events');
  StreamSubscription<dynamic>? _eventSubscription;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Future<Map<String, dynamic>?> init() async {
    try {
      final result = await _methodChannel.invokeMethod('init');
      _startListening();
      if (result is Map) return Map<String, dynamic>.from(result);
      return null;
    } on MissingPluginException {
      debugPrint('[PlatformBridge] Native plugin not available (stub mode)');
      return null;
    }
  }

  Future<bool> connect(String host, {int videoPort = 28200, int controlPort = 28201}) async {
    try {
      final result = await _methodChannel.invokeMethod('connect', {
        'host': host,
        'video_port': videoPort,
        'control_port': controlPort,
      });
      return result == true;
    } on MissingPluginException {
      debugPrint('[PlatformBridge] Native plugin not available (stub mode)');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _methodChannel.invokeMethod('disconnect');
    } on MissingPluginException {
      debugPrint('[PlatformBridge] Native plugin not available (stub mode)');
    }
  }

  Future<void> setMainWindow() async {
    try { await _methodChannel.invokeMethod('set_main_window'); } catch (_) {}
  }

  Future<void> confirmExit() async {
    try {
      await _methodChannel.invokeMethod('confirm_exit');
    } catch (_) {}
  }

  Future<int?> subscribeDevice(int deviceId, {int width = 1080, int height = 1920}) async {
    try {
      final result = await _methodChannel.invokeMethod('subscribe_device', {
        'device_id': deviceId,
        'width': width,
        'height': height,
      });
      if (result is Map) {
        final m = Map<String, dynamic>.from(result);
        final tid = m['texture_id'];
        if (tid is int && tid >= 0) return tid;
      }
      return null;
    } on MissingPluginException {
      debugPrint('[PlatformBridge] Native plugin not available (stub mode)');
      return null;
    }
  }

  Future<void> unsubscribeDevice(int deviceId) async {
    try {
      await _methodChannel.invokeMethod('unsubscribe_device', {
        'device_id': deviceId,
      });
    } on MissingPluginException {
      debugPrint('[PlatformBridge] Native plugin not available (stub mode)');
    }
  }

  Future<Map<String, dynamic>?> adbCommand(
    String serial,
    String command,
    List<String> args,
  ) async {
    try {
      final result = await _methodChannel.invokeMethod('adb_command', {
        'serial': serial,
        'command': command,
        'args': args,
      });
      if (result is Map) return Map<String, dynamic>.from(result);
      return null;
    } on MissingPluginException {
      debugPrint('[PlatformBridge] Native plugin not available (stub mode)');
      return null;
    }
  }

  Future<void> updateCellRect(int deviceId, double x, double y, double w, double h) async {
    try {
      await _methodChannel.invokeMethod('update_cell_rect', {
        'device_id': deviceId,
        'x': x, 'y': y, 'w': w, 'h': h,
      });
    } on MissingPluginException {
      debugPrint('[PlatformBridge] Native plugin not available (stub mode)');
    }
  }

  Future<bool> detachDevice(int deviceId) async {
    try {
      final result = await _methodChannel.invokeMethod('detach_device', {
        'device_id': deviceId,
      });
      return result == true;
    } on MissingPluginException {
      debugPrint('[PlatformBridge] Native plugin not available (stub mode)');
      return false;
    }
  }

  Future<bool> attachDevice(int deviceId) async {
    try {
      final result = await _methodChannel.invokeMethod('attach_device', {
        'device_id': deviceId,
      });
      return result == true;
    } on MissingPluginException {
      debugPrint('[PlatformBridge] Native plugin not available (stub mode)');
      return false;
    }
  }

  Future<void> setFpsProfile(int deviceId, String profile) async {
    try {
      await _methodChannel.invokeMethod('set_fps_profile', {
        'device_id': deviceId,
        'profile': profile,
      });
    } on MissingPluginException {
      debugPrint('[PlatformBridge] Native plugin not available (stub mode)');
    }
  }

  /// Send input command via server control channel (works for remote clients)
  Future<void> sendInput(Map<String, dynamic> params) async {
    try {
      debugPrint('[PlatformBridge] sendInput: ${params['type']} dev=${params['device_id']}');
      await _methodChannel.invokeMethod('send_input', params);
    } on MissingPluginException {
      debugPrint('[PlatformBridge] send_input NOT AVAILABLE');
    } catch (e) {
      debugPrint('[PlatformBridge] sendInput ERROR: $e');
    }
  }

  /// Convenience: send keyevent to device
  Future<void> sendKey(int deviceId, int keycode) =>
      sendInput({'type': 'key', 'device_id': deviceId, 'keycode': keycode});

  /// Convenience: send tap
  Future<void> sendTap(int deviceId, double x, double y) =>
      sendInput({'type': 'tap', 'device_id': deviceId, 'x': x, 'y': y});

  /// Realtime touch: down/move/up for sync swipe
  Future<void> sendTouchDown(int deviceId, double x, double y) =>
      sendInput({'type': 'touch_down', 'device_id': deviceId, 'x': x, 'y': y});
  Future<void> sendTouchMove(int deviceId, double x, double y) =>
      sendInput({'type': 'touch_move', 'device_id': deviceId, 'x': x, 'y': y});
  Future<void> sendTouchUp(int deviceId, double x, double y) =>
      sendInput({'type': 'touch_up', 'device_id': deviceId, 'x': x, 'y': y});

  /// Convenience: send scroll (via scrcpy INJECT_SCROLL_EVENT)
  Future<void> sendScroll(int deviceId, double x, double y, double delta) =>
      sendInput({'type': 'scroll', 'device_id': deviceId, 'x': x, 'y': y, 'delta': delta});

  /// Convenience: send swipe
  Future<void> sendSwipe(int deviceId, double x1, double y1, double x2, double y2, int durationMs) =>
      sendInput({'type': 'swipe', 'device_id': deviceId,
                 'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'duration_ms': durationMs});

  /// Convenience: send text via ADB keyboard
  Future<void> sendText(int deviceId, String text) =>
      sendInput({'type': 'text', 'device_id': deviceId, 'text': text});

  Future<Map<String, int>?> getWindowRect() async {
    try {
      final r = await _methodChannel.invokeMethod('get_window_rect');
      if (r is Map) return Map<String, int>.from(r.map((k, v) => MapEntry(k.toString(), v as int)));
    } on MissingPluginException { /* stub */ }
    return null;
  }

  Future<void> setWindowRect(int x, int y, int width, int height) async {
    try {
      await _methodChannel.invokeMethod('set_window_rect', {
        'x': x, 'y': y, 'width': width, 'height': height,
      });
    } on MissingPluginException { /* stub */ }
  }

  Future<void> lockAspectRatio(int numerator, int denominator) async {
    try {
      await _methodChannel.invokeMethod('lock_aspect_ratio', {
        'num': numerator, 'den': denominator,
      });
    } on MissingPluginException { /* stub */ }
  }

  Future<void> setWindowSize(int width, int height) async {
    try {
      await _methodChannel.invokeMethod('set_window_size', {
        'width': width, 'height': height,
      });
    } on MissingPluginException { /* stub */ }
  }

  Future<void> setWindowTitle(String title) async {
    try {
      await _methodChannel.invokeMethod('set_window_title', title);
    } on MissingPluginException {
      // stub mode
    }
  }

  Future<Map<String, dynamic>?> getFrameStats() async {
    try {
      final result = await _methodChannel.invokeMethod('get_frame_stats');
      if (result is Map) return Map<String, dynamic>.from(result);
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  void _startListening() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _eventController.add(Map<String, dynamic>.from(event));
        }
      },
      onError: (error) {
        debugPrint('[PlatformBridge] Event channel error: $error');
      },
    );
  }

  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _eventController.close();
  }
}
