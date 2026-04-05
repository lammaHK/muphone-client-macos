import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme/muphone_theme.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Container(
          height: 48,
          color: MUPhoneColors.topBar,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const _Logo(),
              const SizedBox(width: 16),
              _ConnectionIndicator(connection: state.connection),
              const SizedBox(width: 12),
              _DeviceCountBadge(
                total: state.devices.length,
                online: state.onlineDeviceCount,
              ),
              const Spacer(),
              _GridModeSelector(
                current: state.gridMode,
                onChanged: state.setGridMode,
              ),
              const SizedBox(width: 8),
              _PanelToggleButton(
                isOpen: state.deviceListPanelOpen,
                onPressed: state.toggleDeviceListPanel,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.phone_android,
          color: MUPhoneColors.primary,
          size: 20,
        ),
        SizedBox(width: 8),
        Text(
          'MUPhone',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MUPhoneColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator({required this.connection});
  final ServerConnectionState connection;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (connection) {
      ServerConnectionState.connected => (MUPhoneColors.statusOnline, 'Connected'),
      ServerConnectionState.connecting => (MUPhoneColors.statusLockedOther, 'Connecting...'),
      ServerConnectionState.reconnecting => (MUPhoneColors.statusLockedOther, 'Reconnecting...'),
      ServerConnectionState.disconnected => (MUPhoneColors.statusFailed, 'Disconnected'),
    };

    return Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: MUPhoneColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCountBadge extends StatelessWidget {
  const _DeviceCountBadge({required this.total, required this.online});
  final int total;
  final int online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MUPhoneColors.hover,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MUPhoneColors.border, width: 0.5),
      ),
      child: Text(
        '$online / $total',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: MUPhoneColors.textSecondary,
        ),
      ),
    );
  }
}

class _GridModeSelector extends StatelessWidget {
  const _GridModeSelector({required this.current, required this.onChanged});
  final GridMode current;
  final ValueChanged<GridMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<GridMode>(
      initialValue: current,
      onSelected: onChanged,
      tooltip: 'Grid layout',
      offset: const Offset(0, 48),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: MUPhoneColors.hover,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: MUPhoneColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_view, size: 14, color: MUPhoneColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              current.label,
              style: const TextStyle(
                fontSize: 12,
                color: MUPhoneColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 14, color: MUPhoneColors.textSecondary),
          ],
        ),
      ),
      itemBuilder: (_) => GridMode.values
          .map((mode) => PopupMenuItem<GridMode>(
                value: mode,
                height: 32,
                child: Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: mode == current
                        ? MUPhoneColors.primary
                        : MUPhoneColors.textPrimary,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _PanelToggleButton extends StatelessWidget {
  const _PanelToggleButton({required this.isOpen, required this.onPressed});
  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Device List (=)',
      child: Material(
        color: isOpen ? MUPhoneColors.primary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onPressed,
          hoverColor: MUPhoneColors.hover,
          child: SizedBox(
            width: 36,
            height: 32,
            child: Center(
              child: Text(
                '≡',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: isOpen ? MUPhoneColors.primary : MUPhoneColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
