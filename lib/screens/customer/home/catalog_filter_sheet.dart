import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/farmer_model.dart';
import '../../../models/market_model.dart';
import '../../../providers/catalog_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/location_service.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);

class CatalogFilterSheet extends ConsumerStatefulWidget {
  final List<MarketModel> markets;
  final List<FarmerModel> farmers;
  final CatalogFilters current;
  final Position? userPosition;

  const CatalogFilterSheet({
    super.key,
    required this.markets,
    required this.farmers,
    required this.current,
    this.userPosition,
  });

  @override
  ConsumerState<CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends ConsumerState<CatalogFilterSheet> {
  String? _marketId;
  String? _farmerId;
  double? _maxDistanceKm;
  Position? _position;
  bool _locating = false;
  LocationIssue? _locationIssue;

  static const _distanceOptions = [5.0, 10.0, 25.0, 50.0];

  @override
  void initState() {
    super.initState();
    _marketId = widget.current.market?.marketId;
    _farmerId = widget.current.farmer?.farmerId;
    _maxDistanceKm = widget.current.maxDistanceKm;
    _position = widget.userPosition;
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _locationIssue = null;
    });
    final result = await ref.read(locationServiceProvider).locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _position = result.position;
      _locationIssue = result.issue;
      if (result.position == null) _maxDistanceKm = null;
      if (result.position != null && _maxDistanceKm == null) {
        _maxDistanceKm = 10;
      }
    });
  }

  Future<void> _fixLocation() async {
    final service = ref.read(locationServiceProvider);
    if (_locationIssue == LocationIssue.serviceOff) {
      await service.openLocationSettings();
    } else if (_locationIssue == LocationIssue.deniedForever) {
      await service.openAppSettings();
    } else {
      await _useMyLocation();
    }
  }

  (String, String) _issueText(LocationIssue issue) {
    switch (issue) {
      case LocationIssue.serviceOff:
        return (
          'Location is turned off on this phone. Turn it on to filter by distance.',
          'Turn on location'
        );
      case LocationIssue.deniedForever:
        return (
          'Location access is blocked for HarvestHub. Allow it in app settings to filter by distance.',
          'Open settings'
        );
      case LocationIssue.denied:
        return (
          'We need your location to show nearby markets. You can still filter by market or farmer.',
          'Try again'
        );
      case LocationIssue.unavailable:
        return (
          'We could not find your location right now. Move near a window or try again.',
          'Try again'
        );
    }
  }

  T? _findById<T>(List<T> items, String? id, String Function(T) idOf) {
    if (id == null) return null;
    for (final item in items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final optionsAsync = ref.watch(catalogFilterOptionsProvider);
    var markets = widget.markets;
    var farmers = widget.farmers;
    final loaded = optionsAsync.valueOrNull;
    if (loaded != null) {
      markets = loaded.markets;
      farmers = loaded.farmers;
    }
    final optionsLoading = optionsAsync.isLoading && markets.isEmpty;
    final optionsFailed = optionsAsync.hasError && markets.isEmpty;
    final sortedMarkets =
        ref.read(marketServiceProvider).withDistanceFrom(markets, _position);

    final market = _findById(markets, _marketId, (MarketModel m) => m.marketId);
    final farmer = _findById(farmers, _farmerId, (FarmerModel f) => f.farmerId);
    final issue = _locationIssue;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD5DBCD),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Filter products',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _textMain),
                ),
                const SizedBox(height: 18),
                if (optionsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (optionsFailed)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFBEDEA),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Markets and farmers did not load.',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF8C1D18)),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(catalogFilterOptionsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                const _Label('MARKET'),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('filter_market_dropdown'),
                  initialValue: market?.marketId,
                  isExpanded: true,
                  decoration: _dropdownDecoration(Icons.storefront_outlined),
                  borderRadius: BorderRadius.circular(16),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Any market')),
                    for (final entry in sortedMarkets)
                      DropdownMenuItem<String?>(
                        value: entry.market.marketId,
                        child: Text(
                          entry.distanceKm == null
                              ? entry.market.marketName
                              : '${entry.market.marketName} · ${entry.distanceKm!.toStringAsFixed(1)} km',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _marketId = value),
                ),
                const SizedBox(height: 16),
                const _Label('FARMER'),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('filter_farmer_dropdown'),
                  initialValue: farmer?.farmerId,
                  isExpanded: true,
                  decoration: _dropdownDecoration(Icons.agriculture_outlined),
                  borderRadius: BorderRadius.circular(16),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Any farmer')),
                    for (final option in farmers)
                      DropdownMenuItem<String?>(
                        value: option.farmerId,
                        child: Text(option.businessName,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => _farmerId = value),
                ),
                const SizedBox(height: 16),
                const _Label('DISTANCE'),
                if (_position == null)
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      key: const ValueKey('filter_use_location_button'),
                      onPressed: _locating ? null : _useMyLocation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brand,
                        side: const BorderSide(color: Color(0xFFCBD8BC)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(
                        _locating
                            ? 'Finding your location...'
                            : 'Use my location',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 16, color: _brand),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Using your current location',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _brand),
                        ),
                      ),
                      TextButton(
                        onPressed: _locating ? null : _useMyLocation,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in _distanceOptions)
                        ChoiceChip(
                          label: Text('Within ${option.toInt()} km'),
                          selected: _maxDistanceKm == option,
                          selectedColor: _brand,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _maxDistanceKm == option
                                ? Colors.white
                                : _textMain,
                          ),
                          checkmarkColor: Colors.white,
                          backgroundColor: _tint,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (selected) => setState(
                              () => _maxDistanceKm = selected ? option : null),
                        ),
                    ],
                  ),
                ],
                if (issue != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFDF2E3),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_off_outlined,
                                size: 18, color: Color(0xFF8A5A0B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _issueText(issue).$1,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Color(0xFF6B4A0B)),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const ValueKey('filter_fix_location_button'),
                            onPressed: _fixLocation,
                            child: Text(_issueText(issue).$2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(const CatalogFilters()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textMain,
                            side: const BorderSide(color: Color(0xFFCBD8BC)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Clear all',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          key: const ValueKey('filter_apply_button'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _brand,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.of(context).pop(
                            CatalogFilters(
                              market: market,
                              farmer: farmer,
                              maxDistanceKm:
                                  _position == null ? null : _maxDistanceKm,
                              position: _position,
                            ),
                          ),
                          child: const Text('Show results',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: _brand, size: 20),
      filled: true,
      fillColor: const Color(0xFFF1F4EC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brand, width: 1.5),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: _textMuted),
      ),
    );
  }
}
