import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'urls.dart';
import 'title.dart';
import 'extras.dart';
import 'accent_override.dart';

class ResetPasswordScreen extends StatefulWidget {
  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  String phoneNumber = '', message = '';
  final _phoneController = TextEditingController();
  bool _resend = false;

  @override
  BuildContext get context => super.context;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 15.0),
              FlutterLogo(size: 200),
              SizedBox(height: 15.0),
              Text(
                'Request to reset your password',
                style: TextStyle(fontSize: 24, color: Colors.blue[700]),
              ),
              SizedBox(height: 15.0),
              Container(
                height: 270,
                child: ListView(
                  children: [
                    Text(
                      "Provide the user account's confirmed phone number and we will send you a password reset OTP",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
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
                      leading: Icon(Icons.phone_android),
                    ),
                    if (!isStringEmpty(message))
                      Padding(
                        child: Text(
                          message,
                          style: TextStyle(fontSize: 16, color: Colors.brown),
                          textAlign: TextAlign.center,
                        ),
                        padding: const EdgeInsets.fromLTRB(8, 25, 8, 0),
                      ),
                    SizedBox(height: 25.0),
                    ConstrainedBox(
                      child: TextButton(
                        onPressed: _submit,
                        child: Align(
                          child: Text(
                            "Request password reset",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          alignment: Alignment.center,
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: 250,
                        maxHeight: 30,
                      ),
                    ),
                    SizedBox(height: 15.0),
                    if (_resend)
                      GestureDetector(
                        child: Text(
                          "Didn't receive OTP? Resend request",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blue[800],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        onTap: _submit,
                      ),
                  ],
                ),
                margin: const EdgeInsets.all(5.0),
                padding: const EdgeInsets.all(15.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
              ),
            ],
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
          physics: BouncingScrollPhysics(),
        ),
        margin: EdgeInsets.all(5.0),
        color: Colors.white,
        height: MediaQuery.of(context).size.height,
      ),
      appBar: AppTitle(context),
    );
  }

  Future<dynamic> handlePasswordRequest(String phoneNumber) async {
    final response = await http.post(
      Uri.parse('$homeBlueprint/request_password_reset/'),
      headers: {"content-type": "application/json"},
      body: json.encode({"phone_number": phoneNumber}),
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
    if (isStringEmpty(_phoneController.text)) {
      showToast("Please enter the phone number", context);
    } else {
      setState(() {
        message = "Please wait...";
        _resend = false;
      });

      try {
        handlePasswordRequest(_phoneController.text).then((res) {
          if (res is String) {
            setState(() => message = res);
            return;
          }
          final statusCode = res["status"];
          if (statusCode != 0) {
            logError("REQUEST PASSWORD ERROR", "Errorcode $statusCode");
            setState(() => message = "${res['message'] ?? 'Unexpected error'}");
            return;
          }
          setState(() {
            message = "${res['message']}";
            _resend = true;
          });
        });
      } catch (err) {
        setState(() => message = "Something went wrong. Please retry later");
        print("$err");
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
