import 'dart:convert';
import 'dart:io';

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
    final isEmail = phoneOrEmail.contains('@');

    final json = await _request(
      method: 'POST',
      path: '/v1/partner/auth/login',
      body: <String, dynamic>{
        isEmail ? 'e-mail' : 'phone': phoneOrEmail.trim(),
        'password': password,
      },
    );

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

    final json = await _request(
      method: 'POST',
      path: '/v1/partner/discount-cards/verify',
      token: token,
      body: payload,
    );

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

    final json = await _request(
      method: 'POST',
      path: '/v1/partner/discount-transactions',
      token: token,
      body: payload,
    );

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
  }) async {
    final client = HttpClient();

    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      if (body != null) {
        request.add(utf8.encode(jsonEncode(body)));
      }

      final response = await request.close();
      final content = await response.transform(utf8.decoder).join();
      final decoded = content.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(content) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _extractMessage(decoded, response.statusCode),
          errors: _extractErrors(decoded),
        );
      }

      return decoded;
    } on SocketException {
      throw ApiException(
        "Impossible de joindre l'API. Verifie l URL du serveur et la connexion reseau.",
      );
    } on HandshakeException {
      throw ApiException(
        'Connexion securisee invalide. Verifie le certificat du serveur.',
      );
    } on HttpException catch (error) {
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
      'invalid credentials.': 'Numero ou mot de passe incorrect.',
      'invalid credentials': 'Numero ou mot de passe incorrect.',
      'unauthorized': 'Acces non autorise.',
      'forbidden': 'Acces refuse.',
      'the provided credentials are incorrect.':
          'Numero ou mot de passe incorrect.',
      'these credentials do not match our records.':
          'Numero ou mot de passe incorrect.',
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
      return 'Numero ou mot de passe incorrect.';
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
}
