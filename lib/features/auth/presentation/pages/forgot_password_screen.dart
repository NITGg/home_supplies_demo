import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _usePhone = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final value = _controller.text.trim();
    String? phone;
    String? email;

    if (_usePhone) {
      phone = value.startsWith('+2') ? value : '+2$value';
    } else {
      email = value;
    }

    dLog('Requesting password reset — phone: $phone  email: $email');
    context.read<AuthCubit>().forgotPassword(phone: phone, email: email);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.forgotPassword), centerTitle: true),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthForgotPasswordOtpSent) {
            context.read<AuthCubit>().reset();
            context.push(
              '/auth/new-password',
              extra: {
                'identifier': state.destination,
                'destination': state.destination,
                'via': state.via,
              },
            );
          } else if (state is AuthFailure) {
            showErrorBanner(context, state.message);
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),

                    Text(
                      loc.enterPhoneToResetPassword,
                      style:
                      AppTextStyles.regular14.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // ── Toggle ──────────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _ToggleTab(
                            label: loc.phone,
                            selected: _usePhone,
                            onTap: () {
                              if (!_usePhone) {
                                setState(() {
                                  _usePhone = true;
                                  _controller.clear();
                                });
                              }
                            },
                          ),
                          _ToggleTab(
                            label: loc.email,
                            selected: !_usePhone,
                            onTap: () {
                              if (_usePhone) {
                                setState(() {
                                  _usePhone = false;
                                  _controller.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Input ───────────────────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _usePhone
                          ? AppTextFormField(
                        key: const ValueKey('phone'),
                        controller: _controller,
                        label: loc.phone,
                        isPhone: true,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return loc.enterPhoneNumber;
                          } else if (value.length != 11 ||
                              !value.startsWith('01')) {
                            return loc.invalidPhoneNumber;
                          }
                          return null;
                        },
                      )
                          : AppTextFormField(
                        key: const ValueKey('email'),
                        controller: _controller,
                        label: loc.email,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return loc.email;
                          }
                          final emailRegex = RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(value)) {
                            return loc.invalidEmail;
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // isLoading passed directly — no dialog needed
                    AppCustomButton(
                      text: loc.sendOtp,
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Toggle tab ────────────────────────────────────────────────────────────────

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.kPrimaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.bold14.copyWith(
              color: selected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}