import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/smart_basket.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/session_providers.dart';
import '../../providers/smart_basket_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/panel_ui.dart';

class SmartBasketScreen extends ConsumerStatefulWidget {
  const SmartBasketScreen({super.key});

  @override
  ConsumerState<SmartBasketScreen> createState() => _SmartBasketScreenState();
}

class _SmartBasketScreenState extends ConsumerState<SmartBasketScreen> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _useExample(String text) {
    _queryController.text = text;
    setState(() {});
  }

  Future<void> _submit() async {
    final text = _queryController.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();

    final productsAsync = ref.read(catalogProductsProvider(null));
    final products = productsAsync.valueOrNull ?? [];

    final farmerOptions = ref.read(catalogFilterOptionsProvider).valueOrNull;
    final farmerNames = <String, String>{};
    if (farmerOptions != null) {
      for (final f in farmerOptions.farmers) {
        farmerNames[f.farmerId] = f.businessName;
      }
    }

    await ref.read(smartBasketProvider.notifier).buildBasket(
          text,
          catalogProducts: products,
          farmerNames: farmerNames,
        );
  }

  Future<void> _addAllToCart() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar('Please sign in to add items to your cart.', tone: SnackTone.error),
      );
      return;
    }

    final success = await ref.read(smartBasketProvider.notifier).addAllToCart(uid);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar('All items added to your cart!', tone: SnackTone.success),
      );
    }
  }

  void _goToCart() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartBasketProvider);
    final notifier = ref.read(smartBasketProvider.notifier);

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              title: 'Smart Basket',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _buildInputCard(state),
                      const SizedBox(height: 16),
                      if (state.isProcessing)
                        _buildLoadingCard(notifier)
                      else if (state.errorMessage != null && state.result == null)
                        _buildErrorCard(state.errorMessage!)
                      else if (state.result != null)
                        _buildReviewSection(state, notifier),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(SmartBasketState state) {
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tell us what you need',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PanelColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Type items with quantities or describe your family size & budget.',
            style: TextStyle(fontSize: 13, color: PanelColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('smart_basket_query_field'),
            controller: _queryController,
            enabled: !state.isProcessing,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: panelInputDecoration(
              'Shopping request',
              hint: 'e.g. 5 log, Rs 3000, hafta bhar ki sabzi',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text('2 kg tamatar, 1 dozen kela', style: TextStyle(fontSize: 12)),
                onPressed: state.isProcessing
                    ? null
                    : () => _useExample('2 kg tamatar, 1 dozen kela'),
              ),
              ActionChip(
                label: const Text('5 log, Rs 3000, hafta bhar ki sabzi', style: TextStyle(fontSize: 12)),
                onPressed: state.isProcessing
                    ? null
                    : () => _useExample('5 log, Rs 3000, hafta bhar ki sabzi'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('smart_basket_submit_button'),
            onPressed: state.isProcessing ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: PanelColors.brand,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(
              state.isProcessing ? 'Building...' : 'Build my basket',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(SmartBasketNotifier notifier) {
    return PanelCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: PanelColors.brand,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Analyzing your request & checking stock...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: PanelColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Finding best prices and matching quantities (max 12s)',
            style: TextStyle(fontSize: 12, color: PanelColors.textMuted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: notifier.cancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PanelColors.dangerBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: PanelColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 13, color: PanelColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(SmartBasketState state, SmartBasketNotifier notifier) {
    final result = state.result!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNoticeHeader(result),
        const SizedBox(height: 14),
        if (result.lines.isEmpty)
          const PanelCard(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                'No matching products available right now.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: PanelColors.textMuted),
              ),
            ),
          )
        else ...[
          for (var i = 0; i < result.lines.length; i++) ...[
            _buildBasketRow(result.lines[i], i, notifier),
            const SizedBox(height: 10),
          ],
        ],
        if (result.notFoundItems.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildNotFoundCard(result.notFoundItems),
        ],
        const SizedBox(height: 14),
        _buildSummaryCard(result, state),
      ],
    );
  }

  Widget _buildNoticeHeader(SmartBasketResult result) {
    final isFallback = result.isFallback;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFallback ? PanelColors.amberBg : const Color(0xFFEAF5EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFallback ? const Color(0xFFF3D58C) : const Color(0xFFCCE6CF)),
      ),
      child: Row(
        children: [
          Icon(
            isFallback ? Icons.info_outline_rounded : Icons.auto_awesome_rounded,
            color: isFallback ? PanelColors.amber : const Color(0xFF2E7D32),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFallback
                  ? 'AI is not available, using simple search. Please check quantities.'
                  : 'Suggested by AI - please check quantities and items before adding.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFallback ? const Color(0xFF7A5200) : const Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasketRow(SmartBasketLine line, int index, SmartBasketNotifier notifier) {
    final product = line.product;

    return PanelCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.itemName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PanelColors.textMain,
                      ),
                    ),
                    if (line.farmerName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'from ${line.farmerName}',
                        style: const TextStyle(fontSize: 12, color: PanelColors.textMuted),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Rs. ${product.pricePerUnit.toStringAsFixed(0)} / ${product.unit}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PanelColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${line.lineTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: PanelColors.textMain,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: PanelColors.danger),
                    onPressed: () => notifier.removeLine(index),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 12, color: PanelColors.border),
          Row(
            children: [
              if (line.checkQuantity)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: PanelColors.amberBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: PanelColors.amber),
                      SizedBox(width: 4),
                      Text(
                        'Check quantity',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PanelColors.amber),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                    color: PanelColors.textBody,
                    onPressed: line.quantity > 1
                        ? () => notifier.updateLineQuantity(index, line.quantity - 1)
                        : null,
                    visualDensity: VisualDensity.compact,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${line.quantity} ${product.unit}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    color: PanelColors.brand,
                    onPressed: line.quantity < product.stockQty
                        ? () => notifier.updateLineQuantity(index, line.quantity + 1)
                        : null,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundCard(List<String> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEDAC0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.search_off_rounded, color: Color(0xFF9E6514), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Not found in current stock:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7A4B06)),
                ),
                const SizedBox(height: 2),
                Text(
                  items.join(', '),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8F5A0D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(SmartBasketResult result, SmartBasketState state) {
    final budget = result.budget;
    final total = result.total;
    final isOver = result.isOverBudget;

    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Basket Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(
                'Rs. ${total.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: PanelColors.brand),
              ),
            ],
          ),
          if (budget != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Budget', style: TextStyle(fontSize: 13, color: PanelColors.textMuted)),
                Text(
                  'Rs. ${total.toStringAsFixed(0)} of Rs. ${budget.toStringAsFixed(0)} budget',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isOver ? PanelColors.danger : PanelColors.brand,
                  ),
                ),
              ],
            ),
          ],
          if (result.budgetAdjustments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PanelColors.tint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final adj in result.budgetAdjustments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• $adj', style: const TextStyle(fontSize: 11, color: PanelColors.brand)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (result.lines.isNotEmpty)
            SizedBox(
              height: 50,
              child: state.addedToCart
                  ? OutlinedButton.icon(
                      onPressed: _goToCart,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PanelColors.brand,
                        side: const BorderSide(color: PanelColors.brand),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, color: PanelColors.brand),
                      label: const Text('Added to Cart! Go to Cart', style: TextStyle(fontWeight: FontWeight.w700)),
                    )
                  : FilledButton.icon(
                      key: const ValueKey('smart_basket_add_cart_button'),
                      onPressed: state.isAddingToCart ? null : _addAllToCart,
                      style: FilledButton.styleFrom(
                        backgroundColor: PanelColors.brand,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: state.isAddingToCart
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.shopping_cart_checkout_rounded),
                      label: Text(
                        state.isAddingToCart ? 'Adding to cart...' : 'Add all to cart',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
