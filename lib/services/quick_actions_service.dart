import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

class QuickActionsService {
  static final QuickActions _quickActions = const QuickActions();
  static String? _pendingAction;
  static void Function(String action)? _actionHandler;

  static void initialize({required void Function(String action) onAction}) {
    if (kIsWeb) return;
    _actionHandler = onAction;

    _quickActions.initialize((String shortcutType) {
      if (_actionHandler != null) {
        _actionHandler!(shortcutType);
      } else {
        _pendingAction = shortcutType;
      }
    });

    try {
      _quickActions.setShortcutItems(const <ShortcutItem>[
        ShortcutItem(
          type: 'action_shop',
          localizedTitle: 'Daily Shop',
          icon: 'ic_shortcut_shop',
        ),
        ShortcutItem(
          type: 'action_party',
          localizedTitle: 'Party Lobby',
          icon: 'ic_shortcut_party',
        ),
        ShortcutItem(
          type: 'action_profile',
          localizedTitle: 'Profile',
          icon: 'ic_shortcut_profile',
        ),
      ]);
    } catch (e) {
      debugPrint('QuickActions setShortcutItems error: $e');
    }

    if (_pendingAction != null) {
      final action = _pendingAction!;
      _pendingAction = null;
      _actionHandler?.call(action);
    }
  }

  static void setActionHandler(void Function(String action) onAction) {
    _actionHandler = onAction;
    if (_pendingAction != null) {
      final action = _pendingAction!;
      _pendingAction = null;
      _actionHandler?.call(action);
    }
  }
}
