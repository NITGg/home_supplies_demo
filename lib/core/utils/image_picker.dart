
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import 'logger.dart';

class ImagePickerService {
  static final _picker = ImagePicker();

  /// Max allowed size (5MB)
  static const int _maxBytes = 5 * 1024 * 1024;

  /// Pick + crop single image
  static Future<File?> pickSingle(
      BuildContext context, {
        String? cropTitle,
        CropAspectRatio? aspectRatio,
        bool lockAspectRatio = false,
      }) async {
    try {
      final source = await _askSource(context);
      if (source == null || !context.mounted) return null;

      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked == null || !context.mounted) return null;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: aspectRatio,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: cropTitle ?? AppLocalizations.of(context)!.cropImage,
            lockAspectRatio: lockAspectRatio,
          ),
          IOSUiSettings(
            title: cropTitle ?? AppLocalizations.of(context)!.cropImage,
            aspectRatioLockEnabled: lockAspectRatio,
          ),
        ],
      );
      if (cropped == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final file = await File(cropped.path).copy(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final size = await file.length();
      dLog('Image size: ${(size / (1024 * 1024)).toStringAsFixed(2)} MB');

      if (size > _maxBytes) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.imageTooLarge)),
          );
        }
        return null;
      }

      return file;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToChooseImage)),
        );
      }
      return null;
    }
  }

  /// Bottom sheet to choose source
  static Future<ImageSource?> _askSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(AppLocalizations.of(context)!.camera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: Text(AppLocalizations.of(context)!.gallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}