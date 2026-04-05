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

class MUPhoneShortcutManager extends StatelessWidget {
  const MUPhoneShortcutManager({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.equal):
            const OpenSettingsIntent(),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true):
            const FocusDeviceIntent(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true):
            const FocusDeviceIntent(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true):
            const FocusDeviceIntent(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true):
            const FocusDeviceIntent(3),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true):
            const FocusDeviceIntent(4),
        const SingleActivator(LogicalKeyboardKey.digit6, control: true):
            const FocusDeviceIntent(5),
        const SingleActivator(LogicalKeyboardKey.digit7, control: true):
            const FocusDeviceIntent(6),
        const SingleActivator(LogicalKeyboardKey.digit8, control: true):
            const FocusDeviceIntent(7),
        const SingleActivator(LogicalKeyboardKey.digit9, control: true):
            const FocusDeviceIntent(8),
        const SingleActivator(LogicalKeyboardKey.escape):
            const EscapeIntent(),
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            const SelectAllIntent(),
        const SingleActivator(LogicalKeyboardKey.keyD, control: true):
            const DeselectAllIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          OpenSettingsIntent:
              CallbackAction<OpenSettingsIntent>(onInvoke: (intent) {
            showDialog(
              context: context,
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<AppState>(),
                child: const SettingsModal(),
              ),
            );
            return null;
          }),
          FocusDeviceIntent:
              CallbackAction<FocusDeviceIntent>(onInvoke: (intent) {
            final state = context.read<AppState>();
            if (intent.slotIndex < state.devices.length) {
              state.setFocused(state.devices[intent.slotIndex].deviceId);
            }
            return null;
          }),
          EscapeIntent: CallbackAction<EscapeIntent>(onInvoke: (intent) {
            context.read<AppState>().clearFocusAndPanels();
            return null;
          }),
          SelectAllIntent: CallbackAction<SelectAllIntent>(onInvoke: (intent) {
            context.read<AppState>().selectAll();
            return null;
          }),
          DeselectAllIntent:
              CallbackAction<DeselectAllIntent>(onInvoke: (intent) {
            context.read<AppState>().deselectAll();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
