import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/widgets/text_form.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../features/auth/manager/auth_cubit.dart';
import '../../features/auth/manager/auth_state.dart';

void showChangePasswordBottomSheet(BuildContext context) {
  final localizations = AppLocalizations.of(context)!;
  final changePasswordFormKey = GlobalKey<FormState>();
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmNewPasswordController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return BlocListener<AuthCubit, AuthState>(
        listener: (context, state) async {
          if (state is AuthUpdateSuccess) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.profileUpdatedSuccessfully,
                ),
              ),
            );
          } else if (state is AuthFailure) {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  backgroundColor: Colors.redAccent,
                  content: Text(
                    state.message.toString(),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: changePasswordFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.changePassword,
                  style: AppTextStyles.bold18,
                ),
                const SizedBox(height: 20),
                AppTextFormField(
                  enabled: true,
                  label: AppLocalizations.of(context)!.oldPassword,
                  controller: oldPasswordController,
                  isPassword: true,
                  validator: (v) =>
                  v!.isEmpty ? localizations.enterPassword : null,
                ),
                const SizedBox(height: 16),
                AppTextFormField(
                  enabled: true,
                  label: localizations.password,
                  controller: newPasswordController,
                  isPassword: true,
                  validator: (v) {
                    if (v!.isEmpty) return localizations.enterPassword;
                    if (v.length < 6) return localizations.shortPassword;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextFormField(
                  enabled: true,
                  label: localizations.confirmPassword,
                  controller: confirmNewPasswordController,
                  isPassword: true,
                  validator: (v) {
                    if (v != newPasswordController.text) {
                      return AppLocalizations.of(context)!.passwordMismatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    return AppCustomButton(
                      onPressed: () {
                        if (changePasswordFormKey.currentState!.validate()) {
                          context.read<AuthCubit>().changePassword(
                            oldPasswordController.text,
                            newPasswordController.text,
                            context,
                          );
                        }
                      },
                      text: AppLocalizations.of(context)!.confirm,
                    );
                  },
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context)!.cancel,
                      style: AppTextStyles.bold16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    },
  );
}