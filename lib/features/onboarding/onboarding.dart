import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/style/app_colors.dart';
import '../../core/style/text_styles.dart';
import '../../core/utils/secure_storage_service.dart';
import '../../core/utils/api_client.dart';
import '../../core/widgets/loading_screen.dart';
import '../../core/widgets/text_button.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/manager/locale_cubit.dart';

class OnBoardingModel {
  OnBoardingModel({required this.onBoarding});

  final List<OnBoardingData> onBoarding;

  factory OnBoardingModel.fromJson(Map<String, dynamic> json) {
    return OnBoardingModel(
      onBoarding: json["onBoarding"] == null
          ? []
          : List<OnBoardingData>.from(
              json["onBoarding"]!.map((x) => OnBoardingData.fromJson(x)),
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    "on-boarding": onBoarding.map((x) => x.toJson()).toList(),
  };
}

class OnBoardingData {
  OnBoardingData({
    required this.title,
    required this.sortId,
    required this.titleAr,
    required this.subtitle,
    required this.content,
    required this.contentAr,
    required this.subtitleAr,
    required this.imageUrl,
  });

  final int sortId;
  final String title;
  final String titleAr;
  final String subtitle;
  final String subtitleAr;
  final String content;
  final String contentAr;
  final String imageUrl;

  factory OnBoardingData.fromJson(Map<String, dynamic> json) {
    return OnBoardingData(
      sortId: json["sort_id"],
      title: json["title"] ?? "",
      titleAr: json["title_ar"] ?? "",
      subtitle: json["subtitle"] ?? "",
      subtitleAr: json["subtitle_ar"] ?? "",
      content: json["content"] ?? "",
      contentAr: json["content_ar"] ?? "",
      imageUrl: json["image_url"] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
    "title": title,
    "sort_id": sortId,
    "title_ar": titleAr,
    "subtitle": subtitle,
    "subtitle_ar": subtitleAr,
    "image_url": imageUrl,
  };
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<OnBoardingData> _pages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchOnBoardingData();
  }

  Future<void> _fetchOnBoardingData() async {
    try {
      final response = await ApiClient.instance.dio.get('/on-boarding?sort=sort_id');
      if (mounted) {
        setState(() {
          final List<dynamic> onBoardingJson = response.data['items'];
          _pages = onBoardingJson
              .map(
                (json) => OnBoardingData.fromJson(json as Map<String, dynamic>),
              )
              .toList();
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load data: ${e.message}";
        });
      }
    } catch (e) {
      // Handle other exceptions
    }
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _goToPage(_currentPage + 1);
    } else {
      _finishOnboarding();
    }
  }

  void _prev() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  void _finishOnboarding() {
    SecureStorageService().setOnboardingShown();
    context.go('/auth/login');
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        // background color
        statusBarIconBrightness: Brightness.dark,
        // dark icons for light background
        statusBarBrightness: Brightness.light, // iOS
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_pages.length, (index) {
        final bool isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 2.0),
          width: isActive ? 22.6 : 7.38,
          height: isActive ? 5.55 : 7.38,
          decoration: BoxDecoration(
            color: isActive ? AppColors.kSecondaryColor : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: _isLoading
            ? const Center(child: LoadingScreen())
            : _error != null
            ? Center(child: Text(_error!))
            : _buildOnboardingContent(context),
      ),
    );
  }

  Widget _buildOnboardingContent(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // Determine if the screen height is small
    final bool isSmallScreen = size.height < 700;

    return Scaffold(
      body: Column(
        // The main content area using Expanded to take up available space
        children: [
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  reverse: true,
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    final isSvg = page.imageUrl.toLowerCase().endsWith('.svg');
                    return Column(
                      children: [
                        // Image carousel area
                        AnnotatedRegion<SystemUiOverlayStyle>(
                          value: _currentPage == 1
                              ? SystemUiOverlayStyle.light
                              : SystemUiOverlayStyle.dark,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double maxWidth = constraints.maxWidth;
                              final double maxHeight =
                                  MediaQuery.sizeOf(context).height *
                                  0.65; // cap height to 60% of screen

                              return Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: maxWidth,
                                    maxHeight:
                                        maxHeight, // prevent over-expanding on tablets
                                  ),
                                  child: isSvg
                                      ? SvgPicture.network(
                                          page.imageUrl,
                                          fit: BoxFit.contain,
                                          width: maxWidth,
                                          placeholderBuilder: (context) =>
                                              Center(
                                                child: SizedBox(
                                                  height: maxHeight,
                                                  child: LoadingScreen(
                                                    isOne: true,
                                                    asWidget: true,
                                                  ),
                                                ),
                                              ),
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stackTrace,
                                              ) => Container(
                                                color: Colors.grey.shade200,
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.image_not_supported,
                                                    size: 64,
                                                  ),
                                                ),
                                              ),
                                        )
                                      : Image.network(
                                          page.imageUrl,
                                          fit: BoxFit.contain,
                                          width: maxWidth,
                                          loadingBuilder:
                                              (context, child, progress) {
                                                if (progress == null) {
                                                  return child;
                                                }
                                                return Center(
                                                  child: SizedBox(
                                                    height: maxHeight,
                                                    child: const LoadingScreen(
                                                      isOne: true,
                                                      asWidget: true,
                                                    ),
                                                  ),
                                                );
                                              },
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stackTrace,
                                              ) => Container(
                                                color: Colors.grey.shade200,
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.image_not_supported,
                                                    size: 64,
                                                  ),
                                                ),
                                              ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: SizedBox(
                                width: 230,
                                child: Column(
                                  children: [
                                    SizedBox(height: isSmallScreen ? 10 : 28),

                                    // Dots
                                    Directionality(textDirection: TextDirection.ltr, child: _buildDots()),
                                    SizedBox(height: isSmallScreen ? 5 : 14),

                                    // Title
                                    Text(
                                      isArabic ? page.titleAr : page.title,
                                      textAlign: TextAlign.center,
                                      style: isSmallScreen
                                          ? AppTextStyles.bold25.copyWith(
                                              fontSize: 14,
                                            )
                                          : AppTextStyles.bold18.copyWith(
                                              fontSize: 20,
                                            ),
                                    ),

                                    SizedBox(height: isSmallScreen ? 5 : 15),

                                    // Subtitle
                                    Text(
                                      isArabic
                                          ? page.subtitleAr
                                          : page.subtitle,
                                      textAlign: TextAlign.center,
                                      style: isSmallScreen
                                          ? AppTextStyles.bold16.copyWith(
                                              fontSize: 12,
                                            )
                                          : AppTextStyles.bold18,
                                    ),

                                    const SizedBox(height: 5),

                                    // Content
                                    Text(
                                      isArabic ? page.contentAr : page.content,
                                      textAlign: TextAlign.center,
                                      style: isSmallScreen
                                          ? AppTextStyles.medium18.copyWith(
                                              fontSize: 10,
                                            )
                                          : AppTextStyles.medium18.copyWith(
                                              fontSize: 16,
                                            ),
                                    ),
                                    const SizedBox(height: 50),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                // Positioned 'skip' button
                Align(
                  alignment: AlignmentGeometry.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Row(
                      spacing: 100,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppTextButton(
                          text: AppLocalizations.of(context)!.skip,
                          onPressed: _finishOnboarding,
                          color: Colors.white,
                          underline: true,
                        ),
                        AppTextButton(
                          text: isArabic ? 'EN' : 'AR',
                          onPressed: () {
                            context.read<LocaleCubit>().toggleLocale();
                          },
                          color: Colors.white,
                          underline: true,
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentGeometry.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 8,
                      top: 18,
                      bottom: 60,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Next / Done button
                        SizedBox(
                          width: _currentPage == _pages.length - 1 ? 134 : 54,
                          height: 45,
                          child: ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.kPrimaryColor,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(18),
                                  bottomRight: Radius.circular(18),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                            child: _currentPage == _pages.length - 1
                                ? Text(
                                    AppLocalizations.of(context)!.continue_,
                                    style: AppTextStyles.bold14,
                                  )
                                : const Icon(
                                    Icons.arrow_back,
                                    color: Colors.black,
                                  ),
                          ),
                        ),
                        // Prev button (hidden on first page)
                        if (!(_currentPage == 0))
                          SizedBox(
                            width: 54,
                            height: 45,
                            child: ElevatedButton(
                              onPressed: _currentPage == 0 ? null : _prev,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.kPrimaryColor,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(18),
                                    bottomLeft: Radius.circular(18),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                elevation: 0,
                              ),
                              child: const Icon(
                                Icons.arrow_forward,
                                color: Colors.black,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Navigation controls at the bottom
        ],
      ),
    );
  }
}
