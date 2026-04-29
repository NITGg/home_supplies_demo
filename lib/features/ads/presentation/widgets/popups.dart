import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/secure_storage_service.dart';
import '../../../../core/widgets/image_with_fallback.dart';
import '../../ad_manager/ad_cubit.dart';
import '../../ad_manager/ad_state.dart';
import '../../data/models/ad_model.dart';

class PopupAdsHandler extends StatefulWidget {
  const PopupAdsHandler({super.key});

  @override
  State<PopupAdsHandler> createState() => _PopupAdsHandlerState();
}

class _PopupAdsHandlerState extends State<PopupAdsHandler> {
  static const _storageKey = 'shownPopupAdIds';

  Set<int> _shownAdIds = {};
  final _storage = SecureStorageService();

  /// Signals when storage has finished loading.
  final Completer<void> _idsLoaded = Completer<void>();

  /// Prevents multiple concurrent popup sequences from running.
  bool _isSequenceRunning = false;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadShownAdIds();
  }

  Future<void> _loadShownAdIds() async {
    final storedIds = await _storage.readValue(_storageKey);
    if (storedIds != null && storedIds.isNotEmpty) {
      final ids = storedIds.split(',').map(int.parse).toSet();
      if (mounted) setState(() => _shownAdIds = ids);
    }
    _idsLoaded.complete();
  }

  Future<void> _persistShownIds() async {
    // Always mutate the set regardless of mounted state,
    // then write the correct value to storage.
    await _storage.writeValue(_storageKey, _shownAdIds.join(','));
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


  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdsCubit, AdsState>(
      listener: (context, state) {
        if (state is AdsSuccess && state.popupAds.isNotEmpty) {
          _showPopupSequence(context, state.popupAds);
        }
      },
      child: const SizedBox.shrink(),
    );
  }

  Future<void> _showPopupSequence(
      BuildContext context,
      List<AdModel> ads,
      ) async {
    // Drop duplicate calls while a sequence is already running.
    if (_isSequenceRunning) return;
    _isSequenceRunning = true;

    try {
      // Wait until storage is loaded before any contains() check.
      await _idsLoaded.future;

      for (final ad in ads) {
        if (_shownAdIds.contains(ad.id)) continue;
        if (!mounted) break;
        await _showPopupAd(context, ad);
      }
    } finally {
      _isSequenceRunning = false;
    }
  }

  Future<void> _showPopupAd(BuildContext context, AdModel ad) async {
    double widthFactor = 0.8;
    double heightFactor = 0.5;

    switch (ad.popupSize.toLowerCase()) {
      case 'small':
        widthFactor = 0.6;
        heightFactor = 0.35;
        break;
      case 'test':
        widthFactor = 0.5;
        heightFactor = 0.25;
        break;
      case 'medium':
        widthFactor = 0.8;
        heightFactor = 0.5;
        break;
      case 'large':
        widthFactor = 0.95;
        heightFactor = 0.7;
        break;
    }

    final duration = Duration(seconds: ad.durationSeconds);

    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: ad.closable,
        barrierColor: Colors.black.withOpacity(0.65),
        builder: (context) {
          Future.delayed(duration, () {
            if (!context.mounted) return;
            if (Navigator.canPop(context)) Navigator.pop(context);
          });

          return Stack(
            alignment: Alignment.center,
            children: [
              // ── Dialog card ─────────────────────────────────────────────
              FractionallySizedBox(
                widthFactor: widthFactor,
                heightFactor: heightFactor,
                child: Dialog(
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // ── Ad image ───────────────────────────────────
                        GestureDetector(
                          onTap: () {
                            if (ad.mobileScreen != null &&
                                ad.mobileScreen!.isNotEmpty &&
                                ad.mobileScreen != 'null') {
                              navigateFromDeepLink(context, ad.mobileScreen!);
                            } else if (ad.targetUrl.isNotEmpty) {
                              launchUrl(Uri.parse(ad.targetUrl));
                            }
                          },
                          child: ImageWithIconFallback(
                            imageUrl: ad.imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            iconSize: 56,
                          ),
                        ),

                        // ── Text overlay ───────────────────────────────
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Builder(
                            builder: (context) {
                              final isArabic =
                                  Localizations.localeOf(
                                    context,
                                  ).languageCode ==
                                      'ar';

                              String title = ad.title;
                              String description = ad.description;

                              if (isArabic) {
                                title = ad.titleAr.isNotEmpty
                                    ? ad.titleAr
                                    : ad.title;
                                description = ad.descriptionAr.isNotEmpty
                                    ? ad.descriptionAr
                                    : ad.description;
                              }

                              if (title.isEmpty && description.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (title.isNotEmpty)
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    if (title.isNotEmpty &&
                                        description.isNotEmpty)
                                      const SizedBox(height: 2),
                                    if (description.isNotEmpty)
                                      Text(
                                        description,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // ── Close button ───────────────────────────────
                        if (ad.closable)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Countdown chip ───────────────────────────────────────────
              if (ad.durationSeconds > 0)
                Positioned(
                  bottom: 24,
                  child: TweenAnimationBuilder<Duration>(
                    duration: duration,
                    tween: Tween(begin: duration, end: Duration.zero),
                    builder: (context, value, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Closing in ${value.inSeconds}...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      );
    }

    // ── Persist after dialog closes ────────────────────────────────────────
    // IMPORTANT: mutate the set unconditionally — do NOT put .add() inside
    // an `if (mounted)` check, otherwise the id is never stored when the
    // widget is disposed before the dialog closes.
    _shownAdIds.add(ad.id);
    if (mounted) setState(() {});   // refresh UI only if still alive
    await _persistShownIds();       // always write the correct set to storage
  }
}