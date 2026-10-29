import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product_model.dart';
import '../../../providers/service_providers.dart';
import '../../../services/product_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/panel_ui.dart';

const int _maxStock = 100000;

Future<void> showStockUpdateSheet(
    BuildContext context, WidgetRef ref, ProductModel product) {
  final productService = ref.read(productServiceProvider);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) =>
        _StockSheet(product: product, productService: productService),
  );
}

class _StockSheet extends StatefulWidget {
  final ProductModel product;
  final ProductService productService;

  const _StockSheet({required this.product, required this.productService});

  @override
  State<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends State<_StockSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.product.stockQty.toString());
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _value => int.tryParse(_controller.text.trim()) ?? 0;

  void _setValue(int value) {
    var next = value;
    if (next < 0) next = 0;
    if (next > _maxStock) next = _maxStock;
    HapticFeedback.selectionClick();
    setState(() {
      _controller.text = '$next';
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final raw = _controller.text.trim();
    final value = int.tryParse(raw);
    if (raw.isEmpty || value == null) {
      setState(
          () => _error = 'Enter how many ${widget.product.unit} you have.');
      return;
    }
    if (value < 0 || value > _maxStock) {
      setState(() => _error = 'Stock must be between 0 and $_maxStock.');
      return;
    }
    if (value == widget.product.stockQty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.productService.setStock(widget.product.productId, value);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(appSnackBar(
          '${widget.product.itemName} stock set to $value ${widget.product.unit}',
          tone: SnackTone.success));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update stock. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final wasOut = product.stockQty == 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: PanelColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update stock',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: PanelColors.textMain),
              ),
              const SizedBox(height: 4),
              Text(
                '${product.itemName} · now ${product.stockQty} ${product.unit}',
                style:
                    const TextStyle(fontSize: 14, color: PanelColors.textMuted),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _RoundButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Decrease stock',
                    onTap: _saving || _value <= 0
                        ? null
                        : () => _setValue(_value - 1),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('stock_update_field'),
                      controller: _controller,
                      enabled: !_saving,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _save(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: PanelColors.textMain,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      decoration: panelInputDecoration(
                        'Available (${product.unit})',
                        error: _error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RoundButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Increase stock',
                    filled: true,
                    onTap: _saving || _value >= _maxStock
                        ? null
                        : () => _setValue(_value + 1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final step in const [5, 10, 25])
                    ActionChip(
                      label: Text('+$step'),
                      onPressed:
                          _saving ? null : () => _setValue(_value + step),
                      backgroundColor: PanelColors.tint,
                      side: BorderSide.none,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: PanelColors.brand),
                    ),
                  ActionChip(
                    label: const Text('Out of stock'),
                    onPressed: _saving ? null : () => _setValue(0),
                    backgroundColor: PanelColors.dangerBg,
                    side: BorderSide.none,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, color: PanelColors.danger),
                  ),
                ],
              ),
              if (wasOut) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        size: 16, color: PanelColors.brand),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Customers who saved or follow this item get a restock alert.',
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: PanelColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const ValueKey('stock_update_save_button'),
                  onPressed: _saving ? null : _save,
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
                      : const Text('Save stock',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;

  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    var background = PanelColors.tint;
    var foreground = PanelColors.brand;
    if (filled) {
      background = PanelColors.brand;
      foreground = Colors.white;
    }
    if (!enabled) {
      background = PanelColors.greyBg;
      foreground = const Color(0xFFA3AC9A);
    }
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: foreground, semanticLabel: tooltip),
          ),
        ),
      ),
    );
  }
}
