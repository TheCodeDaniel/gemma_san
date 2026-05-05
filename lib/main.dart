import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/diagnostic/diagnostic_screen.dart';

void main() {
  runApp(const ProviderScope(child: GemmaSanApp()));
}

class GemmaSanApp extends StatelessWidget {
  const GemmaSanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma-San',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4332)),
        useMaterial3: true,
      ),
      // Temporary: replaced by onboarding on Day 13.
      home: const DiagnosticScreen(),
    );
  }
}
