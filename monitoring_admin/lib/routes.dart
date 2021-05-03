import 'package:flutter/material.dart';

import 'home.dart';
import 'title.dart';
import 'login.dart';
import 'splash.dart';
import 'patients.dart';
import 'relatives.dart';
import 'caregivers.dart';
import 'add_user.dart';

// create paths
final routes = <String, WidgetBuilder>{
  '/': (_) => SplashScreen(),
  LoginScreen.route: (_) => LoginScreen(),
};

/// Handle simple routing to a new page

class SimpleRoute extends PageRoute {
  SimpleRoute({
    @required String name,
    @required this.title,
    @required this.builder,
  }) : super(settings: RouteSettings(name: name));

  final String title;
  final WidgetBuilder builder;

  @override
  Color get barrierColor => null;

  @override
  String get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration(milliseconds: 0);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return Title(
      title: this.title,
      color: Theme.of(context).primaryColor,
      child: builder(context),
    );
  }
}

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Get the routing data. This data is obtained either from a push or from the browser URL
    // It shall contain the route name and query parameters
    var routingData = settings.name;

    // Getting arguments passed in while calling Navigator.pushNamed
    // We will use this to validate screen to be shown by checking if it is of right type for respective screen
    // If not of proper type, we'll show an error screen
    final arguments = settings.arguments;

    switch (settings.name) {
      case '/':
        return SplashScreen.route();
      case HomeScreen.route:
        return MaterialPageRoute(builder: (_) => HomeScreen());
      case PatientsScreen.route:
        return MaterialPageRoute(builder: (_) => PatientsScreen());
      case CaregiversScreen.route:
        return MaterialPageRoute(builder: (_) => CaregiversScreen());
      case RelativesScreen.route:
        return MaterialPageRoute(builder: (_) => RelativesScreen());
      case AddUserScreen.route:
        if (arguments is String) {
          return MaterialPageRoute(
            builder: (_) => AddUserScreen(role: arguments),
          );
        }
        return _errorRoute();
      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        body: Center(
          child: Text('Screen could not be displayed'),
        ),
        appBar: AppTitle(context),
      ),
    );
  }
}
