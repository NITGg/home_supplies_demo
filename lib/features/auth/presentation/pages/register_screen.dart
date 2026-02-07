import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../core/widgets/text_button.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../manager/auth_cubit.dart';
import '../../manager/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  int _currentStep = 0;

  // Step 1: Personal Information
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  File? personalPhoto;
  bool isMale = true; // true = Male, false = Female

  // Step 2: Courier Information
  final TextEditingController vehiclePlateController = TextEditingController();
  File? nationalIdPhoto;
  String? selectedVehicleType;

  // Vehicle types with icons
  final List<Map<String, dynamic>> vehicleTypes = [
    {'name': 'Car', 'icon': Icons.directions_car},
    {'name': 'Van', 'icon': Icons.airport_shuttle},
    {'name': 'Bike', 'icon': Icons.pedal_bike},
    {'name': 'Motorcycle', 'icon': Icons.two_wheeler},
    {'name': 'Onfoot', 'icon': Icons.directions_walk},
  ];

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    vehiclePlateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isPersonalPhoto) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      if (context.mounted) {
        setState(() {
        if (isPersonalPhoto) {
          personalPhoto = File(image.path);
        } else {
          nationalIdPhoto = File(image.path);
        }
      });
      }
    }
  }

  bool _validateStep1() {
    if (!_formKeyStep1.currentState!.validate()) {
      return false;
    }

    if (personalPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.selectPersonalPhoto,
          ),
        ),
      );
      return false;
    }

    return true;
  }

  bool _validateStep2() {
    if (!_formKeyStep2.currentState!.validate()) {
      return false;
    }

    if (nationalIdPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.selectNationalIdPhoto,
          ),
        ),
      );
      return false;
    }

    if (selectedVehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle type')),
      );
      return false;
    }

    return true;
  }

  void _submitRegistration() {
    if (_validateStep2()) {
      String phone = phoneController.text;
      if (!phone.startsWith('+2')) {
        phone = '+2$phone';
      }

      context.read<AuthCubit>().register(
        context: context,
        fullName: '${firstNameController.text} ${lastNameController.text}',
        phone: phone,
        password: passwordController.text,
        gender: isMale ? 'MALE' : 'FEMALE',
        vehicleType: selectedVehicleType!,
        // Send the string directly
        vehiclePlate: vehiclePlateController.text.isEmpty
            ? 'N/A'
            : vehiclePlateController.text,
        personalPhoto: personalPhoto!,
        nationalIdPhoto: nationalIdPhoto!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

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
          } else if (state is AuthOtpRequired) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            context.push('/auth/verify-otp', extra: state.phone);
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
          return Column(
            children: [
              SizedBox(height: 60),
              // Progress Indicator
              _buildProgressIndicator(),

              // Step Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _currentStep == 0
                      ? _buildStep1PersonalInfo(loc)
                      : _buildStep2CourierInfo(loc),
                ),
              ),

              // Bottom Navigation
              _buildBottomNavigation(loc),
            ],
          );
        },
      ),
    );
  }

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
            title:
                AppLocalizations.of(context)!.personalInformation,
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
          _buildProgressStep(
            stepNumber: 2,
            title:
                AppLocalizations.of(context)!.courierInformation ?? 'Courier',
            isActive: _currentStep == 1,
            isCompleted: false,
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

  Widget _buildStep1PersonalInfo(AppLocalizations loc) {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Photo
          _buildImagePicker(
            label: loc.personalPhoto,
            image: personalPhoto,
            onTap: () => _pickImage(true),
          ),
          const SizedBox(height: 20),

          // First Name
          AppTextFormField(
            label: '${loc.firstName} *',
            controller: firstNameController,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // Last Name
          AppTextFormField(
            label: '${loc.lastName} *',
            controller: lastNameController,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // Gender Switch
          _buildGenderSwitch(loc),
          const SizedBox(height: 16),

          // Phone
          AppTextFormField(
            label: '${loc.phone} *',
            controller: phoneController,
            isPhone: true,
            validator: (v) {
              if (v!.isEmpty) {
                return loc.enterPhoneNumber;
              } else if (v.length < 9) {
                return loc.invalidPhoneNumber;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          AppTextFormField(
            label: '${loc.password} *',
            controller: passwordController,
            isPassword: true,
            validator: (v) {
              if (v!.length < 8) {
                return loc.shortPassword;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password
          AppTextFormField(
            label: '${loc.confirmPassword} *',
            controller: confirmPasswordController,
            isPassword: true,
            validator: (v) {
              if (v != passwordController.text) {
                return loc.passwordMismatch;
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
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
          Expanded(
            child: Text(loc.gender, style: AppTextStyles.regular14),
          ),
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
                onChanged: (value) {
                  setState(() {
                    isMale = !value;
                  });
                },
                activeColor: AppColors.kPrimaryColor,
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

  Widget _buildStep2CourierInfo(AppLocalizations loc) {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // National ID Photo
          _buildImagePicker(
            label: loc.nationalIdPhoto,
            image: nationalIdPhoto,
            onTap: () => _pickImage(false),
          ),
          const SizedBox(height: 20),

          // Vehicle Type Selection with Icon Chips
          Text(
            '${loc.vehicleType} *',
            style: AppTextStyles.regular14.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildVehicleTypeSelector(),
          const SizedBox(height: 20),

          // Vehicle Plate (Optional)
          AppTextFormField(
            label: '${loc.vehiclePlate ?? 'Vehicle Plate'} (Optional)',
            controller: vehiclePlateController,
            validator: (_) => null,
          ),
          const SizedBox(height: 24),

          // Info Box
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

  Widget _buildVehicleTypeSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: vehicleTypes.map((vehicle) {
        final isSelected = selectedVehicleType == vehicle['name'];
        return _buildVehicleChip(
          name: vehicle['name'],
          icon: vehicle['icon'],
          isSelected: isSelected,
          onTap: () {
            setState(() {
              selectedVehicleType = vehicle['name'];
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildVehicleChip({
    required String name,
    required IconData icon,
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
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(height: 8),
            Text(
              name,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentStep == 0)
            AppCustomButton(
              text: loc.continue_,
              onPressed: () {
                if (_validateStep1()) {
                  setState(() {
                    _currentStep = 1;
                  });
                }
              },
            )
          else
            AppCustomButton(text: loc.register, onPressed: _submitRegistration),
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }

  Widget _buildImagePicker({
    required String label,
    required File? image,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.regular14),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: image != null
                    ? AppColors.kPrimaryColor
                    : Colors.grey.shade300,
                width: image != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: image != null ? Colors.white : Colors.grey.shade50,
            ),
            child: image != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.kPrimaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_photo_alternate,
                          size: 32,
                          color: AppColors.kPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.tapToSelectImage,
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG or PNG (max 1MB)',
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
