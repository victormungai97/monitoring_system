// let's define a fancy button to, say, point to reading a book
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FancyButton extends StatelessWidget {
  // detect when button is tapped
  final GestureTapCallback onPressed;

  // button content
  final Widget child;

  // button colors
  final Color fillColor, splashColor;

  // button icon
  final Widget icon;

  FancyButton({
    @required this.onPressed,
    this.child,
    this.fillColor,
    this.splashColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      fillColor: fillColor ?? Colors.lightGreen,
      splashColor: splashColor ?? Colors.green,
      child: Padding(
        child: Row(
          children: <Widget>[
            icon ?? Container(),
            SizedBox(width: 8.0),
            child ??
                Text(
                  "Nothing here",
                  style: TextStyle(color: Colors.white),
                ),
          ],
          mainAxisSize: MainAxisSize.min,
        ),
        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
      ),
      onPressed: onPressed,
      shape: const StadiumBorder(),
    );
  }
}

class SomeFancyAnimation extends StatefulWidget {
  @override
  _SomeFancyAnimState createState() => _SomeFancyAnimState();
}

// have a new single Ticker, which sends a signal at almost regular interval,
// linked to this instance of the stateful widget
class _SomeFancyAnimState extends State<SomeFancyAnimation>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, // bind to ticker provider.
      duration: const Duration(milliseconds: 1000),
    );
    // each time controller's value changes, do sth
    _controller.addListener(() => print('Value updated'));
    // start counting once widget initialisation is complete
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // retrieve the value of the controller
    final int percent = (_controller.value * 100.0).round();
    return Container(child: Text('$percent%'));
  }
}

class FancyFab extends StatefulWidget {
  final List<FloatingActionButton> children;

  FancyFab({@required this.children});

  @override
  _FancyFabState createState() => _FancyFabState();
}

class _FancyFabState extends State<FancyFab>
    with SingleTickerProviderStateMixin {
  bool _isOpened = false;
  AnimationController _animationController;
  Animation<Color> _buttonColor;
  Animation<double> _animateIcon;
  Animation<double> _translateButton;
  Curve _curve = Curves.easeOut;
  double _fabHeight = 56.0;

  List<FloatingActionButton> _children;

  @override
  void initState() {
    super.initState();

    _animationController =
    AnimationController(vsync: this, duration: Duration(milliseconds: 500))
      ..addListener(() => setState(() {}));
    _animateIcon =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _buttonColor = ColorTween(begin: Colors.brown, end: Colors.green).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.00, 1.00, curve: Curves.linear),
      ),
    );
    _translateButton = Tween<double>(begin: _fabHeight, end: -14.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.75, curve: _curve),
      ),
    );

    _children = widget.children ?? [];
    _children.add(_toggle());
  }

  _animate() {
    if (!_isOpened) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    setState(() => _isOpened = !_isOpened);
  }

  FloatingActionButton _toggle() =>
      FloatingActionButton(
        backgroundColor: _buttonColor.value,
        onPressed: _animate,
        tooltip: 'Press Me',
        heroTag: 'Press Me',
        child: AnimatedIcon(
          icon: AnimatedIcons.menu_close,
          progress: _animateIcon,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: _children.map((element) {
        int index = _children.indexOf(element);
        int limit = _children.length - 1;
        return index < limit
            ? Transform(
          transform: Matrix4.translationValues(
            0.0,
            _translateButton.value * (limit - index),
            0.0,
          ),
          child: Container(child: element),
        )
            : Container(child: element);
      }).toList(),
    );
  }

  @override
  dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
