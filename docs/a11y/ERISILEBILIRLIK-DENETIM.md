# Erişilebilirlik denetimi (WP-140)

**Tarih:** 2026-07-18  
**Kapsam:** `lib/features/**` (timer FGS / StudyWidget / timer_notification **hariç**).  
**Amaç:** Play pre-launch / TalkBack hazırlığı (WP-123).

## Taranan / düzeltilen yüzeyler

| Ekran / dosya | Yapılan |
|---|---|
| Admin duyurular | Sil IconButton: `tooltip` + min 48 |
| Admin raporlar (görsel kapat, not kapat, gönder) | tooltip + min 48 |
| Sosyal profil diyaloğu | Kapat / tam profil tooltip + min 48 |
| Rapor ekle diyaloğu | Ek kaldırma tooltip + min 48; renk scheme |
| Dünya saati şehir sil | `clockSil` tooltip + min 48 |
| Kronometre aksiyon | `tooltip: label` (zaten ≥56) |
| İzin kartları (`clock_widgets_screen`) | semanticLabel=title; ikon rengi scheme; metin overflow |
| Engellenen kullanıcılar | Avatar Semantics; başlık maxLines; Unblock min 48 |

## Kriterler

- İkon-only aksiyon: **etiket (tooltip/semantics)** ✓ taranan set
- Dokunma hedefi: düzeltilen IconButton’lar **≥48×48** ✓
- Büyük font: engellenenler + izin kartı başlık/alt **ellipsis** ✓
- Renk+ikon: izin durumu check vs warning ikonu (yalnız renk değil) ✓

## Kapsam dışı / kalan (cihaz)

- [ ] TalkBack ile tüm sekmelerde gezinme (fiziksel cihaz)
- [ ] textScaleFactor 1.3 sistem ayarı smoke (Ayarlar, Legal, Admin)
- [ ] Timer widget / bildirim a11y (WP-134–137 QA — bu pakette yok)
- [ ] Campfire sahne decorative asset’ler (ExcludeSemantics — sonraki tur)

## Analyze

`flutter analyze` → **0 issue** (commit anı).
