import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/app_logger.dart';
import '../../../core/constants.dart';
import '../../../models/promo_code_model.dart';
import '../../../providers/promo_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/promo_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/load_more_button.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/panel_ui.dart';

final _dateFormat = DateFormat('d MMM yyyy');

class AdminPromoCodesScreen extends ConsumerStatefulWidget {
  const AdminPromoCodesScreen({super.key});

  @override
  ConsumerState<AdminPromoCodesScreen> createState() =>
      _AdminPromoCodesScreenState();
}

class _AdminPromoCodesScreenState extends ConsumerState<AdminPromoCodesScreen> {
  final Set<String> _busy = {};

  Future<void> _toggle(PromoCodeModel promo, bool active) async {
    if (_busy.contains(promo.code)) return;
    HapticFeedback.selectionClick();
    setState(() => _busy.add(promo.code));
    try {
      await ref.read(promoServiceProvider).setActive(promo.code, active);
    } catch (e, stack) {
      AppLogger.error('Promo toggle failed', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not update ${promo.code}. Try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(promo.code));
    }
  }

  void _openNewSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _NewPromoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final codesAsync = ref.watch(adminPromoCodesProvider);
    final limit = ref.watch(adminPromoLimitProvider);

    Widget body;
    if (codesAsync.hasError && !codesAsync.hasValue) {
      body = AsyncErrorView(
        message: 'Could not load promo codes.',
        onRetry: () => ref.invalidate(adminPromoCodesProvider),
      );
    } else if (!codesAsync.hasValue) {
      body = const Center(
          child: CircularProgressIndicator(color: PanelColors.brand));
    } else {
      final codes = codesAsync.value!;
      if (codes.isEmpty) {
        body = PanelEmptyState(
          icon: Icons.local_offer_outlined,
          title: 'No promo codes yet',
          message:
              'Create a code to give customers a discount. HarvestHub covers the discount, not the farmer.',
          actionLabel: 'New code',
          onAction: _openNewSheet,
        );
      } else {
        final now = DateTime.now();
        var active = 0;
        var paused = 0;
        var expired = 0;
        for (final promo in codes) {
          if (!promo.expiresAt.isAfter(now)) {
            expired++;
          } else if (promo.active) {
            active++;
          } else {
            paused++;
          }
        }

        body = ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            PanelStatStrip(stats: [
              ('$active', 'Active'),
              ('$paused', 'Paused'),
              ('$expired', 'Expired'),
            ]),
            const SizedBox(height: 16),
            for (final promo in codes) ...[
              _PromoCard(
                key: ValueKey('admin_promo_${promo.code}'),
                promo: promo,
                now: now,
                busy: _busy.contains(promo.code),
                onToggle: (value) => _toggle(promo, value),
              ),
              const SizedBox(height: 10),
            ],
            if (codes.length >= limit)
              LoadMoreButton(
                onPressed: () => ref
                    .read(adminPromoLimitProvider.notifier)
                    .state = limit + 20,
              ),
          ],
        );
      }
    }

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('admin_new_promo_button'),
        onPressed: _openNewSheet,
        backgroundColor: PanelColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New code',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const PageHeader(title: 'Promo codes'),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final PromoCodeModel promo;
  final DateTime now;
  final bool busy;
  final ValueChanged<bool> onToggle;

  const _PromoCard({
    super.key,
    required this.promo,
    required this.now,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final expired = !promo.expiresAt.isAfter(now);
    final daysLeft = promo.expiresAt.difference(now).inDays;

    var pill = const StatusPill(
      label: 'Paused',
      icon: Icons.pause_circle_outline_rounded,
      color: PanelColors.amber,
      background: PanelColors.amberBg,
    );
    var accent = PanelColors.amber;
    if (expired) {
      pill = const StatusPill(
        label: 'Expired',
        icon: Icons.event_busy_outlined,
        color: PanelColors.textMuted,
        background: PanelColors.greyBg,
      );
      accent = const Color(0xFFB9C4AE);
    } else if (promo.active) {
      pill = const StatusPill(
        label: 'Active',
        icon: Icons.check_circle_outline_rounded,
        color: PanelColors.brand,
        background: PanelColors.tint,
      );
      accent = PanelColors.brand;
    }

    var ends = 'Ended ${_dateFormat.format(promo.expiresAt)}';
    if (!expired) {
      if (daysLeft < 1) {
        ends = 'Ends today';
      } else if (daysLeft == 1) {
        ends = 'Ends tomorrow';
      } else {
        ends = 'Ends in $daysLeft days';
      }
    }

    return Opacity(
      opacity: expired ? 0.75 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PanelColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 56,
                color: accent,
                child: Icon(
                  promo.isPercent
                      ? Icons.percent_rounded
                      : Icons.payments_outlined,
                  color: Colors.white,
                  size: 26,
                  semanticLabel:
                      promo.isPercent ? 'Percent discount' : 'Flat discount',
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    promo.code,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: PanelColors.textMain,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy ${promo.code}',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: promo.code));
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        appSnackBar('${promo.code} copied',
                                            tone: SnackTone.success));
                                  },
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 18, color: PanelColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          pill,
                        ],
                      ),
                      Text(promo.shortLabel,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: PanelColors.textBody)),
                      const SizedBox(height: 2),
                      Text(
                        promo.minOrder > 0
                            ? 'On orders over Rs. ${promo.minOrder.toStringAsFixed(0)} · $ends'
                            : 'Any order · $ends',
                        style: const TextStyle(
                            fontSize: 12, color: PanelColors.textMuted),
                      ),
                      if (!expired)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                promo.active
                                    ? 'Customers can use this code'
                                    : 'Paused for customers',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: PanelColors.textBody),
                              ),
                            ),
                            Semantics(
                              label: promo.active
                                  ? 'Pause ${promo.code}'
                                  : 'Activate ${promo.code}',
                              child: Switch(
                                value: promo.active,
                                activeTrackColor: PanelColors.brand,
                                onChanged: busy ? null : onToggle,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPromoSheet extends ConsumerStatefulWidget {
  const _NewPromoSheet();

  @override
  ConsumerState<_NewPromoSheet> createState() => _NewPromoSheetState();
}

class _NewPromoSheetState extends ConsumerState<_NewPromoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _valueController = TextEditingController();
  final _maxController = TextEditingController();
  final _minOrderController = TextEditingController(text: '0');
  final _daysController = TextEditingController(text: '30');
  String _type = PromoTypes.percent;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _codeController,
      _valueController,
      _maxController,
      _minOrderController,
      _daysController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    _maxController.dispose();
    _minOrderController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  String? _wholeNumber(String? raw,
      {required int min, required int max, required String label}) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return 'Enter $label.';
    final number = int.tryParse(text);
    if (number == null) return '$label must be a whole number.';
    if (number < min || number > max) {
      return '$label must be between $min and $max.';
    }
    return null;
  }

  String? get _preview {
    final value = int.tryParse(_valueController.text.trim());
    final days = int.tryParse(_daysController.text.trim());
    final minOrder = int.tryParse(_minOrderController.text.trim()) ?? 0;
    if (value == null || value <= 0 || days == null || days <= 0) return null;

    var offer = 'Rs. $value off';
    if (_type == PromoTypes.percent) {
      final max = int.tryParse(_maxController.text.trim());
      offer = max == null ? '$value% off' : '$value% off, up to Rs. $max,';
    }
    final where =
        minOrder > 0 ? 'on orders over Rs. $minOrder' : 'on any order';
    return 'Customers get $offer $where for $days ${days == 1 ? 'day' : 'days'}.';
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final value = double.parse(_valueController.text.trim());
    var maxDiscount = value;
    if (_type == PromoTypes.percent) {
      maxDiscount = double.parse(_maxController.text.trim());
    }
    final days = int.parse(_daysController.text.trim());

    final promo = PromoCodeModel(
      code: PromoService.normalize(_codeController.text),
      type: _type,
      value: value,
      minOrder: double.parse(_minOrderController.text.trim()),
      maxDiscount: maxDiscount,
      active: true,
      expiresAt: DateTime.now().add(Duration(days: days)),
      createdAt: DateTime.now(),
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(promoServiceProvider).createCode(promo);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
          appSnackBar('${promo.code} created', tone: SnackTone.success));
    } on PromoCodeException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e, stack) {
      AppLogger.error('Promo create failed', e, stack);
      if (mounted) {
        setState(() => _error =
            'Could not save this code. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _typeChip(String type, String label, IconData icon) {
    final selected = _type == type;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? PanelColors.tint : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _saving ? null : () => setState(() => _type = type),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? PanelColors.brand : PanelColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 18,
                      color:
                          selected ? PanelColors.brand : PanelColors.textMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color:
                            selected ? PanelColors.brand : PanelColors.textBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPercent = _type == PromoTypes.percent;
    final preview = _preview;
    final error = _error;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: PanelColors.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'New promo code',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: PanelColors.textMain),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('promo_code_field'),
                  controller: _codeController,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 15,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))
                  ],
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, letterSpacing: 1.2),
                  decoration: panelInputDecoration('Code',
                      hint: 'FRESH20', icon: Icons.local_offer_outlined),
                  validator: (raw) {
                    final code = PromoService.normalize(raw ?? '');
                    if (!PromoService.codePattern.hasMatch(code)) {
                      return 'Use 4 to 15 letters and numbers.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _typeChip(PromoTypes.percent, 'Percent off',
                        Icons.percent_rounded),
                    const SizedBox(width: 10),
                    _typeChip(PromoTypes.flat, 'Flat Rs. off',
                        Icons.payments_outlined),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('promo_value_field'),
                        controller: _valueController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: panelInputDecoration(
                            isPercent ? 'Discount (%)' : 'Discount (Rs.)'),
                        validator: (raw) => isPercent
                            ? _wholeNumber(raw,
                                min: 1, max: 90, label: 'Percent')
                            : _wholeNumber(raw,
                                min: 1, max: 5000, label: 'Amount'),
                      ),
                    ),
                    if (isPercent) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('promo_max_field'),
                          controller: _maxController,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: panelInputDecoration('Max off (Rs.)'),
                          validator: (raw) => _wholeNumber(raw,
                              min: 1, max: 5000, label: 'Maximum discount'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('promo_min_order_field'),
                        controller: _minOrderController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: panelInputDecoration('Min order (Rs.)'),
                        validator: (raw) => _wholeNumber(raw,
                            min: 0, max: 100000, label: 'Minimum order'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('promo_days_field'),
                        controller: _daysController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: panelInputDecoration('Valid for (days)'),
                        validator: (raw) =>
                            _wholeNumber(raw, min: 1, max: 365, label: 'Days'),
                      ),
                    ),
                  ],
                ),
                if (preview != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PanelColors.tint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.visibility_outlined,
                            size: 18, color: PanelColors.brand),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(preview,
                              style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                  color: PanelColors.textMain)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error,
                      style: const TextStyle(
                          fontSize: 13, color: PanelColors.danger)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('promo_save_button'),
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: PanelColors.brand,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: PanelColors.brand, strokeWidth: 2),
                          )
                        : const Text('Create code',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
