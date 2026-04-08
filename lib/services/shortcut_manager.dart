import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../widgets/settings_modal.dart';

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class FocusDeviceIntent extends Intent {
  const FocusDeviceIntent(this.slotIndex);
  final int slotIndex;
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

class SelectAllIntent extends Intent {
  const SelectAllIntent();
}

class DeselectAllIntent extends Intent {
  const DeselectAllIntent();
}

LogicalKeyboardKey _keyFromString(String key) {
  final k = key.toLowerCase();
  if (k.length == 1) {
    final code = k.codeUnitAt(0);
    if (code >= 97 && code <= 122) { // a-z
      return LogicalKeyboardKey(0x00000000060 + (code - 97));
    }
    if (code >= 48 && code <= 57) { // 0-9
      return LogicalKeyboardKey(0x00000000030 + (code - 48));
    }
  }
  const map = {
    '=': LogicalKeyboardKey.equal,
    '`': LogicalKeyboardKey.backquote,
    '-': LogicalKeyboardKey.minus,
    '[': LogicalKeyboardKey.bracketLeft,
    ']': LogicalKeyboardKey.bracketRight,
    ';': LogicalKeyboardKey.semicolon,
    '/': LogicalKeyboardKey.slash,
    '.': LogicalKeyboardKey.period,
    ',': LogicalKeyboardKey.comma,
    '\\': LogicalKeyboardKey.backslash,
    'f1': LogicalKeyboardKey.f1,
    'f2': LogicalKeyboardKey.f2,
    'f3': LogicalKeyboardKey.f3,
    'f4': LogicalKeyboardKey.f4,
    'f5': LogicalKeyboardKey.f5,
    'f6': LogicalKeyboardKey.f6,
    'f7': LogicalKeyboardKey.f7,
    'f8': LogicalKeyboardKey.f8,
    'f9': LogicalKeyboardKey.f9,
    'f10': LogicalKeyboardKey.f10,
    'f11': LogicalKeyboardKey.f11,
    'f12': LogicalKeyboardKey.f12,
    'tab': LogicalKeyboardKey.tab,
    'enter': LogicalKeyboardKey.enter,
    'space': LogicalKeyboardKey.space,
    'escape': LogicalKeyboardKey.escape,
    'backspace': LogicalKeyboardKey.backspace,
  };
  return map[k] ?? LogicalKeyboardKey.equal;
}

class MUPhoneShortcutManager extends StatelessWidget {
  const MUPhoneShortcutManager({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final settingsKey = _keyFromString(state.settingsShortcutKey);
        return Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            SingleActivator(settingsKey): const OpenSettingsIntent(),
            const SingleActivator(LogicalKeyboardKey.digit1, control: true): const FocusDeviceIntent(0),
            const SingleActivator(LogicalKeyboardKey.digit2, control: true): const FocusDeviceIntent(1),
            const SingleActivator(LogicalKeyboardKey.digit3, control: true): const FocusDeviceIntent(2),
            const SingleActivator(LogicalKeyboardKey.digit4, control: true): const FocusDeviceIntent(3),
            const SingleActivator(LogicalKeyboardKey.digit5, control: true): const FocusDeviceIntent(4),
            const SingleActivator(LogicalKeyboardKey.digit6, control: true): const FocusDeviceIntent(5),
            const SingleActivator(LogicalKeyboardKey.digit7, control: true): const FocusDeviceIntent(6),
            const SingleActivator(LogicalKeyboardKey.digit8, control: true): const FocusDeviceIntent(7),
            const SingleActivator(LogicalKeyboardKey.digit9, control: true): const FocusDeviceIntent(8),
            const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
            const SingleActivator(LogicalKeyboardKey.keyA, control: true): const SelectAllIntent(),
            const SingleActivator(LogicalKeyboardKey.keyD, control: true): const DeselectAllIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(onInvoke: (intent) {
                showDialog(
                  context: context,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: state,
                    child: const SettingsModal(),
                  ),
                );
                return null;
              }),
              FocusDeviceIntent: CallbackAction<FocusDeviceIntent>(onInvoke: (intent) {
                if (intent.slotIndex < state.devices.length) {
                  state.setFocused(state.devices[intent.slotIndex].deviceId);
                }
                return null;
              }),
              EscapeIntent: CallbackAction<EscapeIntent>(onInvoke: (intent) {
                state.clearFocusAndPanels();
                return null;
              }),
              SelectAllIntent: CallbackAction<SelectAllIntent>(onInvoke: (intent) {
                state.selectAll();
                return null;
              }),
              DeselectAllIntent: CallbackAction<DeselectAllIntent>(onInvoke: (intent) {
                state.deselectAll();
                return null;
              }),
            },
            child: Focus(autofocus: true, child: child),
          ),
        );
      },
    );
  }
}
