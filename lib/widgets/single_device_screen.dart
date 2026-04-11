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
  Timer? _windowRectSaveTimer;
  Map<String, int>? _lastSavedRect;

  @override
  void initState() {
    super.initState();
    _wheelMapper = WheelGestureMapper(widget.deviceId);
    _init();
  }

  @override
  void dispose() {
    _windowRectSaveTimer?.cancel();
    _wheelMapper.dispose(physicalHeight: _physH);
    if (_rememberDetachedWindowPlacement) {
      if (_lastSavedRect != null) {
        _saveWindowPreferencesSync(
          rectForCurrentDevice: Map<String, int>.from(_lastSavedRect!),
        );
      }
      unawaited(_saveWindowRect());
    } else {
      _saveWindowPreferencesSync(removeCurrentDevice: true);
      unawaited(_saveWindowPreferences(removeCurrentDevice: true));
    }
    _eventSub?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  String get _legacyDeviceKey => widget.deviceId.toString();
  String get _deviceKey => _serial.isNotEmpty ? _serial : _legacyDeviceKey;

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

  Map<String, Map<String, int>> _parseDetachedRects(dynamic rawRects) {
    final parsed = <String, Map<String, int>>{};
    if (rawRects is! Map) return parsed;
    for (final entry in rawRects.entries) {
      final rect = entry.value;
      if (rect is! Map) continue;
      parsed[entry.key.toString()] = {
        'x': (rect['x'] as num?)?.toInt() ?? 0,
        'y': (rect['y'] as num?)?.toInt() ?? 0,
        'width': (rect['width'] as num?)?.toInt() ?? 0,
        'height': (rect['height'] as num?)?.toInt() ?? 0,
      };
    }
    return parsed;
  }

  bool _sameRect(Map<String, int>? a, Map<String, int>? b) {
    if (a == null || b == null) return a == b;
    return a['x'] == b['x'] &&
        a['y'] == b['y'] &&
        a['width'] == b['width'] &&
        a['height'] == b['height'];
  }

  Future<bool> _restoreWindowRect() async {
    if (!_rememberDetachedWindowPlacement) return false;
    final rect = _detachedWindowRects[_deviceKey] ??
        (_serial.isEmpty ? _detachedWindowRects[_legacyDeviceKey] : null);
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
    try {
      final rect = await PlatformBridge.instance.getWindowRect();
      if (rect == null) return;
      final bounds = await PlatformBridge.instance.getDisplayBounds();
      final normalized = _normalizeWindowRect(rect, bounds);
      if (normalized == null) return;
      if (_sameRect(_lastSavedRect, normalized)) return;
      await _saveWindowPreferences(rectForCurrentDevice: normalized);
      _lastSavedRect = Map<String, int>.from(normalized);
    } catch (_) {}
  }

  Future<void> _saveWindowPreferences({
    Map<String, int>? rectForCurrentDevice,
    bool removeCurrentDevice = false,
  }) async {
    final data = await Persistence.instance.load();
    final remember =
        data['rememberDetachedWindowPlacement'] as bool? ?? _rememberDetachedWindowPlacement;
    final mergedRects = _parseDetachedRects(data['detachedWindowRects']);

    if (!remember || removeCurrentDevice) {
      mergedRects.remove(_legacyDeviceKey);
      if (_serial.isNotEmpty) {
        mergedRects.remove(_serial);
      }
    } else if (rectForCurrentDevice != null) {
      mergedRects[_deviceKey] = Map<String, int>.from(rectForCurrentDevice);
      if (_serial.isNotEmpty) {
        mergedRects.remove(_legacyDeviceKey);
      }
    }

    data['rememberDetachedWindowPlacement'] = remember;
    data['detachedWindowRects'] = mergedRects;
    await Persistence.instance.save(data);
    _rememberDetachedWindowPlacement = remember;
    _detachedWindowRects = mergedRects;
  }

  void _saveWindowPreferencesSync({
    Map<String, int>? rectForCurrentDevice,
    bool removeCurrentDevice = false,
  }) {
    final data = Persistence.instance.loadSync();
    final remember =
        data['rememberDetachedWindowPlacement'] as bool? ?? _rememberDetachedWindowPlacement;
    final mergedRects = _parseDetachedRects(data['detachedWindowRects']);

    if (!remember || removeCurrentDevice) {
      mergedRects.remove(_legacyDeviceKey);
      if (_serial.isNotEmpty) {
        mergedRects.remove(_serial);
      }
    } else if (rectForCurrentDevice != null) {
      mergedRects[_deviceKey] = Map<String, int>.from(rectForCurrentDevice);
      if (_serial.isNotEmpty) {
        mergedRects.remove(_legacyDeviceKey);
      }
    }

    data['rememberDetachedWindowPlacement'] = remember;
    data['detachedWindowRects'] = mergedRects;
    Persistence.instance.saveSync(data);
    _rememberDetachedWindowPlacement = remember;
    _detachedWindowRects = mergedRects;
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
    if (data.containsKey('customControlActions')) {
      final raw = data['customControlActions'] as List<dynamic>? ?? [];
      context.read<AppState>().setCustomControlActions(
        raw
            .map((e) => CustomControlAction.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
      );
    } else if (data.containsKey('customControls')) {
      final raw = data['customControls'] as Map<String, dynamic>? ?? {};
      context.read<AppState>().setCustomControls(raw.map((k, v) => MapEntry(k, v.toString())));
    }
    _rememberDetachedWindowPlacement =
        data['rememberDetachedWindowPlacement'] as bool? ?? true;
    _detachedWindowRects = _parseDetachedRects(data['detachedWindowRects']);

    setState(() => _status = '初始化 D3D11...');
    await bridge.init();

    _eventSub = bridge.events.listen(_onEvent);

    setState(() => _status = '連接 ${widget.host}...');
    await bridge.connect(widget.host);
    HardwareKeyboard.instance.addHandler(_onKey);

    _startWindowRectAutosave();
    _updateTitle();
  }

  void _startWindowRectAutosave() {
    unawaited(_saveWindowRect());
    _windowRectSaveTimer ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      unawaited(_saveWindowRect());
    });
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
      if (_serial.isNotEmpty) {
        final legacyRect = _detachedWindowRects[_legacyDeviceKey];
        if (legacyRect != null && !_detachedWindowRects.containsKey(_serial)) {
          _detachedWindowRects[_serial] = Map<String, int>.from(legacyRect);
          unawaited(
            _saveWindowPreferences(
              rectForCurrentDevice: Map<String, int>.from(legacyRect),
            ),
          );
        }
      }
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
    final handled = _executeTriggerActions(
      'mouse_wheel',
      cx,
      cy,
      scrollDelta: dy,
    );
    if (!handled) {
      _wheelMapper.handle(x: cx, y: cy, deltaY: dy, physicalHeight: _physH);
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final key = event.logicalKey;
    final hw = HardwareKeyboard.instance;

    if ((key == LogicalKeyboardKey.keyV) && (hw.isControlPressed || hw.isMetaPressed)) {
      if (_executeTriggerActions('shortcut:paste', 0, 0)) return true;
      _paste(); return true;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      if (_executeTriggerActions('key:enter', 0, 0) && key != LogicalKeyboardKey.space) {
        return true;
      }
      if (key == LogicalKeyboardKey.space &&
          _executeTriggerActions('key:space', 0, 0)) {
        return true;
      }
      PlatformBridge.instance.sendKey(
        widget.deviceId,
        key == LogicalKeyboardKey.space ? 62 : 66,
      );
      return true;
    }
    if (key == LogicalKeyboardKey.backspace) {
      if (_executeTriggerActions('key:backspace', 0, 0)) return true;
      PlatformBridge.instance.sendKey(widget.deviceId, 67); return true;
    }
    final customTrigger = _keyTrigger(key);
    if (customTrigger != null &&
        _executeTriggerActions(customTrigger, 0, 0)) {
      return true;
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
    _startWindowRectAutosave();
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

  String? _keyTrigger(LogicalKeyboardKey key) {
    final label = key.keyLabel.trim().toLowerCase();
    if (label.isEmpty) return null;
    return 'key:$label';
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
      PlatformBridge.instance.sendTap(widget.deviceId, x, y);
      return;
    }
    if (lower == CustomControlAction.cmdDoubleTapHere) {
      PlatformBridge.instance.sendTap(widget.deviceId, x, y);
      Future.delayed(const Duration(milliseconds: 80), () {
        PlatformBridge.instance.sendTap(widget.deviceId, x, y);
      });
      return;
    }
    if (lower == CustomControlAction.cmdScrollNative) {
      final delta = scrollDelta ?? 0;
      if (delta.abs() > 0.1) {
        PlatformBridge.instance.sendScroll(widget.deviceId, x, y, delta);
      }
      return;
    }
    if (lower == CustomControlAction.cmdPasteText) {
      _paste();
      return;
    }
    if (lower.startsWith('key:')) {
      final keyCode = int.tryParse(lower.substring(4));
      if (keyCode != null && keyCode > 0) {
        PlatformBridge.instance.sendKey(widget.deviceId, keyCode);
      }
      return;
    }
    if (lower.startsWith('adb:')) {
      final adbCommand = cmd.substring(4).trim();
      if (adbCommand.isEmpty) return;
      PlatformBridge.instance.sendInput({
        'type': 'run_action',
        'device_id': widget.deviceId,
        'action_type': ShortcutAction.adbCommand,
        'command': adbCommand,
      });
      return;
    }
    PlatformBridge.instance.sendInput({
      'type': 'run_action',
      'device_id': widget.deviceId,
      'action_type': ShortcutAction.adbCommand,
      'command': cmd,
    });
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
        final x = _toX(e.localPosition.dx, ww).toDouble();
        final y = _toY(e.localPosition.dy, wh).toDouble();

        if (e.buttons == kSecondaryMouseButton) {
          if (_executeTriggerActions('mouse_right', x, y)) return;
          PlatformBridge.instance.sendKey(widget.deviceId, 4);
        } else if (e.buttons == kMiddleMouseButton) {
          if (_executeTriggerActions('mouse_middle', x, y)) return;
          PlatformBridge.instance.sendTap(widget.deviceId, x, y);
          Future.delayed(const Duration(milliseconds: 80), () {
            PlatformBridge.instance.sendTap(widget.deviceId, x, y);
          });
        } else if (e.buttons == kPrimaryMouseButton) {
          _executeTriggerActions('mouse_left', x, y);
          if (!_hasTouchDragBinding()) return;
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
