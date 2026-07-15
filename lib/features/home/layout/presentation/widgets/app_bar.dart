// ── AppLayoutAppBar ───────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:tawreedat_courier/core/widgets/banners.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../auth/manager/profile_cubit.dart';
import '../../../../notifications/notifications_dialog.dart';
import '../../../../orders/manager/orders_cubit.dart';
import '../../manager/availability_cubit.dart';

class AppLayoutAppBar extends StatefulWidget {
  const AppLayoutAppBar({super.key, required this.localizations});

  final AppLocalizations localizations;

  @override
  State<AppLayoutAppBar> createState() => _AppLayoutAppBarState();
}

class _AppLayoutAppBarState extends State<AppLayoutAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _companyLogoOpacity;
  late Animation<double> _companyLogoScale;
  late Animation<double> _appLogoOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.9,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 0.1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.1,
          end: -0.1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.1,
          end: 0.05,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.05,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    _appLogoOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 40),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _companyLogoOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    _companyLogoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerEasterEgg() {
    if (!_controller.isAnimating) _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.read<ProfileCubit>().currentProfile;

    return AppBar(
      automaticallyImplyLeading: false,
      scrolledUnderElevation: 0,
      elevation: 0,
      actions: const [SizedBox.shrink()],
      // Inside AppLayoutAppBar.build, replace the existing CircleAvatar + Spacer + logo row:
      title: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            // ── Left cluster: notification + availability ──────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  child: NotificationButton(
                    userId: profile?.id.toString() ?? '',
                  ),
                ),
                // ── Availability chip ──────────────────────────────────────
                BlocConsumer<AvailabilityCubit, AvailabilityState>(
                  listener: (context, state) {
                    if (state.blockedReason != null) {
                      showErrorBanner(context, state.blockedReason??'');
                    }
                  },
                  builder: (context, state) {
                    final isAvailable = state.isAvailable;
                    final isLoading = state.isLoading;

                    return GestureDetector(
                      onTap: isLoading
                          ? null
                          : () async {
                        // Read active orders from OrderCubit before toggling
                        final hasActive = context
                            .read<OrderCubit>()
                            .hasActiveOrders;
                        await context.read<AvailabilityCubit>().toggle(
                          hasActiveOrders: await hasActive,
                          onGoingUnavailable: () {
                            context.read<OrderCubit>().blockAvailableOrdersFetch();
                          },
                          onGoingAvailable: () {                              // 👈 add this callback too
                            context.read<OrderCubit>().unblockAvailableOrdersFetch(context);
                          },
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isLoading
                              ? Colors.grey.withOpacity(0.1)
                              : isAvailable
                              ? Colors.green.withOpacity(0.12)
                              : Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isLoading
                                ? Colors.grey.shade400
                                : isAvailable
                                ? Colors.green
                                : Colors.orange,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 5,
                          children: [
                            if (isLoading)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.grey,
                                ),
                              )
                            else
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Icon(
                                  isAvailable
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.do_not_disturb_off_rounded,
                                  key: ValueKey(isAvailable),
                                  size: 13,
                                  color: isAvailable
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                isLoading
                                    ? '...'
                                    : isAvailable
                                    ? AppLocalizations.of(context)!.isAvailable
                                    : AppLocalizations.of(context)!.isNotAvailable,
                                key: ValueKey('$isAvailable$isLoading'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isLoading
                                      ? Colors.grey
                                      : isAvailable
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const Spacer(),

            // ── Logo (unchanged easter-egg logic) ─────────────────────────
            GestureDetector(
              onTap: _triggerEasterEgg,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: _appLogoOpacity.value,
                            child: child!,
                          ),
                          if (_companyLogoOpacity.value > 0)
                            Opacity(
                              opacity: _companyLogoOpacity.value,
                              child: Transform.scale(
                                scale: _companyLogoScale.value,
                                child: SvgPicture.asset(
                                  'assets/images/appbar/company_logo.svg',
                                  height: 30,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                child: SvgPicture.asset(
                  'assets/images/appbar/logo.svg',
                  height: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}