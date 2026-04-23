import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/app_shell_widgets.dart';
import '../models/api_models.dart';

class DiscountTransactionDetailPage extends StatelessWidget {
  const DiscountTransactionDetailPage({super.key, required this.transaction});

  final PartnerDiscountTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final statusLabel = formatDiscountStatus(transaction.status);
    final discountValue = formatDiscountValue(
      amount: transaction.resolvedDiscountAmount,
      type: transaction.discountTypeSnapshot,
      value: transaction.discountValueSnapshot,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Detail remise',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PremiumSection(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.offerName ?? 'Remise appliquee',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(fontSize: 19),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              formatDate(transaction.appliedAt),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(label: statusLabel),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.softSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.softBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Beneficiaire',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          transaction.publicUserDisplayName ?? '-',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _maskPhone(transaction.publicUserPhone),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _AmountCard(
                    label: 'Montant paye',
                    value: formatMoney(transaction.originalAmount),
                    icon: Icons.payments_outlined,
                    tint: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AmountCard(
                    label: 'Remise',
                    value: discountValue,
                    icon: Icons.local_offer_outlined,
                    tint: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _AmountCard(
              label: 'Montant final',
              value: formatMoney(transaction.resolvedFinalAmount),
              icon: Icons.account_balance_wallet_outlined,
              tint: AppColors.mint,
              wide: true,
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: 'Details remise',
              icon: Icons.sell_outlined,
              children: [
                _DetailRow(
                  label: 'Type',
                  value: _formatDiscountType(transaction.discountTypeSnapshot),
                ),
                _DetailRow(
                  label: 'Valeur',
                  value: formatDiscountValue(
                    amount: null,
                    type: transaction.discountTypeSnapshot,
                    value: transaction.discountValueSnapshot,
                  ),
                ),
                _DetailRow(
                  label: 'Offre',
                  value: transaction.offerName ?? '-',
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: 'Carte',
              icon: Icons.credit_card_outlined,
              children: [
                _DetailRow(
                  label: 'Numero',
                  value: transaction.cardNumber ?? '-',
                ),
                _DetailRow(
                  label: 'Identifiant',
                  value: transaction.cardUuid ?? '-',
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: 'Operation',
              icon: Icons.fact_check_outlined,
              children: [
                _DetailRow(
                  label: 'Reference',
                  value: transaction.scanReference,
                ),
                _DetailRow(
                  label: 'Verification',
                  value: formatDiscountStatus(transaction.verificationStatus),
                ),
                _DetailRow(label: 'Statut', value: statusLabel),
                _DetailRow(
                  label: 'Agent',
                  value: transaction.partnerUserName ?? '-',
                ),
                _DetailRow(
                  label: 'Date',
                  value: formatDate(transaction.appliedAt),
                  isLast: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.wide = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return PremiumSection(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: wide ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tint == AppColors.mint
                        ? const Color(0xFF087A4F)
                        : tint,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PremiumSection(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.blue, size: 19),
              ),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF087A4F),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _maskPhone(String? phone) {
  if (phone == null || phone.trim().isEmpty) {
    return '-';
  }

  final digits = phone.replaceAll(RegExp(r'\D+'), '');
  if (digits.length <= 4) {
    return '••••';
  }

  final suffix = digits.substring(digits.length - 4);
  return '•••• •• $suffix';
}

String _formatDiscountType(String? type) {
  return switch ((type ?? '').toLowerCase()) {
    'percentage' || 'percent' => 'Pourcentage',
    'fixed' || 'amount' => 'Montant fixe',
    '' => '-',
    _ => type!,
  };
}
