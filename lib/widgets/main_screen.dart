import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/adb_command_preset.dart';
import '../services/persistence.dart';
import '../services/platform_bridge.dart';
import '../theme/muphone_theme.dart';
import 'device_grid.dart';
import 'settings_modal.dart';

// Android keyevent codes
const int _kAndroidEnter   = 66;
const int _kAndroidBack    = 4;
const int _kAndroidDel     = 67; // Backspace
const int _kAndroidSpace   = 62;
const int _kAndroidTab     = 61;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  String _lastTitle = '';
  Timer? _saveTimer;
  String _desiredProfile = 'full';
  final Map<int, int> _qualitySwitchGen = {};
  final Set<int> _fhdProfileSent = {};

  final List<_PendingSub> _subQueue = [];
  final Set<int> _subscribingNow = {};
  int _activeSubCount = 0;
  static const int _maxConcurrentSubs = 4;
  final Map<int, int> _streamRetryCount = {};
  int _lastReconnectAtMs = 0;
  int _lastDeviceErrorAtMs = 0;

  Timer? _clipboardTimer;
  String _lastClipboard = '';
  int _lastClipboardSeq = 0;
  int _lastClipboardUpdatedAt = 0;

  @override
  void initState() {
    super.initState();
    _initNativeAndConnect();
    _clipboardTimer = Timer.periodic(const Duration(seconds: 2), (_) => _syncClipboard());
  }

  Future<void> _syncClipboard() async {
    if (!mounted) return;
    final state = context.read<AppState>();
    if (state.connection != ServerConnectionState.connected) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isNotEmpty && text != _lastClipboard) {
        _lastClipboard = text;
        for (final dev in state.devices) {
          if (dev.phase == DevicePhase.online || dev.phase == DevicePhase.locked) {
            PlatformBridge.instance.sendInput({
              'type': 'clipboard_set',
              'device_id': dev.deviceId,
              'text': text,
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    final state = context.read<AppState>();
    unawaited(
      _captureMainWindowPlacement(state, PlatformBridge.instance).then(
        (_) => _saveStateNow(state),
      ),
    );
    _clipboardTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _eventSub?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPersistedState(AppState state) async {
    final data = await Persistence.instance.load();
    if (data.containsKey('gridConfig')) {
      final gc = data['gridConfig'] as Map<String, dynamic>;
      state.setGridConfig(GridConfig(
        columns: gc['columns'] as int? ?? 6,
        rows: gc['rows'] as int? ?? 2,
      ));
    }
    if (data.containsKey('deviceOrder')) {
      final raw = data['deviceOrder'] as Map<String, dynamic>;
      state.setDeviceOrder(raw.map((k, v) => MapEntry(k, v as int)));
    }
    if (data.containsKey('serverHost')) {
      state.setServerHost(data['serverHost'] as String? ?? '127.0.0.1');
    }
    if (data.containsKey('hiddenSerials')) {
      final list = data['hiddenSerials'] as List<dynamic>? ?? [];
      state.setHiddenSerials(list.map((e) => e.toString()).toSet());
    }
    if (data.containsKey('deviceQuality')) {
      final raw = data['deviceQuality'] as Map<String, dynamic>? ?? {};
      state.setDeviceQualityMap(raw.map((k, v) => MapEntry(k, v.toString())));
    }
    if (data.containsKey('deviceAliases')) {
      final raw = data['deviceAliases'] as Map<String, dynamic>? ?? {};
      state.setDeviceAliasMap(raw.map((k, v) => MapEntry(k, v.toString())));
    }
    if (data.containsKey('shortcuts')) {
      final raw = data['shortcuts'] as List<dynamic>? ?? [];
      state.setShortcuts(raw.map((e) => ShortcutAction.fromJson(Map<String, dynamic>.from(e as Map))).toList());
    }
    if (data.containsKey('adbCommandPresets')) {
      final raw = data['adbCommandPresets'] as List<dynamic>? ?? [];
      state.setAdbCommandPresets(
        raw
            .map((e) => AdbCommandPreset.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
      );
    }
    if (data.containsKey('customControlActions')) {
      final raw = data['customControlActions'] as List<dynamic>? ?? [];
      state.setCustomControlActions(
        raw
            .map((e) => CustomControlAction.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
      );
    } else if (data.containsKey('customControls')) {
      final raw = data['customControls'] as Map<String, dynamic>? ?? {};
      state.setCustomControls(raw.map((k, v) => MapEntry(k, v.toString())));
    }
    if (data.containsKey('settingsShortcutKey')) {
      state.setSettingsShortcutKey(data['settingsShortcutKey'] as String? ?? '=');
    }
    if (data.containsKey('rememberMainWindowPlacement')) {
      state.setRememberMainWindowPlacement(
        data['rememberMainWindowPlacement'] as bool? ?? true,
      );
    }
    if (data.containsKey('rememberDetachedWindowPlacement')) {
      state.setRememberDetachedWindowPlacement(
        data['rememberDetachedWindowPlacement'] as bool? ?? true,
      );
    }
    if (data.containsKey('mainWindowRect')) {
      final raw = data['mainWindowRect'] as Map<String, dynamic>?;
      if (raw != null) {
        state.setMainWindowRect({
          'x': (raw['x'] as num?)?.toInt() ?? 0,
          'y': (raw['y'] as num?)?.toInt() ?? 0,
          'width': (raw['width'] as num?)?.toInt() ?? 0,
          'height': (raw['height'] as num?)?.toInt() ?? 0,
        });
      }
    }
    if (data.containsKey('detachedWindowRects')) {
      final raw = data['detachedWindowRects'] as Map<String, dynamic>? ?? {};
      final parsed = <String, Map<String, int>>{};
      for (final entry in raw.entries) {
        final rect = entry.value;
        if (rect is! Map) continue;
        parsed[entry.key] = {
          'x': (rect['x'] as num?)?.toInt() ?? 0,
          'y': (rect['y'] as num?)?.toInt() ?? 0,
          'width': (rect['width'] as num?)?.toInt() ?? 0,
          'height': (rect['height'] as num?)?.toInt() ?? 0,
        };
      }
      state.setDetachedWindowRects(parsed);
    }
  }

  Map<String, dynamic> _buildPersistedState(AppState state) {
    final gc = state.gridConfig;
    return {
      'gridConfig': {'columns': gc.columns, 'rows': gc.rows},
      'deviceOrder': state.deviceOrder,
      'serverHost': state.serverHost,
      'hiddenSerials': state.hiddenSerials.toList(),
      'deviceQuality': state.deviceQuality,
      'deviceAliases': state.deviceAliases,
      'shortcuts': state.shortcuts.map((s) => s.toJson()).toList(),
      'adbCommandPresets':
          state.adbCommandPresets.map((p) => p.toJson()).toList(),
      'customControlActions':
          state.customControlActions.map((item) => item.toJson()).toList(),
      'settingsShortcutKey': state.settingsShortcutKey,
      'rememberMainWindowPlacement': state.rememberMainWindowPlacement,
      'rememberDetachedWindowPlacement': state.rememberDetachedWindowPlacement,
      'mainWindowRect': state.mainWindowRect,
      'detachedWindowRects': state.detachedWindowRects,
      'customControls': state.customControls,
    };
  }

  Map<String, Map<String, int>> _parseDetachedRects(dynamic raw) {
    final parsed = <String, Map<String, int>>{};
    if (raw is! Map) return parsed;
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final rect = entry.value;
      if (rect is! Map) continue;
      parsed[key] = {
        'x': (rect['x'] as num?)?.toInt() ?? 0,
        'y': (rect['y'] as num?)?.toInt() ?? 0,
        'width': (rect['width'] as num?)?.toInt() ?? 0,
        'height': (rect['height'] as num?)?.toInt() ?? 0,
      };
    }
    return parsed;
  }

  Future<void> _saveStateNow(AppState state) async {
    final payload = _buildPersistedState(state);
    if (state.rememberDetachedWindowPlacement) {
      final existing = await Persistence.instance.load();
      final diskRects = _parseDetachedRects(existing['detachedWindowRects']);
      final memoryRects = state.detachedWindowRects;
      final merged = <String, Map<String, int>>{
        ...diskRects.map((k, v) => MapEntry(k, Map<String, int>.from(v))),
      };
      for (final entry in memoryRects.entries) {
        merged.putIfAbsent(entry.key, () => Map<String, int>.from(entry.value));
      }
      payload['detachedWindowRects'] = merged;
      state.setDetachedWindowRects(merged, notify: false);
    } else {
      payload['detachedWindowRects'] = <String, Map<String, int>>{};
      state.setDetachedWindowRects({}, notify: false);
    }
    await Persistence.instance.save(payload);
  }

  void _debouncedSave(AppState state) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_saveStateNow(state));
    });
  }

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
    const minH = 240;
    width = width.clamp(minW, bw);
    height = height.clamp(minH, bh);

    final maxX = bx + bw - width;
    final maxY = by + bh - height;
    x = maxX >= bx ? x.clamp(bx, maxX) : bx;
    y = maxY >= by ? y.clamp(by, maxY) : by;
    return {'x': x, 'y': y, 'width': width, 'height': height};
  }

  Future<void> _restoreMainWindowPlacement(AppState state, PlatformBridge bridge) async {
    final bounds = await bridge.getDisplayBounds();
    if (!state.rememberMainWindowPlacement) {
      final current = await bridge.getWindowRect();
      if (current != null && bounds != null) {
        final width = ((current['width'] ?? 1280).clamp(360, bounds['width'] ?? 1280) as num).toInt();
        final height = ((current['height'] ?? 720).clamp(240, bounds['height'] ?? 720) as num).toInt();
        final x = (bounds['x'] ?? 0) + (((bounds['width'] ?? width) - width) ~/ 2);
        final y = (bounds['y'] ?? 0) + (((bounds['height'] ?? height) - height) ~/ 2);
        await bridge.setWindowRect(x, y, width, height);
      }
      return;
    }
    final rect = state.mainWindowRect;
    if (rect == null) return;
    final normalized = _normalizeWindowRect(rect, bounds);
    if (normalized == null) return;
    await bridge.setWindowRect(
      normalized['x']!,
      normalized['y']!,
      normalized['width']!,
      normalized['height']!,
    );
  }

  Future<void> _captureMainWindowPlacement(AppState state, PlatformBridge bridge) async {
    if (!state.rememberMainWindowPlacement) {
      state.setMainWindowRect(null, notify: false);
      return;
    }
    final rect = await bridge.getWindowRect();
    if (rect == null) return;
    final bounds = await bridge.getDisplayBounds();
    final normalized = _normalizeWindowRect(rect, bounds);
    if (normalized == null) return;
    state.setMainWindowRect(normalized, notify: false);
  }

  int? _getActiveDeviceId() {
    final state = context.read<AppState>();
    final serial = state.activeSerial;
    if (serial == null) return null;
    try {
      return state.devices.firstWhere((d) => d.serial == serial).deviceId;
    } catch (_) {
      return null;
    }
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    // Don't steal keyboard from text fields (alias editing, settings input, etc.)
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.context != null) {
      final ctx = focus.context!;
      if (ctx.findAncestorWidgetOfExactType<EditableText>() != null) return false;
      if (ctx.widget is EditableText) return false;
    }
    final devId = _getActiveDeviceId();
    if (devId == null) return false;

    final key = event.logicalKey;
    final hw = HardwareKeyboard.instance;
    final bridge = PlatformBridge.instance;

    if ((key == LogicalKeyboardKey.keyV) &&
        (hw.isControlPressed || hw.isMetaPressed)) {
      _pasteClipboard(devId);
      return true;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      bridge.sendKey(devId, _kAndroidEnter);
      return true;
    }
    if (key == LogicalKeyboardKey.tab) {
      bridge.sendKey(devId, _kAndroidTab);
      return true;
    }

    if (key == LogicalKeyboardKey.backspace) {
      bridge.sendKey(devId, _kAndroidDel);
      return true;
    }

    final ch = event.character;
    if (ch != null && ch.isNotEmpty && !hw.isControlPressed && !hw.isMetaPressed) {
      bridge.sendText(devId, ch);
      return true;
    }

    return false;
  }

  Future<void> _pasteClipboard(int deviceId) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      debugPrint('[Paste] Clipboard empty');
      return;
    }
    debugPrint('[Paste] Sending "${text.length > 50 ? text.substring(0, 50) : text}" to dev=$deviceId');
    PlatformBridge.instance.sendText(deviceId, text);
  }

  Future<void> _applyClipboardUpdate(Map<String, dynamic> event) async {
    final text = event['text'] as String?;
    if (text == null || text.isEmpty) return;

    final deviceId = event['device_id'] as int? ?? -1;
    final seq = (event['seq'] as num?)?.toInt() ?? 0;
    final updatedAt = (event['updated_at_ms'] as num?)?.toInt() ?? 0;

    bool isNewer = true;
    if (seq > 0 && _lastClipboardSeq > 0) {
      isNewer = seq > _lastClipboardSeq;
    } else if (seq > 0 && _lastClipboardSeq == 0) {
      isNewer = true;
    } else if (updatedAt > 0 && _lastClipboardUpdatedAt > 0) {
      isNewer = updatedAt > _lastClipboardUpdatedAt;
    }
    if (!isNewer) {
      debugPrint('[clipboard] Ignore stale update seq=$seq from dev=$deviceId');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: text));
      _lastClipboard = text; // avoid echo loop in periodic clipboard sync
      if (seq > 0) _lastClipboardSeq = seq;
      if (updatedAt > 0) _lastClipboardUpdatedAt = updatedAt;
      debugPrint(
        '[clipboard] Phone→PC applied dev=$deviceId seq=$seq len=${text.length}',
      );
    } catch (e) {
      debugPrint('[clipboard] Failed to write system clipboard: $e');
    }
  }

  Future<void> _initNativeAndConnect() async {
    final state = context.read<AppState>();
    final bridge = PlatformBridge.instance;

    // Load persisted state
    await _loadPersistedState(state);

    // Auto-save on state changes (debounced)
    state.addListener(() => _debouncedSave(state));

    // Register global keyboard handler for ADB text input
    HardwareKeyboard.instance.addHandler(_onHardwareKey);

    final info = await bridge.init();
    await bridge.setMainWindow();
    await _restoreMainWindowPlacement(state, bridge);
    int vramMb = 0;
    if (info != null) {
      vramMb = (info['vram_mb'] as int?) ?? 0;
      debugPrint('[MainScreen] D3D11 adapter: ${info['adapter']}, VRAM: $vramMb MB');
    }

    // Detect GPU: discrete (>= 512MB VRAM) → 60fps, integrated → 30fps
    final isDiscrete = vramMb >= 512;
    debugPrint('[MainScreen] GPU: ${isDiscrete ? "discrete" : "integrated"} ($vramMb MB)');

    _eventSub = bridge.events.listen((event) => _handleNativeEvent(event, state));

    state.setConnection(ServerConnectionState.connecting);
    _syncWindowTitle(state);
    await bridge.connect(state.serverHost);

    // After connecting, set FPS profile based on GPU capability
    // Profile "full" = 60fps/8M, "reduced" = 30fps/2M
    // This is sent for all devices once connection is established
    _desiredProfile = isDiscrete ? 'full' : 'reduced';
    debugPrint('[MainScreen] Default FPS profile: $_desiredProfile');
  }

  void _syncWindowTitle(AppState state) {
    final title = state.windowTitle;
    if (title == _lastTitle) return;
    _lastTitle = title;
    PlatformBridge.instance.setWindowTitle(title);
  }

  void _handleNativeEvent(Map<String, dynamic> event, AppState state) {
    final type = event['event'] as String?;
    if (type == null) return;

    switch (type) {
      case 'server_connection_state':
        final prevConn = state.connection;
        final s = event['state'] as String? ?? '';
        final newConn = switch (s) {
          'connected'    => ServerConnectionState.connected,
          'connecting'   => ServerConnectionState.connecting,
          'reconnecting' => ServerConnectionState.reconnecting,
          _              => ServerConnectionState.disconnected,
        };
        state.setConnection(newConn);
        if (prevConn != ServerConnectionState.connected &&
            newConn == ServerConnectionState.connected) {
          _lastClipboard = '';
          _lastClipboardSeq = 0;
          _lastClipboardUpdatedAt = 0;
        }
        if (newConn == ServerConnectionState.connected) {
          _fhdProfileSent.clear();
          _subQueue.clear();
          _subscribingNow.clear();
        }
        _syncWindowTitle(state);

      case 'device_list':
        if (state.connection != ServerConnectionState.connected) return;
        _onDeviceList(event, state);

      case 'decoder_error':
        final id = event['device_id'] as int?;
        final action = event['action'] as String?;
        if (id != null && action == 'failed') {
          state.updateDevice(id, (d) => d.copyWith(phase: DevicePhase.failed));
        }

      case 'frame_ready':
        final frid = event['device_id'] as int?;
        if (frid != null) {
          state.updateDevice(frid, (d) => d.copyWith(hasFrames: true));
          _onDeviceFrameReady(PlatformBridge.instance, state, frid);
        }

      case 'fps_update':
        final id = event['device_id'] as int?;
        final profile = event['profile'] as String?;
        final restarting = event['restarting'] as bool? ?? false;
        debugPrint('[fps_update] dev=$id profile=$profile restarting=$restarting');
        if (id != null && profile != null) {
          final fpsVal = (profile == 'full' || profile == 'fhd') ? 60 : 24;
          state.updateDevice(id, (d) => d.copyWith(fps: fpsVal, isQualitySwitching: restarting, hasFrames: restarting ? false : d.hasFrames));
          if (restarting) {
            _resubscribeAfterQualitySwitch(PlatformBridge.instance, state, id);
          }
        }

      case 'lock_status':
        final id = event['device_id'] as int?;
        final owner = event['owner'] as String?;
        if (id != null) {
          if (owner != null && owner.isNotEmpty) {
            state.updateDevice(id, (d) => d.copyWith(phase: DevicePhase.locked, lockOwner: owner));
          } else {
            state.updateDevice(id, (d) => d.copyWith(phase: DevicePhase.online, lockOwner: null));
          }
        }

      case 'control_status':
        // Multi-client control status update (for future UI)
        debugPrint('[control] dev=${event['device_id']} mode=${event['mode']} controller=${event['controller']}');

      case 'device_list_error':
        unawaited(_handleDeviceListError(event, state));

      case 'clipboard_update':
        unawaited(_applyClipboardUpdate(event));

      case 'close_requested':
        _showCloseConfirmation();
    }
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: MUPhoneColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: MUPhoneColors.border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MUPhoneColors.statusFailed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.power_settings_new, size: 18, color: MUPhoneColors.statusFailed),
          ),
          const SizedBox(width: 12),
          Text('關閉 MUPhone', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MUPhoneColors.textPrimary)),
        ]),
        content: Text(
          '確定要關閉客戶端嗎？\n所有裝置連接將會中斷。',
          style: TextStyle(fontSize: 12, color: MUPhoneColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(fontSize: 12, color: MUPhoneColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final state = context.read<AppState>();
              await _captureMainWindowPlacement(state, PlatformBridge.instance);
              await _saveStateNow(state);
              PlatformBridge.instance.confirmExit();
            },
            icon: const Icon(Icons.power_settings_new, size: 14),
            label: const Text('關閉'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MUPhoneColors.statusFailed,
              foregroundColor: MUPhoneColors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _onDeviceList(Map<String, dynamic> event, AppState state) {
    final devices = event['devices'];
    if (devices is! List) return;

    final bridge = PlatformBridge.instance;
    final seenSerials = <String>{};

    for (final raw in devices) {
      if (raw is! Map) continue;
      final d = Map<String, dynamic>.from(raw);
      final id = d['device_id'] as int? ?? -1;
      if (id < 0) continue;

      final phase = _parsePhase(d['phase'] as String? ?? 'offline');
      final serial = d['serial'] as String? ?? '';
      if (serial.isNotEmpty) {
        seenSerials.add(serial);
      }
      final width = d['width'] as int? ?? 405;
      final height = d['height'] as int? ?? 720;
      final physW = d['physical_width'] as int? ?? 0;
      final physH = d['physical_height'] as int? ?? 0;
      final profile = d['profile'] as String? ?? '';
      final physicalW = physW > 0 ? physW : (width > 0 ? (width * 10 ~/ 3) : 1080);
      final physicalH = physH > 0 ? physH : (height > 0 ? (height * 10 ~/ 3) : 2400);
      // Derive FPS from server-reported profile
      final fpsFromProfile = (profile == 'fhd' || profile == 'full') ? 60 : (profile == 'hd') ? 30 : (profile == 'reduced') ? 24 : 0;

      if (profile.isNotEmpty && state.getDeviceQuality(serial) != profile) {
        state.setDeviceQuality(serial, profile);
      }

      final existing = state.getDevice(id);
      if (existing == null) {
        final savedAlias = state.getDeviceAlias(serial);
        state.addDevice(DeviceState(
          deviceId: id, serial: serial, phase: phase,
          width: width, height: height,
          physicalWidth: physicalW, physicalHeight: physicalH,
          alias: savedAlias, fps: fpsFromProfile,
        ));
        if ((phase == DevicePhase.online || phase == DevicePhase.locked) &&
            !state.isDeviceHidden(serial)) {
          final needsFhd = state.getDeviceQuality(serial) == 'fhd' && height < 1080;
          if (!needsFhd) {
            _enqueueSubscribe(bridge, state, id, width, height);
          }
        }
      } else {
        final nowOnline = phase == DevicePhase.online || phase == DevicePhase.locked;
        final dimChanged = existing.width != width || existing.height != height;
        final wasOnline = existing.phase == DevicePhase.online || existing.phase == DevicePhase.locked;
        final goingStarting = phase == DevicePhase.starting && wasOnline;
        state.updateDevice(id, (d) => d.copyWith(
          phase: phase, serial: serial,
          width: width, height: height,
          physicalWidth: physicalW, physicalHeight: physicalH,
          fps: fpsFromProfile > 0 ? fpsFromProfile : d.fps,
          isQualitySwitching: dimChanged ? false : d.isQualitySwitching,
          hasFrames: goingStarting ? false : null,
        ));
        if (goingStarting && existing.textureId != null) {
          bridge.unsubscribeDevice(id);
          state.updateDevice(id, (d) => d.copyWith(textureId: null));
          _subscribingNow.remove(id);
        }
        if (nowOnline && !state.isDeviceHidden(serial)) {
          final needsFhd2 = state.getDeviceQuality(serial) == 'fhd' && height < 1080;
          if (existing.textureId == null && !needsFhd2) {
            _enqueueSubscribe(bridge, state, id, width, height);
          } else if (dimChanged) {
            debugPrint('[device_list] dev=$id dim changed ${existing.width}x${existing.height} → ${width}x$height — resubscribe');
            bridge.unsubscribeDevice(id);
            state.updateDevice(id, (d) => d.copyWith(textureId: null, hasFrames: false));
            _enqueueSubscribe(bridge, state, id, width, height);
          }
        }
      }
    }

    for (final device in List<DeviceState>.from(state.devices)) {
      if (seenSerials.contains(device.serial)) continue;
      if (device.textureId != null) {
        bridge.unsubscribeDevice(device.deviceId);
      }
      state.updateDevice(
        device.deviceId,
        (d) => d.copyWith(
          phase: DevicePhase.offline,
          textureId: null,
          hasFrames: false,
          isQualitySwitching: false,
        ),
      );
      _subscribingNow.remove(device.deviceId);
      _subQueue.removeWhere((q) => q.deviceId == device.deviceId);
      if (_fhdProfileSent.contains(device.deviceId)) {
        _fhdProfileSent.remove(device.deviceId);
      }
    }

    // Quality sync: delay FHD upgrades until 5s after this device_list
    // to let all HD devices connect first and stabilise.
    for (final dev in state.devices) {
      if (_fhdProfileSent.contains(dev.deviceId)) continue;
      final clientQ = state.getDeviceQuality(dev.serial);
      if (clientQ == 'fhd' && dev.height < 1080) {
        _fhdProfileSent.add(dev.deviceId);
        final devId = dev.deviceId;
        debugPrint('[quality-sync] dev=$devId queued for fhd in 5s');
        Future.delayed(const Duration(seconds: 5), () {
          bridge.setFpsProfile(devId, 'fhd');
        });
      }
    }
  }

  final Map<int, int> _subscribeGen = {};

  void _enqueueSubscribe(PlatformBridge bridge, AppState state, int id, int w, int h) {
    if (_subscribingNow.contains(id)) return;
    if (_subQueue.any((s) => s.deviceId == id)) return;
    _subQueue.add(_PendingSub(deviceId: id, w: w, h: h));
    _drainSubQueue(bridge, state);
  }

  void _drainSubQueue(PlatformBridge bridge, AppState state) {
    if (_subscribingNow.length >= _maxConcurrentSubs) return;
    if (_subQueue.isEmpty) return;
    final item = _subQueue.removeAt(0);
    _subscribingNow.add(item.deviceId);
    _doSubscribe(bridge, state, item.deviceId, item.w, item.h);
  }

  void _onDeviceFrameReady(PlatformBridge bridge, AppState state, int deviceId) {
    _subscribingNow.remove(deviceId);
    _streamRetryCount[deviceId] = 0;
    _drainSubQueue(bridge, state);
  }

  void _releaseSubSlot(int id, PlatformBridge bridge, AppState state) {
    _subscribingNow.remove(id);
    _drainSubQueue(bridge, state);
  }

  Future<void> _doSubscribe(PlatformBridge bridge, AppState state, int id, int w, int h) async {
    final gen = (_subscribeGen[id] ?? 0) + 1;
    _subscribeGen[id] = gen;

    final subW = w > 0 ? w : 405;
    final subH = h > 0 ? h : 720;
    debugPrint('[sub-queue] subscribing dev=$id (queue=${_subQueue.length} active=${_subscribingNow.length})');
    final textureId = await bridge.subscribeDevice(id, width: subW, height: subH);
    if (textureId != null) {
      state.updateDevice(id, (d) => d.copyWith(textureId: textureId));
    }

    // Long timeout safety net: 30s — should never hit with working IDR gate
    Future.delayed(const Duration(seconds: 8), () {
      if (_subscribeGen[id] != gen) return;
      if (_subscribingNow.contains(id)) {
        final dev = state.getDevice(id);
        final online = dev?.phase == DevicePhase.online || dev?.phase == DevicePhase.locked;
        final hadFrame = dev?.hasFrames == true;
        if (online && !hadFrame) {
          final retry = (_streamRetryCount[id] ?? 0) + 1;
          _streamRetryCount[id] = retry;
          if (retry <= 2) {
            debugPrint('[sub-queue] dev=$id no frame timeout — retry stream #$retry');
            bridge.unsubscribeDevice(id);
            state.updateDevice(id, (d) => d.copyWith(textureId: null, hasFrames: false));
            _releaseSubSlot(id, bridge, state);
            _enqueueSubscribe(bridge, state, id, subW, subH);
            return;
          }
          _streamRetryCount[id] = 0;
          debugPrint('[sub-queue] dev=$id no frame after retries — full reconnect');
          _releaseSubSlot(id, bridge, state);
          unawaited(_triggerFullReconnect(state, '裝置 $id 長時間無畫面'));
          return;
        }
        debugPrint('[sub-queue] dev=$id 8s timeout — releasing slot');
        _releaseSubSlot(id, bridge, state);
      }
    });
  }

  Future<void> _handleDeviceListError(
    Map<String, dynamic> event,
    AppState state,
  ) async {
    final message = (event['message'] as String?)?.trim();
    if (message == null || message.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastDeviceErrorAtMs < 2500) return;
    _lastDeviceErrorAtMs = now;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    if (state.connection == ServerConnectionState.connected) return;
    await PlatformBridge.instance.connect(state.serverHost);
  }

  Future<void> _triggerFullReconnect(AppState state, String reason) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastReconnectAtMs < 8000) return;
    _lastReconnectAtMs = now;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$reason，正在嘗試重連...')),
      );
    }
    final bridge = PlatformBridge.instance;
    await bridge.disconnect();
    await Future.delayed(const Duration(milliseconds: 300));
    await bridge.connect(state.serverHost);
  }

  void _resubscribeAfterQualitySwitch(PlatformBridge bridge, AppState state, int id) {
    final gen = (_qualitySwitchGen[id] ?? 0) + 1;
    _qualitySwitchGen[id] = gen;

    final dev = state.getDevice(id);
    if (dev == null || state.isDeviceHidden(dev.serial)) {
      state.updateDevice(id, (d) => d.copyWith(isQualitySwitching: false));
      return;
    }
    bridge.unsubscribeDevice(id);
    state.updateDevice(id, (d) => d.copyWith(textureId: null));
    Future.delayed(const Duration(milliseconds: 800), () async {
      if (_qualitySwitchGen[id] != gen) return;
      final d2 = state.getDevice(id);
      if (d2 != null && !state.isDeviceHidden(d2.serial)) {
        // Just resubscribe video — do NOT re-send profile (server already has the correct one)
        final subW = d2.width > 0 ? d2.width : 405;
        final subH = d2.height > 0 ? d2.height : 720;
        final textureId = await bridge.subscribeDevice(id, width: subW, height: subH);
        if (textureId != null && _qualitySwitchGen[id] == gen) {
          state.updateDevice(id, (d) => d.copyWith(textureId: textureId, isQualitySwitching: false));
        } else {
          state.updateDevice(id, (d) => d.copyWith(isQualitySwitching: false));
        }
      } else {
        state.updateDevice(id, (d) => d.copyWith(isQualitySwitching: false));
      }
    });
  }

  static DevicePhase _parsePhase(String s) => switch (s.toLowerCase()) {
    'online'   => DevicePhase.online,
    'starting' => DevicePhase.starting,
    'locked'   => DevicePhase.locked,
    'failed'   => DevicePhase.failed,
    _          => DevicePhase.offline,
  };

  void _openSettings() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppState>(),
        child: const SettingsModal(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        _syncWindowTitle(state);
        return const Scaffold(
          body: DeviceGrid(),
        );
      },
    );
  }
}

class _PendingSub {
  final int deviceId;
  final int w, h;
  _PendingSub({required this.deviceId, required this.w, required this.h});
}
