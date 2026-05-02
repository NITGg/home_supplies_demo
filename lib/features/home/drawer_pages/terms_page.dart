import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../core/widgets/circel_back_button.dart';
import '../../static_text/app_dynamic_info.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  bool _isHtml(String content) =>
      RegExp(r'<[a-zA-Z][^>]*>').hasMatch(content);

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final content =
    isArabic && AppInfoManager().data!.termsAr.isNotEmpty
        ? AppInfoManager().data!.termsAr
        : AppInfoManager().data!.terms;

    return Scaffold(
      appBar: AppBar(
        leading: CircleBackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: _isHtml(content)
              ? Html(data: content)
              : Text(content, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}