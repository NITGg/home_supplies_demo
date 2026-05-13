import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/banners.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../core/widgets/text_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/auth_header.dart';
import '../widgets/social_auth_button_row.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

class LoginScreen extends StatefulWidget {
  final bool? isAccountDeleted;

  const LoginScreen({super.key, this.isAccountDeleted});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FocusNode phoneFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool hasShownDialog = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if ((widget.isAccountDeleted ?? false) && !hasShownDialog) {
      hasShownDialog = true;
      Future.delayed(Duration.zero, () {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) => const DeletedAccountAlert(),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    phoneFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthLoading) {
            showDialog(
              useSafeArea: false,
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => const Center(child: LoadingScreen()),
            );
          } else if (state is AuthOtpRequired) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            context.push('/auth/verify-otp', extra: state.phone);
          } else if (state is AuthRoleNotAllowed) {
            showErrorBanner(context, state.message);
            context.pop();
          } else if (state is AuthSuccess) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            if (mounted) context.go('/mainHome');
          } else if (state is AuthForgotPasswordOtpSent ||
              state is AuthUpdateSuccess ||
              state is AuthProfileDeleted ||
              state is AuthInitial) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          } else if (state is AuthForgotPasswordOtpSent) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          } else if (state is AuthFailure) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            showErrorBanner(context, state.message);
          }
        },
        child: Directionality(
          textDirection: Directionality.of(context),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const Spacer(),

                      AuthHeaderImage(),

                      const Divider(),
                      const SizedBox(height: 22),

                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            AppTextFormField(
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(passwordFocus);
                              },
                              focusNode: phoneFocus,
                              controller: phoneController,
                              label: loc.phone,
                              isPhone: true,
                            ),
                            const SizedBox(height: 18),
                            AppTextFormField(
                              focusNode: passwordFocus,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (_formKey.currentState!.validate()) {
                                  String phone = normalizeEgyptPhone(
                                    phoneController.text.trim(),
                                  );
                                  context.read<AuthCubit>().login(
                                    phone: phone,
                                    password: passwordController.text.trim(),
                                  );
                                }
                              },
                              controller: passwordController,
                              label: loc.password,
                              isPassword: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return loc.enterPassword;
                                } else if (value.length < 6) {
                                  return loc.shortPassword;
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      Text(
                        loc.orSignInwith,
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),

                      const SocialAuthButtons(),

                      const SizedBox(height: 28),

                      AppCustomButton(
                        text: loc.signin,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            String phone = phoneController.text.trim();
                            if (!phone.startsWith('+2')) phone = '+2$phone';

                            authCubit.login(
                              phone: phone,
                              password: passwordController.text.trim(),
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 12),
                      AppTextButton(
                        text: loc.browseAsGuest,
                        color: AppColors.kPrimaryColor,
                        underline: true,
                        onPressed: () => context.go('/mainHome'),
                      ),
                      const SizedBox(height: 24),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.iAgreeTo,
                            style: AppTextStyles.regular14,
                          ),
                          const SizedBox(width: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppTextButton(
                                text: AppLocalizations.of(
                                  context,
                                )!.termsAndConditions,
                                color: AppColors.kPrimaryColor,
                                underline: true,
                                onPressed: () => context.push('/Terms'),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  '&',
                                  style: AppTextStyles.regular14,
                                ),
                              ),
                              AppTextButton(
                                text: AppLocalizations.of(
                                  context,
                                )!.privecyPolicy,
                                color: AppColors.kPrimaryColor,
                                underline: true,
                                onPressed: () => context.push('/PrivacyPage'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            loc.dontHaveAccount,
                            style: AppTextStyles.bold14,
                          ),
                          const SizedBox(width: 5),
                          AppTextButton(
                            text: loc.register,
                            color: AppColors.kPrimaryColor,
                            underline: true,
                            onPressed: () => context.go('/auth/register'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeletedAccountAlert extends StatelessWidget {
  const DeletedAccountAlert({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: Colors.white,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/images/checkmark.svg'),
          const SizedBox(height: 10),
          Text(
            loc.accountDeletedSuccess,
            style: AppTextStyles.bold18,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: <Widget>[
        Column(
          children: [
            AppCustomButton(
              onPressed: () => SystemNavigator.pop(),
              text: loc.closeApp,
              isSecondary: true,
            ),
          ],
        ),
      ],
    );
  }
}