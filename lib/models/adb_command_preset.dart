class AdbCommandPreset {
  final String id;
  final String label;
  final String command;
  final String icon;

  const AdbCommandPreset({
    required this.id,
    required this.label,
    required this.command,
    this.icon = 'terminal',
  });

  factory AdbCommandPreset.fromJson(Map<String, dynamic> json) {
    return AdbCommandPreset(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String).trim()
          : DateTime.now().microsecondsSinceEpoch.toString(),
      label: (json['label'] as String? ?? '').trim(),
      command: (json['command'] as String? ?? '').trim(),
      icon: (json['icon'] as String? ?? 'terminal').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'command': command,
    'icon': icon,
  };

  AdbCommandPreset copyWith({
    String? id,
    String? label,
    String? command,
    String? icon,
  }) {
    return AdbCommandPreset(
      id: id ?? this.id,
      label: label ?? this.label,
      command: command ?? this.command,
      icon: icon ?? this.icon,
    );
  }

  static const List<AdbCommandPreset> defaults = [
    AdbCommandPreset(
      id: 'home',
      label: '返回首頁',
      command: 'input keyevent 3',
      icon: 'home',
    ),
    AdbCommandPreset(
      id: 'back',
      label: '返回鍵',
      command: 'input keyevent 4',
      icon: 'arrow_back',
    ),
    AdbCommandPreset(
      id: 'recents',
      label: '最近應用',
      command: 'input keyevent 187',
      icon: 'apps',
    ),
    AdbCommandPreset(
      id: 'power',
      label: '電源鍵',
      command: 'input keyevent 26',
      icon: 'power_settings_new',
    ),
    AdbCommandPreset(
      id: 'screenshot',
      label: '截圖',
      command: 'screencap -p /sdcard/sc.png',
      icon: 'photo',
    ),
    AdbCommandPreset(
      id: 'open_settings',
      label: '打開設定',
      command: 'am start -a android.settings.SETTINGS',
      icon: 'settings',
    ),
    AdbCommandPreset(
      id: 'expand_notifications',
      label: '展開通知',
      command: 'cmd statusbar expand-notifications',
      icon: 'notifications',
    ),
  ];
}
