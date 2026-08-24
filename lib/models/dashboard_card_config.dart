import 'package:flutter/material.dart';

class DashboardCardConfig {
  final String id;
  final String title;
  final String? subtitle;
  final bool enabled;
  final int order;
  final String? icon;
  final String color;
  final String? route;
  final String dataType;
  final String? customValue;
  final String? description;

  const DashboardCardConfig({
    required this.id,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.order = 1,
    this.icon,
    this.color = '#6366f1',
    this.route,
    this.dataType = 'custom',
    this.customValue,
    this.description,
  });

  Color get parsedColor {
    try {
      final hex = color.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('0xFF$hex'));
      }
    } catch (_) {}
    return const Color(0xFF6366F1);
  }

  IconData get parsedIcon {
    switch (icon?.toLowerCase()) {
      case 'groups_rounded':
      case 'groups':
      case 'people':
      case 'people_rounded':
      case 'employee':
      case 'employees':
        return Icons.groups_rounded;
      case 'check_circle_rounded':
      case 'check_circle':
      case 'check':
      case 'present':
        return Icons.check_circle_rounded;
      case 'calendar_month_rounded':
      case 'calendar_month':
      case 'calendar':
      case 'leave':
      case 'leaves':
        return Icons.calendar_month_rounded;
      case 'cancel_rounded':
      case 'cancel':
      case 'absent':
        return Icons.cancel_rounded;
      case 'analytics':
      case 'insights':
      case 'insights_rounded':
        return Icons.insights_rounded;
      case 'payments':
      case 'salary':
      case 'payroll':
        return Icons.payments_rounded;
      case 'qr_code':
      case 'qr_code_scanner':
      case 'qr':
        return Icons.qr_code_scanner_rounded;
      case 'notifications':
      case 'notifications_rounded':
        return Icons.notifications_rounded;
      case 'timer':
      case 'schedule':
      case 'hours':
        return Icons.schedule_rounded;
      default:
        return Icons.dashboard_customize_rounded;
    }
  }

  factory DashboardCardConfig.fromJson(Map<String, dynamic> json) {
    return DashboardCardConfig(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      enabled: json['enabled'] is bool
          ? json['enabled'] as bool
          : (json['enabled']?.toString().toLowerCase() != 'false'),
      order: json['order'] is int
          ? json['order'] as int
          : int.tryParse(json['order']?.toString() ?? '1') ?? 1,
      icon: json['icon']?.toString(),
      color: json['color']?.toString() ?? '#6366f1',
      route: json['route']?.toString(),
      dataType: json['dataType']?.toString() ?? json['id']?.toString() ?? 'custom',
      customValue: json['customValue']?.toString(),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'enabled': enabled,
      'order': order,
      'icon': icon,
      'color': color,
      'route': route,
      'dataType': dataType,
      'customValue': customValue,
      'description': description,
    };
  }

  static List<DashboardCardConfig> get defaultCards => const [
        DashboardCardConfig(
          id: 'total_employees',
          title: 'Total Employees',
          dataType: 'total_employees',
          enabled: true,
          order: 1,
          icon: 'groups_rounded',
          color: '#6366f1',
          route: '/employees',
        ),
        DashboardCardConfig(
          id: 'present_today',
          title: 'Present Today',
          dataType: 'present_today',
          enabled: true,
          order: 2,
          icon: 'check_circle_rounded',
          color: '#10b981',
          route: '/attendance',
        ),
        DashboardCardConfig(
          id: 'on_leave_today',
          title: 'On Leave Today',
          dataType: 'on_leave_today',
          enabled: true,
          order: 3,
          icon: 'calendar_month_rounded',
          color: '#f59e0b',
          route: '/attendance',
        ),
        DashboardCardConfig(
          id: 'absent_today',
          title: 'Absent Today',
          dataType: 'absent_today',
          enabled: true,
          order: 4,
          icon: 'cancel_rounded',
          color: '#ef4444',
          route: '/attendance',
        ),
      ];
}

class BottomNavItemConfig {
  final String id;
  final String label;
  final String icon;
  final bool enabled;
  final int order;
  final String? route;

  const BottomNavItemConfig({
    required this.id,
    required this.label,
    this.icon = 'home',
    this.enabled = true,
    this.order = 1,
    this.route,
  });

  factory BottomNavItemConfig.fromJson(Map<String, dynamic> json) {
    return BottomNavItemConfig(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? json['title']?.toString() ?? 'Tab',
      icon: json['icon']?.toString() ?? 'home',
      enabled: json['enabled'] is bool
          ? json['enabled'] as bool
          : (json['enabled']?.toString().toLowerCase() != 'false'),
      order: json['order'] is int
          ? json['order'] as int
          : int.tryParse(json['order']?.toString() ?? '1') ?? 1,
      route: json['route']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'icon': icon,
      'enabled': enabled,
      'order': order,
      'route': route,
    };
  }

  static List<BottomNavItemConfig> get defaultNav => const [
        BottomNavItemConfig(id: 'dashboard', label: 'Dashboard', icon: 'home', enabled: true, order: 1),
        BottomNavItemConfig(id: 'employees', label: 'Employees', icon: 'people', enabled: true, order: 2),
        BottomNavItemConfig(id: 'leaves', label: 'Leaves', icon: 'business_center', enabled: true, order: 3),
        BottomNavItemConfig(id: 'messages', label: 'Messages', icon: 'chat', enabled: true, order: 4),
        BottomNavItemConfig(id: 'more', label: 'More', icon: 'more_horiz', enabled: true, order: 5),
      ];
}
