import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/style/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../manager/availability_cubit.dart';

class UnavailableReminderSheet extends StatefulWidget {
  const UnavailableReminderSheet({super.key});

  @override
  State<UnavailableReminderSheet> createState() =>
      _UnavailableReminderSheetState();
}

class _UnavailableReminderSheetState extends State<UnavailableReminderSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  static const _autoDismissSeconds = 5;

  @override
  void initState() {
    super.initState();
    _progressController =
        AnimationController(
            vsync: this,
            duration: const Duration(seconds: _autoDismissSeconds),
          )
          ..forward();
          // ..addStatusListener((status) {
          //   if (status == AnimationStatus.completed && mounted) {
          //     Navigator.of(context).pop();
          //   }
          // });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Auto-dismiss progress bar
          AnimatedBuilder(
            animation: _progressController,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1 - _progressController.value, // counts down
                minHeight: 4,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 30,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 14),

      Text(
            AppLocalizations.of(context)!.currentlyUnAvailable,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.notReceiveNewOrders,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.later,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    _progressController.stop();
                    Navigator.of(context).pop();
                    await context.read<AvailabilityCubit>().setAvailable();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.kSecondaryColor,
                    foregroundColor: AppColors.kPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.isAvailable,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
