import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:location/location.dart';

class Webview extends StatefulWidget {
  final String url;

  Webview(this.url);

  @override
  _WebviewState createState() => _WebviewState();
}

class _WebviewState extends State<Webview> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (Platform.isAndroid)
      AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
    var options = InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          useShouldOverrideUrlLoading: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
        android: AndroidInAppWebViewOptions(
          useHybridComposition: true,
          useWideViewPort: true,
        ),
        ios: IOSInAppWebViewOptions(
          allowsInlineMediaPlayback: true,
          enableViewportScale: true,
        ));
    return InAppWebView(
      initialUrlRequest: URLRequest(url: Uri.parse(widget.url)),
      initialOptions: options,
      androidOnPermissionRequest: (controller, origin, resources) async {
        return PermissionRequestResponse(
            resources: resources,
            action: PermissionRequestResponseAction.GRANT);
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        var url = navigationAction.request.url!.toString();
        if (!url.startsWith(widget.url)) {
          launch(url);
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onWebViewCreated: (InAppWebViewController controller) {
        controller.addJavaScriptHandler(
            handlerName: 'getLocation',
            callback: (args) async {
              var location = Location();
              if (!await location.serviceEnabled() &&
                  !await location.requestService()) return null;
              var granted = await location.hasPermission();
              if (granted == PermissionStatus.denied) {
                granted = await location.requestPermission();
                if (granted != PermissionStatus.granted) return null;
              }
              var loc = await location.getLocation();
              return {'lat': loc.latitude, 'long': loc.longitude};
            });
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
