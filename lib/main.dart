import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
              // Image(),
              Row(children: <Widget>[
                Expanded(
                    flex: 2,
                    child: FloatingActionButton.extended(
                      onPressed: () async => {},
                      label: Text('1',
                          maxLines: 10,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 30,
                            color: Colors.grey[300],
                          )),
                    )),
                Expanded(
                    flex: 2,
                    child: FloatingActionButton.extended(
                      onPressed: () async => {_incrementCounter()},
                      label: Text('2',
                          maxLines: 10,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 30,
                            color: Colors.grey[300],
                          )),
                    ))
              ])
            ]),
      ),
    );
  }
}
