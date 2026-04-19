import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';

import '../../../../../../core/style/app_colors.dart';
import '../../../../../../core/style/text_styles.dart';

class ProductImagePicker extends StatelessWidget {
  final bool isRequired;
  final File? productImage;
  final ValueChanged<File> onImagePicked;

  const ProductImagePicker({
    super.key,
    required this.isRequired,
    required this.productImage,
    required this.onImagePicked,
  });

  void _showImageSourceSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
              l10n.productImageOptional,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.kPrimaryColor),
              title: Text(l10n.camera),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: AppColors.kPrimaryColor,
              ),
              title: Text(l10n.gallery),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(context, ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.length();

      final sizeInMB = bytes / (1024 * 1024);
      const limitInMB = 5;

      log(
        'Image size: ${sizeInMB.toStringAsFixed(2)} MB (Limit: $limitInMB MB)',
      );

      if (bytes > limitInMB * 1024 * 1024) {
        if (context.mounted) {
          final loc = AppLocalizations.of(context)!;
          final message = loc.imageTooLargeDetailed(
            sizeInMB.toStringAsFixed(2),
            limitInMB.toString(),
          );

          Fluttertoast.showToast(
            msg: message,
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
        return;
      }

      onImagePicked(File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = isRequired ? l10n.packageImage : l10n.productImageOptional;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppTextStyles.regular14),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showImageSourceSheet(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: productImage != null
                    ? AppColors.kPrimaryColor
                    : (isRequired && productImage == null)
                    ? Colors.red.shade200
                    : Colors.grey.shade300,
                width: productImage != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: productImage != null ? Colors.white : Colors.grey.shade50,
            ),
            child: productImage != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          productImage!,
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
                        l10n.tapToSelectImage,
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG or PNG (max 10MB)',
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
