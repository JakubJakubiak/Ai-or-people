# Human or AI?

A mobile game (Flutter) that trains people to tell AI-generated images, videos and music from work made
by humans. Each round shows one item; the player answers **Human** or **AI**, sees the truth and gets a
short tip on what gives AI away.

- Android: <https://play.google.com/store/apps/details?id=inu.night.humanAI>
- Website: <https://web-ai-vs-humna.vercel.app> (repo: `JakubJakubiak/web-ai-vs-humna`)
- Content lists: `JakubJakubiak/jsonList`

## Screenshots

| Video round | Answer and tip | Music round |
|---|---|---|
| <img src="docs/screenshots/video.jpg" width="240" alt="Video round with Human and AI buttons"> | <img src="docs/screenshots/reveal.jpg" width="240" alt="AI-generated image revealed with a tip"> | <img src="docs/screenshots/music.jpg" width="240" alt="Music round with equalizer"> |

| Game over | Settings | How to play |
|---|---|---|
| <img src="docs/screenshots/results.jpg" width="240" alt="Game over with accuracy per media type"> | <img src="docs/screenshots/settings.jpg" width="240" alt="Settings with content type filter"> | <img src="docs/screenshots/how-to-play.jpg" width="240" alt="How to play dialog"> |

## How the game works

- Three lives. A correct answer adds `10 × combo` points and raises the combo; a miss resets it.
- The starting combo grows with the daily streak (`StreakService`).
- After every answer the card shows a verdict stamp and a tip, then the game moves on by itself.
- Settings let the player choose which content to practise: images, videos, music.
- Game over shows the score and accuracy per media type; a rewarded ad restores all lives.

## Content

The app has no backend. It downloads five JSON lists from the `jsonList` repository
(`lib/api/content_repository.dart`):

| File | Content |
|---|---|
| `humnOrAi.json` | images, `{link, op: "ai" \| "human", credit?}` |
| `video_links_ai.json`, `video_links_human.json` | videos, `{url, op}` |
| `tinyncsmusic.json` | human music, `{url, track, artistraw, cover}` |
| `SunoMusicList.json` | AI music, `playlists[].playlist_clips[].clip.audio_url` |

Each list loads on its own, so one broken file only removes that kind of content. For every media type
the deck holds the same number of AI and human items, so the type never gives the answer away. Media that
fails to load is skipped without costing a life. Dead links are cleaned up, and new items proposed, by the
GitHub Actions in `jsonList`.

## Project layout

```
lib/
  main.dart                          app start, Firebase, ads
  api/content_repository.dart        loading and parsing the lists, deck building
  models/game_item.dart              one round: url, type, AI or human
  features/game_screen/
    game_screen.dart                 game state and layout
    tips.dart                        tips shown after each answer
    streak_service.dart              daily streak
    widgets/                         media card, answer bar, effects (combo flame, sparks),
                                     settings, how to play, game over, streak sheet
  utils/app_colors.dart              colours (shared with the website)
test/content_repository_test.dart    parsing and deck tests
```

## Running

```bash
flutter pub get
flutter test
flutter run
```

iOS notes (Flutter 3.44 / Xcode 27):

- Minimum iOS is 15.
- Swift Package Manager is turned off in `pubspec.yaml` because the Firebase and AdMob plugin versions
  used here only support CocoaPods.
- If `pod install` fails with an encoding error, run it with `LANG=en_US.UTF-8`.
- `flutter build ios --simulator` may fail on an architecture check; `flutter run -d <simulator>` works.

Debug builds use Google's test ad units (`lib/modules/admob_service.dart`).
