import 'package:flutter/material.dart';

import '../../../core/style/text_styles.dart';
import '../../static_text/app_dynamic_info.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(80.0),
          child: Text(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            isArabic && AppInfoManager().data!.termsAr.isNotEmpty
                ? AppInfoManager().data!.termsAr
                : AppInfoManager().data!.terms,
            textAlign: TextAlign.center,
            style: AppTextStyles.bold18,
          ),
        ),
      ),
    );
  }
}
