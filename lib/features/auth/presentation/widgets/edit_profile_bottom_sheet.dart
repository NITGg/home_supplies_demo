import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/widgets/custom_button.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/models/vehicles_model.dart';
import '../../manager/profile_cubit.dart';
import '../../manager/profile_states.dart';

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
  late TextEditingController _extraPhoneController;

  bool isMale = true;
  int? selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _vehiclePlateController = TextEditingController(
      text: widget.profile.courier.vehiclePlate,
    );
    _extraPhoneController = TextEditingController(
      text: widget.profile.extraPhones ?? '',
    );
    isMale = widget.profile.gender == 'MALE';

    // Pre-select the vehicle from profile immediately if vehicles are cached.
    // If not cached yet, fire the fetch — _resolveVehicleId will be called
    // inside the BlocBuilder once VehiclesLoaded is emitted.
    final cubit = context.read<ProfileCubit>();
    if (cubit.availableVehicles.isNotEmpty) {
      _resolveVehicleId(cubit.availableVehicles);
    } else {
      cubit.fetchAvailableVehicles();
    }
  }

  /// Matches the profile's current vehicleType id against the loaded list
  /// and sets [selectedVehicleId] accordingly.
  void _resolveVehicleId(List<VehicleModel> vehicles) {
    final vId = widget.profile.courier.vehicleType?.id;
    if (vId == null) return;
    try {
      final match = vehicles.firstWhere((v) => v.id == vId);
      selectedVehicleId = match.id;
    } catch (_) {
      // No match — leave selectedVehicleId null
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vehiclePlateController.dispose();
    _extraPhoneController.dispose();
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
                      // const SizedBox(height: 16),
                      //
                      // AppTextFormField(
                      //   label: localizations.extraPhone,
                      //   controller: _extraPhoneController,
                      //   isPhone: true,
                      //   isRequired: false, // validates format only when non-empty
                      // ),
                      //
                      // const SizedBox(height: 16),
                      // _buildGenderSwitch(localizations),
                      const SizedBox(height: 16),
                      Text(
                        '${localizations.vehicleType} *',
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildVehicleTypeSelector(localizations, isArabic),
                      const SizedBox(height: 20),
                      AppTextFormField(
                        label: localizations.licensePlate,
                        controller: _vehiclePlateController,
                          validator:(v) {
                            final value = v?.trim();
                            if (value == null || value.isEmpty) return null; // allow empty

                            // Count only letters and digits, ignore spaces
                            final nonSpaceLength = value.replaceAll(' ', '').length;

                            if (nonSpaceLength > 7) {
                              return 'أ ب ج 1234'; // adjust localization
                            }

                            return null;
                          }
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
                              isLoading: context.watch<ProfileCubit>().state
                              is ProfileLoading,
                              onPressed: context.watch<ProfileCubit>().state is ProfileLoading ? () {} : _saveChanges,
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
                activeThumbColor: AppColors.kPrimaryColor,
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

  Widget _buildVehicleTypeSelector(
      AppLocalizations localizations, bool isArabic) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (previous, current) =>
      current is VehiclesLoaded ||
          current is VehiclesFailure ||
          current is ProfileLoading,
      builder: (context, state) {
        final cubit = context.read<ProfileCubit>();
        final vehicles = cubit.availableVehicles;

        // Resolve selectedVehicleId as soon as vehicles become available.
        // Safe to call here — if selectedVehicleId is already set this is
        // a no-op because _resolveVehicleId guards on vId being non-null
        // and the firstWhere will still match the same id.
        if (vehicles.isNotEmpty && selectedVehicleId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _resolveVehicleId(vehicles));
            }
          });
        }

        // Still loading and no cached vehicles yet
        if (vehicles.isEmpty && state is ProfileLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Fetch failed and no cached vehicles
        if (vehicles.isEmpty && state is VehiclesFailure) {
          return Center(
            child: Column(
              children: [
                Text(
                  localizations.error,
                  style: AppTextStyles.regular14.copyWith(color: Colors.red),
                ),
                TextButton(
                  onPressed: () => cubit.fetchAvailableVehicles(),
                  child: Text(localizations.retry),
                ),
              ],
            ),
          );
        }

        if (vehicles.isEmpty) {
          return const SizedBox.shrink();
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
              onTap: () {
                setState(() {
                  selectedVehicleId = vehicle.id;
                });
              },
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
            color:
            isSelected ? AppColors.kPrimaryColor : Colors.grey.shade300,
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
                errorBuilder: (_, __, ___) => _fallbackVehicleIcon(
                  vehicle.name,
                  isSelected,
                ),
              )
            else
              _fallbackVehicleIcon(vehicle.name, isSelected),
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

  /// Fallback icon based on vehicle name when no icon URL is provided.
  Widget _fallbackVehicleIcon(String name, bool isSelected) {
    final color = isSelected ? Colors.white : Colors.grey.shade700;
    final lowerName = name.toLowerCase();

    IconData icon;
    if (lowerName.contains('bike') ||
        lowerName.contains('bicycle') ||
        lowerName.contains('دراجة')) {
      icon = Icons.pedal_bike;
    } else if (lowerName.contains('motor') || lowerName.contains('scooter')) {
      icon = Icons.motorcycle;
    } else if (lowerName.contains('truck') || lowerName.contains('van')) {
      icon = Icons.local_shipping;
    } else {
      icon = Icons.directions_car;
    }

    return Icon(icon, size: 32, color: color);
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      if (selectedVehicleId == null) {
        showErrorBanner(
          context,
          "${AppLocalizations.of(context)!.vehicleType} ${AppLocalizations.of(context)!.required}",
        );
        return;
      }

      await context.read<ProfileCubit>().updateProfile(
        fullName: _nameController.text.trim(),
        gender: isMale ? 'MALE' : 'FEMALE',
        vehicleId: selectedVehicleId!.toString(),
        vehiclePlate: _vehiclePlateController.text.trim(),
        extraPhones: _extraPhoneController.text.trim().isEmpty
            ? null
            : _extraPhoneController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}