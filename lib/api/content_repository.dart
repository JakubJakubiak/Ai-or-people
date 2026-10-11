import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:humanai/models/game_item.dart';

/// Loads the link lists from the jsonList repo and turns them into [GameItem]s.
///
/// Every list is fetched on its own, so one broken file only removes that
/// kind of content instead of blocking the whole game.
class ContentRepository {
  ContentRepository({http.Client? client}) : _client = client ?? http.Client();

  static const _base = 'https://raw.githubusercontent.com/JakubJakubiak/jsonList/main';
  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final resultNotifier = ValueNotifier<RequestState>(const RequestInitial());

  Future<void> load() async {
    resultNotifier.value = const RequestLoadInProgress();
    final lists = await Future.wait([
      _fetch('humnOrAi.json', parseImages),
      _fetch('video_links_ai.json', (j) => parseVideos(j, defaultAi: true)),
      _fetch('video_links_human.json', (j) => parseVideos(j, defaultAi: false)),
      _fetch('tinyncsmusic.json', parseHumanMusic),
      _fetch('SunoMusicList.json', parseAiMusic),
    ]);
    final items = lists.expand((l) => l).toList();
    resultNotifier.value = items.isEmpty ? const RequestLoadFailure() : RequestLoadSuccess(items);
  }

  Future<List<GameItem>> _fetch(String file, List<GameItem> Function(dynamic json) parse) async {
    try {
      final response = await _client.get(Uri.parse('$_base/$file')).timeout(_timeout);
      if (response.statusCode != 200) return const [];
      return parse(jsonDecode(utf8.decode(response.bodyBytes)));
    } catch (e) {
      debugPrint('Could not load $file: $e');
      return const [];
    }
  }

  static String? _url(dynamic value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value.trim());
    return (uri != null && uri.hasScheme && uri.host.isNotEmpty) ? value.trim() : null;
  }

  static String? _text(dynamic value) => (value is String && value.trim().isNotEmpty) ? value.trim() : null;

  static List<GameItem> parseImages(dynamic json) {
    final list = (json is Map ? json['humanOrAi'] : json) as List<dynamic>? ?? const [];
    return [
      for (final e in list.whereType<Map<dynamic, dynamic>>())
        // Older entries use "link", some newer ones were saved as "url".
        if (_url(e['link'] ?? e['url']) case final url?)
          if (e['op'] == 'ai' || e['op'] == 'human')
            GameItem(url: url, isAi: e['op'] == 'ai', type: MediaType.image, credit: _text(e['credit'])),
    ];
  }

  static List<GameItem> parseVideos(dynamic json, {required bool defaultAi}) {
    final list = json as List<dynamic>? ?? const [];
    return [
      for (final e in list.whereType<Map<dynamic, dynamic>>())
        if (_url(e['url'] ?? e['link']) case final url?)
          GameItem(
            url: url,
            isAi: e['op'] == null ? defaultAi : e['op'] == 'ai',
            type: MediaType.video,
            credit: _text(e['credit']),
          ),
    ];
  }

  static List<GameItem> parseHumanMusic(dynamic json) {
    final list = json as List<dynamic>? ?? const [];
    return [
      for (final e in list.whereType<Map<dynamic, dynamic>>())
        if (_url(e['url']) case final url?)
          GameItem(
            url: url,
            isAi: false,
            type: MediaType.music,
            title: _text(e['track']),
            artist: _text(e['artistraw']),
            cover: _url(e['cover']),
            credit: _text(e['credit']),
          ),
    ];
  }

  static List<GameItem> parseAiMusic(dynamic json) {
    final playlists = (json is Map ? json['playlists'] : null) as List<dynamic>? ?? const [];
    final seen = <String>{};
    final items = <GameItem>[];
    for (final playlist in playlists.whereType<Map<dynamic, dynamic>>()) {
      for (final entry in (playlist['playlist_clips'] as List<dynamic>? ?? const []).whereType<Map<dynamic, dynamic>>()) {
        final clip = entry['clip'];
        if (clip is! Map) continue;
        final url = _url(clip['audio_url']);
        if (url == null || !seen.add(url)) continue;
        items.add(GameItem(
          url: url,
          isAi: true,
          type: MediaType.music,
          title: _text(clip['title']),
          artist: _text(clip['display_name']),
          cover: _url(clip['image_url']),
          credit: 'Generated with Suno',
        ));
      }
    }
    return items;
  }

  /// Builds a shuffled deck where, for every media type, half of the items are
  /// AI and half are human. Without this the type alone gives the answer away
  /// (e.g. three times more AI videos than human ones).
  static List<GameItem> buildDeck(Iterable<GameItem> items, {Set<MediaType>? types, Random? random}) {
    final rng = random ?? Random();
    final deck = <GameItem>[];
    for (final type in types ?? MediaType.values.toSet()) {
      final ai = items.where((i) => i.type == type && i.isAi).toList()..shuffle(rng);
      final human = items.where((i) => i.type == type && !i.isAi).toList()..shuffle(rng);
      final n = min(ai.length, human.length);
      deck
        ..addAll(ai.take(n))
        ..addAll(human.take(n));
    }
    return deck..shuffle(rng);
  }
}

sealed class RequestState {
  const RequestState();
}

class RequestInitial extends RequestState {
  const RequestInitial();
}

class RequestLoadInProgress extends RequestState {
  const RequestLoadInProgress();
}

class RequestLoadSuccess extends RequestState {
  const RequestLoadSuccess(this.items);
  final List<GameItem> items;
}

class RequestLoadFailure extends RequestState {
  const RequestLoadFailure();
}
