import '../models/app_state.dart';
import 'platform_bridge.dart';

class ActionDispatcher {
  ActionDispatcher._();

  static final ActionDispatcher instance = ActionDispatcher._();

  Future<void> dispatchShortcut({
    required int deviceId,
    required ShortcutAction action,
  }) async {
    final payload = action.toActionPayload();
    await PlatformBridge.instance.sendInput({
      'type': 'run_action',
      'device_id': deviceId,
      'action_type': payload['action_type'],
      'command': payload['command'],
      'action': payload,
      // Legacy fallback fields, kept for older server/plugin behavior.
      'shortcut_type': action.legacyShortcutType,
      'legacy_command': action.commandForLegacy,
    });
  }
}
