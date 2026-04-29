import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_models.dart';
import '../services/partner_api_client.dart';
import '../services/push_notification_service.dart';

enum AppStage { bootstrapping, onboarding, unauthenticated, authenticated }

class PartnerSessionController extends ChangeNotifier {
  PartnerSessionController({PartnerApiClient? api})
    : _api = api ?? PartnerApiClient();

  static const _tokenKey = 'partner_access_token';
  static const _tokenTypeKey = 'partner_token_type';
  static const _expiresInKey = 'partner_expires_in';
  static const _onboardingDoneKey = 'partner_onboarding_done';
  static const _lastPushTokenKey = 'partner_last_push_token';

  final PartnerApiClient _api;
  final PushNotificationService _pushNotifications = PushNotificationService();

  AppStage _stage = AppStage.bootstrapping;
  PartnerSession? _session;
  List<PartnerOffer> _offers = const [];
  List<PartnerDiscountTransaction> _history = const [];
  List<PartnerNotification> _notifications = const [];
  PartnerStats? _stats;
  String? _offersWarning;
  String? _pushWarning;
  int _unreadNotificationsCount = 0;
  bool _isAuthenticating = false;
  bool _isRefreshing = false;
  bool _isLoadingNotifications = false;
  bool _isSavingProfile = false;
  bool _isUpdatingPassword = false;

  AppStage get stage => _stage;
  PartnerSession? get session => _session;
  List<PartnerOffer> get offers => _offers;
  List<PartnerDiscountTransaction> get history => _history;
  List<PartnerNotification> get notifications => _notifications;
  PartnerStats? get stats => _stats;
  String? get offersWarning => _offersWarning;
  String? get pushWarning => _pushWarning;
  int get unreadNotificationsCount => _unreadNotificationsCount;
  bool get isAuthenticating => _isAuthenticating;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingNotifications => _isLoadingNotifications;
  bool get isSavingProfile => _isSavingProfile;
  bool get isUpdatingPassword => _isUpdatingPassword;
  String get baseUrl => _api.baseUrl;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(_onboardingDoneKey) ?? false;
    final token = prefs.getString(_tokenKey);

    if (token == null || token.isEmpty) {
      _stage = onboardingDone ? AppStage.unauthenticated : AppStage.onboarding;
      notifyListeners();
      return;
    }

    try {
      final currentUser = await _api.me(token);

      _session = PartnerSession(
        accessToken: token,
        tokenType: prefs.getString(_tokenTypeKey) ?? 'bearer',
        expiresIn: prefs.getInt(_expiresInKey) ?? 0,
        user: currentUser,
      );

      _stage = AppStage.authenticated;
      notifyListeners();

      await _initializePushNotifications();
      await refreshPartnerData(showLoader: true);
    } on ApiException {
      await _clearStoredSession(prefs);
      _stage = onboardingDone ? AppStage.unauthenticated : AppStage.onboarding;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
    _stage = AppStage.unauthenticated;
    notifyListeners();
  }

  Future<void> login({
    required String phoneOrEmail,
    required String password,
  }) async {
    _isAuthenticating = true;
    notifyListeners();

    try {
      final session = await _api.login(
        phoneOrEmail: phoneOrEmail,
        password: password,
      );

      final currentUser = await _api.me(session.accessToken);

      _session = PartnerSession(
        accessToken: session.accessToken,
        tokenType: session.tokenType,
        expiresIn: session.expiresIn,
        user: currentUser,
      );

      await _persistSession(session);

      _stage = AppStage.authenticated;
      notifyListeners();

      await _initializePushNotifications();
      await refreshPartnerData(showLoader: true);
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final token = _session?.accessToken;

    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final pushToken = prefs.getString(_lastPushTokenKey);
      if (pushToken != null && pushToken.isNotEmpty) {
        try {
          await _api.deletePushToken(token: token, fcmToken: pushToken);
        } catch (_) {
          // The local state is still cleared if push-token revocation fails.
        }
      }

      try {
        await _api.logout(token);
      } catch (_) {
        // The local state is still cleared if server logout fails.
      }
    }

    _session = null;
    _offers = const [];
    _history = const [];
    _notifications = const [];
    _stats = null;
    _offersWarning = null;
    _pushWarning = null;
    _unreadNotificationsCount = 0;
    await _clearStoredSession();
    _stage = AppStage.unauthenticated;
    notifyListeners();
  }

  Future<void> refreshPartnerData({
    bool showLoader = false,
    DateTime? statsDateFrom,
    DateTime? statsDateTo,
  }) async {
    final currentSession = _session;
    if (currentSession == null) {
      return;
    }

    if (showLoader) {
      _isRefreshing = true;
      notifyListeners();
    }

    try {
      final user = await _api.me(currentSession.accessToken);
      List<PartnerOffer> offers = const [];
      List<PartnerDiscountTransaction> history = const [];
      PartnerStats? stats;
      String? offersWarning;

      try {
        offers = await _api.fetchOffers(currentSession.accessToken);
      } on ApiException catch (error) {
        offersWarning = error.message;
      }

      history = await _api.fetchHistory(currentSession.accessToken);
      stats = await _api.fetchStats(
        currentSession.accessToken,
        dateFrom: statsDateFrom,
        dateTo: statsDateTo,
      );
      try {
        await refreshNotifications();
      } catch (_) {
        // The dashboard stays usable even if notifications are temporarily unavailable.
      }

      _session = PartnerSession(
        accessToken: currentSession.accessToken,
        tokenType: currentSession.tokenType,
        expiresIn: currentSession.expiresIn,
        user: user,
      );
      _offers = offers;
      _history = history;
      _stats = stats;
      _offersWarning = offersWarning;
      notifyListeners();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<VerifiedDiscountCard> verifyCard({
    required String cardUuid,
    int? offerId,
  }) {
    return _api.verifyCard(
      token: _session!.accessToken,
      cardUuid: cardUuid,
      offerId: offerId,
    );
  }

  Future<PartnerDiscountTransaction> applyDiscount({
    required String cardUuid,
    required int offerId,
    double? originalAmount,
    double? discountAmount,
    double? finalAmount,
    String? note,
  }) async {
    final transaction = await _api.applyDiscount(
      token: _session!.accessToken,
      cardUuid: cardUuid,
      offerId: offerId,
      originalAmount: originalAmount,
      discountAmount: discountAmount,
      finalAmount: finalAmount,
      note: note,
    );

    await refreshPartnerData();
    return transaction;
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    final currentSession = _session;
    if (currentSession == null) {
      return;
    }

    _isSavingProfile = true;
    notifyListeners();

    try {
      final user = await _api.updateProfile(
        token: currentSession.accessToken,
        name: name,
        email: email,
        phone: phone,
      );

      _session = PartnerSession(
        accessToken: currentSession.accessToken,
        tokenType: currentSession.tokenType,
        expiresIn: currentSession.expiresIn,
        user: user,
      );

      notifyListeners();
    } finally {
      _isSavingProfile = false;
      notifyListeners();
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    final currentSession = _session;
    if (currentSession == null) {
      return;
    }

    _isUpdatingPassword = true;
    notifyListeners();

    try {
      await _api.updatePassword(
        token: currentSession.accessToken,
        currentPassword: currentPassword,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
    } finally {
      _isUpdatingPassword = false;
      notifyListeners();
    }
  }

  Future<void> refreshNotifications({bool showLoader = false}) async {
    final currentSession = _session;
    if (currentSession == null) {
      return;
    }

    if (showLoader) {
      _isLoadingNotifications = true;
      notifyListeners();
    }

    try {
      final result = await _api.fetchNotifications(currentSession.accessToken);
      _notifications = result.notifications;
      _unreadNotificationsCount = result.unreadCount;
      notifyListeners();
    } finally {
      _isLoadingNotifications = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    final currentSession = _session;
    if (currentSession == null) {
      return;
    }

    await _api.markNotificationAsRead(
      token: currentSession.accessToken,
      notificationId: notificationId,
    );
    await refreshNotifications();
  }

  Future<void> markAllNotificationsAsRead() async {
    final currentSession = _session;
    if (currentSession == null) {
      return;
    }

    await _api.markAllNotificationsAsRead(currentSession.accessToken);
    await refreshNotifications();
  }

  Future<void> _initializePushNotifications() async {
    final currentSession = _session;
    if (currentSession == null) {
      return;
    }

    final result = await _pushNotifications.initialize(
      onToken: (details) async {
        final saveResponse = await _api.registerPushToken(
          token: currentSession.accessToken,
          fcmToken: details.token,
          platform: details.platform,
          deviceName: details.deviceName,
          appVersion: details.appVersion,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastPushTokenKey, details.token);
        _logPush('token_save_response', saveResponse);
      },
      onMessage: (_) => refreshNotifications(),
    );

    _logPush('configuration_result', result.toLogPayload());

    _pushWarning = result.configured
        ? null
        : 'Notifications push non configurees sur ce build.';
    notifyListeners();
  }

  void _logPush(String event, Map<String, dynamic> payload) {
    debugPrint('[MYSIGNAL_PUSH] $event $payload');
  }

  Future<void> _persistSession(PartnerSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
    await prefs.setString(_tokenKey, session.accessToken);
    await prefs.setString(_tokenTypeKey, session.tokenType);
    await prefs.setInt(_expiresInKey, session.expiresIn);
  }

  Future<void> _clearStoredSession([SharedPreferences? prefs]) async {
    final storage = prefs ?? await SharedPreferences.getInstance();
    await storage.remove(_tokenKey);
    await storage.remove(_tokenTypeKey);
    await storage.remove(_expiresInKey);
    await storage.remove(_lastPushTokenKey);
  }

  @override
  void dispose() {
    unawaited(_pushNotifications.dispose());
    super.dispose();
  }
}
