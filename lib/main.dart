import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'services/persistence.dart';
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
          child: MainScreen(),
        ),
      ),
    );
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
