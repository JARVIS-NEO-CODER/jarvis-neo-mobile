# JARVIS NEO Mobile

Companion mobile de l'écosystème J.A.R.V.I.S. NEO, pensée pour Android et iOS.

## État

Prototype fonctionnel cross-platform : interface sombre Material 3, cockpit JARVIS, chat IA, configuration Groq, optimisation cloud/local, appareils, fichiers, routines, Sentinel, sécurité et sauvegarde de préférences.

Le dépôt utilise Flutter afin de partager le cœur applicatif entre Android et iOS. Les workflows GitHub Actions génèrent automatiquement l'APK Android et une build iOS non signée.

## Architecture cible

- `lib/` : application Flutter et logique mobile
- `android/`, `ios/` : générés par `flutter create` dans CI pour garder le dépôt léger au démarrage
- `.github/workflows/build.yml` : builds Android/iOS

## IA et tokens

La clé Groq est saisie dans les paramètres et stockée côté appareil. Elle n'est pas codée en dur dans le dépôt. Le client doit privilégier le traitement local et n'envoyer au cloud que le contexte nécessaire. Une couche de routage JARVIS NEO devra ensuite connecter le mobile au moteur PC/local et appliquer les règles de quota/fallback.

## Sécurité

Les actions sensibles doivent rester soumises aux permissions et confirmations de l'utilisateur. Les paiements ne doivent jamais être confirmés automatiquement par JARVIS.

## Build local

```bash
flutter pub get
flutter run
flutter build apk --release
flutter build ios --release --no-codesign
```

## Important

Certaines capacités demandées dans le cahier des charges nécessitent des APIs natives, des permissions système, un backend JARVIS NEO, des intégrations tierces ou des services Apple/Google. Le prototype expose leur architecture et leur interface, mais ne prétend pas contourner les restrictions des OS.
