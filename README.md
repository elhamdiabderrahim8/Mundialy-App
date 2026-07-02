# 🏆 Mundialy - World Cup Tracker & IPTV Player

<div align="center">
  <img src="flutter_application_1/assets/logo.png" alt="Mundialy Logo" width="160"/>
  <br/>
  <p><b>A Premium Football Companion App featuring Live World Cup Tracking (2022 & 2026), Real-time Match Analytics, and Integrated IPTV Streaming.</b></p>

  [![Flutter](https://img.shields.io/badge/Flutter-3.12.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Python Backend](https://img.shields.io/badge/Python-3.9+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
  [![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://www.android.com/)
  [![Firebase](https://img.shields.io/badge/Firebase-F58220?style=for-the-badge&logo=firebase&logoColor=white)](https://firebase.google.com/)
  [![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
</div>

---

## 🔗 Live Demo & Interactive Sandbox

Experience **Mundialy** instantly in your web browser without installing any APKs. 

> [!TIP]
> **🚀 [Try the Live Interactive Demo on Appetize.io](https://appetize.io)** *(Upload your APK build to Appetize.io to get a shareable URL)*

*Alternatively, scan the QR code below on your Android device to install the application instantly via **Diawi** / **InstallOnAir**:*

<div align="center">
  <img src="https://via.placeholder.com/150x150.png?text=Diawi+QR+Code" alt="Diawi QR Code Install" width="150"/>
  <br/>
  <i>Scan to install the signed release APK</i>
</div>

---

## ✨ Key Features

Mundialy provides a comprehensive, feature-rich experience for football fans and IPTV viewers, wrapped in a premium Dark/Gold theme.

### ⚽ Football Analytics & Live Matches
*   ⚡ **Real-Time Live Scores**: Live score tracking with instant match status updates, scores, and events.
*   🎉 **Animated Goal Overlay**: Dynamic visual notifications (`Animated Goal Overlay`) slide onto the screen whenever a goal is scored.
*   📊 **Historical Stats (2022)**: Complete database of matches, statistics, and group standings from the Qatar 2022 World Cup.
*   📅 **Upcoming Matches (2026)**: Track qualifiers and schedules for the upcoming United 2026 World Cup.
*   👤 **Detailed Profiles**:
    *   **Team Profiles**: Team squad rosters sorted by positions (Goalkeepers, Defenders, Midfielders, Attackers), manager info, and historical performance.
    *   **Player Profiles**: Official photos, age, height, physical attributes, and international stats.

### 📺 IPTV Integration
*   🔑 **Multi-Protocol Login**: Supports connecting to IPTV servers via **Xtream Codes API** or **M3U Playlist URLs**.
*   📂 **Channel Organization**: Automatic categorization of Live Channels, Movies, and TV Series.
*   🎥 **Native Video Player**: Integrated video player based on `chewie` and `video_player` with stream quality selectors, picture-in-picture, and custom controls.

### 🔔 Notifications & Monetization
*   💬 **Firebase Push Notifications**: Real-time push alerts for match kick-offs, goals, and breaking football news using FCM (Firebase Cloud Messaging).
*   💵 **Start.io Ads Integration**:
    *   **App-Open Interstitials**: High-revenue full-screen advertisements shown gracefully during app launches and app resume cycles.
    *   **Native Adaptive Banners**: Non-intrusive ad banners intelligently interspersed within match lists (every 3 matches) and at the bottom of video screens.

---

## 🛠️ Architecture & Project Structure

Mundialy is designed with a decoupled architecture containing a Flutter frontend client and a Python proxy backend to handle secure data fetching.

```
Mundialy-App/
├── flutter_application_1/      # 📱 Flutter Mobile Application
│   ├── lib/
│   │   ├── models/            # Data models (Match, Team, Player, IPTV)
│   │   ├── screens/           # UI Screens (Home, MatchDetails, IPTV, etc.)
│   │   ├── services/          # API services, Start.io SDK wrappers, and lifecycle management
│   │   ├── widgets/           # Reusable UI widgets (MatchCard, Banners, GoalOverlay)
│   │   └── main.dart          # App entry point & State Provider initialization
│   └── assets/                # Local data files, logos, and UI watermarks
│
└── sofascore_backend/          # ⚙️ Python Flask API Proxy & Firebase Administration
    ├── app.py                 # Flask server with curl_cffi for bot protection bypass
    ├── requirements.txt       # Server dependencies
    └── serviceAccountKey.json # Firebase Admin SDK credentials (encrypted/private)
```

---

## 🛡️ Backend Anti-Bot Bypass Mechanism

A standout technical aspect of this project is the **SofaScore API Bypass** located in the backend. 
SofaScore uses advanced cloud protection (Cloudflare) to block standard HTTP libraries (like Python's `requests` or Flutter's `http`). 

To bypass this without paying for expensive scraping services:
1. The backend implements `curl_cffi` (Curl Client File Interface), which mimics browser TLS fingerprints (JA3/JA4) and HTTP/2 headers exactly.
2. The Flutter app queries the Python Flask backend instead of SofaScore directly.
3. The Flask API proxy forwards the request, bypasses the Cloudflare shield, parses the JSON payload, and feeds the clean data back to the Flutter client instantly.

---

## 🚀 Setup & Installation

### 1. Backend Setup (`sofascore_backend`)
Prerequisites: Python 3.9+

1. Navigate to the backend directory:
   ```bash
   cd sofascore_backend
   ```
2. Install the required Python libraries:
   ```bash
   pip install -r requirements.txt
   ```
3. Start the local server:
   ```bash
   python app.py
   ```
   *The server will run on `http://127.0.0.1:5000`.*

### 2. Mobile Frontend Setup (`flutter_application_1`)
Prerequisites: Flutter SDK (v3.12.0+), Java Development Kit (JDK 17), Android Studio.

1. Navigate to the Flutter project:
   ```bash
   cd flutter_application_1
   ```
2. Retrieve the dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app in development mode:
   ```bash
   flutter run --dart-define=WC2026_API_KEY=YOUR_FREE_FOOTBALL_API_KEY
   ```

---

## 📦 Building the Signed APK

The app is pre-configured to automatically sign release builds using the APKPure signature keystore (`apkpure-debug.keystore`).

To build the obfuscated release APK:
```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols --dart-define=WC2026_API_KEY=YOUR_API_KEY
```

The compiled APK will be generated at:
`flutter_application_1/build/app/outputs/flutter-apk/app-release.apk`

---

## 🤝 Maintainers & License

*   **Lead Developer**: [elhamdiabderrahim8](https://github.com/elhamdiabderrahim8)
*   **License**: This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

<div align="center">
  <p>Made with ❤️ for Football Fans and IPTV Enthusiasts worldwide.</p>
</div>
