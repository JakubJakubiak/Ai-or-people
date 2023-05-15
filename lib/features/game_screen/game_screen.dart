import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:games_services/games_services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:humanai/features/game_screen/widgets/game_over_dialog.dart';
import 'package:humanai/features/game_screen/widgets/healh_display.dart';
import 'package:humanai/modules/admob_service.dart';
import 'package:humanai/utils/constants.dart';
import 'package:humanai/utils/gaps.dart';
import 'package:humanai/utils/shared_preferences_helper.dart';
import 'package:humanai/api/prompt.dart';

enum CurrentAnswer { none, ai, human }

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.initialHealth = 3,
    this.limitAdmob = 2,
  });

  final int initialHealth;
  final int limitAdmob;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final stateManager = HomePageManager();
  CurrentAnswer answer = CurrentAnswer.none;

  int currentHealth = 0;
  int score = 0;
  int currentIndex = 0;
  int limitAdmob = 2;

  BannerAd? _banner;

  List<Map<String, dynamic>> gameImages = [];
  Animation<double>? animation;
  dynamic sizeW;
  dynamic sizeH;

  late Timer timer;
  final _pageController = PageController();

  RewardedAd? _rewardedAd;

  void _incrementScore() {
    setState(() {
      score++;
    });
  }

  @override
  void initState() {
    super.initState();
    currentHealth = widget.initialHealth;
    GamesServices.signIn();
    _createBanerAd();
    stateManager.makeGetRequest();
  }

  Future<void> processResponse({
    required String categoryWin,
    required CurrentAnswer answer,
  }) async {
    if (this.answer != CurrentAnswer.none) return;
    this.answer = answer;

    if (categoryWin == gameImages[currentIndex]['category']) {
      _incrementScore();
    } else {
      _loseHealth();
    }

    // if last element, go to index 0 and shuffle gameImages

    Future<void> showNextImage() async {
      await _pageController.animateToPage(
        _pageController.page!.toInt() + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }

    timer = Timer(const Duration(milliseconds: 600), () {
      if (currentIndex == gameImages.length - 1) {
        gameImages.shuffle();
        _pageController.jumpToPage(0);
        setState(() {});
      } else {
        showNextImage();
      }
      setState(() {
        this.answer = CurrentAnswer.none;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _createBanerAd() {
    if (!Constants.adsEnabled) return;
    _banner = BannerAd(
      size: AdSize.fullBanner,
      adUnitId: AdMobService.bannerAdUnitId,
      listener: AdMobService.bannerAdListener,
      request: const AdRequest(),
    )..load();
  }

  void _loseHealth() {
    setState(() {
      currentHealth--;
    });
    if (currentHealth <= 0) {
      endGame();
    }
  }

  void endGame() {
    _loadRewardedAd();
    _submitScore(score);
    saveBestScore(score);
    showGameOverDialog();
  }

  void saveBestScore(int score) {
    final bestScore = SharedPreferencesHelper.getBestScore();
    if (score > bestScore) SharedPreferencesHelper.setBestScore(score);
  }

  Future<Widget?> showGameOverDialog() {
    // if (requestState is RequestLoadSuccess) {

    return showDialog<Widget>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: GameOverDialog(
          score: score,
          onPlayAgain: reset,
          onContinuePlaying: (
            BuildContext dialogContext,
          ) async {
            if (_rewardedAd != null && Constants.adsEnabled) {
              await _rewardedAd?.show(
                onUserEarnedReward: (ad, reward) {
                  addFullHealth();
                  Navigator.of(dialogContext).pop();
                },
              );
            } else {
              addFullHealth();
              Navigator.of(dialogContext).pop();
            }
          },
          limitAdmob: limitAdmob,
        ),
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
          androidLeaderboardID: Constants.androidLeaderboardId,
          iOSLeaderboardID: Constants.iosLeaderboardId,
          value: counter,
        ),
      );
    } catch (e) {
      print(e);
    }
  }

  void addFullHealth() {
    setState(() {
      limitAdmob--;
      currentHealth = 3;
    });
  }

  void reset() {
    setState(() {
      currentHealth = 3;
      limitAdmob = 2;
      score = 0;
    });
  }

  Future<void> _showLeaderboards() async {
    if (!await isSignedIn()) return;
    await Leaderboards.showLeaderboards(
      androidLeaderboardID: Constants.androidLeaderboardId,
      iOSLeaderboardID: Constants.iosLeaderboardId,
    );
  }

  Future<void> _loadIntersitialAd() async {
    if (!Constants.adsEnabled) return;
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
    if (!Constants.adsEnabled) return;
    await RewardedAd.load(
      adUnitId: AdMobService.rewardedAdUnitID,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) =>
                log('ad onAdShowedFullScreenContent.'),
            onAdDismissedFullScreenContent: (ad) async {
              log('ad onAdDismissedFullScreenContent.');
              await ad.dispose();
              await _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              log('ad onAdFailedToShowFullScreenContent: $error');
              ad.dispose();
            },
            onAdImpression: (ad) => log('ad impression.'),
          );
        },
        onAdFailedToLoad: (error) {
          log('RewardedAd failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  void setupImages(Map<String, dynamic> jsonData) {
    final imagesList = jsonData['humanOrAi'] as List<dynamic>;
    final mapped = imagesList.cast<Map<String, dynamic>>().map((e) {
      return {'link': e['link'], 'category': e['op']};
    }).toList()
      ..shuffle();

    gameImages = mapped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: HealthDisplay(
          currentHealth: currentHealth,
          maxHealth: widget.initialHealth,
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _showLeaderboards();
            },
            icon: const Icon(Icons.leaderboard),
          ),
          gapW8,
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<RequestState>(
          valueListenable: stateManager.resultNotifier,
          builder: (context, requestState, child) {
            if (requestState is RequestLoadInProgress) {
              return const SizedBox.shrink();
            }

            if (requestState is RequestLoadFailure) {
              return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Error loading images',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      gapH16,
                      const Text(
                        'Please check your internet connection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      gapH24,
                      FilledButton.icon(
                        onPressed: stateManager.makeGetRequest,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      )
                    ]),
              );
            }

            if (requestState is RequestLoadSuccess) {
              print('success');
              final jsonData =
                  jsonDecode(requestState.body) as Map<String, dynamic>;
              if (gameImages.isEmpty) {
                setupImages(jsonData);
              }
            }

            return Center(
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        gapH16,
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: Sizes.p16),
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
                        gapH16,
                        Text(
                          '$score',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        gapH16,
                        Flexible(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.width -
                                    Sizes.p32,
                              ),
                              child: PageView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: gameImages.length,
                                controller: _pageController,
                                itemBuilder: (
                                  context,
                                  index,
                                ) {
                                  currentIndex = index;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Sizes.p16,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaQuery.of(context).size.width,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: CachedNetworkImage(
                                          imageUrl: gameImages[index]['link']
                                              as String,
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) =>
                                              const Icon(Icons.error),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  gapH16,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sizes.p16),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: FilledButton(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                if (currentHealth > 0) {
                                  await processResponse(
                                    categoryWin: 'ai',
                                    answer: CurrentAnswer.ai,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: answer == CurrentAnswer.ai
                                    ? gameImages[currentIndex]['category'] ==
                                            'ai'
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
                        gapW16,
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: FilledButton(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                if (currentHealth > 0) {
                                  await processResponse(
                                    categoryWin: 'human',
                                    answer: CurrentAnswer.human,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: answer == CurrentAnswer.human
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
                  gapH16,
                  if (_banner != null && Constants.adsEnabled)
                    SizedBox(
                      height: 50,
                      width: 320,
                      child: AdWidget(ad: _banner!),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
