import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/router/zen_router.dart'
    show appCoordinatorProvider;

export 'package:valorant_thunai/router/zen_router.dart' show AppTab;

final currentTabProvider = NotifierProvider<CurrentTabNotifier, int>(
  CurrentTabNotifier.new,
);

class CurrentTabNotifier extends Notifier<int> {
  @override
  int build() {
    final coordinator = ref.watch(appCoordinatorProvider);

    void update() {
      state = coordinator.currentTab;
    }

    coordinator.tabPath.addListener(update);

    ref.onDispose(() {
      coordinator.tabPath.removeListener(update);
    });

    return coordinator.currentTab;
  }
}
