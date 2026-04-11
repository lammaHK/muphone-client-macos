import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class Persistence {
  Persistence._();
  static final Persistence instance = Persistence._();

  late final String _statePath;
  bool _initialized = false;

  void initialize({String? overridePath}) {
    if (_initialized) return;
    if (overridePath != null) {
      _statePath = overridePath;
    } else {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      _statePath = '$exeDir${Platform.pathSeparator}state.json';
    }
    _initialized = true;
    debugPrint('[Persistence] State file path: $_statePath');
  }

  Future<Map<String, dynamic>> load() async {
    _ensureInitialized();
    try {
      final file = File(_statePath);
      if (!await file.exists()) {
        debugPrint('[Persistence] No state file found, using defaults');
        return {};
      }
      final content = await file.readAsString();
      final data = json.decode(content);
      if (data is Map<String, dynamic>) {
        debugPrint('[Persistence] State loaded successfully');
        return data;
      }
      debugPrint('[Persistence] Invalid state format, using defaults');
      return {};
    } catch (e) {
      debugPrint('[Persistence] Failed to load state: $e');
      return {};
    }
  }

  Map<String, dynamic> loadSync() {
    _ensureInitialized();
    try {
      final file = File(_statePath);
      if (!file.existsSync()) {
        debugPrint('[Persistence] No state file found (sync), using defaults');
        return {};
      }
      final content = file.readAsStringSync();
      final data = json.decode(content);
      if (data is Map) {
        debugPrint('[Persistence] State loaded successfully (sync)');
        return Map<String, dynamic>.from(data);
      }
      debugPrint('[Persistence] Invalid state format (sync), using defaults');
      return {};
    } catch (e) {
      debugPrint('[Persistence] Failed to load state (sync): $e');
      return {};
    }
  }

  Future<void> save(Map<String, dynamic> state) async {
    _ensureInitialized();
    try {
      final tmpPath = '$_statePath.${pid}.${DateTime.now().microsecondsSinceEpoch}.tmp';
      final tmpFile = File(tmpPath);

      final dir = tmpFile.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final content = const JsonEncoder.withIndent('  ').convert(state);
      await tmpFile.writeAsString(content, flush: true);

      final targetFile = File(_statePath);
      try {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await tmpFile.rename(_statePath);
      } catch (_) {
        await targetFile.writeAsString(content, flush: true);
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
      }

      debugPrint('[Persistence] State saved successfully');
    } catch (e) {
      debugPrint('[Persistence] Failed to save state: $e');
    }
  }

  void saveSync(Map<String, dynamic> state) {
    _ensureInitialized();
    try {
      final tmpPath = '$_statePath.${pid}.${DateTime.now().microsecondsSinceEpoch}.tmp';
      final tmpFile = File(tmpPath);
      final dir = tmpFile.parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final content = const JsonEncoder.withIndent('  ').convert(state);
      tmpFile.writeAsStringSync(content, flush: true);

      final targetFile = File(_statePath);
      try {
        if (targetFile.existsSync()) {
          targetFile.deleteSync();
        }
        tmpFile.renameSync(_statePath);
      } catch (_) {
        targetFile.writeAsStringSync(content, flush: true);
        if (tmpFile.existsSync()) {
          tmpFile.deleteSync();
        }
      }

      debugPrint('[Persistence] State saved successfully (sync)');
    } catch (e) {
      debugPrint('[Persistence] Failed to save state (sync): $e');
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      initialize();
    }
  }
}
