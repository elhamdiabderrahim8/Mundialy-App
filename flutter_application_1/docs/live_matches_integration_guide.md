# Mundialy Live Matches Integration Guide

This module is intentionally separate from the legacy Xtream IPTV feature.
Do not edit files under `lib/screens/iptv/` for this integration.

## Dependencies

Append these dependencies to `pubspec.yaml` under `dependencies:`:

```yaml
  better_player: ^0.0.84
  webview_flutter: ^4.14.0
```

`webview_flutter` 4.x uses `WebViewController` plus `WebViewWidget`, which is the API used by `ProfessionalLivePlayerScreen`.

## Option A: Add A Tab Inside An Existing Live View

Import the tab:

```dart
import 'matches_list_tab.dart';
```

Use it as a separate tab without replacing the Xtream widget:

```dart
DefaultTabController(
  length: 2,
  child: Scaffold(
    appBar: AppBar(
      title: const Text('Live'),
      bottom: const TabBar(
        tabs: [
          Tab(text: 'Matches'),
          Tab(text: 'IPTV'),
        ],
      ),
    ),
    body: const TabBarView(
      children: [
        MatchesListTab(),
        IptvMainScreen(),
      ],
    ),
  ),
);
```

## Option B: Keep Current Bottom Navigation And Route Live Matches Separately

Add a button or tile anywhere outside `lib/screens/iptv/`:

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => const MatchesListTab(),
  ),
);
```

If you need a full page wrapper:

```dart
class LiveMatchesScreen extends StatelessWidget {
  const LiveMatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: MatchesListTab(),
      ),
    );
  }
}
```

## Safety Notes

- Keep `IptvMainScreen`, `IptvPlayerScreen`, and all Xtream service/model files unchanged.
- `MatchesListTab` imports only `live_match_model.dart` and `ProfessionalLivePlayerScreen`.
- The new model file is named `live_match_model.dart` to avoid interfering with the existing `lib/models/live_match.dart`.

## Correct Match To Stream Mapping

The live module separates match fixtures from stream sources:

- Fixtures describe the visible match card: teams, logos, live time, and match id.
- Stream sources describe the provider/player target URL for one exact match id.

Example:

```dart
const fixtures = [
  LiveMatch(
    id: 'sweden-ukraine-2026-06-27',
    homeTeam: 'Sweden',
    awayTeam: 'Ukraine',
    homeLogo: 'https://flagcdn.com/w160/se.png',
    awayLogo: 'https://flagcdn.com/w160/ua.png',
    time: 'LIVE 23\'',
    targetStreamUrl: '',
  ),
  LiveMatch(
    id: 'asba-zokomk-2026-06-27',
    homeTeam: 'Asba',
    awayTeam: 'Zokomk',
    homeLogo: 'https://flagcdn.com/w160/ma.png',
    awayLogo: 'https://flagcdn.com/w160/hr.png',
    time: 'LIVE 41\'',
    targetStreamUrl: '',
  ),
];

const streams = [
  LiveStreamSource(
    matchId: 'sweden-ukraine-2026-06-27',
    providerName: 'Provider Sweden Ukraine',
    targetStreamUrl: 'https://provider.example/sweden-ukraine',
  ),
  LiveStreamSource(
    matchId: 'asba-zokomk-2026-06-27',
    providerName: 'Provider Asba Zokomk',
    targetStreamUrl: 'https://provider.example/asba-zokomk',
  ),
];
```

`LiveMatchStreamMapper.bindStreamsToMatches()` joins these lists by `matchId`.
That means tapping `Asba vs Zokomk` can only open the stream whose `matchId` is `asba-zokomk-2026-06-27`.
If a match has no stream source yet, the card stays visible but does not open a wrong player.
