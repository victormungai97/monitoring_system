/// Define app bar to avoid typing it everywhere

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home.dart';
import 'login.dart';
import 'extras.dart';
import 'constants.dart';

class AppTitle extends AppBar {
  AppTitle(BuildContext buildContext, {List<Widget> actions, bool implyLeading})
      : super(
          iconTheme: IconThemeData(color: Colors.white),
          centerTitle: true,
          title: GestureDetector(
            onTap: () => _tap(buildContext),
            child: Padding(
              child: Text(
                appName,
                style: GoogleFonts.raleway(fontSize: 28),
              ),
              padding: const EdgeInsets.all(8.0),
            ),
          ),
          //backgroundColor: Colors.blue[900],
          elevation: 0.0,
          actions: actions ?? null,
          automaticallyImplyLeading: implyLeading ?? true,
        );

  static _tap(BuildContext context) async {
    String route = LoginScreen.route;
    var u = (await SharedPreferences.getInstance()).getString('loggedIn_user');
    if (!isStringEmpty(u)) route = HomeScreen.route;
    Navigator.popUntil(context, ModalRoute.withName(route));
  }
}
