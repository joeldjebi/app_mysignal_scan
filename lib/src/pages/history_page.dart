import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/app_shell_widgets.dart';
import '../models/api_models.dart';
import '../state/session_controller.dart';
import 'discount_transaction_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.controller});

  final PartnerSessionController controller;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _selectedStatus = 'all';
  String _selectedOffer = 'all';
  _HistoryDateFilter _dateFilter = _HistoryDateFilter.all;
  DateTimeRange? _customDateRange;

  List<PartnerDiscountTransaction> _filteredHistory() {
    return widget.controller.history.where((transaction) {
      if (_selectedStatus != 'all' && transaction.status != _selectedStatus) {
        return false;
      }

      if (_selectedOffer != 'all' &&
          _offerFilterKey(transaction) != _selectedOffer) {
        return false;
      }

      if (!_isInSelectedDateRange(transaction.appliedAt)) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.controller.history;
    final filteredHistory = _filteredHistory();

    return buildGradientBackground(
      child: RefreshIndicator(
        onRefresh: () => widget.controller.refreshPartnerData(showLoader: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            AppPageHeader(
              title: 'Historique',
              subtitle: '${filteredHistory.length} remise(s) affichée(s)',
              trailing: IconButton.filledTonal(
                onPressed: widget.controller.isRefreshing
                    ? null
                    : () => widget.controller.refreshPartnerData(
                        showLoader: true,
                      ),
                icon: const Icon(Icons.sync_rounded),
              ),
            ),
            const SizedBox(height: 14),
            PremiumSection(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _FilterPill(
                            label: 'Statut',
                            value: _selectedStatus == 'all'
                                ? 'Tout'
                                : formatDiscountStatus(_selectedStatus),
                            active: _selectedStatus != 'all',
                            icon: Icons.verified_outlined,
                            onTap: () => _pickStatus(context, history),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            label: 'Type',
                            value: _selectedOffer == 'all'
                                ? 'Tout'
                                : _selectedOfferLabel(history),
                            active: _selectedOffer != 'all',
                            icon: Icons.local_offer_outlined,
                            onTap: () => _pickOffer(context, history),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            label: 'Date',
                            value: 'Auj',
                            active: _dateFilter == _HistoryDateFilter.today,
                            icon: Icons.calendar_month_outlined,
                            onTap: () =>
                                _selectDateFilter(_HistoryDateFilter.today),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            label: 'Date',
                            value: '7 jours',
                            active: _dateFilter == _HistoryDateFilter.sevenDays,
                            icon: Icons.date_range_outlined,
                            onTap: () =>
                                _selectDateFilter(_HistoryDateFilter.sevenDays),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            label: 'Date',
                            value: '30 jours',
                            active:
                                _dateFilter == _HistoryDateFilter.thirtyDays,
                            icon: Icons.event_note_outlined,
                            onTap: () => _selectDateFilter(
                              _HistoryDateFilter.thirtyDays,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            label: 'Date',
                            value: _customDateRange == null
                                ? 'Perso'
                                : _formatDateRange(_customDateRange!),
                            active: _dateFilter == _HistoryDateFilter.custom,
                            icon: Icons.tune_rounded,
                            onTap: () =>
                                _selectDateFilter(_HistoryDateFilter.custom),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Effacer les filtres',
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 38,
                        ),
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const EmptyStateCard(
                title: 'Aucun historique disponible',
                description:
                    'Les réductions validées apparaîtront ici dès que vous commencerez à scanner des cartes.',
                icon: Icons.history_toggle_off_rounded,
              )
            else if (filteredHistory.isEmpty)
              const EmptyStateCard(
                title: 'Aucun résultat',
                description:
                    'Aucune remise ne correspond au filtre sélectionné.',
                icon: Icons.filter_alt_off_outlined,
              )
            else
              PremiumSection(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Remises',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${filteredHistory.length}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...filteredHistory.map(
                      (transaction) => _HistoryTile(transaction: transaction),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _availableStatuses(List<PartnerDiscountTransaction> history) {
    final statuses = history
        .map((transaction) => transaction.status)
        .where((status) => status.trim().isNotEmpty)
        .toSet()
        .toList();

    statuses.sort();
    return statuses;
  }

  List<_OfferFilterOption> _availableOffers(
    List<PartnerDiscountTransaction> history,
  ) {
    final offers = <String, _OfferFilterOption>{};

    for (final transaction in history) {
      final key = _offerFilterKey(transaction);
      if (key.trim().isEmpty) {
        continue;
      }

      offers[key] = _OfferFilterOption(
        key: key,
        label: transaction.offerName ?? 'Type non renseigné',
      );
    }

    final values = offers.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return values;
  }

  String _offerFilterKey(PartnerDiscountTransaction transaction) {
    return transaction.offerCode ?? transaction.offerName ?? '';
  }

  bool _isInSelectedDateRange(String? isoDate) {
    final range = _selectedDateRange;
    if (range == null) {
      return true;
    }

    final parsed = DateTime.tryParse(isoDate ?? '');
    if (parsed == null) {
      return false;
    }

    final local = parsed.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);

    return !day.isBefore(start) && !day.isAfter(end);
  }

  DateTimeRange? get _selectedDateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (_dateFilter) {
      _HistoryDateFilter.all => null,
      _HistoryDateFilter.today => DateTimeRange(start: today, end: today),
      _HistoryDateFilter.sevenDays => DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      _HistoryDateFilter.thirtyDays => DateTimeRange(
        start: today.subtract(const Duration(days: 29)),
        end: today,
      ),
      _HistoryDateFilter.custom => _customDateRange,
    };
  }

  bool get _hasActiveFilters {
    return _selectedStatus != 'all' ||
        _selectedOffer != 'all' ||
        _dateFilter != _HistoryDateFilter.all;
  }

  void _resetFilters() {
    setState(() {
      _selectedStatus = 'all';
      _selectedOffer = 'all';
      _dateFilter = _HistoryDateFilter.all;
      _customDateRange = null;
    });
  }

  Future<void> _pickStatus(
    BuildContext context,
    List<PartnerDiscountTransaction> history,
  ) async {
    final options = [
      const _FilterOption(key: 'all', label: 'Tout'),
      ..._availableStatuses(history).map(
        (status) =>
            _FilterOption(key: status, label: formatDiscountStatus(status)),
      ),
    ];

    final picked = await _showFilterSheet(
      context: context,
      title: 'Filtrer par statut',
      options: options,
      selectedKey: _selectedStatus,
    );

    if (picked == null) {
      return;
    }

    setState(() => _selectedStatus = picked);
  }

  Future<void> _pickOffer(
    BuildContext context,
    List<PartnerDiscountTransaction> history,
  ) async {
    final options = [
      const _FilterOption(key: 'all', label: 'Tout'),
      ..._availableOffers(
        history,
      ).map((offer) => _FilterOption(key: offer.key, label: offer.label)),
    ];

    final picked = await _showFilterSheet(
      context: context,
      title: 'Filtrer par type',
      options: options,
      selectedKey: _selectedOffer,
    );

    if (picked == null) {
      return;
    }

    setState(() => _selectedOffer = picked);
  }

  Future<String?> _showFilterSheet({
    required BuildContext context,
    required String title,
    required List<_FilterOption> options,
    required String selectedKey,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              ...options.map((option) {
                final selected = option.key == selectedKey;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                  title: Text(option.label),
                  onTap: () => Navigator.of(context).pop(option.key),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDateFilter(_HistoryDateFilter filter) async {
    if (filter == _HistoryDateFilter.custom) {
      await _pickCustomDateRange(context);
      return;
    }

    setState(() => _dateFilter = filter);
  }

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          _customDateRange ??
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
      _dateFilter = _HistoryDateFilter.custom;
      _customDateRange = picked;
    });
  }

  String _formatDateRange(DateTimeRange range) {
    return '${_formatShortDate(range.start)} - ${_formatShortDate(range.end)}';
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _selectedOfferLabel(List<PartnerDiscountTransaction> history) {
    return _availableOffers(history)
        .firstWhere(
          (offer) => offer.key == _selectedOffer,
          orElse: () => const _OfferFilterOption(key: 'unknown', label: 'Type'),
        )
        .label;
  }
}

class _FilterOption {
  const _FilterOption({required this.key, required this.label});

  final String key;
  final String label;
}

class _OfferFilterOption {
  const _OfferFilterOption({required this.key, required this.label});

  final String key;
  final String label;
}

enum _HistoryDateFilter { all, today, sevenDays, thirtyDays, custom }

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppColors.primary : AppColors.muted;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 106, maxWidth: 168),
      child: Material(
        color: active
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.softSurface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$label: $value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.transaction});

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
