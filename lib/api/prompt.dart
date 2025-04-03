import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

class HomePageManager {
  final resultNotifier = ValueNotifier<RequestState>(RequestInitial());
  static const urlPrefix = 'https://raw.githubusercontent.com/JakubJakubiak/jsonList/main/humnOrAi.json';
  static const urlMusickHuman = 'https://raw.githubusercontent.com/JakubJakubiak/jsonList/main/tinyncsmusic.json';
  static const urlMusickAi = 'https://raw.githubusercontent.com/JakubJakubiak/jsonList/main/SunoMusicList.json';
  static const videoLinksAi = 'https://raw.githubusercontent.com/JakubJakubiak/jsonList/refs/heads/main/video_links_ai.json';

  // static const quotesHumanUrl =
  //     'https://raw.githubusercontent.com/JakubJakubiak/jsonList/main/quotes.json';
  // static const quotesAiUrl =
  //     'https://raw.githubusercontent.com/JakubJakubiak/jsonList/main/fejkQuotes.json';

  Future<void> makeGetRequest() async {
    resultNotifier.value = RequestLoadInProgress();
    final uriPrefix = Uri.parse(urlPrefix);
    final uriMusickHuman = Uri.parse(urlMusickHuman);
    final uriMusickAi = Uri.parse(urlMusickAi);
    final urivideoLinksAi = Uri.parse(videoLinksAi);
    // final uriQuotesHuman = Uri.parse(quotesHumanUrl);
    // final uriQuotesAi = Uri.parse(quotesAiUrl);

    try {
      final responses = await Future.wait([
        get(uriPrefix),
        get(uriMusickHuman),
        get(uriMusickAi),
        get(urivideoLinksAi),
        // get(uriQuotesHuman),
        // get(uriQuotesAi),
      ]);

      _handleResponses(
        responses[0],
        responses[1],
        responses[2],
        responses[3],
      );
    } catch (e) {
      resultNotifier.value = RequestLoadFailure();
    }
  }

  void _handleResponses(
    Response response,
    Response responseMusick,
    Response responseMusickAi,
    Response responsvideoLinksAi,
    // Response quotesHuman,
    // Response quotesAi,
  ) {
    // if (response.statusCode >= 400 ||
    //     responseMusick.statusCode >= 400 ||
    //     responseMusickAi.statusCode >= 400||
    //     quotesHuman.statusCode >= 400||
    //     quotesAi.statusCode >= 400
    //     )
    if (response.statusCode >= 400 || responseMusick.statusCode >= 400 || responseMusickAi.statusCode >= 400 || responsvideoLinksAi.statusCode >= 400) {
      resultNotifier.value = RequestLoadFailure();
    } else {
      // final decodedVideoLinks = jsonDecode(responsvideoLinksAi.body);
      final data = {
        'humnOrAi': jsonDecode(response.body),
        'tinyncsmusic': jsonDecode(responseMusick.body),
        'musicAi': jsonDecode(responseMusickAi.body),
        'videoLinksAi': jsonDecode(responsvideoLinksAi.body),
        // 'videoAi': jsonDecode(responseMusickAi.body),
        // 'videoHuman': jsonDecode(responseMusickAi.body),
        // 'quotesHuman': jsonDecode(quotesHuman.body),
        // 'quotesAi': jsonDecode(quotesAi.body),
      };

      // print('DECODED videoLinksAi Data: ${data['videoLinksAi']}');

      resultNotifier.value = RequestLoadSuccess(data);
    }
  }
}

class RequestState {
  const RequestState();
}

class RequestInitial extends RequestState {}

class RequestLoadInProgress extends RequestState {}

class RequestLoadSuccess extends RequestState {
  const RequestLoadSuccess(this.data);
  final Map<String, dynamic> data;
}

class RequestLoadFailure extends RequestState {}
