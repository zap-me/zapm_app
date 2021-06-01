# zap_app

![Flutter](https://github.com/zap-me/zapm_app/workflows/Flutter/badge.svg)

zap.me test app

## Configuring features

See `config.dart`

## Changing bundle-id/app-id/application-name

See https://pub.dev/packages/rename

## Changing package icons

See https://pub.dev/packages/flutter_launcher_icons

## Changing App Links / Deep Links (Android) and/or Universal Links / Custom URL Schemes (iOS)

See https://pub.dev/packages/uni_links

## Changing Firebase account

See https://firebase.google.com/docs/flutter/setup

Android: change the android/app/google-services.json file
iOS: change the ios/Runner/GoogleService-Info.plist file

### Update Android push notification icon

 - Generate icon resource: https://romannurik.github.io/AndroidAssetStudio/icons-notification.html
 - Update Manifest: https://firebase.google.com/docs/cloud-messaging/android/client#manifest

 ### Authorize iOS app on APNS

  - Upload APNS auth key https://firebase.google.com/docs/cloud-messaging/ios/client#upload_your_apns_authentication_key

## accessing location from webview

```
/*
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0">
    </head>
    <body>
      ....
      <script>
window.addEventListener("flutterInAppWebViewPlatformReady", function(event) {
  if (typeof window.flutter_inappwebview !== "undefined") {
    window.flutter_inappwebview.callHandler('getLocation').then(function(loc) {
      console.log(JSON.stringify(loc));
      alert(JSON.stringify(loc));
    });
  }
});
      </script>
    </body>
</html>
```