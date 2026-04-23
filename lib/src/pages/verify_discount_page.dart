import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/app_shell_widgets.dart';
import '../models/api_models.dart';
import '../state/session_controller.dart';
import 'discount_transaction_detail_page.dart';

class VerifyDiscountPage extends StatefulWidget {
  const VerifyDiscountPage({
    super.key,
    required this.controller,
    this.scannedCardUuid,
    this.onScannedCardConsumed,
  });

  final PartnerSessionController controller;
  final String? scannedCardUuid;
  final VoidCallback? onScannedCardConsumed;

  @override
  State<VerifyDiscountPage> createState() => _VerifyDiscountPageState();
}

class _VerifyDiscountPageState extends State<VerifyDiscountPage> {
  final _manualOfferController = TextEditingController();
  final _paidAmountController = TextEditingController();

  PartnerOffer? _selectedOffer;
  VerifiedDiscountCard? _verification;
  PartnerDiscountTransaction? _lastTransaction;
  String? _scannedCardUuid;
  String? _error;
  bool _isVerifying = false;
  bool _isApplying = false;
  String? _lastConsumedScannedCardUuid;

  int? get _resolvedOfferId {
    if (_selectedOffer != null) {
      return _selectedOffer!.id;
    }

    return int.tryParse(_manualOfferController.text.trim());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _consumeScannedCardUuid(),
    );
  }

  @override
  void didUpdateWidget(covariant VerifyDiscountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _consumeScannedCardUuid(),
    );
  }

  @override
  void dispose() {
    _manualOfferController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  void _consumeScannedCardUuid() {
    final scannedCardUuid = widget.scannedCardUuid?.trim();

    if (!mounted ||
        scannedCardUuid == null ||
        scannedCardUuid.isEmpty ||
        scannedCardUuid == _lastConsumedScannedCardUuid) {
      return;
    }

    _lastConsumedScannedCardUuid = scannedCardUuid;
    widget.onScannedCardConsumed?.call();
    _verifyScannedCard(scannedCardUuid);
  }

  Future<void> _verifyScannedCard(String cardUuid) async {
    setState(() {
      _error = null;
      _isVerifying = true;
      _scannedCardUuid = cardUuid;
      _verification = null;
      _lastTransaction = null;
      _selectedOffer = null;
      _manualOfferController.clear();
      _paidAmountController.clear();
    });

    try {
      final verification = await widget.controller.verifyCard(
        cardUuid: cardUuid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _verification = verification;
      });
    } on ApiException catch (error) {
      setState(() {
        _verification = null;
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _applyDiscount() async {
    final cardUuid = _scannedCardUuid;
    final offerId = _resolvedOfferId;

    if (cardUuid == null || cardUuid.isEmpty || _verification == null) {
      setState(() {
        _error = 'Scanne d’abord une carte valide.';
      });
      return;
    }

    if (offerId == null) {
      setState(() {
        _error = 'Sélectionne le type de réduction.';
      });
      _showErrorSnackBar('Sélectionne le type de réduction.');
      return;
    }

    setState(() {
      _error = null;
      _isApplying = true;
    });

    final originalAmount = parseOptionalAmount(_paidAmountController.text);
    final discountAmount = _calculateDiscountAmount(
      offer: _selectedOffer,
      originalAmount: originalAmount,
    );
    final finalAmount = originalAmount != null && discountAmount != null
        ? _clampPositive(originalAmount - discountAmount)
        : null;

    try {
      final transaction = await widget.controller.applyDiscount(
        cardUuid: cardUuid,
        offerId: offerId,
        originalAmount: originalAmount,
        discountAmount: discountAmount,
        finalAmount: finalAmount,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastTransaction = transaction;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Remise appliquée avec succès (${transaction.scanReference}).',
          ),
        ),
      );
    } on ApiException catch (error) {
      setState(() {
        _error = error.message;
      });
      _showErrorSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  double? _calculateDiscountAmount({
    required PartnerOffer? offer,
    required double? originalAmount,
  }) {
    if (offer?.discountValue == null) {
      return null;
    }

    final type = offer!.discountType.toLowerCase();
    final value = offer.discountValue!;
    double? amount;

    if (type == 'fixed' || type == 'fixed_amount' || type == 'amount') {
      amount = originalAmount == null ? value : _min(value, originalAmount);
    } else if ((type == 'percentage' || type == 'percent') &&
        originalAmount != null) {
      amount = originalAmount * value / 100;
    }

    if (amount == null) {
      return null;
    }

    final maxDiscount = offer.maximumDiscountAmount;
    if (maxDiscount != null) {
      amount = _min(amount, maxDiscount);
    }

    return originalAmount == null ? amount : _min(amount, originalAmount);
  }

  double _min(double first, double second) {
    return first < second ? first : second;
  }

  double _clampPositive(double value) {
    return value < 0 ? 0 : value;
  }

  @override
  Widget build(BuildContext context) {
    final offers = widget.controller.offers;
    final canApply = _verification != null && _lastTransaction == null;

    return buildGradientBackground(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 16, 20, canApply ? 18 : 28),
              children: [
                const AppPageHeader(
                  title: 'Vérification',
                  subtitle:
                      'Après le scan, choisissez la réduction à appliquer.',
                ),
                if (_isVerifying) ...[
                  const SizedBox(height: 18),
                  const PremiumSection(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Text('Vérification de la carte...')),
                      ],
                    ),
                  ),
                ],
                if (!_isVerifying &&
                    _verification == null &&
                    _lastTransaction == null) ...[
                  const SizedBox(height: 18),
                  PremiumSection(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aucune carte scannée',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error ??
                              'Lancez le scan depuis le bouton du dashboard pour vérifier une carte.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _error == null
                                    ? AppColors.muted
                                    : Theme.of(context).colorScheme.error,
                                fontWeight: _error == null
                                    ? FontWeight.normal
                                    : FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_verification != null) ...[
                  const SizedBox(height: 16),
                  PremiumSection(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.mint.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _verification!.message,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _InfoLine(
                          label: 'Membre',
                          value: _verification!.memberDisplayName ?? '-',
                        ),
                        _InfoLine(
                          label: 'Carte',
                          value: _verification!.cardNumber ?? '-',
                        ),
                        _InfoLine(
                          label: 'Abonnement',
                          value: _verification!.subscriptionStatus ?? '-',
                        ),
                      ],
                    ),
                  ),
                ],
                if (canApply) ...[
                  const SizedBox(height: 16),
                  PremiumSection(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Appliquer la remise',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        if (offers.isNotEmpty)
                          _NativeOfferSelector(
                            offers: offers,
                            selectedOffer: offers.contains(_selectedOffer)
                                ? _selectedOffer
                                : null,
                            enabled: !_isApplying,
                            onChanged: (value) {
                              setState(() {
                                _selectedOffer = value;
                              });
                            },
                          )
                        else
                          TextField(
                            controller: _manualOfferController,
                            keyboardType: TextInputType.number,
                            enabled: !_isApplying,
                            decoration: const InputDecoration(
                              labelText: 'ID du type de réduction',
                              prefixIcon: Icon(
                                Icons.confirmation_number_outlined,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _paidAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          enabled: !_isApplying,
                          decoration: const InputDecoration(
                            labelText: 'Montant payé (optionnel)',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                        ),
                        if (widget.controller.offersWarning != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Chargement des offres indisponible : ${widget.controller.offersWarning}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (_lastTransaction != null) ...[
                  const SizedBox(height: 16),
                  PremiumSection(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remise appliquée',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        _InfoLine(
                          label: 'Membre',
                          value: _lastTransaction!.publicUserDisplayName ?? '-',
                        ),
                        _InfoLine(
                          label: 'Offre',
                          value: _lastTransaction!.offerName ?? '-',
                        ),
                        _InfoLine(
                          label: 'Montant payé',
                          value: formatMoney(_lastTransaction!.originalAmount),
                        ),
                        _InfoLine(
                          label: 'Remise',
                          value: formatMoney(
                            _lastTransaction!.resolvedDiscountAmount,
                          ),
                        ),
                        _InfoLine(
                          label: 'Référence',
                          value: _lastTransaction!.scanReference,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    DiscountTransactionDetailPage(
                                      transaction: _lastTransaction!,
                                    ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Voir le détail'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canApply)
            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.softBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x160F172A),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isApplying ? null : _applyDiscount,
                      icon: _isApplying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _isApplying ? 'Application...' : 'Appliquer la remise',
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NativeOfferSelector extends StatelessWidget {
  const _NativeOfferSelector({
    required this.offers,
    required this.selectedOffer,
    required this.enabled,
    required this.onChanged,
  });

  final List<PartnerOffer> offers;
  final PartnerOffer? selectedOffer;
  final bool enabled;
  final ValueChanged<PartnerOffer> onChanged;

  Future<void> _showPicker(BuildContext context) async {
    if (!enabled || offers.isEmpty) {
      return;
    }

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      await _showCupertinoPicker(context);
      return;
    }

    await _showMaterialPicker(context);
  }

  Future<void> _showCupertinoPicker(BuildContext context) async {
    var selectedIndex = selectedOffer == null
        ? 0
        : offers.indexOf(selectedOffer!);
    if (selectedIndex < 0) {
      selectedIndex = 0;
    }

    var pendingOffer = offers[selectedIndex];

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return Container(
          height: 320,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () {
                          onChanged(pendingOffer);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Choisir'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 42,
                    scrollController: FixedExtentScrollController(
                      initialItem: selectedIndex,
                    ),
                    onSelectedItemChanged: (index) {
                      pendingOffer = offers[index];
                    },
                    children: offers
                        .map(
                          (offer) => Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              child: Text(
                                _labelFor(offer),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMaterialPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<PartnerOffer>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            itemCount: offers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final offer = offers[index];
              final isSelected = offer.id == selectedOffer?.id;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? AppColors.primary : AppColors.muted,
                ),
                title: Text(
                  offer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  offer.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).pop(offer),
              );
            },
          ),
        );
      },
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  String _labelFor(PartnerOffer offer) => '${offer.name} (${offer.code})';

  @override
  Widget build(BuildContext context) {
    final label = selectedOffer == null
        ? 'Sélectionner une réduction'
        : _labelFor(selectedOffer!);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showPicker(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Type de réduction',
          prefixIcon: const Icon(Icons.local_offer_outlined),
          suffixIcon: Icon(
            Theme.of(context).platform == TargetPlatform.iOS
                ? CupertinoIcons.chevron_down
                : Icons.keyboard_arrow_down_rounded,
          ),
          enabled: enabled,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: selectedOffer == null
              ? Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.muted)
              : Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
