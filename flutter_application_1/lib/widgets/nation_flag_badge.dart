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
    final normalizedCode = _normalizeCountryCode(countryCode);
    if (normalizedCode != null) {
      return 'https://flagcdn.com/w160/${normalizedCode.toLowerCase()}.png';
    }

    final override = imageUrlOverride;
    if (override != null && override.isNotEmpty && override.startsWith('http')) {
      return override;
    }

    return null;
  }

  String? _normalizeCountryCode(String rawCode) {
    final upper = rawCode.trim().toUpperCase();
    if (upper.length == 2) return upper;
    if (upper.length == 3) return _map3To2(upper);
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

  String? _map3To2(String code3) {
    const map = {
      'ARG': 'AR',
      'BEL': 'BE',
      'BRA': 'BR',
      'CAN': 'CA',
      'ENG': 'GB',
      'ESP': 'ES',
      'FRA': 'FR',
      'GER': 'DE',
      'ITA': 'IT',
      'JPN': 'JP',
      'KOR': 'KR',
      'MAR': 'MA',
      'MEX': 'MX',
      'NED': 'NL',
      'POR': 'PT',
      'QAT': 'QA',
      'ROU': 'RO',
      'SUI': 'CH',
      'TUN': 'TN',
      'URU': 'UY',
      'USA': 'US',
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
