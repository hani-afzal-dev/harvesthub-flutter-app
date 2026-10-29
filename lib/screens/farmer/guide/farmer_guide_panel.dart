import 'package:flutter/material.dart';
import '../../../widgets/panel_ui.dart';

class FarmerGuideTopic {
  final IconData icon;
  final String titleEn;
  final String bodyEn;
  final String titleUr;
  final String bodyUr;

  const FarmerGuideTopic({
    required this.icon,
    required this.titleEn,
    required this.bodyEn,
    required this.titleUr,
    required this.bodyUr,
  });
}

const List<FarmerGuideTopic> farmerGuideTopics = [
  FarmerGuideTopic(
    icon: Icons.eco_outlined,
    titleEn: 'Products',
    bodyEn:
        "Add the fruits, vegetables or other items you sell, with a price and how many you have. Turn an item off when it's out of stock so customers can't order it.",
    titleUr: 'پروڈکٹس',
    bodyUr:
        'وہ پھل، سبزیاں یا دیگر چیزیں شامل کریں جو آپ بیچتے ہیں، ساتھ میں قیمت اور کتنی مقدار موجود ہے۔ جب کوئی چیز ختم ہو جائے تو اسے بند کر دیں تاکہ گاہک اسے آرڈر نہ کر سکیں۔',
  ),
  FarmerGuideTopic(
    icon: Icons.receipt_long_outlined,
    titleEn: 'Orders',
    bodyEn:
        "See every order customers have placed for your products. Update the status (Confirmed, Ready for Pickup, Completed) so the customer knows what's happening.",
    titleUr: 'آرڈرز',
    bodyUr:
        'وہ تمام آرڈر دیکھیں جو گاہکوں نے آپ کے پروڈکٹس کے لیے دیے ہیں۔ آرڈر کی صورتحال (تصدیق شدہ، لینے کے لیے تیار، مکمل) اپ ڈیٹ کریں تاکہ گاہک کو پتا چل سکے۔',
  ),
  FarmerGuideTopic(
    icon: Icons.event_outlined,
    titleEn: 'Pickup slots',
    bodyEn:
        'A slot is a time window when a customer can come collect their order. Add a day, a time, and how many orders you can hand out — customers pick one of your open slots at checkout.',
    titleUr: 'پک اپ سلاٹس',
    bodyUr:
        'سلاٹ ایک ایسا وقت ہوتا ہے جب گاہک اپنا آرڈر لینے آ سکتا ہے۔ ایک دن، وقت اور بتائیں کہ آپ کتنے آرڈر اس وقت میں دے سکتے ہیں — گاہک چیک آؤٹ کے وقت آپ کے کھلے سلاٹس میں سے ایک منتخب کرتا ہے۔',
  ),
  FarmerGuideTopic(
    icon: Icons.insert_chart_outlined,
    titleEn: 'Reports',
    bodyEn:
        'Pick a period (daily, weekly or monthly) and tap Generate to see your total orders, earnings and best-selling products for that time.',
    titleUr: 'رپورٹس',
    bodyUr:
        "ایک مدت منتخب کریں (روزانہ، ہفتہ وار یا ماہانہ) اور 'Generate' دبائیں تاکہ اس وقت کے کل آرڈرز، آمدنی اور سب سے زیادہ بکنے والی چیزیں دیکھ سکیں۔",
  ),
  FarmerGuideTopic(
    icon: Icons.person_outline_rounded,
    titleEn: 'Profile',
    bodyEn:
        'Manage your farm details, contact info and password here. You can also log out from this screen.',
    titleUr: 'پروفائل',
    bodyUr:
        'یہاں سے اپنی فارم کی تفصیلات، رابطہ نمبر اور پاس ورڈ تبدیل کریں۔ اسی سکرین سے لاگ آؤٹ بھی کر سکتے ہیں۔',
  ),
];

class FarmerGuidePanel extends StatefulWidget {
  final int initialTopicIndex;
  const FarmerGuidePanel({super.key, this.initialTopicIndex = 0});

  @override
  State<FarmerGuidePanel> createState() => _FarmerGuidePanelState();
}

class _FarmerGuidePanelState extends State<FarmerGuidePanel> {
  late int _topicIndex =
      widget.initialTopicIndex.clamp(0, farmerGuideTopics.length - 1);
  bool _urdu = false;

  @override
  Widget build(BuildContext context) {
    final topic = farmerGuideTopics[_topicIndex];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          color: PanelColors.brand,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Guide',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
              ),
              _LanguageSwitch(
                isUrdu: _urdu,
                onChanged: (value) => setState(() => _urdu = value),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: farmerGuideTopics.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final item = farmerGuideTopics[index];
              final selected = index == _topicIndex;
              return ChoiceChip(
                label: Text(_urdu ? item.titleUr : item.titleEn),
                selected: selected,
                onSelected: (_) => setState(() => _topicIndex = index),
                selectedColor: PanelColors.tint,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? PanelColors.brand : PanelColors.textBody,
                ),
                side: BorderSide(
                    color: selected ? PanelColors.brand : PanelColors.border),
              );
            },
          ),
        ),
        const Divider(height: 1, color: PanelColors.border),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Directionality(
              textDirection: _urdu ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(topic.icon, size: 20, color: PanelColors.brand),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _urdu ? topic.titleUr : topic.titleEn,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: PanelColors.textMain),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _urdu ? topic.bodyUr : topic.bodyEn,
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: PanelColors.textBody),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageSwitch extends StatelessWidget {
  final bool isUrdu;
  final ValueChanged<bool> onChanged;

  const _LanguageSwitch({required this.isUrdu, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill('EN', !isUrdu, () => onChanged(false)),
          _pill('اردو', isUrdu, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? PanelColors.brand : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
