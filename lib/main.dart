import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'services/persistence.dart';
import 'services/platform_bridge.dart';
import 'services/shortcut_manager.dart';
import 'theme/muphone_theme.dart';
import 'widgets/main_screen.dart';
import 'widgets/single_device_screen.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  Persistence.instance.initialize();

  // Check for --device=ID --host=IP args (single device window mode)
  String? deviceArg, hostArg;
  for (final a in args) {
    if (a.startsWith('--device=')) deviceArg = a.substring(9);
    if (a.startsWith('--host=')) hostArg = a.substring(7);
  }

  debugPrint('[main] args=$args device=$deviceArg host=$hostArg');

  if (deviceArg != null) {
    final deviceId = int.tryParse(deviceArg) ?? -1;
    final host = hostArg ?? '127.0.0.1';
    runApp(SingleDeviceApp(deviceId: deviceId, host: host));
  } else {
    runApp(const MUPhoneApp());
  }
}

class MUPhoneApp extends StatelessWidget {
  const MUPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'MUPhone',
        debugShowCheckedModeBanner: false,
        theme: buildMUPhoneTheme(),
        home: const MUPhoneShortcutManager(
          child: _CloseGuard(child: MainScreen()),
        ),
      ),
    );
  }
}

class _CloseGuard extends StatefulWidget {
  const _CloseGuard({required this.child});
  final Widget child;

  @override
  State<_CloseGuard> createState() => _CloseGuardState();
}

class _CloseGuardState extends State<_CloseGuard> {
  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2228),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF2B3A44))),
        title: const Text('關閉 MUPhone', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE8EAED))),
        content: const Text('確定要關閉客戶端嗎？\n所有裝置連接將會中斷。',
          style: TextStyle(fontSize: 12, color: Color(0xFF9AA0A6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
    if (result == true) {
      try { await PlatformBridge.instance.disconnect(); } catch (_) {}
      exit(0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(onWillPop: _onWillPop, child: widget.child);
  }
}

class SingleDeviceApp extends StatelessWidget {
  const SingleDeviceApp({super.key, required this.deviceId, required this.host});
  final int deviceId;
  final String host;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'MUPhone Device',
        debugShowCheckedModeBanner: false,
        theme: buildMUPhoneTheme(),
        home: SingleDeviceScreen(deviceId: deviceId, host: host),
      ),
    );
  }
}
