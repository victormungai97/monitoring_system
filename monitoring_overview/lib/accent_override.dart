import 'package:flutter/material.dart';

class AccentOverride extends StatelessWidget {
  final Color color;
  final Widget child;

  const AccentOverride({Key key, this.color, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Theme(
      child: child,
      data: Theme.of(context).copyWith(accentColor: color),
    );
  }
}
