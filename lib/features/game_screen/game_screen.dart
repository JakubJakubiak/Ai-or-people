import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:games_services/games_services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:humanai/ai_Image/humanimahge.dart';
import 'package:humanai/ai_Image/linkImage.dart';
import 'package:humanai/features/game_screen/widgets/game_over_dialog.dart';
import 'package:humanai/modules/admob_service.dart';
import 'package:humanai/utils/shared_preferences_helper.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  bool answer = false;

  int score = 0;
  int currentIndex = 0;
  BannerAd? _banner;
  int life = 1;

  List<Map<String, dynamic>> gameImages = [];
  Animation<double>? animation;
  dynamic sizeW;
  dynamic sizeH;

  late Timer timer;

  final _pageController = PageController();

  void _incrementScore() {
    setState(() {
      score++;
    });
  }

  @override
  void initState() {
    super.initState();
    loadImages();
    GamesServices.signIn();
    _createBanerAd();
  }

  Future<void> loadImages() async {
    if (gameImages.isEmpty) {
      await Future.forEach(imageListLink, (link) async {
        gameImages.add({'link': link, 'category': 'ai'});
      });
      await Future.forEach(humanImage, (link) async {
        gameImages.add({'link': link, 'category': 'human'});
      });

      gameImages.shuffle();
      setState(() {});
    }
  }

  Future<void> processResponse({required String categoryWin}) async {
    if (categoryWin == gameImages[currentIndex]['category'] &&
        answer == false) {
      _incrementScore();
    } else {
      _loseHealth();
    }

    Future<void> showNextImage() async {
      await _pageController.animateToPage(
        _pageController.page!.toInt() + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }

    if (!answer) {
      timer = Timer(const Duration(milliseconds: 600), () {
        showNextImage();
        setState(() {
          answer = false;
        });
      });
    }

    setState(() {
      answer = !answer;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _createBanerAd() {
    _banner = BannerAd(
      size: AdSize.fullBanner,
      adUnitId: AdMobService.bannerAdUnitId,
      listener: AdMobService.bannerAdListener,
      request: const AdRequest(),
    )..load();
  }

  void _loseHealth() {
    setState(() {
      life--;
    });
    if (life <= 0) {
      endGame();
    }
  }

  void endGame() {
    _submitScore(score);
    final bestScore = SharedPreferencesHelper.getBestScore();
    if (score > bestScore) SharedPreferencesHelper.setBestScore(score);
    showGameOverDialog();
  }

  Future<Widget?> showGameOverDialog() {
    return showDialog<Widget>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GameOverDialog(
        score: score,
        onPlayAgain: reset,
        onContinuePlaying: _loadRewardedAd,
      ),
    );
  }

  Future<bool> isSignedIn() async {
    return GameAuth.isSignedIn;
  }

  Future<void> _submitScore(int counter) async {
    try {
      if (!await isSignedIn()) return;
      await Leaderboards.submitScore(
        score: Score(
          androidLeaderboardID: 'CgkIsM2JmbsEEAIQAA',
          iOSLeaderboardID: 'ios_leaderboard_id',
          value: counter,
        ),
      );
      print("login _submitScore ");
    } catch (e) {
      print(e);
    }
  }

  void addFullHealth() {
    setState(() {
      life = 3;
    });
  }

  void reset() {
    setState(() {
      life = 3;
      score = 0;
    });
  }

  Future<void> _showLeaderboards() async {
    if (!await isSignedIn()) return;
    final result = await Leaderboards.showLeaderboards(
      androidLeaderboardID: 'CgkIsM2JmbsEEAIQAA',
    );
    print(result);
  }

  Future<void> advertisement() async {
    await _loadIntersitialAd();
    reset();
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

  // load rewarded ad
  Future<void> _loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: AdMobService.rewardedAdUnitID,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.show(
            onUserEarnedReward: (ad, reward) {
              addFullHealth();
            },
          );
        },
        onAdFailedToLoad: (error) {
          addFullHealth();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var images = gameImages[currentIndex]['link'] as String;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            const Spacer(),
            Icon(
              life >= 1 ? Icons.favorite : Icons.favorite_border,
              color: Colors.pink,
              size: 36.0,
            ),
            const SizedBox(width: 4),
            Icon(
              life >= 2 ? Icons.favorite : Icons.favorite_border,
              color: Colors.pink,
              size: 36.0,
            ),
            const SizedBox(width: 4),
            Icon(
              life >= 3 ? Icons.favorite : Icons.favorite_border,
              color: Colors.pink,
              size: 36.0,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _showLeaderboards();
            },
            icon: const Icon(Icons.leaderboard),
          ),
          const SizedBox(width: 8)
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(left: 30, right: 30),
                child: Text(
                  'Human-made or AI-generated?',
                  maxLines: 5,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$score',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: MediaQuery.of(context).size.width,
                child: Stack(
                  children: [
                    SizedBox.fromSize(
                      child: PageView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: gameImages.length,
                        controller: _pageController,
                        itemBuilder: (context, index) {
                          currentIndex = index;
                          images = gameImages[index]['link'] as String;

                          return Padding(
                            padding: const EdgeInsets.all(10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CachedNetworkImage(
                                imageUrl: images,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            if (life > 0) processResponse(categoryWin: 'ai');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: answer == true
                                ? gameImages[currentIndex]['category'] == 'ai'
                                    ? const Color.fromARGB(255, 41, 95, 43)
                                    : const Color.fromARGB(255, 129, 42, 42)
                                : const Color(0xff6750a4),
                          ),
                          child: Text(
                            'AI',
                            maxLines: 10,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.grey[300],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            if (life > 0) {
                              processResponse(categoryWin: 'human');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: answer == true
                                ? gameImages[currentIndex]['category'] ==
                                        'human'
                                    ? const Color.fromARGB(255, 41, 95, 43)
                                    : const Color.fromARGB(255, 129, 42, 42)
                                : const Color(0xff6750a4),
                          ),
                          child: Text(
                            'Human',
                            maxLines: 10,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.grey[300],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(padding: EdgeInsets.all(5)),
              if (_banner != null)
                SizedBox(
                  height: 50,
                  width: 320,
                  child: AdWidget(ad: _banner!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
