# 📁 Guide d'organisation du projet Flutter

## Structure recommandée

```
lib/
├── main.dart                 # Point d'entrée de l'app
├── screens/                  # 📺 Toutes les pages de l'app
│   ├── home_screen.dart
│   ├── settings_screen.dart
│   └── profile_screen.dart
├── widgets/                  # 🧩 Composants réutilisables
│   ├── custom_button.dart
│   ├── custom_card.dart
│   └── app_drawer.dart
├── models/                   # 📦 Classes de données
│   ├── user.dart
│   ├── product.dart
│   └── order.dart
├── constants/                # ⚙️ Valeurs fixes (couleurs, textes, etc.)
│   ├── app_colors.dart
│   ├── app_strings.dart
│   └── app_sizes.dart
└── utils/                    # 🔧 Fonctions utilitaires
    ├── validators.dart       # Validation (email, téléphone, etc.)
    └── formatters.dart       # Formatage (dates, nombres, etc.)
```

---

## 📝 Explication de chaque dossier

### **1. `screens/` - Les pages**
- Chaque fichier = une page de votre app
- C'est la structure PRINCIPALE
- Contient les `Scaffold`, `AppBar`, `FloatingActionButton`

**Exemple:**
```dart
// screens/home_screen.dart
class HomeScreen extends StatefulWidget { ... }
```

### **2. `widgets/` - Composants réutilisables**
- Les petits composants que vous utiliserez PARTOUT
- Les boutons custom, cartes, listes...

**Exemple:**
```dart
// widgets/custom_button.dart
class CustomButton extends StatelessWidget { ... }
```

### **3. `models/` - Les classes de données**
- Les objets (User, Product, etc.)
- Les structures de vos données

**Exemple:**
```dart
// models/user.dart
class User {
  final String name;
  final String email;
}
```

### **4. `constants/` - Valeurs fixes**
- Couleurs: `app_colors.dart`
- Textes: `app_strings.dart` 
- Tailles: `app_sizes.dart`

**Avantage:** Modifier une couleur une seule fois, elle change partout!

### **5. `utils/` - Fonctions utilitaires**
- Validations (email valide? téléphone valide?)
- Formatage (date, nombre, devise)
- Fonctions générales

---

## 🚀 Workflow recommandé

### **Vous créez une nouvelle page?**
1. Créez le fichier dans `screens/`
2. Importez-le dans `main.dart` si c'est la page d'accueil
3. Utilisez les couleurs de `constants/app_colors.dart`

### **Vous créez un composant réutilisable?**
1. Créez le fichier dans `widgets/`
2. Importez-le dans vos `screens/`

### **Vous avez des données?**
1. Créez une classe dans `models/`
2. Importez-la où vous en avez besoin

---

## 💡 Conseils pour débuter

✅ **À FAIRE:**
- Un fichier = une classe (habituellement)
- Nommer clairement: `home_screen.dart`, pas `page1.dart`
- Réutiliser les composants (DRY: Don't Repeat Yourself)
- Centraliser les constantes

❌ **À ÉVITER:**
- Mettre tout le code dans `main.dart`
- Copier-coller du code (utiliser `widgets/` à la place)
- Coder les couleurs en dur: utiliser `AppColors`

---

## 📚 Exemple complet

### Vous voulez créer une page de profil?

**1. Créez `screens/profile_screen.dart`:**
```dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: Text('Votre profil',
          style: TextStyle(color: AppColors.primary),
        ),
      ),
    );
  }
}
```

**2. Utilisez-le dans `main.dart`:**
```dart
import 'screens/profile_screen.dart';
// ... dans MyApp
home: const ProfileScreen(),
```

---

## 🎯 Prochaines étapes

- [ ] Créer votre première page
- [ ] Ajouter un composant réutilisable dans `widgets/`
- [ ] Créer une classe `models/` pour vos données
- [ ] Ajouter plus de couleurs à `AppColors`

**Bonne chance! 🚀**
