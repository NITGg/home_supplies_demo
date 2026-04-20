import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/widgets/custom_button.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/widgets/circel_back_cutton.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../static_text/faq_manager.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFaqs();
  }

  Future<void> _loadFaqs() async {
    await FaqManager().loadFaqs();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: LoadingScreen(asWidget: true)));
    }

    final faqs = FaqManager().data?.faqs ?? [];

    if (faqs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.faq),
          centerTitle: true,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.kPrimaryColor,
          leading: CircleBackButton(),
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        size: 80,
                        color: AppColors.kSecondaryColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.noData,
                        style: AppTextStyles.bold16,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!
                            .noData, // add this key
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: AppCustomButton(
                onPressed: () => context.go('/mainHome'),
                text: AppLocalizations.of(context)!.continue_,
                isSecondary: true,
              ),
            ),
          ],
        ),
      );
    }


    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final filteredFaqs = faqs
        .where((f) => f.language.toUpperCase() == (isArabic ? 'AR' : 'EN'))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.faq),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: BackButton(color:
        Colors.black,
        ),
        backgroundColor: AppColors.kPrimaryColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: filteredFaqs.length,
              itemBuilder: (context, index) {
                final faq = filteredFaqs[index];
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.1),
                  clipBehavior: Clip.antiAlias,
                  // Ensures content respects the border radius
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      iconColor: AppColors.kPrimaryColor,
                      collapsedIconColor: AppColors.kSecondaryColor,
                      title: Text(
                        faq.question,
                        style: AppTextStyles.bold16.copyWith(
                          color: const Color(0xFF333333),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          color: Colors.white,
                          child: Text(
                            faq.answer,
                            style: AppTextStyles.regular14.copyWith(
                              height: 1.5,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SafeArea(
            child: AppCustomButton(
              onPressed: () {
                context.go('/mainHome');
              },
              text: AppLocalizations.of(context)!.continue_,
              isSecondary: true,
            ),
          ),
        ],
      ),
    );
  }
}
