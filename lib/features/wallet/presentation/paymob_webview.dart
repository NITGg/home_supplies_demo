import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:developer';

import '../../../l10n/app_localizations.dart';

class PaymobWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final int amount;
  final int transactionId;

  const PaymobWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.amount,
    required this.transactionId,
  });

  @override
  State<PaymobWebViewScreen> createState() => _PaymobWebViewScreenState();
}

class _PaymobWebViewScreenState extends State<PaymobWebViewScreen> {
  late final WebViewController _controller;
  bool _canPop = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            log("➡️ Page started loading: $url");
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            log("✅ Page finished loading: $url");
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) async {
            log("🔗 Navigation request: ${request.url}");

            // Prevent back navigation during payment
            if (request.url.contains(
              "https://accept.paymob.com/unifiedcheckout/payment-status",
            )) {
              setState(() => _canPop = false);
            }

            // Detect Paymob redirect
            if (request.url.contains("redirection-url") ||
                request.url.contains("post_pay")) {
              final uri = Uri.parse(request.url);
              final success = uri.queryParameters["success"] == "true";

              if (success) {
                // Payment successful
                if (mounted) {
                  context.go(
                    '/wallet/topup/success',
                    extra: {
                      'amount': widget.amount,
                      'transactionId': widget.transactionId,
                    },
                  );
                }
              } else {
                // Payment failed
                if (mounted) {
                  final l10n = AppLocalizations.of(context)!;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.paymentFailed),
                      backgroundColor: Colors.red,
                    ),
                  );
                  setState(() => _canPop = true);
                  Navigator.pop(context);
                }
              }
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            log("❌ WebView error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _showCancelDialog() {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelPayment),
        content: Text(l10n.cancelPaymentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close WebView
            },
            child: Text(
              l10n.yes,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: _canPop,
      onPopInvoked: (didPop) {
        if (!didPop && !_canPop) {
          _showCancelDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.payment,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: BackButton(
            color: Colors.black,
            onPressed: () {
              if (_canPop) {
                Navigator.pop(context);
              } else {
                _showCancelDialog();
              }
            },
          ),
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}