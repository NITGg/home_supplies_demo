import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tawreedat_go/core/error/restart_widget.dart';

class ErrorTestPage extends StatelessWidget {
  const ErrorTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error Handler Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Test Error Handling',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // Test 1: Synchronous Exception
              ElevatedButton.icon(
                onPressed: () {
                  throw Exception('Test synchronous exception!');
                },
                icon: const Icon(Icons.warning),
                label: const Text('Throw Exception'),
              ),

              const SizedBox(height: 16),

              // Test 2: Widget Build Error
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const _ErrorWidget(),
                    ),
                  );
                },
                icon: const Icon(Icons.build_circle),
                label: const Text('Trigger Build Error'),
              ),

              const SizedBox(height: 16),

              // Test 3: Async Error
              ElevatedButton.icon(
                onPressed: () async {
                  await Future.delayed(const Duration(seconds: 1));
                  throw Exception('Async error after 1 second!');
                },
                icon: const Icon(Icons.timer),
                label: const Text('Throw Async Error'),
              ),

              const SizedBox(height: 16),

              // Test 4: Null Pointer Error
              ElevatedButton.icon(
                onPressed: () {
                  String? nullString;
                  if (kDebugMode) {
                    print(nullString!.length);
                  } // Will throw
                },
                icon: const Icon(Icons.error_outline),
                label: const Text('Null Pointer Error'),
              ),

              const SizedBox(height: 16),

              // Test 5: Division by Zero
              ElevatedButton.icon(
                onPressed: () {
                  int result = 10 ~/ 0; // Will throw
                  if (kDebugMode) {
                    print(result);
                  }
                },
                icon: const Icon(Icons.calculate),
                label: const Text('Division by Zero'),
              ),

              const SizedBox(height: 32),

              // Manual Restart
              OutlinedButton.icon(
                onPressed: () {
                  RestartWidget.restartApp();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Manual Restart'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget that throws error during build
class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error Widget')),
      body: Builder(
        builder: (context) {
          throw Exception('Widget build error!');
        },
      ),
    );
  }
}
