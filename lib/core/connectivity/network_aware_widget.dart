import 'package:flutter/material.dart';

import 'connectivity_manager.dart';

class NetworkAwareWidget extends StatefulWidget {
  final Widget child;
  final Widget? offlineWidget;
  final Function()? onConnected;
  final Function()? onDisconnected;

  const NetworkAwareWidget({
    Key? key,
    required this.child,
    this.offlineWidget,
    this.onConnected,
    this.onDisconnected,
  }) : super(key: key);

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  bool _isConnected = true;

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
      });

      if (isConnected) {
        widget.onConnected?.call();
      } else {
        widget.onDisconnected?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected && widget.offlineWidget != null) {
      return widget.offlineWidget!;
    }
    return widget.child;
  }
}
