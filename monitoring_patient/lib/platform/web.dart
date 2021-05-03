import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:meet_network_image/meet_network_image.dart';

import 'package:monitoring_patient/title.dart';
import 'package:monitoring_patient/routes.dart';
import 'package:monitoring_patient/extras.dart';
import 'package:monitoring_patient/constants.dart';

/// This class enables us to detect the platform/userAgent of users on the Web
class UserAgent {
  static void setUpWebview() async {}

  /// This is a list of iOS-powered devices
  static List<String> _iOS = [
    'iPad Simulator',
    'iPhone Simulator',
    'iPod Simulator',
    'iPad',
    'iPhone',
    'iPod'
  ];

  /// List of Mac OS powered computers
  static List<String> _macOS = [
    'Macintosh',
    'MacIntel',
    'MacPPC',
    'Mac68K',
    "Mac",
    "darwin"
  ];

  /// List of Windows powered computers
  static List<String> _windowsOS = ['Win32', 'Win64', 'Windows', 'WinCE'];

  /// Check if the device is an iOS device
  static bool isIOS() {
    var matches = false;
    _iOS.forEach((name) {
      if (html.window.navigator.platform.contains(name) ||
          html.window.navigator.userAgent.contains(name)) {
        matches = true;
      }
    });
    return matches;
  }

  /// Check if the device is iPhone
  static Future<bool> isIphone() async {
    return html.window.navigator.platform.toLowerCase().contains('iphone') ||
        html.window.navigator.userAgent.toLowerCase().contains("iphone");
  }

  /// Check if device is an Android device
  static bool isAndroid() =>
      html.window.navigator.platform == "Android" ||
      html.window.navigator.userAgent.contains("Android");

  /// Check if the device is an Fuschia device
  static bool isFuschia() =>
      html.window.navigator.platform == "Fuschia" ||
      html.window.navigator.userAgent.contains("Fuschia");

  /// Check if the device is a Mac device
  static bool isMacOS() {
    var matches = false;
    _macOS.forEach((name) {
      if (html.window.navigator.platform.contains(name) ||
          html.window.navigator.userAgent.contains(name)) {
        matches = true;
      }
    });
    return matches;
  }

  /// Check if the device is a Windows device
  static bool isWindows() {
    var matches = false;
    _windowsOS.forEach((name) {
      if (html.window.navigator.platform.contains(name) ||
          html.window.navigator.userAgent.contains(name)) {
        matches = true;
      }
    });
    return matches;
  }

  /// Check if device is a Linux device
  static bool isLinux() =>
      html.window.navigator.platform == "Linux" ||
      html.window.navigator.userAgent.contains("Linux");

  /// Check if device is a mobile phone, not PC/Mac
  static bool isMobile() => isAndroid() || isIOS() || isFuschia();

  /// Check if device is a PC/Mac
  static bool isPC() => isMacOS() || isWindows() || isLinux();

  /// Set name of the mobile platform we're currently on
  static String name() {
    var name = "";
    if (isAndroid()) {
      name = "Android";
    } else if (isIOS()) {
      name = "iOS";
    }
    return name;
  }
}

class WebviewWidget extends StatefulWidget {
  final String url;
  final String title;
  final bool fullScreen;

  WebviewWidget(this.url, {this.title = '', this.fullScreen = true});

  @override
  _WebviewWidgetState createState() => _WebviewWidgetState();

  static Route<dynamic> route(String url, {String title = ''}) {
    title = isStringEmpty(title) ? 'web' : title;
    final route = title.contains(' ') ? title.split(' ')[0] : title;
    return SimpleRoute(
      name: '/${route.toLowerCase()}',
      title: '${capitalize(title)} | $appName',
      builder: (_) => WebviewWidget(url, title: title),
    );
  }
}

class _WebviewWidgetState extends State<WebviewWidget> {
  String _tag = "";

  @override
  void initState() {
    super.initState();
    _tag = 'html_webview_${DateTime.now()}';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_tag, (int viewId) {
      final iFrameElement = html.IFrameElement();
      html.window.onMessage.forEach((html.MessageEvent element) {
        final data = element.data;
        if (data != null) {
          debugPrint('Event Received in callback');
          if (data is String) {
            if (data.contains('hCAPTCHA_RESPONSE')) {
              final response = data.split(':').sublist(1).join().trim();
              Navigator.pop(context, response);
            }
          }
        } else {
          debugPrint('No data received from event');
        }
      });
      return iFrameElement
        ..width = '${MediaQuery.of(context).size.width}'
        ..height = '${MediaQuery.of(context).size.height}'
        ..src = widget.url ?? 'https://google.com/'
        ..style.border = 'none';
    });
  }

  @override
  BuildContext get context => super.context;

  @override
  Widget build(BuildContext context) {
    return widget.fullScreen
        ? Scaffold(
            appBar: AppTitle(context),
            body: _bodyItems(),
            backgroundColor: Color(0xFFEEEEEE),
          )
        : _bodyItems();
  }

  Widget _bodyItems() => Container(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                ),
                child: Directionality(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: HtmlElementView(viewType: _tag),
                  ),
                  textDirection: TextDirection.ltr,
                ),
                margin: const EdgeInsets.all(10.0),
              ),
              flex: 1,
            ),
          ],
        ),
        margin: EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
      );
}

/// Get file
getFile(String path) => null;

/// This function will pick image and video files from phone.
/// Courtesy of: https://github.com/flutter/flutter/issues/36281
Future<dynamic> mediaUpload(
  BuildContext context, {
  String tag = 'upload',
  String method = "pickFromGallery",
  String preferredCamera = 'back',
}) async {
  String fileType = 'image/*';
  try {
    // Waits for and completes the file picking process
    final byteCompleter = Completer<PickedFile>();
    // Get name of file
    final nameCompleter = Completer<String>();

    // Set source for image
    ImageSource source = method == "pickFromGallery"
        ? ImageSource.gallery
        : method == "pickFromCamera"
            ? ImageSource.camera
            : null;

    // Set preferred camera
    CameraDevice cameraDevice;
    if (method == "pickFromCamera") {
      if (isStringEmpty(preferredCamera)) {
        cameraDevice = CameraDevice.rear;
      } else if (preferredCamera == 'front') {
        cameraDevice = CameraDevice.front;
      } else if (preferredCamera == 'back') {
        cameraDevice = CameraDevice.rear;
      } else {
        showToast("Unidentified camera. Defaulting to back", context);
        cameraDevice = CameraDevice.rear;
      }
    }
    String capture = _computeCaptureAttribute(source, cameraDevice);

    // Create input element
    final html.InputElement input = html.document.createElement('input');
    // Set to only receive files of given type
    input
      ..type = 'file'
      ..style.display = "none"
      ..accept = fileType;
    // Set capture attribute to support videos
    if (capture != null) {
      input.setAttribute('capture', capture);
    }

    // Detect and process selected file
    // Observe the input until we can return something
    input.onChange.first.then((event) {
      // Get the first image picked
      final html.File file = input.files?.first;
      final url = html.Url.createObjectUrl(file);

      // Check file size
      if (file != null) {
        // size of the file
        int size = file.size;
        if (size >= (fileLimit * 1024 * 1024)) {
          showToast('File should be less than $fileLimit MB', context);
          return;
        }
      }

      if (!byteCompleter.isCompleted) {
        // Receive the file bytes, name and path as Promise/Future
        nameCompleter.complete(file.name);
        byteCompleter.complete(PickedFile(url));
      }
    });
    input.onError.first.then((event) {
      if (!byteCompleter.isCompleted) {
        byteCompleter.completeError(event);
      }
    });

    // append input element to DOM
    html.document.body.append(input);
    // Open the file picker dialog screen in the browser
    input.click();

    // Receive file picking results
    final PickedFile pickedFile = await byteCompleter.future;
    final String fileName = await nameCompleter.future;
    // No image/video chosen
    if (pickedFile == null || isStringEmpty(fileName)) {
      showToast('No image received', context);
      return null;
    }
    final String url = pickedFile.path;

    // remove input element from DOM
    input.remove();
    // Pass file details forward
    return [url, fileName];
  } catch (ex) {
    showToast("Oops! Something went wrong!", context);
    print("ERROR:\t${ex.toString()}");
  }
  return null;
}

String _computeCaptureAttribute(ImageSource source, CameraDevice device) {
  if (device == null) return null;
  if (source == ImageSource.camera) {
    return (device == CameraDevice.front) ? 'user' : 'environment';
  }
  return null;
}

/// This function loads an image to the screen from its path,
/// received from the respective platform file pickers, setting it to the [Image] widget.
Widget loadImage(
  String path, {
  double width = 150.0,
  double height = 150.0,
  BoxFit fit = BoxFit.cover,
}) {
  // set picture to widget from network path
  return MonitoringNetworkImage(
    imageUrl: path,
    width: width,
    height: height,
    loadingBuilder: (context) => Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
      ),
    ),
    errorBuilder: (context, error) => Icon(Icons.cancel, color: Colors.red),
    fit: fit,
  );
}

class MonitoringNetworkImage extends MeetNetworkImage {
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
        assert(matchTextDirection != null),
        super(
          key: key,
          imageUrl: imageUrl,
          loadingBuilder: loadingBuilder,
          errorBuilder: errorBuilder,
          fit: fit,
          color: color,
          width: width,
          height: height,
          colorBlendMode: colorBlendMode,
          matchTextDirection: matchTextDirection,
          filterQuality: filterQuality,
          alignment: alignment,
          headers: headers,
          repeat: repeat,
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

class MonitoringNetworkImageProvider extends MeetNetworkImageProvider {
  MonitoringNetworkImageProvider({
    @required String imageUrl,
    double scale = 1.0,
    int width,
    int height,
    Map<String, String> headers,
    void Function() errorListener,
    String cacheKey,
    @required String placeholderAssetPath,
  })  : assert(imageUrl != null),
        assert(scale != null),
        assert(placeholderAssetPath != null),
        super(
          imageUrl: imageUrl,
          scale: scale,
          width: width,
          height: height,
          headers: headers,
          cacheKey: cacheKey,
          errorListener: errorListener,
          placeholderAssetPath: placeholderAssetPath,
        );
}
