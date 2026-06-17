import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/widgets/banners.dart';
import 'package:tawreedat_go/core/widgets/text_form.dart';
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

  // Add focus nodes
  final oldPasswordFocus = FocusNode();
  final newPasswordFocus = FocusNode();
  final confirmPasswordFocus = FocusNode();

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
            showSuccessBanner(context, AppLocalizations.of(context)!.profileUpdatedSuccessfully);
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
                  focusNode: oldPasswordFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(newPasswordFocus),
                  validator: (v) =>
                  v!.isEmpty ? localizations.enterPassword : null,
                ),
                const SizedBox(height: 16),
                AppTextFormField(
                  enabled: true,
                  label: localizations.password,
                  controller: newPasswordController,
                  isPassword: true,
                  focusNode: newPasswordFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(confirmPasswordFocus),
                  validator: (v) {
                    if (v == null || v.isEmpty) return localizations.enterPassword;
                    if (v.length < 8) return localizations.shortPassword;
                    if (!RegExp(r'[A-Z]').hasMatch(v)) return localizations.passwordNeedsUppercase;
                    if (!RegExp(r'[a-z]').hasMatch(v)) return localizations.passwordNeedsLowercase;
                    if (!RegExp(r'[0-9]').hasMatch(v)) return localizations.passwordNeedsNumber;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextFormField(
                  enabled: true,
                  label: localizations.confirmPassword,
                  controller: confirmNewPasswordController,
                  isPassword: true,
                  focusNode: confirmPasswordFocus,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (changePasswordFormKey.currentState!.validate()) {
                      context.read<AuthCubit>().changePassword(
                        oldPasswordController.text,
                        newPasswordController.text,
                        context,
                      );
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) return localizations.enterPassword;
                    if (value != confirmNewPasswordController.text) {
                      return localizations.passwordMismatch;
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
                      isLoading: state is AuthLoading,
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