class DialCountry {
  final String name;
  final String iso;
  final String code;

  const DialCountry(this.name, this.iso, this.code);
}

const DialCountry defaultDialCountry = DialCountry('Pakistan', 'PK', '92');

const List<DialCountry> dialCountries = [
  defaultDialCountry,
  DialCountry('Australia', 'AU', '61'),
  DialCountry('Bahrain', 'BH', '973'),
  DialCountry('Bangladesh', 'BD', '880'),
  DialCountry('Canada', 'CA', '1'),
  DialCountry('China', 'CN', '86'),
  DialCountry('Egypt', 'EG', '20'),
  DialCountry('France', 'FR', '33'),
  DialCountry('Germany', 'DE', '49'),
  DialCountry('India', 'IN', '91'),
  DialCountry('Japan', 'JP', '81'),
  DialCountry('Kuwait', 'KW', '965'),
  DialCountry('Malaysia', 'MY', '60'),
  DialCountry('Nigeria', 'NG', '234'),
  DialCountry('Oman', 'OM', '968'),
  DialCountry('Qatar', 'QA', '974'),
  DialCountry('Saudi Arabia', 'SA', '966'),
  DialCountry('Singapore', 'SG', '65'),
  DialCountry('South Africa', 'ZA', '27'),
  DialCountry('Sri Lanka', 'LK', '94'),
  DialCountry('Turkey', 'TR', '90'),
  DialCountry('United Arab Emirates', 'AE', '971'),
  DialCountry('United Kingdom', 'GB', '44'),
  DialCountry('United States', 'US', '1'),
];

final RegExp _nonDigits = RegExp(r'[^0-9]');
final RegExp _leadingZeros = RegExp(r'^0+');

String localDigits(String local) {
  return local.replaceAll(_nonDigits, '').replaceFirst(_leadingZeros, '');
}

String toE164(DialCountry country, String local) {
  return '+${country.code}${localDigits(local)}';
}

(DialCountry, String) splitStoredPhone(String stored) {
  final value = stored.trim();
  if (!value.startsWith('+')) return (defaultDialCountry, value);

  final digits = value.substring(1);
  DialCountry? best;
  for (final country in dialCountries) {
    if (!digits.startsWith(country.code)) continue;
    if (best == null || country.code.length > best.code.length) best = country;
  }
  if (best == null) return (defaultDialCountry, value);
  return (best, digits.substring(best.code.length));
}
