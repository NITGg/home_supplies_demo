
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/core/widgets/image_with_fallback.dart';
import 'package:tawreedat_courier/features/auth/data/models/vehicles_model.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/utils/image_picker_utils.dart';
import '../../../../core/widgets/banners.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/user_profile_model.dart';
import '../../manager/profile_cubit.dart';

enum DocumentType { nationalId, vehicleLicense, courierLicense, criminalRecord }

class VehicleInfoCard extends StatelessWidget {
  final CourierModel courier;

  const VehicleInfoCard({super.key, required this.courier});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
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
            // ── Header ────────────────────────────────────────────────────
            Column(
              spacing: 5,
              children: [
                Text(
                  loc.vehicleInformation,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        courier.isApproved ? loc.approved : loc.pendingApproval,
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

            // ── Vehicle details ──────────────────────────────────────────
            _buildVehicleTypeRow(
              vehicle: courier.vehicleType,
              label: loc.vehicleType,
              value: (isArabic
                  ? courier.vehicleType?.nameAr
                  : courier.vehicleType?.name) ??
                  '—',
            ),
            const SizedBox(height: 16),
            _buildIconDetailRow(
              icon: Icons.pin_outlined,
              label: loc.licensePlate,
              value: courier.vehiclePlate ?? '—',
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // ── Documents ────────────────────────────────────────────────
            Text(
              loc.documents,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 12),

            // National ID — front + back
            _buildTwoSidedDocumentSection(
              context,
              title: loc.nationalIdPhoto,
              frontUrl: courier.nationalIdPhotoFront,
              backUrl: courier.nationalIdPhotoBack,
              icon: Icons.credit_card,
              onUpdate: () =>
                  _pickTwoSidedDocument(context, DocumentType.nationalId),
            ),
            const SizedBox(height: 12),

            // Vehicle License — front + back
            _buildTwoSidedDocumentSection(
              context,
              title: loc.vehicleLicense,
              frontUrl: courier.vehicleLicenseFront,
              backUrl: courier.vehicleLicenseBack,
              icon: Icons.description,
              onUpdate: () =>
                  _pickTwoSidedDocument(context, DocumentType.vehicleLicense),
            ),
            const SizedBox(height: 12),

            // Courier License — front + back
            _buildTwoSidedDocumentSection(
              context,
              title: loc.courierLicense,
              frontUrl: courier.courierLicenseFront,
              backUrl: courier.courierLicenseBack,
              icon: Icons.badge,
              onUpdate: () =>
                  _pickTwoSidedDocument(context, DocumentType.courierLicense),
            ),
            const SizedBox(height: 12),

            // Criminal Record — single image
            _buildSingleImageDocumentSection(
              context,
              title: loc.criminalRecord,
              imageUrl: courier.criminalRecord,
              icon: Icons.gavel,
              onUpdate: () => _pickSingleDocument(
                  context, DocumentType.criminalRecord),
              showUpdateButton: true,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Two-sided document picker ───────────────────────────────────────────

  Future<void> _pickTwoSidedDocument(
      BuildContext context,
      DocumentType type,
      ) async {
    final loc = AppLocalizations.of(context)!;
    final doc = TwoSidedDoc();
    final docName = _docName(loc, type);

    await ImagePickerService.pickTwoSided(
      context,
      doc,
      docName,
      onUpdate: () {},
    );

    if (!doc.isComplete) return;
    if (!context.mounted) return;

    try {
      showInfoBanner(context, loc.uploading);

      // Send front & back separately — no stitching.
      final front = doc.front!;
      final back = doc.back!;

      if (!context.mounted) return;

      await context.read<ProfileCubit>().updateDocuments(
        nationalIdPhotoFront:
        type == DocumentType.nationalId ? front : null,
        nationalIdPhotoBack:
        type == DocumentType.nationalId ? back : null,
        vehicleLicenseFront:
        type == DocumentType.vehicleLicense ? front : null,
        vehicleLicenseBack:
        type == DocumentType.vehicleLicense ? back : null,
        courierLicenseFront:
        type == DocumentType.courierLicense ? front : null,
        courierLicenseBack:
        type == DocumentType.courierLicense ? back : null,
      );
    } catch (e) {
      if (context.mounted) {
        showErrorBanner(context, '${loc.failedToProcessImage}: $e');
      }
    }
  }

  // ─── Single image document picker ────────────────────────────────────────

  Future<void> _pickSingleDocument(
      BuildContext context,
      DocumentType type,
      ) async {
    final loc = AppLocalizations.of(context)!;
    final docName = _docName(loc, type);

    final file = await ImagePickerService.pickSingle(
      context,
      cropTitle: docName,
      fileLabel: docName,
    );

    if (file == null) return;
    if (!context.mounted) return;

    try {
      showInfoBanner(context, loc.uploading);

      await context.read<ProfileCubit>().updateDocuments(
        criminalRecord: type == DocumentType.criminalRecord ? file : null,
      );
    } catch (e) {
      if (context.mounted) {
        showErrorBanner(context, '${loc.failedToProcessImage}: $e');
      }
    }
  }

  String _docName(AppLocalizations loc, DocumentType type) {
    switch (type) {
      case DocumentType.nationalId:
        return loc.nationalIdPhoto;
      case DocumentType.vehicleLicense:
        return loc.vehicleLicense;
      case DocumentType.courierLicense:
        return loc.courierLicense;
      case DocumentType.criminalRecord:
        return loc.criminalRecord;
    }
  }

  // ─── Two-sided document section ──────────────────────────────────────────

  /// Renders a card with a "Front" thumbnail and a "Back" thumbnail side-by-side,
  /// plus an update button in the top-right corner.
  Widget _buildTwoSidedDocumentSection(
      BuildContext context, {
        required String title,
        required String? frontUrl,
        required String? backUrl,
        required IconData icon,
        VoidCallback? onUpdate,
        bool showUpdateButton = kDebugMode,
      }) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.kPrimaryColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
              ),
              if (onUpdate != null && showUpdateButton)
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
          const SizedBox(height: 10),
          // Front + Back thumbnails
          Row(
            children: [
              Expanded(
                child: _buildSideThumbnail(
                  context,
                  label: loc.front,
                  imageUrl: frontUrl,
                  docTitle: '$title — ${loc.front}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSideThumbnail(
                  context,
                  label: loc.back,
                  imageUrl: backUrl,
                  docTitle: '$title — ${loc.back}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Single image document section ───────────────────────────────────────

  /// Renders a card with a single thumbnail and an update button in the
  /// top-right corner.
  Widget _buildSingleImageDocumentSection(
      BuildContext context, {
        required String title,
        required String? imageUrl,
        required IconData icon,
        VoidCallback? onUpdate,
        bool showUpdateButton = kDebugMode,
      }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.kPrimaryColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
              ),
              if (onUpdate != null && showUpdateButton)
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
          const SizedBox(height: 10),
          _buildSideThumbnail(
            context,
            label: title,
            imageUrl: imageUrl,
            docTitle: title,
          ),
        ],
      ),
    );
  }

  Widget _buildSideThumbnail(
      BuildContext context, {
        required String label,
        required String? imageUrl,
        required String docTitle,
      }) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => _showFullImage(context, imageUrl, docTitle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 90,
            width: double.infinity,
            decoration: BoxDecoration(
              color: hasImage
                  ? Colors.white
                  : AppColors.kPrimaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasImage
                    ? Colors.grey.withOpacity(0.2)
                    : AppColors.kPrimaryColor.withOpacity(0.25),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: hasImage
                  ? SizedBox.expand(
                child: ImageWithIconFallback(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                ),
              )
                  : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 28,
                      color: AppColors.kPrimaryColor.withOpacity(0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.kPrimaryColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ─── Detail rows ─────────────────────────────────────────────────────────

  Widget _buildVehicleTypeRow({
    required VehicleModel? vehicle,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.kPrimaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: vehicle != null &&
              vehicle.icon != null &&
              vehicle.icon!.isNotEmpty
              ? ImageWithIconFallback(
            imageUrl: vehicle.icon,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          )
              : _fallbackVehicleIcon(vehicle?.name ?? ''),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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

  Widget _buildIconDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
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
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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

  Widget _fallbackVehicleIcon(String name) {
    final lower = name.toLowerCase();
    IconData icon;
    if (lower.contains('bike') || lower.contains('bicycle') || lower.contains('دراجة')) {
      icon = Icons.pedal_bike;
    } else if (lower.contains('motor') || lower.contains('scooter')) {
      icon = Icons.motorcycle;
    } else if (lower.contains('van') || lower.contains('truck')) {
      icon = Icons.local_shipping;
    } else {
      icon = Icons.directions_car;
    }
    return Icon(icon, size: 24, color: AppColors.kPrimaryColor);
  }

  // ─── Full-image dialog ───────────────────────────────────────────────────

  void _showFullImage(BuildContext context, String? imageUrl, String title) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
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
}