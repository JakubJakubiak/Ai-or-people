import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:http/http.dart';

import 'package:flutter/material.dart';
import './ai_Image/linkImage.dart';

// import 'package:queue/queue.dart';
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
        // colorSchemeSeed: const Color(0xff6750a4),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    int randomNumber = Random().nextInt(imageListLink.length);
    final imageList =
        randomNumber.isOdd ? imageListLink[_counter] : imageListLink[_counter];

    ListQueue<String> _imageQueue = ListQueue();
    int _maxQueueSize = 5;

    Future<void> _downloadImage(String imageUrl) async {
      var response = await http.get(imageUrl);
      var imageFile = File('path/to/save/image.jpg');
      await imageFile.writeAsBytes(response.bodyBytes);
      print('Image downloaded: $imageUrl');
    }

    Future<void> _processQueue() async {
      while (_imageQueue.isNotEmpty) {
        var imageUrl = _imageQueue.removeFirst();
        await _downloadImage(imageUrl);
      }
    }

    Future<void> addImageToQueue(String imageUrl) async {
      _imageQueue.addLast(imageUrl);
      if (_imageQueue.length == _maxQueueSize) {
        await _processQueue();
      }
    }

    int currentImageIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'You have pushed the button this many times:',
              ),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headline4,
              ),
              SizedBox(
                // width: MediaQuery.of(context).size.width / 2,
                height: MediaQuery.of(context).size.width,
                child: Image.network(cacheWidth: 1000, imageList, frameBuilder:
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
                }),
              ),
              Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: <Widget>[
                    Expanded(
                        flex: 2,
                        child: FloatingActionButton.extended(
                          onPressed: () async => {_incrementCounter()},
                          backgroundColor: const Color(0xff6750a4),
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
                          backgroundColor: const Color(0xff6750a4),
                          onPressed: () async => {_incrementCounter()},
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
      ),
    );
  }
}

// flutter run -d chrome --web-renderer html
