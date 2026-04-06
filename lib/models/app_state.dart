import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/platform_bridge.dart';

enum ServerConnectionState { disconnected, connecting, connected, reconnecting }

enum DevicePhase { offline, starting, online, locked, failed }

class ShortcutAction {
  final String label;
  final String icon;
  final String type; // 'app' or 'adb'
  final String command;

  const ShortcutAction({required this.label, this.icon = 'apps', this.type = 'app', required this.command});

  Map<String, dynamic> toJson() => {'label': label, 'icon': icon, 'type': type, 'command': command};

  factory ShortcutAction.fromJson(Map<String, dynamic> j) => ShortcutAction(
    label: j['label'] as String? ?? '',
    icon: j['icon'] as String? ?? 'apps',
    type: j['type'] as String? ?? 'app',
    command: j['command'] as String? ?? '',
  );

  static const List<ShortcutAction> defaults = [
    ShortcutAction(label: 'Chrome', icon: 'language', type: 'app', command: 'com.android.chrome'),
    ShortcutAction(label: 'WhatsApp', icon: 'chat', type: 'app', command: 'com.whatsapp'),
    ShortcutAction(label: 'Camera', icon: 'camera_alt', type: 'app', command: 'com.sec.android.app.camera'),
    ShortcutAction(label: 'Settings', icon: 'settings', type: 'app', command: 'com.android.settings'),
  ];

  static IconData iconData(String name) {
    const map = {
      'language': Icons.language, 'chat': Icons.chat, 'camera_alt': Icons.camera_alt,
      'settings': Icons.settings, 'apps': Icons.apps, 'phone': Icons.phone,
      'message': Icons.message, 'map': Icons.map, 'shopping_cart': Icons.shopping_cart,
      'music_note': Icons.music_note, 'video_call': Icons.video_call, 'terminal': Icons.terminal,
      'play_arrow': Icons.play_arrow, 'folder': Icons.folder, 'email': Icons.email,
      'search': Icons.search, 'home': Icons.home, 'star': Icons.star,
      'send': Icons.send, 'account_balance_wallet': Icons.account_balance_wallet,
      'qr_code': Icons.qr_code, 'payments': Icons.payments,
      'photo': Icons.photo, 'file_download': Icons.file_download,
      'notifications': Icons.notifications, 'bookmark': Icons.bookmark,
      'share': Icons.share, 'cloud': Icons.cloud,
    };
    return map[name] ?? Icons.apps;
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

  ServerConnectionState get connection => _connection;
  List<DeviceState> get devices => List.unmodifiable(_devices);
  /// Only devices not hidden AND streaming. Grid uses this.
  List<DeviceState> get visibleDevices =>
      _devices.where((d) => !_hiddenSerials.contains(d.serial) && d.textureId != null).toList();
  int? get focusedDeviceId => _focusedDeviceId;
  GridConfig get gridConfig => _gridConfig;
  Set<int> get selectedDeviceIds => Set.unmodifiable(_selectedDeviceIds);
  bool get deviceListPanelOpen => _deviceListPanelOpen;
  String get serverHost => _serverHost;
  String get settingsShortcutKey => _settingsShortcutKey;
  String? get activeSerial => _activeSerial;
  Set<String> get hiddenSerials => Set.unmodifiable(_hiddenSerials);
  Map<String, String> get deviceQuality => Map.unmodifiable(_deviceQuality);

  String getDeviceQuality(String serial) => _deviceQuality[serial] ?? 'hd';
  Map<String, String> get deviceAliases => Map.unmodifiable(_deviceAliases);
  List<ShortcutAction> get shortcuts => List.unmodifiable(_shortcuts);

  void setShortcuts(List<ShortcutAction> list) {
    _shortcuts = List.of(list);
    notifyListeners();
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

    if (state == ServerConnectionState.disconnected && previous != ServerConnectionState.disconnected) {
      _clearAllDevices();
    }

    notifyListeners();
  }

  void _clearAllDevices() {
    _devices.clear();
    _selectedDeviceIds.clear();
    _focusedDeviceId = null;
  }

  void addDevice(DeviceState device) {
    final existing = _devices.indexWhere((d) => d.deviceId == device.deviceId);
    if (existing >= 0) {
      _devices[existing] = device;
    } else {
      _devices.add(device);
    }
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
    swapDevices(fromIndex, newIndex);
  }

  void setDeviceOrder(Map<String, int> order) {
    _deviceOrder = Map.from(order);
    _sortDevicesByOrder();
    notifyListeners();
  }

  void _sortDevicesByOrder() {
    _devices.sort((a, b) {
      final ia = _deviceOrder[a.serial] ?? 999;
      final ib = _deviceOrder[b.serial] ?? 999;
      if (ia != ib) return ia.compareTo(ib);
      return a.deviceId.compareTo(b.deviceId);
    });
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
