# Play Build Runbook (WP-122)

```bash
cd app
# versionCode must be > last uploaded (current code 29 → use 30+)
flutter build appbundle --flavor play --release \
  --build-number=30 \
  --dart-define=DISTRIBUTION_CHANNEL=play \
  --dart-define-from-file=env.json
```

Validate:

```bash
# after unzip / bundletool
# REQUEST_INSTALL_PACKAGES must be ABSENT
```

GitHub sideload (unchanged):

```bash
flutter build apk --flavor stable --release \
  --dart-define=CHANNEL=stable \
  --dart-define=DISTRIBUTION_CHANNEL=githubStable \
  --dart-define-from-file=env.json
```

**Never** force-retag `v29` with new code.
