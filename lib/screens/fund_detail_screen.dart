import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signals/signals_flutter.dart';

import '../dependency_injection.dart';
import '../models/fund.dart';
import 'fund_form_screen.dart';

// ---- Design tokens (shared look with the markets list) -------------------
const _kGold = Color(0xFFF0B90B);
const _kGreen = Color(0xFF16C784);
const _kRed = Color(0xFFF6465D);
const _kTextSecondary = Color(0xFF8A8A8E);
const _kCardBg = Color(0xFFF7F8FA);
const _kDivider = Color(0xFFEDEDED);
const _kChipBg = Color(0xFFF3F4F6);

/// Return threshold that reads as "strong" (green) vs "weak" (red).
const _kStrongReturn = 10.0;

/// Per-category avatar colour, keyed by categoryId (matches the list screen).
const Map<int, Color> _kCategoryColors = {
  1: Color(0xFF0EA5A4),
  2: Color(0xFF3B82F6),
  3: Color(0xFFF59E0B),
  4: Color(0xFF8B5CF6),
};

/// Chart range options: label -> number of trailing months to show.
const Map<String, int> _kRanges = {'3M': 3, '6M': 6, '1Y': 12};

/// Detail screen: headline return, a 12-month area chart with a range
/// selector, a stats grid, the fund manager, and the monthly history —
/// styled after the Binance stock-detail view.
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

  /// Selected chart range (months). Defaults to the full year.
  int _rangeMonths = 12;

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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildOverviewTab(),
            const Divider(height: 1, thickness: 1, color: _kDivider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildHeadline(),
                  const SizedBox(height: 16),
                  _buildChartCard(),
                  const SizedBox(height: 20),
                  _buildDisclaimer(),
                  const SizedBox(height: 20),
                  _buildStatsCard(),
                  const SizedBox(height: 16),
                  _buildCompanyCard(),
                  const SizedBox(height: 16),
                  _buildHistoryCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Custom header: back · category avatar · code + name · edit/delete.
  Widget _buildHeader() {
    final color = _kCategoryColors[widget.fund.categoryId] ?? _kTextSecondary;
    final source = (widget.fund.fundCode ?? widget.fund.fundName).trim();
    final initials = source.length >= 2
        ? source.substring(0, 2).toUpperCase()
        : source.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: color,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fund.fundCode ?? widget.fund.fundName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  widget.fund.fundName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _kTextSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.black),
            tooltip: 'Edit fund',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FundFormScreen(existingFund: widget.fund),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black),
            tooltip: 'Delete fund',
            onPressed: _confirmDelete,
          ),
        ],
      ),
    );
  }

  /// Decorative gold-underlined "Overview" label, echoing the design's tab.
  Widget _buildOverviewTab() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 6),
              SizedBox(
                width: 60,
                child: Divider(height: 3, thickness: 3, color: _kGold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Big latest-return figure + category pill, with an average/rank subline.
  Widget _buildHeadline() {
    return Watch((context) {
      final latest = _performanceController.latestReturn.value;
      final average = _performanceController.averageReturn.value;
      final bestRank = _performanceController.bestRank.value;
      final category =
          _categoryController.categoriesById.value[widget.fund.categoryId];

      final avgColor = (average ?? 0) >= _kStrongReturn ? _kGreen : _kRed;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                latest == null ? '—' : '${latest.toStringAsFixed(2)}%',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              if (category != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kDivider),
                  ),
                  child: Text(
                    category.categoryName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                average == null
                    ? 'Latest annual return'
                    : 'avg ${average.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: avgColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bestRank == null
                    ? '· Past 12 months'
                    : '· best rank #$bestRank · Past 12 months',
                style: const TextStyle(fontSize: 14, color: _kTextSecondary),
              ),
            ],
          ),
        ],
      );
    });
  }

  /// Area chart + right-side axis labels + a 3M/6M/1Y range selector.
  Widget _buildChartCard() {
    return Watch((context) {
      if (_performanceController.isLoadingHistory.value) {
        return const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        );
      }

      final all = _performanceController.chartValues.value;
      // Slice to the selected trailing window (never more than we have).
      final take = _rangeMonths.clamp(0, all.length);
      final values = all.sublist(all.length - take);

      if (values.length < 2) {
        return const SizedBox(
          height: 200,
          child: Center(child: Text('Not enough data')),
        );
      }

      // Colour by trend across the visible window.
      final up = values.last >= values.first;
      final color = up ? _kGreen : _kRed;

      final minV = values.reduce((a, b) => a < b ? a : b);
      final maxV = values.reduce((a, b) => a > b ? a : b);

      return Column(
        children: [
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _AreaChartPainter(values: values, color: color),
                  ),
                ),
                const SizedBox(width: 8),
                _buildAxisLabels(minV, maxV),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildRangeSelector(),
        ],
      );
    });
  }

  /// Five evenly-spaced return labels down the right edge (max at top).
  Widget _buildAxisLabels(double minV, double maxV) {
    const steps = 4; // -> 5 labels
    final labels = [
      for (var i = 0; i <= steps; i++) maxV - (maxV - minV) * i / steps,
    ];
    return SizedBox(
      width: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final v in labels)
              Text(
                '${v.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 11, color: _kTextSecondary),
              ),
          ],
        ),
      ),
    );
  }

  /// The 3M / 6M / 1Y selector; the active range is a filled pill.
  Widget _buildRangeSelector() {
    return Row(
      children: [
        for (final entry in _kRanges.entries) ...[
          _RangeChip(
            label: entry.key,
            selected: _rangeMonths == entry.value,
            onTap: () => setState(() => _rangeMonths = entry.value),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  /// Short honesty note — the figures are generated sample data.
  Widget _buildDisclaimer() {
    return const Text(
      'Figures are illustrative sample data for demonstration only and are '
      'not investment advice. Past performance does not guarantee future '
      'results.',
      style: TextStyle(fontSize: 12, color: _kTextSecondary, height: 1.4),
    );
  }

  /// Grey rounded "Stats" card: a two-column grid of fund + performance data.
  Widget _buildStatsCard() {
    return Watch((context) {
      final history = _performanceController.history.value;
      final rates =
          history.map((p) => p.annualReturnRate).whereType<double>().toList();
      final latest = _performanceController.latestReturn.value;
      final average = _performanceController.averageReturn.value;
      final bestRank = _performanceController.bestRank.value;
      final thisMonthRank = history.isEmpty ? null : history.last.rankPosition;
      final best = rates.isEmpty ? null : rates.reduce((a, b) => a > b ? a : b);
      final worst =
          rates.isEmpty ? null : rates.reduce((a, b) => a < b ? a : b);
      final category =
          _categoryController.categoriesById.value[widget.fund.categoryId];

      String pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)}%';
      String rank(int? v) => v == null ? '—' : '#$v';

      final pairs = <List<String>>[
        ['Latest return', pct(latest), '12-mo average', pct(average)],
        ['Best rank', rank(bestRank), 'This month rank', rank(thisMonthRank)],
        ['Best month', pct(best), 'Weakest month', pct(worst)],
        [
          'Management fee',
          widget.fund.managementFee == null
              ? '—'
              : '${widget.fund.managementFee!.toStringAsFixed(2)}% p.a.',
          'Currency',
          widget.fund.currency ?? '—',
        ],
        [
          'Category',
          category?.categoryName ?? '—',
          'Risk level',
          category?.riskLevel ?? '—',
        ],
      ];

      return Container(
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Stats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
              ],
            ),
            const SizedBox(height: 16),
            for (final row in pairs)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(child: _statCell(row[0], row[1])),
                    Expanded(child: _statCell(row[2], row[3])),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  /// A single label-over-value stat cell.
  Widget _statCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: _kTextSecondary)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  /// The fund manager card, resolved through companiesById.
  Widget _buildCompanyCard() {
    return Watch((context) {
      final company =
          _fundController.companiesById.value[widget.fund.companyId];
      if (company == null) return const SizedBox.shrink();
      return Container(
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fund manager',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            _factRow('Company', company.companyName),
            _factRow('Status', company.regulatoryStatus ?? '—'),
            _factRow(
              'Location',
              [company.city, company.country].whereType<String>().join(', '),
            ),
            _factRow('Email', company.email ?? '—'),
            _factRow('Phone', company.phone ?? '—'),
          ],
        ),
      );
    });
  }

  /// Month-by-month table, newest first for scanability.
  Widget _buildHistoryCard() {
    final dateFormat = DateFormat('MMM yyyy');
    return Watch((context) {
      final rows = _performanceController.history.value.reversed.toList();
      if (rows.isEmpty) return const SizedBox.shrink();
      return Container(
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateFormat.format(row.performanceDate),
                        style: const TextStyle(color: _kTextSecondary),
                      ),
                    ),
                    Text(
                      row.annualReturnRate == null
                          ? '—'
                          : '${row.annualReturnRate!.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 44,
                      child: Text(
                        row.rankPosition == null ? '' : '#${row.rankPosition}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  /// Tiny helper for label/value rows in the manager card.
  Widget _factRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child:
                  Text(label, style: const TextStyle(color: _kTextSecondary)),
            ),
            Expanded(
                child:
                    Text(value, style: const TextStyle(color: Colors.black))),
          ],
        ),
      );

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
}

/// One range chip (3M/6M/1Y): filled light pill when selected.
class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kChipBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.black : _kTextSecondary,
          ),
        ),
      ),
    );
  }
}

/// Draws the return series as a line with a soft gradient area fill and an
/// end-of-series dot. Pure math + canvas — no chart package needed.
class _AreaChartPainter extends CustomPainter {
  _AreaChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  static const double _pad = 8; // top/bottom breathing room

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    Offset pointAt(int i) {
      final x = size.width * i / (values.length - 1);
      final normalized = (values[i] - minV) / range; // 0 = min, 1 = max
      final y = size.height - _pad - normalized * (size.height - 2 * _pad);
      return Offset(x, y);
    }

    final points = [for (var i = 0; i < values.length; i++) pointAt(i)];

    // Smooth curve through every point using a Catmull-Rom spline expressed
    // as cubic Béziers — softer than a raw polyline, still passes through
    // each month's actual value.
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i == 0 ? 0 : i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 >= points.length ? points.length - 1 : i + 2];
      // Classic Catmull-Rom (tension 0.5) -> Bézier control points.
      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      linePath.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    // Area fill = line closed down to the bottom, faded vertically.
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
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    // The line, plus a dot on the latest month.
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(pointAt(values.length - 1), 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AreaChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
