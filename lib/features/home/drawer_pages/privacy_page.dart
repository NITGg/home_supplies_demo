import 'package:flutter/material.dart';
import '../../../core/style/text_styles.dart';
import '../../static_text/app_dynamic_info.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(80.0),
          child: Text(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            isArabic && AppInfoManager().data!.privacyPolicyAr.isNotEmpty
                ? AppInfoManager().data!.privacyPolicyAr
                : AppInfoManager().data!.privacyPolicy,
            textAlign: TextAlign.center,
            style: AppTextStyles.bold18,
          ),
        ),
      ),
    );
  }
}
