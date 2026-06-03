import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/utils/logger.dart';
import '../../../core/widgets/banners.dart';
import '../../../core/widgets/circel_back_button.dart';
import '../../../l10n/app_localizations.dart';

class PaymobWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final int amount;
  final int transactionId;
  final String provider;

  /// Called after a successful payment instead of the default
  /// `/wallet/topup/success` navigation. Supply this when using the WebView
  /// for non-wallet flows (e.g. order payment).
  final VoidCallback? onPaymentSuccess;

  /// Called after a failed payment instead of the default banner + pop.
  final VoidCallback? onPaymentFailed;

  const PaymobWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.amount,
    required this.transactionId,
    this.provider = 'paymob',
    this.onPaymentSuccess,
    this.onPaymentFailed,
  });

  @override
  State<PaymobWebViewScreen> createState() => _PaymobWebViewScreenState();
}

class _PaymobWebViewScreenState extends State<PaymobWebViewScreen> {
  late final WebViewController _controller;
  bool _canPop = true;
  bool _isLoading = true;
  // True once the user has navigated away from the initial payment page
  // (i.e. they submitted their card data). Only after this point do we lock
  // the back button, because before submission there is nothing to lose.
  bool _paymentSubmitted = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            dLog("➡️ Page started loading: $url");
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            dLog("✅ Page finished loading: $url");
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) async {
            dLog("🔗 Navigation request: ${request.url}");

            // Detect Paymob redirect — intercepted before any domain check
            // because the callback URL is outside our allowed domains but
            // must be handled here, not navigated to.
            if (request.url.contains("redirection-url") ||
                request.url.contains("post_pay")) {
              final uri = Uri.parse(request.url);
              final success = uri.queryParameters["success"] == "true";
              _handlePaymentResult(success: success);
              return NavigationDecision.prevent;
            }

            // Detect Kashier redirect — Kashier appends paymentStatus to the
            // merchant callback URL which is outside the kashier.io domain.
            if (widget.provider == 'kashier' &&
                request.url.contains('paymentStatus')) {
              final uri = Uri.parse(request.url);
              final status = uri.queryParameters['paymentStatus']?.toUpperCase();
              _handlePaymentResult(success: status == 'SUCCESS');
              return NavigationDecision.prevent;
            }

            // Once the user navigates away from the initial page (form
            // submission, 3DS redirect, etc.) lock the back button so they
            // cannot accidentally abort mid-transaction.
            if (!_paymentSubmitted &&
                request.url != widget.paymentUrl &&
                request.isMainFrame) {
              setState(() {
                _paymentSubmitted = true;
                _canPop = false;
              });
            }

            // Allow all navigation: payment flows legitimately visit bank
            // domains (3DS / Mastercard SecureCode / Visa OTP pages) that
            // cannot be enumerated in a static allowlist.
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            dLog("❌ WebView error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _handlePaymentResult({required bool success}) {
    if (!mounted) return;
    if (success) {
      if (widget.onPaymentSuccess != null) {
        widget.onPaymentSuccess!();
      } else {
        context.go(
          '/wallet/topup/success',
          extra: {
            'amount': widget.amount,
            'transactionId': widget.transactionId,
          },
        );
      }
    } else {
      setState(() => _canPop = true);
      if (widget.onPaymentFailed != null) {
        widget.onPaymentFailed!();
      } else {
        final l10n = AppLocalizations.of(context)!;
        showErrorBanner(context, l10n.paymentFailed);
        Navigator.pop(context);
      }
    }
  }

@override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: _canPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.payment,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: _canPop
              ? CircleBackButton(onPressed: () => Navigator.pop(context))
              : const SizedBox.shrink(),
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}