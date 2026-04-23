String formatMoney(double? value) {
  if (value == null) {
    return '-';
  }

  final amount = value.toStringAsFixed(
    value.truncateToDouble() == value ? 0 : 2,
  );

  return '${_formatNumber(amount)} F CFA';
}

String formatDiscountValue({
  required double? amount,
  required String? type,
  required double? value,
}) {
  if (amount != null) {
    return formatMoney(amount);
  }

  if (value == null) {
    return '-';
  }

  final formattedValue = value.toStringAsFixed(
    value.truncateToDouble() == value ? 0 : 2,
  );

  return switch ((type ?? '').toLowerCase()) {
    'percentage' || 'percent' => '${_formatNumber(formattedValue)}%',
    'fixed' ||
    'fixed_amount' ||
    'amount' => '${_formatNumber(formattedValue)} F CFA',
    _ => '${_formatNumber(formattedValue)} F CFA',
  };
}

String _formatNumber(String amount) {
  final parts = amount.split('.');
  final integer = parts.first;
  final decimal = parts.length > 1 ? parts.last : null;
  final buffer = StringBuffer();

  for (var index = 0; index < integer.length; index++) {
    final positionFromEnd = integer.length - index;
    buffer.write(integer[index]);

    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write(' ');
    }
  }

  if (decimal == null || decimal.isEmpty) {
    return buffer.toString();
  }

  return '${buffer.toString()}.$decimal';
}

String formatDate(String? isoDate) {
  if (isoDate == null || isoDate.trim().isEmpty) {
    return '-';
  }

  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) {
    return isoDate;
  }

  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day/$month/$year $hour:$minute';
}

String formatDiscountStatus(String status) {
  return switch (status) {
    'validated' => 'Validée',
    'verified' => 'Vérifiée',
    'pending' => 'En attente',
    'cancelled' => 'Annulée',
    'rejected' => 'Rejetée',
    'failed' => 'Échouée',
    '' => '-',
    _ => status,
  };
}

double? parseOptionalAmount(String value) {
  final normalized = value.trim().replaceAll(',', '.');

  if (normalized.isEmpty) {
    return null;
  }

  return double.tryParse(normalized);
}
