# Guide DevOps et CI/CD - Mundialy

Ce guide explique comment fonctionne le pipeline de déploiement continu mis en place.

## 1. Structure Monorepo

Le dépôt racine `D:\WordCup` contient :
- `flutter_application_1/` : L'application mobile Flutter
- `sofascore_backend/` : Le backend Python Flask
- `.github/workflows/` : Les pipelines GitHub Actions

Les pipelines sont configurés pour s'exécuter spécifiquement dans le répertoire de l'application Flutter en utilisant `working-directory: flutter_application_1`.

## 2. CI/CD avec GitHub Actions (Gratuit via Student Pack)

Deux workflows automatisés sont en place :

1. **`ci.yml` (Intégration Continue)** : S'exécute à chaque _push_ sur la branche `main`. Il vérifie le formatage du code, analyse les erreurs (lints), et exécute les tests unitaires pour assurer la **stabilité** et **maintenabilité**.
2. **`cd.yml` (Déploiement Continu)** : S'exécute lors de la création d'un "Tag". Il compile l'APK de production optimisé et obfusqué, puis le publie directement dans les **Releases GitHub**.

### Comment publier une nouvelle version publique ?

C'est très simple :
1. Poussez vos changements sur la branche `main`.
2. Sur GitHub, allez dans **Releases** > **Draft a new release**.
3. Créez un nouveau tag (ex: `v1.0.0`) et donnez un titre à votre version.
4. Cliquez sur **Publish release**.
5. *GitHub Actions va démarrer, compiler l'APK `com.mundialy.app` signé, et l'ajouter automatiquement aux fichiers de la Release.* N'importe qui pourra alors télécharger l'APK !

### Configuration de la Sécurité (Keystore)

Pour que l'APK de production soit signé correctement, vous devez ajouter les informations de votre keystore dans GitHub :
1. Allez dans votre dépôt GitHub > **Settings** > **Secrets and variables** > **Actions**.
2. Ajoutez ces secrets :
   - `KEYSTORE_BASE64` : Le fichier de votre keystore encodé en texte (utilisez `certutil -encode keystore.jks keystore.txt` sur Windows)
   - `KEYSTORE_PASSWORD` : Le mot de passe du keystore
   - `KEY_ALIAS` : L'alias de la clé
   - `KEY_PASSWORD` : Le mot de passe de la clé

Si ces secrets sont manquants, le pipeline signera avec les clés de débug.

## 3. Déploiement Professionnel du Backend (Gratuit)

Le serveur de développement Flask `app.run()` n'est pas conçu pour de multiples utilisateurs. Pour résoudre le message `WARNING: This is a development server`, nous utilisons **Gunicorn** (un serveur WSGI professionnel).

### Déployer sur Render.com (Gratuit)

Render est idéal pour héberger gratuitement des API Python et remplace parfaitement le serveur de développement local :
1. Connectez-vous à [Render.com](https://render.com) avec votre compte GitHub.
2. Créez un nouveau **Web Service**.
3. Connectez votre dépôt GitHub `elhamdiabderrahim8/world-cup`.
4. Configurez :
   - **Root Directory**: `sofascore_backend`
   - **Environment**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn app:app`
5. Sélectionnez l'instance "Free" et déployez !

Une fois déployé, remplacez les URL `http://127.0.0.1:5000` dans votre application Flutter (`api_service.dart`) par l'URL publique fournie par Render.

## 4. Tests et Qualité ISO/IEC 25010

- **Fiabilité** : Tests unitaires ajoutés (`live_match_test.dart`) vérifiant la gestion du parsing JSON et les erreurs réseau potentielles.
- **Maintenabilité** : Pipeline CI avec `flutter analyze`.
- **Utilisabilité et Performance** : La CI/CD permet de déployer rapidement des correctifs pour garantir la fluidité auprès de multiples utilisateurs.
