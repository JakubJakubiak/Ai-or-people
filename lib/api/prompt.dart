import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

class HomePageManager {
  final resultNotifier = ValueNotifier<RequestState>(RequestInitial());
  static const urlPrefix =
      'https://raw.githubusercontent.com/JakubJakubiak/jsonList/main/humnOrAi.json';
  static const urlMusickHuman =
      'https://raw.githubusercontent.com/JakubJakubiak/jsonList/main/tinyncsmusic.json';
  static const urlMusickAi =
      'https://raw.githubusercontent.com/JakubJakubiak/jsonList/main/SunoMusicList.json';

  Future<void> makeGetRequest() async {
    resultNotifier.value = RequestLoadInProgress();
    final uriPrefix = Uri.parse(urlPrefix);
    final uriMusickHuman = Uri.parse(urlMusickHuman);
    final uriMusickAi = Uri.parse(urlMusickAi);

    try {
      final responses = await Future.wait([
        get(uriPrefix),
        get(uriMusickHuman),
        get(uriMusickAi),
      ]);

      _handleResponses(responses[0], responses[1], responses[2]);
    } catch (e) {
      resultNotifier.value = RequestLoadFailure();
    }
  }

  void _handleResponses(
    Response response,
    Response responseMusick,
    Response responseMusickAi,
  ) {
    if (response.statusCode >= 400 ||
        responseMusick.statusCode >= 400 ||
        responseMusickAi.statusCode >= 400) {
      resultNotifier.value = RequestLoadFailure();
    } else {
      final data = {
        'humnOrAi': jsonDecode(response.body),
        'tinyncsmusic': jsonDecode(responseMusick.body),
        'musicAi': jsonDecode(responseMusickAi.body),
      };
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
