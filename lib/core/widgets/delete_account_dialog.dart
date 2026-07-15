import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/manager/auth_cubit.dart';
import '../../l10n/app_localizations.dart';
import '../style/app_colors.dart';
import '../style/text_styles.dart';
import '../utils/secure_storage_service.dart';
import 'custom_button.dart';

class DeleteAccountDialog extends StatelessWidget {
  const DeleteAccountDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: Colors.white,
      title: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Text(
              AppLocalizations.of(context)!.deleteAccount,
              style: AppTextStyles.bold25.copyWith(fontSize: 20),
            ),
          ),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)!.deletingAccountWill,
            style: AppTextStyles.bold18,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.areYouSureDeleteAccount,
            style: AppTextStyles.bold18.copyWith(
              color: AppColors.kPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: <Widget>[
        Column(
          children: [
            AppCustomButton(
              onPressed: () async {
                await context.read<AuthCubit>().deleteProfile().then((value) {
                  SecureStorageService().clearAll();
                  if (context.mounted) {
                    context.go('/auth/loginDeleted');
                  }
                });
              },
              text: AppLocalizations.of(context)!.confirm,
            ),
            AppCustomButton(
              onPressed: () {
                context.pop();
              },
              text: AppLocalizations.of(context)!.cancel,
              isSecondary: true,
            ),
          ],
        ),
      ],
    );
  }
}