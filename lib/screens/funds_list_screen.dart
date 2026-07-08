import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../dependency_injection.dart';
import '../models/fund.dart';
import 'fund_detail_screen.dart';
import 'fund_form_screen.dart';

/// Home screen: search box + category chips + the filtered fund list.
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

  /// Kick off the three initial loads. They write into signals when they
  /// complete, so the UI updates itself — no await, no setState needed.
  @override
  void initState() {
    super.initState();
    _fundController.loadFunds();
    _categoryController.loadCategories();
    _performanceController.loadLatestReturns();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MoneyTrack')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FundFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add fund'),
      ),
      body: Column(
        children: [
          _buildSearchField(),
          _buildCategoryChips(),
          Expanded(child: _buildFundList()),
        ],
      ),
    );
  }

  /// Search box. onChanged writes straight into the searchQuery signal;
  /// filteredFunds recomputes and the list below repaints. That one line
  /// IS the entire search feature.
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search fund name or code…',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
        onChanged: (text) => _fundController.searchQuery.value = text,
      ),
    );
  }

  /// Horizontal row of filter chips: "All" + one chip per category.
  /// Wrapped in Watch because it reads two signals: the category list
  /// (async-loaded) and the current selection.
  Widget _buildCategoryChips() {
    return Watch((context) {
      final categories = _categoryController.categories.value;
      final selectedId = _fundController.selectedCategoryId.value;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: selectedId == null,
              onSelected: (_) =>
                  _fundController.selectedCategoryId.value = null,
            ),
            for (final category in categories) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(category.categoryName),
                selected: selectedId == category.categoryId,
                // Tapping the active chip clears the filter (toggle).
                onSelected: (_) => _fundController.selectedCategoryId.value =
                    selectedId == category.categoryId
                        ? null
                        : category.categoryId,
              ),
            ],
          ],
        ),
      );
    });
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

/// One row in the list: name, code + manager, latest-return badge.
/// Split into its own widget so each row stays cheap to rebuild.
class _FundTile extends StatelessWidget {
  const _FundTile({required this.fund});

  final Fund fund;

  @override
  Widget build(BuildContext context) {
    final fundController = DI.fundController;
    final performanceController = DI.performanceController;

    // This Watch reads companiesById and latestReturns, so the badge pops
    // in by itself the moment loadLatestReturns() finishes.
    return Watch((context) {
      final company = fundController.companiesById.value[fund.companyId];
      final latestReturn =
          performanceController.latestReturns.value[fund.fundId];

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          title: Text(fund.fundName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            [
              if (fund.fundCode != null) fund.fundCode!,
              if (company != null) company.companyName,
            ].join(' · '),
          ),
          trailing: latestReturn == null
              ? null
              : _ReturnBadge(returnRate: latestReturn),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FundDetailScreen(fund: fund)),
          ),
        ),
      );
    });
  }
}

/// Small pill showing the latest annual return, green when >= 10%,
/// amber below — a quick visual scan aid, not investment advice.
class _ReturnBadge extends StatelessWidget {
  const _ReturnBadge({required this.returnRate});

  final double returnRate;

  @override
  Widget build(BuildContext context) {
    final color = returnRate >= 10 ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${returnRate.toStringAsFixed(2)}%',
        style: TextStyle(color: color.shade700, fontWeight: FontWeight.bold),
      ),
    );
  }
}
