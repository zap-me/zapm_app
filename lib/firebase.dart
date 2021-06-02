import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:location/location.dart';

import 'package:zapdart/utils.dart';

class FCM {
  final BuildContext _context;
  final String? _premioStageIndexUrl;
  final String? _premioStageName;
  String? _token;

  FCM(this._context, this._premioStageIndexUrl, this._premioStageName) {
    initFirebase();
  }

  Future<Null> initFirebase() async {
    // exit if we are on a degoogleized android
    if (Platform.isAndroid) {
      var avail = await GoogleApiAvailability.instance
          .checkGooglePlayServicesAvailability();
      if (avail != GooglePlayServicesAvailability.success) return;
    }

    await Firebase.initializeApp();

    // monitor FCM token
    FirebaseMessaging.instance.getToken().then(setToken);
    FirebaseMessaging.instance.onTokenRefresh.listen(setToken);

    // configure push notification stuff
    try {
      FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage? message) => handleMessage(message));
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("initFirebase onMessage: $message");
        handleMessage(message);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("initFirebase onMessageOpenedApp: $message");
        handleMessage(message);
      });
      FirebaseMessaging.onBackgroundMessage(
          (RemoteMessage message) => handleBackgroundMessage(message));
    } on TypeError catch (e) {
      print(e);
    }
  }

  void handleMessage(RemoteMessage? message) async {
    if (message == null) return;
    if (message.data.containsKey('notification')) {
      var title = message.data['notification']['title'];
      var body = message.data['notification']['body'];
      if (title != null && body != null) alert(_context, title, body);
    }
    if (message.data.containsKey('aps')) {
      var aps = message.data['aps'] as Map<dynamic, dynamic>;
      if (aps.containsKey('alert')) {
        var title = aps['alert']['title'];
        var body = aps['alert']['body'];
        if (title != null && body != null) alert(_context, title, body);
      }
    }
    if (message.notification?.title != null &&
        message.notification?.body != null) {
      var title = message.notification!.title!;
      var body = message.notification!.body!;
      var imageUrl = message.notification!.apple?.imageUrl;
      if (imageUrl == null) imageUrl = message.notification!.android?.imageUrl;
      var html = message.data.containsKey('html') ? message.data['html'].toString() : '';
      if (html.isNotEmpty) {
        alert(_context, title, Html(data: html));
      } else if (imageUrl != null) {
        var image = Image.network(imageUrl);
        var content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [image, Divider(), Text(body)]);
        alert(_context, title, content);
      } else
        alert(_context, title, body);
    }
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    if (message.data.containsKey('data')) {
      // handle data message
      final dynamic data = message.data['data'];
      print('handleBackgroundMessage data: $data');
    }

    if (message.data.containsKey('notification')) {
      // handle notification message
      final dynamic notification = message.data['notification'];
      print('handleBackgroundMessage notification: $notification');
    }

    handleMessage(message);
  }

  Future<LocationData?> getLocation() async {
    // get location
    var location = Location();
    if (!await location.serviceEnabled() &&
        !await location.requestService()) return null;
    var granted = await location.hasPermission();
    if (granted == PermissionStatus.denied) {
      granted = await location.requestPermission();
      if (granted != PermissionStatus.granted) return null;
    }
    return await location.getLocation();
  }

  Future<bool> registerPushNotifications({double? lat, double? long}) async {
    if (_token == null) return false;
    // try and register on premio stage for push notifications
    if (_premioStageIndexUrl != null && _premioStageName != null) {
      try {
        var ms = DateTime.now().millisecondsSinceEpoch;
        var response = await httpGet(Uri.parse(_premioStageIndexUrl! +
            '?cache=$ms')); // try to foil caches with timestamp in url
        if (response.statusCode != 200) {
          print(
              'error: failed to get premio stage index (${response.statusCode} - $_premioStageIndexUrl)');
          return false;
        }
        var premioStages = jsonDecode(response.body) as Map<String, dynamic>;
        if (premioStages.containsKey(_premioStageName)) {
          if (lat == null || long == null) {
            var loc = await getLocation();
            lat = loc?.latitude;
            long = loc?.longitude;
          }
          // call push notifcations register
          var url =
              premioStages[_premioStageName] + '/push_notifications_register';
          var response =
              await httpPost(Uri.parse(url), {'registration_token': _token, 'latitude': lat, 'longitude': long});
          if (response.statusCode != 200)
            print(
                'error: failed to regsiter for push notifications (${response.statusCode} - $url)');
          else
            return true;
        }
      } catch (e) {
        print('error: failed to register for push notifications - $e');
      }
    }
    return false;
  }

  void setToken(String? token) async {
    print('FCM Token: $token');
    _token = token;
    registerPushNotifications();
  }

  String? getToken() {
    return _token;
  }
}
