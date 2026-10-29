import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/service_providers.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/image_upload_field.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/panel_ui.dart';
import '../voice_listing_modal.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String farmerId;
  final ProductModel? existing;

  const ProductFormScreen({super.key, required this.farmerId, this.existing});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  String? _imageUrl;

  List<CategoryModel> _categories = [];
  String? _categoryId;
  String _unit = ProductUnits.all.first;
  bool _isAvailable = true;
  bool _loadingCategories = true;
  bool _categoriesFailed = false;
  bool _saving = false;
  bool _submitted = false;
  String? _error;
  late final String _initialSnapshot;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.itemName;
      _descriptionController.text = existing.description;
      _priceController.text = _formatPrice(existing.pricePerUnit);
      _stockController.text = existing.stockQty.toString();
      _imageUrl = existing.imageUrl;
      _categoryId = existing.categoryId;
      _unit = ProductUnits.all.contains(existing.unit)
          ? existing.unit
          : ProductUnits.all.first;
      _isAvailable = existing.isAvailable;
    }
    _initialSnapshot = _snapshot();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) return price.toStringAsFixed(0);
    return price.toStringAsFixed(2);
  }

  String _snapshot() {
    return [
      _nameController.text.trim(),
      _descriptionController.text.trim(),
      _priceController.text.trim(),
      _stockController.text.trim(),
      _imageUrl ?? '',
      _categoryId ?? '',
      _unit,
      '$_isAvailable',
    ].join('|');
  }

  bool get _isDirty => _snapshot() != _initialSnapshot;

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoriesFailed = false;
    });
    try {
      final categories =
          await ref.read(categoryServiceProvider).getActiveCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        final stillExists = categories.any((c) => c.categoryId == _categoryId);
        if (!stillExists) _categoryId = null;
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        _categoriesFailed = true;
      });
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
      productId: widget.existing?.productId ?? '',
      farmerId: widget.farmerId,
      categoryId: _categoryId!,
      itemName: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      pricePerUnit: double.parse(_priceController.text.trim()),
      unit: _unit,
      stockQty: int.parse(_stockController.text.trim()),
      imageUrl: _imageUrl,
      isAvailable: _isAvailable,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );

    final productService = ref.read(productServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isEditing) {
        await productService.updateProduct(product);
      } else {
        await productService.createProduct(product);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(appSnackBar(
        _isEditing
            ? '${product.itemName} updated'
            : '${product.itemName} added to your shop',
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

  Future<void> _delete() async {
    final name = _nameController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this product?'),
        content: Text(
            '$name will be removed from your shop. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: PanelColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(productServiceProvider)
          .deleteProduct(widget.existing!.productId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger
          .showSnackBar(appSnackBar('$name deleted', tone: SnackTone.success));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not delete this product. Please try again.';
        _saving = false;
      });
    }
  }

  Future<void> _handleBack() async {
    if (_saving || !_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes to this product will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: PanelColors.danger),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final showErrors = _submitted;
    final error = _error;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: PanelColors.pageBg,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              PageHeader(
                title: _isEditing ? 'Edit product' : 'Add product',
                onBack: _handleBack,
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
                        if (!_isEditing) ...[
                          _buildVoiceListingBanner(),
                          const SizedBox(height: 16),
                        ],
                        const PanelSectionLabel('Photo'),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Add a clear photo',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: PanelColors.textMain)),
                                      SizedBox(height: 4),
                                      Text(
                                        'Good light and a plain background help customers pick your produce. JPG, PNG or WEBP under 5 MB.',
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
                        const PanelSectionLabel('Details'),
                        PanelCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                key: const ValueKey('product_name_field'),
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
                                key:
                                    const ValueKey('product_description_field'),
                                controller: _descriptionController,
                                enabled: !_saving,
                                minLines: 3,
                                maxLines: 5,
                                maxLength: 500,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onChanged: (_) => setState(() {}),
                                decoration: panelInputDecoration(
                                  'Description (optional)',
                                  hint:
                                      'Where it is grown, taste, how fresh it is',
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
                                      key:
                                          const ValueKey('product_price_field'),
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
                                      key:
                                          const ValueKey('product_stock_field'),
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
                            key: const ValueKey('product_visible_switch'),
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
                            subtitle: Text(
                              _isAvailable
                                  ? 'Customers can see and order this item.'
                                  : 'Hidden from the shop until you turn it on.',
                              style: const TextStyle(
                                  fontSize: 13, color: PanelColors.textMuted),
                            ),
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            key: const ValueKey('product_delete_button'),
                            onPressed: _saving ? null : _delete,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: PanelColors.danger,
                              minimumSize: const Size(0, 48),
                              side: const BorderSide(color: Color(0xFFF0B4B4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Delete product',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
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
                          key: const ValueKey('product_save_button'),
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
                                      strokeWidth: 2, color: PanelColors.brand),
                                )
                              : Text(
                                  _isEditing ? 'Save changes' : 'Add to shop',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
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
    if (_categoriesFailed) {
      return Row(
        children: [
          const Expanded(
            child: Text('Categories did not load.',
                style: TextStyle(fontSize: 13, color: PanelColors.danger)),
          ),
          TextButton(onPressed: _loadCategories, child: const Text('Retry')),
        ],
      );
    }
    if (_categories.isEmpty) {
      return const Text(
        'No categories exist yet. Ask an administrator to add one before listing products.',
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

  Widget _buildVoiceListingBanner() {
    return PanelCard(
      onTap: () async {
        final saved = await showVoiceListingSheet(context, widget.farmerId);
        if (saved == true && mounted) {
          Navigator.of(context).pop(true);
        }
      },
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PanelColors.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.mic_rounded,
                color: PanelColors.brand, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Speak your product',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PanelColors.brand,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Say item, quantity, unit and price to auto-fill',
                  style: TextStyle(fontSize: 12, color: PanelColors.textMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: PanelColors.textMuted),
        ],
      ),
    );
  }
}
