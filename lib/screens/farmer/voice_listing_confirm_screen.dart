import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/voice_listing_draft.dart';
import '../../providers/service_providers.dart';
import '../../providers/voice_listing_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/image_upload_field.dart';
import '../../widgets/page_header.dart';
import '../../widgets/panel_ui.dart';
import 'products/product_form_screen.dart';

class VoiceListingConfirmScreen extends ConsumerStatefulWidget {
  final String farmerId;
  final VoiceListingDraft? initialDraft;

  const VoiceListingConfirmScreen({
    super.key,
    required this.farmerId,
    this.initialDraft,
  });

  @override
  ConsumerState<VoiceListingConfirmScreen> createState() =>
      _VoiceListingConfirmScreenState();
}

class _VoiceListingConfirmScreenState
    extends ConsumerState<VoiceListingConfirmScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _typeInsteadController = TextEditingController();

  String? _imageUrl;
  List<CategoryModel> _categories = [];
  String? _categoryId;
  String _unit = ProductUnits.all.first;
  bool _isAvailable = true;
  bool _loadingCategories = true;
  bool _saving = false;
  bool _submitted = false;
  bool _showTypeInstead = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialDraft != null) {
      _applyDraft(widget.initialDraft!);
    } else {
      _showTypeInstead = true;
    }
    _loadCategories();
  }

  void _applyDraft(VoiceListingDraft draft) {
    _nameController.text = draft.itemName;
    _descriptionController.text = draft.description;
    _priceController.text = draft.pricePerUnit == draft.pricePerUnit.roundToDouble()
        ? draft.pricePerUnit.toStringAsFixed(0)
        : draft.pricePerUnit.toStringAsFixed(2);
    _stockController.text = draft.quantity.toString();
    _unit = ProductUnits.all.contains(draft.unit)
        ? draft.unit
        : ProductUnits.all.first;
    _categoryId = draft.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _typeInsteadController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final categories =
          await ref.read(categoryServiceProvider).getActiveCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (_categoryId != null &&
            !categories.any((c) => c.categoryId == _categoryId)) {
          _categoryId = null;
        }
        _loadingCategories = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  String? get _nameError {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'Enter the product name.';
    if (name.length < 2) return 'Name needs at least 2 characters.';
    if (name.length > 100) return 'Keep the name under 100 characters.';
    return null;
  }

  String? get _categoryError => _categoryId == null ? 'Pick a category.' : null;

  String? get _priceError {
    final price = double.tryParse(_priceController.text.trim());
    if (_priceController.text.trim().isEmpty) return 'Enter a price.';
    if (price == null || price <= 0) return 'Price must be more than 0.';
    if (price > 1000000) return 'That price looks too high.';
    return null;
  }

  String? get _stockError {
    final stock = int.tryParse(_stockController.text.trim());
    if (_stockController.text.trim().isEmpty) return 'Enter the stock.';
    if (stock == null || stock < 0) return 'Stock cannot be negative.';
    return null;
  }

  String? get _descriptionError =>
      _descriptionController.text.trim().length > 500
          ? 'Keep the description under 500 characters.'
          : null;

  bool get _isValid =>
      _nameError == null &&
      _categoryError == null &&
      _priceError == null &&
      _stockError == null &&
      _descriptionError == null;

  Future<void> _processTypedText() async {
    final text = _typeInsteadController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    final notifier = ref.read(voiceListingProvider.notifier);
    await notifier.submitText(text, _categories);

    final listingState = ref.read(voiceListingProvider);
    if (!mounted) return;

    if (listingState.draft != null) {
      setState(() {
        _applyDraft(listingState.draft!);
        _showTypeInstead = false;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
        'Product details updated from text',
        tone: SnackTone.success,
      ));
    } else if (listingState.errorMessage != null) {
      setState(() {
        _error = listingState.errorMessage;
      });
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _error = null;
    });

    if (!_isValid) {
      setState(() => _error = 'Fix the highlighted fields to continue.');
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final product = ProductModel(
      productId: '',
      farmerId: widget.farmerId,
      categoryId: _categoryId!,
      itemName: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      pricePerUnit: double.parse(_priceController.text.trim()),
      unit: _unit,
      stockQty: int.parse(_stockController.text.trim()),
      imageUrl: _imageUrl,
      isAvailable: _isAvailable,
      createdAt: now,
      updatedAt: now,
    );

    final productService = ref.read(productServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await productService.createProduct(product);
      if (!mounted) return;
      // Pop confirm screen and then pop form screen if open
      Navigator.of(context).pop(true);
      messenger.showSnackBar(appSnackBar(
        '${product.itemName} added to your shop',
        tone: SnackTone.success,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not save this product. Check your connection and try again.';
        _saving = false;
      });
    }
  }

  void _openManualForm() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ProductFormScreen(farmerId: widget.farmerId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final showErrors = _submitted;
    final error = _error;
    final listingState = ref.watch(voiceListingProvider);

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              title: 'Confirm listing',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _buildAiNoticeHeader(),
                      const SizedBox(height: 16),
                      if (_showTypeInstead) ...[
                        _buildTypeInsteadCard(listingState.isProcessing),
                        const SizedBox(height: 16),
                      ],
                      const PanelSectionLabel('Photo (optional)'),
                      PanelCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ImageUploadField(
                              size: 104,
                              initialImageUrl: _imageUrl,
                              onUploaded: (url) =>
                                  setState(() => _imageUrl = url),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Product photo',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: PanelColors.textMain)),
                                    SizedBox(height: 4),
                                    Text(
                                      'Add a clear photo if you have one. You can also add it later.',
                                      style: TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: PanelColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const PanelSectionLabel('Product Details'),
                      PanelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              key: const ValueKey('voice_product_name_field'),
                              controller: _nameController,
                              enabled: !_saving,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(100)
                              ],
                              onChanged: (_) => setState(() {}),
                              decoration: panelInputDecoration(
                                'Product name',
                                hint: 'e.g. Sindhri Mango',
                                error: showErrors ? _nameError : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Category',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: PanelColors.textBody)),
                            const SizedBox(height: 8),
                            _buildCategoryPicker(showErrors),
                            const SizedBox(height: 16),
                            TextField(
                              key: const ValueKey(
                                  'voice_product_description_field'),
                              controller: _descriptionController,
                              enabled: !_saving,
                              minLines: 2,
                              maxLines: 4,
                              maxLength: 500,
                              textCapitalization:
                                  TextCapitalization.sentences,
                              onChanged: (_) => setState(() {}),
                              decoration: panelInputDecoration(
                                'Description (optional)',
                                hint: 'Short note about freshness or quality',
                                error: showErrors ? _descriptionError : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const PanelSectionLabel('Price and stock'),
                      PanelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Sold by',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: PanelColors.textBody)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final unit in ProductUnits.all)
                                  ChoiceChip(
                                    label: Text(unit),
                                    selected: _unit == unit,
                                    onSelected: _saving
                                        ? null
                                        : (_) => setState(() => _unit = unit),
                                    selectedColor: PanelColors.brand,
                                    backgroundColor: PanelColors.pageBg,
                                    showCheckmark: false,
                                    side: BorderSide(
                                        color: _unit == unit
                                            ? PanelColors.brand
                                            : PanelColors.border),
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _unit == unit
                                          ? Colors.white
                                          : PanelColors.textBody,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: const ValueKey(
                                        'voice_product_price_field'),
                                    controller: _priceController,
                                    enabled: !_saving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d{0,7}(\.\d{0,2})?')),
                                    ],
                                    onChanged: (_) => setState(() {}),
                                    decoration: panelInputDecoration(
                                      'Price per $_unit',
                                      prefixText: 'Rs. ',
                                      error: showErrors ? _priceError : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    key: const ValueKey(
                                        'voice_product_stock_field'),
                                    controller: _stockController,
                                    enabled: !_saving,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    onChanged: (_) => setState(() {}),
                                    decoration: panelInputDecoration(
                                      'Stock ($_unit)',
                                      error: showErrors ? _stockError : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const PanelSectionLabel('Visibility'),
                      PanelCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeTrackColor: PanelColors.brand,
                          value: _isAvailable,
                          onChanged: _saving
                              ? null
                              : (value) =>
                                  setState(() => _isAvailable = value),
                          title: const Text('Show to customers',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: PanelColors.textMain)),
                          subtitle: const Text(
                            'Customers can see and order this item.',
                            style: TextStyle(
                                fontSize: 13, color: PanelColors.textMuted),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setState(() =>
                                  _showTypeInstead = !_showTypeInstead);
                            },
                            icon: Icon(_showTypeInstead
                                ? Icons.keyboard_hide_outlined
                                : Icons.edit_note_outlined),
                            label: Text(_showTypeInstead
                                ? 'Hide typed input'
                                : 'Type instead'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _openManualForm,
                            icon: const Icon(Icons.assignment_outlined),
                            label: const Text('Open manual form'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: PanelColors.brandDark.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 16, color: PanelColors.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(error,
                                style: const TextStyle(
                                    fontSize: 13, color: PanelColors.danger)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const ValueKey('voice_confirm_save_button'),
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: PanelColors.brand,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Confirm listing',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiNoticeHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCE6CF)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: Color(0xFF2E7D32), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filled by AI - please check',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Review product name, category, quantity and price before confirming.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF388E3C)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeInsteadCard(bool isProcessing) {
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Type instead',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PanelColors.textMain),
          ),
          const SizedBox(height: 4),
          const Text(
            'e.g. "5 kilo tamatar 80 rupees kilo" or "10 dozen kela 150 rs"',
            style: TextStyle(fontSize: 13, color: PanelColors.textMuted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _typeInsteadController,
            enabled: !isProcessing,
            textCapitalization: TextCapitalization.sentences,
            decoration: panelInputDecoration(
              'Product details',
              hint: 'e.g. 5 kilo tamatar 80 rupees kilo',
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isProcessing ? null : _processTypedText,
              style: FilledButton.styleFrom(backgroundColor: PanelColors.brand),
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_fix_high, size: 18),
              label: Text(isProcessing ? 'Extracting...' : 'Extract listing'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker(bool showErrors) {
    if (_loadingCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(color: PanelColors.brand),
      );
    }
    if (_categories.isEmpty) {
      return const Text(
        'No categories found.',
        style: TextStyle(fontSize: 13, color: PanelColors.amber),
      );
    }

    final categoryError = showErrors ? _categoryError : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in _categories)
              ChoiceChip(
                label: Text(category.name),
                selected: _categoryId == category.categoryId,
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _categoryId = category.categoryId),
                selectedColor: PanelColors.brand,
                backgroundColor: PanelColors.pageBg,
                showCheckmark: false,
                side: BorderSide(
                    color: _categoryId == category.categoryId
                        ? PanelColors.brand
                        : PanelColors.border),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _categoryId == category.categoryId
                      ? Colors.white
                      : PanelColors.textBody,
                ),
              ),
          ],
        ),
        if (categoryError != null) ...[
          const SizedBox(height: 6),
          Text(categoryError,
              style: const TextStyle(fontSize: 12, color: PanelColors.danger)),
        ],
      ],
    );
  }
}
