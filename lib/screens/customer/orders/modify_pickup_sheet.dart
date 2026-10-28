import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/pickup_slot_model.dart';
import '../../../providers/pickup_providers.dart';
import '../../../widgets/async_error_view.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);
const Color _border = Color(0xFFDDE5D3);
const Color _fewLeft = Color(0xFF9A5B00);

class ModifyPickupSheet extends ConsumerStatefulWidget {
  final String farmerId;
  final String? currentSlotId;
  final DateTime? currentSlotTime;

  const ModifyPickupSheet({
    super.key,
    required this.farmerId,
    required this.currentSlotId,
    this.currentSlotTime,
  });

  static Future<String?> show(
    BuildContext context, {
    required String farmerId,
    required String? currentSlotId,
    DateTime? currentSlotTime,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ModifyPickupSheet(
        farmerId: farmerId,
        currentSlotId: currentSlotId,
        currentSlotTime: currentSlotTime,
      ),
    );
  }

  @override
  ConsumerState<ModifyPickupSheet> createState() => _ModifyPickupSheetState();
}

class _ModifyPickupSheetState extends ConsumerState<ModifyPickupSheet> {
  static final _dayFormat = DateFormat('EEE, MMM d');
  static final _timeFormat = DateFormat('h:mm\u00A0a');

  String? _selectedId;

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference =
        DateTime(day.year, day.month, day.day).difference(today).inDays;
    if (difference == 0) return 'TODAY';
    if (difference == 1) return 'TOMORROW';
    return _dayFormat.format(day).toUpperCase();
  }

  Map<DateTime, List<PickupSlotModel>> _groupByDay(
      List<PickupSlotModel> slots) {
    final sorted = List<PickupSlotModel>.from(slots)
      ..sort((a, b) => a.slotTime.compareTo(b.slotTime));
    final groups = <DateTime, List<PickupSlotModel>>{};
    for (final slot in sorted) {
      final time = slot.slotTime;
      final day = DateTime(time.year, time.month, time.day);
      groups.putIfAbsent(day, () => []).add(slot);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(availableSlotsProvider(widget.farmerId));
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    Widget body;
    var options = <PickupSlotModel>[];
    if (slotsAsync.hasError && !slotsAsync.hasValue) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: AsyncErrorView(
          compact: true,
          title: 'Pickup times did not load',
          message: 'Check your connection and try again.',
          onRetry: () =>
              ref.invalidate(availableSlotsProvider(widget.farmerId)),
        ),
      );
    } else if (!slotsAsync.hasValue) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: _brand)),
      );
    } else {
      for (final slot in slotsAsync.value!) {
        if (slot.slotId != widget.currentSlotId && !slot.isFull) {
          options.add(slot);
        }
      }
      if (options.isEmpty) {
        body = const _EmptySlots();
      } else {
        body = _buildSlotList(options);
      }
    }

    final selectedId = _selectedId;
    final hasSelection =
        selectedId != null && options.any((slot) => slot.slotId == selectedId);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Change pickup time',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _textMain),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pick a new time that suits you. The farmer is notified.',
                    style:
                        TextStyle(fontSize: 13, height: 1.4, color: _textMuted),
                  ),
                  if (widget.currentSlotTime != null) ...[
                    const SizedBox(height: 12),
                    _CurrentSlotPill(
                      label:
                          '${_dayFormat.format(widget.currentSlotTime!)} · ${_timeFormat.format(widget.currentSlotTime!)}',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(child: body),
            if (options.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _tint)),
                ),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('modify_slot_confirm_button'),
                    onPressed: hasSelection
                        ? () => Navigator.of(context).pop(selectedId)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _brand,
                      disabledBackgroundColor: const Color(0xFFCBD5C0),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      hasSelection ? 'Confirm new time' : 'Select a time',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotList(List<PickupSlotModel> options) {
    final groups = _groupByDay(options);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 40;
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        var tileWidth = (available - 10) / 2;
        if (largeText || tileWidth < 140) tileWidth = available;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          children: [
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Text(
                  _dayLabel(entry.key),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      color: _textMuted),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final slot in entry.value)
                    SizedBox(
                      width: tileWidth,
                      child: _SlotTile(
                        key: ValueKey('modify_slot_${slot.slotId}'),
                        time: _timeFormat.format(slot.slotTime),
                        remaining: slot.remaining,
                        selected: slot.slotId == _selectedId,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedId = slot.slotId);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CurrentSlotPill extends StatelessWidget {
  final String label;

  const _CurrentSlotPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration:
          BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 16, color: _brand),
          const SizedBox(width: 6),
          const Text('Current ',
              style: TextStyle(fontSize: 13, color: _textMuted)),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _textMain),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final String time;
  final int remaining;
  final bool selected;
  final VoidCallback onTap;

  const _SlotTile({
    super.key,
    required this.time,
    required this.remaining,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fewLeft = remaining <= 2;
    var spotsText = '$remaining spots left';
    if (remaining == 1) spotsText = 'Last spot';
    if (remaining == 2) spotsText = 'Only 2 left';

    return Semantics(
      button: true,
      selected: selected,
      label: '$time, $spotsText',
      child: Material(
        color: selected ? _tint : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _brand : _border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _textMain,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (fewLeft) ...[
                              const Icon(Icons.local_fire_department_outlined,
                                  size: 13, color: _fewLeft),
                              const SizedBox(width: 3),
                            ],
                            Flexible(
                              child: Text(
                                spotsText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: fewLeft
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: fewLeft ? _fewLeft : _textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: selected
                        ? const Icon(Icons.check_circle_rounded,
                            key: ValueKey('on'), size: 22, color: _brand)
                        : const Icon(Icons.radio_button_unchecked_rounded,
                            key: ValueKey('off'),
                            size: 22,
                            color: Color(0xFFB9C4AE)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySlots extends StatelessWidget {
  const _EmptySlots();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _tint,
            child: Icon(Icons.event_busy_outlined, color: _brand, size: 26),
          ),
          SizedBox(height: 12),
          Text(
            'No other pickup times right now',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: _textMain),
          ),
          SizedBox(height: 4),
          Text(
            'Your current time stays booked. Check back later for new slots.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: _textMuted),
          ),
        ],
      ),
    );
  }
}
