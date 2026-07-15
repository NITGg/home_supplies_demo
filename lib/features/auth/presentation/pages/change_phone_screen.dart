import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/app_dynamic_settings.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/profile_cubit.dart';
import '../../manager/profile_states.dart';

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _otpSent = false;
  String? _newPhone;
  String? _oldPhone;

  final _newOtpController = TextEditingController();
  final _oldOtpController = TextEditingController();

  late int _otpLength;
  late int _resendSeconds;
  int _secondsRemaining = 0;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _otpLength = AppSettings.otp_length ?? 4;
    _resendSeconds = AppSettings.otp_resend_duration_seconds ?? 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _newOtpController.dispose();
    _oldOtpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = _resendSeconds;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void _requestOtp() {
    if (!_formKey.currentState!.validate()) return;
    final phone = normalizeEgyptPhone(_phoneController.text.trim());
    context.read<ProfileCubit>().requestChangePhone(newPhone: phone);
  }

  void _verifyOtp() {
    final newOtp = _newOtpController.text.trim();
    final oldOtp = _oldOtpController.text.trim();

    if (newOtp.length != _otpLength) {
      showErrorBanner(context, 'Please enter the complete OTP for your new number');
      return;
    }
    if (_oldPhone != null && oldOtp.length != _otpLength) {
      showErrorBanner(context, 'Please enter the complete OTP for your current number');
      return;
    }

    context.read<ProfileCubit>().verifyChangePhone(
      newPhone: _newPhone!,
      newOtp: newOtp,
      oldPhone: _oldPhone,
      oldOtp: _oldPhone != null ? oldOtp : null,
    );
  }

  void _resendOtp() {
    if (!_canResend) return;
    _newOtpController.clear();
    _oldOtpController.clear();
    context.read<ProfileCubit>().resendChangePhoneOtp(
      newPhone: _newPhone!,
      oldPhone: _oldPhone,
    );
    _startTimer();
  }

  void _handleState(BuildContext context, ProfileState state) {
    if (state is ProfileChangePhoneOtpSent) {
      setState(() {
        _otpSent = true;
        _newPhone = state.newPhone;
        _oldPhone = state.oldPhone;
      });
      _startTimer();
    } else if (state is ProfileChangePhoneSuccess) {
      showSuccessBanner(context, state.message);
      context.pop();
    } else if (state is ProfileChangePhoneOtpResent) {
      showSuccessBanner(context, state.message);
    } else if (state is ProfileFailure) {
      showErrorBanner(context, state.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: AppTextStyles.bold18.copyWith(color: Colors.black),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
    );
    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.kPrimaryColor, width: 2),
    );
    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: AppColors.kPrimaryColor.withOpacity(0.1),
        border: Border.all(color: AppColors.kPrimaryColor),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.changePhone),
        centerTitle: true,
        leading: _otpSent
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _otpSent = false;
                  _newOtpController.clear();
                  _oldOtpController.clear();
                  _timer?.cancel();
                }),
              )
            : const BackButton(),
      ),
      body: SafeArea(
        top: false,
        child: BlocConsumer<ProfileCubit, ProfileState>(
          listener: _handleState,
          builder: (context, state) {
            final isLoading = state is ProfileLoading;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: _otpSent ? _buildOtpStep(context, loc, isLoading, defaultPinTheme, focusedPinTheme, submittedPinTheme) : _buildPhoneStep(context, loc, isLoading),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhoneStep(BuildContext context, AppLocalizations loc, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            loc.enterNewPhone,
            style: AppTextStyles.regular14.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AppTextFormField(
            controller: _phoneController,
            label: loc.phone,
            isPhone: true,
            enabled: !isLoading,
          ),
          const SizedBox(height: 24),
          AppCustomButton(
            text: loc.sendOtp,
            isLoading: isLoading,
            onPressed: isLoading ? () {} : _requestOtp,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOtpStep(
    BuildContext context,
    AppLocalizations loc,
    bool isLoading,
    PinTheme defaultPin,
    PinTheme focusedPin,
    PinTheme submittedPin,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          Text(loc.enterOtpSent, style: AppTextStyles.bold18, textAlign: TextAlign.center),

          const SizedBox(height: 8),

          Text(
            _newPhone ?? '',
            textDirection: TextDirection.ltr,
            style: AppTextStyles.bold16.copyWith(color: AppColors.kPrimaryColor),
          ),

          const SizedBox(height: 32),

          Text(loc.newPhoneOtp, style: AppTextStyles.bold14),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Pinput(
              controller: _newOtpController,
              length: _otpLength,
              defaultPinTheme: defaultPin,
              focusedPinTheme: focusedPin,
              submittedPinTheme: submittedPin,
              showCursor: true,
              enabled: !isLoading,
            ),
          ),

          if (_oldPhone != null) ...[
            const SizedBox(height: 24),
            Text(loc.currentPhoneOtp, style: AppTextStyles.bold14),
            const SizedBox(height: 4),
            Text(
              _oldPhone!,
              textDirection: TextDirection.ltr,
              style: AppTextStyles.regular14.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Pinput(
                controller: _oldOtpController,
                length: _otpLength,
                defaultPinTheme: defaultPin,
                focusedPinTheme: focusedPin,
                submittedPinTheme: submittedPin,
                showCursor: true,
                enabled: !isLoading,
              ),
            ),
          ],

          const SizedBox(height: 24),

          _canResend
              ? TextButton(
                  onPressed: isLoading ? null : _resendOtp,
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
            text: loc.verify,
            isLoading: isLoading,
            onPressed: isLoading ? () {} : _verifyOtp,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
