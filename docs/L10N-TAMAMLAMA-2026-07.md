# L10N Tamamlama — WP-182 (2026-07-18)

## Amaç
`app_ar.arb` / `app_de.arb` içindeki İngilizce-kalıntı kullanıcı metinlerini gerçek Arapça / Almanca ile tamamlamak; tr/en/ar/de anahtar kümesi paritesini ve ICU hijyenini doğrulamak.

## Kapsam
| Dokunuldu | Dokunulmadı |
|---|---|
| `app/lib/l10n/app_ar.arb` | `app_tr.arb` |
| `app/lib/l10n/app_de.arb` | timer / widget / FGS |
| `docs/L10N-TAMAMLAMA-2026-07.md` | Home / stats mantığı |
| gen-l10n çıktıları (otomatik) | |

## Anahtar kümesi (parite)
| Locale | Anahtar sayısı | Eksik / fazla |
|---|---:|---|
| tr | 1109 | 0 |
| en | 1109 | 0 (referans) |
| ar | 1109 | 0 |
| de | 1109 | 0 |

## Öncesi / sonrası (EN ile birebir aynı değer)

Ölçüm: `en[k] === locale[k]` (marka/placeholder dahil ham sayı).

| Locale | Önce aynı (EN kalıntı) | Sonra aynı | Farklı (çevrilmiş) | Çeviri oranı |
|---|---:|---:|---:|---:|
| **ar** | **561** (≈%50,5) | **7** | **1102** | **%99,4** |
| **de** | **97** (≈%8,7) | **51** | **1058** | **%95,4** |

### Arapça (ar) — sonra kalan 7 “aynı”
Hepsi bilinçli leave / marka / saf placeholder:
- `{label} 🏕️`, `{day} {month}`, `{todayseconds} / {goalseconds}`, `• {item}`
- Marka/terim: `Marathon`, `Material You`, `UTC`

Arapça betik içeren anahtar: **1102 / 1109**. Kullanıcıya görünen İngilizce cümle kalıntısı ≈ **0** (WP-173 karışık MT parçaları da temizlendi: örn. “I forgot my كلمة المرور” → “نسيت كلمة المرور”).

### Almanca (de) — sonra kalan 51 “aynı”
Çoğu DE’de de aynı yazılan kognat / şehir / marka / placeholder:
- Marka: `Focus Camp` (6 anahtar), `Admin`, `Alarm`, `Offline`, `Beta`, `Spam`, `Gold`/`Bronze`/`Marathon`
- Şehirler: Dubai, London, New York, Berlin, Paris, İstanbul, …
- Hayvan adları: Tiger, Koala, Panda
- Kognat UI: `Countdown`, `Vibration`, `Trend`, `Minute`, ay adları (April…)
- Saf placeholder: `ID: {id}`, `{status}, {state}`, `• {item}`, …

Bağlam düzeltmeleri: `classroomSaat`→Stunden, `classroomDakika`→Minuten, `clockBaslat`/`commonBaslat`→Starten, `safetyBlock`→Blockieren.

## ICU / placeholder
- Tüm `plural` yapıları ar/de’de korundu (`{count, plural, =0/ =1 / other …}`).
- Placeholder isimleri (`{error}`, `{displayname}`, `{streak}` …) en ile eşleşiyor.
- `flutter gen-l10n` **hatasız**.

## Kalite kapıları (gerçek çalıştırma)
| Kapı | Sonuç |
|---|---|
| `flutter gen-l10n` | OK |
| `flutter analyze` | **No issues found! (0)** |
| `flutter test --dart-define-from-file=env.json` | **+526 All tests passed!** (1 skip: Play kanal izolasyonu) |

## Yöntem notu
Ücretsiz MT (Google / MyMemory) günlük kota / 429 nedeniyle bu turda **çevrimdışı sözlük** kullanıldı: en→ar/de haritaları + WP-173’ten kalan AR+EN karışık dizelerin anahtar bazlı yeniden çevirisi. tr.arb okunarak bağlam doğrulandı; tr’ye yazılmadı.

## Kabul (WP-182)
- [x] ar/de kullanıcı metninde İngilizce cümle kalıntısı ≈ 0 (marka/özel ad/placeholder hariç)
- [x] Anahtar kümesi tr/en/ar/de birebir
- [x] ICU parse / gen-l10n temiz
- [x] analyze 0
- [x] full `flutter test` yeşil (526 passed)
- [ ] Cihazda dil değiştirme (ar RTL + de) — `Cihazda doğrulanmalı`

## Sonraki (isteğe bağlı)
- Cihaz QA: Ayarlar → Uygulama dili → ar / de; ana sekmelerde metin dönüşümü.
- DE kognat ay adları / `Start` (desktop) istenirse “Starten” ile hizalanabilir (çoğu zaten Starten).
