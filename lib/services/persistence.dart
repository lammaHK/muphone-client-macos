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

  Future<void> save(Map<String, dynamic> state) async {
    _ensureInitialized();
    try {
      final tmpPath = '$_statePath.tmp';
      final tmpFile = File(tmpPath);

      final dir = tmpFile.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final content = const JsonEncoder.withIndent('  ').convert(state);
      await tmpFile.writeAsString(content, flush: true);

      final targetFile = File(_statePath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tmpFile.rename(_statePath);

      debugPrint('[Persistence] State saved successfully');
    } catch (e) {
      debugPrint('[Persistence] Failed to save state: $e');
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      initialize();
    }
  }
}
