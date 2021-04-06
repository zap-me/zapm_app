import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:zapdart/utils.dart';

Future<dynamic> fcmBackgroundMessageHandler(
    Map<String, dynamic> message) async {
  if (message.containsKey('data')) {
    // handle data message
    final dynamic data = message['data'];
    print('fcmBackgroundMessageHander data: $data');
  }

  if (message.containsKey('notification')) {
    // handle notification message
    final dynamic notification = message['notification'];
    print('fcmBackgroundMessageHander notification: $notification');
  }
}

class FCM {
  final BuildContext _context;
  final String _premioStageIndexUrl;
  final String _premioStageName;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  String _token;
  Stream<String> _tokenStream;

  FCM(this._context, this._premioStageIndexUrl, this._premioStageName) {
    initFirebase();
  }

  Future<Null> initFirebase() async {
    await Firebase.initializeApp();

    // monitor FCM token
    _firebaseMessaging.getToken().then(setToken);
    _tokenStream = _firebaseMessaging.onTokenRefresh;
    _tokenStream.listen(setToken);

    // configure push notification stuff
    _firebaseMessaging.requestNotificationPermissions();
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("initFirebase onMessage: $message");
        handleMessage(message);
      },
      // doesnt work on iOS: https://github.com/FirebaseExtended/flutterfire/issues/116#issuecomment-537516766
      onBackgroundMessage: Platform.isIOS ? null : fcmBackgroundMessageHandler,
      onLaunch: (Map<String, dynamic> message) async {
        print("initFirebase onLaunch: $message");
        handleMessage(message);
      },
      onResume: (Map<String, dynamic> message) async {
        print("initFirebase onResume: $message");
        handleMessage(message);
      },
    );
  }

  void handleMessage(Map<String, dynamic> message) {
    if (message.containsKey('notification')) {
      var title = message['notification']['title'];
      var body = message['notification']['body'];
      if (title != null && body != null) alert(_context, title, body);
    }
    if (message.containsKey('aps')) {
      var aps = message['aps'] as Map<dynamic, dynamic>;
      if (aps.containsKey('alert')) {
        var title = aps['alert']['title'];
        var body = aps['alert']['body'];
        if (title != null && body != null) alert(_context, title, body);
      }
    }
  }

  void setToken(String token) async {
    print('FCM Token: $token');
    _token = token;
    // try and register on premio stage for push notifications
    if (_premioStageIndexUrl != null && _premioStageName != null) {
      try {
        var ms = DateTime.now().millisecondsSinceEpoch;
        var response = await get_(_premioStageIndexUrl +
            '?cache=$ms'); // try to foil caches with timestamp in url
        if (response.statusCode != 200) {
          print(
              'error: failed to get premio stage index (${response.statusCode} - $_premioStageIndexUrl)');
          return;
        }
        var premioStages = jsonDecode(response.body) as Map<String, dynamic>;
        if (premioStages.containsKey(_premioStageName)) {
          var url =
              premioStages[_premioStageName] + '/push_notifications_register';
          var response = await post(url, {'registration_token': token});
          if (response.statusCode != 200)
            print(
                'error: failed to regsiter for push notifications (${response.statusCode} - $url)');
        }
      } catch (e) {
        print('error: failed to register for push notifications - $e');
      }
    }
  }

  String getToken() {
    return _token;
  }
}
