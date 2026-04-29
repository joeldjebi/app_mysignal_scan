import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/api_models.dart';

class PartnerApiClient {
  PartnerApiClient({String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://my-signal.online/api',
          );

  final String baseUrl;

  Future<PartnerSession> login({
    required String phoneOrEmail,
    required String password,
  }) async {
    final payload = <String, dynamic>{
      'phone': phoneOrEmail.trim(),
      'password': password,
    };

    _logLogin('payload', _sanitizeLogPayload(payload));

    final json = await _request(
      method: 'POST',
      path: '/v1/partner/auth/login',
      body: payload,
      logTag: 'PARTNER_LOGIN',
    );

    _logLogin('response', _sanitizeLogPayload(json));

    return PartnerSession.fromJson(_dataMap(json));
  }

  Future<PartnerUser> me(String token) async {
    final json = await _request(
      method: 'GET',
      path: '/v1/partner/me',
      token: token,
    );

    return PartnerUser.fromJson(
      _dataMap(json)['user'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<void> logout(String token) async {
    await _request(
      method: 'POST',
      path: '/v1/partner/auth/logout',
      token: token,
    );
  }

  Future<PartnerUser> updateProfile({
    required String token,
    required String name,
    required String email,
    required String phone,
  }) async {
    final json = await _request(
      method: 'PUT',
      path: '/v1/partner/profile',
      token: token,
      body: <String, dynamic>{
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
      },
    );

    return PartnerUser.fromJson(
      _dataMap(json)['user'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<void> updatePassword({
    required String token,
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _request(
      method: 'PUT',
      path: '/v1/partner/profile/password',
      token: token,
      body: <String, dynamic>{
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  Future<List<PartnerOffer>> fetchOffers(String token) async {
    final json = await _request(
      method: 'GET',
      path: '/v1/partner/discount-offers',
      token: token,
    );

    final offers = _dataMap(json)['offers'] as List<dynamic>? ?? const [];

    return offers
        .whereType<Map<String, dynamic>>()
        .map(PartnerOffer.fromJson)
        .toList();
  }

  Future<VerifiedDiscountCard> verifyCard({
    required String token,
    required String cardUuid,
    int? offerId,
  }) async {
    final payload = <String, dynamic>{'card_uuid': cardUuid.trim()};

    if (offerId != null) {
      payload['offer_id'] = offerId;
    }

    _logScan('verify_payload', _sanitizeLogPayload(payload));

    final json = await _request(
      method: 'POST',
      path: '/v1/partner/discount-cards/verify',
      token: token,
      body: payload,
      logTag: 'SCAN_VERIFY',
    );

    _logScan('verify_response', _sanitizeLogPayload(json));

    return VerifiedDiscountCard.fromJson(_dataMap(json));
  }

  Future<PartnerDiscountTransaction> applyDiscount({
    required String token,
    required String cardUuid,
    required int offerId,
    double? originalAmount,
    double? discountAmount,
    double? finalAmount,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'card_uuid': cardUuid.trim(),
      'offer_id': offerId,
      'metadata': <String, dynamic>{'source': 'flutter-app-scan'},
    };

    if (originalAmount != null) {
      payload['original_amount'] = originalAmount;
    }

    if (discountAmount != null) {
      payload['discount_amount'] = discountAmount;
    }

    if (finalAmount != null) {
      payload['final_amount'] = finalAmount;
    }

    if (note?.trim().isNotEmpty ?? false) {
      (payload['metadata'] as Map<String, dynamic>)['note'] = note!.trim();
    }

    _logScan('discount_payload', _sanitizeLogPayload(payload));

    final json = await _request(
      method: 'POST',
      path: '/v1/partner/discount-transactions',
      token: token,
      body: payload,
      logTag: 'DISCOUNT_APPLY',
    );

    _logScan('discount_response', _sanitizeLogPayload(json));

    final data = _dataMap(json);
    return PartnerDiscountTransaction.fromJson(
      data['transaction'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<List<PartnerDiscountTransaction>> fetchHistory(String token) async {
    final json = await _request(
      method: 'GET',
      path: '/v1/partner/mobile/history',
      token: token,
    );

    final transactions =
        _dataMap(json)['transactions'] as List<dynamic>? ?? const [];

    return transactions
        .whereType<Map<String, dynamic>>()
        .map(PartnerDiscountTransaction.fromJson)
        .toList();
  }

  Future<PartnerStats> fetchStats(
    String token, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, String>{};

    if (dateFrom != null) {
      query['date_from'] = _formatDateParam(dateFrom);
    }

    if (dateTo != null) {
      query['date_to'] = _formatDateParam(dateTo);
    }

    final path = Uri(
      path: '/v1/partner/mobile/stats',
      queryParameters: query.isEmpty ? null : query,
    ).toString();

    final json = await _request(method: 'GET', path: path, token: token);

    final stats = _dataMap(json)['stats'] as Map<String, dynamic>? ?? const {};
    return PartnerStats.fromJson(stats);
  }

  Future<Map<String, dynamic>> registerPushToken({
    required String token,
    required String fcmToken,
    required String platform,
    required String deviceName,
    required String appVersion,
  }) async {
    final json = await _request(
      method: 'POST',
      path: '/v1/partner/push-tokens',
      token: token,
      body: <String, dynamic>{
        'token': fcmToken,
        'platform': platform,
        'device_name': deviceName,
        'app_version': appVersion,
      },
    );

    return _dataMap(json);
  }

  Future<void> deletePushToken({
    required String token,
    required String fcmToken,
  }) async {
    await _request(
      method: 'DELETE',
      path: '/v1/partner/push-tokens',
      token: token,
      body: <String, dynamic>{'token': fcmToken},
    );
  }

  Future<PartnerNotificationsResult> fetchNotifications(
    String token, {
    int limit = 30,
  }) async {
    final json = await _request(
      method: 'GET',
      path: '/v1/partner/notifications?limit=$limit',
      token: token,
    );

    final data = _dataMap(json);
    final notifications = data['notifications'] as List<dynamic>? ?? const [];

    return PartnerNotificationsResult(
      notifications: notifications
          .whereType<Map<String, dynamic>>()
          .map(PartnerNotification.fromJson)
          .toList(),
      unreadCount: data['unread_count'] as int? ?? 0,
    );
  }

  Future<PartnerNotification> markNotificationAsRead({
    required String token,
    required int notificationId,
  }) async {
    final json = await _request(
      method: 'POST',
      path: '/v1/partner/notifications/$notificationId/read',
      token: token,
    );

    return PartnerNotification.fromJson(
      _dataMap(json)['notification'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<void> markAllNotificationsAsRead(String token) async {
    await _request(
      method: 'POST',
      path: '/v1/partner/notifications/read-all',
      token: token,
    );
  }

  String _formatDateParam(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    String? token,
    Map<String, dynamic>? body,
    String? logTag,
  }) async {
    final client = HttpClient();

    try {
      final url = Uri.parse('$baseUrl$path');
      final request = await client.openUrl(method, url);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      if (body != null) {
        final encodedBody = utf8.encode(jsonEncode(body));
        request.contentLength = encodedBody.length;
        request.add(encodedBody);

        if (logTag != null) {
          debugPrint(
            '[MYSIGNAL_$logTag] request {method: $method, url: $url, body_bytes: ${encodedBody.length}, content_type: application/json}',
          );
        }
      } else if (logTag != null) {
        debugPrint(
          '[MYSIGNAL_$logTag] request {method: $method, url: $url, body_bytes: 0}',
        );
      }

      final response = await request.close();
      final content = await response.transform(utf8.decoder).join();
      final decoded = content.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(content) as Map<String, dynamic>;

      if (logTag != null) {
        debugPrint(
          '[MYSIGNAL_$logTag] status ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (logTag != null) {
          debugPrint(
            '[MYSIGNAL_$logTag] error_response ${_sanitizeLogPayload(decoded)}',
          );
        }

        throw ApiException(
          _extractMessage(decoded, response.statusCode),
          errors: _extractErrors(decoded),
        );
      }

      return decoded;
    } on SocketException {
      if (logTag != null) {
        debugPrint('[MYSIGNAL_$logTag] connection_status socket_error');
      }
      throw ApiException(
        "Impossible de joindre l'API. Verifie l URL du serveur et la connexion reseau.",
      );
    } on HandshakeException {
      if (logTag != null) {
        debugPrint('[MYSIGNAL_$logTag] connection_status tls_error');
      }
      throw ApiException(
        'Connexion securisee invalide. Verifie le certificat du serveur.',
      );
    } on HttpException catch (error) {
      if (logTag != null) {
        debugPrint('[MYSIGNAL_$logTag] connection_status http_error');
      }
      throw ApiException(_localizeMessage(error.message));
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic> json) {
    return json['data'] as Map<String, dynamic>? ?? const {};
  }

  String _extractMessage(Map<String, dynamic> json, int statusCode) {
    final message = json['message'];

    if (message is String && message.trim().isNotEmpty) {
      return _localizeMessage(message);
    }

    final errors = _extractErrors(json);
    if (errors.isNotEmpty) {
      return errors.values.first.first;
    }

    return 'Erreur API ($statusCode).';
  }

  Map<String, List<String>> _extractErrors(Map<String, dynamic> json) {
    final rawErrors = json['errors'] as Map<String, dynamic>? ?? const {};

    return rawErrors.map((key, value) {
      final messages = value is List<dynamic>
          ? value.map((item) => _localizeMessage('$item')).toList()
          : <String>[_localizeMessage('$value')];

      return MapEntry(key, messages);
    });
  }

  String _localizeMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'Une erreur est survenue.';
    }

    final normalized = trimmed.toLowerCase();

    const exactTranslations = <String, String>{
      'invalid credentials.': 'Numero de telephone ou mot de passe incorrecte',
      'invalid credentials': 'Numero de telephone ou mot de passe incorrecte',
      'unauthorized': 'Acces non autorise.',
      'forbidden': 'Acces refuse.',
      'the provided credentials are incorrect.':
          'Numero de telephone ou mot de passe incorrecte',
      'these credentials do not match our records.':
          'Numero de telephone ou mot de passe incorrecte',
      'user not found.': 'Aucun compte correspondant n a ete trouve.',
      'user not found': 'Aucun compte correspondant n a ete trouve.',
      'too many attempts. please try again later.':
          'Trop de tentatives. Reessaie plus tard.',
      'server error': 'Erreur serveur. Reessaie dans un instant.',
    };

    final exact = exactTranslations[normalized];
    if (exact != null) {
      return exact;
    }

    if (normalized.contains('invalid credential') ||
        normalized.contains('incorrect password') ||
        normalized.contains('wrong password') ||
        normalized.contains('bad credentials') ||
        normalized.contains('credentials do not match')) {
      return 'Numero de telephone ou mot de passe incorrecte';
    }

    if (normalized.contains('too many attempt') ||
        normalized.contains('too many request')) {
      return 'Trop de tentatives. Reessaie plus tard.';
    }

    if (normalized.contains('user not found') ||
        normalized.contains('account not found')) {
      return 'Aucun compte correspondant n a ete trouve.';
    }

    var localized = trimmed;

    final replacements = <Pattern, String>{
      RegExp(r'\bThe given data was invalid\.?', caseSensitive: false):
          'Les informations saisies sont invalides.',
      RegExp(r'\bThe phone field is required\.?', caseSensitive: false):
          'Le numero est obligatoire.',
      RegExp(r'\bThe password field is required\.?', caseSensitive: false):
          'Le mot de passe est obligatoire.',
      RegExp(r'\bThe phone field must be a string\.?', caseSensitive: false):
          'Le numero saisi est invalide.',
      RegExp(r'\bThe password field must be a string\.?', caseSensitive: false):
          'Le mot de passe saisi est invalide.',
      RegExp(r'\bThe selected [\w_ -]+ is invalid\.?', caseSensitive: false):
          'La valeur selectionnee est invalide.',
      RegExp(r'\bThis action is unauthorized\.?', caseSensitive: false):
          'Cette action n est pas autorisee.',
    };

    replacements.forEach((pattern, replacement) {
      localized = localized.replaceAll(pattern, replacement);
    });

    return localized;
  }

  void _logLogin(String event, Map<String, dynamic> payload) {
    debugPrint('[MYSIGNAL_PARTNER_LOGIN] $event $payload');
  }

  void _logScan(String event, Map<String, dynamic> payload) {
    debugPrint('[MYSIGNAL_SCAN] $event $payload');
  }
}

Map<String, dynamic> _sanitizeLogPayload(Map<String, dynamic> payload) {
  return payload.map((key, value) {
    final normalizedKey = key.toLowerCase();

    if (normalizedKey.contains('password')) {
      return MapEntry(key, '********');
    }

    if (normalizedKey.contains('token')) {
      return MapEntry(key, _previewSecret('$value'));
    }

    if (value is Map<String, dynamic>) {
      return MapEntry(key, _sanitizeLogPayload(value));
    }

    if (value is List) {
      return MapEntry(
        key,
        value
            .map(
              (item) => item is Map<String, dynamic>
                  ? _sanitizeLogPayload(item)
                  : item,
            )
            .toList(),
      );
    }

    return MapEntry(key, value);
  });
}

String _previewSecret(String value) {
  if (value.isEmpty) {
    return '';
  }

  if (value.length <= 18) {
    return value;
  }

  return '${value.substring(0, 10)}...${value.substring(value.length - 6)}';
}
