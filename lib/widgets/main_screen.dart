import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
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
  int _activeSubCount = 0;
  static const int _maxConcurrentSubs = 1;

  @override
  void initState() {
    super.initState();
    _initNativeAndConnect();
  }

  @override
  void dispose() {
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
    if (data.containsKey('settingsShortcutKey')) {
      state.setSettingsShortcutKey(data['settingsShortcutKey'] as String? ?? '=');
    }
  }

  void _debouncedSave(AppState state) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      final gc = state.gridConfig;
      Persistence.instance.save({
        'gridConfig': {'columns': gc.columns, 'rows': gc.rows},
        'deviceOrder': state.deviceOrder,
        'serverHost': state.serverHost,
        'hiddenSerials': state.hiddenSerials.toList(),
        'deviceQuality': state.deviceQuality,
        'deviceAliases': state.deviceAliases,
        'shortcuts': state.shortcuts.map((s) => s.toJson()).toList(),
        'settingsShortcutKey': state.settingsShortcutKey,
      });
    });
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
        final s = event['state'] as String? ?? '';
        final newConn = switch (s) {
          'connected'    => ServerConnectionState.connected,
          'connecting'   => ServerConnectionState.connecting,
          'reconnecting' => ServerConnectionState.reconnecting,
          _              => ServerConnectionState.disconnected,
        };
        state.setConnection(newConn);
        if (newConn == ServerConnectionState.connected) {
          _fhdProfileSent.clear();
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
            onPressed: () {
              Navigator.pop(ctx);
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
    final currentIds = state.devices.map((d) => d.deviceId).toSet();
    final newIds = <int>{};

    for (final raw in devices) {
      if (raw is! Map) continue;
      final d = Map<String, dynamic>.from(raw);
      final id = d['device_id'] as int? ?? -1;
      if (id < 0) continue;
      newIds.add(id);

      final phase = _parsePhase(d['phase'] as String? ?? 'offline');
      final serial = d['serial'] as String? ?? '';
      final width = d['width'] as int? ?? 405;
      final height = d['height'] as int? ?? 720;
      final physW = d['physical_width'] as int? ?? 0;
      final physH = d['physical_height'] as int? ?? 0;
      final profile = d['profile'] as String? ?? '';
      final physicalW = physW > 0 ? physW : (width > 0 ? (width * 10 ~/ 3) : 1080);
      final physicalH = physH > 0 ? physH : (height > 0 ? (height * 10 ~/ 3) : 2400);
      // Derive FPS from server-reported profile
      final fpsFromProfile = (profile == 'fhd' || profile == 'full') ? 60 : (profile == 'hd') ? 30 : (profile == 'reduced') ? 24 : 0;

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
          _enqueueSubscribe(bridge, state, id, width, height);
        }
      } else {
        final nowOnline = phase == DevicePhase.online || phase == DevicePhase.locked;
        final dimChanged = existing.width != width || existing.height != height;
        state.updateDevice(id, (d) => d.copyWith(
          phase: phase, serial: serial,
          width: width, height: height,
          physicalWidth: physicalW, physicalHeight: physicalH,
          fps: fpsFromProfile > 0 ? fpsFromProfile : d.fps,
          isQualitySwitching: dimChanged ? false : d.isQualitySwitching,
        ));
        if (nowOnline && !state.isDeviceHidden(serial)) {
          if (existing.textureId == null) {
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

    for (final id in currentIds) {
      if (!newIds.contains(id)) {
        bridge.unsubscribeDevice(id);
        state.removeDevice(id);
      }
    }

    // Server persists profiles — no need to send on connect.
    // Quality changes are sent only when user explicitly changes in settings UI.
  }

  final Map<int, int> _subscribeGen = {};

  void _enqueueSubscribe(PlatformBridge bridge, AppState state, int id, int w, int h) {
    if (_subQueue.any((s) => s.deviceId == id)) return;
    _subQueue.add(_PendingSub(deviceId: id, w: w, h: h));
    _processSubQueue(bridge, state);
  }

  void _processSubQueue(PlatformBridge bridge, AppState state) {
    while (_activeSubCount < _maxConcurrentSubs && _subQueue.isNotEmpty) {
      final item = _subQueue.removeAt(0);
      _activeSubCount++;
      _subscribeAndSetTexture(bridge, state, item.deviceId, item.w, item.h);
    }
  }

  void _onDeviceFrameReady(PlatformBridge bridge, AppState state, int deviceId) {
    _activeSubCount = (_activeSubCount - 1).clamp(0, 99);
    _processSubQueue(bridge, state);
  }

  Future<void> _subscribeAndSetTexture(PlatformBridge bridge, AppState state, int id, int w, int h) async {
    final gen = (_subscribeGen[id] ?? 0) + 1;
    _subscribeGen[id] = gen;

    final subW = w > 0 ? w : 405;
    final subH = h > 0 ? h : 720;
    final textureId = await bridge.subscribeDevice(id, width: subW, height: subH);
    if (textureId != null) {
      state.updateDevice(id, (d) => d.copyWith(textureId: textureId));
    }

    // Timeout: if no frames after 4s, release the slot and move on
    Future.delayed(const Duration(seconds: 4), () {
      if (_subscribeGen[id] != gen) return;
      final dev = state.getDevice(id);
      if (dev != null && !dev.hasFrames) {
        _activeSubCount = (_activeSubCount - 1).clamp(0, 99);
        _processSubQueue(bridge, state);
      }
    });
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
