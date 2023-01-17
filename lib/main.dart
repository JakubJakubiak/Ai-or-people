import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import './ai_Image/linkImage.dart';

import 'dart:collection';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      checkerboardRasterCacheImages: true,
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
      ),
      home: const MyHomePage(title: 'Human vs Ai?'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  bool answer = false;
  int randomNumber = Random().nextInt(10);
  int _counter = 0;
  List<Map<String, dynamic>> categoryDraw = [];
  late Timer timer;

  void _incrementCounter() async {
    setState(() {
      _counter++;
    });
  }

  loadImages() async {
    if (categoryDraw.isEmpty) {
      await Future.forEach(imageListLink, (link) async {
        categoryDraw.add({'link': link, 'category': 'ai'});
      });
      await Future.forEach(imageGirls, (link) async {
        categoryDraw.add({'link': link, 'category': 'human'});
      });
    }
    setState(() {
      categoryDraw;
    });
  }

  randomNumbers() {
    randomNumber = Random().nextInt(categoryDraw.length);
    categoryDraw.remove(categoryDraw[randomNumber]);
  }

  trueOdFalse(context, {required String categoryWin}) async {
    if (categoryWin == categoryDraw[randomNumber]['category'] &&
        answer == false) _incrementCounter();

    (answer == false)
        ? timer = Timer(const Duration(milliseconds: 600), () {
            setState(() {
              answer = false;
              randomNumbers();
            });
          })
        : null;

    setState(() {
      answer = !answer;
      if (answer == false) {
        randomNumbers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    loadImages();
    String images = categoryDraw[randomNumber]['link'];

    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Guess which image was made by human and which by ai?',
                ),
                Text(
                  '$_counter',
                  style: Theme.of(context).textTheme.headline4,
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.width,
                  child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> aniamtion) {
                        return ScaleTransition(scale: aniamtion, child: child);
                      },
                      child: Image.network(
                          cacheWidth: 1000,
                          images,
                          key: ValueKey<String>('$randomNumber'),
                          fit: BoxFit.cover, frameBuilder:
                              (context, child, frame, wasSynchronouslyLoaded) {
                        return child;
                      }, loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        } else {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                      })),
                ),
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: <Widget>[
                      Expanded(
                          flex: 2,
                          child: FloatingActionButton.extended(
                            onPressed: () async => {
                              HapticFeedback.mediumImpact(),
                              trueOdFalse(context, categoryWin: 'ai'),
                            },
                            backgroundColor: answer == true
                                ? categoryDraw[randomNumber]['category'] == 'ai'
                                    ? const Color.fromARGB(255, 41, 95, 43)
                                    : const Color.fromARGB(255, 129, 42, 42)
                                : const Color(0xff6750a4),
                            label: Text('AI',
                                maxLines: 10,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 30,
                                  color: Colors.grey[300],
                                )),
                          )),
                      const Padding(padding: EdgeInsets.all(5)),
                      Expanded(
                          flex: 2,
                          child: FloatingActionButton.extended(
                            onPressed: () async => {
                              HapticFeedback.mediumImpact(),
                              trueOdFalse(context, categoryWin: 'human'),
                            },
                            backgroundColor: answer == true
                                ? categoryDraw[randomNumber]['category'] ==
                                        'human'
                                    ? const Color.fromARGB(255, 41, 95, 43)
                                    : const Color.fromARGB(255, 129, 42, 42)
                                : const Color(0xff6750a4),
                            label: Text('Human',
                                maxLines: 10,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 30,
                                  color: Colors.grey[300],
                                )),
                          ))
                    ]))
              ]),
        ));
  }
}
