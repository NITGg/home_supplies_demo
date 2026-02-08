import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/widgets/custom_button.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/user_profile_model.dart';
import '../../manager/profile_cubit.dart';
import '../../manager/profile_states.dart';
import '../pages/register_screen.dart';

class EditProfileBottomSheet extends StatefulWidget {
  final UserProfileModel profile;

  const EditProfileBottomSheet({super.key, required this.profile});

  @override
  State<EditProfileBottomSheet> createState() => _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState extends State<EditProfileBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _vehiclePlateController;
  bool isMale = true;
  String? selectedVehicleType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _vehiclePlateController = TextEditingController(
      text: widget.profile.courier.vehiclePlate,
    );
    isMale = widget.profile.gender == 'MALE';
    selectedVehicleType = widget.profile.courier.vehicleType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        localizations.edit,
                        style: AppTextStyles.bold14.copyWith(
                          fontSize: 24,
                          color: const Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppTextFormField(
                        label: '${localizations.name} *',
                        controller: _nameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return localizations.required;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildGenderSwitch(localizations),
                      const SizedBox(height: 16),
                      Text(
                        '${localizations.vehicleType} *',
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildVehicleTypeSelector(localizations),
                      const SizedBox(height: 20),
                      AppTextFormField(
                        label: localizations.licensePlate,
                        controller: _vehiclePlateController,
                        validator: (_) => null,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Flexible(
                            child: AppCustomButton(
                              isSecondary: true,
                              onPressed: () => Navigator.pop(context),
                              text: localizations.cancel,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: AppCustomButton(
                              isLoading: context.watch<ProfileCubit>().state is ProfileLoading,
                              onPressed: _saveChanges,
                              text: localizations.confirm,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSwitch(AppLocalizations localizations) {
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
            child: Text(
              localizations.gender,
              style: AppTextStyles.regular14,
            ),
          ),
          Row(
            children: [
              Text(
                localizations.male,
                style: AppTextStyles.regular14.copyWith(
                  color: isMale ? AppColors.kPrimaryColor : Colors.grey,
                  fontWeight: isMale ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Switch(
                value: !isMale,
                onChanged: (value) => setState(() => isMale = !value),
                activeColor: AppColors.kPrimaryColor,
                inactiveThumbColor: AppColors.kPrimaryColor,
                activeTrackColor: AppColors.kPrimaryColor.withOpacity(0.3),
                inactiveTrackColor: AppColors.kPrimaryColor.withOpacity(0.3),
              ),
              Text(
                localizations.female,
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

  Widget _buildVehicleTypeSelector(AppLocalizations localizations) {
    final vehicleTypes = getVehicleTypes(localizations);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: vehicleTypes.map((vehicle) {
        final isSelected = selectedVehicleType == vehicle['name'];
        return _buildVehicleChip(
          name: vehicle['name'],
          label: vehicle['label'],
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
    required String label,
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

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      if (selectedVehicleType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.vehicleType),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await context.read<ProfileCubit>().updateProfile(
        fullName: _nameController.text.trim(),
        gender: isMale ? 'MALE' : 'FEMALE',
        vehicleType: selectedVehicleType!, // Now using the state variable
        vehiclePlate: _vehiclePlateController.text.trim(),
      );
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}
