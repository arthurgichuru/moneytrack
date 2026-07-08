import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrack/controllers/fund_controller.dart';
import 'package:moneytrack/repositories/fund_management_company_repository.dart';
import 'package:moneytrack/repositories/fund_repository.dart';

/// Example test: proves the filteredFunds computed reacts to the
/// searchQuery and selectedCategoryId signals with no widgets involved —
/// one of the big wins of keeping logic in controllers.
void main() {
  test('filteredFunds narrows by search query and category', () async {
    final controller = FundController(
      DummyFundRepository(),
      DummyFundManagementCompanyRepository(),
    );

    await controller.loadFunds();
    expect(controller.filteredFunds.value.length, 10);

    // Typing in the (virtual) search box…
    controller.searchQuery.value = 'money market';
    expect(controller.filteredFunds.value.length, 4);

    // …then also tapping the Money Market chip (categoryId 1).
    controller.selectedCategoryId.value = 1;
    expect(controller.filteredFunds.value.length, 4);

    // Clearing the search but keeping the chip.
    controller.searchQuery.value = '';
    expect(
      controller.filteredFunds.value.every((f) => f.categoryId == 1),
      isTrue,
    );
  });
}
