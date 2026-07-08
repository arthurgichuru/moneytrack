import 'package:signals/signals_flutter.dart';

import '../models/fund_category.dart';
import '../repositories/fund_category_repository.dart';

/// Holds category state for the whole app.
///
/// Pattern used by every controller here:
///  - `signal(...)`      : a writable piece of state. Setting `.value`
///                         notifies every widget/computed watching it.
///  - `listSignal([...])`: a signal wrapping a List with list helpers.
///  - `computed(...)`    : derived state. Re-evaluates automatically when
///                         any signal it *reads* changes, and caches the
///                         result otherwise.
class FundCategoryController {
  FundCategoryController(this._repository);

  final FundCategoryRepository _repository;

  /// All categories, loaded once at startup.
  final categories = listSignal<FundCategory>([]);

  /// True while a load is in flight — screens show a spinner off this.
  final isLoading = signal(false);

  /// Non-null when the last load failed — screens show an error banner.
  final errorMessage = signal<String?>(null);

  /// Lookup table {categoryId: category}, derived from [categories].
  /// Because it's `computed`, it rebuilds itself only when the list
  /// actually changes — screens can read it every frame for free.
  late final categoriesById = computed(
    () => {for (final c in categories.value) c.categoryId: c},
  );

  /// Fetches categories from the repository into [categories].
  /// The try/catch/finally shape guarantees isLoading never gets stuck true.
  Future<void> loadCategories() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      categories.value = await _repository.getCategories();
    } catch (e) {
      errorMessage.value = 'Failed to load categories: $e';
    } finally {
      isLoading.value = false;
    }
  }
}
