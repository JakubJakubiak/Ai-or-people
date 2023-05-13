import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:games_services/games_services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:humanai/ai_Image/humanimahge.dart';
import 'package:humanai/ai_Image/linkImage.dart';
import 'package:humanai/modules/ad_bob_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  await Firebase.initializeApp();
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
      checkerboardRasterCacheImages: false,
      title: 'Human vs Ai',
      theme: ThemeData(
        brightness: Brightness.dark,
      ),
      home: const MyHomePage(title: 'Human vs Ai'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  bool answer = false;

  // InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  int _counter = 0;
  int currentIndex = 0;
  BannerAd? _banner;
  int life = 3;

  List<Map<String, dynamic>> categoryDraw = [];
  Animation<double>? animation;
  dynamic sizeW;
  dynamic sizeH;

  late Timer timer;
  double posValue = 1000.0;
  double posValueHeight = 1000.0;

  PageController _pageController = PageController();

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  void initState() {
    super.initState();
    GamesServices.signIn();
    // stateManager.makeGetRequest();
    _createBanerAd();

    //google ads
    // _createBanerAd();
    // _createInterstitialAd();
    // _createRewardedAd();
  }
//  final stateManager = HomePageManager();

  void loadImages() async {
    if (categoryDraw.isEmpty) {
      await Future.forEach(imageListLink, (link) async {
        categoryDraw.add({'link': link, 'category': 'ai'});
      });
      await Future.forEach(humanImage, (link) async {
        categoryDraw.add({'link': link, 'category': 'human'});
      });

      setState(() {
        categoryDraw.shuffle();
      });
    }
  }

  void trueOdFalse(context, {required String categoryWin}) async {
    if (categoryWin == categoryDraw[currentIndex]['category'] &&
        answer == false) {
      _incrementCounter();
    } else {
      _dekrementation();
    }

    timesAnimationAwait() async {
      await _pageController.animateToPage(_pageController.page!.toInt() + 1,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }

    (answer == false)
        ? timer = Timer(const Duration(milliseconds: 600), () {
            timesAnimationAwait();
            setState(() {
              answer = false;
            });
          })
        : null;

    setState(() {
      answer = !answer;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _createBanerAd() async {
    _banner = BannerAd(
      size: AdSize.fullBanner,
      adUnitId: AdMobService.bannerAdUnitId,
      listener: AdMobService.bannerAdListener,
      request: const AdRequest(),
    )..load();
  }

  //   void _createInterstitialAd() {
  //   InterstitialAd.load(
  //     adUnitId: AdMobService.interstitialAdUnitId!,
  //     request: const AdRequest(),
  //     adLoadCallback: InterstitialAdLoadCallback(
  //       onAdLoaded: (ad) => _interstitialAd = ad,
  //       onAdFailedToLoad: (LoadAdError error) => _interstitialAd = null,
  //     ),
  //   );
  // }

  void _dekrementation() {
    setState(() {
      life--;
      // if (life <= -1) EndeScrine();
    });
  }

  void EndeScrine() async {
    await _submitScore(_counter);
    _showLeaderboards();
    reset();
  }

  Future<bool> isSignedIn() async {
    return await GameAuth.isSignedIn;
  }

  Future<void> _submitScore(int counter) async {
    try {
      if (!await isSignedIn()) return;
      await Leaderboards.submitScore(
          score: Score(
              androidLeaderboardID: 'CgkIsM2JmbsEEAIQAA',
              iOSLeaderboardID: 'ios_leaderboard_id',
              value: counter));
      print("login _submitScore ");
    } catch (e) {
      print(e);
    }
  }

  void reset() {
    setState(() {
      life = 3;
      _counter = 0;
    });
  }

  void _signIn() async {
    final result = await GameAuth.signIn(shouldEnableSavedGame: true);
    print(result);
  }

  void _showLeaderboards() async {
    if (!await isSignedIn()) return;
    final result = await Leaderboards.showLeaderboards(
        androidLeaderboardID: 'CgkIsM2JmbsEEAIQAA');
    print(result);
  }

  void advertisement() async {
    await _loadIntersitialAd();
    EndeScrine();
  }

  Future<void> _loadIntersitialAd() async {
    await InterstitialAd.load(
      adUnitId: AdMobService.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.show();
        },
        onAdFailedToLoad: (error) {
          // log('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    loadImages();

    var images = categoryDraw[currentIndex]['link'] as String;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Text(widget.title),
            Icon(
              life >= 1 ? Icons.favorite : Icons.favorite_border,
              color: Colors.pink,
              size: 36.0,
            ),
            Icon(
              life >= 2 ? Icons.favorite : Icons.favorite_border,
              color: Colors.pink,
              size: 36.0,
            ),
            Icon(
              life >= 3 ? Icons.favorite : Icons.favorite_border,
              color: Colors.pink,
              size: 36.0,
            ),
            FloatingActionButton.extended(
                onPressed: () async => {
                      HapticFeedback.mediumImpact(),
                      _showLeaderboards(),
                    },
                backgroundColor: ui.Color(0xFF5B4792),
                label: const Icon(
                  Icons.table_rows,
                  color: ui.Color.fromRGBO(255, 255, 255, 1),
                  size: 30.0,
                )),
          ],
        ),
      ),
      body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
            if (life <= 0)
              Column(children: [
                const Text(
                  'chesz otrymac 3 serducha',
                  maxLines: 2,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: advertisement,
                      child: const Text('Yes'),
                    ),
                    ElevatedButton(
                      onPressed: EndeScrine,
                      child: const Text('No'),
                    ),
                  ],
                ),
              ])
            else
              const SizedBox.shrink(),
            const Padding(
              padding: EdgeInsets.only(left: 30, right: 30),
              child: Text(
                'Guess which image was made by human and which by ai?',
                maxLines: 5,
              ),
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(
              height: MediaQuery.of(context).size.width,
              child: Stack(
                children: [
                  SizedBox.fromSize(
                    child: PageView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categoryDraw.length,
                      controller: _pageController,
                      itemBuilder: (context, index) {
                        currentIndex = index;
                        images = categoryDraw[index]['link'] as String;

                        return Padding(
                            padding: const EdgeInsets.all(10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CachedNetworkImage(
                                imageUrl: images,
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                              ),
                            ));
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: <Widget>[
                  Expanded(
                      flex: 2,
                      child: FloatingActionButton.extended(
                        onPressed: () async => {
                          HapticFeedback.mediumImpact(),
                          (life <= 0)
                              ? null
                              : trueOdFalse(context, categoryWin: 'ai'),
                        },
                        backgroundColor: answer == true
                            ? categoryDraw[currentIndex]['category'] == 'ai'
                                ? const Color.fromARGB(255, 41, 95, 43)
                                : const Color.fromARGB(255, 129, 42, 42)
                            : const Color(0xff6750a4),
                        label: Text('AI',
                            maxLines: 10,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 30,
                              color: Colors.grey[300],
                            )),
                      )),
                  const Padding(padding: EdgeInsets.all(5)),
                  Expanded(
                      flex: 2,
                      child: FloatingActionButton.extended(
                        onPressed: () async => {
                          HapticFeedback.mediumImpact(),
                          (life <= 0)
                              ? null
                              : trueOdFalse(context, categoryWin: 'human'),
                        },
                        backgroundColor: answer == true
                            ? categoryDraw[currentIndex]['category'] == 'human'
                                ? const Color.fromARGB(255, 41, 95, 43)
                                : const Color.fromARGB(255, 129, 42, 42)
                            : const Color(0xff6750a4),
                        label: Text('Human',
                            maxLines: 10,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 30,
                              color: Colors.grey[300],
                            )),
                      )),
                ])),
            const Padding(padding: EdgeInsets.all(5)),
            (_banner == null)
                ? Container(
                    height: 0,
                  )
                : SizedBox(
                    height: 50,
                    width: 320,
                    child: AdWidget(ad: _banner!),
                  ),
          ])),
    );
  }
}
