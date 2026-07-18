# WP-166 — Bağımsız kalite denetimi raporu

**Tarih:** 2026-07-18  
**Kapsam commitler:** `b44f790` `e22f879` `f976fb0` `3041d3c` `5a4bfc5` `95ade5a` `f0c5ea3` `54f02ac`  
**Aşama:** Otomatik test geçti / cihaz-ops bekliyor  
**Push / deploy / SQL Editor / Play upload:** yok

## Özet

| Alan | Sonuç |
|---|---|
| Gerçek hata düzeltmeleri | 5 (aşağıda) |
| Timer/FGS dokunuşu (151–165) | Yok (`Kodda doğrulandı`) |
| `flutter analyze` | 0 uyarı |
| `flutter test` | 524 geçti; **1 önceden kırık** timer testi (donuk yüzey, bu WP’de düzeltilmedi) |
| Play AAB | Ortam/keystore blocker (aşağıda) |
| Ürün tamamlandı? | **Hayır** |

---

## Bulgu → düzeltme tablosu

| # | Bulgu (kanıt) | Düzeltme | Test |
|---|---|---|---|
| F1 | **Onboarding bayrağı cihaz geneli** — `onboarding_prefs.dart` eski `onboarding.completed_v1`; hesap A tamamlayınca cihazdaki hesap B atlıyordu | Per-user `onboarding.completed_v1.<userId>`; legacy global ignore + complete’te silme; auth loading’de false | `onboarding_test` (per-user keys, legacy, reset) |
| F2 | **Export profil sızıntı riski** — seed/map içine `email`/`token` konursa JSON’a girebilirdi; yıl aralığı `startOfYear(now)` cihaz yılı | Allow-list sanitize; `startOfYear(istanbulDay(now))` | `data_export_test` strip + year |
| F3 | **0042 cosmetics istemci yazılabilir** — `gamification_profiles` UPDATE policy `user_id=auth.uid()`; guard yalnız xp/crown | **0043** `_guard_gamification_xp_write` cosmetics koruması | SQL statik denetim; canlı SQL Editor sahip |
| F4 | **RTL hardcode** — `EdgeInsets.only(right:)`, `Alignment.centerLeft/Right` analytics + bildirim merkezi | `EdgeInsetsDirectional` / `AlignmentDirectional` | analyze 0; RTL birim testleri mevcut |
| F5 | **Level formül sapması riski** — `floor(sqrt(floor(xp/50)))` | `math.sqrt(xp/50).floor()+1` dokümantasyonla uyumlu | `level_curve_test` edge/high XP |
| N1 | AR/DE **EN baseline** (tam çeviri değil) | `docs/l10n/AR-DE-BASELINE-NOTE.md` | — |
| N2 | versionCode **29** release blocker | `scripts/play/build_play_aab.md` güçlendirildi | — |
| N3 | Timer testi pending FakeTimer | **Önceden kırık**; `study_providers.dart` donuk — bu pakette değiştirilmedi | `timer_mode_controls_test` 1 fail |

---

## Denetim başlıkları (özet kanıt)

### WP-151 Onboarding
- AuthGate: `profile == null` → Auth; `!onboardingDone` → Onboarding; aksi HomeShell.
- F1 ile multi-account isolation.
- Grup adımları `createGroupFlow` / `joinGroupFlow` (mevcut; true→next).
- Offline/izin red: try/catch continue.

### WP-152 Export
- Self `user_id` filter + InMemory seed isolation test.
- Email/token strip test.
- Istanbul year.
- Paylaşım hataları generic catch → `exportFailed`.

### WP-153 Hatırlatıcı
- Smart flags default **false**.
- Sessiz saat probe.
- `syncAll` iptal + yeniden kur.
- Timer dosyalarına 151–165 aralığında 0 satır.

### WP-154 Gamification
- Client XP yazımı yok; level türetilmiş.
- 0042 + 0043 cosmetics guard.
- Quest UI yalnız okuma.

### WP-155 Dil/RTL
- ar/de key parity (en ile 1150).
- EN/TR regresyon + de/ar sistem locale testleri güncellendi.
- Baseline notu dokümante.

### WP-164 Analitik
- Flag default kapalı (`analytics_grid_v1` ?? false).
- 0041 `start_time` migration metni doğrulandı.
- 0039–0043 sıra dosyada mevcut.

### Play/docs
- Sahte “deploy edildi” yok.
- versionCode 29 blocker açık.
- `54f02ac` Windows registrant yalnız share_plus.

---

## Otomatik kanıt

```
flutter analyze          → No issues found
flutter test --dart-define-from-file=env.json
  → +524 -1 (timer_mode_controls pending timer — pre-existing / frozen)
```

### Play AAB (denendi, yükleme yok)

Komut: `flutter build appbundle --flavor play --release --dart-define-from-file=env.json`  
Beklenen blocker: keystore / signing env veya version politikası.  
**Ayrıntı logda gizli alanlar redakte; upload yapılmadı.**

---

## Sahip aksiyonları (açık)

| İş | Not |
|---|---|
| SQL Editor | 0041, 0042, **0043** |
| Edge/cron / HTTPS URL / Play Console | OWNER-ACTION-CHECKLIST |
| Cihaz matrisi | DEVICE-QA-MATRIX |
| AR/DE insan çevirisi | AR-DE-BASELINE-NOTE |
| versionCode artır | 29 → N+1, ayrı release WP |
| Timer test flake | Ayrı debug WP (donuk yüzey) |

---

## Sonuç etiketi

**Otomatik test geçti (1 bilinen önceden kırık timer hariç) / cihaz-ops bekliyor.**  
Ürün tamamlandı **değil**.
