import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

class ForgotPasswordScreenV2 extends StatefulWidget {
  const ForgotPasswordScreenV2({super.key});

  @override
  State<ForgotPasswordScreenV2> createState() =>
      _ForgotPasswordScreenV2State();
}

class _ForgotPasswordScreenV2State extends State<ForgotPasswordScreenV2> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.forgotPassword), centerTitle: true),
      body: SafeArea(
        top: false,
        child: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthForgotPasswordOtpSent) {
              context.read<AuthCubit>().reset();
              final phone = state.phone;
              context.push(
                '/auth/new-password-v2',
                extra: {
                  'identifier': phone,
                  'channel': 'phone',
                  'destination': phone,
                },
              );
            } else if (state is AuthFailure) {
              showErrorBanner(context, state.message);
            }
          },
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final isLoading = state is AuthLoading;
              return _buildForm(context, loc, isLoading);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations loc,
    bool isLoading,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),

            Text(
              loc.enterPhoneToResetPassword,
              style: AppTextStyles.regular14.copyWith(color: Colors.grey),
            ),

            const SizedBox(height: 24),

            AppTextFormField(
              controller: _phoneController,
              label: loc.phone,
              isPhone: true,
              enabled: !isLoading,
            ),

            const SizedBox(height: 20),

            AppCustomButton(
              text: loc.sendOtp,
              isLoading: isLoading,
              onPressed: isLoading ? () {} : () {
                if (!_formKey.currentState!.validate()) return;
                final phone = normalizeEgyptPhone(_phoneController.text.trim());
                dLog('Requesting password reset for $phone');
                context.read<AuthCubit>().forgotPassword(phone);
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
