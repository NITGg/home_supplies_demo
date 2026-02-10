import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../data/models/qr_model.dart';
import '../manager/order_cubit.dart';
import '../manager/order_states.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Parse QR code data
      final qrData = jsonDecode(code);
      final deliveryQR = DeliveryQRCode.fromJson(qrData);

      if (!deliveryQR.isConfirmDelivery) {
        _showError('Invalid QR Code: Not a delivery confirmation code');
        setState(() => _isProcessing = false);
        return;
      }

      // Confirm delivery
      if (mounted) {
        await context.read<OrderCubit>().confirmDelivery(
          orderId: deliveryQR.orderId,
          courierId: deliveryQR.courierId,
        );
      }
    } catch (e) {
      _showError('Invalid QR Code format');
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code', style: AppTextStyles.bold18),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: BlocListener<OrderCubit, OrderState>(
        listener: (context, state) {
          if (state is DeliveryConfirmed) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Delivery confirmed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is OrderError) {
            _showError(state.message);
            setState(() => _isProcessing = false);
          }
        },
        child: Stack(
          children: [
            MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
            ),
            // Overlay with scanning frame
            CustomPaint(
              painter: ScannerOverlayPainter(),
              child: Container(),
            ),
            // Instructions
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    if (_isProcessing)
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    else
                      Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 48,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _isProcessing
                          ? 'Processing...'
                          : 'Align QR code within the frame',
                      style: AppTextStyles.bold16.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan the delivery confirmation QR code from the courier',
                      style: AppTextStyles.regular14.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = size.width * 0.7;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;

    // Draw darkened overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanAreaRect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // Draw overlay with hole
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanAreaRect, const Radius.circular(20))),
      ),
      overlayPaint,
    );

    // Draw corner brackets
    final cornerPaint = Paint()
      ..color = AppColors.kPrimaryColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLength = 30.0;
    final corners = [
      // Top-left
      [
        Offset(left, top + cornerLength),
        Offset(left, top),
        Offset(left + cornerLength, top),
      ],
      // Top-right
      [
        Offset(left + scanAreaSize - cornerLength, top),
        Offset(left + scanAreaSize, top),
        Offset(left + scanAreaSize, top + cornerLength),
      ],
      // Bottom-right
      [
        Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
        Offset(left + scanAreaSize, top + scanAreaSize),
        Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
      ],
      // Bottom-left
      [
        Offset(left + cornerLength, top + scanAreaSize),
        Offset(left, top + scanAreaSize),
        Offset(left, top + scanAreaSize - cornerLength),
      ],
    ];

    for (var corner in corners) {
      final path = Path()
        ..moveTo(corner[0].dx, corner[0].dy)
        ..lineTo(corner[1].dx, corner[1].dy)
        ..lineTo(corner[2].dx, corner[2].dy);
      canvas.drawPath(path, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}