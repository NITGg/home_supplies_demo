import 'package:tawreedat_courier/core/utils/logger.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

import '../style/app_colors.dart';
import 'app_dynamic_settings.dart';

Future<bool> checkForUpdate(BuildContext context) async {
  dLog("checkForUpdate called");

  // Get current version
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  dLog("Current version: ${packageInfo.version}");
  String currentVersion = packageInfo.version;

  String? latestVersion;
  String? updateUrl;
  if (Platform.isAndroid) {
    latestVersion = AppSettings.android_version?.trim();
    updateUrl = AppSettings.android_url;
  } else if (Platform.isIOS) {
    latestVersion = AppSettings.ios_version;
    updateUrl = AppSettings.ios_url;
  }

  dLog("Latest version: $latestVersion");
  if (latestVersion != null &&
      latestVersion.isNotEmpty &&
      updateUrl != null &&
      updateUrl.isNotEmpty &&
      isUpdateAvailable(currentVersion, latestVersion)) {
    // Ensure the context is still mounted before showing the dialog.
    if (!context.mounted) return false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Lottie.asset(
                  'assets/animation_json/Update.json',
                  width: 120,
                  height: 120,
                ),
                  const SizedBox(height: 16),

                  const Text(
                    'يرجى تحديث التطبيق أولا للاستمرار في استخدام الخدمة',
                    style: TextStyle(color: Colors.black87, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final uri = Uri.parse(updateUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                        Future.delayed(const Duration(seconds: 1), () {
                          SystemNavigator.pop();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'اضغط هنا لتحديث التطبيق',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return true;
  }
  return false;
}

bool isUpdateAvailable(String currentVersion, String latestVersion) {
  final current = Version.parse(_normalizeVersion(currentVersion));
  final latest = Version.parse(_normalizeVersion(latestVersion));
  return latest > current;
}

String _normalizeVersion(String version) {
  final parts = version.trim().split('.');
  while (parts.length < 3) {parts.add('0');}
  return parts.take(3).join('.');
}
