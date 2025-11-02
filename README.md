# YamScore – Suivi des Scores de Yam's

Cette application Flutter permet de suivre les scores des parties de **Yam's**.  
Pour l'instant, **seule la version Android** est disponible.

---

## Prérequis

Avant de commencer, assurez-vous d'avoir installé :

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version stable recommandée)

---

## Installation

1. **Cloner le dépôt**

```bash
git clone <URL_DU_DEPOT>
cd yam_score
```

2. **Récupérer les dépendances Flutter**

```bash
flutter pub get
```

3. **Vérifier que Flutter et Android sont prêts**

```bash
flutter doctor
```

Assurez-vous qu’il n’y a pas d’erreurs majeures et que votre appareil (émulateur ou téléphone) est détecté.

4. **Build APK**

```bash
flutter clean
flutter pub get
flutter build apk --release
```

L’APK généré se trouvera dans : `build/app/outputs/apk/release/``

5.	**Installer l’application**

Sur un appareil Android branché :

a. Connectez votre téléphone via USB et activez le mode développeur et le USB debugging.

b. Vérifiez que le téléphone est détecté :

```bash
flutter devices
```

Exemple de sortie :

```bash
1 connected device:

SM A546B (mobile) • A2RJB5SCIEJ • android-arm64  • Android 15 (API 35)
```
    
c. Lancez l’installation de l’application :

```bash
flutter install -d <device_id>
```

## Fonctionnalités
- Ajouter, modifier et supprimer des joueurs.
- Créer et gérer des parties de Yam’s.
- Suivi des scores par joueur pour chaque partie.
- Statistiques détaillées : moyennes par combinaison, pourcentages de réussites, bonus et meilleur score.
- Leaderboard : scores cumulés et meilleurs scores individuels.
- Mode sélection pour supprimer plusieurs joueurs ou parties à la fois.

## Auteur

Manuia Sylvestre-Baron © 2025