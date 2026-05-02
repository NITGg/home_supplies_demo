import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/circel_back_button.dart';
import '../../l10n/app_localizations.dart';
import '../static_text/app_dynamic_info.dart';

class KnowUsMoreScreen extends StatelessWidget {
  const KnowUsMoreScreen({super.key});

  /// Returns true only when [raw] is a non-empty, well-formed http/https URL.
  bool _isValidUrl(String raw) {
    if (raw
        .trim()
        .isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> _launch(BuildContext context, String url) async {
    final uri = Uri.parse(url.trim());
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = AppInfoManager().data;

    /// Each entry: (label, asset path, raw url from model)
    final List<_SocialEntry> allEntries = info == null
        ? []
        : [
      _SocialEntry(
        label: 'Facebook',
        assetPath: 'assets/social_logos/facebook.svg',
        url: info.facebook,
      ),
      _SocialEntry(
        label: 'Instagram',
        assetPath: 'assets/social_logos/instagram.svg',
        url: info.instagram,
      ),
      _SocialEntry(
        label: 'LinkedIn',
        assetPath: 'assets/social_logos/linkedin.svg',
        url: info.linkedin,
      ),

      _SocialEntry(
        label: 'Twitter / X',
        assetPath: 'assets/social_logos/twitter.svg',
        url: info.twitter,
      ),
      _SocialEntry(
        label: 'YouTube',
        assetPath: 'assets/social_logos/youtube.svg',
        url: info.youtube,
      ),
      _SocialEntry(
        label: 'TikTok',
        assetPath: 'assets/social_logos/tiktok.svg',
        url: info.tiktok,
      ),
    ];

    // Filter out entries whose URL is not a valid, parsable http/https link.
    final validEntries = allEntries.where((e) => _isValidUrl(e.url)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.knowUsMore),
          leading: CircleBackButton(),
          ),
      body: info == null
          ? const Center(child: Text('No information available.'))
          : validEntries.isEmpty
          ? const Center(child: Text('No social links available.'))
          : ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: validEntries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = validEntries[index];
          return _SocialButton(
            entry: entry,
            onTap: () => _launch(context, entry.url),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class _SocialEntry {
  final String label;
  final String assetPath;
  final String url;

  const _SocialEntry({
    required this.label,
    required this.assetPath,
    required this.url,
  });
}

// ---------------------------------------------------------------------------
// Button widget
// ---------------------------------------------------------------------------

class _SocialButton extends StatelessWidget {
  final _SocialEntry entry;
  final VoidCallback onTap;

  const _SocialButton({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    final textTheme = Theme
        .of(context)
        .textTheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              SvgPicture.asset(
                entry.assetPath,
                width: 28,
                height: 28,
                // Tint falls back gracefully if the SVG has no fill.
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurfaceVariant,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  entry.label,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
