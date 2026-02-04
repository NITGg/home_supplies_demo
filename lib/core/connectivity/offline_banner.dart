import 'package:flutter/material.dart';
import 'connectivity_manager.dart';

class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({Key? key, required this.child}) : super(key: key);

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isConnected = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _isConnected = ConnectivityManager.instance.isConnected;
    ConnectivityManager.instance.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    ConnectivityManager.instance.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged(bool isConnected) {
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
        _showBanner = !isConnected;
      });

      // Auto-hide banner after 3 seconds when reconnected
      if (isConnected) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _isConnected) {
            setState(() {
              _showBanner = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (_showBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: _isConnected ? Colors.green : Colors.red,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isConnected ? Icons.wifi : Icons.wifi_off,
                        color: Colors.white,
                        size: 20,
                      ),
                      // const SizedBox(width: 8),
                      // Text(
                      //   _isConnected
                      //       ? 'متصل بالإنترنت'
                      //       : 'لا يوجد اتصال بالإنترنت',
                      //   style: const TextStyle(
                      //     color: Colors.white,
                      //     fontWeight: FontWeight.w600,
                      //     fontSize: 14,
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
