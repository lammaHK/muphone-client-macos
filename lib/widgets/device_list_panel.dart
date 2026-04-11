import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme/muphone_theme.dart';

class DeviceListPanel extends StatelessWidget {
  const DeviceListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          right: state.deviceListPanelOpen ? 0 : -320,
          top: 0,
          bottom: 0,
          width: 320,
          child: _PanelBody(state: state),
        );
      },
    );
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MUPhoneColors.card,
        border: Border(
          left: BorderSide(color: MUPhoneColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          _PanelHeader(onClose: state.toggleDeviceListPanel),
          const Divider(height: 1, color: MUPhoneColors.border),
          Expanded(
            child: state.devices.isEmpty
                ? const _EmptyDeviceList()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.devices.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: MUPhoneColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final device = state.devices[index];
                      return _DeviceRow(
                        device: device,
                        isFocused: state.focusedDeviceId == device.deviceId,
                        onFocus: () => state.setFocused(device.deviceId),
                        onDetachToggle: () {
                          state.setDeviceDetached(
                            device.deviceId,
                            !device.isDetached,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'Device List',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MUPhoneColors.textPrimary,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 28,
            height: 28,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onClose,
                hoverColor: MUPhoneColors.hover,
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: MUPhoneColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.isFocused,
    required this.onFocus,
    required this.onDetachToggle,
  });

  final DeviceState device;
  final bool isFocused;
  final VoidCallback onFocus;
  final VoidCallback onDetachToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isFocused ? MUPhoneColors.primary.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _QualityBadge(label: _buildQualityLine()),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  device.displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MUPhoneColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _PhaseBadge(phase: device.phase, lockOwner: device.lockOwner),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _buildStatusLine(),
            style: const TextStyle(
              fontSize: 11,
              color: MUPhoneColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ActionButton(
                label: 'Focus',
                onPressed: onFocus,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: device.isDetached ? 'Attach' : 'Detach',
                onPressed: onDetachToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildQualityLine() {
    final quality = (device.height >= 1080 || device.width >= 1080) ? 'FHD' : 'HD';
    if (device.fps > 0) {
      return '$quality ${device.fps}fps';
    }
    return quality;
  }

  String _buildStatusLine() {
    final parts = <String>[];
    parts.add(device.phase.name.capitalize());
    if (device.lockOwner != null) {
      parts.add('Locked(${device.lockOwner})');
    }
    if (device.isDetached) {
      parts.add('Detached');
    }
    return parts.join(' · ');
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.phase, this.lockOwner});
  final DevicePhase phase;
  final String? lockOwner;

  @override
  Widget build(BuildContext context) {
    final color = switch (phase) {
      DevicePhase.online => MUPhoneColors.statusOnline,
      DevicePhase.locked => lockOwner == 'me'
          ? MUPhoneColors.statusLockedMine
          : MUPhoneColors.statusLockedOther,
      DevicePhase.failed => MUPhoneColors.statusFailed,
      DevicePhase.offline || DevicePhase.starting => MUPhoneColors.statusOffline,
    };

    final text = switch (phase) {
      DevicePhase.online => '在線',
      DevicePhase.locked => '鎖定',
      DevicePhase.failed => '失敗',
      DevicePhase.offline => '離線',
      DevicePhase.starting => '啟動中',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
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
          Text(
            text,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: MUPhoneColors.hover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MUPhoneColors.border, width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: MUPhoneColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          backgroundColor: MUPhoneColors.hover,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: MUPhoneColors.border, width: 0.5),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: MUPhoneColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyDeviceList extends StatelessWidget {
  const _EmptyDeviceList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No devices',
        style: TextStyle(
          fontSize: 13,
          color: MUPhoneColors.textDisabled,
        ),
      ),
    );
  }
}

extension _StringCap on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
