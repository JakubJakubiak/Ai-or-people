import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
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
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

enum CurrentAnswer { none, ai, human }

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.initialHealth = 3,
    this.limitAdmob = 20000,
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
  int currentIndexMusick = 0;
  int limitAdmob = 0;

  final player = AudioPlayer();

  bool isPlaying = false;
  bool musicOrImages = false;

  BannerAd? _banner;

  List<Map<String, dynamic>> gameImages = [];
  List<Map<String, dynamic>> musickList = [];
  Animation<double>? animation;
  dynamic sizeW;
  dynamic sizeH;

  late Timer timer;
  final _pageController = PageController();

  RewardedAd? _rewardedAd;

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _incrementScore() {
    setState(() {
      score++;
    });
  }

  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  @override
  void initState() {
    super.initState();
    currentHealth = widget.initialHealth;
    limitAdmob = widget.limitAdmob;
    GamesServices.signIn();
    _createBanerAd();
    stateManager.makeGetRequest();

    player.onDurationChanged.listen((d) {
      setState(() {
        duration = d;
      });
    });
    player.onPositionChanged.listen((p) {
      setState(() {
        position = p;
      });
    });
  }

  Future<void> processResponse({
    required String categoryWin,
    required CurrentAnswer answer,
  }) async {
    if (this.answer != CurrentAnswer.none) return;
    this.answer = answer;

    if (categoryWin == gameImages[currentIndex]['category'] ||
        categoryWin == musickList[currentIndexMusick]['category']) {
      _incrementScore();
    } else {
      _loseHealth();
    }

    Future<void> showNextImage() async {
      Random random = Random();
      double randomValue = random.nextDouble();

      await _pageController.animateToPage(
        _pageController.page!.toInt() + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      musicOrImages = randomValue < 0.8;
      await player.pause();
      setState(() {
        position = Duration.zero;
        duration = Duration.zero;
        isPlaying = false;
      });
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
    player.dispose();
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
      builder: (context) => PopScope(
        canPop: false,
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
      limitAdmob = 2000;
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
                // log('ad onAdShowedFullScreenContent.'),
                print('ad onAdShowedFullScreenContent.'),
            onAdDismissedFullScreenContent: (ad) async {
              print('ad onAdDismissedFullScreenContent.');
              await ad.dispose();
              await _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('ad onAdFailedToShowFullScreenContent: $error');
              ad.dispose();
            },
            onAdImpression: (ad) => print('ad impression.'),
          );
        },
        onAdFailedToLoad: (error) {
          print('RewardedAd failed to load: $error');
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

  void statusPlayer() {
    player.onPositionChanged.listen((Duration position) {
      setState(() {
        this.position = position;
      });
    });

    player.onDurationChanged.listen((Duration duration) {
      setState(() {
        this.duration = duration;
      });
    });
  }

  void setupMusick(List<dynamic> jsonData, Map<String, dynamic> jsonDataAi) {
    final mapped = jsonData.map<Map<String, dynamic>>((e) {
      return {
        'linkMusick': e['url'],
        'category': 'human',
        'track': e['track'],
        'artistraw': e['artistraw'],
        'imageCover': e['cover'],
      };
    }).toList();

    final randomAi =
        (jsonDataAi['playlists'] as List<dynamic>).expand((playlist) {
      return (playlist['playlist_clips'] as List<dynamic>)
          .map<Map<String, dynamic>>((clipData) {
        final clip = clipData['clip'];
        return {
          'linkMusick': clip['audio_url'],
          'imageCover': clip['image_url'],
          'category': 'ai',
        };
      });
    }).toList();

    musickList = (mapped + randomAi)..shuffle();
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

            if (requestState is RequestLoadSuccess) {
              final jsonData = requestState.data;

              final jsonDatatinyncsmusic =
                  jsonData['tinyncsmusic'] as List<dynamic>;
              final jsonDatatinyncsmusicAi =
                  jsonData['musicAi'] as Map<String, dynamic>;
              final jsonDataHumanOrAi =
                  jsonData['humnOrAi'] as Map<String, dynamic>;

              if (gameImages.isEmpty) setupImages(jsonDataHumanOrAi);
              if (musickList.isEmpty) {
                setupMusick(jsonDatatinyncsmusic, jsonDatatinyncsmusicAi);
              }
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
                                itemCount:
                                    (gameImages.length > musickList.length)
                                        ? gameImages.length
                                        : musickList.length,
                                controller: _pageController,
                                itemBuilder: (
                                  context,
                                  index,
                                ) {
                                  currentIndex = index;
                                  currentIndexMusick = index;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Sizes.p16,
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: CachedNetworkImage(
                                            imageUrl: musicOrImages
                                                ? "https://i.imgur.com/9IAD2q9.jpeg"
                                                // musickList[currentIndexMusick]
                                                //     ['imageCover'] as String

                                                : gameImages[index]['link']
                                                    as String,
                                            fit: BoxFit.cover,
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error),
                                          ),
                                        ),
                                        if (musicOrImages)
                                          ElevatedButton(
                                            onPressed: () async {
                                              if (isPlaying) {
                                                await player.pause();
                                              } else {
                                                await player.play(
                                                  UrlSource(
                                                    musickList.isNotEmpty &&
                                                            currentIndexMusick <
                                                                musickList
                                                                    .length
                                                        ? musickList[
                                                                currentIndexMusick]
                                                            [
                                                            'linkMusick'] as String
                                                        : '',
                                                  ),
                                                );
                                                statusPlayer();
                                              }
                                              setState(() {
                                                isPlaying = !isPlaying;
                                              });
                                            },
                                            child: Icon(
                                              isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                            ),
                                          )
                                        else
                                          Container(),
                                        if (musicOrImages)
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                top: 300,
                                                bottom: 20,
                                                left: Sizes.p16,
                                                right: Sizes.p16,
                                              ),
                                              child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[900]
                                                        ?.withOpacity(0.8),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.only(
                                                    top: 20,
                                                    bottom: 20,
                                                    left: Sizes.p16,
                                                    right: Sizes.p16,
                                                  ),
                                                  child: ProgressBar(
                                                    progress: position,
                                                    total: duration,
                                                    onSeek: (value) async {
                                                      await player.seek(
                                                        Duration(
                                                            seconds: value
                                                                .inSeconds),
                                                      );
                                                    },
                                                    // timeLabelLocation:
                                                    //     TimeLabelLocation.sides,
                                                    barHeight: 10,
                                                    baseBarColor: Colors.grey,
                                                    thumbColor: Colors.blue,
                                                    progressBarColor:
                                                        Colors.blue,
                                                    bufferedBarColor:
                                                        Colors.grey,
                                                    timeLabelTextStyle:
                                                        const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  )))
                                        else
                                          Container(),
                                      ],
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
                  // if (musicOrImages)
                  //   Padding(
                  //       padding: const EdgeInsets.symmetric(
                  //         horizontal: Sizes.p16,
                  //       ),
                  //       child: ProgressBar(
                  //         progress: position,
                  //         total: duration,
                  //         onSeek: (value) async {
                  //           await player
                  //               .seek(Duration(seconds: value.inSeconds));
                  //         },
                  //         barHeight: 10,
                  //         baseBarColor: Colors.grey,
                  //         progressBarColor: Colors.blue,
                  //         bufferedBarColor: Colors.grey,
                  //         timeLabelTextStyle: const TextStyle(
                  //           fontSize: 12,
                  //         ),
                  //       ))
                  // else
                  //   Container(),
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
                                    ? (gameImages[currentIndex]['category'] ==
                                                'ai' ||
                                            musickList[currentIndexMusick]
                                                    ['category'] ==
                                                'ai')
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
                                await HapticFeedback.mediumImpact();
                                await player.stop();
                                if (currentHealth > 0) {
                                  await processResponse(
                                    categoryWin: 'human',
                                    answer: CurrentAnswer.human,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: answer == CurrentAnswer.human
                                    ? (gameImages[currentIndex]['category'] ==
                                                'human' ||
                                            musickList[currentIndexMusick]
                                                    ['category'] ==
                                                'human')
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
