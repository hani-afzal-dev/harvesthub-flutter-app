import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/market_model.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/location_service.dart';
import '../../../services/market_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/panel_ui.dart';

class AdminMarketsScreen extends ConsumerStatefulWidget {
  const AdminMarketsScreen({super.key});

  @override
  ConsumerState<AdminMarketsScreen> createState() => _AdminMarketsScreenState();
}

class _AdminMarketsScreenState extends ConsumerState<AdminMarketsScreen> {
  final Set<String> _busy = {};

  void _openSheet([MarketModel? market]) {
    final marketService = ref.read(marketServiceProvider);
    final locationService = ref.read(locationServiceProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _MarketSheet(
        existing: market,
        marketService: marketService,
        locationService: locationService,
      ),
    );
  }

  Future<void> _toggleActive(MarketModel market, bool value) async {
    if (_busy.contains(market.marketId)) return;
    HapticFeedback.selectionClick();
    setState(() => _busy.add(market.marketId));
    try {
      await ref.read(marketServiceProvider).setActive(market.marketId, value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not update ${market.marketName}. Try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(market.marketId));
    }
  }

  Future<void> _delete(MarketModel market, int farmerCount) async {
    if (_busy.contains(market.marketId)) return;
    if (farmerCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
        '$farmerCount ${farmerCount == 1 ? 'farmer is' : 'farmers are'} linked to ${market.marketName}. Turn it off instead, or move them first.',
        tone: SnackTone.error,
      ));
      return;
    }
    final confirmed = await showPanelConfirm(
      context,
      title: 'Delete ${market.marketName}?',
      message: 'Customers will no longer see this market in filters.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy.add(market.marketId));
    try {
      await ref.read(marketServiceProvider).deleteMarket(market.marketId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar('${market.marketName} deleted', tone: SnackTone.success));
    } on MarketInUseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(appSnackBar(e.toString(), tone: SnackTone.error));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not delete ${market.marketName}. Try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(market.marketId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketsAsync = ref.watch(adminAllMarketsProvider);
    final farmerCounts = <String, int>{};
    for (final farmer
        in ref.watch(adminFarmerProfilesProvider).valueOrNull ?? const []) {
      final id = farmer.marketId;
      if (id != null) farmerCounts[id] = (farmerCounts[id] ?? 0) + 1;
    }

    Widget body;
    if (marketsAsync.hasError && !marketsAsync.hasValue) {
      body = AsyncErrorView(
        message: 'Could not load markets.',
        onRetry: () => ref.invalidate(adminAllMarketsProvider),
      );
    } else if (!marketsAsync.hasValue) {
      body = const Center(
          child: CircularProgressIndicator(color: PanelColors.brand));
    } else {
      final markets = marketsAsync.value!;
      if (markets.isEmpty) {
        body = PanelEmptyState(
          icon: Icons.storefront_outlined,
          title: 'No markets yet',
          message:
              'Add the farmers\' markets where customers collect their orders.',
          actionLabel: 'Add market',
          onAction: _openSheet,
        );
      } else {
        var active = 0;
        var linked = 0;
        for (final market in markets) {
          if (market.activeStatus) active++;
          linked += farmerCounts[market.marketId] ?? 0;
        }
        body = ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            PanelStatStrip(stats: [
              ('${markets.length}', 'Markets'),
              ('$active', 'Open'),
              ('$linked', 'Farmers'),
            ]),
            const SizedBox(height: 16),
            for (final market in markets) ...[
              _MarketCard(
                key: ValueKey('admin_market_${market.marketId}'),
                market: market,
                farmerCount: farmerCounts[market.marketId] ?? 0,
                busy: _busy.contains(market.marketId),
                onToggle: (value) => _toggleActive(market, value),
                onEdit: () => _openSheet(market),
                onDelete: () =>
                    _delete(market, farmerCounts[market.marketId] ?? 0),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      }
    }

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('admin_add_market_button'),
        backgroundColor: PanelColors.brand,
        foregroundColor: Colors.white,
        onPressed: _openSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add market',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const PageHeader(title: 'Farmers\' markets'),
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

class _MarketCard extends StatelessWidget {
  final MarketModel market;
  final int farmerCount;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MarketCard({
    super.key,
    required this.market,
    required this.farmerCount,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation = market.latitude != null && market.longitude != null;
    return PanelCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelAvatar(
                name: market.marketName,
                icon: Icons.storefront_outlined,
                muted: !market.activeStatus,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(market.marketName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: PanelColors.textMain)),
                    const SizedBox(height: 4),
                    _Line(icon: Icons.place_outlined, text: market.address),
                    if (market.operatingHours.trim().isNotEmpty)
                      _Line(
                          icon: Icons.schedule_rounded,
                          text: market.operatingHours),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusPill(
                label:
                    '$farmerCount ${farmerCount == 1 ? 'farmer' : 'farmers'}',
                icon: Icons.agriculture_outlined,
                color: PanelColors.brand,
                background: PanelColors.tint,
              ),
              if (!hasLocation)
                const StatusPill(
                  label: 'No location, hidden from distance filter',
                  icon: Icons.location_off_outlined,
                  color: PanelColors.amber,
                  background: PanelColors.amberBg,
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: PanelColors.border),
          Row(
            children: [
              Expanded(
                child: MergeSemantics(
                  child: Row(
                    children: [
                      SizedBox(
                        height: 40,
                        child: FittedBox(
                          child: Switch(
                            value: market.activeStatus,
                            activeTrackColor: PanelColors.brand,
                            onChanged: busy ? null : onToggle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          market.activeStatus ? 'Shown to customers' : 'Hidden',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PanelColors.textBody),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit ${market.marketName}',
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, color: PanelColors.brand),
              ),
              IconButton(
                tooltip: 'Delete ${market.marketName}',
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: PanelColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Line({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: PanelColors.textMuted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, height: 1.35, color: PanelColors.textBody)),
          ),
        ],
      ),
    );
  }
}

class _MarketSheet extends StatefulWidget {
  final MarketModel? existing;
  final MarketService marketService;
  final LocationService locationService;

  const _MarketSheet({
    required this.existing,
    required this.marketService,
    required this.locationService,
  });

  @override
  State<_MarketSheet> createState() => _MarketSheetState();
}

class _MarketSheetState extends State<_MarketSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.marketName ?? '');
  late final TextEditingController _addressController =
      TextEditingController(text: widget.existing?.address ?? '');
  late final TextEditingController _hoursController =
      TextEditingController(text: widget.existing?.operatingHours ?? '');
  late final TextEditingController _latController = TextEditingController(
      text: widget.existing?.latitude?.toStringAsFixed(6) ?? '');
  late final TextEditingController _lngController = TextEditingController(
      text: widget.existing?.longitude?.toStringAsFixed(6) ?? '');
  bool _saving = false;
  bool _locating = false;
  bool _submitted = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _hoursController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  String? get _nameError {
    final length = _nameController.text.trim().length;
    if (length < 2 || length > 80) return 'Use 2 to 80 characters.';
    return null;
  }

  String? get _addressError {
    final length = _addressController.text.trim().length;
    if (length < 5) return 'Add the street and area.';
    if (length > 200) return 'Keep it under 200 characters.';
    return null;
  }

  String? get _hoursError => _hoursController.text.trim().length > 80
      ? 'Keep it under 80 characters.'
      : null;

  String? get _coordinateError {
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();
    if (latText.isEmpty && lngText.isEmpty) return null;
    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);
    if (lat == null || lng == null) {
      return 'Enter both latitude and longitude, or leave both empty.';
    }
    if (lat < -90 || lat > 90) return 'Latitude must be between -90 and 90.';
    if (lng < -180 || lng > 180) {
      return 'Longitude must be between -180 and 180.';
    }
    return null;
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _error = null;
    });
    final result = await widget.locationService.locate();
    if (!mounted) return;
    final position = result.position;
    setState(() {
      _locating = false;
      if (position != null) {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
      } else if (result.issue == LocationIssue.serviceOff) {
        _error = 'Location is turned off on this phone.';
      } else if (result.issue == LocationIssue.denied ||
          result.issue == LocationIssue.deniedForever) {
        _error = 'Location permission is blocked for HarvestHub.';
      } else {
        _error = 'Could not find your location. Enter it by hand.';
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_nameError != null ||
        _addressError != null ||
        _hoursError != null ||
        _coordinateError != null) {
      return;
    }

    GeoPoint? point;
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat != null && lng != null) point = GeoPoint(lat, lng);

    final market = MarketModel(
      marketId: widget.existing?.marketId ?? '',
      marketName: _nameController.text.trim(),
      address: _addressController.text.trim(),
      gpsCoordinates: point,
      operatingHours: _hoursController.text.trim(),
      activeStatus: widget.existing?.activeStatus ?? true,
    );

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.marketService.saveMarket(market);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(appSnackBar(
          _isEditing
              ? '${market.marketName} updated'
              : '${market.marketName} added',
          tone: SnackTone.success));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'Could not save the market. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final coordinateError = _submitted ? _coordinateError : null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text(_isEditing ? 'Edit market' : 'New market',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: PanelColors.textMain)),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('market_name_field'),
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(80)],
                onChanged: (_) => setState(() {}),
                decoration: panelInputDecoration('Market name',
                    hint: 'e.g. Latifabad Farmers Market',
                    icon: Icons.storefront_outlined,
                    error: _submitted ? _nameError : null),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('market_address_field'),
                controller: _addressController,
                enabled: !_saving,
                minLines: 1,
                maxLines: 3,
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                onChanged: (_) => setState(() {}),
                decoration: panelInputDecoration('Address',
                    icon: Icons.place_outlined,
                    error: _submitted ? _addressError : null),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('market_hours_field'),
                controller: _hoursController,
                enabled: !_saving,
                inputFormatters: [LengthLimitingTextInputFormatter(80)],
                onChanged: (_) => setState(() {}),
                decoration: panelInputDecoration('Opening hours (optional)',
                    hint: 'e.g. Sat-Sun 8:00 AM - 2:00 PM',
                    icon: Icons.schedule_rounded,
                    error: _submitted ? _hoursError : null),
              ),
              const SizedBox(height: 18),
              const PanelSectionLabel('Location for the distance filter'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PanelColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('market_lat_field'),
                            controller: _latController,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[-0-9.]')),
                              LengthLimitingTextInputFormatter(12),
                            ],
                            onChanged: (_) => setState(() {}),
                            decoration: panelInputDecoration('Latitude',
                                icon: Icons.explore_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('market_lng_field'),
                            controller: _lngController,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[-0-9.]')),
                              LengthLimitingTextInputFormatter(12),
                            ],
                            onChanged: (_) => setState(() {}),
                            decoration: panelInputDecoration('Longitude',
                                icon: Icons.explore_outlined),
                          ),
                        ),
                      ],
                    ),
                    if (coordinateError != null) ...[
                      const SizedBox(height: 8),
                      Text(coordinateError,
                          style: const TextStyle(
                              fontSize: 12, color: PanelColors.danger)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        key: const ValueKey('market_use_location_button'),
                        onPressed:
                            _saving || _locating ? null : _useMyLocation,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PanelColors.brand,
                          side: const BorderSide(color: PanelColors.brand),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: PanelColors.brand),
                              )
                            : const Icon(Icons.my_location_rounded, size: 18),
                        label: const Text('Use my current location'),
                      ),
                    ),
                  ],
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(error,
                    style: const TextStyle(
                        fontSize: 13, color: PanelColors.danger)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const ValueKey('market_save_button'),
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: PanelColors.brand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PanelColors.brand),
                        )
                      : Text(_isEditing ? 'Save changes' : 'Add market',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
