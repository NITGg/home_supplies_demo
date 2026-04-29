import 'dart:async';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/image_with_fallback.dart';
import '../../ad_manager/ad_cubit.dart';
import '../../ad_manager/ad_state.dart';
import '../../data/models/ad_model.dart';

class HomeAdsCarousel extends StatefulWidget {
  const HomeAdsCarousel({super.key});

  @override
  State<HomeAdsCarousel> createState() => _HomeAdsCarouselState();
}

class _HomeAdsCarouselState extends State<HomeAdsCarousel> {
  int _currentIndex = 0;
  Timer? _timer;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ─── Logic unchanged ────────────────────────────────────────────────────────

  void _startAutoPlay(List<AdModel> ads) {
    _timer?.cancel();
    if (ads.isEmpty) return;

    final duration = Duration(seconds: ads[_currentIndex].durationSeconds ?? 3);
    _timer = Timer(duration, () {
      if (mounted) {
        final nextIndex = (_currentIndex + 1) % ads.length;
        _carouselController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdsCubit, AdsState>(
      builder: (context, state) {
        if (state is AdsLoading) return _buildSkeletonLoader(context);
        if (state is AdsFailure) return const SizedBox.shrink();

        if (state is AdsSuccess) {
          final List<AdModel> sortedAds = List.from(state.homeAds);
          sortedAds.sort(
            (a, b) => (a.priority ?? 999).compareTo(b.priority ?? 999),
          );

          if (sortedAds.isEmpty) return const SizedBox.shrink();

          // Fix RangeError after delete and refresh
          if (_currentIndex >= sortedAds.length) _currentIndex = 0;

          // Start auto-play timer
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startAutoPlay(sortedAds);
          });

          return _buildCarousel(context, sortedAds);
        }

        return const SizedBox.shrink();
      },
    );
  }

  void navigateFromDeepLink(BuildContext context, String link) {
    // Accepts "/category/8", "/product/19", or full URL with same path
    final uri = Uri.parse(link);
    final segments = uri.pathSegments; // ['category', '8']

    if (segments.length < 2) return;

    final type = segments[0];
    final id = int.tryParse(segments[1]);

    if (id == null) return;

    switch (type) {
      case 'category':
        context.push(
          '/categories/$id',
        ); // matches GoRoute path '/categories/:id'
        break;
      case 'product':
        context.push('/products/$id'); // matches GoRoute path '/products/:id'
        break;
    }
  }

  Widget _buildCarousel(BuildContext context, List<AdModel> sortedAds) {
    return Container(
      color: AppColors.kBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Banner ──────────────────────────────────────────────────────────
          CarouselSlider(
            carouselController: _carouselController,
            options: CarouselOptions(
              aspectRatio: 3 / 1,
              autoPlay: false,
              // Disabled – we control it manually
              viewportFraction: 1.0,
              enableInfiniteScroll: true,
              scrollPhysics: const BouncingScrollPhysics(),
              onPageChanged: (index, reason) {
                setState(() => _currentIndex = index);
                // Restart auto-play regardless of scroll reason
                _startAutoPlay(sortedAds);
              },
            ),
            items: sortedAds.map((ad) {
              return Builder(
                builder: (context) {
                  return GestureDetector(
                    onTap: () {
                      if (ad.mobileScreen != null &&
                          ad.mobileScreen!.isNotEmpty &&
                          ad.mobileScreen != 'null') {
                        if (context.mounted) {
                          navigateFromDeepLink(context, ad.mobileScreen!);
                        }
                      } else if (ad.targetUrl.isNotEmpty) {
                        launchUrl(Uri.parse(ad.targetUrl));
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ImageWithIconFallback(
                          imageUrl: ad.imageUrl,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          iconSize: 40,
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // ── Dot indicators ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: sortedAds.asMap().entries.map((entry) {
              final isActive = _currentIndex == entry.key;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: isActive ? 22 : 6.0,
                height: 6.0,
                margin: const EdgeInsets.symmetric(horizontal: 3.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: isActive
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 3 / 1,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  width: index == 0 ? 22 : 6.0,
                  height: 6.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: index == 0 ? Colors.black : Colors.grey.shade300,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
