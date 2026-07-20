import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../dependency_injection.dart';
import '../models/fund.dart';

// ---- Design tokens (shared look with the markets list / detail) ----------
const _kGold = Color(0xFFF0B90B);
const _kFieldBg = Color(0xFFF3F4F6);
const _kTextSecondary = Color(0xFF8A8A8E);

/// Create/edit form. One screen handles both modes:
///  - existingFund == null  -> "Add fund" (fundId 0 signals a create)
///  - existingFund != null  -> "Edit fund" (fields pre-filled)
class FundFormScreen extends StatefulWidget {
  const FundFormScreen({super.key, this.existingFund});

  final Fund? existingFund;

  @override
  State<FundFormScreen> createState() => _FundFormScreenState();
}

class _FundFormScreenState extends State<FundFormScreen> {
  final _fundController = DI.fundController;
  final _categoryController = DI.categoryController;

  /// Standard Flutter Form machinery: the key lets us run all validators
  /// at once on save.
  final _formKey = GlobalKey<FormState>();

  // Text inputs use controllers; dropdowns use plain fields + setState,
  // because this is *ephemeral, screen-local* state — signals are reserved
  // for state that outlives a screen or is shared between screens.
  late final _nameController =
      TextEditingController(text: widget.existingFund?.fundName);
  late final _codeController =
      TextEditingController(text: widget.existingFund?.fundCode);
  late final _feeController = TextEditingController(
      text: widget.existingFund?.managementFee?.toString());
  late final _descriptionController =
      TextEditingController(text: widget.existingFund?.description);
  late final _objectiveController =
      TextEditingController(text: widget.existingFund?.investmentObjective);

  late int? _categoryId = widget.existingFund?.categoryId;
  late int? _companyId = widget.existingFund?.companyId;
  late String _currency = widget.existingFund?.currency ?? 'KES';

  bool get _isEditing => widget.existingFund != null;

  /// TextEditingControllers hold native resources — always dispose them.
  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _feeController.dispose();
    _descriptionController.dispose();
    _objectiveController.dispose();
    super.dispose();
  }

  /// Validate -> assemble a Fund -> hand it to the controller.
  /// The screen never touches a repository directly.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final base = widget.existingFund;
    final fund = Fund(
      fundId: base?.fundId ?? 0, // 0 = create (see FundController.saveFund)
      fundName: _nameController.text.trim(),
      fundCode: _emptyToNull(_codeController.text),
      companyId: _companyId,
      categoryId: _categoryId,
      currency: _currency,
      managementFee: double.tryParse(_feeController.text.trim()),
      description: _emptyToNull(_descriptionController.text),
      investmentObjective: _emptyToNull(_objectiveController.text),
      isActive: base?.isActive ?? true,
      createdAt: base?.createdAt ?? now,
      updatedAt: now,
    );

    final success = await _fundController.saveFund(fund);
    if (success && mounted) Navigator.of(context).pop();
  }

  /// Converts whitespace-only input to null so optional DB columns
  /// stay NULL instead of storing empty strings.
  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  /// Shared filled-input styling: soft grey fill, rounded corners, and a
  /// gold focus ring — matching the search pill and the rest of the theme.
  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kTextSecondary),
        floatingLabelStyle: const TextStyle(color: Colors.black),
        filled: true,
        fillColor: _kFieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kGold, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit fund' : 'Add fund')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: _decoration('Fund name *'),
              textCapitalization: TextCapitalization.words,
              // Only truly required field — mirrors NOT NULL in the schema.
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Fund name is required'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _codeController,
              decoration: _decoration('Fund code'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 14),
            _buildCategoryDropdown(),
            const SizedBox(height: 14),
            _buildCompanyDropdown(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildCurrencyDropdown()),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _feeController,
                    decoration: _decoration('Mgmt fee % p.a.'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    // Optional, but if present it must parse as a number.
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      return double.tryParse(value.trim()) == null
                          ? 'Enter a valid number'
                          : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              decoration: _decoration('Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _objectiveController,
              decoration: _decoration('Investment objective'),
              maxLines: 2,
            ),
            const SizedBox(height: 28),
            // Watch so the button disables + shows progress while
            // FundController.saveFund is running.
            Watch((context) {
              final saving = _fundController.isLoading.value;
              return SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGold,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: _kGold.withValues(alpha: 0.5),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: saving ? null : _save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isEditing ? 'Save changes' : 'Create fund'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Category dropdown fed by the category signal — Watch means the
  /// options appear automatically once loadCategories() completes.
  Widget _buildCategoryDropdown() {
    return Watch((context) {
      final categories = _categoryController.categories.value;
      return DropdownButtonFormField<int>(
        initialValue: _categoryId,
        decoration: _decoration('Category'),
        borderRadius: BorderRadius.circular(12),
        items: [
          for (final c in categories)
            DropdownMenuItem(value: c.categoryId, child: Text(c.categoryName)),
        ],
        onChanged: (value) => setState(() => _categoryId = value),
      );
    });
  }

  /// Company dropdown fed by the companies signal on FundController.
  Widget _buildCompanyDropdown() {
    return Watch((context) {
      final companies = _fundController.companies.value;
      return DropdownButtonFormField<int>(
        initialValue: _companyId,
        decoration: _decoration('Fund manager'),
        borderRadius: BorderRadius.circular(12),
        items: [
          for (final c in companies)
            DropdownMenuItem(value: c.companyId, child: Text(c.companyName)),
        ],
        onChanged: (value) => setState(() => _companyId = value),
      );
    });
  }

  /// Currency is a plain local dropdown — nothing else depends on it.
  Widget _buildCurrencyDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _currency,
      decoration: _decoration('Currency'),
      borderRadius: BorderRadius.circular(12),
      items: const [
        DropdownMenuItem(value: 'KES', child: Text('KES')),
        DropdownMenuItem(value: 'USD', child: Text('USD')),
      ],
      onChanged: (value) => setState(() => _currency = value ?? 'KES'),
    );
  }
}
