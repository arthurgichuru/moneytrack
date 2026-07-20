import '../models/fund_category.dart';
import 'fund_catalog.dart';

/// Contract for reading fund categories.
///
/// Controllers depend on this *abstract* class, never on a concrete
/// implementation. In iteration 2 we add `SupabaseFundCategoryRepository`
/// and change one line in dependency_injection.dart.
abstract class FundCategoryRepository {
  /// Returns all categories, ordered by name.
  Future<List<FundCategory>> getCategories();
}

/// Iteration-1 implementation backed by [FundCatalog].
class DummyFundCategoryRepository implements FundCategoryRepository {
  /// Simulates a network round-trip with a short delay so loading
  /// states are actually visible in the UI.
  @override
  Future<List<FundCategory>> getCategories() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final list = List<FundCategory>.from(FundCatalog.categories)
      ..sort((a, b) => a.categoryName.compareTo(b.categoryName));
    return list;
  }
}
