import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flushbar/flushbar.dart';
import 'package:http/http.dart' as http;
import 'package:monitoring_admin/urls.dart';
import 'package:shared_preferences/shared_preferences.dart';

showToast(String message, BuildContext context) {
  Navigator.of(context).overlay.insert(
        OverlayEntry(builder: (_) => Toast(message: message)),
      );
}

/// This widget will create an overlay for showing a toast

class Toast extends StatefulWidget {
  final String message;

  Toast({@required this.message});

  @override
  State<StatefulWidget> createState() => _ToastState();
}

class _ToastState extends State<Toast> with SingleTickerProviderStateMixin {
  AnimationController controller;
  Animation<Offset> position;
  Timer timer;
  bool visible = true;

  @override
  void initState() {
    super.initState();

    controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 0));
    position = Tween<Offset>(begin: Offset(0.0, -4.0), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: controller, curve: Curves.bounceInOut));

    controller.forward();
    timer = Timer(Duration(milliseconds: 1500), () {
      setState(() => visible = false);
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: visible
          ? Material(
              color: Colors.transparent,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 20.0),
                  child: SlideTransition(
                    position: position,
                    child: Container(
                      width: 500.0,
                      height: 50.0,
                      decoration: ShapeDecoration(
                        color: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.message,
                          style: TextStyle(color: Colors.white, fontSize: 16.0),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Container(),
    );
  }
}

/// This will print errors to console

logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

/// Confirm if string is empty

bool isStringEmpty(String str) => str == null || str == '' || str.isEmpty;

/// Retrieve the unique identifier for the installation

Future<String> getID() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs == null) return 'general';
    var deviceID = prefs.getString('device_id') ?? '';
    if (isStringEmpty(deviceID)) {
      deviceID = '${DateTime.now().microsecondsSinceEpoch}';
      prefs.setString('device_id', deviceID);
    }
    return deviceID;
  } catch (err) {
    print(err);
    return 'general';
  }
}

/// Capitalize any string

String capitalize(String s) => s[0].toUpperCase() + s.substring(1);

/// Open [AlertDialog] for showing requests for location permission and GPS etc
Future<dynamic> showAlertDialog(
  BuildContext context, {
  String title,
  Widget child,
  String message,
  bool barrierDismissible = true,
  List<Widget> actions = const [],
}) async {
  return await showDialog(
    context: context,
    builder: (BuildContext buildContext) {
      return AlertDialog(
        title: Text(title ?? ''),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: child ?? Text(message ?? 'No message'),
        actions: actions == null || actions.isEmpty
            ? [
                // usually buttons at the bottom of the dialog
                TextButton(
                  child: Text("CANCEL"),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text("ACCEPT"),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ]
            : actions,
        elevation: 0.0,
        backgroundColor: Colors.white,
      );
    },
    barrierDismissible: barrierDismissible,
  );
}

/// Check Debug Mode
class DebugMode {
  static bool get isInDebugMode {
    bool inDebugMode = false;
    assert(inDebugMode = true);
    return inDebugMode;
  }
}

enum SnackbarDuration {
  SHORT,
  LONG,
}

/// Show a SnackBar to user

void showGenericFlushBar(
  String message,
  BuildContext context, {
  String title,
  SnackbarDuration duration = SnackbarDuration.SHORT,
  Widget icon,
  TextButton mainButton,
}) {
  int timeInMilSecs = 0;
  switch (duration) {
    case SnackbarDuration.SHORT:
      timeInMilSecs = 1500;
      break;
    case SnackbarDuration.LONG:
      timeInMilSecs = 2750;
      break;
    default:
      timeInMilSecs = 0;
      break;
  }
  Flushbar(
    title: title,
    message: message,
    duration: Duration(milliseconds: timeInMilSecs),
    icon: icon,
    mainButton: mainButton,
  )..show(context);
}

/// Generate a cryptographically random string

String createCryptoRandomString([int length = 32]) {
  final Random random = Random.secure();
  var values = List<int>.generate(length, (i) => random.nextInt(256));
  return base64Url.encode(values);
}

int mod(int val, int mod) => (val % mod + mod) % mod;

/// Implement Caesar Cipher algorithm for encrypting text like password and JWTs

Future<String> vigenereCipher(String text, [bool isEncrypt = true]) async {
  try {
    isEncrypt = isEncrypt ?? true;
    return isEncrypt ? railfenceEncrypt(text, 64) : railfenceDecrypt(text, 64);
  } on Exception catch (ex) {
    logError("VIGENERE CIPHER ERROR", "$ex");
    return "";
  }
}

String railfenceEncrypt(String text, int key) {
  int row = key, col = text.length, x = 0, y = 0;
  String result = '';
  bool dir = false;
  var matrix = List.generate(row, (i) => List.filled(col, ''));
  for (var i = 0; i < text.length; i++) {
    if (x == 0 || x == row - 1) dir = !dir;
    matrix[x][y++] = text[i];
    dir ? x++ : x--;
  }
  for (var i = 0; i < row; i++) {
    for (var j = 0; j < col; j++) {
      if (matrix[i][j] != null) result += matrix[i][j];
    }
  }
  return result;
}

String railfenceDecrypt(String text, int key) {
  String result = '';
  int row = 0, col = 0, index = 0;
  bool dir;
  var matrix = List.generate(key, (i) => List.filled(text.length, ''));

  for (var i = 0; i < text.length; i++) {
    if (row == 0) dir = true;
    if (row == key - 1) dir = false;
    matrix[row][col++] = '*';
    dir ? row++ : row--;
  }

  for (var i = 0; i < key; i++) {
    for (var j = 0; j < text.length; j++) {
      if (matrix[i][j] == '*' && index < text.length)
        matrix[i][j] = text[index++];
    }
  }

  row = 0;
  col = 0;

  for (var i = 0; i < text.length; i++) {
    if (row == 0) dir = true;
    if (row == key - 1) dir = false;
    if (matrix[row][col] != '*') result += matrix[row][col++];
    dir ? row++ : row--;
  }

  return result;
}

/// Handle token refresh

Future<dynamic> _handleTokenRefresh() async {
  final prefs = await SharedPreferences.getInstance();
  final userID = prefs.getString('loggedIn_user');
  if (isStringEmpty(userID)) return "No user provided";
  var refresh = prefs.getString('refresh_token');
  if (isStringEmpty(refresh)) {
    logError('LOGOUT ERROR!!', 'Refresh token empty/missing');
    return 'Unable to logout. Please contact administrator';
  }
  final response = await http.get(
    Uri.parse('$homeBlueprint/token/refresh/'),
    headers: {
      "content-type": "application/json",
      "Refresh": "Bearer ${await vigenereCipher(refresh, false)}",
      "UniqueID": await getID(),
      "UserID": userID,
    },
  );
  if (response.statusCode < 400) {
    return json.decode(response.body);
  } else {
    final message = json.decode(response.body)['message'];
    logError("Status Code:\t${response.statusCode}", "Message:\t$message");
    return "Something went wrong. Please try again later";
  }
}

/// Handle token refresh

Future<String> tokenRefresh(BuildContext context) async {
  try {
    var res = await _handleTokenRefresh();
    showToast("Please wait...", context);
    if (res is String) {
      logError("REFRESH ERROR!!", "Message:\t$res");
      return "Something went wrong. Please try again later";
    } else if (!(res is Map)) {
      logError("REFRESH ERROR!!", "Message:\t$res");
      return "Something went wrong. Please try again later";
    } else {
      final token = res['auth_token'];
      if (isStringEmpty(token)) {
        logError("REFRESH ERROR", "Token missing");
        return "Something went wrong. Please try again later";
      } else {
        final _prefs = await SharedPreferences.getInstance();
        _prefs.setString('auth_token', await vigenereCipher(token));
        _prefs.setString('login_date', '${DateTime.now()}');
        return "";
      }
    }
  } catch (err) {
    print("$err");
    return "Oops! Something went wrong! Please try again later";
  }
}
