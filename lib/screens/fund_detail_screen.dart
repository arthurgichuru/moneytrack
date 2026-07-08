import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signals/signals_flutter.dart';

import '../dependency_injection.dart';
import '../models/fund.dart';
import '../models/fund_category.dart';
import 'fund_form_screen.dart';

/// Detail screen: stats row, 12-month sparkline, monthly history,
/// fund facts and manager card. Edit + delete live in the app bar.
class FundDetailScreen extends StatefulWidget {
  const FundDetailScreen({super.key, required this.fund});

  final Fund fund;

  @override
  State<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends State<FundDetailScreen> {
  final _fundController = DI.fundController;
  final _categoryController = DI.categoryController;
  final _performanceController = DI.performanceController;

  @override
  void initState() {
    super.initState();
    // Load this fund's 12-month series; the computeds
    // (latestReturn/averageReturn/bestRank/chartValues) all refresh from it.
    _performanceController.loadHistory(widget.fund.fundId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fund.fundName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit fund',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FundFormScreen(existingFund: widget.fund),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete fund',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsRow(),
          const SizedBox(height: 16),
          _buildChartCard(),
          const SizedBox(height: 16),
          _buildFundFacts(),
          const SizedBox(height: 16),
          _buildCompanyCard(),
          const SizedBox(height: 16),
          _buildHistoryList(),
        ],
      ),
    );
  }

  /// Delete = soft delete (is_active -> false). Confirm first, then pop
  /// back to the list, which will no longer show this fund because
  /// filteredFunds excludes inactive rows.
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete fund?'),
        content: Text(
            '"${widget.fund.fundName}" will be deactivated. Its performance '
            'history is kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _fundController.deactivateFund(widget.fund.fundId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Three stat tiles fed by three computeds. One Watch covers all of them.
  Widget _buildStatsRow() {
    return Watch((context) {
      final latest = _performanceController.latestReturn.value;
      final average = _performanceController.averageReturn.value;
      final bestRank = _performanceController.bestRank.value;

      String pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)}%';

      return Row(
        children: [
          _StatTile(label: 'Latest return', value: pct(latest)),
          const SizedBox(width: 8),
          _StatTile(label: '12-mo average', value: pct(average)),
          const SizedBox(width: 8),
          _StatTile(
              label: 'Best rank', value: bestRank == null ? '—' : '#$bestRank'),
        ],
      );
    });
  }

  /// The sparkline card. chartValues is already a clean `List<double>`,
  /// so the painter receives data ready to draw.
  Widget _buildChartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Annual return — last 12 months',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Watch((context) {
                if (_performanceController.isLoadingHistory.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final values = _performanceController.chartValues.value;
                if (values.length < 2) {
                  return const Center(child: Text('Not enough data'));
                }
                return CustomPaint(
                  painter: _SparklinePainter(
                    values: values,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Fund facts. Wrapped in Watch because the category name/risk level
  /// come from the categoriesById computed, which may resolve after this
  /// screen is first built.
  Widget _buildFundFacts() {
    final fund = widget.fund;
    return Watch((context) {
      final category =
          _categoryController.categoriesById.value[fund.categoryId];
      return _fundFactsCard(fund, category);
    });
  }

  Widget _fundFactsCard(Fund fund, FundCategory? category) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fund facts', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _factRow('Code', fund.fundCode ?? '—'),
            _factRow('Category', category?.categoryName ?? '—'),
            _factRow('Risk level', category?.riskLevel ?? '—'),
            _factRow('Currency', fund.currency ?? '—'),
            _factRow(
                'Management fee',
                fund.managementFee == null
                    ? '—'
                    : '${fund.managementFee!.toStringAsFixed(2)}% p.a.'),
            if (fund.investmentObjective != null) ...[
              const SizedBox(height: 8),
              Text(fund.investmentObjective!,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  /// The fund manager card, resolved through companiesById.
  Widget _buildCompanyCard() {
    return Watch((context) {
      final company =
          _fundController.companiesById.value[widget.fund.companyId];
      if (company == null) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fund manager',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _factRow('Company', company.companyName),
              _factRow('Status', company.regulatoryStatus ?? '—'),
              _factRow(
                  'Location',
                  [company.city, company.country]
                      .whereType<String>()
                      .join(', ')),
              _factRow('Email', company.email ?? '—'),
              _factRow('Phone', company.phone ?? '—'),
            ],
          ),
        ),
      );
    });
  }

  /// Month-by-month table, newest first for scanability.
  Widget _buildHistoryList() {
    final dateFormat = DateFormat('MMM yyyy');
    return Watch((context) {
      final rows = _performanceController.history.value.reversed.toList();
      if (rows.isEmpty) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monthly history',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(dateFormat.format(row.performanceDate))),
                      Text(
                        row.annualReturnRate == null
                            ? '—'
                            : '${row.annualReturnRate!.toStringAsFixed(2)}%',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 44,
                        child: Text(
                          row.rankPosition == null
                              ? ''
                              : '#${row.rankPosition}',
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  /// Tiny helper for label/value rows in the fact cards.
  Widget _factRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

/// One stat tile (used three times in the stats row).
class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the 12-month return series as a line with a soft gradient fill.
/// Pure math + canvas — no chart package needed for a sparkline.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Normalise: map each value into 0..1 within min..max, with a
    //    little padding so the line never touches the card edges.
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    Offset pointAt(int i) {
      final x = size.width * i / (values.length - 1);
      final normalized = (values[i] - minV) / range; // 0 = min, 1 = max
      final y = size.height -
          (normalized * (size.height * 0.85)) -
          (size.height * 0.075);
      return Offset(x, y);
    }

    // 2. Build the polyline path through every point.
    final linePath = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      linePath.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    // 3. Fill path = line path closed down to the bottom edge,
    //    painted with a vertical fade for the "area chart" look.
    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    // 4. The line itself, plus a dot on the latest month.
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(pointAt(values.length - 1), 4, Paint()..color = color);
  }

  /// Repaint only when the data or colour actually changed.
  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
