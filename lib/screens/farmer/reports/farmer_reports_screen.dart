import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/report_model.dart';
import '../../../providers/farmer_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/panel_ui.dart';

final _rangeFormat = DateFormat('MMM d');
final _money = NumberFormat('#,##0');

String _rangeText(ReportModel report) {
  final start = _rangeFormat.format(report.startDate);
  final end = _rangeFormat.format(report.endDate);
  if (start == end) return start;
  return '$start – $end';
}

class FarmerReportsScreen extends ConsumerStatefulWidget {
  final String farmerId;
  const FarmerReportsScreen({super.key, required this.farmerId});

  @override
  ConsumerState<FarmerReportsScreen> createState() =>
      _FarmerReportsScreenState();
}

class _FarmerReportsScreenState extends ConsumerState<FarmerReportsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.daily;
  bool _generating = false;

  Future<void> _generate() async {
    if (_generating) return;
    HapticFeedback.lightImpact();
    setState(() => _generating = true);
    try {
      await ref
          .read(reportServiceProvider)
          .generateReport(farmerId: widget.farmerId, period: _selectedPeriod);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
        '${reportPeriodLabel(_selectedPeriod)} report ready',
        tone: SnackTone.success,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not generate the report. Check your connection and try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(farmerReportsProvider(widget.farmerId));

    Widget reportsBody;
    if (reportsAsync.hasError && !reportsAsync.hasValue) {
      reportsBody = AsyncErrorView(
        compact: true,
        title: 'Reports did not load',
        message: 'Check your connection and try again.',
        onRetry: () => ref.invalidate(farmerReportsProvider(widget.farmerId)),
      );
    } else if (!reportsAsync.hasValue) {
      reportsBody = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child:
            Center(child: CircularProgressIndicator(color: PanelColors.brand)),
      );
    } else {
      final reports = reportsAsync.value!;
      if (reports.isEmpty) {
        reportsBody = const Padding(
          padding: EdgeInsets.only(top: 12),
          child: PanelEmptyState(
            icon: Icons.insert_chart_outlined,
            title: 'No reports yet',
            message:
                'Pick a period above and tap Generate to see your orders, earnings and best sellers.',
          ),
        );
      } else {
        final latest = reports.first;
        final older = reports.skip(1).toList();
        reportsBody = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            PanelSectionLabel(
                'Latest ${reportPeriodLabel(latest.period).toLowerCase()} report'),
            _LatestReport(report: latest),
            if (latest.topProducts.isNotEmpty) ...[
              const SizedBox(height: 20),
              const PanelSectionLabel('Best sellers'),
              _TopProducts(report: latest),
            ],
            if (older.isNotEmpty) ...[
              const SizedBox(height: 20),
              const PanelSectionLabel('Earlier reports'),
              for (final report in older) ...[
                _ReportRow(report: report),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      }
    }

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const PanelHeader(
              title: 'Sales reports',
              subtitle: 'See how your shop is doing',
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      const PanelSectionLabel('Generate a report'),
                      PanelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Pick a period and generate a report to see your orders, earnings and best sellers for that time.',
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: PanelColors.textBody),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                for (final period in ReportPeriod.values) ...[
                                  Expanded(
                                    child: _PeriodButton(
                                      label: reportPeriodLabel(period),
                                      selected: period == _selectedPeriod,
                                      onTap: _generating
                                          ? null
                                          : () => setState(
                                              () => _selectedPeriod = period),
                                    ),
                                  ),
                                  if (period != ReportPeriod.values.last)
                                    const SizedBox(width: 8),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                key: const ValueKey('farmer_generate_report'),
                                onPressed: _generating ? null : _generate,
                                style: FilledButton.styleFrom(
                                  backgroundColor: PanelColors.brand,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: _generating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            color: PanelColors.brand,
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.auto_graph_rounded),
                                label: Text(
                                  _generating
                                      ? 'Generating...'
                                      : 'Generate ${reportPeriodLabel(_selectedPeriod).toLowerCase()} report',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      reportsBody,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _PeriodButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? PanelColors.tint : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? PanelColors.brand : PanelColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? PanelColors.brand : PanelColors.textBody,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LatestReport extends StatelessWidget {
  final ReportModel report;

  const _LatestReport({required this.report});

  @override
  Widget build(BuildContext context) {
    final average =
        report.totalOrders == 0 ? 0.0 : report.revenue / report.totalOrders;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F8A1A), PanelColors.brand, PanelColors.brandDark],
        ),
        boxShadow: [
          BoxShadow(
            color: PanelColors.brandDark.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  reportPeriodLabel(report.period),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _rangeText(report),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Earnings',
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Rs. ${_money.format(report.revenue.round())}',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child:
                    _HeroStat(label: 'Orders', value: '${report.totalOrders}'),
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(width: 14),
              Expanded(
                child: _HeroStat(
                  label: 'Avg. order',
                  value: 'Rs. ${_money.format(average.round())}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}

class _TopProducts extends StatelessWidget {
  final ReportModel report;

  const _TopProducts({required this.report});

  @override
  Widget build(BuildContext context) {
    var maxQty = 1;
    for (final product in report.topProducts) {
      if (product.qty > maxQty) maxQty = product.qty;
    }
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return PanelCard(
      child: Column(
        children: [
          for (var i = 0; i < report.topProducts.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Semantics(
              label:
                  '${report.topProducts[i].itemName}, ${report.topProducts[i].qty} sold',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              i == 0 ? PanelColors.amberBg : PanelColors.tint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color:
                                i == 0 ? PanelColors.amber : PanelColors.brand,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          report.topProducts[i].itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: PanelColors.textMain),
                        ),
                      ),
                      Text(
                        '${report.topProducts[i].qty} sold',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PanelColors.textMuted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final target = constraints.maxWidth *
                          (report.topProducts[i].qty / maxQty);
                      return Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: PanelColors.tint,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                                begin: reduceMotion ? target : 0, end: target),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            builder: (context, width, _) => Container(
                              width: width,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? const Color(0xFFEF9F27)
                                    : PanelColors.brand,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final ReportModel report;

  const _ReportRow({required this.report});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PanelColors.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.insert_chart_outlined,
                color: PanelColors.brand, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: PanelColors.tint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reportPeriodLabel(report.period),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PanelColors.brand),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _rangeText(report),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PanelColors.textMain),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.totalOrders} ${report.totalOrders == 1 ? 'order' : 'orders'}',
                  style: const TextStyle(
                      fontSize: 12, color: PanelColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs. ${_money.format(report.revenue.round())}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: PanelColors.brand,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Text('earned',
                  style:
                      TextStyle(fontSize: 11, color: PanelColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
