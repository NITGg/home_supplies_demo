import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tawreedat_go/core/utils/app_dynamic_settings.dart';
import 'package:tawreedat_go/core/widgets/loading_screen.dart';

import '../../core/style/app_colors.dart';
import '../../core/style/text_styles.dart';
import '../../core/utils/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../auth/manager/profile_cubit.dart';
import '../auth/manager/profile_states.dart';
import '../../core/widgets/banners.dart';

class ReferralQrScreen extends StatefulWidget {
  const ReferralQrScreen({super.key});

  @override
  State<ReferralQrScreen> createState() => _ReferralQrScreenState();
}

class _ReferralQrScreenState extends State<ReferralQrScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _copiedIos = false;
  bool _copiedAndroid = false;

  Map<String, dynamic>? _stats;
  bool _statsLoading = false;
  String? _statsError;

  String _buildAndroidUrl(String referralCode) {
    final encoded = Uri.encodeComponent('ref_code=$referralCode');
    return '${AppSettings.android_url}&referrer=$encoded';
  }

  String _buildIosUrl(String referralCode) {
    final encoded = Uri.encodeComponent('ref_code=$referralCode');
    return '${AppSettings.ios_url}?referral=$encoded';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchStats());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    final profileState = context.read<ProfileCubit>().state;
    if (profileState is! ProfileLoaded) return;

    final userId = profileState.profile.id;
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });

    try {
      final response = await ApiClient.instance.dio.get(
        '/admin/manage-seller/get-seller-stat/$userId',
      );

      setState(() {
        _stats = response.data['data']['stats'] as Map<String, dynamic>;
        _statsLoading = false;
      });
    } on DioException catch (e) {
      log('ReferralQrScreen: stats error: $e');
      setState(() {
        _statsError = e.message ?? 'Something went wrong';
        _statsLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard(String url, bool isIos) async {
    await Clipboard.setData(ClipboardData(text: url));
    showInfoBanner(context, AppLocalizations.of(context)!.copiedToClipboard);
    setState(() {
      if (isIos)
        _copiedIos = true;
      else
        _copiedAndroid = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        if (isIos)
          _copiedIos = false;
        else
          _copiedAndroid = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        if (profileState is! ProfileLoaded) {
          return const Scaffold(
            body: Center(child: LoadingScreen(asWidget: true, isOne: true)),
          );
        }

        final referralCode = profileState.profile.referralCode ?? '';
        final androidUrl = _buildAndroidUrl(referralCode);
        final iosUrl = _buildIosUrl(referralCode);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F7),
          appBar: AppBar(
            title: Text(
              localizations.referral,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.kPrimaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.kPrimaryColor,
              indicatorWeight: 2.5,
              labelStyle: AppTextStyles.bold16.copyWith(fontSize: 13),
              unselectedLabelStyle: AppTextStyles.regular14.copyWith(
                fontSize: 13,
              ),
              tabs: [
                Tab(
                  icon: const Icon(Icons.bar_chart_rounded, size: 20),
                  text: localizations.statistics,
                ),
                const Tab(icon: Icon(Icons.android, size: 20), text: 'Android'),
                const Tab(icon: Icon(Icons.apple, size: 20), text: 'iOS'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _StatsTab(
                stats: _stats,
                loading: _statsLoading,
                error: _statsError,
                onRetry: _fetchStats,
              ),
              _QrTab(
                url: androidUrl,
                copied: _copiedAndroid,
                platform: 'Android',
                platformColor: const Color(0xFF3DDC84),
                onCopy: () => _copyToClipboard(androidUrl, false),
              ),
              _QrTab(
                url: iosUrl,
                copied: _copiedIos,
                platform: 'iOS',
                platformColor: Colors.black,
                onCopy: () => _copyToClipboard(iosUrl, true),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── QR Tab ────────────────────────────────────────────────────────────────────

class _QrTab extends StatefulWidget {
  final String url;
  final bool copied;
  final String platform;
  final Color platformColor;
  final VoidCallback onCopy;

  const _QrTab({
    required this.url,
    required this.copied,
    required this.platform,
    required this.platformColor,
    required this.onCopy,
  });

  @override
  State<_QrTab> createState() => _QrTabState();
}

class _QrTabState extends State<_QrTab> {
  final GlobalKey _qrKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareToWhatsApp() async {
    setState(() => _sharing = true);
    try {
      final boundary =
      _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/qr_${widget.platform.toLowerCase()}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: widget.url,
        sharePositionOrigin: Rect.zero,
      );
    } catch (e) {
      debugPrint('QR share error: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.platformColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      Icon(
                        widget.platform == 'iOS' ? Icons.apple : Icons.android,
                        size: 16,
                        color: widget.platformColor,
                      ),
                      Text(
                        widget.platform,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.platformColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: widget.onCopy,
                  child: RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      color: Colors.white,
                      child: QrImageView(
                        data: widget.url,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: OutlinedButton.icon(
                          key: ValueKey(widget.copied),
                          onPressed: widget.onCopy,
                          icon: Icon(
                            widget.copied
                                ? Icons.check_rounded
                                : Icons.copy_rounded,
                            size: 16,
                          ),
                          label: Text(
                            widget.copied
                                ? AppLocalizations.of(context)!.copiedToClipboard
                                : AppLocalizations.of(context)!.copy,
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.kPrimaryColor,
                            side: BorderSide(color: AppColors.kPrimaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sharing ? null : _shareToWhatsApp,
                        icon: _sharing
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.share, size: 16),
                        label: Text(
                          _sharing ? '...' : AppLocalizations.of(context)!.whatsapp,
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;

  const _StatsTab({
    required this.stats,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: LoadingScreen(asWidget: true, isOne: true));
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            Text(
              error!,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      );
    }

    if (stats == null) {
      return const Center(child: LoadingScreen(asWidget: true, isOne: true));
    }

    // ✅ Referrals hero card
    final referralsItem = _StatItem(
      label: AppLocalizations.of(context)!.referrals,
      value: stats!['numberOfReferralsBySeller'] ?? 0,
      icon: Icons.people_alt_rounded,
      color: AppColors.kSecondaryColor,
    );

    final items = [
      _StatItem(
        label: AppLocalizations.of(context)!.orders,
        value: stats!['total_orders'],
        icon: Icons.receipt_long_rounded,
        color: AppColors.kSecondaryColor,
      ),
      _StatItem(
        label: AppLocalizations.of(context)!.pending,
        value: stats!['total_pending_orders'],
        icon: Icons.hourglass_empty_rounded,
        color: const Color(0xFFFF9500),
      ),
      _StatItem(
        label: AppLocalizations.of(context)!.inProgress,
        value: stats!['total_in_progress_orders'],
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF5856D6),
      ),
      _StatItem(
        label: AppLocalizations.of(context)!.delivered,
        value: stats!['total_delivered_orders'],
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF34C759),
      ),
      _StatItem(
        label: AppLocalizations.of(context)!.cancelled,
        value: stats!['total_cancelled_orders'],
        icon: Icons.cancel_rounded,
        color: const Color(0xFFFF3B30),
      ),
    ];

    return RefreshIndicator(
      onRefresh: onRetry,
      color: AppColors.kPrimaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // ✅ Referrals at the top
            _HeroStatCard(item: referralsItem),
            const SizedBox(height: 12),
            // Total orders below
            _HeroStatCard(item: items[0]),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children:
              items.skip(1).map((item) => _StatCard(item: item)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _HeroStatCard extends StatelessWidget {
  final _StatItem item;

  const _HeroStatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: item.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: item.color.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.value}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.value}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: item.color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}