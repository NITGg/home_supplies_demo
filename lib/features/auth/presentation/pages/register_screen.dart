import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../core/widgets/text_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';
import '../widgets/auth_header.dart';
import '../widgets/social_auth_button_row.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // FocusNodes
  final FocusNode firstNameFocus = FocusNode();
  final FocusNode lastNameFocus = FocusNode();
  final FocusNode emailFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  final FocusNode confirmPasswordFocus = FocusNode();

  final TextEditingController firstNameController = TextEditingController();

  final TextEditingController lastNameController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    firstNameFocus.dispose();
    lastNameFocus.dispose();
    emailFocus.dispose();
    phoneFocus.dispose();
    passwordFocus.dispose();
    confirmPasswordFocus.dispose();

    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      String phone = normalizeEgyptPhone(phoneController.text.trim());

      context.read<AuthCubit>().register(
        context: context,
        email: emailController.text.isEmpty ? null : emailController.text,
        phone: phone,
        password: passwordController.text,
        fullName: '${firstNameController.text} ${lastNameController.text}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthLoading) {
            showDialog(
              context: context,
              useSafeArea: false,
              barrierDismissible: false,
              builder: (dialogContext) => const Center(child: LoadingScreen()),
            );
          } else if (state is AuthSuccess) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            context.go('/mainHome');
          } else if (state is AuthFailure) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(color: AppColors.kBackgroundColor, height: 48),
                      AuthHeaderImage(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                bottom: 10,
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.register,
                                style: AppTextStyles.bold14,
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 22),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  AppTextFormField(
                                    focusNode: firstNameFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) {
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(lastNameFocus);
                                    },
                                    label:
                                        '${AppLocalizations.of(context)!.firstName} *',
                                    controller: firstNameController,
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 18),
                                  AppTextFormField(
                                    focusNode: lastNameFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) {
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(emailFocus);
                                    },
                                    label:
                                        '${AppLocalizations.of(context)!.lastName} *',
                                    controller: lastNameController,
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 18),
                                  AppTextFormField(
                                    focusNode: emailFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) {
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(phoneFocus);
                                    },
                                    label: AppLocalizations.of(context)!.email,
                                    controller: emailController,
                                    validator: (v) {
                                      if (v!.isEmpty) return null; // optional
                                      final emailRegex = RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                      );
                                      if (!emailRegex.hasMatch(v)) {
                                        return AppLocalizations.of(
                                          context,
                                        )!.invalidEmail;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  AppTextFormField(
                                    focusNode: phoneFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) {
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(passwordFocus);
                                    },
                                    label:
                                        '${AppLocalizations.of(context)!.phone} *',
                                    controller: phoneController,
                                    isPhone: true,
                                  ),
                                  const SizedBox(height: 18),
                                  AppTextFormField(
                                    focusNode: passwordFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) {
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(confirmPasswordFocus);
                                    },
                                    label: AppLocalizations.of(
                                      context,
                                    )!.password,
                                    controller: passwordController,
                                    isPassword: true,
                                    validator: (v) {
                                      if (v!.length < 6) {
                                        return AppLocalizations.of(
                                          context,
                                        )!.shortPassword;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  AppTextFormField(
                                    focusNode: confirmPasswordFocus,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) {
                                      if (_formKey.currentState!.validate()) {
                                        _submit();
                                      }
                                    },
                                    label: AppLocalizations.of(
                                      context,
                                    )!.confirmPassword,
                                    controller: confirmPasswordController,
                                    isPassword: true,
                                    validator: (v) {
                                      if (v != passwordController.text) {
                                        return AppLocalizations.of(
                                          context,
                                        )!.passwordMismatch;
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.orRegisterwith,
                              style: AppTextStyles.regular14.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const SocialAuthButtons(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(AppLocalizations.of(context)!.iAgreeTo, style: AppTextStyles.regular14),
                                const SizedBox(width: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AppTextButton(
                                      text: AppLocalizations.of(context)!.termsAndConditions,
                                      color: AppColors.kPrimaryColor,
                                      underline: true,
                                      onPressed: () => context.push('/Terms'),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text('&', style: AppTextStyles.regular14),
                                    ),
                                    AppTextButton(
                                      text: AppLocalizations.of(context)!.privecyPolicy,
                                      color: AppColors.kPrimaryColor,
                                      underline: true,
                                      onPressed: () => context.push('/PrivacyPage'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppCustomButton(
                      text: AppLocalizations.of(context)!.register,
                      onPressed: () {
                        _submit();
                      },
                    ),
                    Row(
                      spacing: 5,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.haveAccount,
                          style: AppTextStyles.bold14,
                        ),
                        AppTextButton(
                          text: AppLocalizations.of(context)!.signin,
                          color: AppColors.kPrimaryColor,
                          underline: true,
                          onPressed: () => context.go('/auth/login'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
