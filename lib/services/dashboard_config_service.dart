import '../core/constants/api_constants.dart';
import '../models/dashboard_card_config.dart';
import 'api_service.dart';

class DashboardConfigResult {
  final List<DashboardCardConfig> cards;
  final List<BottomNavItemConfig> bottomNav;

  const DashboardConfigResult({
    required this.cards,
    required this.bottomNav,
  });
}

class DashboardConfigService {
  static Future<DashboardConfigResult> getDashboardConfig() async {
    try {
      final response = await ApiService.get(
        ApiConstants.dashboardConfig,
        queryParams: {'platform': 'mobile'},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List<DashboardCardConfig> cards = [];
        List<BottomNavItemConfig> bottomNav = [];

        if (data is Map) {
          if (data['cards'] is List) {
            cards = (data['cards'] as List)
                .map((c) => DashboardCardConfig.fromJson(Map<String, dynamic>.from(c as Map)))
                .toList();
          } else if (data['data'] is List) {
            cards = (data['data'] as List)
                .map((c) => DashboardCardConfig.fromJson(Map<String, dynamic>.from(c as Map)))
                .toList();
          }

          if (data['bottomNav'] is List) {
            bottomNav = (data['bottomNav'] as List)
                .map((n) => BottomNavItemConfig.fromJson(Map<String, dynamic>.from(n as Map)))
                .toList();
          }
        }

        cards.sort((a, b) => a.order.compareTo(b.order));
        bottomNav.sort((a, b) => a.order.compareTo(b.order));

        return DashboardConfigResult(
          cards: cards.isNotEmpty ? cards : DashboardCardConfig.defaultCards,
          bottomNav: bottomNav.isNotEmpty ? bottomNav : BottomNavItemConfig.defaultNav,
        );
      }
      return DashboardConfigResult(
        cards: DashboardCardConfig.defaultCards,
        bottomNav: BottomNavItemConfig.defaultNav,
      );
    } catch (e) {
      return DashboardConfigResult(
        cards: DashboardCardConfig.defaultCards,
        bottomNav: BottomNavItemConfig.defaultNav,
      );
    }
  }
}
