# app_scan

Application mobile partenaire MYSIGNAL pour scanner les cartes de reduction.

## Configuration locale

Copier le fichier d exemple puis renseigner les valeurs Firebase Android :

```bash
cp config/firebase.example.json config/firebase.local.json
```

Le fichier `config/firebase.local.json` est ignore par Git.

Lancer l application avec les variables :

```bash
flutter run --dart-define-from-file=config/firebase.local.json
```

Build debug :

```bash
flutter build apk --debug --dart-define-from-file=config/firebase.local.json
```

Valeurs attendues dans le fichier :

```json
{
  "API_BASE_URL": "https://my-signal.online/api",
  "FIREBASE_ANDROID_API_KEY": "",
  "FIREBASE_ANDROID_APP_ID": "",
  "FIREBASE_MESSAGING_SENDER_ID": "",
  "FIREBASE_PROJECT_ID": "my-signal-1b9d9",
  "FIREBASE_STORAGE_BUCKET": ""
}
```

Important : dans Firebase, l application Android doit correspondre au package Android utilise par l app, actuellement `com.mysignal.scanci`.
