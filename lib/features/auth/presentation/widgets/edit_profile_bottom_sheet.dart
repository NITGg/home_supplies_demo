import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/widgets/custom_button.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart' show rootNavigatorKey;
import '../../data/models/user_profile_model.dart';
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
  late TextEditingController _extraPhoneController;
  bool isMale = true;

  @override
  void initState() {
    super.initState();
    _nameController       = TextEditingController(text: widget.profile.fullName);
    _extraPhoneController = TextEditingController(text: widget.profile.extraPhones ?? '');
    isMale = widget.profile.gender == 'MALE';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _extraPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return BlocListener<ProfileCubit, ProfileState>(
      listener: (context, state) {
        final rootCtx = rootNavigatorKey.currentContext;
        if (state is ProfileUpdateSuccess) {
          if (rootCtx != null) showSuccessBanner(rootCtx, state.message);
          Navigator.pop(context);
        } else if (state is ProfileFailure) {
          if (rootCtx != null) showErrorBanner(rootCtx, state.message);
        }
      },
      child: Directionality(
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

                        // ── Full name ──────────────────────────────────────
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

                        // ── Gender ─────────────────────────────────────────
                        _buildGenderSwitch(localizations),
                        const SizedBox(height: 32),

                        // ── Action buttons ─────────────────────────────────
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
            child: Text(localizations.gender, style: AppTextStyles.regular14),
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit      = context.read<ProfileCubit>();
    final extraPhone = _extraPhoneController.text.trim();

    await cubit.updateProfile(
      fullName:    _nameController.text.trim(),
      gender:      isMale ? 'MALE' : 'FEMALE',
      extraPhones: extraPhone.isEmpty ? null : extraPhone,
    );
  }
}