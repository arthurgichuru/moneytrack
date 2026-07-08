import 'package:signals/signals_flutter.dart';

import '../models/fund.dart';
import '../models/fund_management_company.dart';
import '../repositories/fund_management_company_repository.dart';
import '../repositories/fund_repository.dart';

/// The main controller: owns the fund list, the search box text and the
/// active category filter, and exposes the filtered result as a computed.
class FundController {
  FundController(this._fundRepository, this._companyRepository);

  final FundRepository _fundRepository;
  final FundManagementCompanyRepository _companyRepository;

  // ---------------------------------------------------------------- state

  /// Every fund known to the app (the unfiltered source of truth).
  final funds = listSignal<Fund>([]);

  /// Companies, loaded alongside funds so list rows can show manager names.
  final companies = listSignal<FundManagementCompany>([]);

  final isLoading = signal(false);
  final errorMessage = signal<String?>(null);

  /// Bound to the search TextField. Every keystroke writes here, which
  /// automatically re-runs [filteredFunds] — no setState, no listeners.
  final searchQuery = signal('');

  /// The tapped filter chip. `null` means "All categories".
  final selectedCategoryId = signal<int?>(null);

  // -------------------------------------------------------------- derived

  /// Lookup table {companyId: company} for fast name resolution in the UI.
  late final companiesById = computed(
    () => {for (final c in companies.value) c.companyId: c},
  );

  /// THE core of the screen: active funds that match both the search text
  /// and the selected category, sorted by name.
  ///
  /// It reads three signals (funds, searchQuery, selectedCategoryId), so
  /// changing any one of them recomputes this list and repaints only the
  /// widgets watching it.
  late final filteredFunds = computed(() {
    final query = searchQuery.value.trim().toLowerCase();
    final categoryId = selectedCategoryId.value;

    final result = funds.value.where((fund) {
      if (!fund.isActive) return false; // hide soft-deleted funds
      final matchesCategory =
          categoryId == null || fund.categoryId == categoryId;
      final matchesQuery = query.isEmpty ||
          fund.fundName.toLowerCase().contains(query) ||
          (fund.fundCode?.toLowerCase().contains(query) ?? false);
      return matchesCategory && matchesQuery;
    }).toList()
      ..sort((a, b) => a.fundName.compareTo(b.fundName));
    return result;
  });

  // -------------------------------------------------------------- actions

  /// Loads funds and companies in parallel (Future.wait) — one spinner,
  /// half the wait.
  Future<void> loadFunds() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final results = await Future.wait([
        _fundRepository.getFunds(),
        _companyRepository.getCompanies(),
      ]);
      funds.value = results[0] as List<Fund>;
      companies.value = results[1] as List<FundManagementCompany>;
    } catch (e) {
      errorMessage.value = 'Failed to load funds: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Create-or-update in one entry point, used by the form screen.
  /// Convention: fundId == 0 means "not yet persisted" -> create.
  /// Returns true on success so the form knows whether to pop.
  Future<bool> saveFund(Fund fund) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      if (fund.fundId == 0) {
        final created = await _fundRepository.createFund(fund);
        // listSignal.add mutates AND notifies watchers in one call.
        funds.add(created);
      } else {
        final updated = await _fundRepository.updateFund(fund);
        // Replace the old copy in place, then reassign to notify.
        final next = funds.value
            .map((f) => f.fundId == updated.fundId ? updated : f)
            .toList();
        funds.value = next;
      }
      return true;
    } catch (e) {
      errorMessage.value = 'Failed to save fund: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Soft-deletes a fund, then mirrors the change locally instead of
  /// re-fetching the whole list (cheaper, and instant in the UI).
  Future<void> deactivateFund(int fundId) async {
    try {
      await _fundRepository.deactivateFund(fundId);
      funds.value = funds.value
          .map((f) => f.fundId == fundId ? f.copyWith(isActive: false) : f)
          .toList();
    } catch (e) {
      errorMessage.value = 'Failed to delete fund: $e';
    }
  }
}
