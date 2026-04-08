import 'package:flutter/material.dart';
class EgyptianPlate extends StatelessWidget {
  final String plateNumber;

  const EgyptianPlate({super.key, required this.plateNumber});

  (String letters, String numbers) _splitPlate(String plate) {
    final parts = plate.trim().split(RegExp(r'\s+'));
    final letterParts = <String>[];
    final numberParts = <String>[];
    for (final p in parts) {
      if (RegExp(r'^[0-9٠-٩]+$').hasMatch(p)) {
        numberParts.add(p);
      } else {
        letterParts.add(p);
      }
    }
    return (letterParts.join(' '), numberParts.join(' '));
  }

  @override
  Widget build(BuildContext context) {
    final (letters, numbers) = _splitPlate(plateNumber);

    return IntrinsicWidth(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black87, width: 1),
          ),
          child: Column(
            children: [
              // ── Blue top band ──
              Container(
                height: 10,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF21ABF5),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'EGYPT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(width: 0.5, color: Colors.white54, height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'مصر',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 5.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── White body ──
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        numbers,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Container(width: 0.5, color: Colors.black38),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        letters,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}