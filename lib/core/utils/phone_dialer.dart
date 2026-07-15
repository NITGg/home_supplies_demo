import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openPhoneApp(String phoneNumber) async {
  final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);

  // Check if the device can launch the dialer
  if (await canLaunchUrl(phoneUri)) {
    await launchUrl(
      phoneUri,
      mode:
          LaunchMode.platformDefault, // ensures it opens the default phone app
    );
  } else {
    debugPrint('Cannot open phone app for $phoneNumber');
  }
}
