import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart' show rootNavigatorKey;
import '../../manager/profile_cubit.dart';
import '../../manager/profile_states.dart';

class ProfileOtpScreen extends StatefulWidget {
  /// Current contact value (OTP sent here for ownership confirmation).
  /// Null or empty means no old contact exists — only the new OTP is shown.
  final String? oldDestination;

  /// New contact value (OTP sent here to confirm it belongs to the user).
  final String newDestination;

  /// Called only after OTP(s) are confirmed successfully on the backend.
  final VoidCallback? onConfirmed;

  /// When set, the screen is in single-code mode (no old contact).
  /// Called with just the new OTP code; skips the old-contact PIN entirely
  /// and uses /auth/verify-account instead of /auth/verify-old-new-phone-email.
  final void Function(String code)? onSingleVerify;

  const ProfileOtpScreen({
    super.key,
    this.oldDestination,
    required this.newDestination,
    this.onConfirmed,
    this.onSingleVerify,
  });

  @override
  State<ProfileOtpScreen> createState() => _ProfileOtpScreenState();
}

class _ProfileOtpScreenState extends State<ProfileOtpScreen> {
  static const int _otpLength = 4;

  final _oldOtpController = TextEditingController();
  final _newOtpController = TextEditingController();
  final _oldFocusNode     = FocusNode();
  final _newFocusNode     = FocusNode();

  bool get _hasOldContact =>
      widget.oldDestination != null && widget.oldDestination!.isNotEmpty;

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
    _oldOtpController.dispose();
    _newOtpController.dispose();
    _oldFocusNode.dispose();
    _newFocusNode.dispose();
    super.dispose();
  }

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

  void _showError(String message) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null) showErrorBanner(ctx, message);
  }

  void _verify() {
    final newOtp = _newOtpController.text.trim();

    if (newOtp.length != _otpLength) {
      _showError(AppLocalizations.of(context)!.required);
      return;
    }

    // Single-code mode: first-time contact addition, no old code needed.
    if (widget.onSingleVerify != null) {
      dLog('ProfileOtpScreen: single verify new=$newOtp');
      widget.onSingleVerify!(newOtp);
      return;
    }

    // Two-code mode: changing an existing contact.
    final oldOtp = _oldOtpController.text.trim();
    if (_hasOldContact && oldOtp.length != _otpLength) {
      _showError(AppLocalizations.of(context)!.required);
      return;
    }

    dLog('ProfileOtpScreen: two-code verify hasOld=$_hasOldContact old=$oldOtp new=$newOtp');
    context.read<ProfileCubit>().verifyContactChange(
      oldCode: _hasOldContact ? oldOtp : '',
      newCode: newOtp,
    );
  }

  void _onState(BuildContext ctx, ProfileState state) {
    final rootCtx = rootNavigatorKey.currentContext;
    if (state is ProfileOtpConfirmSuccess) {
      if (state.message.isNotEmpty && rootCtx != null) {
        showSuccessBanner(rootCtx, state.message);
      }
      widget.onConfirmed?.call();
      Navigator.pop(ctx);
    } else if (state is ProfileFailure) {
      if (rootCtx != null) showErrorBanner(rootCtx, state.message);
    }
  }

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

    final focusedPin = defaultPin.copyDecorationWith(
      border: Border.all(color: AppColors.kPrimaryColor, width: 2),
    );

    final submittedPin = defaultPin.copyWith(
      decoration: defaultPin.decoration?.copyWith(
        color: AppColors.kPrimaryColor.withOpacity(0.1),
        border: Border.all(color: AppColors.kPrimaryColor),
      ),
    );

    return BlocListener<ProfileCubit, ProfileState>(
      listener: _onState,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.verify),
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
                  const SizedBox(height: 24),

                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.kPrimaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 40,
                      color: AppColors.kPrimaryColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Old contact PIN (only when an old contact exists) ────
                  if (_hasOldContact) ...[
                    _SectionLabel(
                      title: loc.enterOtpSent,
                      destination: widget.oldDestination!,
                    ),
                    const SizedBox(height: 16),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Pinput(
                        length: _otpLength,
                        controller: _oldOtpController,
                        focusNode: _oldFocusNode,
                        enabled: !isLoading,
                        defaultPinTheme: defaultPin,
                        focusedPinTheme: focusedPin,
                        submittedPinTheme: submittedPin,
                        onCompleted: (_) {
                          if (!isLoading) _newFocusNode.requestFocus();
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ── New contact PIN ──────────────────────────────────────
                  _SectionLabel(
                    title: loc.enterOtpSent,
                    destination: widget.newDestination,
                  ),
                  const SizedBox(height: 16),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Pinput(
                      length: _otpLength,
                      controller: _newOtpController,
                      focusNode: _newFocusNode,
                      enabled: !isLoading,
                      defaultPinTheme: defaultPin,
                      focusedPinTheme: focusedPin,
                      submittedPinTheme: submittedPin,
                      onCompleted: (_) {
                        // Auto-submit when this is the only PIN on screen
                        if (!isLoading && (!_hasOldContact || _oldOtpController.text.trim().length == _otpLength)) {
                          _verify();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  _canResend
                      ? TextButton(
                          onPressed: isLoading ? null : _startTimer,
                          child: Text(
                            loc.resendOtp,
                            style: AppTextStyles.bold14.copyWith(
                              color: isLoading ? Colors.grey : AppColors.kPrimaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        )
                      : Text(
                          '${loc.resendOtpIn} $_secondsRemaining ${loc.seconds}',
                          style: AppTextStyles.regular14.copyWith(color: Colors.grey),
                        ),

                  const SizedBox(height: 32),

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

class _SectionLabel extends StatelessWidget {
  final String title;
  final String destination;

  const _SectionLabel({required this.title, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: AppTextStyles.bold16, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          destination,
          textDirection: TextDirection.ltr,
          style: AppTextStyles.bold14.copyWith(color: AppColors.kPrimaryColor),
        ),
      ],
    );
  }
}
