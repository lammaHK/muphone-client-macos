import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/adb_command_preset.dart';
import '../services/installed_apps_service.dart';
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
                      _WindowBehaviorSection(state: state),
                      const SizedBox(height: 22),
                      _CustomControlsSection(state: state),
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
          Material(
            color: MUPhoneColors.background,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _showShortcutKeyCaptureDialog(context, state),
              hoverColor: MUPhoneColors.hover,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard, size: 11, color: MUPhoneColors.textDisabled.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(state.settingsShortcutKey, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: MUPhoneColors.textDisabled.withValues(alpha: 0.6))),
                  ],
                ),
              ),
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

  void _showShortcutKeyCaptureDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => _KeyCaptureDialog(
        currentKey: state.settingsShortcutKey,
        onKeySelected: (key) => state.setSettingsShortcutKey(key),
      ),
    );
  }
}

class _KeyCaptureDialog extends StatefulWidget {
  const _KeyCaptureDialog({required this.currentKey, required this.onKeySelected});
  final String currentKey;
  final ValueChanged<String> onKeySelected;

  @override
  State<_KeyCaptureDialog> createState() => _KeyCaptureDialogState();
}

class _KeyCaptureDialogState extends State<_KeyCaptureDialog> {
  String? _captured;
  final _focusNode = FocusNode();

  @override
  void dispose() { _focusNode.dispose(); super.dispose(); }

  String? _keyLabel(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.enter) return null;
    
    // Check specific allowed keys first
    final allowed = {
      LogicalKeyboardKey.equal: '=', LogicalKeyboardKey.minus: '-',
      LogicalKeyboardKey.backquote: '`', LogicalKeyboardKey.bracketLeft: '[',
      LogicalKeyboardKey.bracketRight: ']', LogicalKeyboardKey.semicolon: ';',
      LogicalKeyboardKey.slash: '/', LogicalKeyboardKey.period: '.',
      LogicalKeyboardKey.comma: ',', LogicalKeyboardKey.backslash: '\\',
      LogicalKeyboardKey.f1: 'F1', LogicalKeyboardKey.f2: 'F2',
      LogicalKeyboardKey.f3: 'F3', LogicalKeyboardKey.f4: 'F4',
      LogicalKeyboardKey.f5: 'F5', LogicalKeyboardKey.f6: 'F6',
      LogicalKeyboardKey.f7: 'F7', LogicalKeyboardKey.f8: 'F8',
      LogicalKeyboardKey.f9: 'F9', LogicalKeyboardKey.f10: 'F10',
      LogicalKeyboardKey.f11: 'F11', LogicalKeyboardKey.f12: 'F12',
      LogicalKeyboardKey.tab: 'Tab', LogicalKeyboardKey.space: 'Space',
      LogicalKeyboardKey.backspace: 'Backspace',
    };
    if (allowed.containsKey(key)) return allowed[key];

    // Check a-z and 0-9
    final char = event.character;
    if (char != null && char.length == 1) {
      final code = char.toLowerCase().codeUnitAt(0);
      if ((code >= 97 && code <= 122) || (code >= 48 && code <= 57)) {
        return char.toUpperCase();
      }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MUPhoneColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: MUPhoneColors.border)),
      title: const Text('設定快捷鍵', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MUPhoneColors.textPrimary)),
      content: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          final label = _keyLabel(event);
          if (label != null) setState(() => _captured = label);
        },
        child: Container(
          width: 200, height: 80,
          decoration: BoxDecoration(
            color: MUPhoneColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _captured != null ? MUPhoneColors.primary : MUPhoneColors.border),
          ),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_captured ?? widget.currentKey,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                color: _captured != null ? MUPhoneColors.primary : MUPhoneColors.textDisabled)),
            const SizedBox(height: 4),
            Text(_captured != null ? '已捕獲按鍵' : '按下新的快捷鍵...',
              style: const TextStyle(fontSize: 10, color: MUPhoneColors.textSecondary)),
          ])),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(onPressed: _captured != null ? () {
          widget.onKeySelected(_captured!);
          Navigator.pop(context);
        } : null, child: const Text('確認')),
      ],
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
      final host = _ipController.text.trim();
      if (host.isNotEmpty) widget.state.setServerHost(host);
      // Set disconnected first (triggers device list clear + UI refresh in-place)
      widget.state.setConnection(ServerConnectionState.disconnected);
      // Then disconnect in background (non-blocking)
      Future(() async {
        try { await PlatformBridge.instance.disconnect(); } catch (_) {}
      });
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
                Widget cellContent = Container(
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
                );

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: col < cols - 1 ? 4 : 0),
                    child: DragTarget<String>(
                      onAcceptWithDetails: (details) {
                        final draggedSerial = details.data;
                        state.reorderDevice(draggedSerial, index);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHovered = candidateData.isNotEmpty;
                        
                        Widget targetCell = isHovered 
                            ? Opacity(opacity: 0.5, child: cellContent) 
                            : cellContent;

                        if (dev != null) {
                          return Draggable<String>(
                            data: dev.serial,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Opacity(
                                opacity: 0.8,
                                child: SizedBox(
                                  width: 80,
                                  child: cellContent,
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(opacity: 0.3, child: cellContent),
                            child: targetCell,
                          );
                        }
                        return targetCell;
                      },
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
  final InstalledAppsService _installedAppsService = InstalledAppsService();
  static const String _kIconDocsUrl =
      'https://api.flutter.dev/flutter/material/Icons-class.html';

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
    final cmdCtl = TextEditingController(text: existing?.commandForLegacy ?? '');
    String selectedType = ShortcutAction.isSupportedType(existing?.actionType ?? '')
        ? existing!.actionType
        : ShortcutAction.appLaunch;
    String selectedIcon = existing?.icon ?? 'apps';
    final iconKeyCtl = TextEditingController(text: selectedIcon);
    String? selectedSerial = existing?.deviceSerial;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setDialogState) {
        return AlertDialog(
          backgroundColor: MUPhoneColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: MUPhoneColors.border)),
          title: Text(index != null ? '編輯快捷鍵' : '新增快捷鍵',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MUPhoneColors.textPrimary)),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('類型', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _TypeChip(label: '開啟 App', value: ShortcutAction.appLaunch, selected: selectedType == ShortcutAction.appLaunch,
                        onTap: () => setDialogState(() => selectedType = ShortcutAction.appLaunch)),
                      _TypeChip(label: 'ADB 指令', value: ShortcutAction.adbCommand, selected: selectedType == ShortcutAction.adbCommand,
                        onTap: () => setDialogState(() => selectedType = ShortcutAction.adbCommand)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('目標裝置', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => Container(
                          decoration: const BoxDecoration(
                            color: MUPhoneColors.card,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 8, bottom: 16),
                                width: 40, height: 4,
                                decoration: BoxDecoration(
                                  color: MUPhoneColors.border,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const Text('選擇目標裝置', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MUPhoneColors.textPrimary)),
                              const SizedBox(height: 16),
                              ListTile(
                                leading: const Icon(Icons.language, color: MUPhoneColors.textSecondary),
                                title: const Text('全域 (所有裝置)', style: TextStyle(color: MUPhoneColors.textPrimary)),
                                trailing: selectedSerial == null ? const Icon(Icons.check, color: MUPhoneColors.primary) : null,
                                onTap: () {
                                  setDialogState(() => selectedSerial = null);
                                  Navigator.pop(ctx);
                                },
                              ),
                              const Divider(height: 1, color: MUPhoneColors.border),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: widget.state.devices.length,
                                  itemBuilder: (ctx, i) {
                                    final d = widget.state.devices[i];
                                    final name = d.alias.isNotEmpty ? d.alias : d.serial;
                                    final isSelected = selectedSerial == d.serial;
                                    return ListTile(
                                      leading: const Icon(Icons.phone_android, color: MUPhoneColors.primary),
                                      title: Text(name, style: const TextStyle(color: MUPhoneColors.textPrimary)),
                                      subtitle: Text(d.serial, style: const TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                                      trailing: isSelected ? const Icon(Icons.check, color: MUPhoneColors.primary) : null,
                                      onTap: () {
                                        setDialogState(() => selectedSerial = d.serial);
                                        Navigator.pop(ctx);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: MUPhoneColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: MUPhoneColors.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Icon(selectedSerial == null ? Icons.language : Icons.phone_android, size: 14, color: MUPhoneColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedSerial == null ? '全域 (所有裝置)' : (() {
                                final d = widget.state.devices.where((d) => d.serial == selectedSerial).firstOrNull;
                                return d != null ? (d.alias.isNotEmpty ? '${d.alias} (${d.serial})' : d.serial) : selectedSerial!;
                              })(),
                              style: const TextStyle(fontSize: 12, color: MUPhoneColors.textPrimary),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 16, color: MUPhoneColors.textDisabled),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('名稱', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                  const SizedBox(height: 4),
                  _dialogInput(labelCtl, selectedType == ShortcutAction.appLaunch ? 'Chrome' : 'Screenshot'),
                  const SizedBox(height: 12),
                  if (selectedType == ShortcutAction.appLaunch || selectedType == ShortcutAction.adbCommand) ...[
                    Row(
                      children: [
                        Text(
                          selectedType == ShortcutAction.appLaunch ? '套件名稱' : 'Shell 指令',
                          style: const TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled),
                        ),
                        const Spacer(),
                        if (selectedType == ShortcutAction.appLaunch)
                          InkWell(
                            onTap: () => _showAppSelector(context, selectedSerial, cmdCtl, labelCtl),
                            child: const Text('從裝置讀取...', style: TextStyle(fontSize: 10, color: MUPhoneColors.primary)),
                          )
                        else
                          InkWell(
                            onTap: () => _showAdbCommandSelector(context, cmdCtl, labelCtl),
                            child: const Text('常用指令...', style: TextStyle(fontSize: 10, color: MUPhoneColors.primary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _dialogInput(
                      cmdCtl,
                      selectedType == ShortcutAction.appLaunch
                          ? 'com.android.chrome'
                          : 'screencap -p /sdcard/sc.png',
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('圖標', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                  const SizedBox(height: 6),
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MUPhoneColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: MUPhoneColors.border, width: 0.5),
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                      ),
                      itemCount: ShortcutAction.iconKeys.length,
                      itemBuilder: (ctx, i) {
                        final name = ShortcutAction.iconKeys[i];
                        final active = selectedIcon == name;
                        return GestureDetector(
                          onTap: () => setDialogState(() {
                            selectedIcon = name;
                            iconKeyCtl.text = name;
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                              color: active ? MUPhoneColors.primary.withValues(alpha: 0.2) : MUPhoneColors.card,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: active ? MUPhoneColors.primary : MUPhoneColors.border.withValues(alpha: 0.3)),
                            ),
                            child: Icon(ShortcutAction.iconData(name), size: 16,
                              color: active ? MUPhoneColors.primary : MUPhoneColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('自定義 icon key', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                      const Spacer(),
                      InkWell(
                        onTap: () => _openIconDocs(context),
                        child: const Text(
                          '查看 Icons 文檔',
                          style: TextStyle(fontSize: 10, color: MUPhoneColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 32,
                    child: TextField(
                      controller: iconKeyCtl,
                      style: const TextStyle(fontSize: 11, color: MUPhoneColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '例如：terminal',
                        hintStyle: TextStyle(color: MUPhoneColors.textDisabled.withValues(alpha: 0.45)),
                        filled: true,
                        fillColor: MUPhoneColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: const BorderSide(color: MUPhoneColors.border, width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: const BorderSide(color: MUPhoneColors.border, width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: const BorderSide(color: MUPhoneColors.primary, width: 1),
                        ),
                        isDense: true,
                      ),
                      onChanged: (v) => setDialogState(() => selectedIcon = v.trim().isEmpty ? 'apps' : v.trim()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(onPressed: () {
              final label = labelCtl.text.trim();
              final cmd = cmdCtl.text.trim();
              final requiresCommand = selectedType == ShortcutAction.appLaunch ||
                  selectedType == ShortcutAction.adbCommand;
              if (label.isEmpty || (requiresCommand && cmd.isEmpty)) return;
              final iconKey = iconKeyCtl.text.trim();
              final action = ShortcutAction(
                label: label,
                icon: iconKey.isEmpty ? selectedIcon : iconKey,
                actionType: selectedType,
                command: requiresCommand ? cmd : '',
                deviceSerial: selectedSerial,
              );
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

  Future<void> _showAppSelector(
    BuildContext context,
    String? serial,
    TextEditingController cmdCtl,
    TextEditingController labelCtl,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: SizedBox(
            width: 280,
            child: _LoadingCard(text: '正在讀取應用程式列表...'),
          ),
        ),
      ),
    );

    late final InstalledAppsResult result;
    try {
      result = await _installedAppsService.loadIntersection(
        devices: widget.state.devices,
        targetSerial: serial,
      );
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!context.mounted) return;
    if (result.apps.isEmpty) {
      final reason = result.errors.isNotEmpty ? result.errors.first : '沒有可用的應用程式';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: MUPhoneColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: MUPhoneColors.border),
        ),
        child: Container(
          width: 360,
          height: 500,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('選擇應用程式', style: TextStyle(color: MUPhoneColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('共 ${result.apps.length} 個交集應用程式', style: const TextStyle(color: MUPhoneColors.textDisabled, fontSize: 11)),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: MUPhoneColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MUPhoneColors.border, width: 0.5),
                  ),
                  child: ListView.separated(
                    itemCount: result.apps.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: MUPhoneColors.border.withValues(alpha: 0.3),
                      indent: 12,
                      endIndent: 12,
                    ),
                    itemBuilder: (context, index) {
                      final app = result.apps[index];
                      return InkWell(
                        onTap: () {
                          cmdCtl.text = app.packageName;
                          if (labelCtl.text.isEmpty) {
                            labelCtl.text = app.label;
                          }
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.android, size: 16, color: MUPhoneColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  app.packageName,
                                  style: const TextStyle(color: MUPhoneColors.textPrimary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(foregroundColor: MUPhoneColors.textSecondary),
                  child: const Text('取消'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdbCommandSelector(
    BuildContext context,
    TextEditingController cmdCtl,
    TextEditingController labelCtl,
  ) {
    final commands = widget.state.adbCommandPresets;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MUPhoneColors.card,
        title: const Text('ADB 指令列表', style: TextStyle(color: MUPhoneColors.textPrimary, fontSize: 14)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: commands
                .map(
                  (c) => ListTile(
                    leading: Icon(
                      ShortcutAction.iconData(c.icon),
                      color: MUPhoneColors.primary,
                      size: 18,
                    ),
                    title: Text(
                      c.label,
                      style: const TextStyle(color: MUPhoneColors.textPrimary, fontSize: 12),
                    ),
                    subtitle: Text(
                      c.command,
                      style: const TextStyle(color: MUPhoneColors.textDisabled, fontSize: 10),
                    ),
                    onTap: () {
                      cmdCtl.text = c.command;
                      if (labelCtl.text.isEmpty) labelCtl.text = c.label;
                      Navigator.pop(ctx);
                    },
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAdbPresetManager(context);
            },
            child: const Text('管理列表'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('關閉')),
        ],
      ),
    );
  }

  void _showAdbPresetManager(BuildContext context) {
    final presets = List<AdbCommandPreset>.from(widget.state.adbCommandPresets);
    bool editMode = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            backgroundColor: MUPhoneColors.card,
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    '管理 ADB 指令列表',
                    style: TextStyle(fontSize: 14, color: MUPhoneColors.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: () => setDialogState(() => editMode = !editMode),
                  child: Text(editMode ? '完成' : '編輯模式'),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              height: 360,
              child: Column(
                children: [
                  if (editMode)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final next = await _editAdbPreset(context);
                          if (next == null) return;
                          setDialogState(() => presets.add(next));
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('新增'),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.separated(
                      itemCount: presets.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: MUPhoneColors.border.withValues(alpha: 0.3),
                      ),
                      itemBuilder: (_, i) {
                        final p = presets[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(ShortcutAction.iconData(p.icon), size: 16, color: MUPhoneColors.primary),
                          title: Text(p.label, style: const TextStyle(fontSize: 12, color: MUPhoneColors.textPrimary)),
                          subtitle: Text(p.command, style: const TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (editMode)
                                IconButton(
                                  iconSize: 14,
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit_outlined, color: MUPhoneColors.textDisabled),
                                  onPressed: () async {
                                    final updated = await _editAdbPreset(context, existing: p);
                                    if (updated == null) return;
                                    setDialogState(() => presets[i] = updated);
                                  },
                                ),
                              if (editMode)
                                IconButton(
                                  iconSize: 14,
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_outline, color: MUPhoneColors.statusFailed),
                                  onPressed: () => setDialogState(() => presets.removeAt(i)),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              TextButton(
                onPressed: () {
                  widget.state.setAdbCommandPresets(presets);
                  Navigator.pop(ctx);
                },
                child: const Text('儲存'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openIconDocs(BuildContext context) async {
    try {
      if (Platform.isWindows) {
        await Process.start(
          'cmd',
          ['/c', 'start', '', _kIconDocsUrl],
          runInShell: true,
        );
      } else if (Platform.isMacOS) {
        await Process.start('open', [_kIconDocsUrl]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [_kIconDocsUrl]);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟瀏覽器，請手動複製連結')),
      );
    }
  }

  Future<AdbCommandPreset?> _editAdbPreset(
    BuildContext context, {
    AdbCommandPreset? existing,
  }) async {
    final labelCtl = TextEditingController(text: existing?.label ?? '');
    final cmdCtl = TextEditingController(text: existing?.command ?? '');
    String icon = existing?.icon ?? 'terminal';
    return showDialog<AdbCommandPreset>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            backgroundColor: MUPhoneColors.card,
            title: Text(existing == null ? '新增 ADB 指令' : '編輯 ADB 指令',
                style: const TextStyle(fontSize: 14, color: MUPhoneColors.textPrimary)),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('名稱', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                  const SizedBox(height: 4),
                  _dialogInput(labelCtl, '例如：返回首頁'),
                  const SizedBox(height: 10),
                  const Text('指令', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                  const SizedBox(height: 4),
                  _dialogInput(cmdCtl, '例如：input keyevent 3'),
                  const SizedBox(height: 10),
                  const Text('圖標', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 74,
                    child: GridView.builder(
                      itemCount: ShortcutAction.iconKeys.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemBuilder: (_, i) {
                        final key = ShortcutAction.iconKeys[i];
                        final active = icon == key;
                        return InkWell(
                          onTap: () => setDialogState(() => icon = key),
                          child: Container(
                            decoration: BoxDecoration(
                              color: active ? MUPhoneColors.primary.withValues(alpha: 0.2) : MUPhoneColors.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: active ? MUPhoneColors.primary : MUPhoneColors.border.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              ShortcutAction.iconData(key),
                              size: 14,
                              color: active ? MUPhoneColors.primary : MUPhoneColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              TextButton(
                onPressed: () {
                  final label = labelCtl.text.trim();
                  final command = cmdCtl.text.trim();
                  if (label.isEmpty || command.isEmpty) return;
                  Navigator.pop(
                    ctx,
                    AdbCommandPreset(
                      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                      label: label,
                      command: command,
                      icon: icon,
                    ),
                  );
                },
                child: const Text('確認'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dialogInput(TextEditingController ctrl, String hint) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 12, color: MUPhoneColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: MUPhoneColors.textDisabled.withValues(alpha: 0.4)),
          filled: true, fillColor: MUPhoneColors.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
        _SectionTitle(
          icon: Icons.bolt,
          title: '快捷鍵',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _showAdbPresetManager(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.terminal, size: 12, color: MUPhoneColors.textSecondary),
                      SizedBox(width: 2),
                      Text('ADB 列表', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: MUPhoneColors.textSecondary)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
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
            ],
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: MUPhoneColors.card,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: MUPhoneColors.primary),
          ),
          const SizedBox(width: 16),
          Text(
            text,
            style: const TextStyle(
              color: MUPhoneColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
              color: action.actionType == ShortcutAction.appLaunch
                  ? MUPhoneColors.primary.withValues(alpha: 0.1)
                  : MUPhoneColors.statusLockedOther.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(action.actionType == ShortcutAction.appLaunch ? 'APP' : action.actionType.toUpperCase(),
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600,
                color: action.actionType == ShortcutAction.appLaunch ? MUPhoneColors.primary : MUPhoneColors.statusLockedOther)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: action.deviceSerial == null ? MUPhoneColors.textDisabled.withValues(alpha: 0.1) : MUPhoneColors.statusOnline.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(action.deviceSerial == null ? '全域' : '裝置',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600,
                color: action.deviceSerial == null ? MUPhoneColors.textDisabled : MUPhoneColors.statusOnline)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(action.commandForLegacy,
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

class _WindowBehaviorSection extends StatelessWidget {
  const _WindowBehaviorSection({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(icon: Icons.open_in_new, title: '視窗行為'),
        const SizedBox(height: 10),
        _SectionBox(
          child: Column(
            children: [
              _WindowBehaviorRow(
                title: '記住主視窗位置',
                description: '儲存主視窗位置與尺寸，重新啟動時自動還原。',
                value: state.rememberMainWindowPlacement,
                onChanged: state.setRememberMainWindowPlacement,
              ),
              Divider(height: 16, color: MUPhoneColors.border.withValues(alpha: 0.35)),
              _WindowBehaviorRow(
                title: '記住獨立視窗位置',
                description: '依裝置視窗分別儲存位置與尺寸。',
                value: state.rememberDetachedWindowPlacement,
                onChanged: state.setRememberDetachedWindowPlacement,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WindowBehaviorRow extends StatelessWidget {
  const _WindowBehaviorRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MUPhoneColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 10,
                  color: MUPhoneColors.textDisabled,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          height: 18,
          child: Transform.scale(
            scale: 0.65,
            child: Switch(
              value: value,
              activeColor: MUPhoneColors.statusOnline,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
        const _SectionTitle(icon: Icons.devices, title: '裝置列表'),
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
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  itemCount: state.devices.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final serial = state.devices[oldIndex].serial;
                    state.reorderDevice(serial, newIndex);
                  },
                  itemBuilder: (_, i) {
                    final d = state.devices[i];
                    return _DeviceRow(
                      key: ValueKey(d.serial),
                      index: i,
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
  const _DeviceRow({super.key, required this.index, required this.device, required this.state});
  final int index;
  final DeviceState device;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final dev = device;
    final (color, label) = switch (dev.phase) {
      DevicePhase.online  => (MUPhoneColors.statusOnline, '在線'),
      DevicePhase.locked  => (MUPhoneColors.statusLockedMine, '鎖定'),
      DevicePhase.starting => (MUPhoneColors.statusLockedOther, '啟動中'),
      DevicePhase.failed  => (MUPhoneColors.statusFailed, '失敗'),
      DevicePhase.offline => (MUPhoneColors.statusOffline, '離線'),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Row(
          children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_indicator, size: 14, color: MUPhoneColors.textDisabled),
          ),
          const SizedBox(width: 6),
          _QualityChip(
            quality: state.getDeviceQuality(dev.serial),
            onChanged: (val) {
              if (dev.isQualitySwitching) return; // debounce: ignore while switching
              state.setDeviceQuality(dev.serial, val);
              state.updateDevice(dev.deviceId, (d) => d.copyWith(isQualitySwitching: true));
              PlatformBridge.instance.setFpsProfile(dev.deviceId, val);
              Future.delayed(const Duration(seconds: 10), () {
                final d = state.getDevice(dev.deviceId);
                if (d != null && d.isQualitySwitching) {
                  state.updateDevice(dev.deviceId, (d) => d.copyWith(isQualitySwitching: false));
                }
              });
            },
          ),
          const SizedBox(width: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w500, color: color)),
              ],
            ),
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

class _CustomControlsSection extends StatefulWidget {
  const _CustomControlsSection({required this.state});
  final AppState state;

  @override
  State<_CustomControlsSection> createState() => _CustomControlsSectionState();
}

class _CustomControlsSectionState extends State<_CustomControlsSection> {
  Future<void> _editAction(CustomControlAction action) async {
    final nameCtl = TextEditingController(text: action.name);
    final descCtl = TextEditingController(text: action.description);
    final cmdCtl = TextEditingController(text: action.command);
    final bindingsCtl = TextEditingController(text: action.bindings.join(', '));

    final result = await showDialog<CustomControlAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MUPhoneColors.card,
        title: Text(
          action.builtIn ? '編輯綁定鍵' : '編輯自定義操作',
          style: const TextStyle(fontSize: 14, color: MUPhoneColors.textPrimary),
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('操作名稱', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
              const SizedBox(height: 4),
              _dialogInput(nameCtl, '例如：返回首頁'),
              const SizedBox(height: 10),
              const Text('描述', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
              const SizedBox(height: 4),
              _dialogInput(descCtl, '簡短說明這個操作用途'),
              const SizedBox(height: 10),
              const Text('執行命令', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
              const SizedBox(height: 4),
              _dialogInput(cmdCtl, '例如：key:4 / adb:input keyevent 3 / touch_drag'),
              const SizedBox(height: 10),
              const Text('綁定鍵（可多個，逗號分隔）', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
              const SizedBox(height: 4),
              _dialogInput(bindingsCtl, '例如：mouse_right, key:escape'),
              const SizedBox(height: 6),
              const Text(
                '可用鍵值：mouse_left / mouse_right / mouse_middle / mouse_wheel / key:<名稱> / shortcut:paste',
                style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final bindings = bindingsCtl.text
                  .split(',')
                  .map(CustomControlAction.normalizeBinding)
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList();
              if (bindings.isEmpty) return;
              if (action.builtIn) {
                Navigator.pop(
                  ctx,
                  action.copyWith(bindings: bindings),
                );
                return;
              }
              final name = nameCtl.text.trim();
              final cmd = cmdCtl.text.trim();
              if (name.isEmpty || cmd.isEmpty) return;
              Navigator.pop(
                ctx,
                action.copyWith(
                  name: name,
                  description: descCtl.text.trim(),
                  command: cmd,
                  bindings: bindings,
                ),
              );
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final next = widget.state.customControlActions
        .map((item) => item.id == action.id ? result : item)
        .toList(growable: false);
    widget.state.setCustomControlActions(next);
  }

  Future<void> _addCustomAction() async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    final cmdCtl = TextEditingController(text: 'adb:input keyevent 3');
    final bindingsCtl = TextEditingController(text: 'key:f8');
    final result = await showDialog<CustomControlAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MUPhoneColors.card,
        title: const Text(
          '新增自定義操作',
          style: TextStyle(fontSize: 14, color: MUPhoneColors.textPrimary),
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('操作名稱', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
              const SizedBox(height: 4),
              _dialogInput(nameCtl, '例如：快速返回'),
              const SizedBox(height: 10),
              const Text('描述', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
              const SizedBox(height: 4),
              _dialogInput(descCtl, '例如：送出 Android 返回鍵'),
              const SizedBox(height: 10),
              const Text('執行命令', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
              const SizedBox(height: 4),
              _dialogInput(cmdCtl, '例如：key:4 或 adb:input keyevent 3'),
              const SizedBox(height: 10),
              const Text('綁定鍵（可多個，逗號分隔）', style: TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled)),
              const SizedBox(height: 4),
              _dialogInput(bindingsCtl, '例如：key:f8, key:escape'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final name = nameCtl.text.trim();
              final cmd = cmdCtl.text.trim();
              final bindings = bindingsCtl.text
                  .split(',')
                  .map(CustomControlAction.normalizeBinding)
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList();
              if (name.isEmpty || cmd.isEmpty || bindings.isEmpty) return;
              Navigator.pop(
                ctx,
                CustomControlAction(
                  id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
                  name: name,
                  description: descCtl.text.trim(),
                  command: cmd,
                  bindings: bindings,
                  builtIn: false,
                ),
              );
            },
            child: const Text('新增'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final next = List<CustomControlAction>.from(widget.state.customControlActions)
      ..add(result);
    widget.state.setCustomControlActions(next);
  }

  void _deleteCustomAction(CustomControlAction action) {
    if (action.builtIn) return;
    final next = widget.state.customControlActions
        .where((item) => item.id != action.id)
        .toList(growable: false);
    widget.state.setCustomControlActions(next);
  }

  Widget _dialogInput(TextEditingController ctrl, String hint) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 12, color: MUPhoneColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: MUPhoneColors.textDisabled.withValues(alpha: 0.4)),
          filled: true,
          fillColor: MUPhoneColors.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: MUPhoneColors.border, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: MUPhoneColors.border, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: MUPhoneColors.primary, width: 1),
          ),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.state.customControlActions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.keyboard_command_key,
          title: '自定義控制',
          trailing: TextButton.icon(
            onPressed: _addCustomAction,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('新增操作'),
          ),
        ),
        const SizedBox(height: 10),
        _SectionBox(
          child: Column(
            children: actions.map((action) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                action.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: MUPhoneColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (action.builtIn)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: MUPhoneColors.textDisabled.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '內建',
                                    style: TextStyle(fontSize: 9, color: MUPhoneColors.textDisabled),
                                  ),
                                ),
                            ],
                          ),
                          if (action.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              action.description,
                              style: const TextStyle(fontSize: 10, color: MUPhoneColors.textDisabled),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            action.command,
                            style: const TextStyle(fontSize: 10, color: MUPhoneColors.primary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: action.bindings
                                .map(
                                  (binding) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: MUPhoneColors.background,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: MUPhoneColors.border.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      binding,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: MUPhoneColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, color: MUPhoneColors.textSecondary),
                      onPressed: () => _editAction(action),
                    ),
                    if (!action.builtIn)
                      IconButton(
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline, color: MUPhoneColors.statusFailed),
                        onPressed: () => _deleteCustomAction(action),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
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
