import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:device_info/device_info.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

import 'package:monitoring_patient/constants.dart';
import 'package:monitoring_patient/extras.dart';
import 'package:monitoring_patient/title.dart';
import '../routes.dart' show SimpleRoute;

/// This class enables us to detect the platform/userAgent of users
class UserAgent {
  static void setUpWebview() async {
    if (UserAgent.isAndroid()) {
      await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
  }

  /// Check if device is an Android device
  static bool isAndroid() => Platform.isAndroid;

  /// Check if the device is an iOS device
  static bool isIOS() => Platform.isIOS;

  /// Check if the device is an Fuschia device
  static bool isFuschia() => Platform.isFuchsia;

  /// Check if the device is iPhone
  static Future<bool> isIphone() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    IosDeviceInfo info = await deviceInfo.iosInfo;
    return info.name.toLowerCase().contains("iphone");
  }

  /// Check if device is a mobile phone, not PC/Mac
  static bool isMobile() => isAndroid() || isIOS() || isFuschia();

  /// Check if the device is a Mac device
  static bool isMacOS() => Platform.isMacOS;

  /// Check if the device is a Windows device
  static bool isWindows() => Platform.isWindows;

  /// Check if device is a Linux device
  static bool isLinux() => Platform.isLinux;

  /// Check if device is a PC/Mac
  static bool isPC() => isMacOS() || isWindows() || isLinux();

  /// Here, we shall provide URLs to the various app stores for users to download the app
  static void openStore() {
    if (isMobile()) {
      if (isAndroid()) {
        print("your Play Store URL");
      } else {
        print("Your App Store URL");
      }
    }
  }
}

/// Checking if your App has been Given Permission
Future<bool> _requestAppPermission(
    BuildContext context, perm.Permission permission,
    {String tag = '', Function onPermissionDenied}) async {
  try {
    tag = isStringEmpty(tag) ? 'permission' : tag;
    if (permission == null) {
      logError(
          '${tag.toUpperCase()} PERMISSION ERROR', 'permission not provided');
      return false;
    }
    var status = await permission.status;
    if (status == null) {
      logError('${tag.toUpperCase()} PERMISSION ERROR',
          'Unable to determine permission status');
      return false;
    }
    if (status.isGranted) return true;
    if (status.isDenied || status.isRestricted || status.isLimited) {
      perm.PermissionStatus permissionStatus = await permission.request();
      final granted = permissionStatus != null && permissionStatus.isGranted;

      if (granted != true) {
        bool accepted = await showAlertDialog(
          context,
          title: '${capitalize(tag)} Permission required',
          message:
              '''To continue with this feature, the app requires permission to access the device's ${tag.toLowerCase()}.
            \nPlease accept this request and provide the permission''',
        );
        if (accepted != null && accepted) {
          return await _requestAppPermission(context, permission,
              tag: tag, onPermissionDenied: onPermissionDenied);
        } else {
          return false;
        }
      }
      debugPrint('request${capitalize(tag)}Permission $granted');
      return granted;
    } else if (status.isPermanentlyDenied) {
      bool accepted = await showAlertDialog(
        context,
        title: '${capitalize(tag)} Permission required',
        message:
            '''To continue with this feature, the app requires permission to access the device's ${tag.toLowerCase()}.
            \nPlease accept this in the app settings''',
      );
      if (accepted != null && accepted) {
        // The user opted to never again see the permission request dialog for this
        // app. The only way to change the permission's status now is to let the
        // user manually enable it in the system settings.
        perm.openAppSettings();
      }
      return false;
    }
    return true;
  } catch (err) {
    showToast('Unable to request ${tag.toLowerCase()} permission', context);
    logError('${tag.toUpperCase()} PERMISSION ERROR!!', '$err');
    return false;
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
  String _url = "";
  double _progress = 0.0;

  InAppWebViewController _webViewController;
  final GlobalKey _webViewKey = GlobalKey();

  InAppWebViewGroupOptions _options = InAppWebViewGroupOptions(
    crossPlatform: InAppWebViewOptions(
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
    ),
    android: AndroidInAppWebViewOptions(
      useHybridComposition: true,
      // on Android you need to set supportMultipleWindows to true,
      // otherwise the onCreateWindow event won't be called
      supportMultipleWindows: true,
    ),
    ios: IOSInAppWebViewOptions(
      allowsInlineMediaPlayback: true,
    ),
  );

  PullToRefreshController pullToRefreshController;
  final _urlController = TextEditingController();

  final _supportedSchemes = [
    "http",
    "https",
    "file",
    "chrome",
    "data",
    "javascript",
    "about"
  ];

  @override
  void initState() {
    super.initState();
    _url = widget.url ?? 'https://google.com/';
    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(color: Colors.black),
      onRefresh: () async {
        if (Platform.isAndroid) {
          _webViewController?.reload();
        } else if (Platform.isIOS) {
          _webViewController?.loadUrl(
              urlRequest: URLRequest(url: await _webViewController?.getUrl()));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTitle(context),
      body: Container(
        height: MediaQuery.of(context).size.height,
        child: Column(
          children: <Widget>[
            TextField(
              decoration: InputDecoration(prefixIcon: Icon(Icons.search)),
              controller: _urlController,
              keyboardType: TextInputType.url,
              onSubmitted: (value) {
                var url = Uri.parse(value);
                if (url.scheme.isEmpty) {
                  url = Uri.parse("https://www.google.com/search?q=" + value);
                }
                _webViewController?.loadUrl(urlRequest: URLRequest(url: url));
              },
            ),
            SizedBox(
              child: _progress < 1.0
                  ? LinearProgressIndicator(value: _progress)
                  : Container(),
              height: 2.5,
            ),
            Expanded(
              child: Container(
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent),
                ),
                child: InAppWebView(
                  key: _webViewKey,
                  initialUrlRequest: URLRequest(url: Uri.parse(_url)),
                  initialOptions: _options,
                  pullToRefreshController: pullToRefreshController,
                  onWebViewCreated: (InAppWebViewController controller) {
                    setState(() => _webViewController = controller);
                    _webViewController.addJavaScriptHandler(
                        handlerName: 'handlerFoo',
                        callback: (args) {
                          // return data to JavaScript side!
                          return {'bar': 'bar_value', 'baz': 'baz_value'};
                        });

                    _webViewController.addJavaScriptHandler(
                        handlerName: 'handlerFooWithArgs',
                        callback: (args) {
                          if (args != null && args.isNotEmpty) {
                            debugPrint('Event Received in callback');
                            if (args.length == 1) {
                              final data = args[0];
                              if (data is String) {
                                if (data.contains('hCAPTCHA_RESPONSE')) {
                                  final parts = data.split(':').sublist(1);
                                  Navigator.pop(context, parts.join().trim());
                                }
                              }
                            }
                          } else {
                            debugPrint('No data received from event');
                          }
                        });
                  },
                  // Listen to the onDownloadStart event
                  onDownloadStart: (controller, url) async {
                    try {
                      // Check if storage permission is denied/restricted/undetermined
                      bool granted = await _requestAppPermission(
                        context,
                        perm.Permission.storage,
                        tag: 'storage',
                      );
                      if (granted) {
                        debugPrint("onDownloadStart $url");
                        // Create new download task:
                        final taskId = await FlutterDownloader.enqueue(
                          url: url.toString(),
                          savedDir: (await getExternalStorageDirectory()).path,
                          showNotification: true,
                          // Show download progress in status bar (for Android)
                          openFileFromNotification:
                              true, // click on notification to open downloaded file (for Android)
                        );
                        debugPrint("Download task ID: $taskId");
                      } else {
                        showToast(
                          'Please grant storage permission and try again',
                          context,
                        );
                        logError(
                          'STORAGE ERROR!!!',
                          'Storage permission not granted',
                        );
                      }
                    } catch (err) {
                      showToast('Unable to download file. Try again', context);
                      logError('DOWNLOAD ERROR!!!', '$err');
                      return null;
                    }
                  },
                  androidOnPermissionRequest: (_, origin, resources) async {
                    return PermissionRequestResponse(
                      resources: resources,
                      action: PermissionRequestResponseAction.GRANT,
                    );
                  },
                  shouldOverrideUrlLoading: (_, navigationAction) async {
                    var uri = navigationAction.request.url;

                    if (!_supportedSchemes.contains(uri.scheme)) {
                      if (await canLaunch(_url)) {
                        // Launch the App
                        await launch(_url);
                        // and cancel the request
                        return NavigationActionPolicy.CANCEL;
                      }
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  // Handle pop-up windows
                  onCreateWindow: (controller, createWindowRequest) async {
                    debugPrint("onCreateWindow");

                    showDialog(
                      builder: (context) {
                        return AlertDialog(
                          content: Container(
                            height: 400,
                            child: InAppWebView(
                              // Setting the windowId property is important here!
                              windowId: createWindowRequest.windowId,
                              initialOptions: InAppWebViewGroupOptions(
                                crossPlatform: InAppWebViewOptions(
                                  // debuggingEnabled: true,
                                  useShouldOverrideUrlLoading: true,
                                ),
                              ),
                              onLoadStart: (controller, url) {
                                setState(() {
                                  this._url = url.toString();
                                  _urlController.text = this._url;
                                });
                              },
                              onLoadStop: (controller, url) async {
                                pullToRefreshController.endRefreshing();
                                setState(() {
                                  this._url = url.toString();
                                  _urlController.text = this._url;
                                });
                              },
                              onLoadError: (controller, url, code, message) {
                                pullToRefreshController.endRefreshing();
                              },
                              shouldOverrideUrlLoading:
                                  (_, navigationAction) async {
                                var uri = navigationAction.request.url;

                                if (!_supportedSchemes.contains(uri.scheme)) {
                                  if (await canLaunch(_url)) {
                                    // Launch the App
                                    await launch(_url);
                                    // and cancel the request
                                    return NavigationActionPolicy.CANCEL;
                                  }
                                }

                                return NavigationActionPolicy.ALLOW;
                              },
                            ),
                            width: MediaQuery.of(context).size.width,
                          ),
                        );
                      },
                      context: context,
                    );

                    return true;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      this._url = url.toString();
                      _urlController.text = this._url;
                    });
                  },
                  onLoadStop: (controller, url) async {
                    pullToRefreshController.endRefreshing();
                    setState(() {
                      this._url = url.toString();
                      _urlController.text = this._url;
                    });
                  },
                  onLoadError: (controller, url, code, message) {
                    pullToRefreshController.endRefreshing();
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress == 100) {
                      pullToRefreshController.endRefreshing();
                    }
                    setState(() {
                      this._progress = progress / 100;
                      _urlController.text = this._url;
                    });
                  },
                  onUpdateVisitedHistory: (controller, url, androidIsReload) {
                    setState(() {
                      this._url = url.toString();
                      _urlController.text = this._url;
                    });
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    print(consoleMessage);
                  },
                ),
                margin: const EdgeInsets.all(1.0),
                height: MediaQuery.of(context).size.height,
              ),
              flex: 1,
            ),
            ButtonBar(
              children: <Widget>[
                ElevatedButton(
                  child: Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => _webViewController?.goBack(),
                ),
                ElevatedButton(
                  child: Icon(Icons.arrow_forward, color: Colors.black),
                  onPressed: () => _webViewController?.goForward(),
                ),
                ElevatedButton(
                  child: Icon(Icons.refresh, color: Colors.black),
                  onPressed: () => _webViewController?.reload(),
                ),
              ],
              alignment: MainAxisAlignment.center,
            ),
          ],
        ),
        margin: EdgeInsets.all(1.0),
        width: MediaQuery.of(context).size.width,
      ),
      backgroundColor: Color(0xFFEEEEEE),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}

/// Get file
getFile(String path) => File(path);

/// This function will pick image and video files from phone.
Future<dynamic> mediaUpload(
  BuildContext context, {
  String tag = 'upload',
  String method = "pickFromGallery",
  String preferredCamera = 'back',
}) async {
  try {
    if (UserAgent.isMobile()) {
      String _source = method == "pickFromCamera" ? 'camera' : 'storage';
      // Check if permission is denied/restricted/undetermined
      bool granted = await _requestAppPermission(
        context,
        method == "pickFromCamera"
            ? perm.Permission.camera
            : perm.Permission.storage,
        tag: _source,
      );
      if (granted) {
        // Set source for image
        ImageSource source;
        if (method == "pickFromGallery") {
          source = ImageSource.gallery;
        } else if (method == "pickFromCamera") {
          source = ImageSource.camera;
        }

        // Set preferred camera
        CameraDevice cameraDevice = CameraDevice.front;
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

        // Pick file
        final picker = ImagePicker();
        PickedFile pickedFile = await picker.getImage(
          source: source,
          maxWidth: 640,
          maxHeight: 480,
          preferredCameraDevice: cameraDevice,
        );

        // No image/video chosen
        if (pickedFile == null) {
          showToast("No image selected", context);
          return null;
        }

        File imageFile = File(pickedFile.path);

        // Get file size in bytes and ensure it's within desired specifications
        int size = await imageFile.length();
        if (size >= (fileLimit * 1024 * 1024)) {
          showToast('File should be less than $fileLimit MB', context);
          return null;
        }

        String filePath = imageFile.path;

        // Pass file details forward
        return [filePath, path.basename(filePath)];
      } else {
        showToast('Please grant $_source permission and try again', context);
        logError(
          '${_source.toUpperCase()} ERROR!!!',
          '${capitalize(_source)} permission not granted',
        );
      }
    } else {
      showToast("Still being built", context);
    }
  } on PlatformException catch (err) {
    // There was a problem calling native code
    print("Failed to invoke: '${err.message}'.");
  } catch (ex) {
    // Any other problem
    print("Problem: ${ex.toString()}");
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

class MonitoringNetworkImage extends CachedNetworkImage {
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
          progressIndicatorBuilder: (c, _, __) => loadingBuilder(c),
          errorWidget: (c, _, e) => errorBuilder(c, e),
          matchTextDirection: matchTextDirection,
          colorBlendMode: colorBlendMode,
          filterQuality: filterQuality,
          alignment: alignment,
          httpHeaders: headers,
          repeat: repeat,
          height: height,
          width: width,
          color: color,
          fit: fit,
        );
}

Image getImage(
  String path, {
  bool isFile = true,
  double width = 150,
  double height = 150,
  BoxFit fit = BoxFit.contain,
}) {
  isFile = isFile ?? false;
  if (isFile)
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
    );
  return Image.network(path, width: width, height: height, fit: fit);
}

class MonitoringNetworkImageProvider
    extends ImageProvider<MonitoringNetworkImageProvider> {
  /// Creates an ImageProvider which loads an image from the [url], using the [scale].
  /// When the image fails to load [errorListener] is called.
  const MonitoringNetworkImageProvider({
    @required this.imageUrl,
    this.scale = 1.0,
    this.errorListener,
    this.headers,
    this.cacheKey,
    this.width,
    this.height,
    @required this.placeholderAssetPath,
  })  : assert(imageUrl != null),
        assert(scale != null),
        assert(placeholderAssetPath != null);

  /// Web url of the image to load
  final String imageUrl;

  /// Cache key of the image to cache
  final String cacheKey;

  /// Target image width to which the image shall be scaled after decoding
  final int width;

  /// Target image height to which the image shall be scaled after decoding
  final int height;

  /// Scale of the image
  final double scale;

  /// Listener to be called when images fails to load.
  final void Function() errorListener;

  /// Set headers for the image provider, for example for authentication
  final Map<String, String> headers;

  /// Path to placeholder asset image file.
  /// Should be non-null so as to be loaded in case of network failure
  final String placeholderAssetPath;

  @override
  Future<MonitoringNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return SynchronousFuture<MonitoringNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(
      MonitoringNetworkImageProvider key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>(
          'Image provider: $this \n Image key: $key',
          this,
          style: DiagnosticsTreeStyle.errorProperty,
        );
      },
      chunkEvents: StreamController<ImageChunkEvent>().stream,
    );
  }

  Future<ui.Codec> _loadPlaceholderAsset() async {
    try {
      ByteData byteData = await rootBundle.load(placeholderAssetPath);
      Uint8List bytes = byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      return await ui.instantiateImageCodec(bytes,
          targetHeight: height, targetWidth: width);
    } catch (err) {
      print("Error!!:\t$err");
      return Future<ui.Codec>.error("Couldn't download or retrieve file");
    }
  }

  Future<ui.Codec> _loadAsync(MonitoringNetworkImageProvider key) async {
    assert(key == this);
    if (isStringEmpty(imageUrl)) return await _loadPlaceholderAsset();
    try {
      final manager = DefaultCacheManager();
      final file = await manager.getSingleFile(
        key.imageUrl,
        key: key.cacheKey,
        headers: headers,
      );
      return await ui.instantiateImageCodec(await file.readAsBytes(),
          targetHeight: height, targetWidth: width);
    } catch (err) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      print('NYWELE IMAGE PROVIDER ERROR!!\n$err');

      errorListener?.call();
    }
    return await _loadPlaceholderAsset();
  }

  @override
  bool operator ==(dynamic other) {
    if (other is MonitoringNetworkImageProvider) {
      var sameKey =
          (cacheKey ?? imageUrl) == (other.cacheKey ?? other.imageUrl);
      return sameKey && scale == other.scale;
    }
    return false;
  }

  @override
  int get hashCode => hashValues(imageUrl, scale);

  @override
  String toString() => '$runtimeType("$imageUrl", scale: $scale)';
}
