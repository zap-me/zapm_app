import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:zapdart/utils.dart';

Future<dynamic> fcmBackgroundMessageHandler(Map<String, dynamic> message) async {
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

class FCM  {
  final BuildContext context;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  String _token;
  Stream<String> _tokenStream;
  
  FCM(this.context) {
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
        print("onMessage: $message");
        if (message.containsKey('notification')) {
          var title = message['notification']['title'];
          var body = message['notification']['body'];
          alert(context, title, body);
        }
      },
      onBackgroundMessage: fcmBackgroundMessageHandler,
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
        //TODO: _navigateToItemDetail(message);
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
        //TODO: _navigateToItemDetail(message);
      },
    );
  }

  void setToken(String token) {
    print('FCM Token: $token');
    _token = token;
  }
}