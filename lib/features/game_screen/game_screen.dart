import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:games_services/games_services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:humanai/api/content_repository.dart';
import 'package:humanai/features/game_screen/streak_service.dart';
import 'package:humanai/features/game_screen/tips.dart';
import 'package:humanai/features/game_screen/widgets/answer_bar.dart';
import 'package:humanai/features/game_screen/widgets/daily_raking.dart';
import 'package:humanai/features/game_screen/widgets/effects.dart';
import 'package:humanai/features/game_screen/widgets/game_over_dialog.dart';
import 'package:humanai/features/game_screen/widgets/healh_display.dart';
import 'package:humanai/features/game_screen/widgets/how_to_play.dart';
import 'package:humanai/features/game_screen/widgets/media_card.dart';
import 'package:humanai/features/game_screen/widgets/setings_menu.dart';
import 'package:humanai/models/game_item.dart';
import 'package:humanai/modules/admob_service.dart';
import 'package:humanai/utils/app_colors.dart';
import 'package:humanai/utils/constants.dart';
import 'package:humanai/utils/shared_preferences_helper.dart';
import 'package:video_player/video_player.dart';

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

class _GameScreenState extends State<GameScreen> {
  /// How long a video or song may take to start before it is skipped.
  static const _mediaTimeout = Duration(seconds: 15);

  /// After this many dead links in a row we assume the connection is the problem.
  static const _maxBrokenInRow = 6;
  static const _autoAdvanceDelay = Duration(milliseconds: 1800);

  /// A miss stays a little longer so the tip can be read; "Next" skips the wait.
  static const _autoAdvanceDelayWrong = Duration(milliseconds: 2800);

  /// "Next" sits where the answer buttons were, so a quick double tap would
  /// skip the tip. Taps this soon after an answer are ignored.
  static const _nextGuard = Duration(milliseconds: 500);

  final _repository = ContentRepository();
  final _player = AudioPlayer();
  final _audioSubscriptions = <StreamSubscription<dynamic>>[];

  List<GameItem> _allItems = const [];
  List<GameItem> _deck = const [];
  int _index = 0;
  Set<MediaType> _types = SharedPreferencesHelper.getEnabledTypes();

  int _health = 0;
  int _score = 0;
  int _limitAdmob = 0;
  double _boostX = 1;

  // State of the current round.
  bool _answered = false;
  bool _correct = false;
  int _pointsEarned = 0;
  String _tip = '';
  DateTime _answeredAt = DateTime.now();
  final Map<MediaType, RoundStats> _stats = {};

  // Media of the current round. [_mediaToken] changes with every round so that
  // late callbacks from a previous item can be ignored.
  int _mediaToken = 0;
  int _brokenInRow = 0;
  bool _connectionProblem = false;
  VideoPlayerController? _video;
  bool _audioWanted = false;
  bool _audioReady = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  Timer? _mediaWatchdog;
  Timer? _autoAdvance;

  BannerAd? _banner;
  RewardedAd? _rewardedAd;

  GameItem? get _item => _deck.isEmpty ? null : _deck[_index];

  @override
  void initState() {
    super.initState();
    _health = widget.initialHealth;
    _limitAdmob = widget.limitAdmob;
    _boostX = _startingBoost();

    _player.setReleaseMode(ReleaseMode.loop);
    _audioSubscriptions
      ..add(_player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _audioDuration = d);
      }))
      ..add(_player.onPositionChanged.listen((p) {
        if (!mounted) return;
        setState(() {
          _audioPosition = p;
          if (p > Duration.zero && !_audioReady) {
            _audioReady = true;
            _mediaStarted();
          }
        });
      }));

    _repository.resultNotifier.addListener(_onContentState);
    _repository.load();

    _signInToGames();
    _createBannerAd();
    _loadRewardedAd();

    if (!SharedPreferencesHelper.getHowToPlaySeen()) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await HowToPlayDialog.show(context);
        await SharedPreferencesHelper.setHowToPlaySeen();
      });
    }
  }

  @override
  void dispose() {
    _mediaWatchdog?.cancel();
    _autoAdvance?.cancel();
    for (final s in _audioSubscriptions) {
      s.cancel();
    }
    _repository.resultNotifier.removeListener(_onContentState);
    _player.dispose();
    _video?.dispose();
    _banner?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- content

  void _onContentState() {
    final state = _repository.resultNotifier.value;
    if (state is RequestLoadSuccess) {
      _allItems = state.items;
      _startDeck();
    } else if (mounted) {
      setState(() {});
    }
  }

  void _startDeck() {
    var deck = ContentRepository.buildDeck(_allItems, types: _types);
    // If the chosen types have no content (e.g. a list failed to load), fall back to everything.
    if (deck.isEmpty) deck = ContentRepository.buildDeck(_allItems);
    _deck = deck;
    _index = 0;
    _connectionProblem = false;
    _brokenInRow = 0;
    _showCurrentItem();
  }

  /// Day-streak bonus: the longer the streak, the higher the starting combo.
  double _startingBoost() {
    final loginDay = StreakService.instance.getCurrentStreak();
    if (loginDay < 1) return 1;
    return min(1.2 + (loginDay ~/ 2) * 0.5, 10);
  }

  // ------------------------------------------------------------------ media

  void _showCurrentItem() {
    _mediaWatchdog?.cancel();
    _autoAdvance?.cancel();
    _mediaToken++;
    final token = _mediaToken;

    final oldVideo = _video;
    _video = null;
    oldVideo?.dispose();
    _player.stop();

    _answered = false;
    _audioWanted = false;
    _audioReady = false;
    _audioPosition = Duration.zero;
    _audioDuration = Duration.zero;

    final item = _item;
    if (item != null) {
      switch (item.type) {
        case MediaType.image:
          break;
        case MediaType.video:
          _startVideo(item, token);
        case MediaType.music:
          _startAudio(item, token);
      }
      _precacheUpcomingImages();
    }
    if (mounted) setState(() {});
  }

  Future<void> _startVideo(GameItem item, int token) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(item.url));
    _video = controller;
    _mediaWatchdog = Timer(_mediaTimeout, () => _skipBroken(token));
    try {
      await controller.initialize();
      if (!mounted || token != _mediaToken) return;
      await controller.setLooping(true);
      await controller.play();
      _mediaStarted();
      setState(() {});
    } catch (e) {
      debugPrint('Video failed (${item.url}): $e');
      _skipBroken(token);
    }
  }

  Future<void> _startAudio(GameItem item, int token) async {
    _audioWanted = true;
    _mediaWatchdog = Timer(_mediaTimeout, () => _skipBroken(token));
    try {
      await _player.play(UrlSource(item.url));
    } catch (e) {
      debugPrint('Audio failed (${item.url}): $e');
      _skipBroken(token);
    }
  }

  void _mediaStarted() {
    _mediaWatchdog?.cancel();
    _brokenInRow = 0;
  }

  /// Dead or unreachable media never costs the player anything: the round is
  /// silently replaced by the next one.
  void _skipBroken(int token) {
    if (!mounted || token != _mediaToken || _answered) return;
    _brokenInRow++;
    if (_brokenInRow >= _maxBrokenInRow) {
      _mediaWatchdog?.cancel();
      _player.stop();
      setState(() => _connectionProblem = true);
      return;
    }
    _advance();
  }

  void _precacheUpcomingImages() {
    for (var i = 1; i <= 3 && _index + i < _deck.length; i++) {
      final next = _deck[_index + i];
      if (next.type == MediaType.image) {
        precacheImage(CachedNetworkImageProvider(next.url), context, onError: (_, __) {});
      }
    }
  }

  Future<void> _toggleAudio() async {
    final item = _item;
    if (item == null) return;
    if (_audioWanted) {
      await _player.pause();
    } else if (_audioReady) {
      await _player.resume();
    } else {
      unawaited(_startAudio(item, _mediaToken));
    }
    if (mounted) setState(() => _audioWanted = !_audioWanted);
  }

  void _toggleVideo() {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    video.value.isPlaying ? video.pause() : video.play();
  }

  void _openZoom() {
    final item = _item;
    if (item == null || item.type != MediaType.image) return;
    Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => ZoomView(url: item.url)));
  }

  // --------------------------------------------------------------- gameplay

  void _answer(bool guessedAi) {
    final item = _item;
    if (item == null || _answered || _health <= 0) return;
    _mediaWatchdog?.cancel();
    _brokenInRow = 0;

    final correct = guessedAi == item.isAi;
    final stats = _stats.putIfAbsent(item.type, RoundStats.new);
    stats.total++;

    setState(() {
      _answered = true;
      _answeredAt = DateTime.now();
      _correct = correct;
      _tip = Tips.forItem(item);
      if (correct) {
        stats.correct++;
        _pointsEarned = (10 * _boostX).toInt();
        _score += _pointsEarned;
        _boostX = min(double.parse((_boostX * 1.1).toStringAsFixed(1)), 12);
      } else {
        _pointsEarned = 0;
        _health--;
        _boostX = 1;
      }
    });

    if (correct) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    // Every round moves on by itself, right or wrong, to keep the game flowing.
    _autoAdvance = Timer(correct ? _autoAdvanceDelay : _autoAdvanceDelayWrong, _next);
  }

  void _onNextTapped() {
    if (DateTime.now().difference(_answeredAt) < _nextGuard) return;
    _next();
  }

  void _next() {
    _autoAdvance?.cancel();
    if (!mounted || !_answered) return;
    if (_health <= 0) {
      _endGame();
    } else {
      _advance();
    }
  }

  void _advance() {
    if (_index + 1 < _deck.length) {
      _index++;
      _showCurrentItem();
    } else {
      // Whole deck seen: deal a freshly balanced one.
      final keepBroken = _brokenInRow;
      _startDeck();
      _brokenInRow = keepBroken;
    }
  }

  void _endGame() {
    _player.pause();
    _video?.pause();
    setState(() => _audioWanted = false);

    StreakService.instance.recordEntry().then((isNewDay) {
      if (isNewDay && mounted) {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => SlidingMenuWidget(
            consecutiveDays: StreakService.instance.getCurrentStreak(),
            onClose: () => Navigator.pop(context),
          ),
        );
      }
    });

    final isNewBest = _score > SharedPreferencesHelper.getBestScore();
    if (isNewBest) SharedPreferencesHelper.setBestScore(_score);
    _submitScore(_score);
    _loadRewardedAd();
    _showGameOverDialog(isNewBest: isNewBest);
  }

  Future<void> _showGameOverDialog({required bool isNewBest}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: GameOverDialog(
          score: _score,
          isNewBest: isNewBest,
          stats: _stats,
          limitAdmob: _limitAdmob,
          onPlayAgain: _reset,
          onContinuePlaying: _continueAfterAd,
        ),
      ),
    );
  }

  Future<void> _continueAfterAd() async {
    final ad = _rewardedAd;
    if (ad != null && Constants.adsEnabled) {
      _rewardedAd = null;
      var rewarded = false;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadRewardedAd();
          // Closing the ad early gives no extra lives: back to the results.
          if (rewarded) {
            _restoreHealth();
          } else if (mounted) {
            _showGameOverDialog(isNewBest: false);
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadRewardedAd();
          _restoreHealth();
        },
      );
      await ad.show(onUserEarnedReward: (_, __) => rewarded = true);
    } else {
      // No ad available (offline, no fill): do not punish the player for it.
      _restoreHealth();
      _loadRewardedAd();
    }
  }

  void _restoreHealth() {
    if (!mounted) return;
    setState(() {
      if (_limitAdmob > 0) _limitAdmob--;
      _health = widget.initialHealth;
    });
    _advance();
  }

  void _reset() {
    setState(() {
      _health = widget.initialHealth;
      _limitAdmob = widget.limitAdmob;
      _score = 0;
      _boostX = _startingBoost();
      _stats.clear();
    });
    _startDeck();
    _loadRewardedAd();
  }

  // ------------------------------------------------------- services and ads

  Future<void> _signInToGames() async {
    try {
      await GamesServices.signIn();
    } catch (e) {
      debugPrint('Games sign-in failed: $e');
    }
  }

  Future<void> _submitScore(int value) async {
    try {
      if (!await GamesServices.isSignedIn) return;
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: Constants.androidLeaderboardId,
          iOSLeaderboardID: Constants.iosLeaderboardId,
          value: value,
        ),
      );
    } catch (e) {
      debugPrint('Error submitting score: $e');
    }
  }

  Future<void> _showLeaderboards() async {
    try {
      if (!await GamesServices.isSignedIn) await GamesServices.signIn();
      await GamesServices.showLeaderboards(
        iOSLeaderboardID: Constants.iosLeaderboardId,
        androidLeaderboardID: Constants.androidLeaderboardId,
      );
    } catch (e) {
      debugPrint('Error showing leaderboards: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leaderboards are not available right now.')));
      }
    }
  }

  Future<void> _openSettings() async {
    final before = _types;
    final selected = await showDialog<Set<MediaType>>(
      context: context,
      builder: (context) => SettingsMenu(
        enabledTypes: _types,
        availableTypes: _allItems.map((i) => i.type).toSet(),
      ),
    );
    if (selected == null || !mounted) return;
    await SharedPreferencesHelper.setEnabledTypes(selected);
    if (selected.length == before.length && selected.containsAll(before)) return;
    _types = selected;
    // Only swap the round if the player has not answered it yet.
    if (_allItems.isNotEmpty && _health > 0) _startDeck();
  }

  void _createBannerAd() {
    if (!Constants.adsEnabled) return;
    _banner = BannerAd(
      // A standard 320x50 banner fits every phone; the old full banner (468 wide) was cut off.
      size: AdSize.banner,
      adUnitId: AdMobService.bannerAdUnitId,
      listener: AdMobService.bannerAdListener,
      request: const AdRequest(),
    )..load();
  }

  Future<void> _loadRewardedAd() async {
    if (!Constants.adsEnabled || _rewardedAd != null) return;
    await RewardedAd.load(
      adUnitId: AdMobService.rewardedAdUnitID,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  // --------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LivingBackground(
        heat: ((_boostX - 1) / 4).clamp(0, 1),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                health: _health,
                maxHealth: widget.initialHealth,
                onLeaderboard: () {
                  HapticFeedback.selectionClick();
                  _showLeaderboards();
                },
                onSettings: () {
                  HapticFeedback.selectionClick();
                  _openSettings();
                },
              ),
              Expanded(child: _buildBody()),
              if (_banner != null && Constants.adsEnabled)
                SizedBox(
                  width: _banner!.size.width.toDouble(),
                  height: _banner!.size.height.toDouble(),
                  child: AdWidget(ad: _banner!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final state = _repository.resultNotifier.value;
    if (state is RequestLoadFailure || _connectionProblem) {
      return _Message(
        icon: Icons.wifi_off_rounded,
        title: 'No connection',
        text: 'The game needs the internet to load images, videos and music.',
        action: 'Try again',
        onAction: () {
          setState(() => _connectionProblem = false);
          if (_allItems.isEmpty) {
            _repository.load();
          } else {
            _brokenInRow = 0;
            _advance();
          }
        },
      );
    }
    final item = _item;
    if (item == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.textMuted));
    }

    final token = _mediaToken;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          _ScoreHeader(
            score: _score,
            best: max(SharedPreferencesHelper.getBestScore(), _score),
            boost: _boostX,
            popKey: _answered && _correct ? token : null,
            points: _pointsEarned,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(animation), child: child),
              ),
              child: Shake(
                key: ValueKey(token),
                trigger: _answered && !_correct ? token : null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MediaCard(
                      item: item,
                      revealed: _answered,
                      wasCorrect: _correct,
                      videoController: _video,
                      audioPlaying: _audioWanted,
                      audioReady: _audioReady,
                      audioPosition: _audioPosition,
                      audioDuration: _audioDuration,
                      onToggleAudio: _toggleAudio,
                      onSeekAudio: _player.seek,
                      onToggleVideo: _toggleVideo,
                      onMediaError: () => _skipBroken(token),
                      onZoom: _openZoom,
                    ),
                    if (_answered && _correct) Positioned.fill(child: SparkBurst(color: item.isAi ? AppColors.ai : AppColors.human)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: _answered
                ? RevealPanel(
                    key: ValueKey('reveal$token'),
                    correct: _correct,
                    isAi: item.isAi,
                    tip: _tip,
                    pointsEarned: _pointsEarned,
                    credit: item.credit,
                    nextLabel: _health <= 0 ? 'See results' : 'Next',
                    autoAdvance: _correct ? _autoAdvanceDelay : _autoAdvanceDelayWrong,
                    onNext: _onNextTapped,
                  )
                : AnswerButtons(
                    enabled: _health > 0,
                    onAnswer: (ai) {
                      HapticFeedback.mediumImpact();
                      _answer(ai);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.health,
    required this.maxHealth,
    required this.onLeaderboard,
    required this.onSettings,
  });

  final int health;
  final int maxHealth;
  final VoidCallback onLeaderboard;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
      child: Row(
        children: [
          HealthDisplay(currentHealth: health, maxHealth: maxHealth),
          const Spacer(),
          IconButton(onPressed: onLeaderboard, tooltip: 'Leaderboard', icon: const Icon(Icons.leaderboard_rounded, color: Colors.white)),
          IconButton(onPressed: onSettings, tooltip: 'Settings', icon: const Icon(Icons.tune_rounded, color: Colors.white)),
        ],
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.score, required this.best, required this.boost, required this.popKey, required this.points});
  final int score;
  final int best;
  final double boost;

  /// Non-null right after a correct answer; a new value replays the score pop.
  final Object? popKey;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Human or AI?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
              ),
              const SizedBox(height: 2),
              Text('Best $best', style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        ComboFlame(boost: boost, size: 62),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 84),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topRight,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('SCORE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                    TweenAnimationBuilder<double>(
                      key: ValueKey(popKey),
                      tween: Tween(begin: popKey == null ? 1 : 1.35, end: 1),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) => Transform.scale(scale: scale, alignment: Alignment.centerRight, child: child),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: score.toDouble()),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        builder: (context, value, _) => Text(
                          '${value.round()}',
                          style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, height: 1.1),
                        ),
                      ),
                    ),
                  ],
                ),
                if (popKey != null) Positioned(top: -6, right: 0, child: FloatingPoints(key: ValueKey(popKey), points: points)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text, required this.action, required this.onAction});
  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textMuted, size: 64),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 16, height: 1.35)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(action),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Answers given for one media type during a run.
class RoundStats {
  int correct = 0;
  int total = 0;
}
