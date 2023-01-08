import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart';

import 'package:flutter/material.dart';
import './ai_Image/linkImage.dart';

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
    final odp =
        randomNumber.isOdd ? imageListLink[_counter] : imageListLink[_counter];

    final Future<String> _getImages = Future<String>.delayed(
      const Duration(seconds: 2),
      () => 'Data Loaded',
    );

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
                child: Image.network(cacheWidth: 1000, odp, frameBuilder:
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
