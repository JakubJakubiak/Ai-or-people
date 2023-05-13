import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static String get bannerAdUnitId {
    if (kDebugMode)
      return 'ca-app-pub-3940256099942544/2934735716'; // test ad ID
    if (Platform.isAndroid) {
      return 'ca-app-pub-5915784054696948/6625475644';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-5915784054696948/9426559499';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

// ca-app-pub-5915784054696948/9198262159

  //   if (Platform.isAndroid) {
  //     return 'ca-app-pub-5915784054696948/9198262159';
  //   } else {
  //     throw UnsupportedError("Unsupported platform");
  //   }
  // }
  //   return null;
  // }
//

// Baner
// ca-app-pub-5915784054696948/1356221148

//test gogoel apk
  // ca-app-pub-3940256099942544/8691691433

// fullscriin
//  'ca-app-pub-5915784054696948/9198262159';

//full video scrien
// 'ca-app-pub-5915784054696948/7783395671';

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-5915784054696948/7684396126';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get rewardedAdUnitID {
    if (kDebugMode) return 'ca-app-pub-3940256099942544/1712485313';
    if (Platform.isAndroid) {
      return 'ca-app-pub-5915784054696948/7684396126';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-5915784054696948/6894892781';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static final BannerAdListener bannerAdListener = BannerAdListener(
    onAdLoaded: (ad) => debugPrint('Ad loaded'),
    onAdFailedToLoad: (ad, error) {
      ad.dispose();
      debugPrint('Ad failed to load: $error');
    },
    onAdOpened: (ad) => debugPrint('Ad opened'),
    onAdClosed: (ad) => debugPrint('Ad closed'),
  );
}
