import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_card_config.dart';
import '../services/dashboard_config_service.dart';

class DashboardConfigState {
  final bool isLoading;
  final List<DashboardCardConfig>? cards;
  final List<BottomNavItemConfig>? bottomNav;
  final String? error;

  const DashboardConfigState({
    this.isLoading = false,
    this.cards = const [],
    this.bottomNav = const [],
    this.error,
  });

  List<DashboardCardConfig> get enabledCards {
    final list = cards ?? DashboardCardConfig.defaultCards;
    final enabled = list.where((c) => c.enabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return enabled.isNotEmpty ? enabled : DashboardCardConfig.defaultCards;
  }

  List<BottomNavItemConfig> get enabledBottomNav {
    final list = bottomNav ?? BottomNavItemConfig.defaultNav;
    final enabled = list
        .where((n) => n.enabled && n.id.toLowerCase() != 'more')
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return enabled.isNotEmpty ? enabled : BottomNavItemConfig.defaultNav;
  }

  DashboardConfigState copyWith({
    bool? isLoading,
    List<DashboardCardConfig>? cards,
    List<BottomNavItemConfig>? bottomNav,
    String? error,
  }) {
    return DashboardConfigState(
      isLoading: isLoading ?? this.isLoading,
      cards: cards ?? this.cards ?? DashboardCardConfig.defaultCards,
      bottomNav: bottomNav ?? this.bottomNav ?? BottomNavItemConfig.defaultNav,
      error: error,
    );
  }
}

class DashboardConfigNotifier extends StateNotifier<DashboardConfigState> {
  DashboardConfigNotifier()
      : super(DashboardConfigState(
          cards: DashboardCardConfig.defaultCards,
          bottomNav: BottomNavItemConfig.defaultNav,
        )) {
    loadConfig();
  }

  Future<void> loadConfig() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final result = await DashboardConfigService.getDashboardConfig();
      state = state.copyWith(
        isLoading: false,
        cards: result.cards,
        bottomNav: result.bottomNav,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final dashboardConfigProvider =
    StateNotifierProvider<DashboardConfigNotifier, DashboardConfigState>((ref) {
  return DashboardConfigNotifier();
});
