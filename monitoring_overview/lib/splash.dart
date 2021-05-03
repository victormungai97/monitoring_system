import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monitoring_overview/extras.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home.dart';
import 'login.dart';
import 'constants.dart';
import 'routes.dart' show SimpleRoute;

class SplashScreen extends StatefulWidget {
  /// Redirect to here
  static Route<dynamic> route() {
    return SimpleRoute(
      name: '/',
      title: appName,
      builder: (_) => SplashScreen(),
    );
  }

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 1000), _fetchSavedUsers);
  }

  /// Check for any previous users and if they are previously logged in
  _fetchSavedUsers() async {
    try {
      final _prefs = await SharedPreferences.getInstance();
      String user = _prefs.getString('loggedIn_user') ?? '';
      if (!isStringEmpty(user)) {
        Navigator.pushReplacementNamed(context, HomeScreen.route);
      } else {
        Navigator.of(context).pushReplacementNamed(LoginScreen.route);
      }
    } on Exception catch (err) {
      print("SPLASH SCREEN ERROR: $err");
      Navigator.of(context).pushReplacementNamed(LoginScreen.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              FlutterLogo(size: 200),
              SizedBox(height: 25.0),
              Text(
                appName,
                style: GoogleFonts.lobsterTwo(
                  fontSize: 36,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 15.0),
              CircularProgressIndicator(),
            ],
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
          ),
        ),
      ),
    );
  }
}
