import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'platform/platform.dart';
import 'constants.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  UserAgent.setUpWebview();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    try {
      // Connect to socket
      socket.on('connect', (_) => print('connect'));
    } catch (err) {
      print("Initialization error: $err");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      theme: ThemeData(primarySwatch: Colors.pink),
      onGenerateRoute: RouteGenerator.generateRoute,
      builder: (_, child) => child,
      initialRoute: null,
      routes: routes,
      debugShowCheckedModeBanner: false,
    );
  }

  @override
  void dispose() {
    socket.on('disconnect', (_) => print('disconnected'));
    super.dispose();
  }
}
