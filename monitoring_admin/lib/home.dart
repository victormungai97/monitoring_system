import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'caregivers.dart';
import 'relatives.dart';
import 'patients.dart';
import 'title.dart';
import 'extras.dart';
import 'login.dart';
import 'urls.dart';

class HomeScreen extends StatefulWidget {
  static const String route = '/home';

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((val) => setState(() => _prefs = val));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTitle(context),
      body: Container(
        width: MediaQuery.of(context).size.width,
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Column(
            children: [
              FlutterLogo(size: 200),
              SizedBox(height: 20),
              Container(
                alignment: Alignment.center,
                child: ListTile(
                  leading: Icon(Icons.elderly, color: Colors.black),
                  title: Text(
                    'Patients',
                    style: GoogleFonts.roboto(fontSize: 20),
                  ),
                  onTap: () => Navigator.of(context).pushNamed(
                    PatientsScreen.route,
                  ),
                ),
                width: 200,
              ),
              SizedBox(height: 20),
              Container(
                alignment: Alignment.center,
                child: ListTile(
                  leading: Icon(Icons.medical_services, color: Colors.black),
                  title: Text(
                    'Caregivers',
                    style: GoogleFonts.roboto(fontSize: 20),
                  ),
                  onTap: () => Navigator.of(context).pushNamed(
                    CaregiversScreen.route,
                  ),
                ),
                width: 200,
              ),
              SizedBox(height: 20),
              Container(
                alignment: Alignment.center,
                child: ListTile(
                  leading: ImageIcon(
                    AssetImage('images/relatives.png'),
                    color: Colors.black,
                  ),
                  title: Text(
                    'Relatives',
                    style: GoogleFonts.roboto(fontSize: 20),
                  ),
                  onTap: () => Navigator.of(context).pushNamed(
                    RelativesScreen.route,
                  ),
                ),
                width: 200,
              ),
              SizedBox(height: 20),
              Container(
                alignment: Alignment.center,
                child: ListTile(
                  leading: Icon(Icons.analytics, color: Colors.black),
                  title: Text(
                    'Analytics',
                    style: GoogleFonts.roboto(fontSize: 20),
                  ),
                  onTap: () => showToast('Still being built', context),
                ),
                width: 200,
              ),
              SizedBox(height: 20),
              Container(
                alignment: Alignment.center,
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.black),
                  title: Text(
                    'Logout',
                    style: GoogleFonts.roboto(fontSize: 20),
                  ),
                  onTap: _logout,
                ),
                width: 200,
              ),
              SizedBox(height: 20),
            ],
            mainAxisAlignment: MainAxisAlignment.center,
          ),
          physics: BouncingScrollPhysics(),
        ),
        color: Colors.white,
        margin: const EdgeInsets.all(8.0),
      ),
      backgroundColor: Color(0xFFEEEEEE),
    );
  }

  void _logout() async {
    try {
      final userID = _prefs.getString('loggedIn_user');
      if (isStringEmpty(userID)) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      showToast("Please wait...", context);
      final token = _prefs.getString('auth_token');
      var refresh = _prefs.getString('refresh_token');
      if (isStringEmpty(token)) {
        logError('LOGOUT ERROR!!', 'Authentication token empty/missing');
        showToast('Unable to logout. Please contact administrator', context);
        return;
      }
      if (isStringEmpty(refresh)) {
        logError('LOGOUT ERROR!!', 'Refresh token empty/missing');
        showToast('Unable to logout. Please contact administrator', context);
        return;
      }
      final response = await http.get(
        Uri.parse('$homeBlueprint/logout/'),
        headers: {
          "content-type": "application/json",
          "Authorization": "Bearer ${await vigenereCipher(token, false)}",
          "Refresh": "Bearer ${await vigenereCipher(refresh, false)}",
          "UniqueID": await getID(),
          "UserID": userID,
        },
      );
      if (response.statusCode < 400) {
        final res = json.decode(response.body);
        final errorCode = res['status'];
        if (errorCode == null) {
          showGenericFlushBar("Error while logging out", context);
          logError("ERROR", "Status code missing");
          return;
        }
        showToast("${res['message']}", context);
        if (errorCode != 0) {
          logError("LOGOUT ERROR", "Errorcode $errorCode");
          return;
        } else {
          _prefs.setString("loggedIn_user", '');
          _prefs.setString('auth_token', '');
          _prefs.setString('refresh_token', '');
          _prefs.setString('login_date', '');
          _prefs.setString('user_role', '');
        }
        Navigator.pushReplacementNamed(context, LoginScreen.route);
      } else {
        final message = json.decode(response.body)['message'];
        if (message == "Signature expired. Please log in again.") {
          final resp = await tokenRefresh(context);
          if (!isStringEmpty(resp)) {
            showGenericFlushBar(resp, context);
            return;
          } else {
            _logout();
          }
        }
        if (message == 'User not logged in' ||
            message == 'Login session not found') {
          _prefs.setString("loggedIn_user", '');
          _prefs.setString('auth_token', '');
          _prefs.setString('refresh_token', '');
          _prefs.setString('login_date', '');
          _prefs.setString('user_role', '');
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          return;
        }
        logError("Status Code:\t${response.statusCode}", "Message:\t$message");
        showToast("Something went wrong. Please try again later", context);
      }
    } catch (err) {
      showToast("Oops! Something went wrong! Please try again later", context);
      print("$err");
    }
  }
}
