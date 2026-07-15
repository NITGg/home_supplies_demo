import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/widgets/banners.dart';
import 'package:tawreedat_courier/core/widgets/text_form.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../features/auth/manager/auth_cubit.dart';
import '../../features/auth/manager/auth_state.dart';

void showChangePasswordBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _ChangePasswordSheetBody(),
  );
}

class _ChangePasswordSheetBody extends StatefulWidget {
  const _ChangePasswordSheetBody();

  @override
  State<_ChangePasswordSheetBody> createState() =>
      _ChangePasswordSheetBodyState();
}

class _ChangePasswordSheetBodyState extends State<_ChangePasswordSheetBody> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  final _oldPasswordFocus = FocusNode();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    _oldPasswordFocus.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) async {
        if (state is AuthUpdateSuccess) {
          Navigator.pop(context);
          showSuccessBanner(
            context,
            AppLocalizations.of(context)!.profileUpdatedSuccessfully,
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
          key: _formKey,
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
                controller: _oldPasswordController,
                isPassword: true,
                focusNode: _oldPasswordFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_newPasswordFocus),
                validator: (v) =>
                    v!.isEmpty ? localizations.enterPassword : null,
              ),
              const SizedBox(height: 16),
              AppTextFormField(
                enabled: true,
                label: localizations.password,
                controller: _newPasswordController,
                isPassword: true,
                focusNode: _newPasswordFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_confirmPasswordFocus),
                validator: (v) {
                  if (v == null || v.isEmpty) return localizations.enterPassword;
                  if (v.length < 6) return localizations.shortPassword;
                  if (!RegExp(r'[A-Z]').hasMatch(v)) {
                    return localizations.passwordNeedsUppercase;
                  }
                  if (!RegExp(r'[a-z]').hasMatch(v)) {
                    return localizations.passwordNeedsLowercase;
                  }
                  if (!RegExp(r'[0-9]').hasMatch(v)) {
                    return localizations.passwordNeedsNumber;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextFormField(
                enabled: true,
                label: localizations.confirmPassword,
                controller: _confirmNewPasswordController,
                isPassword: true,
                focusNode: _confirmPasswordFocus,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (_formKey.currentState!.validate()) {
                    context.read<AuthCubit>().changePassword(
                      _oldPasswordController.text,
                      _newPasswordController.text,
                      context,
                    );
                  }
                },
                validator: (v) {
                  if (v != _newPasswordController.text) {
                    return AppLocalizations.of(context)!.passwordMismatch;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  final isLoading = state is AuthLoading;
                  return AppCustomButton(
                    isLoading: isLoading,
                    onPressed: isLoading ? () {} : () {
                      if (_formKey.currentState!.validate()) {
                        context.read<AuthCubit>().changePassword(
                          _oldPasswordController.text,
                          _newPasswordController.text,
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
  }
}
