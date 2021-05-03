import 'package:flutter/material.dart';

import 'title.dart';
import 'add_user.dart';
import 'fancy_button.dart';

class CaregiversScreen extends StatefulWidget {
  static const String route = '/caregivers';

  @override
  _CaregiversScreenState createState() => _CaregiversScreenState();
}

class _CaregiversScreenState extends State<CaregiversScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        color: Colors.white,
        margin: EdgeInsets.all(8.0),
        child: Column(
          children: [
            SizedBox(height: 10.0),
            Center(
              child: Text(
                'Caregivers',
                style: TextStyle(fontSize: 28, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(10, 15, 10, 15),
              child: Divider(color: Colors.black, height: 3),
            ),
            Container(
              width: 250,
              child: FancyButton(
                icon: Icon(
                  Icons.medical_services,
                  color: Colors.white,
                ),
                fillColor: Colors.black,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AddUserScreen.route,
                    arguments: 'caregiver',
                  );
                },
                child: Text(
                  'Add Caregiver',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                splashColor: Colors.black38,
              ),
              alignment: Alignment.center,
            ),
            SizedBox(height: 5.0),
          ],
        ),
        width: MediaQuery.of(context).size.width,
      ),
      appBar: AppTitle(context),
      backgroundColor: Color(0xFFEEEEEE),
    );
  }
}
