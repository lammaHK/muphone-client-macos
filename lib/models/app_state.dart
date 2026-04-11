import 'dart:async';
import 'package:flutter/material.dart';
import 'adb_command_preset.dart';
import 'shortcut_icon_catalog.dart';
import '../services/platform_bridge.dart';

enum ServerConnectionState { disconnected, connecting, connected, reconnecting }

enum DevicePhase { offline, starting, online, locked, failed }

class ShortcutAction {
  final String label;
  final String icon;
  final String actionType;
  final String command;
  final Map<String, dynamic> args;
  final String? deviceSerial; // null means global

  static const String appLaunch = 'app_launch';
  static const String adbCommand = 'adb_command';
  static const String tap = 'tap';
  static const String middle = 'middle';
  static const String swipeUp = 'swipe_up';
  static const String swipeDown = 'swipe_down';
  static const String enter = 'enter';
  static const Set<String> supportedTypes = {appLaunch, adbCommand};

  const ShortcutAction({
    required this.label,
    this.icon = 'apps',
    this.actionType = appLaunch,
    this.command = '',
    this.args = const {},
    this.deviceSerial,
  });

  factory ShortcutAction.fromJson(Map<String, dynamic> j) {
    final actionTypeRaw =
        (j['actionType'] ?? j['action_type'] ?? j['type'] ?? appLaunch).toString();
    final normalizedType = normalizeActionType(actionTypeRaw);
    final parsedArgs = <String, dynamic>{};
    final rawArgs = j['args'] ?? j['arguments'];
    if (rawArgs is Map) {
      for (final entry in rawArgs.entries) {
        parsedArgs[entry.key.toString()] = entry.value;
      }
    }
    final cmd = (j['command'] as String? ?? '').trim();
    if (parsedArgs.isEmpty && cmd.isNotEmpty) {
      if (normalizedType == appLaunch) {
        parsedArgs['package'] = cmd;
      } else if (normalizedType == adbCommand) {
        parsedArgs['command'] = cmd;
      }
    }

    return ShortcutAction(
      label: (j['label'] as String? ?? '').trim(),
      icon: (j['icon'] as String? ?? 'apps').trim(),
      actionType: normalizedType,
      command: cmd,
      args: parsedArgs,
      deviceSerial: (j['deviceSerial'] as String?)?.trim().isEmpty == true
          ? null
          : j['deviceSerial'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'icon': icon,
    'actionType': actionType,
    'command': commandForLegacy,
    'args': args,
    // Backward compatibility for old clients/state readers.
    'type': legacyShortcutType,
    'deviceSerial': deviceSerial,
  };

  static String normalizeActionType(String rawType) {
    switch (rawType.toLowerCase()) {
      case 'app':
      case 'app_launch':
      case 'launch_app':
        return appLaunch;
      case 'adb':
      case 'adb_command':
      case 'command':
        return adbCommand;
      case 'tap':
      case 'left_click':
      case 'mouse_left':
        return tap;
      case 'middle':
      case 'middle_click':
      case 'mouse_middle':
        return middle;
      case 'swipe_up':
      case 'up_swipe':
        return swipeUp;
      case 'swipe_down':
      case 'down_swipe':
        return swipeDown;
      case 'enter':
        return enter;
      default:
        return rawType.toLowerCase();
    }
  }

  static bool isSupportedType(String actionType) {
    return supportedTypes.contains(actionType);
  }

  String get legacyShortcutType => actionType == appLaunch ? 'app' : 'adb';

  String get commandKey {
    return switch (actionType) {
      appLaunch => 'package',
      adbCommand => 'command',
      _ => 'command',
    };
  }

  String get commandForLegacy {
    final cmd = command.trim();
    if (cmd.isNotEmpty) return cmd;
    final fromArgs = args[commandKey];
    return fromArgs is String ? fromArgs.trim() : '';
  }

  bool get requiresCommand => actionType == appLaunch || actionType == adbCommand;

  Map<String, dynamic> toActionPayload() {
    return {
      'action_type': actionType,
      'command': commandForLegacy,
      if (args.isNotEmpty) 'args': args,
    };
  }

  static const List<ShortcutAction> defaults = [
    ShortcutAction(label: 'Chrome', icon: 'language', actionType: appLaunch, command: 'com.android.chrome'),
    ShortcutAction(label: 'WhatsApp', icon: 'chat', actionType: appLaunch, command: 'com.whatsapp'),
    ShortcutAction(label: 'Camera', icon: 'camera_alt', actionType: appLaunch, command: 'com.sec.android.app.camera'),
    ShortcutAction(label: 'Settings', icon: 'settings', actionType: appLaunch, command: 'com.android.settings'),
  ];

  static IconData iconData(String name) {
    return ShortcutIconCatalog.iconData(name);
  }

  static List<String> get iconKeys => ShortcutIconCatalog.defaultKeys;
}

class CustomControlAction {
  const CustomControlAction({
    required this.id,
    required this.name,
    required this.description,
    required this.command,
    required this.bindings,
    required this.builtIn,
  });

  final String id;
  final String name;
  final String description;
  final String command;
  final List<String> bindings;
  final bool builtIn;

  static const String cmdTouchDrag = 'touch_drag';
  static const String cmdTapHere = 'tap_here';
  static const String cmdDoubleTapHere = 'double_tap_here';
  static const String cmdScrollNative = 'scroll_native';
  static const String cmdPasteText = 'paste_text';

  static const List<CustomControlAction> defaults = [
    CustomControlAction(
      id: 'touch_drag',
      name: '拖曳 / 點擊',
      description: '主要觸控拖曳與點擊操作',
      command: cmdTouchDrag,
      bindings: ['mouse_left'],
      builtIn: true,
    ),
    CustomControlAction(
      id: 'android_back',
      name: '返回',
      description: '送出 Android 返回鍵',
      command: 'key:4',
      bindings: ['mouse_right'],
      builtIn: true,
    ),
    CustomControlAction(
      id: 'middle_double_tap',
      name: '中鍵雙擊',
      description: '在游標位置送出雙擊',
      command: cmdDoubleTapHere,
      bindings: ['mouse_middle'],
      builtIn: true,
    ),
    CustomControlAction(
      id: 'wheel_scroll',
      name: '滾輪捲動',
      description: '使用滾輪觸發原生捲動注入',
      command: cmdScrollNative,
      bindings: ['mouse_wheel'],
      builtIn: true,
    ),
    CustomControlAction(
      id: 'enter_key',
      name: 'Enter',
      description: '送出 Android Enter',
      command: 'key:66',
      bindings: ['key:enter'],
      builtIn: true,
    ),
    CustomControlAction(
      id: 'space_key',
      name: 'Space',
      description: '送出 Android Space',
      command: 'key:62',
      bindings: ['key:space'],
      builtIn: true,
    ),
    CustomControlAction(
      id: 'backspace_key',
      name: 'Backspace',
      description: '送出 Android Backspace',
      command: 'key:67',
      bindings: ['key:backspace'],
      builtIn: true,
    ),
    CustomControlAction(
      id: 'paste_clipboard',
      name: '貼上剪貼簿',
      description: '將電腦剪貼簿文字貼到裝置',
      command: cmdPasteText,
      bindings: ['shortcut:paste'],
      builtIn: true,
    ),
  ];

  factory CustomControlAction.fromJson(Map<String, dynamic> j) {
    final rawBindings = j['bindings'];
    final bindings = <String>[];
    if (rawBindings is List) {
      for (final item in rawBindings) {
        final normalized = normalizeBinding(item.toString());
        if (normalized.isNotEmpty && !bindings.contains(normalized)) {
          bindings.add(normalized);
        }
      }
    }
    if (bindings.isEmpty) {
      final legacy = normalizeBinding((j['binding'] ?? '').toString());
      if (legacy.isNotEmpty) bindings.add(legacy);
    }
    return CustomControlAction(
      id: (j['id'] ?? '').toString().trim(),
      name: (j['name'] ?? '').toString().trim(),
      description: (j['description'] ?? '').toString().trim(),
      command: (j['command'] ?? '').toString().trim(),
      bindings: bindings,
      builtIn: j['builtIn'] == true || j['builtin'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'command': command,
    'bindings': bindings,
    'builtIn': builtIn,
  };

  CustomControlAction copyWith({
    String? id,
    String? name,
    String? description,
    String? command,
    List<String>? bindings,
    bool? builtIn,
  }) {
    return CustomControlAction(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      command: command ?? this.command,
      bindings: bindings ?? this.bindings,
      builtIn: builtIn ?? this.builtIn,
    );
  }

  static String normalizeBinding(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return '';
    if (v == 'ctrl+v' || v == 'cmd+v') return 'shortcut:paste';
    if (v == 'enter') return 'key:enter';
    if (v == 'space') return 'key:space';
    if (v == 'backspace') return 'key:backspace';
    return v;
  }
}

class GridConfig {
  final int columns;
  final int rows;

  const GridConfig({this.columns = 6, this.rows = 2});

  int get totalSlots => columns * rows;

  GridConfig copyWith({int? columns, int? rows}) =>
      GridConfig(columns: columns ?? this.columns, rows: rows ?? this.rows);

  @override
  bool operator ==(Object other) =>
      other is GridConfig && other.columns == columns && other.rows == rows;

  @override
  int get hashCode => Object.hash(columns, rows);
}

class DeviceState {
  final int deviceId;
  final String serial;
  String alias;
  DevicePhase phase;
  String? lockOwner;
  int width;          // stream width (e.g. 328)
  int height;         // stream height (e.g. 720)
  int physicalWidth;  // device physical width (e.g. 1080)
  int physicalHeight; // device physical height (e.g. 2400)
  int fps;
  bool isSelected;
  bool isDetached;
  bool isQualitySwitching;
  bool hasFrames;
  int? textureId;

  DeviceState({
    required this.deviceId,
    required this.serial,
    this.alias = '',
    this.phase = DevicePhase.offline,
    this.lockOwner,
    this.width = 405,
    this.height = 720,
    this.physicalWidth = 1080,
    this.physicalHeight = 2400,
    this.fps = 0,
    this.isSelected = false,
    this.isDetached = false,
    this.isQualitySwitching = false,
    this.hasFrames = false,
    this.textureId,
  });

  String get displayName => alias.isNotEmpty ? alias : serial;

  bool get isLockedByMe => phase == DevicePhase.locked && lockOwner == 'me';
  bool get isLockedByOther => phase == DevicePhase.locked && lockOwner != 'me';

  DeviceState copyWith({
    int? deviceId,
    String? serial,
    String? alias,
    DevicePhase? phase,
    String? lockOwner,
    int? width,
    int? height,
    int? physicalWidth,
    int? physicalHeight,
    int? fps,
    bool? isSelected,
    bool? isDetached,
    bool? isQualitySwitching,
    bool? hasFrames,
    int? textureId,
  }) {
    return DeviceState(
      deviceId: deviceId ?? this.deviceId,
      serial: serial ?? this.serial,
      alias: alias ?? this.alias,
      phase: phase ?? this.phase,
      lockOwner: lockOwner ?? this.lockOwner,
      width: width ?? this.width,
      height: height ?? this.height,
      physicalWidth: physicalWidth ?? this.physicalWidth,
      physicalHeight: physicalHeight ?? this.physicalHeight,
      fps: fps ?? this.fps,
      isSelected: isSelected ?? this.isSelected,
      isDetached: isDetached ?? this.isDetached,
      isQualitySwitching: isQualitySwitching ?? this.isQualitySwitching,
      hasFrames: hasFrames ?? this.hasFrames,
      textureId: textureId ?? this.textureId,
    );
  }
}

class AppState extends ChangeNotifier {
  ServerConnectionState _connection = ServerConnectionState.disconnected;
  final List<DeviceState> _devices = [];
  int? _focusedDeviceId;
  GridConfig _gridConfig = const GridConfig();
  final Set<int> _selectedDeviceIds = {};
  bool _deviceListPanelOpen = false;
  String _serverHost = '127.0.0.1';
  String _settingsShortcutKey = '=';
  String? _activeSerial;
  Set<String> _hiddenSerials = {};
  Map<String, String> _deviceQuality = {};  // serial → 'hd' or 'fhd'
  Map<String, String> _deviceAliases = {};  // serial → alias
  List<ShortcutAction> _shortcuts = List.of(ShortcutAction.defaults);
  List<AdbCommandPreset> _adbCommandPresets = List.of(AdbCommandPreset.defaults);
  List<CustomControlAction> _customControlActions =
      List.of(CustomControlAction.defaults);
  bool _rememberMainWindowPlacement = true;
  bool _rememberDetachedWindowPlacement = true;
  Map<String, int>? _mainWindowRect;
  Map<String, Map<String, int>> _detachedWindowRects = {};
  Map<String, String> _customControls = {
    'mouseLeft': CustomControlAction.cmdTouchDrag,
    'mouseMiddle': CustomControlAction.cmdDoubleTapHere,
    'mouseRight': 'key:4',
    'scroll': CustomControlAction.cmdScrollNative,
    'enter': 'key:66',
    'space': 'key:62',
    'backspace': 'key:67',
    'paste': CustomControlAction.cmdPasteText,
  };

  ServerConnectionState get connection => _connection;
  List<DeviceState> get devices => List.unmodifiable(_devices);
  /// Only devices not hidden. Offline cards remain visible for stable ordering.
  List<DeviceState> get visibleDevices =>
      _devices.where((d) => !_hiddenSerials.contains(d.serial)).toList();
  int? get focusedDeviceId => _focusedDeviceId;
  GridConfig get gridConfig => _gridConfig;
  Set<int> get selectedDeviceIds => Set.unmodifiable(_selectedDeviceIds);
  bool get deviceListPanelOpen => _deviceListPanelOpen;
  String get serverHost => _serverHost;
  String get settingsShortcutKey => _settingsShortcutKey;
  String? get activeSerial => _activeSerial;
  Set<String> get hiddenSerials => Set.unmodifiable(_hiddenSerials);
  Map<String, String> get deviceQuality => Map.unmodifiable(_deviceQuality);
  bool get rememberMainWindowPlacement => _rememberMainWindowPlacement;
  bool get rememberDetachedWindowPlacement => _rememberDetachedWindowPlacement;
  Map<String, int>? get mainWindowRect =>
      _mainWindowRect == null ? null : Map<String, int>.from(_mainWindowRect!);
  Map<String, Map<String, int>> get detachedWindowRects =>
      Map.unmodifiable(_detachedWindowRects.map(
        (k, v) => MapEntry(k, Map<String, int>.from(v)),
      ));

  String getDeviceQuality(String serial) => _deviceQuality[serial] ?? 'hd';
  Map<String, String> get deviceAliases => Map.unmodifiable(_deviceAliases);
  List<ShortcutAction> get shortcuts => List.unmodifiable(_shortcuts);
  List<AdbCommandPreset> get adbCommandPresets =>
      List.unmodifiable(_adbCommandPresets);
  List<CustomControlAction> get customControlActions =>
      List.unmodifiable(_customControlActions);
  Map<String, String> get customControls => Map.unmodifiable(_customControls);

  void setRememberMainWindowPlacement(bool enabled) {
    if (_rememberMainWindowPlacement == enabled) return;
    _rememberMainWindowPlacement = enabled;
    notifyListeners();
  }

  void setRememberDetachedWindowPlacement(bool enabled) {
    if (_rememberDetachedWindowPlacement == enabled) return;
    _rememberDetachedWindowPlacement = enabled;
    notifyListeners();
  }

  void setMainWindowRect(Map<String, int>? rect, {bool notify = true}) {
    _mainWindowRect = rect == null ? null : Map<String, int>.from(rect);
    if (notify) notifyListeners();
  }

  Map<String, int>? getDetachedWindowRect(int deviceId) {
    final rect = _detachedWindowRects[deviceId.toString()];
    return rect == null ? null : Map<String, int>.from(rect);
  }

  void setDetachedWindowRect(int deviceId, Map<String, int> rect, {bool notify = true}) {
    _detachedWindowRects[deviceId.toString()] = Map<String, int>.from(rect);
    if (notify) notifyListeners();
  }

  void removeDetachedWindowRect(int deviceId, {bool notify = true}) {
    _detachedWindowRects.remove(deviceId.toString());
    if (notify) notifyListeners();
  }

  void setDetachedWindowRects(Map<String, Map<String, int>> rects, {bool notify = true}) {
    _detachedWindowRects = rects.map(
      (k, v) => MapEntry(k, Map<String, int>.from(v)),
    );
    if (notify) notifyListeners();
  }

  void setCustomControls(Map<String, String> map) {
    _customControls = Map.from(map);
    _customControlActions = _applyLegacyCustomControls(
      _customControlActions,
      _customControls,
    );
    notifyListeners();
  }

  void setShortcuts(List<ShortcutAction> list) {
    _shortcuts = list
        .where((item) => ShortcutAction.isSupportedType(item.actionType))
        .toList(growable: false);
    notifyListeners();
  }

  void setAdbCommandPresets(List<AdbCommandPreset> list) {
    _adbCommandPresets = List.of(list);
    notifyListeners();
  }

  List<CustomControlAction> resolveControlActionsByTrigger(String trigger) {
    final normalized = CustomControlAction.normalizeBinding(trigger);
    if (normalized.isEmpty) return const [];
    return _customControlActions
        .where((item) => item.bindings.contains(normalized))
        .toList(growable: false);
  }

  void setCustomControlActions(List<CustomControlAction> list) {
    final merged = _normalizeControlActions(list);
    _customControlActions = merged;
    _customControls = _buildLegacyCustomControls(merged);
    notifyListeners();
  }

  List<CustomControlAction> _normalizeControlActions(
    List<CustomControlAction> list,
  ) {
    final byId = <String, CustomControlAction>{};
    for (final item in list) {
      final id = item.id.trim();
      if (id.isEmpty) continue;
      final uniqueBindings = <String>[];
      for (final binding in item.bindings) {
        final normalized = CustomControlAction.normalizeBinding(binding);
        if (normalized.isNotEmpty && !uniqueBindings.contains(normalized)) {
          uniqueBindings.add(normalized);
        }
      }
      byId[id] = item.copyWith(
        id: id,
        bindings: uniqueBindings,
      );
    }

    final result = <CustomControlAction>[];
    for (final builtin in CustomControlAction.defaults) {
      final current = byId.remove(builtin.id);
      result.add(
        (current ?? builtin).copyWith(
          id: builtin.id,
          name: builtin.name,
          description: builtin.description,
          builtIn: true,
          bindings: (current?.bindings.isNotEmpty == true)
              ? current!.bindings
              : builtin.bindings,
          command: (current?.command.trim().isNotEmpty == true)
              ? current!.command.trim()
              : builtin.command,
        ),
      );
    }

    for (final custom in byId.values) {
      if (custom.builtIn) continue;
      if (custom.name.trim().isEmpty) continue;
      if (custom.command.trim().isEmpty) continue;
      result.add(custom.copyWith(builtIn: false));
    }
    return result;
  }

  Map<String, String> _buildLegacyCustomControls(List<CustomControlAction> list) {
    String commandOf(String id, String fallback) {
      final action = list.where((item) => item.id == id).firstOrNull;
      final command = action?.command.trim();
      return (command == null || command.isEmpty) ? fallback : command;
    }

    return {
      'mouseLeft': commandOf('touch_drag', CustomControlAction.cmdTouchDrag),
      'mouseMiddle':
          commandOf('middle_double_tap', CustomControlAction.cmdDoubleTapHere),
      'mouseRight': commandOf('android_back', 'key:4'),
      'scroll': commandOf('wheel_scroll', CustomControlAction.cmdScrollNative),
      'enter': commandOf('enter_key', 'key:66'),
      'space': commandOf('space_key', 'key:62'),
      'backspace': commandOf('backspace_key', 'key:67'),
      'paste': commandOf('paste_clipboard', CustomControlAction.cmdPasteText),
    };
  }

  List<CustomControlAction> _applyLegacyCustomControls(
    List<CustomControlAction> source,
    Map<String, String> legacy,
  ) {
    final updated = source.map((item) {
      String? cmd;
      switch (item.id) {
        case 'touch_drag':
          cmd = legacy['mouseLeft'];
        case 'middle_double_tap':
          cmd = legacy['mouseMiddle'];
        case 'android_back':
          cmd = legacy['mouseRight'];
        case 'wheel_scroll':
          cmd = legacy['scroll'];
        case 'enter_key':
          cmd = legacy['enter'];
        case 'space_key':
          cmd = legacy['space'];
        case 'backspace_key':
          cmd = legacy['backspace'];
        case 'paste_clipboard':
          cmd = legacy['paste'];
        default:
          cmd = null;
      }
      if (cmd == null || cmd.trim().isEmpty) return item;
      return item.copyWith(command: cmd.trim());
    }).toList(growable: false);
    return _normalizeControlActions(updated);
  }

  void setDeviceQuality(String serial, String quality) {
    _deviceQuality[serial] = quality;
    notifyListeners();
  }

  void setDeviceQualityMap(Map<String, String> map) {
    _deviceQuality = Map.from(map);
  }

  String getDeviceAlias(String serial) => _deviceAliases[serial] ?? '';

  void setDeviceAlias(String serial, String alias) {
    if (alias.isEmpty) {
      _deviceAliases.remove(serial);
    } else {
      _deviceAliases[serial] = alias;
    }
    // Also update the device state
    for (final d in _devices) {
      if (d.serial == serial) {
        d.alias = alias;
        break;
      }
    }
    notifyListeners();
  }

  void setDeviceAliasMap(Map<String, String> map) {
    _deviceAliases = Map.from(map);
  }

  void hideDevice(String serial) {
    _hiddenSerials.add(serial);
    notifyListeners();
  }

  void showDevice(String serial) {
    _hiddenSerials.remove(serial);
    notifyListeners();
  }

  bool isDeviceHidden(String serial) => _hiddenSerials.contains(serial);

  void setHiddenSerials(Set<String> serials) {
    _hiddenSerials = Set.from(serials);
  }

  void setActiveSerial(String? serial) {
    if (_activeSerial == serial) return;
    _activeSerial = serial;
    notifyListeners();
  }

  int get onlineDeviceCount =>
      _devices.where((d) => d.phase == DevicePhase.online || d.phase == DevicePhase.locked).length;

  int get totalDeviceCount => _devices.length;

  String get windowTitle {
    return switch (_connection) {
      ServerConnectionState.disconnected => 'MUPhone — 離線',
      ServerConnectionState.connecting   => 'MUPhone — 連接中 ($_serverHost)',
      ServerConnectionState.reconnecting => 'MUPhone — 重新連接中...',
      ServerConnectionState.connected    => 'MUPhone — $_serverHost — $onlineDeviceCount 在線 / $totalDeviceCount 裝置',
    };
  }

  DeviceState? getDevice(int deviceId) {
    try {
      return _devices.firstWhere((d) => d.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }

  void setConnection(ServerConnectionState state) {
    final previous = _connection;
    _connection = state;

    if ((state == ServerConnectionState.disconnected || state == ServerConnectionState.reconnecting) &&
        previous == ServerConnectionState.connected) {
      _markAllDevicesOffline();
    }

    notifyListeners();
  }

  void _markAllDevicesOffline() {
    for (var i = 0; i < _devices.length; i++) {
      _devices[i] = _devices[i].copyWith(
        phase: DevicePhase.offline,
        textureId: null,
        hasFrames: false,
        isQualitySwitching: false,
      );
    }
    _selectedDeviceIds.clear();
    _focusedDeviceId = null;
  }

  void addDevice(DeviceState device) {
    final existing = _devices.indexWhere((d) => d.deviceId == device.deviceId);
    if (existing >= 0) {
      _devices[existing] = device;
      _ensureDeviceOrder();
      _sortDevicesByOrder();
      notifyListeners();
      return;
    }
    final bySerial = _devices.indexWhere((d) => d.serial == device.serial);
    if (bySerial >= 0) {
      _devices[bySerial] = device;
    } else {
      if (!_deviceOrder.containsKey(device.serial)) {
        final nextIndex = _deviceOrder.values.isEmpty
            ? 0
            : (_deviceOrder.values.reduce((a, b) => a > b ? a : b) + 1);
        _deviceOrder[device.serial] = nextIndex;
      }
      _devices.add(device);
    }
    _ensureDeviceOrder();
    _sortDevicesByOrder();
    notifyListeners();
  }

  void removeDevice(int deviceId) {
    _devices.removeWhere((d) => d.deviceId == deviceId);
    _selectedDeviceIds.remove(deviceId);
    if (_focusedDeviceId == deviceId) {
      _focusedDeviceId = null;
    }
    notifyListeners();
  }

  void updateDevice(int deviceId, DeviceState Function(DeviceState) updater) {
    final index = _devices.indexWhere((d) => d.deviceId == deviceId);
    if (index >= 0) {
      _devices[index] = updater(_devices[index]);
      notifyListeners();
    }
  }

  Timer? _focusTimer;
  static const Duration _focusTimeout = Duration(seconds: 3);
  Map<String, int> _deviceOrder = {};  // serial → grid index

  Map<String, int> get deviceOrder => Map.unmodifiable(_deviceOrder);

  /// Focus a device: boost its FPS to 60, start 3s auto-unfocus timer.
  void setFocused(int? deviceId) {
    if (_focusedDeviceId == deviceId) {
      // Same device — just reset timer
      _resetFocusTimer();
      return;
    }

    // Unfocus previous device
    if (_focusedDeviceId != null) {
      _sendFpsProfile(_focusedDeviceId!, 'reduced');
    }

    _focusedDeviceId = deviceId;

    // Focus new device
    if (deviceId != null) {
      _sendFpsProfile(deviceId, 'full');
      _resetFocusTimer();
    } else {
      _focusTimer?.cancel();
      _focusTimer = null;
    }

    notifyListeners();
  }

  /// Called on every user interaction with the focused device to keep it alive.
  void touchFocus() {
    if (_focusedDeviceId != null) {
      _resetFocusTimer();
    }
  }

  void _resetFocusTimer() {
    _focusTimer?.cancel();
    _focusTimer = Timer(_focusTimeout, () {
      if (_focusedDeviceId != null) {
        _sendFpsProfile(_focusedDeviceId!, 'reduced');
        _focusedDeviceId = null;
        notifyListeners();
      }
    });
  }

  void _sendFpsProfile(int deviceId, String profile) {
    PlatformBridge.instance.setFpsProfile(deviceId, profile);
  }

  /// Swap two devices in the grid by their list indices.
  void swapDevices(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= _devices.length) return;
    if (toIndex < 0 || toIndex >= _devices.length) return;
    if (fromIndex == toIndex) return;
    final tmp = _devices[fromIndex];
    _devices[fromIndex] = _devices[toIndex];
    _devices[toIndex] = tmp;
    // Persist: update order map for all devices
    for (int i = 0; i < _devices.length; i++) {
      _deviceOrder[_devices[i].serial] = i;
    }
    notifyListeners();
  }

  /// Reorder device in grid. Persisted via deviceOrder map.
  void reorderDevice(String serial, int newIndex) {
    final fromIndex = _devices.indexWhere((d) => d.serial == serial);
    if (fromIndex < 0 || fromIndex == newIndex) return;
    
    final item = _devices.removeAt(fromIndex);
    _devices.insert(newIndex, item);
    
    // Persist: update order map for all devices
    for (int i = 0; i < _devices.length; i++) {
      _deviceOrder[_devices[i].serial] = i;
    }
    notifyListeners();
  }

  void setDeviceOrder(Map<String, int> order) {
    _deviceOrder = Map.from(order);
    _sortDevicesByOrder();
    notifyListeners();
  }

  void _sortDevicesByOrder() {
    _ensureDeviceOrder();
    _devices.sort((a, b) {
      final ia = _deviceOrder[a.serial] ?? 999;
      final ib = _deviceOrder[b.serial] ?? 999;
      if (ia != ib) return ia.compareTo(ib);
      return a.deviceId.compareTo(b.deviceId);
    });
  }

  void _ensureDeviceOrder() {
    var nextIndex = _deviceOrder.values.isEmpty
        ? 0
        : (_deviceOrder.values.reduce((a, b) => a > b ? a : b) + 1);
    for (final d in _devices) {
      if (_deviceOrder.containsKey(d.serial)) continue;
      _deviceOrder[d.serial] = nextIndex++;
    }
  }

  void toggleSelection(int deviceId) {
    if (_selectedDeviceIds.contains(deviceId)) {
      _selectedDeviceIds.remove(deviceId);
    } else {
      _selectedDeviceIds.add(deviceId);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedDeviceIds.clear();
    for (final device in _devices) {
      _selectedDeviceIds.add(device.deviceId);
    }
    notifyListeners();
  }

  void deselectAll() {
    _selectedDeviceIds.clear();
    notifyListeners();
  }

  void setGridConfig(GridConfig config) {
    if (_gridConfig == config) return;
    _gridConfig = config;
    notifyListeners();
  }

  void setServerHost(String host) {
    if (_serverHost == host) return;
    _serverHost = host;
    notifyListeners();
  }

  void setSettingsShortcutKey(String key) {
    if (_settingsShortcutKey == key) return;
    _settingsShortcutKey = key;
    notifyListeners();
  }

  void toggleDeviceListPanel() {
    _deviceListPanelOpen = !_deviceListPanelOpen;
    notifyListeners();
  }

  void setDeviceListPanelOpen(bool open) {
    _deviceListPanelOpen = open;
    notifyListeners();
  }

  void clearFocusAndPanels() {
    if (_focusedDeviceId != null) {
      _focusedDeviceId = null;
      notifyListeners();
    } else if (_deviceListPanelOpen) {
      _deviceListPanelOpen = false;
      notifyListeners();
    }
  }

  void setDeviceDetached(int deviceId, bool detached) {
    updateDevice(deviceId, (d) => d.copyWith(isDetached: detached));
  }

  void replaceAllDevices(List<DeviceState> newDevices) {
    _devices.clear();
    _devices.addAll(newDevices);
    _selectedDeviceIds.retainWhere(
      (id) => _devices.any((d) => d.deviceId == id),
    );
    if (_focusedDeviceId != null && !_devices.any((d) => d.deviceId == _focusedDeviceId)) {
      _focusedDeviceId = null;
    }
    notifyListeners();
  }
}
