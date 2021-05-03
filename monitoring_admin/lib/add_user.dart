import 'dart:convert';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'urls.dart';
import 'extras.dart';
import 'title.dart';
import 'models/users.dart';
import 'fancy_button.dart';
import 'accent_override.dart';
import 'platform/platform.dart';

class AddUserScreen extends StatefulWidget {
  final String role;

  AddUserScreen({this.role = ''});

  static const String route = '/add_user';

  @override
  _AddUserScreenState createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  String _role, _errorMessage = '', _gender;
  User _caregiver, _relative;
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  final _residenceController = TextEditingController();

  List<User> _caregivers = [], _relatives = [];

  // User profile picture
  Image _profilePicture;
  bool _loaded = false;
  String _profileName = '', _profilePath;

  // User ID picture, in case of caregiver
  Image _idPicture;
  String _idPicName = '', _idPicPath;

  SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _role = widget.role ?? '';

    SharedPreferences.getInstance().then((val) {
      setState(() => _prefs = val);
      if (_role == 'patient') _getCaregivers().then((value) => _getRelatives());
    });
  }

  Future<dynamic> _getCaregivers() async {
    if (!mounted) return;
    try {
      final userID = _prefs.getString('loggedIn_user');
      final token = _prefs.getString('auth_token');
      var userRoles = _prefs.getString('user_role');
      var resp = await http.get(
        Uri.parse('$adminBlueprint/get/?role=caregiver'),
        headers: {
          'Authorization': "Bearer $token",
          'UserID': "$userID",
          'UniqueID': await getID(),
          'Role': userRoles,
        },
      );
      final result = json.decode(resp.body)['message'];
      if (resp.statusCode >= 400) {
        logError('LOADING CAREGIVERS ERROR', '${resp.statusCode}');
        setState(() => _errorMessage = 'Unable to load caregivers');
      } else {
        if (result is String) {
          setState(() => _errorMessage = result);
        } else if (result is List) {
          result.forEach((element) {
            final user = User.fromMap(element);
            setState(() => _caregivers.add(user));
          });
        }
      }
    } catch (ex) {
      print(ex);
      setState(() => _errorMessage = 'Unable to load caregivers');
    }
  }

  Future<dynamic> _getRelatives() async {
    if (!mounted) return;
    try {
      final userID = _prefs.getString('loggedIn_user');
      final token = _prefs.getString('auth_token');
      var userRoles = _prefs.getString('user_role');
      var resp = await http.get(
        Uri.parse('$adminBlueprint/get/?role=relative'),
        headers: {
          'Authorization': "Bearer $token",
          'UserID': "$userID",
          'UniqueID': await getID(),
          'Role': userRoles,
        },
      );
      final result = json.decode(resp.body)['message'];
      if (resp.statusCode >= 400) {
        logError('LOADING RELATIVES ERROR', '${resp.statusCode}');
        setState(() => _errorMessage = 'Unable to load relatives');
      } else {
        if (result is String) {
          setState(() => _errorMessage = result);
        } else if (result is List) {
          result.forEach((element) {
            final user = User.fromMap(element);
            setState(() => _relatives.add(user));
          });
        }
      }
    } catch (ex) {
      print(ex);
      setState(() => _errorMessage = 'Unable to load relatives');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTitle(context),
      body: Container(
        width: MediaQuery.of(context).size.width,
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => _showPicker(tag: 'profile'),
                  child: CircleAvatar(
                    radius: 100,
                    child: !_loaded
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.camera, color: Colors.black),
                            width: 180,
                            height: 180,
                          )
                        : _profilePicture,
                    backgroundColor: Colors.black,
                  ),
                ),
              ),
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
                      style: TextStyle(fontSize: 16.0, color: Colors.black),
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
              Padding(
                child: ListTile(
                  title: AccentOverride(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Official Names',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                      ),
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                    ),
                    color: Colors.grey,
                  ),
                  leading: Icon(Icons.person, color: Colors.black),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
              ),
              Padding(
                child: ListTile(
                  title: AccentOverride(
                    child: TextField(
                      controller: _idController,
                      decoration: InputDecoration(
                        labelText: 'ID Number',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      textCapitalization: TextCapitalization.words,
                    ),
                    color: Colors.grey,
                  ),
                  leading: Icon(Icons.credit_card, color: Colors.black),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
              ),
              Padding(
                child: ListTile(
                  title: AccentOverride(
                    child: TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      textCapitalization: TextCapitalization.words,
                    ),
                    color: Colors.grey,
                  ),
                  leading: Icon(Icons.phone_android, color: Colors.black),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
              ),
              Padding(
                child: ListTile(
                  title: AccentOverride(
                    child: TextField(
                      controller: _residenceController,
                      decoration: InputDecoration(
                        labelText: 'Residence',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                      ),
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                    ),
                    color: Colors.grey,
                  ),
                  leading: Icon(Icons.home, color: Colors.black),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Please select your gender',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      leading: Icon(Icons.wc, color: Colors.black),
                    ),
                    Padding(
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Radio(
                                  value: 'Male',
                                  groupValue: _gender,
                                  onChanged: (s) => setState(() => _gender = s),
                                ),
                                Text('Male', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            flex: 1,
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Radio(
                                  value: 'Female',
                                  groupValue: _gender,
                                  onChanged: (s) => setState(() => _gender = s),
                                ),
                                Text('Female', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            flex: 1,
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Radio(
                                  value: 'Other',
                                  groupValue: _gender,
                                  onChanged: (s) => setState(() => _gender = s),
                                ),
                                Text('Other', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            flex: 1,
                          ),
                        ],
                        mainAxisSize: MainAxisSize.min,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    ),
                  ],
                ),
              ),
              if (_role == 'caregiver')
                Padding(
                  child: ListTile(
                    title: Text('Tap to provide ID card picture'),
                    leading: Icon(Icons.photo, color: Colors.black),
                    onTap: () => _showPicker(tag: 'identification'),
                    trailing: _idPicture ?? null,
                  ),
                  padding: const EdgeInsets.all(8.0),
                ),
              if (_role == 'patient')
                Padding(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'Please select the caregiver',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        leading: Icon(
                          Icons.medical_services,
                          color: Colors.black,
                        ),
                      ),
                      Row(
                        children: _caregivers
                            .map(
                              (e) => Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Radio(
                                        value: e,
                                        groupValue: _caregiver,
                                        onChanged: (u) =>
                                            setState(() => _caregiver = u),
                                      ),
                                      flex: 1,
                                    ),
                                    Flexible(
                                      child: Text(
                                        e.fullname,
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        mainAxisSize: MainAxisSize.min,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                ),
              if (_role == 'patient')
                Padding(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'Please select the relative',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        leading: ImageIcon(
                          AssetImage('images/relatives.png'),
                          color: Colors.black,
                        ),
                      ),
                      Row(
                        children: _relatives
                            .map(
                              (e) => Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Radio(
                                        value: e,
                                        groupValue: _relative,
                                        onChanged: (u) =>
                                            setState(() => _relative = u),
                                      ),
                                      flex: 1,
                                    ),
                                    Flexible(
                                      child: Text(
                                        e.fullname,
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        mainAxisSize: MainAxisSize.min,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                ),
              if (!_isLoading)
                Center(
                  child: Container(
                    width: 200,
                    child: FancyButton(
                      icon: Icon(Icons.person_add_alt_1, color: Colors.white),
                      fillColor: Colors.black,
                      onPressed: _submit,
                      child: Text(
                        'Add ${capitalize(_role)}',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      splashColor: Colors.black38,
                    ),
                    alignment: Alignment.center,
                  ),
                )
              else
                Center(child: CircularProgressIndicator()),
              SizedBox(height: 5.0),
            ],
            crossAxisAlignment: CrossAxisAlignment.start,
          ),
          physics: BouncingScrollPhysics(),
        ),
        margin: EdgeInsets.all(8.0),
        alignment: Alignment.center,
        height: MediaQuery.of(context).size.height,
      ),
      backgroundColor: Color(0xFFEEEEEE),
    );
  }

  void _showPicker({String tag}) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext buildContext) {
          return SafeArea(
            child: Container(
              child: Wrap(
                children: <Widget>[
                  ListTile(
                    title: Text('Photo Library'),
                    onTap: () async {
                      // remove add image icon
                      Navigator.pop(context);
                      final res = await mediaUpload(context, tag: tag);
                      if (res == null) {
                        showToast('File not received', context);
                      } else if (res is String) {
                        showToast(res, context);
                      } else if (res is List<String>) {
                        if (res.isNotEmpty) {
                          _setPicture(res[0], res[1], tag: tag);
                        } else {
                          showToast('$tag image details not provided', context);
                        }
                      } else {
                        showToast('Error getting $tag image', context);
                      }
                    },
                    leading: Icon(Icons.photo_library),
                  ),
                  ListTile(
                    title: Text('Camera'),
                    onTap: () async {
                      // remove add image icon
                      Navigator.pop(context);
                      final res = await mediaUpload(
                        context,
                        tag: tag,
                        preferredCamera: 'front',
                        method: "pickFromCamera",
                      );
                      if (res == null) {
                        showToast('File not received', context);
                      } else if (res is String) {
                        showToast(res, context);
                      } else if (res is List<String>) {
                        if (res.isNotEmpty) {
                          _setPicture(res[0], res[1], tag: tag);
                        } else {
                          showToast('$tag image details not provided', context);
                        }
                      } else {
                        showToast('Error getting $tag image', context);
                      }
                    },
                    leading: Icon(Icons.photo_camera),
                  ),
                  ListTile(
                    title: Text('Cancel'),
                    onTap: () => Navigator.pop(context),
                    leading: Icon(Icons.cancel),
                  ),
                ],
              ),
            ),
          );
        });
  }

  _setPicture(String path, String name, {String tag = 'profile'}) async {
    try {
      tag = isStringEmpty(tag) ? '' : tag;
      if (!mounted || isStringEmpty(path) || isStringEmpty(name)) return;
      setState(() {
        if (tag == 'profile') {
          _profilePath = path;
          _profileName = name;
          _profilePicture = getImage(
            path,
            isFile: true,
            fit: BoxFit.fitHeight,
            width: 180,
            height: 180,
          );
          // If picture set successfully, set it to replace placeholder avatar
          if (_profilePicture != null) {
            _profilePicture.image
                .resolve(ImageConfiguration())
                .addListener(ImageStreamListener((imageInfo, boolean) {
              if (mounted) setState(() => _loaded = true);
            }));
          }
        } else if (tag == 'identification') {
          _idPicName = name;
          _idPicPath = path;
          _idPicture = getImage(path, isFile: true, width: null, height: null);
        } else {
          showToast('Image not specified', context);
        }
      });
    } catch (err) {
      print("${err.toString()}");
      setState(() => _loaded = false);
    }
  }

  _submit() async {
    if (!mounted) return;
    if (isStringEmpty(_role)) {
      logError('REGISTRATION ERROR', 'Role not provided');
      showToast('Error adding user. Try again later', context);
      return;
    }
    if (isStringEmpty(_nameController.text)) {
      showToast('Please provide the official names', context);
    } else if (isStringEmpty(_idController.text)) {
      showToast('Please provide the ID number', context);
    } else if (isStringEmpty(_phoneController.text)) {
      showToast('Please provide the phone number', context);
    } else if (isStringEmpty(_residenceController.text)) {
      showToast('Please provide the residence', context);
    } else if (isStringEmpty(_gender)) {
      showToast('Please select a gender', context);
    } else if (isStringEmpty(_profilePath)) {
      showToast('Please provide a profile picture', context);
    } else if ((_role == 'caregiver' || _role == 'admin') &&
        isStringEmpty(_idPicPath)) {
      showToast('Please provide an picture of ID card', context);
    } else if (_role == 'patient' && _caregiver == null) {
      showToast('Please select a caregiver', context);
    } else if (_role == 'patient' && _relative == null) {
      showToast('Please select a relative', context);
    } else {
      final userID = _prefs.getString('loggedIn_user');
      final token = _prefs.getString('auth_token');
      var refresh = _prefs.getString('refresh_token');
      var userRoles = _prefs.getString('user_role');
      if (isStringEmpty(userID)) {
        logError('REGISTRATION ERROR!!', 'Logged in user empty/missing');
        showToast('Unable to add user. Please contact administrator', context);
        return;
      }
      if (isStringEmpty(token)) {
        logError('REGISTRATION ERROR!!', 'Authentication token empty/missing');
        showToast('Unable to add user. Please contact administrator', context);
        return;
      }
      if (isStringEmpty(refresh)) {
        logError('REGISTRATION ERROR!!', 'Refresh token empty/missing');
        showToast('Unable to add user. Please contact administrator', context);
        return;
      }
      if (isStringEmpty(userID)) userRoles = 'admin';
      setState(() => _isLoading = true);
      var request =
          http.MultipartRequest("POST", Uri.parse("$adminBlueprint/register/"));
      // Set headers
      request.headers['Authorization'] = "Bearer $token";
      request.headers['UserID'] = "$userID";
      request.headers['UniqueID'] = await getID();
      request.headers['Role'] = userRoles;
      // find the mime type of the profile and ID picture by looking at file header bytes
      final mimeTypeData =
          lookupMimeType(_profileName, headerBytes: [0xFF, 0xD8]).split('/');
      final mimeTypeData1 =
          lookupMimeType(_idPicName, headerBytes: [0xFF, 0xD8]).split('/');
      // attach files to request
      request.files.addAll(
        [
          http.MultipartFile.fromBytes(
            'profile_picture',
            await ((PickedFile(_profilePath).readAsBytes())),
            filename: _profileName,
            contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
          ),
          if (_role == 'caregiver' || _role == 'admin')
            http.MultipartFile.fromBytes(
              'identification_picture',
              await ((PickedFile(_idPicPath).readAsBytes())),
              filename: _idPicName,
              contentType: MediaType(mimeTypeData1[0], mimeTypeData1[1]),
            ),
        ],
      );
      // add registration details
      request.fields['official_names'] = _nameController.text;
      request.fields['id_number'] = _idController.text;
      request.fields['residency'] = _residenceController.text;
      request.fields['phone_number'] = _phoneController.text;
      request.fields['gender'] = _gender;
      request.fields['role'] = _role;
      if (_role == 'patient') {
        request.fields['relative'] = _relative.userID;
        request.fields['caregiver'] = _caregiver.userID;
      }
      // send the request
      var response = await http.Response.fromStream(await request.send());
      Map resp = json.decode(response.body);
      if (response.statusCode >= 400) {
        logError('${response.statusCode}', '${resp['message']}');
      }
      setState(() => _isLoading = false);
      final statusCode = resp["status"] ?? -5;
      final message = resp['message'] ??
          'Something went wrong. Please contact the administrator';
      if (message == "Signature expired. Please log in again.") {
        final resp = await tokenRefresh(context);
        if (!isStringEmpty(resp)) {
          setState(() => _errorMessage = resp);
          return;
        } else {
          _submit();
        }
      } else if (message == 'User not logged in' ||
          message == 'Login session not found') {
        _prefs.setString("loggedIn_user", '');
        _prefs.setString('auth_token', '');
        _prefs.setString('refresh_token', '');
        _prefs.setString('login_date', '');
        _prefs.setString('user_role', '');
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        return;
      } else {
        if (statusCode == null) {
          setState(() => _errorMessage =
              'Something went wrong. Please contact the administrator');
          logError("ERROR", "Status code missing");
          return;
        }
        setState(() => _errorMessage = message);
        if (statusCode != 0) {
          showGenericFlushBar(
            message,
            context,
            duration: SnackbarDuration.LONG,
            icon: Icon(Icons.error, color: Colors.redAccent),
          );
          logError("REGISTRATION ERROR", "Errorcode $statusCode");
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    _residenceController.dispose();
    super.dispose();
  }
}
