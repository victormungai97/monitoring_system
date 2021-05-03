import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autocomplete_textfield/autocomplete_textfield.dart';

import 'extras.dart';
import 'title.dart';
import 'home.dart';
import 'urls.dart';
import 'accent_override.dart';
import 'platform/platform.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key key}) : super(key: key);

  static const String route = '/login';

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscure = true, _visible = false, _isLoading = false;
  FocusNode _focus = FocusNode();
  List<String> _addedNames = [];
  String _phoneNumber = '', _errorMessage;
  final _passwordController = TextEditingController();
  SharedPreferences _prefs;
  GlobalKey<AutoCompleteTextFieldState<String>> _key = GlobalKey();

  _phone(String str) => setState(() => _phoneNumber = str);

  @override
  void initState() {
    super.initState();

    _focus.addListener(() => setState(() {
          _visible = _focus.hasFocus;
          if (!_focus.hasFocus) _obscure = true;
        }));

    SharedPreferences.getInstance().then((sharedPreferences) {
      setState(() {
        _prefs = sharedPreferences;
        _addedNames = _prefs.getStringList('users') ?? [];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: !_isLoading
          ? Container(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    FlutterLogo(size: 150),
                    SizedBox(height: 20),
                    if (!isStringEmpty(_errorMessage))
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 10),
                        width: MediaQuery.of(context).size.width - 20,
                        height: 80,
                        alignment: Alignment.center,
                        child: Center(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(fontSize: 16, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(width: 2.0, color: Colors.black),
                          borderRadius: BorderRadius.all(Radius.circular(5.0)),
                        ),
                        padding: EdgeInsets.all(10.0),
                      ),
                    SizedBox(height: 20),
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.black),
                      title: AccentOverride(
                        child: Theme(
                          child: AutoCompleteTextField(
                            key: _key,
                            suggestions: _addedNames,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.black),
                              ),
                              filled: true,
                              labelStyle: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                              fillColor: Colors.transparent,
                            ),
                            style: TextStyle(color: Colors.black, fontSize: 16),
                            submitOnSuggestionTap: true,
                            clearOnSubmit: false,
                            textSubmitted: _phone,
                            textChanged: _phone,
                            itemBuilder: (_, item) => Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(item),
                            ),
                            itemSorter: (a, b) => a.compareTo(b),
                            onFocusChanged: (hasFocus) {},
                            itemFilter: (item, query) => item
                                .toLowerCase()
                                .startsWith(query.toLowerCase()),
                            itemSubmitted: _phone,
                            keyboardType: TextInputType.phone,
                          ),
                          data: ThemeData(primaryColor: Colors.black),
                        ),
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 25),
                    ListTile(
                      leading: Icon(Icons.lock, color: Colors.black),
                      title: AccentOverride(
                        child: Theme(
                          child: TextField(
                            focusNode: _focus,
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.black),
                              ),
                              labelStyle: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                              focusColor: Colors.black,
                            ),
                            style:
                                TextStyle(color: Colors.black, fontSize: 16.0),
                            obscureText: _obscure,
                          ),
                          data: ThemeData(primaryColor: Colors.black),
                        ),
                        color: Colors.white,
                      ),
                      trailing: _visible
                          ? IconButton(
                              icon: AnimatedSwitcher(
                                child: _obscure
                                    ? Icon(Icons.visibility)
                                    : Icon(Icons.visibility_off),
                                duration: Duration(milliseconds: 2000),
                              ),
                              color: Colors.grey,
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              iconSize: 25,
                            )
                          : null,
                    ),
                    SizedBox(height: 20),
                    Container(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          onPrimary: Colors.white,
                          onSurface: Colors.grey,
                          shape: StadiumBorder(),
                          textStyle: GoogleFonts.berkshireSwash(fontSize: 24),
                        ),
                        label: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('Login'),
                        ),
                        icon: Icon(Icons.login),
                        onPressed: _submit,
                      ),
                      padding: EdgeInsets.all(20),
                    ),
                  ],
                  mainAxisAlignment: MainAxisAlignment.center,
                ),
                physics: BouncingScrollPhysics(),
              ),
              color: Colors.white,
              margin: EdgeInsets.all(8.0),
            )
          : Center(child: CircularProgressIndicator()),
      appBar: AppTitle(context),
      backgroundColor: Color(0xFFEEEEEE),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _passwordController.dispose();
  }

  void _submit() async {
    final password = _passwordController.text;
    _passwordController.clear();
    if (isStringEmpty(_phoneNumber)) {
      showToast("Please enter your phone number", context);
    } else if (isStringEmpty(password)) {
      showToast("Please enter your password", context);
    } else {
      showToast('Please wait...', context);
      try {
        setState(() => _isLoading = true);

        var res = await _logIn(password);
        setState(() => _isLoading = false);
        if (!isStringEmpty(res)) setState(() => _errorMessage = res);
      } catch (err) {
        setState(() {
          _errorMessage = "Something went wrong. Please try again later";
          _isLoading = false;
        });
        print("$err");
      }
    }
  }

  Future<String> _logIn(String password) async {
    final pref = await SharedPreferences.getInstance();
    var firebaseToken = pref.getString('firebase_token') ?? '';
    if (!kIsWeb && isStringEmpty(firebaseToken)) {
      logError("FIREBASE TOKEN ERROR!!!", "Firebase token is missing");
      // return "Something went wrong. Please try again later";
    }
    var fone = UserAgent.isAndroid()
        ? 'android'
        : UserAgent.isIOS()
            ? 'ios'
            : '';
    final response = await http.post(
      Uri.parse('$homeBlueprint/login/'),
      headers: {
        "content-type": "application/json",
        "FirebaseToken": firebaseToken,
        "UniqueID": await getID(),
        "Platform": fone,
      },
      body: json.encode({"phone_number": _phoneNumber, "password": password}),
    );
    if (response.statusCode < 400) {
      final res = json.decode(response.body);
      var token = res['auth_token'];
      final message = res["message"];
      var refresh = res['refresh_token'];
      final role = res['role'] ?? '';
      if (isStringEmpty(role)) {
        logError('ERROR', 'Role not provided during login');
        return 'Something went wrong. Contact administrator';
      }
      if (token == null || refresh == null) return "$message";
      List<String> responses = message.split(' ');
      showToast(responses.first, context);
      _prefs.setString("loggedIn_user", responses.last);
      _prefs.setString('auth_token', await vigenereCipher(token));
      _prefs.setString('refresh_token', await vigenereCipher(refresh));
      _prefs.setString('login_date', '${DateTime.now()}');
      _prefs.setString('user_role', role);
      List<String> users = _prefs.getStringList('users') ?? [];
      if (users.isEmpty) {
        users = [_phoneNumber];
      } else {
        if (!users.contains(_phoneNumber)) users.add(responses.last);
      }
      _prefs.setStringList('users', users);
      Navigator.pushReplacementNamed(context, HomeScreen.route);
      return '';
    } else {
      final message = json.decode(response.body)['message'];
      logError("Status Code:\t${response.statusCode}", "Message:\t$message");
      return "Something went wrong. Please try again later";
    }
  }
}
