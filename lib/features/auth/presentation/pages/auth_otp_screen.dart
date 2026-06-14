import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

class OtpVerificationScreen extends StatefulWidget {
  /// Phone number OR email — whatever the user entered on the previous screen.
  final String destination;
  /// "phone" or "email" — tells the screen which channel to verify.
  final String via;

  const OtpVerificationScreen({
    super.key,
    required this.destination,
    this.via = 'phone',
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _otpLength = 4;

  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  int _secondsRemaining = 60;
  bool _canResend = false;
  bool _hasNavigated = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthCubit>().reset();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  // ─── Timer ────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _canResend = true);
        t.cancel();
      }
    });
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  void _verify() {
    final otp = _otpController.text.trim();
    if (otp.length != _otpLength) {
      showErrorBanner(context, 'Please enter the complete OTP');
      return;
    }

    // Registration flow — verify OTP via the correct channel.
    final isEmail = widget.via == 'email';
    context.read<AuthCubit>().verifyRegistrationOtp(
      phone: isEmail ? null : widget.destination,
      email: isEmail ? widget.destination : null,
      code: otp,
    );
  }

  void _resend() {
    if (!_canResend) return;
    _otpController.clear();

    final isEmail = widget.via == 'email';
    context.read<AuthCubit>().resendRegistrationOtp(
      phone: isEmail ? null : widget.destination,
      email: isEmail ? widget.destination : null,
    );
    _startTimer();
  }

  // ─── Bloc listener ────────────────────────────────────────────────────────

  void _onState(BuildContext ctx, AuthState state) {
    if (_hasNavigated) return;
    dLog('OtpVerificationScreen — \${state.runtimeType}');

    if (state is AuthSuccess) {
      _hasNavigated = true;
      ctx.go('/mainHome');
    } else if (state is AuthNextOtpRequired) {
      // One channel done, another still pending — push a new OTP screen.
      _hasNavigated = true;
      ctx.pushReplacement(
        '/auth/verify-otp',
        extra: {
          'destination': state.destination,
          'via': state.via,
        },
      );
    } else if (state is AuthOtpResent) {
      showSuccessBanner(ctx, state.message);
    } else if (state is AuthFailure) {
      showErrorBanner(ctx, state.message);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final defaultPin = PinTheme(
      width: 52,
      height: 56,
      textStyle: AppTextStyles.bold18.copyWith(color: Colors.black),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return BlocConsumer<AuthCubit, AuthState>(
      listener: _onState,
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          appBar: AppBar(
            title: Text(loc.verifyPhone),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.kPrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 48,
                    color: AppColors.kPrimaryColor,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  loc.enterOtpSent,
                  style: AppTextStyles.bold18,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  widget.destination.isNotEmpty
                      ? widget.destination
                      : (widget.via == 'email' ? loc.email : loc.phone),
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.bold16
                      .copyWith(color: AppColors.kPrimaryColor),
                ),

                const SizedBox(height: 40),

                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Pinput(
                    length: _otpLength,
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    enabled: !isLoading,
                    defaultPinTheme: defaultPin,
                    focusedPinTheme: defaultPin.copyDecorationWith(
                      border: Border.all(
                        color: AppColors.kPrimaryColor,
                        width: 2,
                      ),
                    ),
                    submittedPinTheme: defaultPin.copyWith(
                      decoration: defaultPin.decoration?.copyWith(
                        color: AppColors.kPrimaryColor.withOpacity(0.1),
                        border: Border.all(color: AppColors.kPrimaryColor),
                      ),
                    ),
                    onCompleted: (_) {
                      if (!isLoading) _verify();
                    },
                  ),
                ),

                const SizedBox(height: 24),

                _canResend
                    ? TextButton(
                  onPressed: isLoading ? null : _resend,
                  child: Text(
                    loc.resendOtp,
                    style: AppTextStyles.bold14.copyWith(
                      color: isLoading
                          ? Colors.grey
                          : AppColors.kPrimaryColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
                    : Text(
                  '${loc.resendOtpIn} $_secondsRemaining ${loc.seconds}',
                  style: AppTextStyles.regular14
                      .copyWith(color: Colors.grey),
                ),

                const SizedBox(height: 40),

                AppCustomButton(
                  text: loc.confirm,
                  isLoading: isLoading,
                  onPressed: _verify,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}