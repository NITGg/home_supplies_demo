import 'package:tawreedat_courier/core/utils/logger.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/banners.dart';

// ─── Image size limits (easy to adjust) ──────────────────────────────────────

/// Maximum size for a single picked/cropped image (1 MB).
const int kMaxSingleImageBytes = 5 * 1024 * 1024;

/// Maximum size for a stitched collage image (3 MB).
const int kMaxCollageImageBytes = 10 * 1024 * 1024;

/// Maximum total payload size for all files combined (5 MB).
const int kMaxTotalPayloadBytes = 40 * 1024 * 1024;

String totalPayloadTooLargeMsg(int sizeBytes, {required bool isArabic}) =>
    _localised(
      'الحجم الكلي للملفات كبير جداً (${fileSizeMB(sizeBytes)}).'
          ' الحد الأقصى المسموح به هو ${fileSizeMB(kMaxTotalPayloadBytes)}.'
          ' يرجى إعادة التقاط الصور بدقة أقل.',
      '',
      isArabic: isArabic,
    );

String fileSizeMB(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// Returns a localised error string — Arabic when [isArabic], English otherwise.
String _localised(String ar, String en, {required bool isArabic}) =>
    isArabic ? ar : en;

String _singleImageTooLargeMsg(
  int sizeBytes, {
  required bool isArabic,
  String? fileLabel,
}) => _localised(
  '${fileLabel != null ? "$fileLabel: " : ""}الصورة كبيرة جداً (${fileSizeMB(sizeBytes)}).'
      ' الحد الأقصى المسموح به هو ${fileSizeMB(kMaxSingleImageBytes)}.'
      ' يرجى اختيار صورة بجودة أقل.',
  '${fileLabel != null ? "$fileLabel: " : ""}Image is too large (${fileSizeMB(sizeBytes)}).'
      ' Maximum allowed is ${fileSizeMB(kMaxSingleImageBytes)}.'
      ' Please pick a lower-quality photo.',
  isArabic: isArabic,
);

String _collageImageTooLargeMsg(
  int sizeBytes, {
  required bool isArabic,
  String? fileLabel,
}) => _localised(
  '${fileLabel != null ? "$fileLabel: " : ""}الصورة المدمجة كبيرة جداً (${fileSizeMB(sizeBytes)}).'
      ' الحد الأقصى المسموح به هو ${fileSizeMB(kMaxCollageImageBytes)}.'
      ' يرجى إعادة التقاط الصور بإضاءة أفضل أو دقة أقل.',
  '${fileLabel != null ? "$fileLabel: " : ""}Collage image is too large (${fileSizeMB(sizeBytes)}).'
      ' Maximum allowed is ${fileSizeMB(kMaxCollageImageBytes)}.'
      ' Please retake the photos with better lighting or lower detail.',
  isArabic: isArabic,
);

// ─── Custom exception (clean user-facing message, no "Exception:" prefix) ────────

class ImageSizeException implements Exception {
  final String message;

  const ImageSizeException(this.message);

  @override
  String toString() => message;
}

// ─── Two-sided document holder ────────────────────────────────────────────────

class TwoSidedDoc {
  File? front;
  File? back;

  bool get isComplete => front != null && back != null;
}

// ─── Stitch params ────────────────────────────────────────────────────────────

class StitchParams {
  final String topPath;
  final String bottomPath;
  final String outputPath;
  final bool isArabic;
  final String? fileLabel;

  const StitchParams(
    this.topPath,
    this.bottomPath,
    this.outputPath, {
    this.isArabic = false,
    this.fileLabel,
  });
}

// Top-level so it can be called from a background isolate if needed.
// Future<File> stitchInBackground(StitchParams params) async {
//   final topBytes = await File(params.topPath).readAsBytes();
//   final bottomBytes = await File(params.bottomPath).readAsBytes();
//
//   final topImg = await decodeImageFromList(topBytes);
//   final bottomImg = await decodeImageFromList(bottomBytes);
//
//   final targetW = topImg.width > bottomImg.width
//       ? topImg.width
//       : bottomImg.width;
//   final topH = (topImg.height * targetW / topImg.width).round();
//   final bottomH = (bottomImg.height * targetW / bottomImg.width).round();
//
//   final recorder = ui.PictureRecorder();
//   final canvas = Canvas(recorder);
//
//   canvas.drawImageRect(
//     topImg,
//     Rect.fromLTWH(0, 0, topImg.width.toDouble(), topImg.height.toDouble()),
//     Rect.fromLTWH(0, 0, targetW.toDouble(), topH.toDouble()),
//     Paint(),
//   );
//   canvas.drawImageRect(
//     bottomImg,
//     Rect.fromLTWH(
//       0,
//       0,
//       bottomImg.width.toDouble(),
//       bottomImg.height.toDouble(),
//     ),
//     Rect.fromLTWH(0, topH.toDouble(), targetW.toDouble(), bottomH.toDouble()),
//     Paint(),
//   );
//
//   final picture = recorder.endRecording();
//   final stitched = await picture.toImage(targetW, topH + bottomH);
//   final byteData = await stitched.toByteData(format: ui.ImageByteFormat.png);
//   final bytes = byteData!.buffer.asUint8List();
//
//   // ── write as compressed JPEG instead of raw PNG ───────────────────────────
//   final tempPath = '${params.outputPath}.tmp.png';
//   await File(tempPath).writeAsBytes(bytes);
//
//   final compressedBytes = await FlutterImageCompress.compressWithFile(
//     tempPath,
//     quality: 99,
//     format: CompressFormat.jpeg,
//   );
//   await File(tempPath).delete(); // clean up temp PNG
//
//   final finalBytes = compressedBytes ?? bytes; // fallback to PNG if compress fails
//   await File(params.outputPath).writeAsBytes(finalBytes);
//
//   // ── collage size guard ────────────────────────────────────────────────────
//   final collageSize = finalBytes.length;
//   if (collageSize > kMaxCollageImageBytes) {
//     throw ImageSizeException(
//       _collageImageTooLargeMsg(
//         collageSize,
//         isArabic: params.isArabic,
//         fileLabel: params.fileLabel,
//       ),
//     );
//   }
//
//   return File(params.outputPath);
// }

// ─── ImagePickerService ───────────────────────────────────────────────────────

class ImagePickerService {
  static final _picker = ImagePicker();

  /// Shows source sheet, returns chosen [ImageSource] or null.
  static Future<ImageSource?> askSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const ImageSourceSheet(),
    );
  }

  /// Picks one image from [source], crops it, saves to app docs dir.
  static Future<File?> pickAndCrop(
    BuildContext context,
    ImageSource source, {
    String? cropTitle,
    String? fileLabel,
    CropAspectRatio? aspectRatio,
    bool lockAspectRatio = false,
  }) async {
    try {
      final xFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (xFile == null) return null;

      // ── guard #1: after image pick ────────────────────────────────────────
      if (!context.mounted) return null;

      final cropped = await ImageCropper().cropImage(
        sourcePath: xFile.path,
        aspectRatio: aspectRatio,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: cropTitle ?? 'Crop Image',
            toolbarColor: AppColors.kPrimaryColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: lockAspectRatio,
          ),
          IOSUiSettings(
            title: cropTitle ?? 'Crop Image',
            aspectRatioLockEnabled: lockAspectRatio,
            resetAspectRatioEnabled: !lockAspectRatio,
          ),
        ],
      );
      if (cropped == null) return null;

      // ── guard #2: after crop ──────────────────────────────────────────────
      if (!context.mounted) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final resultFile = await File(
        cropped.path,
      ).copy('${appDir.path}/$fileName');

      // ── single image size guard ───────────────────────────────────────────
      final sizeBytes = await resultFile.length();
      dLog('Image size: ${fileSizeMB(sizeBytes)}');
      if (sizeBytes > kMaxSingleImageBytes) {
        if (context.mounted) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          await _showSizeErrorDialog(
            context,
            message: _singleImageTooLargeMsg(
              sizeBytes,
              isArabic: isArabic,
              fileLabel: fileLabel,
            ),
            isArabic: isArabic,
          );
        }
        return null;
      }

      return resultFile;
    } catch (e) {
      if (context.mounted) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        showErrorBanner(
          context,
          isArabic ? 'حدث خطأ أثناء اختيار الصورة' : 'Error picking image',
        );
      }
      return null;
    }
  }

  /// ask source → pick → crop (single image).
  static Future<File?> pickSingle(
    BuildContext context, {
    String? cropTitle,
    String? fileLabel,
    CropAspectRatio? aspectRatio,
    bool lockAspectRatio = false,
  }) async {
    final source = await askSource(context);
    if (source == null) return null;

    if (!context.mounted) return null;

    return pickAndCrop(
      context,
      source,
      cropTitle: cropTitle,
      fileLabel: fileLabel,
      aspectRatio: aspectRatio,
      lockAspectRatio: lockAspectRatio,
    );
  }

  /// ask source ONCE → pick front → pick back (two-sided document).
  /// Calls [onUpdate] after both sides are saved so the caller can setState.
  static Future<void> pickTwoSided(
    BuildContext context,
    TwoSidedDoc doc,
    String docName, {
    required VoidCallback onUpdate,
  }) async {
    final source = await askSource(context);
    if (source == null) return;
    if (!context.mounted) return;
    final loc = AppLocalizations.of(context)!;

    // ── Front side instruction ────────────────────────────────────────────
    final proceedFront = await _showSidePrompt(
      context,
      title: docName,
      message: loc.takeFrontPhotoNow,
      icon: Icons.flip_to_front,
    );
    if (proceedFront != true) return;
    if (!context.mounted) return;

    final front = await pickAndCrop(
      context,
      source,
      cropTitle: '$docName – ${loc.front}',
      fileLabel: docName,
    );
    if (front == null) return;
    if (!context.mounted) return;

    // ── Back side instruction ─────────────────────────────────────────────
    final proceedBack = await _showSidePrompt(
      context,
      title: docName,
      message: loc.takeBackPhotoNow,
      icon: Icons.flip_to_back,
    );
    if (proceedBack != true) return;
    if (!context.mounted) return;

    final back = await pickAndCrop(
      context,
      source,
      cropTitle: '$docName – ${loc.back}',
      fileLabel: docName,
    );
    if (back == null) return;
    if (!context.mounted) return;

    doc.front = front;
    doc.back = back;
    onUpdate();
  }

  /// Shows a blocking error dialog for image size violations.
  static Future<void> _showSizeErrorDialog(
    BuildContext context, {
    required String message,
    required bool isArabic,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_size_select_large_outlined,
                size: 40,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'الصورة كبيرة جداً' : 'Image Too Large',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isArabic ? 'حسناً' : 'OK'),
          ),
        ],
      ),
    );
  }

  /// Shows a simple instruction dialog before each side.
  static Future<bool?> _showSidePrompt(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.kPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.kPrimaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              AppLocalizations.of(ctx)!.cancel,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx)!.continue_),
          ),
        ],
      ),
    );
  }

  /// Stitches two images into one vertical collage, off the main thread.
  // static Future<File> stitchImages(
  //   File top,
  //   File bottom, {
  //   bool isArabic = false,
  //   String? fileLabel,
  // }) async {
  //   final appDir = await getApplicationDocumentsDirectory();
  //   final outputPath =
  //       '${appDir.path}/collage_${DateTime.now().millisecondsSinceEpoch}.jpg';
  //   return stitchInBackground(
  //     StitchParams(
  //       top.path,
  //       bottom.path,
  //       outputPath,
  //       isArabic: isArabic,
  //       fileLabel: fileLabel,
  //     ),
  //   );
  // }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

/// Bottom sheet that returns an [ImageSource] — never calls picker itself.
class ImageSourceSheet extends StatelessWidget {
  const ImageSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            loc.chooseImageSource,
            style: AppTextStyles.bold14.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SourceOption(
                icon: Icons.camera_alt_outlined,
                label: loc.camera,
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              _SourceOption(
                icon: Icons.photo_library_outlined,
                label: loc.gallery,
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.kPrimaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.kPrimaryColor.withOpacity(0.3),
              ),
            ),
            child: Icon(icon, size: 32, color: AppColors.kPrimaryColor),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: AppTextStyles.regular14.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single-image picker card. Use for profile photo, criminal record, etc.
class SingleImagePickerCard extends StatelessWidget {
  final String label;
  final File? image;
  final VoidCallback onTap;
  final double height;

  const SingleImagePickerCard({
    super.key,
    required this.label,
    required this.image,
    required this.onTap,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.regular14),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: image != null
                    ? AppColors.kPrimaryColor
                    : Colors.grey.shade300,
                width: image != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: image != null ? Colors.white : Colors.grey.shade50,
            ),
            child: image != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          image!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                      Positioned(top: 8, right: 8, child: _EditBadge()),
                    ],
                  )
                : _EmptyPickerContent(
                    hint: AppLocalizations.of(context)!.tapToSelectImage,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Two-sided document picker card. Use for national ID, licenses, etc.
class TwoSidedDocPickerCard extends StatelessWidget {
  final String label;
  final TwoSidedDoc doc;
  final VoidCallback onTap;

  const TwoSidedDocPickerCard({
    super.key,
    required this.label,
    required this.doc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isComplete = doc.isComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.regular14),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isComplete
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isComplete ? loc.bothSides : loc.frontAndBackRequired,
                style: TextStyle(
                  fontSize: 11,
                  color: isComplete ? Colors.green[700] : Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isComplete
                    ? AppColors.kPrimaryColor
                    : Colors.grey.shade300,
                width: isComplete ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: isComplete
                ? _TwoSidedPreview(doc: doc)
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: _EmptyPickerContent(hint: loc.tapToAddFrontAndBack),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TwoSidedPreview extends StatelessWidget {
  final TwoSidedDoc doc;

  const _TwoSidedPreview({required this.doc});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        _SideImage(
          file: doc.front!,
          label: loc.front,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          showEditBadge: false,
        ),
        Container(height: 2, color: AppColors.kPrimaryColor.withOpacity(0.3)),
        _SideImage(
          file: doc.back!,
          label: loc.back,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(10),
          ),
          showEditBadge: true,
        ),
      ],
    );
  }
}

class _SideImage extends StatelessWidget {
  final File file;
  final String label;
  final BorderRadius borderRadius;
  final bool showEditBadge;

  const _SideImage({
    required this.file,
    required this.label,
    required this.borderRadius,
    required this.showEditBadge,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Image.file(
            file,
            height: 130,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black45,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          if (showEditBadge) Positioned(top: 8, right: 8, child: _EditBadge()),
        ],
      ),
    );
  }
}

class _EmptyPickerContent extends StatelessWidget {
  final String? hint;

  const _EmptyPickerContent({this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
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
          hint ?? AppLocalizations.of(context)!.tapToSelectImage,
          style: AppTextStyles.regular14.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          'JPG or PNG',
          style: AppTextStyles.regular14.copyWith(
            color: Colors.grey.shade500,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _EditBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.edit, color: Colors.white, size: 16),
    );
  }
}
