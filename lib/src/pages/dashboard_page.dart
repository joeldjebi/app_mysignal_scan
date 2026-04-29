import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/app_shell_widgets.dart';
import '../models/api_models.dart';
import 'discount_transaction_detail_page.dart';
import '../state/session_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.controller,
    required this.onStartScan,
    required this.onOpenHistory,
    required this.onOpenNotifications,
  });

  final PartnerSessionController controller;
  final VoidCallback onStartScan;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenNotifications;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  _StatsFilter _statsFilter = _StatsFilter.today;
  DateTimeRange? _customStatsRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.controller.isRefreshing) {
        return;
      }

      _refreshDashboardData(showLoader: true);
    });
  }

  Future<void> _refreshDashboardData({bool showLoader = false}) {
    final range = _selectedStatsRange;
    return widget.controller.refreshPartnerData(
      showLoader: showLoader,
      statsDateFrom: range?.start,
      statsDateTo: range?.end,
    );
  }

  DateTimeRange? get _selectedStatsRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (_statsFilter) {
      _StatsFilter.today => DateTimeRange(start: today, end: today),
      _StatsFilter.sevenDays => DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      _StatsFilter.thirtyDays => DateTimeRange(
        start: today.subtract(const Duration(days: 29)),
        end: today,
      ),
      _StatsFilter.custom => _customStatsRange,
    };
  }

  Future<void> _selectStatsFilter(_StatsFilter filter) async {
    if (filter == _StatsFilter.custom) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final picked = await showDateRangePicker(
        context: context,
        initialDateRange:
            _customStatsRange ??
            DateTimeRange(
              start: today.subtract(const Duration(days: 6)),
              end: today,
            ),
        firstDate: DateTime(today.year - 5),
        lastDate: today,
      );

      if (picked == null) {
        return;
      }

      setState(() {
        _statsFilter = filter;
        _customStatsRange = picked;
      });

      await _refreshDashboardData(showLoader: true);
      return;
    }

    if (_statsFilter == filter) {
      return;
    }

    setState(() => _statsFilter = filter);
    await _refreshDashboardData(showLoader: true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final session = controller.session;
    final user = session?.user;
    final stats = controller.stats;
    final lastDiscounts = controller.history.take(10).toList();

    return buildGradientBackground(
      child: RefreshIndicator(
        onRefresh: () => _refreshDashboardData(showLoader: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            AppPageHeader(
              title: 'Bienvenue',
              subtitle: user?.organization?.name ?? 'Espace partenaire',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NotificationButton(
                    unreadCount: controller.unreadNotificationsCount,
                    onPressed: widget.onOpenNotifications,
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: controller.isRefreshing
                        ? null
                        : () => _refreshDashboardData(showLoader: true),
                    icon: controller.isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PremiumSection(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _StatsFilterPill(
                      label: 'Aujourd hui',
                      active: _statsFilter == _StatsFilter.today,
                      onTap: () => _selectStatsFilter(_StatsFilter.today),
                    ),
                    const SizedBox(width: 8),
                    _StatsFilterPill(
                      label: '7 jours',
                      active: _statsFilter == _StatsFilter.sevenDays,
                      onTap: () => _selectStatsFilter(_StatsFilter.sevenDays),
                    ),
                    const SizedBox(width: 8),
                    _StatsFilterPill(
                      label: '30 jours',
                      active: _statsFilter == _StatsFilter.thirtyDays,
                      onTap: () => _selectStatsFilter(_StatsFilter.thirtyDays),
                    ),
                    const SizedBox(width: 8),
                    _StatsFilterPill(
                      label: _customStatsRange == null
                          ? 'Personnalise'
                          : _formatRange(_customStatsRange!),
                      active: _statsFilter == _StatsFilter.custom,
                      onTap: () => _selectStatsFilter(_StatsFilter.custom),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                MetricCard(
                  label: 'Scans total',
                  value: '${stats?.totalScans ?? controller.history.length}',
                  icon: Icons.qr_code_scanner_rounded,
                  tint: AppColors.primary,
                ),
                MetricCard(
                  label: 'Scans du jour',
                  value: '${stats?.todayScans ?? 0}',
                  icon: Icons.today_rounded,
                  tint: AppColors.orange,
                ),
                MetricCard(
                  label: 'Réduction totale',
                  value: formatMoney(
                    _resolvedTotalDiscount(stats, controller.history),
                  ),
                  icon: Icons.savings_rounded,
                  tint: AppColors.blue,
                ),
                MetricCard(
                  label: 'Montant final',
                  value: formatMoney(
                    _resolvedTotalFinal(stats, controller.history),
                  ),
                  icon: Icons.payments_rounded,
                  tint: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onStartScan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scanner'),
              ),
            ),
            const SizedBox(height: 12),
            PremiumSection(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '10 dernières remises',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${lastDiscounts.length}/10',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (lastDiscounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Aucune remise appliquée pour le moment. Lancez votre premier scan depuis le bouton principal.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  else
                    ...lastDiscounts.map(
                      (transaction) =>
                          _RecentDiscountTile(transaction: transaction),
                    ),
                  if (controller.history.length > 10) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onOpenHistory,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Rechercher'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = IconButton.filledTonal(
      tooltip: 'Notifications',
      onPressed: onPressed,
      icon: const Icon(Icons.notifications_outlined),
    );

    if (unreadCount == 0) {
      return icon;
    }

    return Badge(
      label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
      child: icon,
    );
  }
}

double? _resolvedTotalDiscount(
  PartnerStats? stats,
  List<PartnerDiscountTransaction> history,
) {
  if (stats != null) {
    return stats.totalDiscountAmount;
  }

  return history.fold<double>(
    0,
    (total, transaction) => total + (transaction.resolvedDiscountAmount ?? 0),
  );
}

double? _resolvedTotalFinal(
  PartnerStats? stats,
  List<PartnerDiscountTransaction> history,
) {
  if (stats != null) {
    return stats.totalFinalAmount;
  }

  return history.fold<double>(
    0,
    (total, transaction) => total + (transaction.resolvedFinalAmount ?? 0),
  );
}

enum _StatsFilter { today, sevenDays, thirtyDays, custom }

class _StatsFilterPill extends StatelessWidget {
  const _StatsFilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppColors.primary : AppColors.muted;

    return Material(
      color: active
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.softSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.32)
                  : AppColors.softBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_outlined, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatRange(DateTimeRange range) {
  return '${_formatShortDate(range.start)} - ${_formatShortDate(range.end)}';
}

String _formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

class _RecentDiscountTile extends StatelessWidget {
  const _RecentDiscountTile({required this.transaction});

  final PartnerDiscountTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                DiscountTransactionDetailPage(transaction: transaction),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.softSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.softBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                color: AppColors.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.publicUserDisplayName?.isNotEmpty == true
                        ? transaction.publicUserDisplayName!
                        : transaction.offerName ?? 'Remise appliquée',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDate(transaction.appliedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    transaction.offerName ?? 'Type non renseigné',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDiscountValue(
                    amount: transaction.resolvedDiscountAmount,
                    type: transaction.discountTypeSnapshot,
                    value: transaction.discountValueSnapshot,
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDiscountStatus(transaction.status),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
