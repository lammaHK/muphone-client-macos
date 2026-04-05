import 'package:flutter/material.dart';
import '../theme/muphone_theme.dart';

class AdbCommandBar extends StatelessWidget {
  const AdbCommandBar({
    super.key,
    required this.serial,
    this.onScreenshot,
    this.onInstall,
    this.onShell,
    this.onReboot,
    this.onInfo,
  });

  final String serial;
  final VoidCallback? onScreenshot;
  final VoidCallback? onInstall;
  final VoidCallback? onShell;
  final VoidCallback? onReboot;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: MUPhoneColors.card,
        border: Border(
          bottom: BorderSide(color: MUPhoneColors.border, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CmdButton(
            icon: Icons.screenshot_outlined,
            tooltip: 'Screenshot',
            onPressed: onScreenshot ?? () => _stub('Screenshot', serial),
          ),
          _CmdButton(
            icon: Icons.install_mobile_outlined,
            tooltip: 'Install APK',
            onPressed: onInstall ?? () => _stub('Install', serial),
          ),
          _CmdButton(
            icon: Icons.terminal_outlined,
            tooltip: 'Shell',
            onPressed: onShell ?? () => _stub('Shell', serial),
          ),
          _CmdButton(
            icon: Icons.restart_alt_outlined,
            tooltip: 'Reboot',
            onPressed: onReboot ?? () => _stub('Reboot', serial),
          ),
          _CmdButton(
            icon: Icons.info_outline,
            tooltip: 'Info',
            onPressed: onInfo ?? () => _stub('Info', serial),
          ),
        ],
      ),
    );
  }

  static void _stub(String action, String serial) {
    debugPrint('[AdbCommandBar] $action pressed for $serial (placeholder)');
  }
}

class _CmdButton extends StatelessWidget {
  const _CmdButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 32,
        height: 28,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onPressed,
            hoverColor: MUPhoneColors.hover,
            child: Icon(
              icon,
              size: 16,
              color: MUPhoneColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
