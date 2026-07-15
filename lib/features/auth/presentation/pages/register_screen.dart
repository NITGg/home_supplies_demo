import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/image_picker_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../core/widgets/text_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/vehicles_model.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';
import '../../../auth/data/models/social_registration_data.dart';

// ─── Bilingual helpers ────────────────────────────────────────────────────────

String _bi(String ar, String en) => '$ar\n$en';

class RegisterScreen extends StatefulWidget {
  /// Non-null when arriving from a social login 401 redirect.
  final SocialRegistrationData? socialData;

  const RegisterScreen({super.key, this.socialData});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ScrollController _scrollController = ScrollController();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  int _currentStep = 0;
  bool _isPeekingStep2 = false;
  bool _isProcessing = false;
  bool _agreedToTerms = false;
  bool _over18 = false;

  // Step 1
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  File? personalPhoto;
  bool isMale = true;

  // Step 2
  final vehiclePlateController = TextEditingController();
  final nationalIdNumberController = TextEditingController();
  final nationalIdDoc = TwoSidedDoc();
  final vehicleLicenseDoc = TwoSidedDoc();
  final courierLicenseDoc = TwoSidedDoc();
  File? criminalRecord; // optional, single image

  int? selectedVehicleId;

  // ─── Helpers ─────────────────────────────────────────────────────────────

  bool get _isSocialMode => widget.socialData != null;

  bool get _isBike {
    final vehicles = context.read<AuthCubit>().availableVehicles;
    final selected = vehicles
        .where((v) => v.id == selectedVehicleId)
        .firstOrNull;
    final name = selected?.name.toLowerCase() ?? '';
    return name.contains('bike') ||
        name.contains('bicycle') ||
        name.contains('on-foot') ||
        name.contains('onfoot');
  }

  final firstNameFocus = FocusNode();
  final lastNameFocus = FocusNode();
  final phoneFocus = FocusNode();
  final passwordFocus = FocusNode();
  final confirmPasswordFocus = FocusNode();
  final nationalIdNumberFocus = FocusNode();

  // ─── Init ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    final cubit = context.read<AuthCubit>();
    if (cubit.availableVehicles.isEmpty) cubit.fetchAvailableVehicles();

    _prefillSocialData();
  }

  Future<void> _prefillSocialData() async {
    final social = widget.socialData;
    if (social == null) return;

    final parts = (social.fullName ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      firstNameController.text = parts.first;
      if (parts.length > 1) {
        lastNameController.text = parts.sublist(1).join(' ');
      }
    }

    if (social.photoUrl != null && social.photoUrl!.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(social.photoUrl!));
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/social_profile_photo.jpg');
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) setState(() => personalPhoto = file);
      } catch (e) {
        debugPrint('Could not download social profile photo: $e');
      }
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    vehiclePlateController.dispose();
    firstNameFocus.dispose();
    lastNameFocus.dispose();
    phoneFocus.dispose();
    passwordFocus.dispose();
    confirmPasswordFocus.dispose();
    _scrollController.dispose();
    nationalIdNumberController.dispose();
    nationalIdNumberFocus.dispose();
    super.dispose();
  }

  // ─── Validation ───────────────────────────────────────────────────────────

  bool _validateStep1() {
    if (!_formKeyStep1.currentState!.validate()) return false;
    if (personalPhoto == null && Platform.isAndroid) {
      showErrorBanner(
        context,
        _bi(AppLocalizations.of(context)!.selectPersonalPhoto, ''),
      );
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    final loc = AppLocalizations.of(context)!;
    if (!_formKeyStep2.currentState!.validate()) return false;

    if (nationalIdNumberController.text.trim().length != 14 ||
        !RegExp(r'^\d{14}$').hasMatch(nationalIdNumberController.text.trim())) {
      showErrorBanner(
        context,
        _bi('${loc.nationalId}: ${loc.mustBe14Digits}', ''),
      );
      return false;
    }

    if (selectedVehicleId == null) {
      showErrorBanner(context, _bi('${loc.vehicleType}: ${loc.required}', ''));
      return false;
    }

    if (!nationalIdDoc.isComplete) {
      showErrorBanner(
        context,
        _bi('${loc.nationalIdPhoto}: ${loc.frontAndBackRequired}', ''),
      );
      return false;
    }

    if (!_isBike && !vehicleLicenseDoc.isComplete) {
      showErrorBanner(
        context,
        _bi('${loc.vehicleLicense}: ${loc.frontAndBackRequired}', ''),
      );
      return false;
    }

    if (!_isBike && !courierLicenseDoc.isComplete) {
      showErrorBanner(
        context,
        _bi('${loc.courierLicense}: ${loc.frontAndBackRequired}', ''),
      );
      return false;
    }

    return true;
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submitRegistration() async {
    if (_isProcessing) return;
    if (!_validateStep2()) return;

    setState(() => _isProcessing = true);

    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: LoadingScreen()),
        );
      }

      final isArabic = Localizations.localeOf(context).languageCode == 'ar';

      // ── Resolve front/back files directly — no stitching ─────────────────
      final nationalIdFront = nationalIdDoc.front!;
      final nationalIdBack = nationalIdDoc.back!;

      File? vehicleLicenseFront;
      File? vehicleLicenseBack;
      File? courierLicenseFront;
      File? courierLicenseBack;

      if (!_isBike) {
        vehicleLicenseFront = vehicleLicenseDoc.front!;
        vehicleLicenseBack = vehicleLicenseDoc.back!;
        courierLicenseFront = courierLicenseDoc.front!;
        courierLicenseBack = courierLicenseDoc.back!;
      }

      // ── Log total payload size ────────────────────────────────────────────
      final filesToLog = <String, File?>{
        'personalPhoto': personalPhoto,
        'national_id_photo_front': nationalIdFront,
        'national_id_photo_back': nationalIdBack,
        'vehicle_license_front': vehicleLicenseFront,
        'vehicle_license_back': vehicleLicenseBack,
        'courier_license_front': courierLicenseFront,
        'courier_license_back': courierLicenseBack,
        'courier_criminal_record': criminalRecord,
      };

      int totalBytes = 0;
      for (final entry in filesToLog.entries) {
        if (entry.value != null) {
          final size = await entry.value!.length();
          totalBytes += size;
          dLog('📎 ${entry.key}: ${fileSizeMB(size)}');
        } else {
          dLog('📎 ${entry.key}: null (not sent)');
        }
      }
      dLog('📦 Total payload size: ${fileSizeMB(totalBytes)}');

      if (totalBytes > kMaxTotalPayloadBytes) {
        throw ImageSizeException(
          totalPayloadTooLargeMsg(totalBytes, isArabic: isArabic),
        );
      }
      // ─────────────────────────────────────────────────────────────────────

      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;

      final phone = normalizeEgyptPhone(phoneController.text.trim());
      final fullName = '${firstNameController.text} ${lastNameController.text}'
          .trim();
      final nationalId = nationalIdNumberController.text.trim();
      final cubit = context.read<AuthCubit>();

      if (_isSocialMode) {
        final social = widget.socialData!;
        if (social.isGoogle) {
          cubit.googleRegister(
            context: context,
            idToken: social.idToken,
            fullName: fullName,
            phone: phone,
            gender: isMale ? 'MALE' : 'FEMALE',
            vehicleId: selectedVehicleId!.toString(),
            vehiclePlate: vehiclePlateController.text.isEmpty
                ? 'N/A'
                : vehiclePlateController.text,
            personalPhoto: personalPhoto,
            nationalIdPhotoFront: nationalIdFront,
            nationalIdPhotoBack: nationalIdBack,
            vehicleLicenseFront: vehicleLicenseFront,
            vehicleLicenseBack: vehicleLicenseBack,
            courierLicenseFront: courierLicenseFront,
            courierLicenseBack: courierLicenseBack,
            criminalRecord: criminalRecord,
            nationalId: nationalId,
          );
        } else {
          cubit.appleRegister(
            context: context,
            idToken: social.idToken,
            fullName: fullName,
            phone: phone,
            gender: isMale ? 'MALE' : 'FEMALE',
            vehicleId: selectedVehicleId!.toString(),
            vehiclePlate: vehiclePlateController.text.isEmpty
                ? 'N/A'
                : vehiclePlateController.text,
            personalPhoto: personalPhoto,
            nationalIdPhotoFront: nationalIdFront,
            nationalIdPhotoBack: nationalIdBack,
            vehicleLicenseFront: vehicleLicenseFront,
            vehicleLicenseBack: vehicleLicenseBack,
            courierLicenseFront: courierLicenseFront,
            courierLicenseBack: courierLicenseBack,
            criminalRecord: criminalRecord,
            nationalId: nationalId,
          );
        }
      } else {
        cubit.register(
          context: context,
          fullName: fullName,
          nationalId: nationalId,
          phone: phone,
          password: passwordController.text,
          gender: isMale ? 'MALE' : 'FEMALE',
          vehicleId: selectedVehicleId!.toString(),
          vehiclePlate: vehiclePlateController.text.isEmpty
              ? 'N/A'
              : vehiclePlateController.text,
          personalPhoto: personalPhoto,
          nationalIdPhotoFront: nationalIdFront,
          nationalIdPhotoBack: nationalIdBack,
          vehicleLicenseFront: vehicleLicenseFront,
          vehicleLicenseBack: vehicleLicenseBack,
          courierLicenseFront: courierLicenseFront,
          courierLicenseBack: courierLicenseBack,
          criminalRecord: criminalRecord,
        );
      }
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        final isArabic0 = Localizations.localeOf(context).languageCode == 'ar';
        final msg = e is ImageSizeException
            ? e.message
            : (isArabic0
                  ? 'فشل معالجة الصورة'
                  : AppLocalizations.of(context)!.failedToProcessImage);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_size_select_large_outlined,
                    size: 40,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isArabic0 ? 'خطأ في الصورة' : 'Image Error',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
                const SizedBox(height: 20),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(isArabic0 ? 'حسناً' : 'OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final showStep2 = _currentStep == 1 || _isPeekingStep2;

    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (_, current) =>
            current is! AuthVehiclesLoaded && current is! AuthVehiclesFailure,
        listener: (context, state) {
          if (state is AuthLoading) {
            showDialog(
              context: context,
              useSafeArea: false,
              barrierDismissible: false,
              builder: (_) => const Center(child: LoadingScreen()),
            );
          } else if (state is AuthOtpRequired) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            context.push(
              '/auth/verify-account-otp',
              extra: {'destination': state.phone, 'channel': 'phone'},
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
            setState(() => _currentStep = 0);
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
            showErrorBanner(context, state.message);
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              const SizedBox(height: 16),
              _buildProgressIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: showStep2
                            ? _buildStep2CourierInfo(loc)
                            : _buildStep1PersonalInfo(loc),
                      ),
                      _buildBottomNavigation(loc),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  // ─── Progress indicator ───────────────────────────────────────────────────

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildProgressStep(
            stepNumber: 1,
            title: AppLocalizations.of(context)!.personalInformation,
            isActive: _currentStep == 0,
            isCompleted: _currentStep > 0,
          ),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: _currentStep > 0
                  ? AppColors.kPrimaryColor
                  : Colors.grey.shade300,
            ),
          ),
          GestureDetector(
            onLongPressStart: (_) {
              setState(() => _isPeekingStep2 = true);
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
            onLongPressEnd: (_) => setState(() => _isPeekingStep2 = false),
            onLongPressCancel: () => setState(() => _isPeekingStep2 = false),
            child: _buildProgressStep(
              stepNumber: 2,
              title: AppLocalizations.of(context)!.courierInformation,
              isActive: _currentStep == 1 || _isPeekingStep2,
              isCompleted: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep({
    required int stepNumber,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted || isActive
                ? AppColors.kPrimaryColor
                : Colors.grey.shade300,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 10)
                : Text(
                    '$stepNumber',
                    style: AppTextStyles.bold14.copyWith(
                      color: isActive ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: AppTextStyles.regular14.copyWith(
            color: isActive || isCompleted
                ? AppColors.kPrimaryColor
                : Colors.grey.shade600,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ─── Step 1 ───────────────────────────────────────────────────────────────

  Widget _buildStep1PersonalInfo(AppLocalizations loc) {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isSocialMode) ...[
            _buildSocialModeBanner(loc),
            const SizedBox(height: 16),
          ],
          SingleImagePickerCard(
            label: Platform.isAndroid
                ? loc.personalPhoto
                : '${loc.personalPhoto} *)',
            image: personalPhoto,
            onTap: () async {
              final f = await ImagePickerService.pickSingle(
                context,
                cropTitle: loc.personalPhoto,
                fileLabel: loc.personalPhoto,
              );
              if (f != null && mounted) setState(() => personalPhoto = f);
            },
          ),
          const SizedBox(height: 20),
          AppTextFormField(
            focusNode: firstNameFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(lastNameFocus),
            label: '${loc.firstName} *',
            controller: firstNameController,
            validator: (v) => v!.isEmpty ? loc.required : null,
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            focusNode: lastNameFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(phoneFocus),
            label: '${loc.lastName} *',
            controller: lastNameController,
            validator: (v) => v!.isEmpty ? loc.required : null,
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            focusNode: phoneFocus,
            textInputAction: _isSocialMode
                ? TextInputAction.done
                : TextInputAction.next,
            onFieldSubmitted: _isSocialMode
                ? null
                : (_) => FocusScope.of(context).requestFocus(passwordFocus),
            label: '${loc.phone} *',
            controller: phoneController,
            isPhone: true,
          ),
          if (!_isSocialMode) ...[
            const SizedBox(height: 16),
            AppTextFormField(
              focusNode: passwordFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(confirmPasswordFocus),
              label: '${loc.password} *',
              controller: passwordController,
              isPassword: true,
              validator: (v) {
                if (v == null || v.isEmpty) return loc.enterPassword;
                if (v.length < 6) return loc.shortPassword;
                if (!RegExp(r'[A-Z]').hasMatch(v)) {
                  return loc.passwordNeedsUppercase;
                }
                if (!RegExp(r'[a-z]').hasMatch(v)) {
                  return loc.passwordNeedsLowercase;
                }
                if (!RegExp(r'[0-9]').hasMatch(v)) {
                  return loc.passwordNeedsNumber;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextFormField(
              focusNode: confirmPasswordFocus,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (_validateStep1()) {
                  setState(() {
                    _currentStep = 1;
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                    Future.delayed(const Duration(milliseconds: 350), () {
                      if (mounted) {
                        FocusScope.of(
                          context,
                        ).requestFocus(nationalIdNumberFocus);
                      }
                    });
                  });
                }
              },
              label: '${loc.confirmPassword} *',
              controller: confirmPasswordController,
              isPassword: true,
              validator: (v) =>
                  v != passwordController.text ? loc.passwordMismatch : null,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSocialModeBanner(AppLocalizations loc) {
    final providerName = widget.socialData!.isGoogle ? 'Google' : 'Apple';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.kPrimaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.kPrimaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            widget.socialData!.isGoogle
                ? Icons.g_mobiledata_rounded
                : Icons.apple,
            color: AppColors.kPrimaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${loc.completeYourProfile} $providerName',
              style: AppTextStyles.regular14.copyWith(
                color: AppColors.kPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSwitch(AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isMale ? Icons.male : Icons.female,
            color: AppColors.kPrimaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(loc.gender, style: AppTextStyles.regular14)),
          Row(
            children: [
              Text(
                loc.male,
                style: AppTextStyles.regular14.copyWith(
                  color: isMale ? AppColors.kPrimaryColor : Colors.grey,
                  fontWeight: isMale ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Switch(
                value: !isMale,
                onChanged: (v) => setState(() => isMale = !v),
                activeThumbColor: AppColors.kPrimaryColor,
                inactiveThumbColor: AppColors.kPrimaryColor,
                activeTrackColor: AppColors.kPrimaryColor.withOpacity(0.3),
                inactiveTrackColor: AppColors.kPrimaryColor.withOpacity(0.3),
              ),
              Text(
                loc.female,
                style: AppTextStyles.regular14.copyWith(
                  color: !isMale ? AppColors.kPrimaryColor : Colors.grey,
                  fontWeight: !isMale ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step 2 ───────────────────────────────────────────────────────────────

  Widget _buildStep2CourierInfo(AppLocalizations loc) {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextFormField(
            focusNode: nationalIdNumberFocus,
            textInputAction: TextInputAction.next,
            label: '${loc.nationalId} *',
            controller: nationalIdNumberController,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return loc.required;
              if (!RegExp(r'^\d{14}$').hasMatch(v.trim())) {
                return AppLocalizations.of(context)!.mustBe14Digits;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TwoSidedDocPickerCard(
            label: loc.nationalIdPhoto,
            doc: nationalIdDoc,
            onTap: () => ImagePickerService.pickTwoSided(
              context,
              nationalIdDoc,
              loc.nationalIdPhoto,
              onUpdate: () => setState(() {}),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${loc.vehicleType} *',
            style: AppTextStyles.regular14.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildVehicleTypeSelector(loc),
          const SizedBox(height: 20),
          if (!_isBike) ...[
            TwoSidedDocPickerCard(
              label: loc.vehicleLicense,
              doc: vehicleLicenseDoc,
              onTap: () => ImagePickerService.pickTwoSided(
                context,
                vehicleLicenseDoc,
                loc.vehicleLicense,
                onUpdate: () => setState(() {}),
              ),
            ),
            const SizedBox(height: 20),
            TwoSidedDocPickerCard(
              label: loc.courierLicense,
              doc: courierLicenseDoc,
              onTap: () => ImagePickerService.pickTwoSided(
                context,
                courierLicenseDoc,
                loc.courierLicense,
                onUpdate: () => setState(() {}),
              ),
            ),
            const SizedBox(height: 20),
            AppTextFormField(
              label: loc.vehiclePlate,
              controller: vehiclePlateController,
              validator: (v) {
                final value = v?.trim();
                if (value == null || value.isEmpty) return null;
                final nonSpaceLength = value.replaceAll(' ', '').length;
                if (nonSpaceLength > 7) return 'أ ب ج 1234';
                return null;
              },
            ),
          ],
          const SizedBox(height: 20),
          // criminalRecord is optional
          SingleImagePickerCard(
            label: loc.criminalRecord,
            image: criminalRecord,
            onTap: () async {
              final f = await ImagePickerService.pickSingle(
                context,
                cropTitle: loc.criminalRecord,
                fileLabel: loc.criminalRecord,
              );
              if (f != null && mounted) setState(() => criminalRecord = f);
            },
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.criminalRecordHint,
                    style: AppTextStyles.regular14.copyWith(
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.kPrimaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.kPrimaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.yourAccountWillBeVerified,
                    style: AppTextStyles.regular14.copyWith(
                      color: AppColors.kPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Vehicle type selector ────────────────────────────────────────────────

  Widget _buildVehicleTypeSelector(AppLocalizations loc) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (_, current) =>
          current is AuthVehiclesLoaded || current is AuthVehiclesFailure,
      builder: (context, state) {
        final cubit = context.read<AuthCubit>();
        final vehicles = cubit.availableVehicles;

        if (vehicles.isEmpty && state is! AuthVehiclesFailure) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (vehicles.isEmpty) {
          return Center(
            child: Column(
              children: [
                Text(
                  loc.error,
                  style: AppTextStyles.regular14.copyWith(color: Colors.red),
                ),
                TextButton(
                  onPressed: () => cubit.fetchAvailableVehicles(),
                  child: Text(loc.retry),
                ),
              ],
            ),
          );
        }

        if (selectedVehicleId == null && vehicles.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => selectedVehicleId = vehicles.first.id);
            }
          });
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: vehicles.map((vehicle) {
            final isSelected = selectedVehicleId == vehicle.id;
            final label = isArabic ? vehicle.nameAr : vehicle.name;
            return _buildVehicleChip(
              vehicle: vehicle,
              label: label,
              isSelected: isSelected,
              onTap: () => setState(() => selectedVehicleId = vehicle.id),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildVehicleChip({
    required VehicleModel vehicle,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.kPrimaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.kPrimaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.kPrimaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vehicle.icon != null && vehicle.icon!.isNotEmpty)
              Image.network(
                vehicle.icon!,
                width: 32,
                height: 32,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (_, __, ___) =>
                    _fallbackIcon(vehicle.name, isSelected),
              )
            else
              _fallbackIcon(vehicle.name, isSelected),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.regular14.copyWith(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackIcon(String name, bool isSelected) {
    final color = isSelected ? Colors.white : Colors.grey.shade700;
    final lower = name.toLowerCase();
    final IconData icon;
    if (lower.contains('bike') || lower.contains('bicycle')) {
      icon = Icons.pedal_bike;
    } else if (lower.contains('motor') || lower.contains('scooter')) {
      icon = Icons.motorcycle;
    } else if (lower.contains('van') || lower.contains('truck')) {
      icon = Icons.airport_shuttle;
    } else {
      icon = Icons.directions_car;
    }
    return Icon(icon, size: 32, color: color);
  }

  // ─── Bottom navigation ────────────────────────────────────────────────────

  Widget _buildBottomNavigation(AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Replace the two checkbox rows in _buildBottomNavigation with this:

          // ── Over-18 + Terms checkboxes ────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Over-18
              InkWell(
                onTap: () => setState(() => _over18 = !_over18),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _over18,
                        activeColor: AppColors.kPrimaryColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) => setState(() => _over18 = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        loc.iamOver18,
                        style: AppTextStyles.regular14.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Terms & Privacy
              InkWell(
                onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        activeColor: AppColors.kPrimaryColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) =>
                            setState(() => _agreedToTerms = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          style: AppTextStyles.regular14.copyWith(fontSize: 12),
                          children: [
                            TextSpan(text: '${loc.iAgreeTo} '),
                            TextSpan(
                              text: loc.termsAndConditions,
                              style: TextStyle(
                                color: AppColors.kPrimaryColor,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.orange,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => context.push('/Terms'),
                            ),
                            const TextSpan(text: ' & '),
                            TextSpan(
                              text: loc.privecyPolicy,
                              style: TextStyle(
                                color: AppColors.kPrimaryColor,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.orange,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => context.push('/PrivacyPage'),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentStep == 0)
            AppCustomButton(
              enabled: _agreedToTerms && _over18,
              text: loc.continue_,
              onPressed: () {
                if (_validateStep1()) {
                  setState(() {
                    _currentStep = 1;
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                    Future.delayed(const Duration(milliseconds: 350), () {
                      if (mounted) {
                        FocusScope.of(
                          context,
                        ).requestFocus(nationalIdNumberFocus);
                      }
                    });
                  });
                }
              },
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep = 0;
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.kPrimaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: AppColors.kPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: AppCustomButton(
                    enabled: _agreedToTerms && _over18,
                    text: loc.register,
                    onPressed: _agreedToTerms
                        ? _submitRegistration
                        : () => showErrorBanner(
                            context,
                            _bi(loc.pleaseAgreeToTerms, ''),
                          ),
                    isLoading: _isProcessing,
                  ),
                ),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(loc.haveAccount, style: AppTextStyles.bold14),
              const SizedBox(width: 5),
              AppTextButton(
                text: loc.signin,
                color: AppColors.kPrimaryColor,
                underline: true,
                onPressed: () => context.go('/auth/login'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
