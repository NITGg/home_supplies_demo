class NotificationSettings {
  final bool newOrders;
  final bool offerUpdates;
  final bool badgeUpdates;
  final bool pushEnabled;
  final bool allowAdminNotification;

  NotificationSettings({
    required this.newOrders,
    required this.offerUpdates,
    required this.badgeUpdates,
    required this.pushEnabled,
    required this.allowAdminNotification,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      newOrders: json['new_orders'] ?? true,
      offerUpdates: json['offer_updates'] ?? true,
      badgeUpdates: json['badge_updates'] ?? true,
      pushEnabled: json['push_enabled'] ?? true,
      allowAdminNotification: json['allow_admin_notification'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'new_orders': newOrders,
    'offer_updates': offerUpdates,
    'badge_updates': badgeUpdates,
    'push_enabled': pushEnabled,
    'allow_admin_notification': allowAdminNotification,
  };

  NotificationSettings copyWith({
    bool? newOrders,
    bool? offerUpdates,
    bool? badgeUpdates,
    bool? pushEnabled,
    bool? allowAdminNotification,
  }) {
    return NotificationSettings(
      newOrders: newOrders ?? this.newOrders,
      offerUpdates: offerUpdates ?? this.offerUpdates,
      badgeUpdates: badgeUpdates ?? this.badgeUpdates,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      allowAdminNotification:
      allowAdminNotification ?? this.allowAdminNotification,
    );
  }
}