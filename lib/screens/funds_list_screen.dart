import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../dependency_injection.dart';
import '../models/fund.dart';
import 'fund_detail_screen.dart';
import 'fund_form_screen.dart';

// ---- Design tokens (Binance-style markets list) --------------------------
const _kGold = Color(0xFFF0B90B); // active-tab accent
const _kGreen = Color(0xFF16C784); // gains
const _kRed = Color(0xFFF6465D); // losses / weak returns
const _kTextSecondary = Color(0xFF8A8A8E);
const _kSearchBg = Color(0xFFF3F4F6);
const _kDivider = Color(0xFFEDEDED);

/// A return at or above this (% p.a.) reads as "strong" and shows green;
/// below it shows red — the app's stand-in for the design's gain/loss split.
const _kStrongReturn = 10.0;

/// Fixed column widths so the header labels line up with each row's numbers.
const double _kNumberCol = 74;
const double _kPillCol = 84;

/// Per-category avatar colour, keyed by categoryId (see FundCatalog).
const Map<int, Color> _kCategoryColors = {
  1: Color(0xFF0EA5A4), // Money Market — teal
  2: Color(0xFF3B82F6), // Fixed Income — blue
  3: Color(0xFFF59E0B), // Equity — amber
  4: Color(0xFF8B5CF6), // Balanced — violet
};

/// Home screen: search box + category tabs + the filtered fund list.
///
/// Note how little state lives in the widget itself — everything is read
/// from the controllers via `Watch`, which rebuilds ONLY the widget
/// subtree inside it when a signal it reads changes.
class FundsListScreen extends StatefulWidget {
  const FundsListScreen({super.key});

  @override
  State<FundsListScreen> createState() => _FundsListScreenState();
}

class _FundsListScreenState extends State<FundsListScreen> {
  final _fundController = DI.fundController;
  final _categoryController = DI.categoryController;
  final _performanceController = DI.performanceController;

  /// The category the list opens on. There is no "All" tab, so a category
  /// is always selected — Money Market by default.
  static const _defaultCategory = 'Money Market';

  /// Kick off the initial loads. They write into signals when they complete,
  /// so the UI updates itself — no await, no setState needed. Once categories
  /// arrive, default the filter to Money Market (only on first run, so a
  /// choice the user made before navigating away is preserved).
  @override
  void initState() {
    super.initState();
    _fundController.loadFunds();
    _performanceController.loadLatestReturns();
    _categoryController.loadCategories().then((_) {
      if (!mounted) return;
      if (_fundController.selectedCategoryId.value == null) {
        _selectDefaultCategory();
      }
    });
  }

  /// Selects the Money Market category (no-op if it isn't loaded yet).
  void _selectDefaultCategory() {
    for (final c in _categoryController.categories.value) {
      if (c.categoryName == _defaultCategory) {
        _fundController.selectedCategoryId.value = c.categoryId;
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MoneyTrack')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kGold,
        foregroundColor: Colors.black,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FundFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildSearchRow(),
          _buildCategoryTabs(),
          const Divider(height: 1, thickness: 1, color: _kDivider),
          _buildColumnHeader(),
          Expanded(child: _buildFundList()),
        ],
      ),
    );
  }

  /// Search pill + a trailing "more" affordance, mirroring the design's
  /// rounded field and the "…" button beside it.
  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              // onChanged writes straight into the searchQuery signal;
              // filteredFunds recomputes and the list below repaints. That
              // one line IS the entire search feature.
              onChanged: (text) => _fundController.searchQuery.value = text,
              decoration: InputDecoration(
                hintText: 'Search fund name or code…',
                hintStyle: const TextStyle(color: _kTextSecondary),
                prefixIcon: const Icon(Icons.search, color: _kTextSecondary),
                filled: true,
                fillColor: _kSearchBg,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            tooltip: 'Reset',
            // Clears the search text and returns to the default category.
            onPressed: () {
              _fundController.searchQuery.value = '';
              _selectDefaultCategory();
            },
          ),
        ],
      ),
    );
  }

  /// Horizontal, gold-underlined category tabs — one per category, Money
  /// Market first (no "All" tab; a category is always selected). Wrapped in
  /// Watch because it reads the (async-loaded) category list and the
  /// current selection.
  Widget _buildCategoryTabs() {
    return Watch((context) {
      final selectedId = _fundController.selectedCategoryId.value;

      // Money Market first, then the rest alphabetically.
      final categories = [..._categoryController.categories.value]
        ..sort((a, b) {
          if (a.categoryName == _defaultCategory) return -1;
          if (b.categoryName == _defaultCategory) return 1;
          return a.categoryName.compareTo(b.categoryName);
        });

      return SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final category in categories)
              _CategoryTab(
                label: category.categoryName,
                selected: selectedId == category.categoryId,
                // Always selects this category (no toggle-to-"all").
                onTap: () => _fundController.selectedCategoryId.value =
                    category.categoryId,
              ),
          ],
        ),
      );
    });
  }

  /// Column labels that line up with each row: Name | Latest | Return.
  Widget _buildColumnHeader() {
    const style = TextStyle(fontSize: 12, color: _kTextSecondary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          const Expanded(child: Text('Name / Manager', style: style)),
          const SizedBox(
            width: _kNumberCol,
            child: Text('Latest', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 12),
          const SizedBox(
            width: _kPillCol,
            child: Text('Return', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  /// The list body. One Watch handles all four visual states:
  /// loading -> error -> empty -> data.
  Widget _buildFundList() {
    return Watch((context) {
      if (_fundController.isLoading.value &&
          _fundController.funds.value.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final error = _fundController.errorMessage.value;
      if (error != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _fundController.loadFunds,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }

      final funds = _fundController.filteredFunds.value;
      if (funds.isEmpty) {
        return const Center(child: Text('No funds match your filters.'));
      }

      return RefreshIndicator(
        onRefresh: () async {
          await _fundController.loadFunds();
          await _performanceController.loadLatestReturns();
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 96), // clear the FAB
          itemCount: funds.length,
          itemBuilder: (context, index) => _FundTile(fund: funds[index]),
        ),
      );
    });
  }
}

/// One category tab: bold black label + gold underline when selected,
/// muted grey otherwise.
class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
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
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.black : _kTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            // Underline sizes to the label width (Column is min-width).
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: selected ? _kGold : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in the list: avatar, ticker + name/manager, latest return with
/// fee, and a solid green/red return pill. Split into its own widget so
/// each row stays cheap to rebuild.
class _FundTile extends StatelessWidget {
  const _FundTile({required this.fund});

  final Fund fund;

  @override
  Widget build(BuildContext context) {
    final fundController = DI.fundController;
    final performanceController = DI.performanceController;

    // This Watch reads companiesById and latestReturns, so the numbers pop
    // in by themselves the moment loadLatestReturns() finishes.
    return Watch((context) {
      final company = fundController.companiesById.value[fund.companyId];
      final latestReturn =
          performanceController.latestReturns.value[fund.fundId];
      final manager = company?.companyName;

      return InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FundDetailScreen(fund: fund)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _kDivider)),
          ),
          child: Row(
            children: [
              _CategoryAvatar(fund: fund),
              const SizedBox(width: 12),
              // Identity: ticker on top, name · manager beneath.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fund.fundCode ?? fund.fundName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        fund.fundName,
                        if (manager != null) manager,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Latest return + management fee, right-aligned.
              SizedBox(
                width: _kNumberCol,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      latestReturn == null
                          ? '—'
                          : '${latestReturn.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fund.managementFee == null
                          ? '—'
                          : '${fund.managementFee!.toStringAsFixed(2)}% p.a.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // The signature solid pill: green when strong, red when weak.
              SizedBox(
                width: _kPillCol,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: latestReturn == null
                      ? const SizedBox.shrink()
                      : _ReturnPill(returnRate: latestReturn),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Circular avatar coloured by the fund's category, showing the first two
/// letters of its code (or name) — the stand-in for the design's brand logos.
class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({required this.fund});

  final Fund fund;

  @override
  Widget build(BuildContext context) {
    final color = _kCategoryColors[fund.categoryId] ?? _kTextSecondary;
    final source = (fund.fundCode ?? fund.fundName).trim();
    final initials = source.length >= 2
        ? source.substring(0, 2).toUpperCase()
        : source.toUpperCase();
    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Solid rounded pill showing the latest annual return: green at or above
/// [_kStrongReturn], red below. White bold text, like the design's change chip.
class _ReturnPill extends StatelessWidget {
  const _ReturnPill({required this.returnRate});

  final double returnRate;

  @override
  Widget build(BuildContext context) {
    final color = returnRate >= _kStrongReturn ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${returnRate.toStringAsFixed(2)}%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
