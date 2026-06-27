// Auto-generated mapping: 365Scores nationalityId → ISO 3166-1 alpha-2 country code
// Used to resolve coach/player nationality flags from the squads API
const Map<int, String> nationality365IdToCode = {
  185: 'AF', // Afghanistan
  76: 'AL',  // Albania
  139: 'DZ', // Algeria
  103: 'AD', // Andorra
  136: 'AO', // Angola
  187: 'AG', // Antigua & Barbuda
  10: 'AR',  // Argentina
  49: 'AM',  // Armenia
  252: 'CW', // Aruba (use Netherlands Antilles / Curaçao code as fallback)
  36: 'AU',  // Australia
  20: 'AT',  // Austria
  77: 'AZ',  // Azerbaijan
  186: 'BS', // Bahamas
  116: 'BH', // Bahrain
  219: 'BD', // Bangladesh
  196: 'BB', // Barbados
  104: 'BY', // Belarus
  16: 'BE',  // Belgium
  195: 'BZ', // Belize
  113: 'BO', // Bolivia
  57: 'BA',  // Bosnia & Herzegovina
  63: 'BW',  // Botswana
  21: 'BR',  // Brazil
  40: 'BG',  // Bulgaria
  192: 'BI', // Burundi
  73: 'CM',  // Cameroon
  66: 'CA',  // Canada
  28: 'CL',  // Chile
  35: 'CN',  // China
  109: 'CO', // Colombia
  153: 'CR', // Costa Rica
  38: 'HR',  // Croatia
  39: 'CY',  // Cyprus
  22: 'CZ',  // Czechia
  23: 'DK',  // Denmark
  183: 'DO', // Dominican Republic
  51: 'EC',  // Ecuador
  131: 'EG', // Egypt
  147: 'SV', // El Salvador
  1: 'GB-ENG', // England
  102: 'EE', // Estonia
  70: 'ET',  // Ethiopia
  106: 'FO', // Faroe Islands
  61: 'FJ',  // Fiji
  25: 'FI',  // Finland
  5: 'FR',   // France
  143: 'GA', // Gabon
  78: 'GE',  // Georgia
  4: 'DE',   // Germany
  65: 'GH',  // Ghana
  13: 'GR',  // Greece
  152: 'HT', // Haiti
  169: 'HN', // Honduras
  79: 'HK',  // Hong Kong
  30: 'HU',  // Hungary
  32: 'IS',  // Iceland
  80: 'IN',  // India
  75: 'ID',  // Indonesia
  81: 'IR',  // Iran
  114: 'IQ', // Iraq
  9: 'IE',   // Ireland
  6: 'IL',   // Israel
  3: 'IT',   // Italy
  74: 'CI',  // Ivory Coast
  151: 'JM', // Jamaica
  34: 'JP',  // Japan
  119: 'JO', // Jordan
  105: 'KZ', // Kazakhstan
  144: 'KE', // Kenya
  205: 'XK', // Kosovo
  126: 'KW', // Kuwait
  41: 'LV',  // Latvia
  123: 'LB', // Lebanon
  138: 'LR', // Liberia
  42: 'LT',  // Lithuania
  92: 'LU',  // Luxembourg
  82: 'MY',  // Malaysia
  128: 'ML', // Mali
  93: 'MT',  // Malta
  31: 'MX',  // Mexico
  91: 'MD',  // Moldova
  84: 'ME',  // Montenegro
  127: 'MA', // Morocco
  64: 'NA',  // Namibia
  7: 'NL',   // Netherlands
  159: 'NZ', // New Zealand
  83: 'NG',  // Nigeria
  180: 'KP', // North Korea
  56: 'MK',  // North Macedonia
  99: 'GB-NIR', // Northern Ireland
  27: 'NO',  // Norway
  117: 'OM', // Oman
  146: 'PA', // Panama
  108: 'PY', // Paraguay
  112: 'PE', // Peru
  37: 'PL',  // Poland
  11: 'PT',  // Portugal
  115: 'QA', // Qatar
  29: 'RO',  // Romania
  14: 'RU',  // Russia
  122: 'SA', // Saudi Arabia
  8: 'GB-SCT', // Scotland
  133: 'SN', // Senegal
  85: 'RS',  // Serbia
  33: 'SK',  // Slovakia
  46: 'SI',  // Slovenia
  134: 'ZA', // South Africa
  86: 'KR',  // South Korea
  2: 'ES',   // Spain
  130: 'SD', // Sudan
  24: 'SE',  // Sweden
  15: 'CH',  // Switzerland
  184: 'TJ', // Tajikistan
  118: 'TH', // Thailand
  71: 'TG',  // Togo
  135: 'TN', // Tunisia
  12: 'TR',  // Turkiye
  120: 'TM', // Turkmenistan
  26: 'UA',  // Ukraine
  111: 'UY', // Uruguay
  18: 'US',  // USA
  121: 'UZ', // Uzbekistan
  110: 'VE', // Venezuela
  100: 'GB-WLS', // Wales
  60: 'ZW',  // Zimbabwe
  232: 'CW', // Curaçao
  175: 'CU', // Cuba
  55: 'MM',  // Myanmar
  201: 'NE', // Niger
  215: 'KN', // Saint Kitts and Nevis
  212: 'SR', // Suriname
  148: 'TT', // Trinidad and Tobago
  124: 'AE', // UAE
  137: 'UG', // Uganda
  155: 'VN', // Vietnam
};

/// Resolve a 365Scores nationalityId to a 2-letter ISO country code
String resolveNationalityId(int? natId) {
  if (natId == null) return '';
  return nationality365IdToCode[natId] ?? '';
}
