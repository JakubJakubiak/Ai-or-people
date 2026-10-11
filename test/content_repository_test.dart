import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:humanai/api/content_repository.dart';
import 'package:humanai/features/game_screen/tips.dart';
import 'package:humanai/models/game_item.dart';

void main() {
  group('parseImages', () {
    test('reads both "link" and legacy "url" entries', () {
      final items = ContentRepository.parseImages({
        'humanOrAi': [
          {'link': 'https://example.com/a.jpg', 'op': 'human'},
          {'url': 'https://example.com/b.webp', 'op': 'ai', 'new': '09.04.2025'},
        ],
      });
      expect(items, hasLength(2));
      expect(items[0].isAi, isFalse);
      expect(items[1].isAi, isTrue);
      expect(items[1].url, 'https://example.com/b.webp');
      expect(items.every((i) => i.type == MediaType.image), isTrue);
    });

    test('drops entries without a usable link or label', () {
      final items = ContentRepository.parseImages({
        'humanOrAi': [
          {'op': 'ai'},
          {'link': 'not a url', 'op': 'ai'},
          {'link': 'https://example.com/c.jpg'},
          {'link': 'https://example.com/d.jpg', 'op': 'human', 'credit': 'Jane · CC BY-SA 4.0'},
          'garbage',
        ],
      });
      expect(items, hasLength(1));
      expect(items.single.credit, 'Jane · CC BY-SA 4.0');
    });

    test('survives a completely unexpected shape', () {
      expect(ContentRepository.parseImages({'other': 1}), isEmpty);
    });
  });

  test('parseVideos uses the list default when "op" is missing', () {
    final items = ContentRepository.parseVideos(
      [
        {'url': 'https://example.com/1.mp4'},
        {'url': 'https://example.com/2.mp4', 'op': 'human'},
      ],
      defaultAi: true,
    );
    expect(items.map((i) => i.isAi), [true, false]);
  });

  test('parseAiMusic flattens playlists and removes duplicates', () {
    final clip = {
      'clip': {'audio_url': 'https://cdn.example.com/x.mp4', 'title: ': 'x', 'title': 'Song', 'display_name': 'someone'},
    };
    final items = ContentRepository.parseAiMusic({
      'playlists': [
        {
          'playlist_clips': [
            clip,
            {
              'clip': {'audio_url': 'https://cdn.example.com/y.mp4'},
            },
          ],
        },
        {
          'playlist_clips': [clip, <String, dynamic>{}],
        },
      ],
    });
    expect(items, hasLength(2));
    expect(items.first.title, 'Song');
    expect(items.every((i) => i.isAi && i.type == MediaType.music), isTrue);
  });

  test('parseHumanMusic keeps track details for the reveal', () {
    final items = ContentRepository.parseHumanMusic([
      {'url': 'https://example.com/t.mp3', 'track': 'Royalty', 'artistraw': 'Egzod', 'cover': null},
    ]);
    expect(items.single.title, 'Royalty');
    expect(items.single.artist, 'Egzod');
    expect(items.single.cover, isNull);
    expect(items.single.isAi, isFalse);
  });

  group('buildDeck', () {
    GameItem item(MediaType type, {required bool ai, required int n}) =>
        GameItem(url: 'https://example.com/${type.name}-$ai-$n', isAi: ai, type: type);

    final items = [
      for (var n = 0; n < 30; n++) item(MediaType.video, ai: true, n: n),
      for (var n = 0; n < 10; n++) item(MediaType.video, ai: false, n: n),
      for (var n = 0; n < 5; n++) item(MediaType.image, ai: true, n: n),
      for (var n = 0; n < 50; n++) item(MediaType.image, ai: false, n: n),
      for (var n = 0; n < 8; n++) item(MediaType.music, ai: false, n: n),
    ];

    test('is half AI and half human for every media type', () {
      final deck = ContentRepository.buildDeck(items, random: Random(1));
      for (final type in MediaType.values) {
        final ofType = deck.where((i) => i.type == type);
        expect(ofType.where((i) => i.isAi).length, ofType.where((i) => !i.isAi).length, reason: type.name);
      }
      expect(deck.where((i) => i.type == MediaType.video), hasLength(20));
      expect(deck.where((i) => i.type == MediaType.image), hasLength(10));
      // Music has no AI tracks here, so it would always be "human": leave it out.
      expect(deck.where((i) => i.type == MediaType.music), isEmpty);
    });

    test('respects the selected types and never repeats an item', () {
      final deck = ContentRepository.buildDeck(items, types: {MediaType.image}, random: Random(2));
      expect(deck.every((i) => i.type == MediaType.image), isTrue);
      expect(deck.map((i) => i.url).toSet(), hasLength(deck.length));
    });
  });

  test('there is a tip for every kind of item', () {
    for (final type in MediaType.values) {
      for (final ai in [true, false]) {
        expect(Tips.forItem(GameItem(url: 'https://example.com', isAi: ai, type: type)), isNotEmpty);
      }
    }
  });
}
