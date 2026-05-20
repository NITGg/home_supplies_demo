import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/banners.dart';
import 'package:tawreedat_go/features/coupons/manager/coupons_cubit.dart';
import 'package:tawreedat_go/features/wallet/manager/wallet_cubit.dart';
import 'package:tawreedat_go/features/wallet/manager/wallet_state.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/socket_service.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../core/widgets/login_prompt.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../addresses/data/models/governorate_model.dart';
import '../../../addresses/manager/address_cubit.dart';
import '../../../addresses/manager/governorate_cubit.dart';
import '../../../addresses/manager/governorate_states.dart';
import '../../../addresses/presentation/default_address_chip.dart';
import '../../../addresses/presentation/default_address_picker_sheet.dart';
import '../../../ads/ad_manager/ad_cubit.dart';
import '../../../auth/manager/auth_cubit.dart';
import '../../../../core/utils/secure_storage_service.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../../../auth/manager/auth_state.dart';
import '../../../auth/manager/profile_cubit.dart';
import '../../../auth/manager/profile_states.dart';
import '../../../categories/presentation/categories_screen.dart';
import '../../../chat/config/chat_injection.dart';
import '../../../coupons/presentation/coupons_ticker_title.dart';
import '../../../notifications/presentation/widgets/notification_dialog.dart';
import '../../../orders/data/models/order_model.dart';
import '../../../orders/manager/order_cubit.dart';
import '../../../orders/manager/order_states.dart';
import '../../../orders/presentation/orders_list_screen.dart';
import '../../../orders/presentation/widgets/sheets/create_order_sheet/create_order_sheet.dart';
import '../../../orders/presentation/widgets/sheets/proposal_sheet.dart';
import '../../../referral/refferal_service.dart';
import '../../../static_text/app_dynamic_info.dart';
import '../manager/guest_cubit.dart';
import '../manager/home_cubit.dart';
import 'go_button.dart';

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> with WidgetsBindingObserver {
  StreamSubscription? _newOfferSubscription;
  final ValueNotifier<bool> _categoriesEmpty = ValueNotifier(false);

  // ── Guest mode ─────────────────────────────────────────────────────────────
  // _isGuest: plain bool for reactive rebuilds of HomeLayout itself.
  // so it can react to the value even though the widget is created only once.
  bool _isGuest = false;

  String _userId = '';
  late final HomeCubit _homeCubit = HomeCubit();
  late final CouponCubit _couponCubit = CouponCubit()..loadCoupons();
  bool _firstOrderChecked = false;
  bool _phoneSheetShown = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _screens = [
    CategoriesScreen(onEmptyChanged: (v) => _categoriesEmpty.value = v),
    const OrdersListScreen(),
  ];

  // ── Life-cycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    notificationDialogTrigger.addListener(_onExternalNotificationTrigger);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ── 0. Determine guest mode first ────────────────────────────────────
      await _checkGuestMode();

      // Guests can browse categories without any authenticated services.
      if (_isGuest) return;

      // ── 1. Connect socket ─────────────────────────────────────────────────
      await _connectSocket();

      // ── 2. Fetch profile and wallet ───────────────────────────────────────
      if (mounted) {
        context.read<ProfileCubit>().fetchProfile();
        context.read<WalletCubit>().fetchWalletData();
      }

      // ── 3. Subscribe to order offer events ────────────────────────────────
      _newOfferSubscription = SocketService().onNewOffer.listen((data) {
        if (mounted) _handleNewOffer(data);
      });
    });
  }

  /// Checks for a stored token and marks the session as guest when absent.
  Future<void> _checkGuestMode() async {
    final token = await SecureStorageService().getToken();
    final guest = token == null || token.isEmpty;
    if (mounted) {
      setState(() => _isGuest = guest);
      // ← Propagate guest mode to cubits so they skip 401-bound API calls
      context.read<OrderCubit>().setGuestMode(guest);
      context.read<AddressCubit>().setGuestMode(guest);
      context.read<GuestModeCubit>().setGuest(guest);
    }
  }

  /// Reads the token and connects the shared socket.
  Future<void> _connectSocket() async {
    final token = await SecureStorageService().getToken();
    if (token == null || token.isEmpty) return;
    SocketService().connect(
      baseUrl: 'https://tawreedat.nitg-eg.com',
      accessToken: token,
    );
  }

  void _onExternalNotificationTrigger() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showNotificationsDialog(
        context,
        _userId,
        homeCubit: _homeCubit,
        couponCubit: _couponCubit,
      );
    });
  }

  void _showPendingNotificationDialog() {
    if (!mounted) return;
    if (pendingNotificationData == null && !shouldShowNotificationDialog) {
      return;
    }

    shouldShowNotificationDialog = false;
    pendingNotificationData = null;

    showNotificationsDialog(
      context,
      _userId,
      homeCubit: _homeCubit,
      couponCubit: _couponCubit,
    );
  }

  @override
  void dispose() {
    _newOfferSubscription?.cancel();
    _homeCubit.close();
    _couponCubit.close();
    WidgetsBinding.instance.removeObserver(this);
    notificationDialogTrigger.removeListener(_onExternalNotificationTrigger);
    _categoriesEmpty.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _ensureSocketConnection();
    }
  }

  Object? _lastHandledExtra;

  Future<void> _ensureSocketConnection() async {
    if (_isGuest) return;
    final socketService = SocketService();
    if (!socketService.isConnected) {
      await _connectSocket();
    }
  }

  void _handleNewOffer(Map<String, dynamic> data) {
    final ctx = _scaffoldKey.currentContext;
    if (ctx == null) return;

    final l10n = AppLocalizations.of(ctx);
    final orderId = data['orderId'] as int?;

    showSuccessBanner(
      ctx,
      l10n?.newProposalReceived ?? 'New Proposal Received!',
      actionLabel: l10n?.view ?? 'View',
      onAction: () {
        if (orderId != null) _findAndShowProposals(orderId);
      },
    );
  }

  void _findAndShowProposals(int orderId) {
    final ctx = _scaffoldKey.currentContext;
    if (ctx == null) return;

    OrderCubit cubit;
    try {
      cubit = ctx.read<OrderCubit>();
    } catch (_) {
      return;
    }

    cubit.loadActiveOrders(loadMore: false).then((_) {
      if (!mounted) return;
      final state = cubit.state;
      if (state is OrdersLoaded) {
        final order = state.orders.firstWhereOrNull((o) => o.id == orderId);
        if (order != null) _showProposals(order);
      }
    });
  }

  void _showProposals(Order order) {
    final ctx = _scaffoldKey.currentContext;
    if (ctx == null) return;

    OrderCubit cubit;
    try {
      cubit = ctx.read<OrderCubit>();
    } catch (_) {
      return;
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: OrderProposalsSheet(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final extra = GoRouterState.of(context).extra;
    if (extra is GoToTab && extra != _lastHandledExtra) {
      _lastHandledExtra = extra;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Guests may not switch to the orders tab.
        if (!_isGuest || extra.index == 0) {
          if (mounted) _homeCubit.changeTab(extra.index);
        }
      });
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _homeCubit),
        BlocProvider.value(value: _couponCubit),
        BlocProvider<GovernorateCubit>(
          create: (_) => GovernorateCubit()..loadGovernorates(),
        ),
        BlocProvider(create: (context) => AdsCubit()..getHomeAds()),
      ],
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final cubit = context.read<HomeCubit>();

          return BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, profileState) {
              final profile = profileState is ProfileLoaded
                  ? profileState.profile
                  : null;

              return MultiBlocListener(
                listeners: [
                  BlocListener<AuthCubit, AuthState>(
                    listener: (context, state) {
                      if (state is AuthUpdateSuccess) {
                        context.read<ProfileCubit>().fetchProfile();
                      }
                    },
                  ),
                  BlocListener<ProfileCubit, ProfileState>(
                    listener: (context, profileState) async {
                      if (profileState is! ProfileLoaded) return;

                      setState(
                        () => _userId = profileState.profile.id.toString(),
                      );

                      if (!ChatModule.isInitialized) {
                        ChatModule.init(currentUserId: profileState.profile.id);
                      }

                      if (profileState.profile.referralCode == null) {
                        ReferralCaptureService.captureOnFirstLaunch(
                          userId: _userId,
                        ).then((code) {
                          if (code != null && context.mounted) {
                            showSuccessBanner(
                              context,
                              'your referral code is: $code',
                            );
                          }
                        });
                      }

                      if (_firstOrderChecked) return;
                      _firstOrderChecked = true;

                      if (profileState.profile.phone == null &&
                          !_phoneSheetShown) {
                        _phoneSheetShown = true;
                        await _showPhoneNumberBottomSheet(context);
                      }

                      if (!mounted) return;
                      _showPendingNotificationDialog();

                    },
                  ),
                ],
                child: Scaffold(
                  key: _scaffoldKey,
                  appBar: PreferredSize(
                    preferredSize: Size.fromHeight(Platform.isIOS ? 60 : 70),
                    child: AppLayoutAppBar(
                      scaffoldKey: _scaffoldKey,
                      localizations: localizations,
                      userId: _userId,
                      categoriesEmpty: _categoriesEmpty,
                      isGuest: _isGuest,
                    ),
                  ),
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.centerDocked,
                  floatingActionButton: FloatingActionButton.large(
                    onPressed: () async {
                      // Guests cannot create orders — show login prompt instead.
                      if (_isGuest) {
                        showGuestLoginPrompt(context);
                        return;
                      }

                      final govState = context.read<GovernorateCubit>().state;
                      final governorates = govState is GovernoratesLoaded
                          ? govState.response
                          : GovernoratesResponse(
                              governorates: [],
                              totalCount: 0,
                              totalPages: 0,
                            );
                      final walletCubit = context.read<WalletCubit>();
                      final balance =
                          walletCubit.cachedWalletData?.wallet.balance ?? 0.0;
                      if(!context.mounted) return;
                      showModalBottomSheet<Order>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => BlocProvider.value(
                          value: _couponCubit,
                          child: CreateOrderBottomSheet(
                            governorates: governorates,
                            walletBalance: balance,
                            initialCouponCode: '',
                          ),
                        ),
                      ).then((order) {
                        if (order != null && mounted) {
                          _homeCubit.changeTab(1);
                        }
                      });
                    },
                    backgroundColor: AppColors.kSecondaryColor,
                    shape: const CircleBorder(),
                    child: AnimatedGoButton(),
                  ),
                  endDrawer: Drawer(
                    backgroundColor: AppColors.kBackgroundColor,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: EdgeInsets.zero,
                                children: [
                                  // ── Drawer header ──────────────────────────
                                  BlocBuilder<WalletCubit, WalletState>(
                                    builder: (context, walletState) {
                                      final walletCubit = context
                                          .read<WalletCubit>();
                                      final badge = walletCubit.currentBadge;
                                      final isArabic =
                                          localizations.localeName == 'ar';

                                      final badgeName = badge == null
                                          ? null
                                          : isArabic &&
                                                (badge.nameAr?.isNotEmpty ??
                                                    false)
                                          ? badge.nameAr
                                          : badge.name;

                                      return DrawerHeader(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF2D3436),
                                              Color(0xFF636E72),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: GestureDetector(
                                          // Guests cannot navigate to profile.
                                          onTap: _isGuest
                                              ? null
                                              : () => context.push(
                                                  '/ProfileScreen',
                                                ),
                                          child: Row(
                                            spacing: 10,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 10.0,
                                                ),
                                                child: _ProfileAvatar(
                                                  imageUrl: _isGuest
                                                      ? null
                                                      : profile?.personalPhoto,
                                                  badgeName: _isGuest
                                                      ? null
                                                      : badgeName,
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  spacing: 10,
                                                  children: [
                                                    Text(
                                                      localizations.welcome,
                                                      style: AppTextStyles
                                                          .bold16
                                                          .copyWith(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                    Text(
                                                      localizations
                                                          .tawreedatIsYourBestChoice,
                                                      style: AppTextStyles
                                                          .regular14
                                                          .copyWith(
                                                            fontSize: 12,
                                                            color: Colors.white,
                                                          ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  // ── Menu items ─────────────────────────────
                                  Padding(
                                    padding: const EdgeInsets.all(17.0),
                                    child: Material(
                                      elevation: 4,
                                      color: Colors.white,
                                      shadowColor: Colors.black.withOpacity(
                                        0.1,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Column(
                                        children: [
                                          // ── Language — always visible ──────
                                          ListTile(
                                            leading: const Icon(
                                              Icons.language_outlined,
                                            ),
                                            title: Text(
                                              localizations.lang,
                                              style: AppTextStyles.bold16,
                                            ),
                                            trailing: SizedBox(
                                              width: 100,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'EN',
                                                    style:
                                                        AppTextStyles.regular14,
                                                  ),
                                                  Switch(
                                                    value:
                                                        localizations
                                                            .localeName ==
                                                        'ar',
                                                    onChanged: (value) =>
                                                        context
                                                            .read<LocaleCubit>()
                                                            .toggleLocale(),
                                                    trackOutlineColor:
                                                        WidgetStateProperty.resolveWith(
                                                          (_) => AppColors
                                                              .kPrimaryColor,
                                                        ),
                                                    activeThumbColor:
                                                        AppColors.kPrimaryColor,
                                                    activeTrackColor:
                                                        Colors.white,
                                                    inactiveTrackColor:
                                                        Colors.white,
                                                    inactiveThumbColor:
                                                        AppColors.kPrimaryColor,
                                                  ),
                                                  Text(
                                                    'AR',
                                                    style:
                                                        AppTextStyles.regular14,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            onTap: () => context
                                                .read<LocaleCubit>()
                                                .toggleLocale(),
                                          ),

                                          // ── Account items — hidden for guests ──
                                          if (!_isGuest) ...[
                                            if (profileState is ProfileLoaded &&
                                                profileState.profile.roleId
                                                        .toString() ==
                                                    '4') ...[
                                              const Divider(),
                                              ListTile(
                                                onTap: () => context.push(
                                                  '/ReferralQrScreen',
                                                ),
                                                leading: const Icon(
                                                  Icons.share,
                                                ),
                                                title: Text(
                                                  localizations.referral,
                                                  style: AppTextStyles.bold16,
                                                ),
                                              ),
                                            ],
                                            const Divider(),
                                            ListTile(
                                              onTap: () =>
                                                  context.push('/cart'),
                                              leading: const Icon(
                                                Icons.shopping_cart_rounded,
                                              ),
                                              title: Text(
                                                localizations.cart,
                                                style: AppTextStyles.bold16,
                                              ),
                                            ),
                                            const Divider(),
                                            ListTile(
                                              onTap: () =>
                                                  context.push('/WalletScreen'),
                                              leading: const Icon(
                                                Icons
                                                    .account_balance_wallet_rounded,
                                              ),
                                              title: Text(
                                                localizations.wallet,
                                                style: AppTextStyles.bold16,
                                              ),
                                            ),
                                            const Divider(),
                                            ListTile(
                                              onTap: () {
                                                context.pop();
                                                showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  isDismissible: false,
                                                  enableDrag: false,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  builder: (_) =>
                                                      BlocProvider.value(
                                                        value: context
                                                            .read<
                                                              AddressCubit
                                                            >(),
                                                        child:
                                                            const DefaultAddressPickerSheet(),
                                                      ),
                                                );
                                              },
                                              leading: const Icon(
                                                Icons.location_pin,
                                              ),
                                              title: Text(
                                                localizations.address,
                                                style: AppTextStyles.bold16,
                                              ),
                                            ),
                                            const Divider(),
                                            ListTile(
                                              onTap: () => context.push(
                                                '/ProfileScreen',
                                              ),
                                              leading: const Icon(Icons.person),
                                              title: Text(
                                                localizations.profile,
                                                style: AppTextStyles.bold16,
                                              ),
                                            ),
                                            const Divider(),
                                            ListTile(
                                              onTap: () => context.push(
                                                '/ReviewsScreen',
                                              ),
                                              leading: const Icon(
                                                Icons.star_half,
                                              ),
                                              title: Text(
                                                localizations.reviews,
                                                style: AppTextStyles.bold16,
                                              ),
                                            ),
                                            const Divider(),
                                            ListTile(
                                              onTap: () =>
                                                  context.push('/FaqPage'),
                                              leading: const Icon(
                                                Icons.question_mark,
                                              ),
                                              title: Text(
                                                localizations.faq,
                                                style: AppTextStyles.bold16,
                                              ),
                                            ),
                                          ],

                                          // ── Public items — always visible ──
                                          const Divider(),
                                          ListTile(
                                            onTap: () => context.push(
                                              '/KnowUsMoreScreen',
                                            ),
                                            leading: const Icon(Icons.favorite),
                                            title: Text(
                                              localizations.knowUsMore,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                          const Divider(),
                                          ListTile(
                                            onTap: () {
                                              launchUrl(
                                                Uri.parse(
                                                  "https://wa.me/${AppInfoManager().data!.supportNumber.replaceAll(' ', '')}",
                                                ),
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            },
                                            leading: const Icon(
                                              Icons.support_agent_rounded,
                                            ),
                                            title: Text(
                                              localizations.support,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                          const Divider(),
                                          ListTile(
                                            onTap: () =>
                                                context.push('/PrivacyPage'),
                                            leading: const Icon(
                                              Icons.policy_rounded,
                                            ),
                                            title: Text(
                                              localizations.privecyPolicy,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                          const Divider(),
                                          ListTile(
                                            onTap: () => context.push('/Terms'),
                                            leading: const Icon(Icons.lock),
                                            title: Text(
                                              localizations.termsAndConditions,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── Logout (authenticated) / Login (guest) ────────
                            if (_isGuest)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 17.0,
                                ),
                                child: Material(
                                  elevation: 1,
                                  color: AppColors.kPrimaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      context.go('/auth/login');
                                    },
                                    child: SizedBox(
                                      height: 70,
                                      width: double.infinity,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        spacing: 10,
                                        children: [
                                          const Icon(
                                            Icons.login_rounded,
                                            color: Colors.black,
                                          ),
                                          Text(
                                            localizations.signin,
                                            style: AppTextStyles.bold16
                                                .copyWith(color: Colors.black),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              FutureBuilder(
                                future: SecureStorageService().getToken(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Expanded(
                                      child: Center(
                                        child: LoadingScreen(asWidget: true),
                                      ),
                                    );
                                  } else if (snapshot.hasData &&
                                      snapshot.data != null) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 17.0,
                                      ),
                                      child: Material(
                                        elevation: 1,
                                        color: Colors.white,
                                        shadowColor: AppColors.kPrimaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          onTap: () async {
                                            await context
                                                .read<AuthCubit>()
                                                .logout();
                                            ChatModule.dispose();
                                            await SecureStorageService()
                                                .clearAll();
                                            if (context.mounted) {
                                              context.go('/auth/login');
                                            }
                                          },
                                          child: Container(
                                            color: Colors.white,
                                            height: 70,
                                            width: double.infinity,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              spacing: 10,
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/images/drawer/logout.svg',
                                                ),
                                                Text(
                                                  localizations.logout,
                                                  style: AppTextStyles.bold16
                                                      .copyWith(
                                                        color: AppColors
                                                            .kPrimaryColor,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return const SizedBox.shrink();
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  body: IndexedStack(
                    index: cubit.currentIndex,
                    children: _screens,
                  ),
                  bottomNavigationBar: _BottomNavBar(
                    currentIndex: cubit.currentIndex,
                    userId: _userId,
                    localizations: localizations,
                    isGuest: _isGuest,
                    onOrdersTap: () => cubit.changeTab(1),
                    onCategoriesTap: () => cubit.changeTab(0),
                    onGuestRestrictedTap: () {
                      showGuestLoginPrompt(context);
                    },
                    onNotificationsTap: () => showNotificationsDialog(
                      context,
                      _userId,
                      homeCubit: _homeCubit,
                      couponCubit: _couponCubit,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showPhoneNumberBottomSheet(BuildContext context) async {
    final parentContext = context;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PhoneNumberSheet(parentContext: parentContext),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phone-number sheet (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneNumberSheet extends StatefulWidget {
  final BuildContext parentContext;

  const _PhoneNumberSheet({required this.parentContext});

  @override
  State<_PhoneNumberSheet> createState() => _PhoneNumberSheetState();
}

class _PhoneNumberSheetState extends State<_PhoneNumberSheet> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _errorMessage;
  bool _submitted = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _submitted = true;
    });
    widget.parentContext.read<ProfileCubit>().changePhone(
      phone: _phoneController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocListener<ProfileCubit, ProfileState>(
      bloc: widget.parentContext.read<ProfileCubit>(),
      listener: (_, state) {
        if (!_submitted) return;
        if (state is ProfileLoaded) {
          if (mounted) Navigator.pop(context);
        } else if (state is ProfileFailure) {
          if (mounted) {
            setState(() {
              _loading = false;
              _errorMessage = state.message;
            });
          }
        } else if (state is ProfileLoading) {
          if (mounted) setState(() => _loading = true);
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.enterPhoneNumber, style: AppTextStyles.bold18),
            const SizedBox(height: 8),
            Text(
              localizations.weNeedYourPhoneNumber,
              style: AppTextStyles.regular14.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: AppTextFormField(
                label: localizations.phone,
                controller: _phoneController,
                isPhone: true,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 14,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            AppCustomButton(
              onPressed: _loading ? () {} : _submit,
              text: localizations.confirm,
              isLoading: _loading,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom nav bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String userId;
  final AppLocalizations localizations;
  final bool isGuest;
  final VoidCallback onOrdersTap;
  final VoidCallback onCategoriesTap;
  final VoidCallback onNotificationsTap;

  /// Called instead of [onOrdersTap] when the session is a guest, so the
  /// parent can show a login prompt rather than switching tabs.
  final VoidCallback onGuestRestrictedTap;

  const _BottomNavBar({
    required this.currentIndex,
    required this.userId,
    required this.localizations,
    required this.isGuest,
    required this.onOrdersTap,
    required this.onCategoriesTap,
    required this.onNotificationsTap,
    required this.onGuestRestrictedTap,
  });

  @override
  Widget build(BuildContext context) {
    const itemCount = 2;

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final itemWidth = totalWidth / itemCount;

          final textDirection = Directionality.of(context);
          final logicalIndex = textDirection == TextDirection.ltr
              ? currentIndex
              : (itemCount - 1 - currentIndex);

          const indicatorWidth = 65.0;
          final leftPos =
              logicalIndex * itemWidth + (itemWidth - indicatorWidth) / 2;

          return Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned.fill(
                top: 8,
                child: Row(
                  children: [
                    // ── Categories tab ───────────────────────────────────────
                    Expanded(
                      child: InkWell(
                        onTap: onCategoriesTap,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              currentIndex == 0
                                  ? Icons.shopping_bag
                                  : Icons.shopping_bag_outlined,
                              color: currentIndex == 0
                                  ? AppColors.kPrimaryColor
                                  : Colors.grey,
                            ),
                            Text(
                              localizations.shopping,
                              style: TextStyle(
                                height: 2,
                                fontSize: 10,
                                fontWeight: currentIndex == 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: currentIndex == 0
                                    ? AppColors.kPrimaryColor
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Orders tab — login prompt for guests ─────────────────
                    Expanded(
                      child: InkWell(
                        onTap: isGuest ? onGuestRestrictedTap : onOrdersTap,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  currentIndex == 1
                                      ? Icons.receipt
                                      : Icons.receipt_long,
                                  color: isGuest
                                      ? Colors.grey.shade400
                                      : currentIndex == 1
                                      ? AppColors.kPrimaryColor
                                      : Colors.grey,
                                ),
                                // Small lock badge for guests
                                if (isGuest)
                                  Positioned(
                                    right: -6,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade400,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.lock_rounded,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              localizations.orders,
                              style: TextStyle(
                                height: 2,
                                fontSize: 10,
                                fontWeight: (!isGuest && currentIndex == 1)
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isGuest
                                    ? Colors.grey.shade400
                                    : currentIndex == 1
                                    ? AppColors.kPrimaryColor
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: 2,
                left: leftPos,
                child: SvgPicture.asset(
                  'assets/images/navbar/indicator.svg',
                  height: 10,
                  width: indicatorWidth,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile avatar (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? badgeName;

  const _ProfileAvatar({this.imageUrl, this.badgeName});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Hero(
            tag: 'profile-avatar',
            child: ClipOval(
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          SvgPicture.asset(
                            'assets/images/drawer/profile_placholder.svg',
                          ),
                    )
                  : SvgPicture.asset(
                      'assets/images/drawer/profile_placholder.svg',
                    ),
            ),
          ),
        ),
        if (badgeName != null && badgeName!.isNotEmpty)
          Positioned(
            bottom: -20,
            left: 10,
            right: 10,
            child: Text(
              badgeName!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar
// ─────────────────────────────────────────────────────────────────────────────

class AppLayoutAppBar extends StatefulWidget {
  final ValueNotifier<bool> categoriesEmpty;
  final AppLocalizations localizations;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String userId;

  /// When true the notification button and address chip are hidden so that
  /// guest users see a clean browsing experience.
  final bool isGuest;

  const AppLayoutAppBar({
    super.key,
    required this.localizations,
    required this.scaffoldKey,
    required this.userId,
    required this.categoriesEmpty,
    this.isGuest = false,
  });

  @override
  State<AppLayoutAppBar> createState() => _AppLayoutAppBarState();
}

class _AppLayoutAppBarState extends State<AppLayoutAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: Platform.isIOS ? 60 : 70,
      // 60 + 10 padding on Android
      automaticallyImplyLeading: false,
      scrolledUnderElevation: 0,
      elevation: 0,
      actions: const [SizedBox.shrink()],
      title: Directionality(
        textDirection: AppLocalizations.of(context)!.localeName == 'ar'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Menu button — always visible ─────────────────────────────────
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade200,
              child: IconButton(
                icon: const Icon(Icons.menu),
                color: Colors.grey.shade700,
                onPressed: () =>
                    widget.scaffoldKey.currentState?.openEndDrawer(),
              ),
            ),
            const SizedBox(width: 5),

            // ── Notification button — hidden for guests ───────────────────────
            if (!widget.isGuest) ...[
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                child: NotificationButton(userId: widget.userId),
              ),
            ],

            // ── Address chip / coupon ticker — hidden for guests ──────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: widget.categoriesEmpty,
                  builder: (_, isEmpty, __) => isEmpty
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!widget.isGuest) const DefaultAddressChip(),
                          ],
                        )
                      : const CouponTickerTitle(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
