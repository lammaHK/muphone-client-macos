import 'package:flutter/material.dart';
import '../services/platform_bridge.dart';
import '../theme/muphone_theme.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key, required this.deviceId, required this.serial});

  final int deviceId;
  final String serial;

  static const int _keyBack   = 4;
  static const int _keyHome   = 3;
  static const int _keyRecent = 187;

  void _sendKey(int keycode) {
    PlatformBridge.instance.sendKey(deviceId, keycode);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: const BoxDecoration(
        color: MUPhoneColors.card,
        border: Border(top: BorderSide(color: MUPhoneColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          _NavBtn(icon: Icons.arrow_back_ios_rounded, size: 10,
            onPressed: () => _sendKey(_keyBack)),
          _NavBtn(icon: Icons.circle_outlined, size: 11,
            onPressed: () => _sendKey(_keyHome)),
          _NavTextBtn(label: '☰', size: 13,
            onPressed: () => _sendKey(_keyRecent)),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.size, required this.onPressed});
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: MUPhoneColors.hover,
          child: Center(child: Icon(icon, size: size, color: MUPhoneColors.textSecondary)),
        ),
      ),
    );
  }
}

class _NavTextBtn extends StatelessWidget {
  const _NavTextBtn({required this.label, required this.size, required this.onPressed});
  final String label;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: MUPhoneColors.hover,
          child: Center(
            child: Text(label, style: TextStyle(
              fontSize: size, color: MUPhoneColors.textSecondary, height: 1,
            )),
          ),
        ),
      ),
    );
  }
}
