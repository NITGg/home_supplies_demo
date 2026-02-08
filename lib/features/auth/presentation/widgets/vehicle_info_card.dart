import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tawreedat_courier/core/widgets/image_with_fallback.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/user_profile_model.dart';
import '../../manager/profile_cubit.dart';

enum DocumentType { nationalId, vehicleLicense, courierLicense }

class VehicleInfoCard extends StatelessWidget {
  final CourierModel courier;

  const VehicleInfoCard({super.key, required this.courier});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localizations.vehicleInformation,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: courier.isApproved
                        ? const Color(0xFF00B894).withOpacity(0.1)
                        : const Color(0xFFFDCB6E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        courier.isApproved ? Icons.verified : Icons.pending,
                        size: 14,
                        color: courier.isApproved
                            ? const Color(0xFF00B894)
                            : const Color(0xFFFDCB6E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        courier.isApproved
                            ? (localizations.approved)
                            : (localizations.pendingApproval),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: courier.isApproved
                              ? const Color(0xFF00B894)
                              : const Color(0xFFFDCB6E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(
              Icons.local_shipping_outlined,
              localizations.vehicleType,
              _getLocalizedVehicleType(context, courier.vehicleType),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              Icons.pin_outlined,
              localizations.licensePlate,
              courier.vehiclePlate,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              localizations.documents,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 12),
            _buildDocumentCard(
              context,
              localizations.nationalIdPhoto,
              courier.nationalIdPhoto,
              Icons.credit_card,
                  () => _showFullImage(
                context,
                courier.nationalIdPhoto,
                localizations.nationalIdPhoto,
              ),
              onUpdate: () =>
                  _showPhotoOptions(context, type: DocumentType.nationalId),
            ),
            const SizedBox(height: 12),
            _buildDocumentCard(
              context,
              localizations.vehicleLicense,
              courier.vehicleLicense,
              Icons.description,
                  () => _showFullImage(
                context,
                courier.vehicleLicense ?? '',
                localizations.vehicleLicense,
              ),
              onUpdate: () =>
                  _showPhotoOptions(context, type: DocumentType.vehicleLicense),
            ),
            const SizedBox(height: 12),
            _buildDocumentCard(
              context,
              localizations.courierLicense ,
              courier.courierLicense,
              Icons.badge,
                  () => _showFullImage(
                context,
                courier.courierLicense ?? '',
                localizations.courierLicense ,
              ),
              onUpdate: () =>
                  _showPhotoOptions(context, type: DocumentType.courierLicense),
            ),
          ],
        ),
      ),
    );
  }

  String _getLocalizedVehicleType(BuildContext context, String vehicleType) {
    final localizations = AppLocalizations.of(context)!;

    switch (vehicleType.toLowerCase()) {
      case 'car':
        return localizations.car;
      case 'van':
        return localizations.van;
      case 'bike':
        return localizations.bike ;
      case 'motorcycle':
        return localizations.motorcycle;
      case 'onfoot':
        return localizations.onFoot;
      default:
        return vehicleType;
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.kPrimaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 24, color: AppColors.kPrimaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(
      BuildContext context,
      String title,
      String? imageUrl,
      IconData icon,
      VoidCallback onTap, {
        VoidCallback? onUpdate,
      }) {
    final localizations = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageWithIconFallback(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizations.tapToViewFullImage,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (onUpdate != null)
              IconButton(
                icon: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.kPrimaryColor,
                  size: 20,
                ),
                onPressed: onUpdate,
              ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: ImageWithIconFallback(imageUrl: imageUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoOptions(BuildContext context, {required DocumentType type}) {
    final localizations = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
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
              localizations.documents,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.kPrimaryColor),
              title: Text(localizations.camera),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                // Use the original context, not bottomSheetContext
                _pickImage(context, ImageSource.camera, type);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: AppColors.kPrimaryColor,
              ),
              title: Text(localizations.gallery),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                // Use the original context, not bottomSheetContext
                _pickImage(context, ImageSource.gallery, type);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(
      BuildContext context,
      ImageSource source,
      DocumentType type,
      ) async {
    final localizations = AppLocalizations.of(context)!;
    try {
      log('VehicleInfoCard: Starting image picker for $type');

      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        log('VehicleInfoCard: No image selected');
        return;
      }

      log('VehicleInfoCard: Image picked: ${pickedFile.path}');

      final file = File(pickedFile.path);

      // Check if file exists
      if (!await file.exists()) {
        log('VehicleInfoCard: ERROR - File does not exist at path: ${file.path}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: File not found')),
          );
        }
        return;
      }

      // Check file size
      final fileSize = await file.length();
      log('VehicleInfoCard: File size: ${fileSize / 1024} KB');

      if (!context.mounted) {
        log('VehicleInfoCard: Context not mounted, cannot proceed');
        return;
      }

      log('VehicleInfoCard: Context is mounted, proceeding with upload');
      log('VehicleInfoCard: Calling ProfileCubit.updateDocuments');

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.uploading),
          duration: Duration(seconds: 2),
        ),
      );

      await context.read<ProfileCubit>().updateDocuments(
        nationalIdPhoto: type == DocumentType.nationalId ? file : null,
        vehicleLicense: type == DocumentType.vehicleLicense ? file : null,
        courierLicense: type == DocumentType.courierLicense ? file : null,
      );

      log('VehicleInfoCard: updateDocuments call completed');

    } catch (e, stackTrace) {
      log('VehicleInfoCard: Error picking image: $e');
      log('VehicleInfoCard: Stack trace: $stackTrace');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}