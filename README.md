<div align="center">
  <img src="flutter_application_1/assets/logo.png" alt="Mundialy Logo" width="150"/>
  <h1>🏆 Mundialy</h1>
  <p><b>L'application ultime pour suivre les Coupes du Monde (2022 & 2026) et profiter du contenu IPTV.</b></p>

  [![Flutter](https://img.shields.io/badge/Flutter-3.12.0-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
  [![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android)](https://www.android.com/)
  [![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
</div>

<br/>

## ✨ Fonctionnalités Principales

Mundialy vous permet de plonger au cœur des compétitions internationales de football grâce à une interface riche, fluide et pensée pour les fans.

*   🔴 **Matchs en Direct** : Suivez les scores en temps réel sans avoir à rafraîchir l'écran, avec des animations de but superposées (`Animated Goal Overlay`).
*   📅 **Historique & Programme** : Parcourez les résultats complets de la Coupe du Monde 2022 et le programme des qualifications pour 2026.
*   📊 **Statistiques Détaillées** :
    *   **Classements complets** par groupes.
    *   **Profils des équipes** : Historique, sélectionneur, et liste complète de l'effectif classée par postes.
    *   **Profils des joueurs** : Âge, taille, statistiques nationales, caractéristiques physiques et photo officielle.
*   📺 **Module IPTV Intégré** : Connectez-vous avec vos identifiants pour accéder aux catégories de chaînes et profitez d'un lecteur vidéo natif et fluide.
*   📰 **Actualités** : Les dernières nouvelles et articles concernant les compétitions (via une interface UI optimisée).
*   🔔 **Notifications Push** : Ne ratez aucun moment clé grâce à l'intégration complète de Firebase Cloud Messaging (FCM).
*   🎨 **Thème Dynamique** : Support natif du Mode Sombre (Dark Mode) et du Mode Clair avec une palette de couleurs Premium (Or, Bleu Nuit).

---

## 📸 Aperçus (Screenshots)

| Accueil & Matchs | Profil de l'Équipe | Lecteur IPTV |
| :---: | :---: | :---: |
| <img src="https://via.placeholder.com/250x500.png?text=Accueil" width="250"> | <img src="https://via.placeholder.com/250x500.png?text=Profil+%C3%89quipe" width="250"> | <img src="https://via.placeholder.com/250x500.png?text=Lecteur+IPTV" width="250"> |

---

## 🚀 Installation & Build

### 1. Prérequis
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.12.0 ou supérieure)
*   Java Development Kit (JDK 17 recommandé)
*   Android Studio / Xcode

### 2. Cloner le projet
```bash
git clone https://github.com/elhamdiabderrahim8/Mundialy-App.git
cd Mundialy-App/flutter_application_1
```

### 3. Installer les dépendances
```bash
flutter pub get
```

### 4. Compiler pour Android (APK)
Le projet est configuré pour signer automatiquement l'APK de production avec la signature officielle APKPure (`apkpure-debug.keystore`).
```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

L'APK sera généré dans `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🛠️ Technologies Utilisées

*   **Framework** : [Flutter](https://flutter.dev/) & Dart
*   **Architecture & State Management** : `Provider`
*   **Réseau** : `http`, `cronet_http` (avec contournement anti-bot via requêtes résidentielles)
*   **Vidéo** : `video_player`, `chewie`
*   **Backend & Data** : Firebase (Notifications), SofaScore API (Données live, joueurs, stats)
*   **Intégration Continue (CI/CD)** : GitHub Actions (Compilation et Release automatisées)

---

## 🤝 Contribution & Maintenance

L'application récupère ses données de football via un bypass direct vers l'API de SofaScore (`SofaDirectService`). En cas de changement de format d'API, le parser `TeamPlayer.fromApi` ou les URLs d'images peuvent nécessiter une mise à jour.

<div align="center">
  <p>Fait avec ❤️ pour les passionnés de Football.</p>
</div>
