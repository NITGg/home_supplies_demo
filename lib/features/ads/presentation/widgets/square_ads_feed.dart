import 'dart:async';
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

class SquareAdsFeed extends StatelessWidget {
  /// Optional: filter ads by a tag/type if your AdModel supports it.
  /// Leave null to show all home ads.
  final String? filterTag;

  const SquareAdsFeed({super.key, this.filterTag});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdsCubit, AdsState>(
      builder: (context, state) {
        if (state is AdsLoading) return const _SquareAdsSkeleton();
        if (state is AdsFailure) return const SizedBox.shrink();

        if (state is AdsSuccess) {
          List<AdModel> ads = List.from(state.feedAds);
          ads.sort((a, b) => (a.priority ?? 999).compareTo(b.priority ?? 999));

          if (ads.isEmpty) return const SizedBox.shrink();

          return _SquareAdsList(ads: ads);
        }

        return const SizedBox.shrink();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feed list
// ─────────────────────────────────────────────────────────────────────────────

class _SquareAdsList extends StatelessWidget {
  final List<AdModel> ads;

  const _SquareAdsList({required this.ads});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: ads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => _SquareAdCard(ad: ads[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single card — mimics a Facebook-style post card
// ─────────────────────────────────────────────────────────────────────────────

class _SquareAdCard extends StatefulWidget {
  final AdModel ad;

  const _SquareAdCard({required this.ad});

  @override
  State<_SquareAdCard> createState() => _SquareAdCardState();
}

class _SquareAdCardState extends State<_SquareAdCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _onTap(BuildContext context) async {
    await _pressController.forward();
    await _pressController.reverse();

    if (!context.mounted) return;

    final ad = widget.ad;
    if (ad.targetUrl.isNotEmpty) {
      launchUrl(Uri.parse(ad.targetUrl));
    }
  }
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pressScale,
      child: GestureDetector(
        onTap: () => _onTap(context),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Square image ───────────────────────────────────────────────
              AspectRatio(
                aspectRatio: 1,
                child: ImageWithIconFallback(
                  imageUrl: widget.ad.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  iconSize: 48,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loader
// ─────────────────────────────────────────────────────────────────────────────

class _SquareAdsSkeleton extends StatelessWidget {
  const _SquareAdsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(color: Colors.grey[300]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
