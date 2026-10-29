import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/pickup_slot_model.dart';
import '../../../providers/pickup_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/pickup_slot_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/panel_ui.dart';

final _timeFormat = DateFormat('h:mm\u00A0a');
final _dayFormat = DateFormat('EEE, MMM d');

String _dayLabel(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff =
      DateTime(time.year, time.month, time.day).difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return _dayFormat.format(time);
}

class FarmerPickupSlotsScreen extends ConsumerStatefulWidget {
  final String farmerId;
  const FarmerPickupSlotsScreen({super.key, required this.farmerId});

  @override
  ConsumerState<FarmerPickupSlotsScreen> createState() =>
      _FarmerPickupSlotsScreenState();
}

class _FarmerPickupSlotsScreenState
    extends ConsumerState<FarmerPickupSlotsScreen> {
  final Set<String> _busy = {};
  bool _showPast = false;

  Future<void> _openAddSheet(List<PickupSlotModel> existing) async {
    final service = ref.read(pickupSlotServiceProvider);
    final created = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddSlotSheet(
        farmerId: widget.farmerId,
        service: service,
        existing: existing,
      ),
    );
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
      'Slot added for ${_dayLabel(created)}, ${_timeFormat.format(created)}',
      tone: SnackTone.success,
    ));
  }

  Future<void> _toggleActive(PickupSlotModel slot, bool value) async {
    if (_busy.contains(slot.slotId)) return;
    HapticFeedback.selectionClick();
    setState(() => _busy.add(slot.slotId));
    try {
      await ref.read(pickupSlotServiceProvider).setActive(slot.slotId, value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
            'Could not update this slot. Try again.',
            tone: SnackTone.error));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(slot.slotId));
    }
  }

  Future<void> _confirmDelete(PickupSlotModel slot) async {
    if (_busy.contains(slot.slotId)) return;
    final service = ref.read(pickupSlotServiceProvider);
    setState(() => _busy.add(slot.slotId));

    int openBookings;
    try {
      openBookings =
          (await service.getOpenBookings(slot.slotId, widget.farmerId)).length;
    } catch (_) {
      if (mounted) {
        setState(() => _busy.remove(slot.slotId));
        ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
            'Could not check bookings for this slot. Try again.',
            tone: SnackTone.error));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy.remove(slot.slotId));

    var message = 'No customers have booked this slot.';
    if (openBookings == 1) {
      message =
          '1 customer has booked this slot. They will be asked to pick a new time.';
    } else if (openBookings > 1) {
      message =
          '$openBookings customers have booked this slot. They will be asked to pick a new time.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            'Delete ${_dayLabel(slot.slotTime)}, ${_timeFormat.format(slot.slotTime)}?'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep slot')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: PanelColors.danger),
            child: const Text('Delete slot'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy.add(slot.slotId));
    try {
      await service.cancelSlot(slotId: slot.slotId, farmerId: widget.farmerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(appSnackBar('Slot deleted', tone: SnackTone.success));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not delete the slot. Please try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(slot.slotId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(farmerSlotsProvider(widget.farmerId));
    final slots = slotsAsync.valueOrNull ?? const <PickupSlotModel>[];

    Widget body;
    if (slotsAsync.hasError && !slotsAsync.hasValue) {
      body = AsyncErrorView(
        title: 'Pickup slots did not load',
        message: 'Check your connection and try again.',
        onRetry: () => ref.invalidate(farmerSlotsProvider(widget.farmerId)),
      );
    } else if (!slotsAsync.hasValue) {
      body = const Center(
          child: CircularProgressIndicator(color: PanelColors.brand));
    } else if (slots.isEmpty) {
      body = PanelEmptyState(
        icon: Icons.event_outlined,
        title: 'No pickup slots yet',
        message:
            'Add the times customers can collect their orders. They pick one at checkout.',
        actionLabel: 'Add slot',
        onAction: () => _openAddSheet(slots),
      );
    } else {
      final now = DateTime.now();
      final upcoming = <PickupSlotModel>[];
      final past = <PickupSlotModel>[];
      for (final slot in slots) {
        if (slot.slotTime.isAfter(now)) {
          upcoming.add(slot);
        } else {
          past.add(slot);
        }
      }
      var booked = 0;
      var free = 0;
      for (final slot in upcoming) {
        booked += slot.booked;
        if (slot.isActive) free += slot.remaining;
      }

      final groups = <String, List<PickupSlotModel>>{};
      for (final slot in upcoming) {
        groups.putIfAbsent(_dayLabel(slot.slotTime), () => []).add(slot);
      }

      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          const _HowSlotsWorkCard(),
          const SizedBox(height: 16),
          PanelStatStrip(stats: [
            ('${upcoming.length}', 'Upcoming'),
            ('$booked', 'Booked'),
            ('$free', 'Spots free'),
          ]),
          if (upcoming.isEmpty) ...[
            const SizedBox(height: 16),
            const PanelCard(
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: PanelColors.amber),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No upcoming slots. Customers cannot choose a pickup time until you add one.',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: PanelColors.textBody),
                    ),
                  ),
                ],
              ),
            ),
          ],
          for (final entry in groups.entries) ...[
            const SizedBox(height: 18),
            PanelSectionLabel(entry.key),
            for (final slot in entry.value) ...[
              _SlotCard(
                key: ValueKey('farmer_slot_${slot.slotId}'),
                slot: slot,
                busy: _busy.contains(slot.slotId),
                onToggle: (value) => _toggleActive(slot, value),
                onDelete: () => _confirmDelete(slot),
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (past.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('farmer_past_slots_toggle'),
                onPressed: () => setState(() => _showPast = !_showPast),
                style: TextButton.styleFrom(
                    foregroundColor: PanelColors.textMuted,
                    minimumSize: const Size(48, 44)),
                icon: Icon(_showPast
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded),
                label:
                    Text('Past slots (${past.length > 10 ? 10 : past.length})'),
              ),
            ),
          ],
          if (past.isNotEmpty && _showPast) ...[
            for (final slot in past.reversed.take(10)) ...[
              _SlotCard(
                key: ValueKey('farmer_slot_${slot.slotId}'),
                slot: slot,
                busy: _busy.contains(slot.slotId),
                isPast: true,
                onToggle: null,
                onDelete: () => _confirmDelete(slot),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      );
    }

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      floatingActionButton: slotsAsync.hasValue
          ? FloatingActionButton.extended(
              key: const ValueKey('farmer_add_slot_button'),
              backgroundColor: PanelColors.brand,
              foregroundColor: Colors.white,
              onPressed: () => _openAddSheet(slots),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add slot',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const PanelHeader(
              title: 'Pickup slots',
              subtitle: 'Add times customers can book to collect their order',
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _HowSlotsWorkCard extends StatelessWidget {
  const _HowSlotsWorkCard();

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      borderColor: PanelColors.tint,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PanelColors.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: PanelColors.brand, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What is a pickup slot?',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: PanelColors.textMain),
                ),
                SizedBox(height: 4),
                Text(
                  "It's a time window when a customer can come collect their order from you. Add a day, a time, and how many orders you can hand out in that window — customers then pick one of your open slots at checkout.",
                  style: TextStyle(
                      fontSize: 13, height: 1.4, color: PanelColors.textBody),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final PickupSlotModel slot;
  final bool busy;
  final bool isPast;
  final ValueChanged<bool>? onToggle;
  final VoidCallback onDelete;

  const _SlotCard({
    super.key,
    required this.slot,
    required this.busy,
    required this.onToggle,
    required this.onDelete,
    this.isPast = false,
  });

  @override
  Widget build(BuildContext context) {
    StatusPill? pill;
    if (isPast) {
      pill = const StatusPill(
        label: 'Finished',
        icon: Icons.history_rounded,
        color: PanelColors.textMuted,
        background: PanelColors.greyBg,
      );
    } else if (slot.isActive && slot.isFull) {
      pill = const StatusPill(
        label: 'Full',
        icon: Icons.event_busy_outlined,
        color: PanelColors.amber,
        background: PanelColors.amberBg,
      );
    }

    final progress = slot.capacity == 0 ? 0.0 : slot.booked / slot.capacity;
    final toggle = onToggle;

    return Opacity(
      opacity: isPast ? 0.7 : 1,
      child: PanelCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _timeFormat.format(slot.slotTime),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: PanelColors.textMain,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        isPast
                            ? _dayFormat.format(slot.slotTime)
                            : '${slot.booked} of ${slot.capacity} booked',
                        style: const TextStyle(
                            fontSize: 13, color: PanelColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (pill != null) pill,
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1).toDouble(),
                minHeight: 6,
                color: slot.isFull ? PanelColors.amber : PanelColors.brand,
                backgroundColor: PanelColors.border,
                semanticsLabel: 'Bookings',
                semanticsValue: '${slot.booked} of ${slot.capacity}',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (toggle != null)
                  Expanded(
                    child: MergeSemantics(
                      child: Row(
                        children: [
                          Switch(
                            value: slot.isActive,
                            activeTrackColor: PanelColors.brand,
                            onChanged: busy ? null : toggle,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              slot.isActive ? 'Open for booking' : 'Paused',
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
                  )
                else
                  const Spacer(),
                busy
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PanelColors.brand),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Delete slot',
                        onPressed: onDelete,
                        style: IconButton.styleFrom(
                          backgroundColor: PanelColors.dangerBg,
                          foregroundColor: PanelColors.danger,
                          shape: const CircleBorder(),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 20),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSlotSheet extends StatefulWidget {
  final String farmerId;
  final PickupSlotService service;
  final List<PickupSlotModel> existing;

  const _AddSlotSheet({
    required this.farmerId,
    required this.service,
    required this.existing,
  });

  @override
  State<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends State<_AddSlotSheet> {
  static const _presetTimes = [
    TimeOfDay(hour: 9, minute: 0),
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 18, minute: 0),
  ];
  static const int _maxCapacity = 50;

  late DateTime _day;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  int _capacity = 5;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  DateTime get _slotTime =>
      DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);

  String _formatTime(TimeOfDay time) =>
      _timeFormat.format(DateTime(2000, 1, 1, time.hour, time.minute));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null && mounted) {
      setState(() {
        _day = picked;
        _error = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) {
      setState(() {
        _time = picked;
        _error = null;
      });
    }
  }

  Future<void> _create() async {
    if (_saving) return;
    final slotTime = _slotTime;
    if (!slotTime.isAfter(DateTime.now())) {
      setState(
          () => _error = 'That time has already passed. Pick a later time.');
      return;
    }
    final duplicate =
        widget.existing.any((slot) => slot.slotTime.isAtSameMomentAs(slotTime));
    if (duplicate) {
      setState(() => _error = 'You already have a slot at this time.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.createSlot(
        farmerId: widget.farmerId,
        slotTime: slotTime,
        capacity: _capacity,
      );
      if (mounted) Navigator.of(context).pop(slotTime);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not add the slot. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days =
        List<DateTime>.generate(7, (i) => today.add(Duration(days: i)));
    final dayInList = days.any((d) => d.isAtSameMomentAs(_day));
    final isPreset = _presetTimes
        .any((t) => t.hour == _time.hour && t.minute == _time.minute);
    final error = _error;

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
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
              const Text('Add pickup slot',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: PanelColors.textMain)),
              const SizedBox(height: 4),
              const Text('Customers can choose this time at checkout.',
                  style: TextStyle(fontSize: 13, color: PanelColors.textMuted)),
              const SizedBox(height: 20),
              const PanelSectionLabel('Day'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final day in days)
                    _ChoicePill(
                      label: _dayLabel(day),
                      selected: day.isAtSameMomentAs(_day),
                      onTap: _saving
                          ? null
                          : () => setState(() {
                                _day = day;
                                _error = null;
                              }),
                    ),
                  _ChoicePill(
                    label: dayInList ? 'Other date' : _dayFormat.format(_day),
                    icon: Icons.calendar_month_outlined,
                    selected: !dayInList,
                    onTap: _saving ? null : _pickDate,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const PanelSectionLabel('Time'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in _presetTimes)
                    _ChoicePill(
                      label: _formatTime(time),
                      selected: time.hour == _time.hour &&
                          time.minute == _time.minute,
                      onTap: _saving
                          ? null
                          : () => setState(() {
                                _time = time;
                                _error = null;
                              }),
                    ),
                  _ChoicePill(
                    label: isPreset ? 'Other time' : _formatTime(_time),
                    icon: Icons.access_time_rounded,
                    selected: !isPreset,
                    onTap: _saving ? null : _pickTime,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const PanelSectionLabel('How many orders'),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                decoration: BoxDecoration(
                  color: PanelColors.pageBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PanelColors.border),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Orders this slot can hold',
                          style: TextStyle(
                              fontSize: 14, color: PanelColors.textBody)),
                    ),
                    IconButton(
                      tooltip: 'Fewer orders',
                      onPressed: _saving || _capacity <= 1
                          ? null
                          : () => setState(() => _capacity--),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      color: PanelColors.brand,
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '$_capacity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: PanelColors.textMain,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'More orders',
                      onPressed: _saving || _capacity >= _maxCapacity
                          ? null
                          : () => setState(() => _capacity++),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      color: PanelColors.brand,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PanelColors.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available_rounded,
                        color: PanelColors.brand, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_dayLabel(_day)}, ${_formatTime(_time)} · up to $_capacity orders',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PanelColors.textMain),
                      ),
                    ),
                  ],
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error,
                    style: const TextStyle(
                        fontSize: 13, color: PanelColors.danger)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const ValueKey('add_slot_create_button'),
                  onPressed: _saving ? null : _create,
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
                      : const Text('Add slot',
                          style: TextStyle(
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

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final pillIcon = icon;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? PanelColors.brand : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? PanelColors.brand : PanelColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pillIcon != null) ...[
                  Icon(pillIcon,
                      size: 16,
                      color: selected ? Colors.white : PanelColors.brand),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : PanelColors.textBody,
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
