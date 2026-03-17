import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/profile_cubit.dart';
import '../../manager/profile_states.dart';

class ProfileOtpScreen extends StatefulWidget {
  /// The masked destination shown to the user (e.g. "a***@mail.com" or "+9665***").
  final String destination;

  /// Called only after OTP is confirmed successfully on the backend.
  /// Use this to continue any pending work (e.g. updateProfile).
  final VoidCallback? onConfirmed;

  const ProfileOtpScreen({
    super.key,
    required this.destination,
    this.onConfirmed,
  });

  @override
  State<ProfileOtpScreen> createState() => _ProfileOtpScreenState();
}

class _ProfileOtpScreenState extends State<ProfileOtpScreen> {
  static const int _otpLength = 6;

  final _otpController = TextEditingController();
  final _otpFocusNode  = FocusNode();

  int  _secondsRemaining = 60;
  bool _canResend        = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
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
      _canResend        = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
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
      _showSnack(
        AppLocalizations.of(context)!.required, // reuse or add dedicated key
        Colors.red,
      );
      return;
    }
    log('ProfileOtpScreen: verifying OTP for ${widget.destination}');
    context.read<ProfileCubit>().confirmOtp(code: otp);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ─── State listener ───────────────────────────────────────────────────────

  void _onState(BuildContext ctx, ProfileState state) {
    if (state is ProfileOtpConfirmSuccess) {
      _showSnack(state.message, Colors.green);
      widget.onConfirmed?.call(); // ← continue pending work
      Navigator.pop(ctx);         // ← close OTP screen
    } else if (state is ProfileFailure) {
      _showSnack(state.message, Colors.red);
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

    return BlocListener<ProfileCubit, ProfileState>(
      listener: _onState,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.verify), // reuse key or add verifyOtp key
          centerTitle: true,
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            final isLoading = state is ProfileLoading;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // ── Icon ──────────────────────────────────────────────────
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

                  // ── Subtitle ──────────────────────────────────────────────
                  Text(
                    loc.enterOtpSent, // "Enter the OTP sent to"
                    style: AppTextStyles.bold18,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.destination,
                    style: AppTextStyles.bold16
                        .copyWith(color: AppColors.kPrimaryColor),
                  ),

                  const SizedBox(height: 40),

                  // ── Pin input ─────────────────────────────────────────────
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
                      onCompleted: (_) { if (!isLoading) _verify(); },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Resend timer ──────────────────────────────────────────
                  _canResend
                      ? TextButton(
                    onPressed: isLoading ? null : _startTimer,
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

                  // ── Confirm button ────────────────────────────────────────
                  AppCustomButton(
                    text: loc.confirm,
                    isLoading: isLoading,
                    onPressed: _verify,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}