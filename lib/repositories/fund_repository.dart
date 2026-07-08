import '../models/fund.dart';
import 'dummy_data.dart';

/// Contract for reading *and writing* funds — the only entity the
/// user can create/edit in this app.
abstract class FundRepository {
  /// All funds (active and inactive — the controller decides what to show).
  Future<List<Fund>> getFunds();

  /// Inserts a fund and returns it with its server-assigned id.
  Future<Fund> createFund(Fund fund);

  /// Updates an existing fund and returns the stored version.
  Future<Fund> updateFund(Fund fund);

  /// Soft-deletes: real financial systems rarely hard-delete records
  /// with performance history hanging off them, so we flip is_active
  /// instead — matching what we'll do with Supabase later.
  Future<void> deactivateFund(int fundId);
}

/// Iteration-1 implementation: keeps a private mutable copy of the seed
/// list so create/update/deactivate behave like a real backend for the
/// lifetime of the app session.
class DummyFundRepository implements FundRepository {
  // Private working copy — mutating DummyData.funds directly would leak
  // state between repository instances.
  final List<Fund> _funds = List<Fund>.from(DummyData.funds);

  /// Next id for created funds (max existing id + 1, like a SERIAL column).
  int get _nextId =>
      _funds.map((f) => f.fundId).fold(0, (a, b) => a > b ? a : b) + 1;

  @override
  Future<List<Fund>> getFunds() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return List<Fund>.unmodifiable(_funds);
  }

  @override
  Future<Fund> createFund(Fund fund) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // copyWith stamps the new id, mimicking Postgres SERIAL assignment.
    final created = fund.copyWith(fundId: _nextId, updatedAt: DateTime.now());
    _funds.add(created);
    return created;
  }

  @override
  Future<Fund> updateFund(Fund fund) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _funds.indexWhere((f) => f.fundId == fund.fundId);
    if (index == -1) {
      throw StateError('Fund ${fund.fundId} not found');
    }
    final updated = fund.copyWith(updatedAt: DateTime.now());
    _funds[index] = updated;
    return updated;
  }

  @override
  Future<void> deactivateFund(int fundId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _funds.indexWhere((f) => f.fundId == fundId);
    if (index == -1) return; // already gone — nothing to do
    _funds[index] = _funds[index].copyWith(isActive: false);
  }
}
