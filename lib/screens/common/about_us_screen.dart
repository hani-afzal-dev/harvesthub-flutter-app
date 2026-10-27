import 'package:flutter/material.dart';
import '../../widgets/page_header.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F3),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const PageHeader(title: 'About Us'),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF5A9A1F),
                              _brand,
                              Color(0xFF2A4A0C)
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.eco,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'HarvestHub',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Fresh produce straight from local farms.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: Colors.white
                                            .withValues(alpha: 0.9)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _SectionLabel('WHO WE ARE'),
                      const _Card(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'HarvestHub connects local farmers directly with customers looking for fresh, '
                          'locally sourced produce. Instead of going through multiple middlemen, farmers can '
                          'list their fruits, vegetables, grains, dairy, and other goods straight from the farm, '
                          'and customers can browse, compare, and order from growers near them.',
                          style: TextStyle(
                              fontSize: 14, height: 1.5, color: _textMain),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _SectionLabel('WHY WE BUILT THIS'),
                      const _Card(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Small-scale farmers often struggle to reach customers beyond their immediate market, '
                          'while customers who want fresher, more affordable produce have no easy way to find them. '
                          'HarvestHub gives both sides a simple digital marketplace built around browsing, '
                          'wishlists, pickup scheduling, and direct communication.',
                          style: TextStyle(
                              fontSize: 14, height: 1.5, color: _textMain),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _SectionLabel('WHAT YOU CAN DO HERE'),
                      const _Card(
                        child: Column(
                          children: [
                            _AboutPoint(
                                icon: Icons.storefront_outlined,
                                text:
                                    'Browse and search products from local farmers by category, market, or distance'),
                            Divider(height: 1, indent: 64),
                            _AboutPoint(
                                icon: Icons.favorite_border,
                                text:
                                    'Save products to a wishlist and follow your favourite farmers for restock alerts'),
                            Divider(height: 1, indent: 64),
                            _AboutPoint(
                                icon: Icons.event_available_outlined,
                                text:
                                    'Pick a convenient pickup slot instead of waiting for delivery'),
                            Divider(height: 1, indent: 64),
                            _AboutPoint(
                                icon: Icons.smart_toy_outlined,
                                text:
                                    'Ask the built-in Farm Products Assistant about nutrition, storage, and seasonality'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'This app was built as a submission for TechWiz 7, Aptech\'s multi-platform application '
                          'computing competition.',
                          style: TextStyle(
                              fontSize: 13, height: 1.4, color: _textMuted),
                        ),
                      ),
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
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: _textMuted),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({required this.child, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: child,
    );
  }
}

class _AboutPoint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AboutPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: _tint, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: _brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14, height: 1.4, color: _textMain)),
            ),
          ],
        ),
      ),
    );
  }
}
