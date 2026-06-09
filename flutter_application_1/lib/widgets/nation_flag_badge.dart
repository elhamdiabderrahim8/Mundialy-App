import 'package:flutter/material.dart';

class NationFlagBadge extends StatelessWidget {
  const NationFlagBadge({
    super.key,
    required this.countryCode,
    required this.size,
    this.imageUrlOverride,
  });

  final String countryCode;
  final double size;
  final String? imageUrlOverride;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl();
    final outerSize = size;
    final innerSize = size * 0.66;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: outerSize * 0.7,
              height: outerSize * 0.7,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFFD5DCE2),
                  width: outerSize * 0.035,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: outerSize * 0.12,
                    offset: Offset(0, outerSize * 0.05),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: innerSize,
            height: innerSize,
            child: ClipPath(
              clipper: _DiamondClipper(),
              child: ColoredBox(
                color: Colors.white,
                child: imageUrl == null
                    ? _FlagFallback(countryCode: countryCode, size: size)
                    : FittedBox(
                        fit: BoxFit.cover,
                        alignment: _flagAlignment(),
                        child: SizedBox(
                          width: innerSize * _flagAspectRatio(),
                          height: innerSize,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.fill,
                            errorBuilder: (_, __, ___) => _FlagFallback(
                              countryCode: countryCode,
                              size: size,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _resolveImageUrl() {
    final override = imageUrlOverride;
    if (override != null && override.isNotEmpty && override.startsWith('http')) {
      return override;
    }

    return resolveFlagUrl(countryCode);
  }

  /// Drapeaux uniquement via flagcdn.com â€” jamais de logos SofaScore / fÃ©dÃ©rations.
  static String? resolveFlagUrl(String countryCode) {
    final normalizedCode = _normalizeCountryCode(countryCode);
    if (normalizedCode != null) {
      return 'https://flagcdn.com/w160/${normalizedCode.toLowerCase()}.png';
    }

    final byName = _resolveByTeamName(countryCode);
    if (byName != null) {
      return 'https://flagcdn.com/w160/${byName.toLowerCase()}.png';
    }

    return null;
  }

  /// Tries to find an ISO-2 code from a team/country full name
  static String? _resolveByTeamName(String name) {
    const nameMap = {
      'afghanistan': 'af',
      'albania': 'al',
      'algeria': 'dz',
      'angola': 'ao',
      'argentina': 'ar',
      'armenia': 'am',
      'australia': 'au',
      'austria': 'at',
      'azerbaijan': 'az',
      'bahrain': 'bh',
      'bangladesh': 'bd',
      'belgium': 'be',
      'benin': 'bj',
      'bolivia': 'bo',
      'bosnia': 'ba',
      'botswana': 'bw',
      'brazil': 'br',
      'bulgaria': 'bg',
      'burkina': 'bf',
      'burundi': 'bi',
      'cameroon': 'cm',
      'canada': 'ca',
      'chile': 'cl',
      'china': 'cn',
      'colombia': 'co',
      'comoros': 'km',
      'congo': 'cg',
      'costa rica': 'cr',
      'croatia': 'hr',
      'cuba': 'cu',
      'czech': 'cz',
      'denmark': 'dk',
      'dr congo': 'cd',
      'ecuador': 'ec',
      'egypt': 'eg',
      'england': 'gb-eng',
      'ethiopia': 'et',
      'finland': 'fi',
      'france': 'fr',
      'gabon': 'ga',
      'gambia': 'gm',
      'georgia': 'ge',
      'germany': 'de',
      'ghana': 'gh',
      'greece': 'gr',
      'guatemala': 'gt',
      'guinea': 'gn',
      'haiti': 'ht',
      'honduras': 'hn',
      'hungary': 'hu',
      'iceland': 'is',
      'india': 'in',
      'indonesia': 'id',
      'iran': 'ir',
      'iraq': 'iq',
      'ireland': 'ie',
      'israel': 'il',
      'italy': 'it',
      'jamaica': 'jm',
      'japan': 'jp',
      'jordan': 'jo',
      'kazakhstan': 'kz',
      'kenya': 'ke',
      'north korea': 'kp',
      'south korea': 'kr',
      'kuwait': 'kw',
      'latvia': 'lv',
      'lebanon': 'lb',
      'liberia': 'lr',
      'libya': 'ly',
      'liechtenstein': 'li',
      'lithuania': 'lt',
      'luxembourg': 'lu',
      'madagascar': 'mg',
      'malawi': 'mw',
      'malaysia': 'my',
      'mali': 'ml',
      'malta': 'mt',
      'mauritania': 'mr',
      'mauritius': 'mu',
      'mexico': 'mx',
      'moldova': 'md',
      'mongolia': 'mn',
      'montenegro': 'me',
      'morocco': 'ma',
      'mozambique': 'mz',
      'myanmar': 'mm',
      'namibia': 'na',
      'nepal': 'np',
      'netherlands': 'nl',
      'holland': 'nl',
      'new zealand': 'nz',
      'nicaragua': 'ni',
      'niger': 'ne',
      'nigeria': 'ng',
      'north macedonia': 'mk',
      'norway': 'no',
      'oman': 'om',
      'pakistan': 'pk',
      'panama': 'pa',
      'paraguay': 'py',
      'peru': 'pe',
      'philippines': 'ph',
      'poland': 'pl',
      'portugal': 'pt',
      'qatar': 'qa',
      'romania': 'ro',
      'russia': 'ru',
      'rwanda': 'rw',
      'saudi arabia': 'sa',
      'scotland': 'gb-sct',
      'senegal': 'sn',
      'serbia': 'rs',
      'sierra leone': 'sl',
      'singapore': 'sg',
      'slovakia': 'sk',
      'slovenia': 'si',
      'somalia': 'so',
      'south africa': 'za',
      'spain': 'es',
      'sri lanka': 'lk',
      'sweden': 'se',
      'switzerland': 'ch',
      'syria': 'sy',
      'tanzania': 'tz',
      'thailand': 'th',
      'togo': 'tg',
      'trinidad': 'tt',
      'tunisia': 'tn',
      'turkey': 'tr',
      'turkiye': 'tr',
      'uganda': 'ug',
      'ukraine': 'ua',
      'united arab emirates': 'ae',
      'uae': 'ae',
      'united states': 'us',
      'usa': 'us',
      'uruguay': 'uy',
      'uzbekistan': 'uz',
      'venezuela': 've',
      'vietnam': 'vn',
      'wales': 'gb-wls',
      'yemen': 'ye',
      'zambia': 'zm',
      'zimbabwe': 'zw',
      'ivory coast': 'ci',
      'cÃ´te d\'ivoire': 'ci',
      'cape verde': 'cv',
      'el salvador': 'sv',
      'equatorial guinea': 'gq',
      'trinidad and tobago': 'tt',
      'new caledonia': 'nc',
    };
    final lower = name.trim().toLowerCase();
    // Exact match
    if (nameMap.containsKey(lower)) return nameMap[lower];
    // Partial match (if team name contains country name)
    for (final entry in nameMap.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }
    return null;
  }

  static String? _normalizeCountryCode(String rawCode) {
    final upper = rawCode.trim().toUpperCase();
    if (upper.length == 2) return upper;
    if (upper.length == 3) return _map3To2(upper);
    // Handle subdivision codes like GB-ENG, GB-WLS, GB-SCT, GB-NIR
    if (upper.contains('-') && upper.length <= 6) return upper;
    return null;
  }

  double _flagAspectRatio() {
    final normalized = _normalizeCountryCode(countryCode);
    return switch (normalized) {
      'CH' || 'VA' => 1,
      'QA' || 'NP' => 11 / 8,
      _ => 4 / 3,
    };
  }

  Alignment _flagAlignment() {
    final normalized = _normalizeCountryCode(countryCode);
    return switch (normalized) {
      'QA' => const Alignment(-0.38, 0),
      'US' => const Alignment(-0.62, -0.45),
      'MX' => const Alignment(0, -0.05),
      'TN' => const Alignment(0.08, 0),
      'MA' || 'JP' => Alignment.center,
      _ => Alignment.center,
    };
  }

  static String? _map3To2(String code3) {
    const map = {
      // A
      'AFG': 'AF', 'ALB': 'AL', 'ALG': 'DZ', 'AND': 'AD', 'ANG': 'AO',
      'ANT': 'AG', 'ARG': 'AR', 'ARM': 'AM', 'ARU': 'AW', 'ASA': 'AS',
      'AUS': 'AU', 'AUT': 'AT', 'AZE': 'AZ',
      // B
      'BAH': 'BS', 'BAN': 'BD', 'BDI': 'BI', 'BEL': 'BE', 'BEN': 'BJ',
      'BER': 'BM', 'BFA': 'BF', 'BHR': 'BH', 'BHU': 'BT', 'BIH': 'BA',
      'BLR': 'BY', 'BLZ': 'BZ', 'BOL': 'BO', 'BOT': 'BW', 'BRA': 'BR',
      'BRB': 'BB', 'BRU': 'BN', 'BUL': 'BG',
      // C
      'CAM': 'KH', 'CAN': 'CA', 'CAY': 'KY', 'CGO': 'CG', 'CHA': 'TD',
      'CHI': 'CL', 'CHN': 'CN', 'CIV': 'CI', 'CMR': 'CM', 'COD': 'CD',
      'COL': 'CO', 'COM': 'KM', 'CPV': 'CV', 'CRC': 'CR', 'CRO': 'HR',
      'CUB': 'CU', 'CUW': 'CW', 'CYP': 'CY', 'CZE': 'CZ',
      // D
      'DEN': 'DK', 'DJI': 'DJ', 'DMA': 'DM', 'DOM': 'DO',
      // E
      'ECU': 'EC', 'EGY': 'EG', 'ENG': 'GB-ENG', 'EQG': 'GQ', 'ERI': 'ER',
      'ESP': 'ES', 'EST': 'EE', 'ETH': 'ET',
      // F
      'FIJ': 'FJ', 'FIN': 'FI', 'FRA': 'FR', 'FRO': 'FO',
      // G
      'GAB': 'GA', 'GAM': 'GM', 'GEO': 'GE', 'GER': 'DE', 'GHA': 'GH',
      'GNB': 'GW', 'GRE': 'GR', 'GRN': 'GD', 'GUA': 'GT', 'GUI': 'GN',
      'GUM': 'GU', 'GUY': 'GY',
      // H
      'HAI': 'HT', 'HKG': 'HK', 'HON': 'HN', 'HUN': 'HU',
      // I
      'IDN': 'ID', 'IND': 'IN', 'IRL': 'IE', 'IRN': 'IR', 'IRQ': 'IQ',
      'ISL': 'IS', 'ISR': 'IL', 'ITA': 'IT',
      // J
      'JAM': 'JM', 'JOR': 'JO', 'JPN': 'JP',
      // K
      'KAZ': 'KZ', 'KEN': 'KE', 'KGZ': 'KG', 'KOR': 'KR', 'KSA': 'SA',
      'KUW': 'KW', 'KVX': 'XK',
      // L
      'LAO': 'LA', 'LBN': 'LB', 'LBR': 'LR', 'LBY': 'LY', 'LCA': 'LC',
      'LES': 'LS', 'LIE': 'LI', 'LTU': 'LT', 'LUX': 'LU', 'LVA': 'LV',
      // M
      'MAC': 'MO', 'MAD': 'MG', 'MAR': 'MA', 'MAS': 'MY', 'MAW': 'MW',
      'MDA': 'MD', 'MDV': 'MV', 'MEX': 'MX', 'MKD': 'MK', 'MLI': 'ML',
      'MLT': 'MT', 'MNE': 'ME', 'MNG': 'MN', 'MOZ': 'MZ', 'MRI': 'MU',
      'MSR': 'MS', 'MTN': 'MR', 'MYA': 'MM',
      // N
      'NAM': 'NA', 'NCA': 'NI', 'NCL': 'NC', 'NED': 'NL', 'NEP': 'NP',
      'NGA': 'NG', 'NIG': 'NE', 'NIR': 'GB-NIR', 'NOR': 'NO', 'NZL': 'NZ',
      // O
      'OMA': 'OM',
      // P
      'PAK': 'PK', 'PAN': 'PA', 'PAR': 'PY', 'PER': 'PE', 'PHI': 'PH',
      'PLE': 'PS', 'PLW': 'PW', 'PNG': 'PG', 'POL': 'PL', 'POR': 'PT',
      'PRK': 'KP', 'PUR': 'PR',
      // Q
      'QAT': 'QA',
      // R
      'ROU': 'RO', 'RSA': 'ZA', 'RUS': 'RU', 'RWA': 'RW',
      // S
      'SAM': 'WS', 'SCO': 'GB-SCT', 'SEN': 'SN', 'SEY': 'SC', 'SIN': 'SG',
      'SKN': 'KN', 'SLE': 'SL', 'SLV': 'SV', 'SMR': 'SM', 'SOL': 'SB',
      'SOM': 'SO', 'SRB': 'RS', 'SRI': 'LK', 'SSD': 'SS', 'STP': 'ST',
      'SUI': 'CH', 'SUR': 'SR', 'SVK': 'SK', 'SVN': 'SI', 'SWE': 'SE',
      'SWZ': 'SZ', 'SYR': 'SY',
      // T
      'TAH': 'PF', 'TAN': 'TZ', 'TCA': 'TC', 'TGA': 'TO', 'THA': 'TH',
      'TJK': 'TJ', 'TKM': 'TM', 'TLS': 'TL', 'TOG': 'TG', 'TPE': 'TW',
      'TRI': 'TT', 'TUN': 'TN', 'TUR': 'TR',
      // U
      'UAE': 'AE', 'UGA': 'UG', 'UKR': 'UA', 'URU': 'UY', 'USA': 'US',
      'UZB': 'UZ',
      // V
      'VAN': 'VU', 'VEN': 'VE', 'VIE': 'VN', 'VIN': 'VC',
      // W
      'WAL': 'GB-WLS',
      // Y
      'YEM': 'YE',
      // Z
      'ZAM': 'ZM', 'ZIM': 'ZW',
    };
    return map[code3];
  }
}

class _FlagFallback extends StatelessWidget {
  const _FlagFallback({required this.countryCode, required this.size});

  final String countryCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = countryCode.trim().toUpperCase();
    final label = normalized.length == 2 ? _emojiFlag(normalized) : normalized;

    return ColoredBox(
      color: const Color(0xFFE8EEF3),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFF16324A),
            fontWeight: FontWeight.w800,
            fontSize: size * 0.22,
          ),
        ),
      ),
    );
  }

  String _emojiFlag(String code) {
    final first = code.codeUnitAt(0) + 127397;
    final second = code.codeUnitAt(1) + 127397;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}

class _DiamondClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

