import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

class HomePageManager {
  final resultNotifier = ValueNotifier<RequestState>(RequestInitial());
  static const urlPrefix =
      'https://raw.githubusercontent.com/JakubJakubiak/jsonList/main/humnOrAi.json';

  Future<void> makeGetRequest() async {
    resultNotifier.value = RequestLoadInProgress();
    final url = Uri.parse('$urlPrefix');
    try {
      Response response = await get(url);
      _handleResponse(response);
    } catch (e) {
      resultNotifier.value = RequestLoadFailure();
    }
  }

  Future<void> makePostRequest() async {
    resultNotifier.value = RequestLoadInProgress();
    final url = Uri.parse('$urlPrefix');
    final headers = {"Content-type": "application/json"};
    final response = await post(url, headers: headers, body: json);
    _handleResponse(response);
  }

  void _handleResponse(Response response) {
    if (response.statusCode >= 400) {
      resultNotifier.value = RequestLoadFailure();
    } else {
      resultNotifier.value = RequestLoadSuccess(response.body);
    }
  }

  void searchData(String searchText) {}
}

class RequestState {
  const RequestState();
}

class RequestInitial extends RequestState {}

class RequestLoadInProgress extends RequestState {}

class RequestLoadSuccess extends RequestState {
  const RequestLoadSuccess(this.body);
  final String body;
}

class RequestLoadFailure extends RequestState {}
