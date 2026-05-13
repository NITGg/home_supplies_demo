import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../style/app_colors.dart';
import '../style/text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/custom_button.dart';

void showGuestLoginPrompt(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.kPrimaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.kPrimaryColor),
          ),
          const SizedBox(height: 18),
          Text(l10n.signin, style: AppTextStyles.bold18, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          AppCustomButton(
            text: l10n.signin,
            onPressed: () { Navigator.pop(sheetCtx); context.go('/auth/login'); },
          ),
          const SizedBox(height: 12),
          AppCustomButton(
            text: l10n.register,
            isSecondary: true,
            onPressed: () { Navigator.pop(sheetCtx); context.go('/auth/register'); },
          ),
        ],
      ),
    ),
  );
}