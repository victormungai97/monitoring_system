import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

import 'urls.dart';
import 'title.dart';
import 'extras.dart';
import 'accent_override.dart';

class OTPScreen extends StatefulWidget {
  @override
  _OTPScreenState createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  FocusNode _focus = FocusNode(), _focus1 = FocusNode();
  bool _obscure = true, _obscure1 = true, _visible = false, _visible1 = false;
  bool _isLoading = false;
  final _otpController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordController1 = TextEditingController();
  String _errorMessage;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {
          _visible = _focus.hasFocus;
          if (!_focus.hasFocus) _obscure = true;
        }));
    _focus1.addListener(() => setState(() {
          _visible1 = _focus1.hasFocus;
          if (!_focus1.hasFocus) _obscure1 = true;
        }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 20),
              FlutterLogo(size: 150),
              SizedBox(height: 20),
              Text(
                'Enter the provided OTP and preferred password to set/reset password',
                style: GoogleFonts.abrilFatface(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              if (!isStringEmpty(_errorMessage))
                Container(
                  margin: EdgeInsets.fromLTRB(10, 0, 10, 20),
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
                leading: Icon(Icons.code, color: Colors.black),
                title: AccentOverride(
                  child: Theme(
                    child: TextField(
                      controller: _otpController,
                      decoration: InputDecoration(
                        labelText: 'OTP Code',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        labelStyle: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        focusColor: Colors.black,
                      ),
                      keyboardType: TextInputType.url,
                      style: TextStyle(color: Colors.black, fontSize: 16.0),
                    ),
                    data: ThemeData(primaryColor: Colors.black),
                  ),
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 25.0),
              ListTile(
                title: AccentOverride(
                  child: TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      labelStyle: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                      focusColor: Colors.black,
                    ),
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: Colors.black, fontSize: 16.0),
                  ),
                ),
                leading: Icon(Icons.phone_android, color: Colors.black),
              ),
              SizedBox(height: 20),
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
                      style: TextStyle(color: Colors.black, fontSize: 16.0),
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
                        onPressed: () => setState(() => _obscure = !_obscure),
                        iconSize: 25,
                      )
                    : null,
              ),
              SizedBox(height: 25),
              ListTile(
                leading: Icon(Icons.lock, color: Colors.black),
                title: AccentOverride(
                  child: Theme(
                    child: TextField(
                      focusNode: _focus1,
                      controller: _passwordController1,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        labelStyle: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        focusColor: Colors.black,
                      ),
                      style: TextStyle(color: Colors.black, fontSize: 16.0),
                      obscureText: _obscure1,
                    ),
                    data: ThemeData(primaryColor: Colors.black),
                  ),
                  color: Colors.white,
                ),
                trailing: _visible1
                    ? IconButton(
                        icon: AnimatedSwitcher(
                          child: _obscure1
                              ? Icon(Icons.visibility)
                              : Icon(Icons.visibility_off),
                          duration: Duration(milliseconds: 2000),
                        ),
                        color: Colors.grey,
                        onPressed: () => setState(() => _obscure1 = !_obscure1),
                        iconSize: 25,
                      )
                    : null,
              ),
              SizedBox(height: 20),
              if (!_isLoading)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    onPrimary: Colors.white,
                    onSurface: Colors.grey,
                    shape: StadiumBorder(),
                    textStyle: GoogleFonts.berkshireSwash(fontSize: 24),
                  ),
                  label: Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('Send'),
                  ),
                  icon: ImageIcon(AssetImage('assets/otp.png'), size: 24),
                  onPressed: _submit,
                )
              else
                Center(child: CircularProgressIndicator()),
              SizedBox(height: 25),
            ],
            mainAxisAlignment: MainAxisAlignment.center,
          ),
          physics: BouncingScrollPhysics(),
        ),
        height: MediaQuery.of(context).size.height,
      ),
      appBar: AppTitle(context),
      backgroundColor: Colors.white,
    );
  }

  Future<dynamic> handleOTPVerification(Map<String, String> values) async {
    final response = await http.post(
      Uri.parse('$homeBlueprint/verify_otp/'),
      headers: {"content-type": "application/json"},
      body: json.encode(values),
    );
    if (response.statusCode < 400) {
      return json.decode(response.body);
    } else {
      final message = json.decode(response.body)['message'];
      logError("Status Code:\t${response.statusCode}", "Message:\t$message");
      return "Something went wrong. Please try again later";
    }
  }

  _submit() async {
    if (!mounted) return;
    try {
      if (isStringEmpty(_otpController.text)) {
        showToast('Enter the OTP code', context);
      } else if (isStringEmpty(_phoneController.text)) {
        showToast('Enter the phone number', context);
      } else if (isStringEmpty(_passwordController.text)) {
        showToast('Enter your password', context);
      } else if (isStringEmpty(_passwordController1.text)) {
        showToast('Enter confirm password', context);
      } else if (_passwordController.text != _passwordController1.text) {
        showToast('Passwords do not match', context);
      } else {
        setState(() => _isLoading = true);

        Map<String, String> values = {
          'otp': _otpController.text,
          'phone_number': _phoneController.text,
          'password': _passwordController.text,
        };
        final res = await handleOTPVerification(values);
        if (res is String) {
          setState(() => _errorMessage = res);
          return;
        }
        setState(() {
          _errorMessage = "${res['message'] ?? 'Unexpected error'}";
        });
        if (res['message'] == 'Success') Navigator.pop(context);
      }
    } catch (ex) {
      print(ex);
      setState(() => _errorMessage = 'Something went wrong. Contact admin');
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _focus.removeListener(() {});
    _focus.dispose();
    _passwordController.dispose();

    _focus1.removeListener(() {});
    _focus1.dispose();
    _passwordController1.dispose();

    _otpController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
