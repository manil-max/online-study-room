# L10N denetim özeti (WP-139)

**Tarih:** 2026-07-17  
**Kapsam:** ARB parity, sızıntı, hardcoded tarama (safety/legal/admin), native action string’leri.

## 1. Flutter ARB parity

| Metrik | Sonuç |
|---|---|
| `app_en.arb` anahtar | 1037 (+4 adminUgc* = 1041 gen-l10n sonrası) |
| `app_tr.arb` anahtar | aynı küme |
| Yalnız EN / yalnız TR | **0** |
| Boş değer | **0** |
| `safety*` anahtarları | 23 / 23 eş |

## 2. Sızıntı (TR↔EN)

- safety / legal / admin bloklarında otomatik sezgisel tarama: **0** şüpheli sızıntı.
- Bilinçli loanword: `Spam` (TR de aynı).

## 3. Hardcoded kullanıcı metni

| Dosya | Durum |
|---|---|
| `safety/report_sheet.dart` | l10n ✓ |
| `safety/blocked_users_screen.dart` | l10n ✓ |
| `safety/block_user_action.dart` | l10n ✓ |
| `legal_center_screen.dart` | l10n ✓ |
| `admin/tabs/admin_moderation_tab.dart` | **düzeltildi** → `adminUgcNoReports`, `adminUgcStatusInReview/Resolved/Rejected` |

Not: Rapor satırında `target_type` / `reason` / `status` **ham veritabanı değerleri** (teknik kod); kullanıcı etiketi değil. İleride enum çevirisi ayrı iş.

## 4. Native Android string paritesi

| Metrik | Sonuç |
|---|---|
| `values/strings.xml` anahtar | 66 |
| `values-tr/strings.xml` | 66 |
| Fark | **0** |
| `action_start/stop/break/return_to_work` | EN (default values) + TR (values-tr) ✓ |
| `timer_*` bildirim metinleri | EN + TR ✓ |

### Bilinen sınır (düzeltme bu WP’de yok)

RemoteViews / sistem bildirimi **cihaz sistem dilini** kullanır (`Configuration.locale`), uygulama içi **Ayarlar → Uygulama dili** seçimini **yansıtmaz**.  
Flutter `MaterialApp.locale` zinciri yalnız Flutter UI’yi kapsar (`main.dart` → `ReleaseNote.forLocale`).  
Native dil = sistem; uygulama dili ≠ native bildirim/widget metni. Ayrı ürün kararı / köprü gerekirse yeni WP.

## 5. Sürüm notları dil (WP-138 çapraz)

- `ReleaseNote.forLocale`: `languageCode == tr` → TR; aksi EN; EN boşsa TR yedek (`release_notes_service.dart`).
- `updater_dialog` / `release_notes_screen`: `Localizations.localeOf(context)` → MaterialApp `locale:` (seçilen dil). **Sapma yok** (kod teyidi).

## 6. Araçlar

- `flutter gen-l10n` — temiz
- `flutter analyze` — **0 issue** (WP-139 commit anı)

## 7. Düzeltme listesi (bu WP)

1. Admin moderasyon hardcoded metinleri ARB’ye taşındı.
2. Denetim dokümanı eklendi.
3. Parity/sızıntı/native: ek içerik düzeltmesi gerekmedi.
