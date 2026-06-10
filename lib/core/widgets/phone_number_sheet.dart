import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/manager/profile_cubit.dart';
import '../../features/auth/manager/profile_states.dart';
import '../../features/auth/presentation/pages/otp_screen.dart';
import '../../l10n/app_localizations.dart';
import '../style/text_styles.dart';
import 'custom_button.dart';
import 'text_form.dart';

/// Returns true if the current user already has a phone number on file.
bool hasPhoneNumber(BuildContext context) {
  final state = context.read<ProfileCubit>().state;
  return state is ProfileLoaded && state.profile.phone != null;
}

/// Ensures the current user has a phone number, prompting for one if missing.
///
/// Returns true if the user already has a phone number (caller can proceed),
/// or false if the phone number bottom sheet was shown instead.
Future<bool> ensurePhoneNumber(BuildContext context) async {
  if (hasPhoneNumber(context)) return true;
  await showPhoneNumberBottomSheet(context);
  return false;
}

Future<void> showPhoneNumberBottomSheet(BuildContext context) async {
  final parentContext = context;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => PhoneNumberSheet(parentContext: parentContext),
  );
}

class PhoneNumberSheet extends StatefulWidget {
  final BuildContext parentContext;

  const PhoneNumberSheet({super.key, required this.parentContext});

  @override
  State<PhoneNumberSheet> createState() => _PhoneNumberSheetState();
}

class _PhoneNumberSheetState extends State<PhoneNumberSheet> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _errorMessage;
  bool _submitted = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _submitted = true;
    });
    String phone = _phoneController.text.trim();
    if (!phone.startsWith('+2')) phone = '+2$phone';
    widget.parentContext.read<ProfileCubit>().changePhone(phone: phone);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocListener<ProfileCubit, ProfileState>(
      bloc: widget.parentContext.read<ProfileCubit>(),
      listener: (_, state) {
        if (!_submitted) return;
        if (state is ProfilePhoneOtpSent) {
          if (mounted) {
            Navigator.pop(context);
            Navigator.push(
              widget.parentContext,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: widget.parentContext.read<ProfileCubit>(),
                  child: ProfileOtpScreen(
                    newDestination: state.destination,
                    onConfirmed: () =>
                        widget.parentContext.read<ProfileCubit>().fetchProfile(),
                    onSingleVerify: (code) => widget.parentContext
                        .read<ProfileCubit>()
                        .confirmPhoneOtp(code: code),
                  ),
                ),
              ),
            );
          }
        } else if (state is ProfileFailure) {
          if (mounted) {
            setState(() {
              _loading = false;
              _errorMessage = state.message;
            });
          }
        } else if (state is ProfileLoading) {
          if (mounted) setState(() => _loading = true);
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.enterPhoneNumber, style: AppTextStyles.bold18),
            const SizedBox(height: 8),
            Text(
              localizations.weNeedYourPhoneNumber,
              style: AppTextStyles.regular14.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: AppTextFormField(
                label: localizations.phone,
                controller: _phoneController,
                isPhone: true,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 14,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            AppCustomButton(
              onPressed: _loading ? () {} : _submit,
              text: localizations.confirm,
              isLoading: _loading,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
