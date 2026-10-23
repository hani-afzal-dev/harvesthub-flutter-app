import 'package:flutter/material.dart';
import '../core/phone_numbers.dart';
import '../core/validators.dart';
import 'animated_auth_field.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);

class PhoneNumberField extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController controller;
  final DialCountry country;
  final ValueChanged<DialCountry> onCountryChanged;
  final String label;

  const PhoneNumberField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.label = 'Mobile number',
  });

  Future<void> _pickCountry(BuildContext context) async {
    final picked = await showModalBottomSheet<DialCountry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CountrySheet(selected: country),
    );
    if (picked != null) onCountryChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label:
              'Country code ${country.name}, plus ${country.code}. Tap to change',
          excludeSemantics: true,
          child: Material(
            color: const Color(0xFFF1F4EC),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _pickCountry(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56, minWidth: 84),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: const Color(0xFFE3E9DA), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(country.iso,
                            style: const TextStyle(
                                fontSize: 11, color: _textMuted)),
                        Text(
                          '+${country.code}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textMain),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_drop_down_rounded,
                        color: _textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedAuthField(
            key: fieldKey,
            controller: controller,
            label: label,
            icon: Icons.phone_outlined,
            accentColor: _brand,
            keyboardType: TextInputType.phone,
            validator: (value) => Validators.isValidLocalPhone(country, value),
            errorText: 'Enter a valid ${country.name} number',
            errorMessage: (value) => Validators.localPhoneError(country, value),
          ),
        ),
      ],
    );
  }
}

class _CountrySheet extends StatelessWidget {
  final DialCountry selected;

  const _CountrySheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFD5DBCD),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Choose country code',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textMain),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: dialCountries.length,
                itemBuilder: (context, index) {
                  final country = dialCountries[index];
                  final isSelected = country.iso == selected.iso;
                  return ListTile(
                    minTileHeight: 52,
                    title: Text(
                      country.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: _textMain,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('+${country.code}',
                            style: const TextStyle(
                                fontSize: 14, color: _textMuted)),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_rounded,
                              color: _brand, semanticLabel: 'Selected'),
                        ],
                      ],
                    ),
                    onTap: () => Navigator.of(context).pop(country),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
