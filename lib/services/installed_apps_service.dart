import '../models/app_state.dart';
import '../models/installed_app.dart';
import 'platform_bridge.dart';

class InstalledAppsResult {
  final List<InstalledApp> apps;
  final List<String> errors;
  final int queriedDeviceCount;

  const InstalledAppsResult({
    required this.apps,
    required this.errors,
    required this.queriedDeviceCount,
  });
}

class InstalledAppsService {
  InstalledAppsService({PlatformBridge? bridge})
      : _bridge = bridge ?? PlatformBridge.instance;

  final PlatformBridge _bridge;

  Future<InstalledAppsResult> loadIntersection({
    required List<DeviceState> devices,
    String? targetSerial,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final onlineDevices = devices.where((d) {
      final online = d.phase == DevicePhase.online || d.phase == DevicePhase.locked;
      final serialMatch = targetSerial == null || d.serial == targetSerial;
      return online && serialMatch;
    }).toList();

    if (onlineDevices.isEmpty) {
      return const InstalledAppsResult(
        apps: [],
        errors: ['沒有可查詢的在線裝置'],
        queriedDeviceCount: 0,
      );
    }

    final packageSets = <Set<String>>[];
    final errors = <String>[];

    for (final device in onlineDevices) {
      try {
        final result = await _bridge
            .adbCommand(device.serial, 'shell', ['pm', 'list', 'packages'])
            .timeout(timeout);
        if (result == null || result['exit_code'] != 0) {
          errors.add('裝置 ${device.serial} 讀取失敗');
          continue;
        }
        final stdout = result['stdout'] as String? ?? '';
        final packages = _parsePackages(stdout);
        if (packages.isEmpty) {
          errors.add('裝置 ${device.serial} 未回傳有效套件');
          continue;
        }
        packageSets.add(packages);
      } catch (e) {
        errors.add('裝置 ${device.serial}：$e');
      }
    }

    if (packageSets.isEmpty) {
      return InstalledAppsResult(
        apps: const [],
        errors: errors.isEmpty ? ['讀取應用程式列表失敗'] : errors,
        queriedDeviceCount: onlineDevices.length,
      );
    }

    var intersection = Set<String>.from(packageSets.first);
    for (var i = 1; i < packageSets.length; i++) {
      intersection = intersection.intersection(packageSets[i]);
    }

    final apps = intersection
        .map(InstalledApp.fromPackage)
        .toList()
      ..sort((a, b) => a.packageName.compareTo(b.packageName));

    return InstalledAppsResult(
      apps: apps,
      errors: errors,
      queriedDeviceCount: onlineDevices.length,
    );
  }

  Set<String> _parsePackages(String stdout) {
    final packages = <String>{};
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('package:') && line.length > 8) {
        packages.add(line.substring(8));
      }
    }
    return packages;
  }
}
