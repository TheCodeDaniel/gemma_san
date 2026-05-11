import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/avatar_picker_screen.dart';
import 'features/onboarding/onboarding_prefs.dart';
import 'features/onboarding/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  runApp(const ProviderScope(child: GemmaSanApp()));
}

class GemmaSanApp extends StatelessWidget {
  const GemmaSanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma-San',
      theme: buildAppTheme(),
      home: const _AppRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OnboardingPrefs.hasOnboarded,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(backgroundColor: Color(0xFFF5ECD7), body: SizedBox.shrink());
        }
        return snapshot.data! ? const AvatarPickerScreen() : const WelcomeScreen();
      },
    );
  }
}
