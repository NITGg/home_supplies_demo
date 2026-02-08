import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
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
          // Avatar with badge overlay
          Stack(
            children: [
              GestureDetector(
                onTap: () => _showPhotoOptions(context),
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
                      child: profile.personalPhoto.isNotEmpty
                          ? Image.network(
                        profile.personalPhoto,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
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

          // Name and info
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.orange),
              title: Text(localizations.camera ),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(parentContext, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: Text(localizations.gallery),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(parentContext, ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      if (context.mounted) {
        context.read<ProfileCubit>().updateDocuments(personalPhoto: file);
      }
    }
  }
}