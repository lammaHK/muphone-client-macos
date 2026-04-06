import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/persistence.dart';
import '../services/platform_bridge.dart';
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
  Timer? _scrollTimer;
  bool _scrollActive = false;
  double _scrollAccumY = 0;
  double _scrollCx = 0, _scrollCy = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    if (_scrollActive) {
      PlatformBridge.instance.sendTouchUp(widget.deviceId, _scrollCx, _scrollCy);
    }
    _saveWindowRect();
    _eventSub?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  String get _rectFile {
    final dir = File(Platform.resolvedExecutable).parent.path;
    return '$dir${Platform.pathSeparator}window_${widget.deviceId}.json';
  }

  Future<void> _restoreWindowRect() async {
    try {
      final f = File(_rectFile);
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        if (data is Map) {
          await PlatformBridge.instance.setWindowRect(
            data['x'] as int? ?? 100, data['y'] as int? ?? 100,
            data['width'] as int? ?? 360, data['height'] as int? ?? 820);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveWindowRect() async {
    try {
      final rect = await PlatformBridge.instance.getWindowRect();
      if (rect != null) {
        await File(_rectFile).writeAsString(jsonEncode(rect));
      }
    } catch (_) {}
  }

  Future<void> _init() async {
    final bridge = PlatformBridge.instance;

    // Load persisted shortcuts into AppState
    Persistence.instance.initialize();
    final data = await Persistence.instance.load();
    if (data.containsKey('shortcuts') && mounted) {
      final raw = data['shortcuts'] as List<dynamic>? ?? [];
      context.read<AppState>().setShortcuts(
        raw.map((e) => ShortcutAction.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
    }

    setState(() => _status = '初始化 D3D11...');
    await bridge.init();

    _eventSub = bridge.events.listen(_onEvent);

    setState(() => _status = '連接 ${widget.host}...');
    await bridge.connect(widget.host);
    HardwareKeyboard.instance.addHandler(_onKey);

    _updateTitle();
  }

  void _updateTitle() {
    final name = _serial.isNotEmpty ? _serial : '裝置 ${widget.deviceId}';
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
    final step = _physH * 0.04;
    if (!_scrollActive) {
      _scrollCx = cx; _scrollCy = cy; _scrollAccumY = 0;
      PlatformBridge.instance.sendTouchDown(widget.deviceId, cx, cy);
      _scrollActive = true;
    }
    _scrollAccumY += (dy > 0 ? -step : step);
    final newY = (_scrollCy + _scrollAccumY).clamp(0.0, _physH.toDouble());
    PlatformBridge.instance.sendTouchMove(widget.deviceId, _scrollCx, newY);
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 150), () {
      if (_scrollActive) {
        final endY = (_scrollCy + _scrollAccumY).clamp(0.0, _physH.toDouble());
        PlatformBridge.instance.sendTouchUp(widget.deviceId, _scrollCx, endY);
        _scrollActive = false; _scrollAccumY = 0;
      }
    });
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final key = event.logicalKey;
    final hw = HardwareKeyboard.instance;

    if ((key == LogicalKeyboardKey.keyV) && (hw.isControlPressed || hw.isMetaPressed)) {
      _paste(); return true;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      PlatformBridge.instance.sendKey(widget.deviceId, 66); return true;
    }
    if (key == LogicalKeyboardKey.backspace) {
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

    // Restore saved position/size, or set default
    final saved = File(_rectFile);
    if (await saved.exists()) {
      await _restoreWindowRect();
    } else {
      final initW = 360;
      final initH = (initW * den / num).round() + 22;
      PlatformBridge.instance.setWindowSize(initW, initH);
    }
  }

  DeviceState get _deviceState => DeviceState(
    deviceId: widget.deviceId,
    serial: _serial,
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

  Widget _buildGestureLayer(double ww, double wh) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final cx = _toX(event.localPosition.dx, ww).toDouble();
          final cy = _toY(event.localPosition.dy, wh).toDouble();
          final dy = event.scrollDelta.dy;
          if (dy.abs() > 1) {
            _handleScroll(cx, cy, dy);
          }
        }
      },
      onPointerDown: (e) {
        if (e.buttons == kSecondaryMouseButton) {
          PlatformBridge.instance.sendKey(widget.deviceId, 4);
        } else if (e.buttons == kMiddleMouseButton) {
          final x = _toX(e.localPosition.dx, ww).toDouble();
          final y = _toY(e.localPosition.dy, wh).toDouble();
          PlatformBridge.instance.sendTap(widget.deviceId, x, y);
          Future.delayed(const Duration(milliseconds: 80), () {
            PlatformBridge.instance.sendTap(widget.deviceId, x, y);
          });
        } else if (e.buttons == kPrimaryMouseButton) {
          _dragStart = e.localPosition;
          _dragCurrent = e.localPosition;
          PlatformBridge.instance.sendTouchDown(widget.deviceId,
            _toX(e.localPosition.dx, ww).toDouble(), _toY(e.localPosition.dy, wh).toDouble());
        }
      },
      onPointerMove: (e) {
        if (_dragStart != null && e.buttons == kPrimaryMouseButton) {
          _dragCurrent = e.localPosition;
          PlatformBridge.instance.sendTouchMove(widget.deviceId,
            _toX(e.localPosition.dx, ww).toDouble(), _toY(e.localPosition.dy, wh).toDouble());
        }
      },
      onPointerUp: (e) {
        if (_dragStart != null) {
          final pos = _dragCurrent ?? _dragStart!;
          PlatformBridge.instance.sendTouchUp(widget.deviceId,
            _toX(pos.dx, ww).toDouble(), _toY(pos.dy, wh).toDouble());
          _dragStart = null; _dragCurrent = null;
        }
      },
      child: Texture(textureId: _textureId!),
    );
  }
}
