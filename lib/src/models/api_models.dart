class ApiException implements Exception {
  ApiException(this.message, {this.errors = const {}});

  final String message;
  final Map<String, List<String>> errors;

  @override
  String toString() => message;
}

class PartnerSession {
  const PartnerSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final PartnerUser user;

  factory PartnerSession.fromJson(Map<String, dynamic> json) {
    return PartnerSession(
      accessToken: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 0,
      user: PartnerUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class PartnerUser {
  const PartnerUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
    required this.organization,
    required this.roles,
    required this.permissions,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String status;
  final PartnerOrganization? organization;
  final List<String> roles;
  final List<String> permissions;
  final String? createdAt;

  factory PartnerUser.fromJson(Map<String, dynamic> json) {
    final rolesJson = json['roles'] as List<dynamic>? ?? const [];
    final permissionsJson = json['permissions'] as List<dynamic>? ?? const [];

    return PartnerUser(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      status: json['status'] as String? ?? '',
      organization: json['organization'] is Map<String, dynamic>
          ? PartnerOrganization.fromJson(
              json['organization'] as Map<String, dynamic>,
            )
          : null,
      roles: rolesJson
          .map(
            (role) => role is Map<String, dynamic>
                ? (role['name'] as String? ?? '')
                : '',
          )
          .where((role) => role.isNotEmpty)
          .toList(),
      permissions: permissionsJson.map((permission) => '$permission').toList(),
      createdAt: json['created_at'] as String?,
    );
  }
}

class PartnerOrganization {
  const PartnerOrganization({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.typeCode,
    required this.typeName,
  });

  final int id;
  final String code;
  final String name;
  final String status;
  final String? typeCode;
  final String? typeName;

  factory PartnerOrganization.fromJson(Map<String, dynamic> json) {
    final type = json['organization_type'] as Map<String, dynamic>?;

    return PartnerOrganization(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      typeCode: type?['code'] as String?,
      typeName: type?['name'] as String?,
    );
  }
}

class PartnerOffer {
  const PartnerOffer({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.currency,
    required this.minimumPurchaseAmount,
    required this.maximumDiscountAmount,
    required this.maxUsesPerCard,
    required this.maxUsesPerDay,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  final int id;
  final String code;
  final String name;
  final String? description;
  final String discountType;
  final double? discountValue;
  final String? currency;
  final double? minimumPurchaseAmount;
  final double? maximumDiscountAmount;
  final int? maxUsesPerCard;
  final int? maxUsesPerDay;
  final String? startsAt;
  final String? endsAt;
  final String status;

  factory PartnerOffer.fromJson(Map<String, dynamic> json) {
    return PartnerOffer(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      discountType: json['discount_type'] as String? ?? '',
      discountValue: _toDouble(json['discount_value']),
      currency: json['currency'] as String?,
      minimumPurchaseAmount: _toDouble(json['minimum_purchase_amount']),
      maximumDiscountAmount: _toDouble(json['maximum_discount_amount']),
      maxUsesPerCard: json['max_uses_per_card'] as int?,
      maxUsesPerDay: json['max_uses_per_day'] as int?,
      startsAt: json['starts_at'] as String?,
      endsAt: json['ends_at'] as String?,
      status: json['status'] as String? ?? '',
    );
  }
}

class VerifiedDiscountCard {
  const VerifiedDiscountCard({
    required this.isValid,
    required this.message,
    required this.verifiedAt,
    required this.subscriptionStatus,
    required this.memberDisplayName,
    required this.cardId,
    required this.cardNumber,
    required this.cardUuid,
    required this.cardStatus,
    required this.expiresAt,
    required this.offer,
  });

  final bool isValid;
  final String message;
  final String? verifiedAt;
  final String? subscriptionStatus;
  final String? memberDisplayName;
  final int? cardId;
  final String? cardNumber;
  final String? cardUuid;
  final String? cardStatus;
  final String? expiresAt;
  final PartnerOffer? offer;

  factory VerifiedDiscountCard.fromJson(Map<String, dynamic> json) {
    final card = json['card'] as Map<String, dynamic>? ?? const {};

    return VerifiedDiscountCard(
      isValid: json['is_valid'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      verifiedAt: json['verified_at'] as String?,
      subscriptionStatus: json['subscription_status'] as String?,
      memberDisplayName: json['member_display_name'] as String?,
      cardId: card['id'] as int?,
      cardNumber: card['card_number'] as String?,
      cardUuid: card['card_uuid'] as String?,
      cardStatus: card['status'] as String?,
      expiresAt: card['expires_at'] as String?,
      offer: json['offer'] is Map<String, dynamic>
          ? PartnerOffer.fromJson(json['offer'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PartnerDiscountTransaction {
  const PartnerDiscountTransaction({
    required this.id,
    required this.scanReference,
    required this.verificationStatus,
    required this.status,
    required this.originalAmount,
    required this.discountAmount,
    required this.finalAmount,
    required this.discountTypeSnapshot,
    required this.discountValueSnapshot,
    required this.appliedAt,
    required this.partnerUserName,
    required this.offerName,
    required this.offerCode,
    required this.cardNumber,
    required this.cardUuid,
    required this.publicUserDisplayName,
    required this.publicUserPhone,
  });

  final int id;
  final String scanReference;
  final String verificationStatus;
  final String status;
  final double? originalAmount;
  final double? discountAmount;
  final double? finalAmount;
  final String? discountTypeSnapshot;
  final double? discountValueSnapshot;
  final String? appliedAt;
  final String? partnerUserName;
  final String? offerName;
  final String? offerCode;
  final String? cardNumber;
  final String? cardUuid;
  final String? publicUserDisplayName;
  final String? publicUserPhone;

  double? get resolvedDiscountAmount {
    if (discountAmount != null) {
      return discountAmount;
    }

    final type = (discountTypeSnapshot ?? '').toLowerCase();
    final value = discountValueSnapshot;

    if ((type == 'fixed' || type == 'fixed_amount' || type == 'amount') &&
        value != null) {
      if (originalAmount == null) {
        return value;
      }

      return value > originalAmount! ? originalAmount : value;
    }

    if ((type == 'percentage' || type == 'percent') &&
        value != null &&
        originalAmount != null) {
      return originalAmount! * value / 100;
    }

    if (originalAmount != null && finalAmount != null) {
      final discount = originalAmount! - finalAmount!;
      return discount < 0 ? 0 : discount;
    }

    return null;
  }

  double? get resolvedFinalAmount {
    if (finalAmount != null) {
      return finalAmount;
    }

    final discount = resolvedDiscountAmount;
    if (originalAmount == null || discount == null) {
      return null;
    }

    final amount = originalAmount! - discount;
    return amount < 0 ? 0 : amount;
  }

  factory PartnerDiscountTransaction.fromJson(Map<String, dynamic> json) {
    final partnerUser = json['partner_user'] as Map<String, dynamic>?;
    final offer = json['offer'] as Map<String, dynamic>?;
    final card = json['card'] as Map<String, dynamic>?;
    final publicUser = json['public_user'] as Map<String, dynamic>?;

    return PartnerDiscountTransaction(
      id: json['id'] as int? ?? 0,
      scanReference: json['scan_reference'] as String? ?? '',
      verificationStatus: json['verification_status'] as String? ?? '',
      status: json['status'] as String? ?? '',
      originalAmount: _toDouble(json['original_amount']),
      discountAmount: _toDouble(json['discount_amount']),
      finalAmount: _toDouble(json['final_amount']),
      discountTypeSnapshot: json['discount_type_snapshot'] as String?,
      discountValueSnapshot: _toDouble(json['discount_value_snapshot']),
      appliedAt: json['applied_at'] as String?,
      partnerUserName: partnerUser?['name'] as String?,
      offerName: offer?['name'] as String?,
      offerCode: offer?['code'] as String?,
      cardNumber: card?['card_number'] as String?,
      cardUuid: card?['card_uuid'] as String?,
      publicUserDisplayName: publicUser?['display_name'] as String?,
      publicUserPhone: publicUser?['phone'] as String?,
    );
  }
}

class PartnerStats {
  const PartnerStats({
    required this.totalScans,
    required this.todayScans,
    required this.totalDiscountAmount,
    required this.totalOriginalAmount,
    required this.totalFinalAmount,
    required this.lastScanAt,
  });

  final int totalScans;
  final int todayScans;
  final double totalDiscountAmount;
  final double totalOriginalAmount;
  final double totalFinalAmount;
  final String? lastScanAt;

  factory PartnerStats.fromJson(Map<String, dynamic> json) {
    return PartnerStats(
      totalScans: json['total_scans'] as int? ?? 0,
      todayScans: json['today_scans'] as int? ?? 0,
      totalDiscountAmount: _toDouble(json['total_discount_amount']) ?? 0,
      totalOriginalAmount: _toDouble(json['total_original_amount']) ?? 0,
      totalFinalAmount: _toDouble(json['total_final_amount']) ?? 0,
      lastScanAt: json['last_scan_at'] as String?,
    );
  }
}

double? _toDouble(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString());
}
