import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:humanai/features/game_screen/game_screen.dart';
import 'package:humanai/features/game_screen/streak_service.dart';
import 'package:humanai/features/shop/store_service.dart';
import 'package:humanai/features/shop/wallet.dart';
import 'package:humanai/utils/app_colors.dart';
import 'package:humanai/utils/shared_preferences_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  await Firebase.initializeApp();

  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  await FirebaseAnalytics.instance.setConsent(
      adStorageConsentGranted: true,
      adUserDataConsentGranted: true,
      adPersonalizationSignalsConsentGranted: true,
    );

  await SharedPreferencesHelper.initialize();
  await StreakService.init();
  await Wallet.init();
  unawaited(StoreService.instance.init());
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((value) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Human vs Ai',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.ai, brightness: Brightness.dark, surface: AppColors.surface),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const GameScreen(),
    );
  }
}
