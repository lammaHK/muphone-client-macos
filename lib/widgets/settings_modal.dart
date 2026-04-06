import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/platform_bridge.dart';
import '../theme/muphone_theme.dart';

class SettingsModal extends StatelessWidget {
  const SettingsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MUPhoneColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: MUPhoneColors.border),
      ),
      child: SizedBox(
        width: 540,
        height: 600,
        child: Consumer<AppState>(
          builder: (context, state, _) {
            return Column(
              children: [
                _Header(state: state, onClose: () => Navigator.of(context).pop()),
                _StatusBar(state: state),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                    children: [
                      _ServerSection(state: state),
                      const SizedBox(height: 22),
                      _GridSection(state: state),
                      const SizedBox(height: 22),
                      _ShortcutSection(state: state),
                      const SizedBox(height: 22),
                      _DeviceListSection(state: state),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Header ───

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onClose});
  final AppState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: MUPhoneColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MUPhoneColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.settings, size: 16, color: MUPhoneColors.primary),
          ),
          const SizedBox(width: 12),
          const Text('設定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: MUPhoneColors.textPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: MUPhoneColors.background,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard, size: 11, color: MUPhoneColors.textDisabled.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text('=', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: MUPhoneColors.textDisabled.withValues(alpha: 0.6))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 30, height: 30,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onClose,
                hoverColor: MUPhoneColors.statusFailed.withValues(alpha: 0.1),
                child: const Icon(Icons.close, size: 15, color: MUPhoneColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Bar (always visible at top) ───

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (state.connection) {
      ServerConnectionState.connected    => (MUPhoneColors.statusOnline, '已連接', Icons.check_circle),
      ServerConnectionState.connecting   => (MUPhoneColors.statusLockedOther, '連接中...', Icons.sync),
      ServerConnectionState.reconnecting => (MUPhoneColors.statusLockedOther, '重連中...', Icons.sync),
      ServerConnectionState.disconnected => (MUPhoneColors.statusFailed, '離線', Icons.cancel),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.15)),
          bottom: BorderSide(color: color.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          if (state.connection == ServerConnectionState.connected) ...[
            Text('  —  ${state.serverHost}', style: const TextStyle(fontSize: 11, color: MUPhoneColors.textSecondary)),
          ],
          const Spacer(),
          if (state.connection == ServerConnectionState.connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MUPhoneColors.statusOnline.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${state.onlineDeviceCount} 在線 / ${state.totalDeviceCount} 裝置',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: MUPhoneColors.statusOnline)),
            ),
        ],
      ),
    );
  }
}

// ─── Section Container ───

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: MUPhoneColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: MUPhoneColors.textSecondary, letterSpacing: 0.5)),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

class _SectionBox extends StatelessWidget {
  const _SectionBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MUPhoneColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MUPhoneColors.border.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}

// ─── Server Section ───

class _ServerSection extends StatefulWidget {
  const _ServerSection({required this.state});
  final AppState state;

  @override
  State<_ServerSection> createState() => _ServerSectionState();
}

class _ServerSectionState extends State<_ServerSection> {
  late TextEditingController _ipController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.state.serverHost);
    _portController = TextEditingController(text: '28200');
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _handleConnectButton() async {
    final conn = widget.state.connection;

    if (conn == ServerConnectionState.reconnecting ||
        conn == ServerConnectionState.connecting ||
        conn == ServerConnectionState.connected) {
      try { await PlatformBridge.instance.disconnect(); } catch (_) {}
      widget.state.setConnection(ServerConnectionState.disconnected);
      if (conn == ServerConnectionState.connected) return;
      return;
    }

    final host = _ipController.text.trim();
    if (host.isEmpty) return;
    final port = int.tryParse(_portController.text.trim()) ?? 28200;
    widget.state.setServerHost(host);

    widget.state.setConnection(ServerConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await PlatformBridge.instance.connect(host, videoPort: port, controlPort: port + 1);
    } catch (e) {
      debugPrint('[Settings] Connect error: $e');
      widget.state.setConnection(ServerConnectionState.disconnected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conn = widget.state.connection;
    final isReconnecting = conn == ServerConnectionState.reconnecting || conn == ServerConnectionState.connecting;
    final isConnected = conn == ServerConnectionState.connected;

    final (btnLabel, btnIcon, btnBg, btnFg) = isReconnecting
        ? ('停止重連', Icons.stop, MUPhoneColors.statusFailed, MUPhoneColors.textPrimary)
        : isConnected
            ? ('中斷連接', Icons.link_off, MUPhoneColors.statusFailed.withValues(alpha: 0.8), MUPhoneColors.textPrimary)
            : ('連接伺服器', Icons.power_settings_new, MUPhoneColors.primary, MUPhoneColors.background);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(icon: Icons.dns_outlined, title: '伺服器連線'),
        const SizedBox(height: 10),
        _SectionBox(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(flex: 5, child: _FieldRow(label: '位址', child: _buildInput(_ipController, '127.0.0.1'))),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _FieldRow(label: '埠', child: _buildInput(_portController, '28200'))),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: ElevatedButton.icon(
                  onPressed: _handleConnectButton,
                  icon: Icon(btnIcon, size: 15),
                  label: Text(btnLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnBg,
                    foregroundColor: btnFg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, {double? width}) {
    return SizedBox(
      height: 32,
      width: width,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13, color: MUPhoneColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: MUPhoneColors.textDisabled.withValues(alpha: 0.4)),
          filled: true,
          fillColor: MUPhoneColors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: MUPhoneColors.border, width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: MUPhoneColors.border, width: 0.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: MUPhoneColors.primary, width: 1)),
          isDense: true,
        ),
        onSubmitted: (_) => _handleConnectButton(),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

// ─── Grid Section ───

class _GridSection extends StatelessWidget {
  const _GridSection({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final grid = state.gridConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.grid_view_rounded, title: '網格佈局',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: MUPhoneColors.background, borderRadius: BorderRadius.circular(10)),
            child: Text('${grid.columns}×${grid.rows}  ${grid.totalSlots}格',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: MUPhoneColors.textDisabled)),
          )),
        const SizedBox(height: 10),
        _SectionBox(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _NumberStepper(label: '列數', value: grid.columns, min: 1, max: 8,
                    onChanged: (v) => state.setGridConfig(grid.copyWith(columns: v)))),
                  const SizedBox(width: 20),
                  Expanded(child: _NumberStepper(label: '行數', value: grid.rows, min: 1, max: 6,
                    onChanged: (v) => state.setGridConfig(grid.copyWith(rows: v)))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Text('快速選擇', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                  Spacer(),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final p in [('3×2', 3, 2), ('4×3', 4, 3), ('5×2', 5, 2), ('6×2', 6, 2), ('4×4', 4, 4), ('5×4', 5, 4)])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _PresetChip(label: p.$1, cols: p.$2, rows: p.$3,
                        active: grid.columns == p.$2 && grid.rows == p.$3,
                        onTap: () => state.setGridConfig(GridConfig(columns: p.$2, rows: p.$3))),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('裝置分配（點擊格子選擇裝置）',
                style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
              const SizedBox(height: 6),
              _GridAssignment(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

class _GridAssignment extends StatelessWidget {
  const _GridAssignment({required this.state});
  final AppState state;

  void _showSlotPicker(BuildContext context, int slotIndex,
      List<DeviceState> devices, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MUPhoneColors.card,
        title: Text('選擇裝置 #${slotIndex + 1}',
          style: const TextStyle(fontSize: 13, color: MUPhoneColors.textPrimary)),
        content: SizedBox(
          width: 250, height: 300,
          child: ListView.builder(
            itemCount: devices.length,
            itemBuilder: (_, i) {
              final d = devices[i];
              final isHidden = state.isDeviceHidden(d.serial);
              return ListTile(
                dense: true, visualDensity: VisualDensity.compact,
                leading: Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: isHidden ? MUPhoneColors.statusFailed : MUPhoneColors.statusOnline,
                    shape: BoxShape.circle)),
                title: Text(d.displayName,
                  style: const TextStyle(fontSize: 11, color: MUPhoneColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
                subtitle: Text(d.serial,
                  style: const TextStyle(fontSize: 8, color: MUPhoneColors.textDisabled)),
                onTap: () {
                  state.reorderDevice(d.serial, slotIndex);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grid = state.gridConfig;
    final devices = state.devices
        .where((d) => !state.isDeviceHidden(d.serial))
        .toList();
    final cols = grid.columns;
    final rows = grid.rows;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: MUPhoneColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MUPhoneColors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: List.generate(rows, (row) {
          return Padding(
            padding: EdgeInsets.only(bottom: row < rows - 1 ? 4 : 0),
            child: Row(
              children: List.generate(cols, (col) {
                final index = row * cols + col;
                final dev = index < devices.length ? devices[index] : null;
                final isHidden = dev != null && state.isDeviceHidden(dev.serial);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: col < cols - 1 ? 4 : 0),
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: isHidden
                            ? MUPhoneColors.statusFailed.withValues(alpha: 0.08)
                            : MUPhoneColors.card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: dev != null
                              ? (isHidden ? MUPhoneColors.statusFailed.withValues(alpha: 0.3)
                                          : MUPhoneColors.statusOnline.withValues(alpha: 0.3))
                              : MUPhoneColors.border.withValues(alpha: 0.2),
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _showSlotPicker(context, index, devices, state),
                        borderRadius: BorderRadius.circular(4),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              dev != null ? dev.displayName : '#${index + 1}',
                              style: TextStyle(
                                fontSize: 9,
                                color: dev != null
                                    ? MUPhoneColors.textPrimary
                                    : MUPhoneColors.textDisabled.withValues(alpha: 0.5),
                              ),
                              overflow: TextOverflow.ellipsis, maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.cols, required this.rows,
    required this.active, required this.onTap});
  final String label;
  final int cols, rows;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? MUPhoneColors.primary.withValues(alpha: 0.15) : MUPhoneColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
            color: active ? MUPhoneColors.primary : MUPhoneColors.textSecondary)),
        ),
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});
  final String label;
  final int value;
  final int min, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: MUPhoneColors.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MUPhoneColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              _StepBtn(icon: Icons.remove, enabled: value > min, onPressed: () => onChanged(value - 1)),
              Expanded(child: Center(child: Text('$value',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: MUPhoneColors.textPrimary)))),
              _StepBtn(icon: Icons.add, enabled: value < max, onPressed: () => onChanged(value + 1)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.enabled, required this.onPressed});
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: enabled ? onPressed : null,
        child: SizedBox(width: 36, height: 36,
          child: Icon(icon, size: 14, color: enabled ? MUPhoneColors.textSecondary : MUPhoneColors.textDisabled)),
      ),
    );
  }
}

// ─── Shortcut Section ───

class _ShortcutSection extends StatefulWidget {
  const _ShortcutSection({required this.state});
  final AppState state;

  @override
  State<_ShortcutSection> createState() => _ShortcutSectionState();
}

class _ShortcutSectionState extends State<_ShortcutSection> {
  static const _iconOptions = [
    'language', 'chat', 'camera_alt', 'settings', 'apps', 'phone',
    'message', 'map', 'shopping_cart', 'music_note', 'video_call',
    'terminal', 'play_arrow', 'folder', 'email', 'search', 'home', 'star',
    'send', 'account_balance_wallet', 'qr_code', 'payments',
    'photo', 'file_download', 'notifications', 'bookmark', 'share', 'cloud',
  ];

  void _addShortcut() {
    _showEditor(context, null, null);
  }

  void _editShortcut(int index) {
    _showEditor(context, index, widget.state.shortcuts[index]);
  }

  void _deleteShortcut(int index) {
    final list = List<ShortcutAction>.from(widget.state.shortcuts);
    list.removeAt(index);
    widget.state.setShortcuts(list);
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final list = List<ShortcutAction>.from(widget.state.shortcuts);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    widget.state.setShortcuts(list);
  }

  void _showEditor(BuildContext context, int? index, ShortcutAction? existing) {
    final labelCtl = TextEditingController(text: existing?.label ?? '');
    final cmdCtl = TextEditingController(text: existing?.command ?? '');
    String selectedType = existing?.type ?? 'app';
    String selectedIcon = existing?.icon ?? 'apps';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setDialogState) {
        return AlertDialog(
          backgroundColor: MUPhoneColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: MUPhoneColors.border)),
          title: Text(index != null ? '編輯快捷鍵' : '新增快捷鍵',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MUPhoneColors.textPrimary)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('類型', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                const SizedBox(height: 4),
                Row(children: [
                  _TypeChip(label: '應用程式', value: 'app', selected: selectedType == 'app',
                    onTap: () => setDialogState(() => selectedType = 'app')),
                  const SizedBox(width: 6),
                  _TypeChip(label: 'ADB 指令', value: 'adb', selected: selectedType == 'adb',
                    onTap: () => setDialogState(() => selectedType = 'adb')),
                ]),
                const SizedBox(height: 12),
                const Text('名稱', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                const SizedBox(height: 4),
                _dialogInput(labelCtl, selectedType == 'app' ? 'Chrome' : 'Screenshot'),
                const SizedBox(height: 12),
                Text(selectedType == 'app' ? '套件名稱' : 'Shell 指令',
                  style: const TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                const SizedBox(height: 4),
                _dialogInput(cmdCtl, selectedType == 'app' ? 'com.android.chrome' : 'screencap -p /sdcard/sc.png'),
                const SizedBox(height: 12),
                const Text('圖標', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4, runSpacing: 4,
                  children: _iconOptions.map((name) {
                    final active = selectedIcon == name;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = name),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: active ? MUPhoneColors.primary.withValues(alpha: 0.2) : MUPhoneColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: active ? MUPhoneColors.primary : MUPhoneColors.border.withValues(alpha: 0.3)),
                        ),
                        child: Icon(ShortcutAction.iconData(name), size: 14,
                          color: active ? MUPhoneColors.primary : MUPhoneColors.textSecondary),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(onPressed: () {
              final label = labelCtl.text.trim();
              final cmd = cmdCtl.text.trim();
              if (label.isEmpty || cmd.isEmpty) return;
              final action = ShortcutAction(label: label, icon: selectedIcon, type: selectedType, command: cmd);
              final list = List<ShortcutAction>.from(widget.state.shortcuts);
              if (index != null) {
                list[index] = action;
              } else {
                list.add(action);
              }
              widget.state.setShortcuts(list);
              Navigator.pop(ctx);
            }, child: const Text('確認')),
          ],
        );
      }),
    );
  }

  Widget _dialogInput(TextEditingController ctrl, String hint) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 12, color: MUPhoneColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: MUPhoneColors.textDisabled.withValues(alpha: 0.4)),
          filled: true, fillColor: MUPhoneColors.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: MUPhoneColors.border, width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: MUPhoneColors.border, width: 0.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: MUPhoneColors.primary, width: 1)),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = widget.state.shortcuts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.bolt, title: '快捷鍵',
          trailing: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _addShortcut,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 12, color: MUPhoneColors.primary),
                  SizedBox(width: 2),
                  Text('新增', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: MUPhoneColors.primary)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SectionBox(
          child: shortcuts.isEmpty
              ? const Center(
                  heightFactor: 2,
                  child: Text('尚未設定快捷鍵', style: TextStyle(fontSize: 11, color: MUPhoneColors.textDisabled)))
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: shortcuts.length,
                  onReorder: _reorder,
                  itemBuilder: (ctx, i) {
                    final s = shortcuts[i];
                    return _ShortcutRow(
                      key: ValueKey('shortcut_$i'),
                      index: i,
                      action: s,
                      onEdit: () => _editShortcut(i),
                      onDelete: () => _deleteShortcut(i),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.value, required this.selected, required this.onTap});
  final String label, value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? MUPhoneColors.primary.withValues(alpha: 0.15) : MUPhoneColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? MUPhoneColors.primary.withValues(alpha: 0.4) : MUPhoneColors.border.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
          color: selected ? MUPhoneColors.primary : MUPhoneColors.textSecondary)),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({super.key, required this.index, required this.action, required this.onEdit, required this.onDelete});
  final int index;
  final ShortcutAction action;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_indicator, size: 14, color: MUPhoneColors.textDisabled),
          ),
          const SizedBox(width: 6),
          Icon(ShortcutAction.iconData(action.icon), size: 14, color: MUPhoneColors.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(action.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: MUPhoneColors.textPrimary),
              overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: action.type == 'app' ? MUPhoneColors.primary.withValues(alpha: 0.1) : MUPhoneColors.statusLockedOther.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(action.type == 'app' ? 'APP' : 'ADB',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600,
                color: action.type == 'app' ? MUPhoneColors.primary : MUPhoneColors.statusLockedOther)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(action.command,
            style: const TextStyle(fontSize: 9, color: MUPhoneColors.textDisabled),
            overflow: TextOverflow.ellipsis)),
          SizedBox(width: 22, height: 18, child: IconButton(
            padding: EdgeInsets.zero, iconSize: 12,
            icon: const Icon(Icons.edit_outlined, color: MUPhoneColors.textDisabled),
            onPressed: onEdit)),
          SizedBox(width: 22, height: 18, child: IconButton(
            padding: EdgeInsets.zero, iconSize: 12,
            icon: const Icon(Icons.delete_outline, color: MUPhoneColors.statusFailed),
            onPressed: onDelete)),
        ],
      ),
    );
  }
}

// ─── Device List Section ───

class _DeviceListSection extends StatelessWidget {
  const _DeviceListSection({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.devices, title: '裝置列表',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: MUPhoneColors.background, borderRadius: BorderRadius.circular(10)),
            child: Text('${state.totalDeviceCount} 台',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: MUPhoneColors.textDisabled)),
          )),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: MUPhoneColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MUPhoneColors.border.withValues(alpha: 0.5)),
          ),
          child: state.devices.isEmpty
              ? const Center(heightFactor: 3,
                  child: Text('暫無裝置連接', style: TextStyle(fontSize: 12, color: MUPhoneColors.textDisabled)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: state.devices.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: 14, endIndent: 14,
                    color: MUPhoneColors.border.withValues(alpha: 0.3)),
                  itemBuilder: (_, i) {
                    final d = state.devices[i];
                    return _DeviceRow(
                      key: ValueKey('${d.deviceId}_${d.textureId}'),
                      device: d,
                      state: state,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({super.key, required this.device, required this.state});
  final DeviceState device;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final dev = device;
    final isStreaming = dev.textureId != null;
    final (color, label) = switch (dev.phase) {
      DevicePhase.online  => (MUPhoneColors.statusOnline, '在線'),
      DevicePhase.locked  => (MUPhoneColors.statusLockedMine, '鎖定'),
      DevicePhase.starting => (MUPhoneColors.statusLockedOther, '啟動中'),
      DevicePhase.failed  => (MUPhoneColors.statusFailed, '失敗'),
      DevicePhase.offline => (MUPhoneColors.statusOffline, '離線'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          Container(width: 7, height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 3)])),
          const SizedBox(width: 8),
          // Name (tap to edit)
          GestureDetector(
            onDoubleTap: () => _editAlias(context),
            child: SizedBox(
              width: 100,
              child: Text(dev.displayName,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: MUPhoneColors.textPrimary),
                overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
            child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w500, color: color)),
          ),
          const SizedBox(width: 6),
          // Quality toggle chip
          _QualityChip(
            quality: state.getDeviceQuality(dev.serial),
            onChanged: (val) {
              state.setDeviceQuality(dev.serial, val);
              state.updateDevice(dev.deviceId, (d) => d.copyWith(isQualitySwitching: true));
              PlatformBridge.instance.setFpsProfile(dev.deviceId, val);
              // Fallback: clear loading after 10s even if no ack
              Future.delayed(const Duration(seconds: 10), () {
                final d = state.getDevice(dev.deviceId);
                if (d != null && d.isQualitySwitching) {
                  state.updateDevice(dev.deviceId, (d) => d.copyWith(isQualitySwitching: false));
                }
              });
            },
          ),
          const Spacer(),
          // Open in separate window
          SizedBox(
            width: 24, height: 20,
            child: IconButton(
              padding: EdgeInsets.zero, iconSize: 14,
              icon: const Icon(Icons.open_in_new, color: MUPhoneColors.textDisabled),
              onPressed: () => _openDeviceWindow(context, dev),
            ),
          ),
          const SizedBox(width: 4),
          // Toggle: ON = show+stream, OFF = hide+disconnect
          SizedBox(
            width: 32, height: 18,
            child: Transform.scale(
              scale: 0.65,
              child: Switch(
              value: !state.isDeviceHidden(dev.serial),
              activeColor: MUPhoneColors.statusOnline,
              onChanged: (val) {
                if (val) {
                  // Show: unhide + subscribe
                  state.showDevice(dev.serial);
                  if (dev.phase == DevicePhase.online || dev.phase == DevicePhase.locked) {
                    PlatformBridge.instance.subscribeDevice(
                      dev.deviceId, width: dev.width, height: dev.height).then((tid) {
                      if (tid != null) state.updateDevice(dev.deviceId, (d) => d.copyWith(textureId: tid));
                    });
                  }
                } else {
                  // Hide: set hidden + unsubscribe + clear textureId
                  state.hideDevice(dev.serial);
                  state.updateDevice(dev.deviceId, (d) => d.copyWith(textureId: null));
                  PlatformBridge.instance.unsubscribeDevice(dev.deviceId);
                }
              },
            ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDeviceWindow(BuildContext context, DeviceState dev) async {
    try {
      final ok = await PlatformBridge.instance.detachDevice(dev.deviceId);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法開啟獨立視窗'), duration: Duration(seconds: 2)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('開啟失敗: $e'), duration: const Duration(seconds: 2)));
      }
    }
  }

  void _editAlias(BuildContext context) {
    final ctl = TextEditingController(text: device.alias.isNotEmpty ? device.alias : device.serial);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MUPhoneColors.card,
        title: const Text('裝置名稱', style: TextStyle(fontSize: 14, color: MUPhoneColors.textPrimary)),
        content: TextField(
          controller: ctl, autofocus: true,
          style: const TextStyle(fontSize: 13, color: MUPhoneColors.textPrimary),
          decoration: InputDecoration(
            hintText: device.serial,
            hintStyle: const TextStyle(color: MUPhoneColors.textDisabled),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () {
            final alias = ctl.text.trim();
            state.setDeviceAlias(device.serial, alias);
            Navigator.pop(ctx);
          }, child: const Text('確認')),
        ],
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.quality, required this.onChanged});
  final String quality;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: MUPhoneColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MUPhoneColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip('HD', 'hd', quality == 'hd'),
          _chip('FHD', 'fhd', quality == 'fhd'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, bool active) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? MUPhoneColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
          fontSize: 8, fontWeight: FontWeight.w600,
          color: active ? MUPhoneColors.primary : MUPhoneColors.textDisabled,
        )),
      ),
    );
  }
}
