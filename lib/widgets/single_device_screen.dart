import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/persistence.dart';
import '../services/platform_bridge.dart';
import '../services/wheel_gesture_mapper.dart';
import '../theme/muphone_theme.dart';
import 'nav_bar.dart';
import 'shortcut_bar.dart';

class SingleDeviceScreen extends StatefulWidget {
  const SingleDeviceScreen({super.key, required this.deviceId, required this.host});
  final int deviceId;
  final String host;

  @override
  State<SingleDeviceScreen> createState() => _SingleDeviceScreenState();
}

class _SingleDeviceScreenState extends State<SingleDeviceScreen> {
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  int? _textureId;
  int _physW = 1080, _physH = 2400;
  int _streamW = 405, _streamH = 720;
  String _serial = '';
  String _status = '初始化...';
  bool _connected = false;
  bool _isQualitySwitching = false;
  bool _hasFrames = false;
  late final WheelGestureMapper _wheelMapper;
  bool _rememberDetachedWindowPlacement = true;
  Map<String, Map<String, int>> _detachedWindowRects = {};

  @override
  void initState() {
    super.initState();
    _wheelMapper = WheelGestureMapper(widget.deviceId);
    _init();
  }

  @override
  void dispose() {
    _wheelMapper.dispose(physicalHeight: _physH);
    if (_rememberDetachedWindowPlacement) {
      _saveWindowRect();
    } else {
      _detachedWindowRects.remove(_deviceKey);
      unawaited(_saveWindowPreferences());
    }
    _eventSub?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  String get _deviceKey => widget.deviceId.toString();

  Map<String, int>? _normalizeWindowRect(
    Map<String, int>? rect,
    Map<String, int>? bounds,
  ) {
    if (rect == null) return null;
    var x = rect['x'] ?? 0;
    var y = rect['y'] ?? 0;
    var width = rect['width'] ?? 0;
    var height = rect['height'] ?? 0;
    if (width <= 0 || height <= 0) return null;

    if (bounds == null) return {'x': x, 'y': y, 'width': width, 'height': height};

    final bx = bounds['x'] ?? 0;
    final by = bounds['y'] ?? 0;
    final bw = bounds['width'] ?? 0;
    final bh = bounds['height'] ?? 0;
    if (bw <= 0 || bh <= 0) return {'x': x, 'y': y, 'width': width, 'height': height};

    const minW = 360;
    const minH = 320;
    width = width.clamp(minW, bw);
    height = height.clamp(minH, bh);
    final maxX = bx + bw - width;
    final maxY = by + bh - height;
    x = maxX >= bx ? x.clamp(bx, maxX) : bx;
    y = maxY >= by ? y.clamp(by, maxY) : by;
    return {'x': x, 'y': y, 'width': width, 'height': height};
  }

  Future<bool> _restoreWindowRect() async {
    if (!_rememberDetachedWindowPlacement) return false;
    final rect = _detachedWindowRects[_deviceKey];
    if (rect == null) return false;
    try {
      final bounds = await PlatformBridge.instance.getDisplayBounds();
      final normalized = _normalizeWindowRect(rect, bounds);
      if (normalized == null) return false;
      await PlatformBridge.instance.setWindowRect(
        normalized['x']!,
        normalized['y']!,
        normalized['width']!,
        normalized['height']!,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveWindowRect() async {
    if (!_rememberDetachedWindowPlacement) return;
    try {
      final rect = await PlatformBridge.instance.getWindowRect();
      if (rect == null) return;
      final bounds = await PlatformBridge.instance.getDisplayBounds();
      final normalized = _normalizeWindowRect(rect, bounds);
      if (normalized == null) return;
      _detachedWindowRects[_deviceKey] = normalized;
      await _saveWindowPreferences();
    } catch (_) {}
  }

  Future<void> _saveWindowPreferences() async {
    final data = await Persistence.instance.load();
    data['rememberDetachedWindowPlacement'] = _rememberDetachedWindowPlacement;
    data['detachedWindowRects'] = _detachedWindowRects;
    await Persistence.instance.save(data);
  }

  Future<void> _init() async {
    final bridge = PlatformBridge.instance;

    Persistence.instance.initialize();
    final data = await Persistence.instance.load();
    if (data.containsKey('shortcuts') && mounted) {
      final raw = data['shortcuts'] as List<dynamic>? ?? [];
      context.read<AppState>().setShortcuts(
        raw.map((e) => ShortcutAction.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
    }
    // Load all aliases into AppState for later matching
    if (data.containsKey('deviceAliases')) {
      final raw = data['deviceAliases'] as Map<String, dynamic>? ?? {};
      context.read<AppState>().setDeviceAliasMap(raw.map((k, v) => MapEntry(k, v.toString())));
    }
    if (data.containsKey('customControls')) {
      final raw = data['customControls'] as Map<String, dynamic>? ?? {};
      context.read<AppState>().setCustomControls(raw.map((k, v) => MapEntry(k, v.toString())));
    }
    _rememberDetachedWindowPlacement =
        data['rememberDetachedWindowPlacement'] as bool? ?? true;
    final rawRects = data['detachedWindowRects'] as Map<String, dynamic>? ?? {};
    _detachedWindowRects = {};
    for (final entry in rawRects.entries) {
      final rect = entry.value;
      if (rect is! Map) continue;
      _detachedWindowRects[entry.key] = {
        'x': (rect['x'] as num?)?.toInt() ?? 0,
        'y': (rect['y'] as num?)?.toInt() ?? 0,
        'width': (rect['width'] as num?)?.toInt() ?? 0,
        'height': (rect['height'] as num?)?.toInt() ?? 0,
      };
    }

    setState(() => _status = '初始化 D3D11...');
    await bridge.init();

    _eventSub = bridge.events.listen(_onEvent);

    setState(() => _status = '連接 ${widget.host}...');
    await bridge.connect(widget.host);
    HardwareKeyboard.instance.addHandler(_onKey);

    _updateTitle();
  }

  String _alias = '';

  void _updateTitle() {
    final name = _alias.isNotEmpty ? _alias : _serial.isNotEmpty ? _serial : '裝置 ${widget.deviceId}';
    PlatformBridge.instance.setWindowTitle(name);
  }

  void _onEvent(Map<String, dynamic> event) {
    final type = event['event'] as String?;
    if (type == 'server_connection_state') {
      final s = event['state'] as String? ?? '';
      setState(() {
        _connected = s == 'connected';
        _status = switch (s) {
          'connected' => '已連接，等待裝置...',
          'connecting' => '連接中...',
          'reconnecting' => '重新連接中...',
          _ => '離線',
        };
      });
    } else if (type == 'device_list') {
      _handleDeviceList(event);
    } else if (type == 'frame_ready') {
      final frid = event['device_id'] as int?;
      if (frid == widget.deviceId && !_hasFrames) {
        setState(() => _hasFrames = true);
      }
    } else if (type == 'fps_update') {
      _handleFpsUpdate(event);
    }
  }

  void _handleFpsUpdate(Map<String, dynamic> event) {
    final id = event['device_id'] as int?;
    final restarting = event['restarting'] as bool? ?? false;
    if (id != widget.deviceId || !restarting) return;

    setState(() => _isQualitySwitching = true);

    // Unsubscribe old stream, wait for new scrcpy, then resubscribe
    PlatformBridge.instance.unsubscribeDevice(widget.deviceId);
    setState(() { _textureId = null; _status = '切換畫質中...'; });

    Future.delayed(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      final tid = await PlatformBridge.instance.subscribeDevice(
          widget.deviceId, width: 0, height: 0);
      if (tid != null && mounted) {
        setState(() {
          _textureId = tid;
          _isQualitySwitching = false;
          _status = '';
        });
      } else if (mounted) {
        setState(() { _isQualitySwitching = false; _status = '重新訂閱失敗'; });
      }
    });
  }

  void _handleDeviceList(Map<String, dynamic> event) async {
    final devices = event['devices'];
    if (devices is! List) return;

    for (final raw in devices) {
      if (raw is! Map) continue;
      final d = Map<String, dynamic>.from(raw);
      final id = d['device_id'] as int? ?? -1;
      if (id != widget.deviceId) continue;

      final phase = (d['phase'] as String? ?? '').toLowerCase();
      _serial = d['serial'] as String? ?? '';
      if (_alias.isEmpty && _serial.isNotEmpty) {
        _alias = context.read<AppState>().getDeviceAlias(_serial);
      }
      _updateTitle();

      if (phase != 'online' && phase != 'locked') {
        setState(() => _status = '$_serial — $phase');
        continue;
      }

      final w = d['width'] as int? ?? 405;
      final h = d['height'] as int? ?? 720;
      _streamW = w;
      _streamH = h;
      _physW = d['physical_width'] as int? ?? (w * 10 ~/ 3);
      _physH = d['physical_height'] as int? ?? (h * 10 ~/ 3);

      if (_textureId == null) {
        setState(() => _status = '$_serial — 訂閱中...');
        debugPrint('[SingleDevice] subscribing dev=$id ${w}x${h}');
        final tid = await PlatformBridge.instance.subscribeDevice(id, width: w, height: h);
        debugPrint('[SingleDevice] subscribe result: textureId=$tid');
        if (tid != null && mounted) {
          setState(() {
            _textureId = tid;
            _status = '';
          });
        } else if (mounted) {
          setState(() => _status = '$_serial — 重試中...');
          // Retry once after delay
          Future.delayed(const Duration(seconds: 2), () async {
            if (!mounted || _textureId != null) return;
            final tid2 = await PlatformBridge.instance.subscribeDevice(id, width: w, height: h);
            if (tid2 != null && mounted) {
              setState(() { _textureId = tid2; _status = ''; });
            }
          });
        }
      }
      break;
    }
  }

  void _handleScroll(double cx, double cy, double dy) {
    final state = context.read<AppState>();
    final cmd = state.customControls['scroll'] ?? 'default';
    if (cmd != 'default') {
      _executeCustomControl('scroll', cx, cy);
      return;
    }
    _wheelMapper.handle(x: cx, y: cy, deltaY: dy, physicalHeight: _physH);
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final key = event.logicalKey;
    final hw = HardwareKeyboard.instance;
    final state = context.read<AppState>();

    if ((key == LogicalKeyboardKey.keyV) && (hw.isControlPressed || hw.isMetaPressed)) {
      final cmd = state.customControls['paste'] ?? 'default';
      if (cmd != 'default') {
        _executeCustomControl('paste', 0, 0);
        return true;
      }
      _paste(); return true;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      final cmd = state.customControls['enter'] ?? 'key:66';
      if (cmd != 'default') {
        _executeCustomControl('enter', 0, 0);
        return true;
      }
      PlatformBridge.instance.sendKey(widget.deviceId, 66); return true;
    }
    if (key == LogicalKeyboardKey.space) {
      final cmd = state.customControls['space'] ?? 'key:66';
      if (cmd != 'default') {
        _executeCustomControl('space', 0, 0);
        return true;
      }
      PlatformBridge.instance.sendKey(widget.deviceId, 66); return true;
    }
    if (key == LogicalKeyboardKey.backspace) {
      final cmd = state.customControls['backspace'] ?? 'key:67';
      if (cmd != 'default') {
        _executeCustomControl('backspace', 0, 0);
        return true;
      }
      PlatformBridge.instance.sendKey(widget.deviceId, 67); return true;
    }
    final ch = event.character;
    if (ch != null && ch.isNotEmpty && !hw.isControlPressed && !hw.isMetaPressed) {
      PlatformBridge.instance.sendText(widget.deviceId, ch); return true;
    }
    return false;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      PlatformBridge.instance.sendText(widget.deviceId, data.text!);
    }
  }

  int _toX(double wx, double ww) => (wx / ww * _physW).round().clamp(0, _physW);
  int _toY(double wy, double wh) => (wy / wh * _physH).round().clamp(0, _physH);

  double get _aspectRatio {
    if (_physW > 0 && _physH > 0) return _physW / _physH;
    return 9.0 / 20.0;
  }

  bool _aspectLocked = false;

  void _lockAspect() async {
    if (_aspectLocked) return;
    _aspectLocked = true;
    final num = _physW > 0 ? _physW : 9;
    final den = _physH > 0 ? _physH : 20;
    PlatformBridge.instance.lockAspectRatio(num, den);

    // Restore saved position/size, or set default.
    final restored = await _restoreWindowRect();
    if (!restored) {
      final initW = 360;
      final initH = (initW * den / num).round() + 22;
      PlatformBridge.instance.setWindowSize(initW, initH);
    }
  }

  DeviceState get _deviceState => DeviceState(
    deviceId: widget.deviceId,
    serial: _serial,
    alias: _alias,
    phase: _connected ? DevicePhase.online : DevicePhase.offline,
    width: _streamW,
    height: _streamH,
    physicalWidth: _physW,
    physicalHeight: _physH,
    hasFrames: _hasFrames,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MUPhoneColors.background,
      body: Column(
        children: [
          ShortcutBar(deviceId: widget.deviceId, device: _deviceState),
          Expanded(
            child: Stack(
              children: [
                if (_textureId != null)
                  Builder(builder: (ctx) {
                    if (!_aspectLocked) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _lockAspect());
                    }
                    return Container(
                      color: Colors.black,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _aspectRatio,
                          child: LayoutBuilder(builder: (ctx2, box) =>
                              _buildGestureLayer(box.maxWidth, box.maxHeight)),
                        ),
                      ),
                    );
                  })
                else
                  Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(strokeWidth: 2),
                      const SizedBox(height: 12),
                      Text(_status, style: const TextStyle(
                        fontSize: 12, color: MUPhoneColors.textDisabled)),
                    ])),
                if (_isQualitySwitching)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.75),
                      child: const Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: MUPhoneColors.primary)),
                          SizedBox(height: 10),
                          Text('切換畫質中...', style: TextStyle(fontSize: 11, color: MUPhoneColors.textSecondary)),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          NavBar(deviceId: widget.deviceId, serial: _serial),
        ],
      ),
    );
  }

  Offset? _dragStart, _dragCurrent;

  void _finishDrag(double ww, double wh) {
    if (_dragStart == null) return;
    final pos = _dragCurrent ?? _dragStart!;
    PlatformBridge.instance.sendTouchUp(
      widget.deviceId,
      _toX(pos.dx, ww).toDouble(),
      _toY(pos.dy, wh).toDouble(),
    );
    _dragStart = null;
    _dragCurrent = null;
  }

  void _executeCustomControl(String controlKey, double x, double y) {
    final state = context.read<AppState>();
    final cmd = state.customControls[controlKey] ?? 'default';
    if (cmd == 'default') return;

    if (cmd.startsWith('key:')) {
      final keycode = int.tryParse(cmd.substring(4)) ?? 0;
      if (keycode > 0) PlatformBridge.instance.sendKey(widget.deviceId, keycode);
    } else if (cmd.startsWith('adb:')) {
      final adbCmd = cmd.substring(4);
      PlatformBridge.instance.sendInput({
        'type': 'run_shortcut',
        'device_id': widget.deviceId,
        'shortcut_type': 'adb',
        'command': adbCmd,
      });
    }
  }

  Widget _buildGestureLayer(double ww, double wh) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final cx = _toX(event.localPosition.dx, ww).toDouble();
          final cy = _toY(event.localPosition.dy, wh).toDouble();
          final dy = event.scrollDelta.dy;
          if (dy.abs() > 0.5) {
            _handleScroll(cx, cy, dy);
          }
        }
      },
      onPointerDown: (e) {
        final state = context.read<AppState>();
        final x = _toX(e.localPosition.dx, ww).toDouble();
        final y = _toY(e.localPosition.dy, wh).toDouble();

        if (e.buttons == kSecondaryMouseButton) {
          final cmd = state.customControls['mouseRight'] ?? 'key:4';
          if (cmd != 'default') {
            _executeCustomControl('mouseRight', x, y);
            return;
          }
          PlatformBridge.instance.sendKey(widget.deviceId, 4);
        } else if (e.buttons == kMiddleMouseButton) {
          final cmd = state.customControls['mouseMiddle'] ?? 'default';
          if (cmd != 'default') {
            _executeCustomControl('mouseMiddle', x, y);
            return;
          }
          PlatformBridge.instance.sendTap(widget.deviceId, x, y);
          Future.delayed(const Duration(milliseconds: 80), () {
            PlatformBridge.instance.sendTap(widget.deviceId, x, y);
          });
        } else if (e.buttons == kPrimaryMouseButton) {
          final cmd = state.customControls['mouseLeft'] ?? 'default';
          if (cmd != 'default') {
            _executeCustomControl('mouseLeft', x, y);
            return;
          }
          _wheelMapper.release(physicalHeight: _physH);
          _dragStart = e.localPosition;
          _dragCurrent = e.localPosition;
          PlatformBridge.instance.sendTouchDown(widget.deviceId, x, y);
        }
      },
      onPointerMove: (e) {
        if (_dragStart != null && (e.buttons & kPrimaryMouseButton) != 0) {
          _dragCurrent = e.localPosition;
          PlatformBridge.instance.sendTouchMove(widget.deviceId,
            _toX(e.localPosition.dx, ww).toDouble(), _toY(e.localPosition.dy, wh).toDouble());
        }
      },
      onPointerUp: (_) => _finishDrag(ww, wh),
      onPointerCancel: (_) => _finishDrag(ww, wh),
      child: Texture(textureId: _textureId!),
    );
  }
}
