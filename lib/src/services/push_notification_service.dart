import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushTokenDetails {
  const PushTokenDetails({
    required this.token,
    required this.platform,
    required this.deviceName,
    required this.appVersion,
  });

  final String token;
  final String platform;
  final String deviceName;
  final String appVersion;
}

class PushConfigurationResult {
  const PushConfigurationResult({
    required this.configured,
    required this.permissionStatus,
    this.token,
    this.error,
  });

  final bool configured;
  final String permissionStatus;
  final String? token;
  final String? error;

  Map<String, dynamic> toLogPayload() {
    return <String, dynamic>{
      'configured': configured,
      'permission_status': permissionStatus,
      'has_token': token != null && token!.isNotEmpty,
      'token_preview': _previewToken(token),
      if (error != null) 'error': error,
    };
  }
}

class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging})
    : _messaging = messaging;

  static const _channel = AndroidNotificationChannel(
    'mysignal_partner_scan',
    'Notifications MySignal Scan',
    description: 'Notifications pour les utilisateurs partenaires scanneurs.',
    importance: Importance.high,
  );

  static const _defaultAndroidApiKey =
      'AIzaSyD_Rgpu5kT4X4eZbdF-uOum4qfh_bF1jVE';
  static const _defaultAndroidAppId =
      '1:159467027690:android:4b108f84cfe7b8c7ceeb93';
  static const _defaultMessagingSenderId = '159467027690';
  static const _defaultProjectId = 'my-signal-1b9d9';
  static const _defaultStorageBucket = 'my-signal-1b9d9.firebasestorage.app';

  static const _apiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: _defaultAndroidApiKey,
  );
  static const _appId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: _defaultAndroidAppId,
  );
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: _defaultMessagingSenderId,
  );
  static const _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: _defaultProjectId,
  );
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: _defaultStorageBucket,
  );

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  bool _initialized = false;
  bool _localNotificationsInitialized = false;

  Future<PushConfigurationResult> initialize({
    required Future<void> Function(PushTokenDetails details) onToken,
    Future<void> Function(RemoteMessage message)? onMessage,
  }) async {
    if (!_hasFirebaseConfig) {
      return const PushConfigurationResult(
        configured: false,
        permissionStatus: 'not_configured',
        error: 'Missing Firebase Android configuration.',
      );
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: _apiKey,
            appId: _appId,
            messagingSenderId: _messagingSenderId,
            projectId: _projectId,
            storageBucket: _storageBucket,
          ),
        );
      }

      final messaging = _messaging ?? FirebaseMessaging.instance;
      _messaging = messaging;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await _initializeLocalNotifications();

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await onToken(_detailsForToken(token));
      }

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) {
        if (token.isNotEmpty) {
          unawaited(onToken(_detailsForToken(token)));
        }
      });

      if (!_initialized) {
        await _foregroundMessageSubscription?.cancel();
        _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
          message,
        ) {
          unawaited(_showForegroundNotification(message));

          if (onMessage != null) {
            unawaited(onMessage(message));
          }
        });
      }

      _initialized = true;
      return PushConfigurationResult(
        configured: true,
        permissionStatus: settings.authorizationStatus.name,
        token: token,
      );
    } catch (error) {
      return PushConfigurationResult(
        configured: false,
        permissionStatus: 'error',
        error: error.toString(),
      );
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
  }

  bool get _hasFirebaseConfig {
    return _apiKey.isNotEmpty &&
        _appId.isNotEmpty &&
        _messagingSenderId.isNotEmpty &&
        _projectId.isNotEmpty;
  }

  PushTokenDetails _detailsForToken(String token) {
    return PushTokenDetails(
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
      deviceName:
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      appVersion: 'app-scan',
    );
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _localNotificationsInitialized = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] ?? 'MySignal';
    final body = notification?.body ?? data['body'] ?? '';

    debugPrint(
      '[MYSIGNAL_PUSH] foreground_message ${_remoteMessageLog(message)}',
    );

    if (title.trim().isEmpty && body.trim().isEmpty) {
      return;
    }

    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data.isEmpty ? null : data.toString(),
    );
  }
}

Map<String, dynamic> _remoteMessageLog(RemoteMessage message) {
  return <String, dynamic>{
    'message_id': message.messageId,
    'title': message.notification?.title ?? message.data['title'],
    'has_body':
        (message.notification?.body?.isNotEmpty ?? false) ||
        ((message.data['body'] as String?)?.isNotEmpty ?? false),
    'data': message.data,
  };
}

String _previewToken(String? token) {
  if (token == null || token.isEmpty) {
    return '';
  }

  if (token.length <= 18) {
    return token;
  }

  return '${token.substring(0, 10)}...${token.substring(token.length - 6)}';
}
