/// Code pays ISO 3166-1 alpha-3 (ex. ALG, FRA, ARG).
String resolveAlpha3Code(String? rawName, {String fallback = 'UNK'}) {
  final alpha2 = resolveCountryCode(rawName, fallback: '');
  if (alpha2.isEmpty || alpha2 == 'UN') {
    return fallback;
  }
  final base = alpha2.contains('-') ? alpha2.split('-').first : alpha2;
  return _alpha2ToAlpha3[base] ?? fallback;
}

String resolveCountryCode(String? rawName, {String fallback = 'UN'}) {
  if (rawName == null) return fallback;
  // If it's already a raw code like GB-ENG, pass it through directly
  final upper = rawName.trim().toUpperCase();
  if (upper.length <= 6 &&
      RegExp(r'^[A-Z]{2}(-[A-Z]{2,3})?$').hasMatch(upper)) {
    return upper;
  }
  final normalized = _normalizeCountryName(rawName);
  final mapped = _countryCodeByName[normalized];
  if (mapped != null) return mapped;

  if (RegExp(r'^[A-Z]{3}$').hasMatch(upper)) {
    final override = _alpha3ToFlagCodeOverrides[upper];
    if (override != null) return override;
    for (final entry in _alpha2ToAlpha3.entries) {
      if (entry.value == upper) return entry.key;
    }
    return fallback;
  }

  return fallback;
}

String _normalizeCountryName(String? value) {
  return (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('ç', 'c') // curaçao → curacao
      .replaceAll('ô', 'o') // côte → cote
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('&', 'and')
      .replaceAll(
        RegExp(r"['\']"),
        ' ',
      ) // apostrophes → space: cote d'ivoire → cote d ivoire
      .replaceAll(RegExp(r'[^a-z0-9 -]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const Map<String, String> _countryCodeByName = {
  // A
  'afghanistan': 'AF', 'albania': 'AL', 'algeria': 'DZ', 'andorra': 'AD',
  'angola': 'AO', 'antigua and barbuda': 'AG', 'argentina': 'AR',
  'armenia': 'AM', 'australia': 'AU', 'austria': 'AT', 'azerbaijan': 'AZ',
  // SofaScore aliases
  'ir iran': 'IR',
  'korea dpr': 'KP',
  'timor-leste': 'TL',
  'st kitts and nevis': 'KN', 'st lucia': 'LC',
  'saint kitts and nevis': 'KN',
  'brunei darussalam': 'BN', 'lao pdr': 'LA',
  'kyrgyz republic': 'KG',
  // B
  'bahamas': 'BS', 'bahrain': 'BH', 'bangladesh': 'BD', 'barbados': 'BB',
  'belarus': 'BY', 'belgium': 'BE', 'belize': 'BZ', 'benin': 'BJ',
  'bermuda': 'BM', 'bhutan': 'BT', 'bolivia': 'BO',
  'bosnia and herzegovina': 'BA',
  'bosnia herz': 'BA',
  'bosnia': 'BA',
  'bih': 'BA',
  'botswana': 'BW', 'brazil': 'BR', 'brunei': 'BN', 'bulgaria': 'BG',
  'burkina faso': 'BF', 'burundi': 'BI',
  // C
  'cabo verde': 'CV', 'cape verde': 'CV', 'cape verde islands': 'CV',
  'cambodia': 'KH', 'cameroon': 'CM', 'canada': 'CA',
  'central african republic': 'CF', 'chad': 'TD', 'chile': 'CL',
  'china': 'CN', 'china pr': 'CN', 'colombia': 'CO', 'comoros': 'KM',
  'comores': 'KM', 'comorian': 'KM',
  'congo': 'CG', 'congo dr': 'CD', 'dr congo': 'CD',
  'democratic republic of congo': 'CD', 'congo democratic republic': 'CD',
  'costa rica': 'CR', 'croatia': 'HR', 'cuba': 'CU', 'curacao': 'CW',
  'cyprus': 'CY', 'czech republic': 'CZ', 'czechia': 'CZ',
  'cote divoire': 'CI', 'cote d ivoire': 'CI', 'ivory coast': 'CI',
  // D
  'denmark': 'DK', 'djibouti': 'DJ', 'dominica': 'DM',
  'dominican republic': 'DO',
  // E
  'ecuador': 'EC', 'egypt': 'EG', 'el salvador': 'SV',
  'england': 'GB-ENG', 'eng': 'GB-ENG',
  'equatorial guinea': 'GQ', 'eritrea': 'ER', 'estonia': 'EE', 'ethiopia': 'ET',
  // F
  'faroe islands': 'FO', 'fiji': 'FJ', 'finland': 'FI', 'france': 'FR',
  // G
  'gabon': 'GA', 'gambia': 'GM', 'georgia': 'GE', 'germany': 'DE',
  'ghana': 'GH', 'greece': 'GR', 'grenada': 'GD', 'guatemala': 'GT',
  'guinea': 'GN', 'guineabissau': 'GW', 'guinea bissau': 'GW', 'guyana': 'GY',
  // H
  'haiti': 'HT', 'honduras': 'HN', 'hong kong': 'HK', 'hungary': 'HU',
  // I
  'iceland': 'IS', 'india': 'IN', 'indonesia': 'ID', 'iran': 'IR',
  'iraq': 'IQ', 'ireland': 'IE', 'israel': 'IL', 'italy': 'IT',
  // J
  'jamaica': 'JM', 'japan': 'JP', 'jordan': 'JO',
  // K
  'kazakhstan': 'KZ', 'kenya': 'KE', 'korea republic': 'KR',
  'south korea': 'KR', 'north korea': 'KP', 'kosovo': 'XK',
  'kuwait': 'KW', 'kyrgyzstan': 'KG',
  // L
  'laos': 'LA', 'latvia': 'LV', 'lebanon': 'LB', 'lesotho': 'LS',
  'liberia': 'LR', 'libya': 'LY', 'liechtenstein': 'LI',
  'lithuania': 'LT', 'luxembourg': 'LU',
  // M
  'macao': 'MO', 'madagascar': 'MG', 'malawi': 'MW', 'malaysia': 'MY',
  'maldives': 'MV', 'mali': 'ML', 'malta': 'MT', 'mauritania': 'MR',
  'mauritius': 'MU', 'mexico': 'MX', 'moldova': 'MD', 'mongolia': 'MN',
  'montenegro': 'ME', 'morocco': 'MA', 'maroc': 'MA', 'moroccan': 'MA',
  'marocaine': 'MA', 'marocain': 'MA', 'mozambique': 'MZ', 'myanmar': 'MM',
  'north macedonia': 'MK', 'macedonia': 'MK',
  // N
  'namibia': 'NA', 'nepal': 'NP', 'netherlands': 'NL', 'new zealand': 'NZ',
  'nicaragua': 'NI', 'niger': 'NE', 'nigeria': 'NG', 'norway': 'NO',
  'northern ireland': 'GB-NIR',
  // O
  'oman': 'OM',
  // P
  'pakistan': 'PK', 'palestine': 'PS', 'panama': 'PA', 'papua new guinea': 'PG',
  'paraguay': 'PY', 'peru': 'PE', 'philippines': 'PH', 'poland': 'PL',
  'portugal': 'PT', 'puerto rico': 'PR',
  // Q
  'qatar': 'QA',
  // R
  'romania': 'RO', 'russia': 'RU', 'rwanda': 'RW',
  // S
  'samoa': 'WS', 'san marino': 'SM', 'saudi arabia': 'SA',
  'scotland': 'GB-SCT', 'senegal': 'SN', 'serbia': 'RS', 'seychelles': 'SC',
  'sierra leone': 'SL', 'singapore': 'SG', 'slovakia': 'SK', 'slovenia': 'SI',
  'solomon islands': 'SB', 'somalia': 'SO', 'south africa': 'ZA',
  'south sudan': 'SS', 'spain': 'ES', 'sri lanka': 'LK', 'sudan': 'SD',
  'suriname': 'SR', 'eswatini': 'SZ', 'swaziland': 'SZ',
  'sweden': 'SE', 'switzerland': 'CH', 'syria': 'SY',
  // T
  'taiwan': 'TW', 'chinese taipei': 'TW', 'tajikistan': 'TJ',
  'tanzania': 'TZ', 'thailand': 'TH', 'timor leste': 'TL', 'togo': 'TG',
  'tonga': 'TO', 'trinidad and tobago': 'TT', 'tunisia': 'TN',
  'turkey': 'TR', 'turkiye': 'TR', 'turkmenistan': 'TM',
  // U
  'uae': 'AE', 'united arab emirates': 'AE', 'uganda': 'UG',
  'ukraine': 'UA', 'united states': 'US', 'usa': 'US', 'uruguay': 'UY',
  'uzbekistan': 'UZ',
  // V
  'vanuatu': 'VU', 'venezuela': 'VE', 'vietnam': 'VN',
  'saint vincent and the grenadines': 'VC',
  // W
  'wales': 'GB-WLS',
  // Y
  'yemen': 'YE',
  // Z
  'zambia': 'ZM', 'zimbabwe': 'ZW',
};

const Map<String, String> _alpha2ToAlpha3 = {
  'AF': 'AFG',
  'AL': 'ALB',
  'DZ': 'ALG',
  'AD': 'AND',
  'AO': 'ANG',
  'AR': 'ARG',
  'AM': 'ARM',
  'AU': 'AUS',
  'AT': 'AUT',
  'AZ': 'AZE',
  'BS': 'BAH',
  'BH': 'BHR',
  'BD': 'BAN',
  'BB': 'BRB',
  'BY': 'BLR',
  'BE': 'BEL',
  'BZ': 'BLZ',
  'BJ': 'BEN',
  'BO': 'BOL',
  'BA': 'BIH',
  'BW': 'BOT',
  'BR': 'BRA',
  'BG': 'BUL',
  'BF': 'BFA',
  'BI': 'BDI',
  'CV': 'CPV',
  'KH': 'CAM',
  'CM': 'CMR',
  'CA': 'CAN',
  'CL': 'CHI',
  'CN': 'CHN',
  'CO': 'COL',
  'CG': 'CGO',
  'CD': 'COD',
  'CR': 'CRC',
  'CI': 'CIV',
  'HR': 'CRO',
  'CU': 'CUB',
  'CY': 'CYP',
  'CZ': 'CZE',
  'DK': 'DEN',
  'EC': 'ECU',
  'EG': 'EGY',
  'SV': 'SLV',
  'GQ': 'EQG',
  'EE': 'EST',
  'ET': 'ETH',
  'FI': 'FIN',
  'FR': 'FRA',
  'GA': 'GAB',
  'GM': 'GAM',
  'DE': 'GER',
  'GH': 'GHA',
  'GR': 'GRE',
  'GT': 'GUA',
  'GN': 'GUI',
  'HT': 'HAI',
  'HN': 'HON',
  'HU': 'HUN',
  'IS': 'ISL',
  'IN': 'IND',
  'ID': 'IDN',
  'IR': 'IRN',
  'IQ': 'IRQ',
  'IE': 'IRL',
  'IL': 'ISR',
  'IT': 'ITA',
  'JM': 'JAM',
  'JP': 'JPN',
  'JO': 'JOR',
  'KZ': 'KAZ',
  'KE': 'KEN',
  'KP': 'PRK',
  'KR': 'KOR',
  'KW': 'KUW',
  'LV': 'LVA',
  'LB': 'LBN',
  'LY': 'LBY',
  'LT': 'LTU',
  'LU': 'LUX',
  'MG': 'MAD',
  'MW': 'MAW',
  'MY': 'MAS',
  'ML': 'MLI',
  'MT': 'MLT',
  'MR': 'MTN',
  'MX': 'MEX',
  'MD': 'MDA',
  'ME': 'MNE',
  'MA': 'MAR',
  'MZ': 'MOZ',
  'NL': 'NED',
  'NZ': 'NZL',
  'NI': 'NCA',
  'NG': 'NGA',
  'MK': 'MKD',
  'NO': 'NOR',
  'OM': 'OMA',
  'PA': 'PAN',
  'PY': 'PAR',
  'PE': 'PER',
  'PH': 'PHI',
  'PL': 'POL',
  'PT': 'POR',
  'QA': 'QAT',
  'RO': 'ROU',
  'RU': 'RUS',
  'SA': 'KSA',
  'SN': 'SEN',
  'RS': 'SRB',
  'SL': 'SLE',
  'SG': 'SIN',
  'SK': 'SVK',
  'SI': 'SVN',
  'ZA': 'RSA',
  'ES': 'ESP',
  'SE': 'SWE',
  'CH': 'SUI',
  'SY': 'SYR',
  'TZ': 'TAN',
  'TH': 'THA',
  'TG': 'TOG',
  'TT': 'TRI',
  'TN': 'TUN',
  'TR': 'TUR',
  'UG': 'UGA',
  'UA': 'UKR',
  'AE': 'UAE',
  'US': 'USA',
  'UY': 'URU',
  'UZ': 'UZB',
  'VE': 'VEN',
  'VN': 'VIE',
  'YE': 'YEM',
  'ZM': 'ZAM',
  'ZW': 'ZIM',
  'GB': 'ENG',
  'NC': 'NCL',
  'TW': 'TPE',
  'PS': 'PLE',
};

const Map<String, String> _alpha3ToFlagCodeOverrides = {
  'COM': 'KM',
  'ENG': 'GB-ENG',
  'NIR': 'GB-NIR',
  'SCO': 'GB-SCT',
  'WAL': 'GB-WLS',
};
