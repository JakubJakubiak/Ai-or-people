import 'dart:async';
import 'dart:convert';
import 'dart:developer'; // Używany log, zostawiam, jeśli potrzebny
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:games_services/games_services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:humanai/features/game_screen/streak_service.dart';
import 'package:humanai/features/game_screen/widgets/FlameBoostAnimation%20.dart';
import 'package:humanai/features/game_screen/widgets/daily_raking.dart'; // Nie używane?
import 'package:humanai/features/game_screen/widgets/game_over_dialog.dart';
import 'package:humanai/features/game_screen/widgets/healh_display.dart';
import 'package:humanai/features/game_screen/widgets/setings_menu.dart';
// import 'package:humanai/features/game_screen/widgets/vide_player.dart'; // Usunięto, logika wbudowana
import 'package:humanai/modules/admob_service.dart';
import 'package:humanai/utils/constants.dart';
import 'package:humanai/utils/gaps.dart';
import 'package:humanai/utils/shared_preferences_helper.dart';
import 'package:animated_digit/animated_digit.dart';
import 'package:humanai/api/prompt.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:intl/intl.dart'; // Nie używane bezpośrednio? Może przez ProgressBar
import 'package:video_player/video_player.dart';

enum CurrentAnswer { none, ai, human }

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.initialHealth = 3,
    this.limitAdmob = 20000,
    // this.colorbackground = const Color.fromARGB(0, 0, 0, 131),
    // required this.onColorChanged,
  });

  final int initialHealth;
  final int limitAdmob;
  // final Color colorbackground;
  // final Function(Color) onColorChanged;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final stateManager = HomePageManager();
  CurrentAnswer answer = CurrentAnswer.none;

  int currentHealth = 0;
  int score = 0;
  int currentIndex = 0;
  int limitAdmob = 0;

  double boostX = 1;

  // --- ZMIENNE VIDEO ---
  VideoPlayerController? _videoController;
  int? _videoControllerIndex;
  Future<void>? _initializeVideoPlayerFuture;
  bool _isVideoPlaying = false;
  VoidCallback? _videoPlayerListener; // Do przechowywania listenera
  // --- KONIEC ZMIENNYCH VIDEO ---

  final player = AudioPlayer(); // Odtwarzacz audio
  final AnimatedDigitController _controller = AnimatedDigitController(0); // Licznik punktów

  bool isPlaying = false; // Czy audio gra
  BannerAd? _banner;

  List<Map<String, dynamic>> allListItems = []; // Główna lista elementów gry

  // Nie używane? Usunąć jeśli niepotrzebne
  // Animation<double>? animation;
  // dynamic sizeW;
  // dynamic sizeH;

  late Timer timer; // Timer do opóźnienia przejścia
  final PageController pageController = PageController(); // Zmieniono nazwę z _pageController

  RewardedAd? _rewardedAd;
  Color _appBarColor = Colors.black; // Kolor paska aplikacji

  // Formatowanie czasu dla paska postępu audio/wideo
  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  // Zwiększanie wyniku
  void _incrementScore(double boostX) {
    setState(() {
      score = (score + 10 * boostX).toInt();
      _controller.addValue(10 * boostX);
      // Resetowanie koloru paska - czy to na pewno potrzebne?
      // _appBarColor = Colors.black;
    });
  }

  // Zmienne do śledzenia postępu audio
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    currentHealth = widget.initialHealth;
    limitAdmob = widget.limitAdmob;
    GamesServices.signIn(); // Logowanie do Usług Gier Google Play/Game Center
    _createBanerAd(); // Tworzenie banera reklamowego
    stateManager.makeGetRequest(); // Pobieranie danych gry

    // Listenery dla odtwarzacza audio
    player.onDurationChanged.listen((d) {
      if (mounted) {
        // Sprawdź czy widget jest nadal w drzewie
        setState(() {
          duration = d;
        });
      }
    });
    player.onPositionChanged.listen((p) {
      if (mounted) {
        // Sprawdź czy widget jest nadal w drzewie
        setState(() {
          position = p;
        });
      }
    });

    // Listener zmian strony w PageView
    pageController.addListener(() {
      int newIndex = pageController.page?.round() ?? 0;
      // Sprawdź czy indeks się faktycznie zmienił i czy jest poprawny
      if (newIndex != currentIndex && newIndex >= 0 && newIndex < allListItems.length) {
        // Zatrzymaj poprzednie odtwarzacze podczas przesuwania
        player.pause(); // Zatrzymaj muzykę, jeśli gra
        _videoController?.pause(); // Zatrzymaj wideo, jeśli gra

        setState(() {
          currentIndex = newIndex;
          // Zresetuj stan wizualny muzyki
          isPlaying = false;
          position = Duration.zero; // Resetuj pozycję audio
          // Zresetuj stan wizualny wideo
          _isVideoPlaying = false;
        });
        // Zainicjuj kontroler (audio/video) dla *nowego* indeksu
        _initControllerForIndex(newIndex);
      }
    });

    // Obliczanie mnożnika punktów na podstawie dni logowania
    final loginDay = StreakService.instance.getCurrentStreak();
    if (loginDay > 1) {
      double comboCalculator = 1.2;
      comboCalculator += (loginDay ~/ 2) * 0.5;
      comboCalculator = min(comboCalculator, 10.0); // Ogranicz do max 10.0
      setState(() {
        boostX = comboCalculator;
      });
    }

    _loadRewardedAd(); // Załaduj reklamę nagradzaną na start
  }

  // Przetwarzanie odpowiedzi użytkownika
  Future<void> processResponse({
    required String categoryWin, // Poprawna kategoria ('ai' lub 'human')
    required CurrentAnswer answer, // Odpowiedź użytkownika
  }) async {
    if (this.answer != CurrentAnswer.none) return; // Zapobiegaj wielokrotnemu kliknięciu
    this.answer = answer;
    setState(() {}); // Aktualizuj UI, aby pokazać wybraną odpowiedź

    bool correctAnswer = (categoryWin == 'ai' && answer == CurrentAnswer.ai) || (categoryWin == 'human' && answer == CurrentAnswer.human);

    if (correctAnswer) {
      _incrementScore(boostX);
    } else {
      _loseHealth();
    }

    // Opóźnienie przed przejściem do następnego elementu
    timer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return; // Sprawdź, czy widget wciąż istnieje

      // Jeśli to ostatni element, wróć na początek i przetasuj
      if (currentIndex == allListItems.length - 1) {
        allListItems.shuffle();
        pageController.jumpToPage(0);
        // Inicjalizuj kontroler dla strony 0 po przetasowaniu
        _initControllerForIndex(0);
      } else {
        // Przejdź do następnej strony
        pageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
        // Listener PageController zajmie się inicjalizacją kontrolera
      }

      // Zresetuj stan odpowiedzi po przejściu
      setState(() {
        this.answer = CurrentAnswer.none;
        // Resetowanie stanu audio przy przejściu
        isPlaying = false;
        position = Duration.zero;
        duration = Duration.zero;
        player.stop(); // Upewnij się, że audio jest zatrzymane
      });

      // Buforowanie następnych elementów (obrazy/muzyka)
      indexBuforImages();
      indexBuforMusic();
    });
  }

  @override
  void dispose() {
    timer.cancel(); // Anuluj timer, jeśli istnieje
    player.dispose(); // Zwolnij zasoby odtwarzacza audio
    _videoController?.dispose(); // Zwolnij zasoby odtwarzacza wideo
    _banner?.dispose(); // Zwolnij zasoby banera
    _rewardedAd?.dispose(); // Zwolnij zasoby reklamy nagradzanej
    pageController.dispose(); // Zwolnij zasoby kontrolera strony
    _controller.dispose(); // Zwolnij zasoby kontrolera animowanej cyfry
    super.dispose();
  }

  // Tworzenie banera reklamowego AdMob
  void _createBanerAd() {
    if (!Constants.adsEnabled) return;
    _banner = BannerAd(
      size: AdSize.fullBanner,
      adUnitId: AdMobService.bannerAdUnitId,
      listener: AdMobService.bannerAdListener,
      request: const AdRequest(),
    )..load();
  }

  // Utrata punktu życia
  void _loseHealth() {
    setState(() {
      currentHealth--;
    });
    if (currentHealth <= 0) {
      endGame(); // Koniec gry, jeśli zdrowie spadnie do zera
    }
  }

  // Logika końca gry
  void endGame() {
    // Zapisz wejście do śledzenia dni logowania
    StreakService.instance.recordEntry().then((isNewDay) {
      final loginDay = StreakService.instance.getCurrentStreak();

      // Ponownie oblicz mnożnik na wypadek, gdyby zmienił się dzień
      double comboCalculator = 1.2;
      comboCalculator += (loginDay ~/ 2) * 0.5;
      comboCalculator = min(comboCalculator, 10.0);
      // Nie aktualizujemy boostX w stanie tutaj, bo to koniec gry

      // Pokaż modal z informacją o dniach logowania, jeśli to nowy dzień
      if (isNewDay && mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => SlidingMenuWidget(
            consecutiveDays: loginDay,
            onClose: () {
              Navigator.pop(context);
            },
          ),
        );
      }
    });

    _submitScore(score); // Wyślij wynik do tablicy wyników
    saveBestScore(score); // Zapisz najlepszy wynik lokalnie
    _loadRewardedAd(); // Spróbuj załadować nową reklamę nagradzaną na przyszłość
    showGameOverDialog(); // Pokaż dialog końca gry
  }

  // Zapisywanie najlepszego wyniku lokalnie
  void saveBestScore(int score) {
    final bestScore = SharedPreferencesHelper.getBestScore();
    if (score > bestScore) SharedPreferencesHelper.setBestScore(score);
  }

  // Wyświetlanie dialogu końca gry
  Future<Widget?> showGameOverDialog() {
    return showDialog<Widget>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: GameOverDialog(
          score: score,
          onPlayAgain: reset,
          onContinuePlaying: (BuildContext dialogContext) async {
            if (_rewardedAd != null && Constants.adsEnabled) {
              // Pokaż reklamę nagradzaną
              await _rewardedAd?.show(
                onUserEarnedReward: (ad, reward) {
                  print('User earned reward!');
                  addFullHealth(); // Dodaj zdrowie po obejrzeniu reklamy
                  if (Navigator.canPop(dialogContext)) {
                    Navigator.of(dialogContext).pop(); // Zamknij dialog
                  }
                  _loadRewardedAd(); // Załaduj kolejną reklamę
                },
              );
              // Ustaw _rewardedAd na null po próbie pokazania, aby uniknąć ponownego użycia tej samej reklamy
              _rewardedAd = null;
            } else {
              // Jeśli reklama nie jest dostępna lub wyłączona
              print('Rewarded Ad not available');
              addFullHealth(); // Dodaj zdrowie bez reklamy (np. w trybie debugowania)
              if (Navigator.canPop(dialogContext)) {
                Navigator.of(dialogContext).pop(); // Zamknij dialog
              }
              _loadRewardedAd(); // Spróbuj załadować nową reklamę
            }
          },
          limitAdmob: limitAdmob, // Przekaż limit użycia reklam
        ),
      ),
    );
  }

  // Sprawdzenie, czy użytkownik jest zalogowany do usług gier
  Future<bool> isSignedIn() async {
    return GamesServices.isSignedIn;
  }

  // Wysyłanie wyniku do tablicy wyników Google Play/Game Center
  Future<void> _submitScore(int counter) async {
    try {
      if (!await isSignedIn()) {
        print("User not signed in, cannot submit score.");
        return;
      }
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: Constants.androidLeaderboardId,
          iOSLeaderboardID: Constants.iosLeaderboardId,
          value: counter,
        ),
      );
      print("Score submitted: $counter");
    } catch (e) {
      print("Error submitting score: $e");
    }
  }

  // Dodanie pełnego zdrowia (np. po obejrzeniu reklamy)
  void addFullHealth() {
    setState(() {
      if (limitAdmob > 0) {
        // Sprawdź czy limit nie został wyczerpany
        limitAdmob--;
        currentHealth = widget.initialHealth; // Ustaw zdrowie na maksimum
      } else {
        print("Ad limit reached, cannot add health via ad.");
        // Można dodać informację dla użytkownika, np. przez SnackBar
      }
    });
  }

  // Resetowanie stanu gry (np. po naciśnięciu "Play Again")
  void reset() {
    setState(() {
      currentHealth = widget.initialHealth;
      limitAdmob = widget.limitAdmob; // Zresetuj limit reklam (lub inną logikę)
      score = 0;
      _controller.resetValue(0);
      answer = CurrentAnswer.none; // Zresetuj stan odpowiedzi
      currentIndex = 0; // Wróć do pierwszego elementu
      allListItems.shuffle(); // Przetasuj elementy
      pageController.jumpToPage(0); // Przejdź do pierwszej strony
      _initControllerForIndex(0); // Zainicjuj kontroler dla pierwszej strony
      isPlaying = false; // Zresetuj stan audio
      position = Duration.zero;
      _isVideoPlaying = false; // Zresetuj stan wideo
      player.stop();
      _videoController?.pause();
    });
    _loadRewardedAd(); // Załaduj nową reklamę nagradzaną
  }

  // Wyświetlanie tablicy wyników
  Future<void> _showLeaderboards() async {
    if (!await isSignedIn()) {
      print("User not signed in, attempting to sign in to show leaderboards...");
      try {
        await GamesServices.signIn();
        if (!await isSignedIn()) {
          print("Sign in failed, cannot show leaderboards.");
          // Można pokazać komunikat użytkownikowi
          return;
        }
      } catch (e) {
        print("Error during sign in for leaderboards: $e");
        return;
      }
    }
    try {
      await GamesServices.showLeaderboards(
        iOSLeaderboardID: Constants.iosLeaderboardId,
        androidLeaderboardID: Constants.androidLeaderboardId,
      );
    } catch (e) {
      print("Error showing leaderboards: $e");
    }
  }

  // Wyświetlanie menu ustawień (dialog)
  Future<void> _setingsMenu() async {
    await showDialog<Widget>(
      context: context,
      barrierDismissible: true, // Pozwól na zamknięcie przez kliknięcie obok
      builder: (context) => SettingsMenu(
        score: score, // Przekaż aktualny wynik (jeśli potrzebny)
        onOptionChanged: (String option) {
          // Tutaj obsługa zmian w ustawieniach, jeśli są
          print('Settings option changed: $option');
        },
      ),
    );
  }

  // Ładowanie reklamy pełnoekranowej (Interstitial) - nieużywane obecnie?
  Future<void> _loadIntersitialAd() async {
    if (!Constants.adsEnabled) return;
    await InterstitialAd.load(
      adUnitId: AdMobService.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.show(); // Pokaż od razu po załadowaniu
        },
        onAdFailedToLoad: (error) {
          print('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  // Ładowanie reklamy nagradzanej
  Future<void> _loadRewardedAd() async {
    if (!Constants.adsEnabled) return;
    await RewardedAd.load(
      adUnitId: AdMobService.rewardedAdUnitID,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('Rewarded Ad Loaded.');
          _rewardedAd = ad; // Zapisz załadowaną reklamę
          // Ustawienie callbacków dla cyklu życia reklamy
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) => print('Rewarded ad onAdShowedFullScreenContent.'),
            onAdDismissedFullScreenContent: (ad) async {
              print('Rewarded ad onAdDismissedFullScreenContent.');
              await ad.dispose(); // Zwolnij zasoby reklamy po zamknięciu
              _rewardedAd = null; // Usuń referencję
              // _loadRewardedAd(); // Załaduj kolejną reklamę od razu po zamknięciu poprzedniej
            },
            onAdFailedToShowFullScreenContent: (ad, error) async {
              print('Rewarded ad onAdFailedToShowFullScreenContent: $error');
              await ad.dispose(); // Zwolnij zasoby w razie błędu
              _rewardedAd = null; // Usuń referencję
              // _loadRewardedAd(); // Spróbuj załadować ponownie
            },
            onAdImpression: (ad) => print('Rewarded ad impression.'),
          );
        },
        onAdFailedToLoad: (error) {
          print('RewardedAd failed to load: $error');
          _rewardedAd = null; // Ustaw na null w razie błędu ładowania
        },
      ),
    );
  }

  // Konfiguracja listy elementów gry na podstawie pobranych danych JSON
  void setupAllListItems(
    Map<String, dynamic> jsonDataImages,
    List<dynamic> jsonDataMusickHuman,
    Map<String, dynamic> jsonDataMusickAi,
    // List<dynamic> jsonDataquotesHuman, // Obecnie nieużywane
    // List<dynamic> jsonDataquotesAi, // Obecnie nieużywane
    List<dynamic> jsonDataVideoAi,
    List<dynamic> jsonDataVideoHuman,
  ) {
    allListItems.clear(); // Wyczyść listę przed dodaniem nowych elementów

    // Przetwarzanie obrazów
    final imagesList = jsonDataImages['humanOrAi'] as List<dynamic>? ?? [];
    final randomImages = imagesList.cast<Map<String, dynamic>>().map((e) {
      return {'link': e['link'], 'category': e['op'], 'typ': 'images'};
    }).toList();

    final randomvideoLinksAi = jsonDataVideoAi.map<Map<String, dynamic>>((e) {
      return {
        'link': e['url'],
        'category': e['op'] ?? 'ai',
        'typ': 'video',
      };
      // Upewnij się, że kategoria 'op' istnieje, domyślnie 'ai'
    }).toList();

    final randomvideoLinksHuman = jsonDataVideoHuman.map<Map<String, dynamic>>((e) {
      return {'link': e['url'], 'category': e['op'] ?? 'human', 'typ': 'video'};
    }).toList();

    // Przetwarzanie muzyki ludzkiej
    final randomMusickHuman = jsonDataMusickHuman.map<Map<String, dynamic>>((e) {
      return {'link': e['url'], 'category': 'human', 'track': e['track'], 'artistraw': e['artistraw'], 'imageCover': e['cover'], 'typ': 'musick'};
    }).toList();

    // Przetwarzanie muzyki AI
    final randomMusickAi = (jsonDataMusickAi['playlists'] as List<dynamic>? ?? []).expand((playlist) {
      return (playlist['playlist_clips'] as List<dynamic>? ?? []).map<Map<String, dynamic>>((clipData) {
        final clip = clipData['clip'];
        return {'link': clip['audio_url'], 'imageCover': clip['image_url'], 'category': 'ai', 'typ': 'musick'};
      });
    }).toList();

    final localList = (randomvideoLinksAi + randomMusickAi + randomvideoLinksHuman + randomMusickHuman + randomImages)..shuffle(Random());
    // print('/////////randomvideoLinksAi///////////$randomvideoLinksHuman');

    // final localList = (randomvideoLinksHuman)..shuffle(Random());

    allListItems.addAll(localList);
    print("Total items loaded: ${allListItems.length}");

    // Sprawdź, czy lista nie jest pusta przed próbą inicjalizacji
    if (allListItems.isNotEmpty) {
      // Zainicjuj kontroler dla pierwszego elementu po załadowaniu danych
      _initControllerForIndex(0);
      // Rozpocznij buforowanie
      indexBuforImages();
      indexBuforMusic();
    } else {
      print("Warning: No items loaded into allListItems.");
      // Można tu dodać obsługę błędu, np. pokazanie komunikatu
    }
  }

  // Buforowanie obrazów w tle
  Future<void> indexBuforImages() async {
    if (!mounted || allListItems.isEmpty) return; // Sprawdzenie bezpieczeństwa
    int currentIn = this.currentIndex;
    int imagesToPrecache = 5; // Zmniejszono liczbę dla wydajności
    for (int i = 1; i <= imagesToPrecache; i++) {
      int nextIndex = (currentIn + i) % allListItems.length;
      if (allListItems[nextIndex]['typ'] == "images") {
        String? imageUrl = allListItems[nextIndex]['link'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          // Użyj try-catch, aby złapać ewentualne błędy podczas precache
          try {
            await precacheImage(
              CachedNetworkImageProvider(imageUrl),
              context,
              // onError: (exception, stackTrace) { // Opcjonalnie obsłuż błąd
              //   print("Error precaching image $imageUrl: $exception");
              // }
            );
            // print("Precached image: $imageUrl");
          } catch (e) {
            print("Exception during precache image $imageUrl: $e");
          }
        }
      }
    }
  }

  // Buforowanie muzyki w tle (AudioPlayers zazwyczaj robi to sam)
  Future<void> indexBuforMusic() async {
    if (!mounted || allListItems.isEmpty) return;
    // AudioPlayers zazwyczaj buforuje automatycznie po wywołaniu setSource.
    // Ta funkcja może nie być konieczna lub można ją uprościć.
    // Można ewentualnie wywołać `player.setSourceUrl` dla kilku następnych utworów,
    // ale może to zużywać niepotrzebnie dane. Zostawiam pustą lub do usunięcia.
    // print("Music pre-buffering (usually handled by audioplayers).");

    // Przykład potencjalnego buforowania (ostrożnie z użyciem danych):
    /*
    int currentInMusick = this.currentIndex;
    int musicToPrecache = 2;
    for (int i = 1; i <= musicToPrecache; i++) {
      int nextIndex = (currentInMusick + i) % allListItems.length;
      if (allListItems[nextIndex]['typ'] == "musick") {
        String? musicLink = allListItems[nextIndex]['link'] as String?;
        if (musicLink != null && musicLink.isNotEmpty) {
          try {
            // Samo ustawienie źródła powinno rozpocząć buforowanie
            await player.setSourceUrl(musicLink);
            // Można od razu zatrzymać, żeby nie odtwarzało
            await player.stop();
            print("Pre-set source for music: $musicLink");
          } catch (e) {
            print("Error pre-setting source for music $musicLink: $e");
          }
        }
      }
    }
    // Przywróć źródło dla bieżącego utworu, jeśli jest muzyką
    if (allListItems[currentIndex]['typ'] == "musick") {
       String? currentMusicLink = allListItems[currentIndex]['link'] as String?;
        if (currentMusicLink != null && currentMusicLink.isNotEmpty) {
           await player.setSourceUrl(currentMusicLink);
        }
    }
    */
  }

  // Inicjalizacja kontrolera wideo dla danego indeksu
  void _initControllerForIndex(int index) {
    // Pozbądź się poprzedniego kontrolera wideo, jeśli istnieje i jest dla innego indeksu
    if (_videoController != null && _videoControllerIndex != index) {
      _disposeVideoController();
    }

    // Sprawdzenie granic indeksu
    if (index < 0 || index >= allListItems.length) {
      // Jeśli aktualny element nie jest wideo, ale kontroler istnieje, pozbądź się go
      if (_videoController != null) {
        _disposeVideoController();
      }
      return;
    }

    final item = allListItems[index];
    final itemType = item['typ'];
    final itemLink = item['link'] as String?;

    // Jeśli element to wideo, ma link i kontroler nie jest jeszcze utworzony DLA TEGO INDEKSU
    if (itemType == 'video' && itemLink != null && _videoController == null) {
      // Sprawdź, czy URL jest poprawny
      Uri? videoUri = Uri.tryParse(itemLink);
      if (videoUri == null || !videoUri.hasAbsolutePath || !videoUri.isAbsolute) {
        print("Error: Invalid video URL for index $index: $itemLink");
        // Opcjonalnie: Ustaw stan błędu w UI
        return;
      }

      print("Initializing video for index $index, URL: $itemLink");
      _videoController = VideoPlayerController.networkUrl(videoUri);
      _videoControllerIndex = index; // Zapisz indeks, dla którego inicjalizujemy

      // --- Stwórz i zapisz listener ---
      _videoPlayerListener = () {
        // Sprawdź 'mounted' i czy listener jest dla właściwego kontrolera/indeksu
        // oraz czy kontroler nie został w międzyczasie usunięty
        if (mounted && _videoControllerIndex == index && _videoController != null) {
          bool currentlyPlaying = _videoController!.value.isPlaying;
          // Aktualizuj stan tylko jeśli się zmienił lub jeśli pozycja się zmienia (dla paska)
          if (_isVideoPlaying != currentlyPlaying || (_videoController?.value.position ?? Duration.zero) != Duration.zero) {
            setState(() {
              _isVideoPlaying = currentlyPlaying;
              // Aktualizacja pozycji/czasu trwania jest obsługiwana przez ValueListenableBuilder w ProgressBar
            });
          }
        }
      };
      // --- Dodaj zapisanego listenera ---
      _videoController!.addListener(_videoPlayerListener!);

      // Rozpocznij inicjalizację i obsłuż jej wynik (sukces/błąd)
      _initializeVideoPlayerFuture = _videoController!.initialize().then((_) {
        if (mounted && _videoControllerIndex == index) {
          print("Video Initialized successfully for index $index");
          // _videoController!.play(); // Opcjonalnie: Automatyczne odtwarzanie po inicjalizacji
          // _isVideoPlaying = true;
          setState(() {}); // Przebuduj UI, aby pokazać pierwszy kadr
        } else {
          print("Video Initialized for index $index, but widget is no longer mounted or index changed.");
          // Jeśli widget został zdjęty lub indeks się zmienił zanim inicjalizacja się zakończyła,
          // kontroler zostanie usunięty przez logikę dispose lub kolejny init.
        }
      }).catchError((error) {
        print("Error initializing video for index $index: $error");
        // Jeśli inicjalizacja się nie powiodła
        if (mounted && _videoControllerIndex == index) {
          // Usuń kontroler i zresetuj stan, aby FutureBuilder pokazał błąd
          _disposeVideoController(); // Dispose zajmie się czyszczeniem
          // Wywołaj setState, aby FutureBuilder mógł zareagować na null w _videoController / _initializeVideoPlayerFuture
          setState(() {});
        }
      });

      // Wywołaj setState, aby FutureBuilder pokazał wskaźnik ładowania
      setState(() {});
    } else if (itemType != 'video' && _videoController != null) {
      // Jeśli bieżący element NIE jest wideo, ale kontroler wideo istnieje (z poprzedniego elementu),
      // pozbądź się go.
      _disposeVideoController();
    }
  }

  // Pomocnicza funkcja do zwalniania zasobów kontrolera wideo
  void _disposeVideoController() {
    print("Disposing video controller for index $_videoControllerIndex");

    // --- Usuń zapisanego listenera ---
    if (_videoController != null && _videoPlayerListener != null) {
      try {
        _videoController!.removeListener(_videoPlayerListener!);
      } catch (e) {
        print("Error removing video listener: $e"); // Złap potencjalne błędy
      }
      _videoPlayerListener = null;
    }

    // Zatrzymaj i zwolnij zasoby kontrolera
    // Użyj `?` dla bezpieczeństwa, chociaż w tym punkcie _videoController nie powinien być null
    _videoController?.pause(); // Najpierw pauza
    _videoController?.dispose(); // Potem dispose

    // Zresetuj zmienne stanu
    _videoController = null;
    _initializeVideoPlayerFuture = null;
    _videoControllerIndex = null;

    // Zresetuj stan wizualny i przebuduj UI, jeśli widget jest zamontowany
    if (mounted) {
      setState(() {
        _isVideoPlaying = false;
      });
    } else {
      _isVideoPlaying = false; // Ustaw stan bezpośrednio, jeśli nie jest zamontowany
    }
  }

  Color _getHighlightColor() {
    if (answer == CurrentAnswer.none) {
      return Colors.transparent; // Brak podświetlenia, jeśli nie ma odpowiedzi
    }
    // Bezpieczny dostęp do kategorii, domyślnie pusty string jeśli null
    final correctAnswerCategory = allListItems[currentIndex]['category'] as String? ?? '';
    bool wasCorrect = (answer == CurrentAnswer.ai && correctAnswerCategory == 'ai') || (answer == CurrentAnswer.human && correctAnswerCategory == 'human');

    // Użyj nieco jaśniejszych kolorów dla podświetlenia
    return wasCorrect ? Colors.green.shade400 : Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _appBarColor,
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
          IconButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _setingsMenu();
            },
            icon: const Icon(Icons.settings),
          ),
          gapW8,
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<RequestState>(
          valueListenable: stateManager.resultNotifier,
          builder: (context, requestState, child) {
            // --- STAN ŁADOWANIA DANYCH ---
            if (requestState is RequestLoadInProgress || requestState is RequestInitial) {
              // Pokaż wskaźnik ładowania na środku, gdy dane są pobierane
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1a1a2e), // Dark base
                      Color(0xFF16213e), // Slightly lighter mid
                      Color(0xFF0f3460), // Optional lighter shade at bottom
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            // --- STAN BŁĘDU POBIERANIA DANYCH ---
            if (requestState is RequestLoadFailure) {
              return Container(
                // Zachowaj tło nawet przy błędzie
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1a1a2e),
                      Color(0xFF16213e),
                      Color(0xFF0f3460),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
                child: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text(
                      'Error loading data', // Zmieniono komunikat
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // Lepszy kontrast na gradiencie
                      ),
                    ),
                    gapH16,
                    const Text(
                      'Please check your internet connection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70, // Lepszy kontrast
                      ),
                    ),
                    gapH24,
                    FilledButton.icon(
                      onPressed: stateManager.makeGetRequest,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blueAccent, // Wyraźniejszy przycisk
                      ),
                    )
                  ]),
                ),
              );
            }

            // --- STAN SUKCESU POBIERANIA DANYCH ---
            if (requestState is RequestLoadSuccess) {
              // Przetwarzaj dane tylko raz, jeśli lista jest pusta
              if (allListItems.isEmpty) {
                final jsonData = requestState.data;
                try {
                  final jsonDataHumanOrAi = jsonData['humnOrAi'] as Map<String, dynamic>? ?? {};
                  final jsonDatatinyncsmusic = jsonData['tinyncsmusic'] as List<dynamic>? ?? [];
                  final jsonDatatinyncsmusicAi = jsonData['musicAi'] as Map<String, dynamic>? ?? {};
                  final videoLinksAi = jsonData['videoLinksAi'] as List<dynamic>? ?? [];
                  final videoLinksHuman = jsonData['videoLinksHuman'] as List<dynamic>? ?? [];

                  setupAllListItems(jsonDataHumanOrAi, jsonDatatinyncsmusic, jsonDatatinyncsmusicAi, videoLinksAi, videoLinksHuman);
                  print("Data setup complete. Total items: ${allListItems.length}");
                  // Sprawdź, czy po setupie lista nadal jest pusta
                  if (allListItems.isEmpty && mounted) {
                    // Pokaż komunikat, jeśli nie załadowano żadnych elementów
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("No game items loaded. Please try again later.")),
                      );
                    });

                    return Container(
                        /* ... tło ... */
                        child: const Center(child: Text("No game items available.", style: TextStyle(color: Colors.white))));
                  }
                } catch (e) {
                  print("Error processing loaded data: $e");
                  // Zwróć widok błędu, jeśli przetwarzanie danych się nie powiodło
                  return Container(/* ... tło ... */ child: Center(child: Text("Error loading game content: $e", style: const TextStyle(color: Colors.red))));
                }
              }
            }

            // Jeśli allListItems jest nadal pusta po próbie załadowania (np. błąd przetwarzania powyżej)
            if (allListItems.isEmpty) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1a1a2e),
                      Color(0xFF16213e),
                      Color(0xFF0f3460),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
                child: const Center(child: Text("No content available.", style: TextStyle(color: Colors.white))),
              );
            }

            // --- GŁÓWNY WIDOK GRY (PO ZAŁADOWANIU DANYCH) ---
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1a1a2e),
                    Color(0xFF16213e),
                    Color(0xFF0f3460),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
              child: Column(
                // Zmieniono Center na Column, aby baner był na dole
                children: [
                  Expanded(
                    // Główna zawartość gry zajmuje dostępną przestrzeń
                    child: Column(
                      // mainAxisAlignment: MainAxisAlignment.center, // Wyśrodkuj elementy w pionie
                      children: <Widget>[
                        gapH16,
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: Sizes.p16),
                          child: Text(
                            'Human-made or AI-generated?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // Lepszy kontrast
                            ),
                          ),
                        ),
                        gapH16,
                        // Wyświetlanie wyniku i mnożnika
                        Column(
                          children: [
                            AnimatedDigitWidget(
                              controller: _controller,
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (boostX > 1)
                              Padding(
                                // Dodaj odstęp dla animacji
                                padding: const EdgeInsets.only(top: Sizes.p8),
                                child: AnimatedPixelFlameCombo(
                                  comboCount: boostX,
                                  size: 60, // Zmniejszono rozmiar
                                ),
                              ),
                          ],
                        ),
                        gapH16,
                        // Kontener na PageView (obraz/muzyka/wideo)
                        Flexible(
                          // Pozwala PageView zająć dostępną przestrzeń
                          child: Padding(
                            // Dodaj padding wokół PageView
                            padding: const EdgeInsets.symmetric(horizontal: Sizes.p16),
                            child: AspectRatio(
                              // Utrzymaj proporcje kontenera
                              aspectRatio: 1.0, // Kwadratowy kontener główny
                              child: PageView.builder(
                                physics: const NeverScrollableScrollPhysics(), // Wyłącz przewijanie gestem
                                itemCount: allListItems.length,
                                controller: pageController, // Użyj poprawnej nazwy kontrolera
                                // onPageChanged: (index) { // Listener jest już dodany w initState
                                // },
                                itemBuilder: (context, index) {
                                  // currentIndex jest aktualizowany w listenerze PageController
                                  // Upewnij się, że indeks jest w granicach
                                  if (index < 0 || index >= allListItems.length) {
                                    return const Center(child: Text("Invalid item index.", style: TextStyle(color: Colors.red)));
                                  }
                                  final item = allListItems[index];
                                  final itemType = item['typ'];
                                  final itemLink = item['link'] as String?;
                                  final itemQuote = item['quote'] as String?;

                                  // print('Building item $index: Type: $itemType, Link: $itemLink');

                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _getHighlightColor(),
                                        width: 5.0,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Stack(
                                        children: [
                                          Container(
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                // --- BUDOWANIE ELEMENTU ZALEŻNIE OD TYPU ---
                                                Builder(
                                                  builder: (context) {
                                                    // --- MUZYKA ---
                                                    if (itemType == 'musick') {
                                                      return Image.asset(
                                                        'lib/logoIcon/headphones.jpg',
                                                        fit: BoxFit.contain,
                                                      );
                                                    }
                                                    // --- CYTATY (jeśli wrócą) ---
                                                    else if (itemType == 'quotes') {
                                                      return Center(
                                                        child: SingleChildScrollView(
                                                          child: Padding(
                                                            padding: const EdgeInsets.all(Sizes.p16),
                                                            child: Text(
                                                              itemQuote ?? 'Quote not available',
                                                              textAlign: TextAlign.center,
                                                              style: const TextStyle(color: Colors.white, fontSize: 18),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    // --- WIDEO ---
                                                    else if (itemType == 'video') {
                                                      // Używamy FutureBuilder do obsługi inicjalizacji
                                                      return FutureBuilder<void>(
                                                        key: ValueKey('video_$index'), // Klucz dla poprawnego zarządzania stanem
                                                        future: _initializeVideoPlayerFuture,
                                                        builder: (context, snapshot) {
                                                          print(
                                                              "FutureBuilder for video $index: ConnectionState=${snapshot.connectionState}, HasError=${snapshot.hasError}, Controller=${_videoController != null}, Initialized=${_videoController?.value.isInitialized}");

                                                          // --- STAN PO ZAKOŃCZENIU FUTURE ---
                                                          if (snapshot.connectionState == ConnectionState.done) {
                                                            // --- BŁĄD INICJALIZACJI ---
                                                            if (snapshot.hasError || _videoController == null || !_videoController!.value.isInitialized) {
                                                              print("FutureBuilder ERROR or controller not ready: ${snapshot.error}");
                                                              return Center(
                                                                child: Column(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                                                    gapH8,
                                                                    Text(_videoController == null ? "Video controller disposed" : "Failed to load video",
                                                                        style: const TextStyle(color: Colors.white70)),
                                                                  ],
                                                                ),
                                                              );
                                                            }
                                                            // --- SUKCES INICJALIZACJI ---
                                                            else {
                                                              // Kontroler jest gotowy, pokaż odtwarzacz
                                                              return SizedBox.expand(
                                                                child: FittedBox(
                                                                  fit: BoxFit.cover,
                                                                  child: SizedBox(
                                                                    width: _videoController!.value.size.width,
                                                                    height: _videoController!.value.size.height,
                                                                    child: VideoPlayer(_videoController!),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          }
                                                          // --- STAN ŁADOWANIA (FUTURE W TRAKCIE) ---
                                                          else {
                                                            return const Center(
                                                              child: CircularProgressIndicator(),
                                                            );
                                                          }
                                                        },
                                                      );
                                                    }
                                                    // --- OBRAZY (domyślny typ) ---
                                                    else {
                                                      if (itemLink != null && itemLink.isNotEmpty) {
                                                        return CachedNetworkImage(
                                                          imageUrl: itemLink,
                                                          fit: BoxFit.cover, // Użyj cover, aby wypełnić kontener
                                                          width: double.infinity,
                                                          height: double.infinity,
                                                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                                          errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.red, size: 48)),
                                                        );
                                                      } else {
                                                        // Obsługa braku linku dla obrazu
                                                        return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 48));
                                                      }
                                                    }
                                                  },
                                                ),

                                                // --- PRZYCISKI I PASKI POSTĘPU (NA WIERZCHU) ---

                                                // Przycisk Play/Pause dla MUZYKI
                                                if (itemType == 'musick')
                                                  Center(
                                                    // Wyśrodkuj przycisk
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        shape: const CircleBorder(),
                                                        padding: const EdgeInsets.all(15),
                                                        backgroundColor: Colors.black54, // Półprzezroczyste tło
                                                      ),
                                                      onPressed: () async {
                                                        if (itemLink == null || itemLink.isEmpty) return;
                                                        if (isPlaying) {
                                                          await player.pause();
                                                        } else {
                                                          try {
                                                            await player.play(UrlSource(itemLink));
                                                            // statusPlayer(); // Listenery są już w initState
                                                          } catch (e) {
                                                            print("Error playing audio: $e");
                                                            // Pokaż błąd użytkownikowi
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error playing audio file.")));
                                                            }
                                                          }
                                                        }
                                                        setState(() {
                                                          isPlaying = !isPlaying;
                                                        });
                                                      },
                                                      child: Icon(
                                                        isPlaying ? Icons.pause : Icons.play_arrow,
                                                        size: 40,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),

                                                // Pasek postępu dla MUZYKI
                                                if (itemType == 'musick')
                                                  Positioned(
                                                    left: Sizes.p16,
                                                    right: Sizes.p16,
                                                    bottom: 10,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withOpacity(0.7), // Lepsza widoczność
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      padding: const EdgeInsets.symmetric(horizontal: Sizes.p12, vertical: Sizes.p8),
                                                      child: ProgressBar(
                                                        progress: position,
                                                        total: duration,
                                                        onSeek: (value) async {
                                                          await player.seek(value);
                                                        },
                                                        barHeight: 8, // Cieńszy pasek
                                                        baseBarColor: Colors.grey[700],
                                                        progressBarColor: Colors.blueAccent,
                                                        bufferedBarColor: Colors.grey[500],
                                                        thumbColor: Colors.blueAccent,
                                                        timeLabelTextStyle: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.white, // Biały tekst
                                                        ),
                                                      ),
                                                    ),
                                                  ),

                                                // Przycisk Play/Pause i Pasek Postępu dla WIDEO
                                                if (itemType == 'video' && _videoController != null && _videoController!.value.isInitialized)

                                                  // Nakładka z przyciskiem i paskiem tylko gdy wideo jest gotowe
                                                  Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      // Przycisk Play/Pause
                                                      Center(
                                                        child: IconButton(
                                                          icon: Icon(
                                                            _isVideoPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                                            size: 60.0, // Większy przycisk
                                                            color: Colors.white.withOpacity(0.8), // Lekko przezroczysty
                                                          ),
                                                          onPressed: () {
                                                            if (_videoController != null && _videoController!.value.isInitialized) {
                                                              setState(() {
                                                                if (_isVideoPlaying) {
                                                                  _videoController!.pause();
                                                                } else {
                                                                  _videoController!.play();
                                                                }
                                                                // _isVideoPlaying jest aktualizowane przez listener
                                                              });
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                      // Pasek postępu
                                                      Positioned(
                                                        left: 10, // Mniejsze marginesy
                                                        right: 10,
                                                        bottom: 10,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Mniejszy padding
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withOpacity(0.7),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: ValueListenableBuilder(
                                                            // Używamy ValueListenableBuilder zamiast polegania na setState z listenera dla paska
                                                            valueListenable: _videoController!,
                                                            builder: (context, VideoPlayerValue value, child) {
                                                              return ProgressBar(
                                                                progress: value.position,
                                                                total: value.duration,
                                                                onSeek: (duration) {
                                                                  _videoController!.seekTo(duration);
                                                                },
                                                                barHeight: 6, // Cieńszy pasek
                                                                baseBarColor: Colors.grey[700],
                                                                progressBarColor: Colors.redAccent, // Inny kolor
                                                                bufferedBarColor: Colors.grey[500],
                                                                thumbColor: Colors.redAccent,
                                                                timeLabelTextStyle: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 10, // Mniejszy tekst czasu
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        // gapH16, // Usunięto dodatkowy odstęp
                      ],
                    ),
                  ),
                  // Przyciski odpowiedzi i baner na dole
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sizes.p16).copyWith(bottom: Sizes.p8), // Mniejszy dolny padding

                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: FilledButton(
                              onPressed: (answer != CurrentAnswer.none || currentHealth <= 0) // Wyłącz przycisk, jeśli już odpowiedziano lub koniec gry
                                  ? null
                                  : () async {
                                      HapticFeedback.mediumImpact();
                                      await processResponse(
                                        categoryWin: (allListItems[currentIndex]['category'] as String?) ?? 'ai',
                                        answer: CurrentAnswer.ai,
                                      );
                                    },
                              style: FilledButton.styleFrom(
                                side: BorderSide(
                                  color: answer == CurrentAnswer.ai
                                      ? Colors.transparent // Brak ramki dla wybranego
                                      : Colors.white,
                                  width: 2,
                                ),

                                backgroundColor: answer == CurrentAnswer.ai
                                    ? ((allListItems[currentIndex]['category'] == 'ai')
                                        ? Colors.green.shade800 // Ciemniejsza zieleń
                                        : Colors.red.shade800) // Ciemniejsza czerwień
                                    : Colors.transparent, // Przezroczyste tło domyślnie
                                foregroundColor: Colors.white, // Kolor tekstu
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'AI',
                                style: TextStyle(
                                  fontSize: 24,
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
                              onPressed: (answer != CurrentAnswer.none || currentHealth <= 0)
                                  ? null
                                  : () async {
                                      HapticFeedback.mediumImpact();
                                      // Zatrzymaj odtwarzacze przed przetworzeniem odpowiedzi
                                      await player.pause(); // Użyj pause zamiast stop, aby zachować pozycję
                                      await _videoController?.pause();
                                      setState(() {
                                        isPlaying = false;
                                        _isVideoPlaying = false;
                                      });

                                      await processResponse(
                                        categoryWin: (allListItems[currentIndex]['category'] ?? 'human').toString(),
                                        answer: CurrentAnswer.human,
                                      );
                                    },
                              style: FilledButton.styleFrom(
                                side: BorderSide(
                                  color: answer == CurrentAnswer.human ? Colors.transparent : Colors.white,
                                  width: 2,
                                ),
                                backgroundColor:
                                    answer == CurrentAnswer.human ? ((allListItems[currentIndex]['category'] ?? 'human') == 'human' ? Colors.green.shade800 : Colors.red.shade800) : Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Human',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  gapH8, // Mniejszy odstęp przed banerem
                  // Baner reklamowy na samym dole
                  if (_banner != null && Constants.adsEnabled)
                    Container(
                      alignment: Alignment.center,
                      width: _banner!.size.width.toDouble(),
                      height: _banner!.size.height.toDouble(),
                      child: AdWidget(ad: _banner!),
                    )
                  else
                    const SizedBox(height: 50), // Placeholder, jeśli nie ma banera
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
