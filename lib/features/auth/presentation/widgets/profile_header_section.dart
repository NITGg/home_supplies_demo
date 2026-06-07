import 'dart:io';
import 'package:tawreedat_go/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/user_profile_model.dart';

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
          // Avatar with camera overlay
          Stack(
            children: [
              GestureDetector(
                onTap: () => _showPhotoOptions(context),
                child: Hero(
                  tag: 'profile-avatar',
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
                          ? Image.network(
                              profile.personalPhoto!,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                dLog('ProfileHeader: image failed — url=${profile.personalPhoto} error=$error');
                                return SvgPicture.asset(
                                  'assets/images/drawer/profile_placholder.svg',
                                );
                              },
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
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 14,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions(BuildContext parentContext) {
    final localizations = AppLocalizations.of(parentContext)!;

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              localizations.updateProfile,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.orange),
              title: Text(localizations.camera),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndCropImage(parentContext, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: Text(localizations.gallery),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndCropImage(parentContext, ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCropImage(
      BuildContext context,
      ImageSource source,
      ) async {
    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    final bytes = await pickedFile.length();

    final sizeInMB = bytes / (1024 * 1024);
    const limitInMB = 5;

    dLog(
      'Image size: ${sizeInMB.toStringAsFixed(2)} MB (Limit: $limitInMB MB)',
    );

    if (bytes > limitInMB * 1024 * 1024) {
      if (context.mounted) {
        final loc = AppLocalizations.of(context)!;

        final message = loc.imageTooLargeDetailed(
          sizeInMB.toStringAsFixed(2),
          limitInMB.toString(),
        );

        showErrorBanner(context, message);
      }
      return;
    }

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      // Square crop suits a circular profile avatar
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle:
              AppLocalizations.of(context)?.updateProfile ?? 'Crop Photo',
          toolbarColor: Colors.orange,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: AppLocalizations.of(context)?.updateProfile ?? 'Crop Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile != null && context.mounted) {
      final file = File(croppedFile.path);
      // Uncomment and use whichever cubit/method handles profile photo updates:
      // context.read<AuthCubit>().updateProfile(personalPhoto: file);
    }
  }
}
