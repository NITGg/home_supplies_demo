import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/notification_settings_cubit.dart';

class NotificationSettingsSheet extends StatelessWidget {
  const NotificationSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationSettingsCubit, NotificationSettingsState>(
      builder: (context, state) {
        final cubit = context.read<NotificationSettingsCubit>();

        if (state is NotificationSettingsLoading) {
          return const SizedBox(
            height: 200,
            child: Center(child: LoadingScreen(isOne: true)),
          );
        }

        if (state is NotificationSettingsError) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.grey[400], size: 48),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.notificationSettingsError,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: cubit.loadSettings,
                    child: Text(AppLocalizations.of(context)!.retry),
                  ),
                ],
              ),
            ),
          );
        }

        final settings = state is NotificationSettingsLoaded
            ? state.settings
            : state is NotificationSettingsUpdating
            ? state.settings
            : null;

        if (settings == null) return const SizedBox.shrink();

        final isUpdating = state is NotificationSettingsUpdating;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.tune_rounded),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.notificationSettings,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (isUpdating) ...[
                    const Spacer(),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              NotificationSettingsTile(
                icon: Icons.notifications_active_outlined,
                title: AppLocalizations.of(context)!.pushNotifications,
                subtitle:
                AppLocalizations.of(context)!.pushNotificationsSubtitle,
                value: settings.pushEnabled,
                onChanged: isUpdating
                    ? null
                    : (val) => cubit
                    .updateSetting(settings.copyWith(pushEnabled: val)),
              ),
              NotificationSettingsTile(
                icon: Icons.receipt_long_outlined,
                title: AppLocalizations.of(context)!.newOrdersNotification,
                subtitle: AppLocalizations.of(context)!
                    .newOrdersNotificationSubtitle,
                value: settings.newOrders,
                onChanged: isUpdating
                    ? null
                    : (val) => cubit
                    .updateSetting(settings.copyWith(newOrders: val)),
              ),
              NotificationSettingsTile(
                icon: Icons.local_offer_outlined,
                title:
                AppLocalizations.of(context)!.offerUpdatesNotification,
                subtitle: AppLocalizations.of(context)!
                    .offerUpdatesNotificationSubtitle,
                value: settings.offerUpdates,
                onChanged: isUpdating
                    ? null
                    : (val) => cubit
                    .updateSetting(settings.copyWith(offerUpdates: val)),
              ),
              NotificationSettingsTile(
                icon: Icons.workspace_premium_outlined,
                title:
                AppLocalizations.of(context)!.badgeUpdatesNotification,
                subtitle: AppLocalizations.of(context)!
                    .badgeUpdatesNotificationSubtitle,
                value: settings.badgeUpdates,
                onChanged: isUpdating
                    ? null
                    : (val) => cubit
                    .updateSetting(settings.copyWith(badgeUpdates: val)),
              ),
              NotificationSettingsTile(
                icon: Icons.admin_panel_settings_outlined,
                title: AppLocalizations.of(context)!.adminNotifications,
                subtitle:
                AppLocalizations.of(context)!.adminNotificationsSubtitle,
                value: settings.allowAdminNotification,
                onChanged: isUpdating
                    ? null
                    : (val) => cubit.updateSetting(
                    settings.copyWith(allowAdminNotification: val)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tile widget (reusable) ────────────────────────────────────────────────────

class NotificationSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const NotificationSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.kPrimaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.kPrimaryColor,
            trackOutlineColor: WidgetStateProperty.resolveWith(
                  (_) => AppColors.kPrimaryColor.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}