import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:tawreedat_courier/core/widgets/image_with_fallback.dart';

import '../../../../core/utils/image_picker_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/user_profile_model.dart';
import '../../manager/profile_cubit.dart';

class ProfileHeaderSection extends StatelessWidget {
  final UserProfileModel profile;

  const ProfileHeaderSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Row(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => _pickProfilePhoto(context),
                child: Hero(
                  tag: 'profile_avatar',
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: profile.personalPhoto != null &&
                          profile.personalPhoto!.isNotEmpty
                          ? ImageWithIconFallback(
                        imageUrl: profile.personalPhoto,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        isCircle: true,
                      )
                          : SvgPicture.asset(
                        'assets/images/drawer/profile_placholder.svg',
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: isArabic ? null : 0,
                left: isArabic ? 0 : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt,
                      size: 14, color: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              profile.fullName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Uses the shared [ImagePickerService] — camera/gallery sheet + square crop.
  Future<void> _pickProfilePhoto(BuildContext context) async {
    final file = await ImagePickerService.pickSingle(
      context,
      cropTitle: AppLocalizations.of(context)?.updateProfile ?? 'Crop',
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      lockAspectRatio: true,
    );
    if (file != null && context.mounted) {
      context.read<ProfileCubit>().updateDocuments(personalPhoto: file);
    }
  }
}