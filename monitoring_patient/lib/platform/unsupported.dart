import 'package:flutter/material.dart';
import '../routes.dart' show SimpleRoute;

/// This class enables us to detect the platform/userAgent of users
class UserAgent {
  static void setUpWebview() async {}

  static bool isAndroid() => false;

  static bool isIOS() => false;

  static bool isFuschia() => false;

  static Future<bool> isIphone() async => false;

  static bool isMobile() => isAndroid() || isIOS() || isFuschia();

  static bool isMacOS() => false;

  static bool isWindows() => false;

  static bool isLinux() => false;

  static bool isPC() => isMacOS() || isWindows() || isLinux();

  static void openStore() {}
}

class WebviewWidget extends StatelessWidget {
  final String url;
  final String title;
  final bool fullScreen;

  WebviewWidget(this.url, {this.title = '', this.fullScreen = true});

  static Route<dynamic> route(String url, {String title = ''}) {
    return SimpleRoute(
      name: '',
      title: '',
      builder: (_) => WebviewWidget(url, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

/// Get file
getFile(String path) => null;

/// This function will pick image and video files from phone.
Future<dynamic> mediaUpload(
  BuildContext context, {
  String tag = 'upload',
  String method = "pickFromGallery",
  String preferredCamera = 'back',
}) async =>
    null;

/// This function loads an image to the screen from its path,
/// received from the respective platform file pickers, setting it to the [Image] widget.
Image loadImage(String path,
    {double width = 150.0, double height = 150.0, BoxFit fit = BoxFit.cover}) {
  // set picture to widget from bytes
  return Image(
    image: NetworkImage(path, scale: 1.0),
    width: width,
    height: height,
    fit: fit,
  );
}

Image getImage(
  String path, {
  bool isFile = true,
  double width = 150,
  double height = 150,
  BoxFit fit = BoxFit.contain,
}) =>
    Image.network(path);

class MonitoringNetworkImage extends Image {
  MonitoringNetworkImage({
    Key key,
    @required String imageUrl,
    @required Widget Function(BuildContext context) loadingBuilder,
    @required Widget Function(BuildContext context, Object error) errorBuilder,
    BoxFit fit,
    Color color,
    double width,
    double height,
    BlendMode colorBlendMode,
    Map<String, String> headers,
    bool matchTextDirection = false,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    AlignmentGeometry alignment = Alignment.center,
    FilterQuality filterQuality = FilterQuality.low,
  })  : assert(imageUrl != null),
        assert(loadingBuilder != null),
        assert(errorBuilder != null),
        assert(alignment != null),
        assert(filterQuality != null),
        assert(repeat != null),
        assert(matchTextDirection != null);
}

abstract class MonitoringNetworkImageProvider
    extends ImageProvider<MonitoringNetworkImageProvider> {
  factory MonitoringNetworkImageProvider({
    @required String imageUrl,
    double scale,
    int width,
    int height,
    Map<String, String> headers,
    void Function() errorListener,
    String cacheKey,
    @required String placeholderAssetPath,
  }) {
    return null;
  }
}
