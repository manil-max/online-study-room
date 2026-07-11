---
name: worker
description: >
  İş paketini (WP) uygulayan ajan. Kullanıcı "progress.md oku ve WP-N'yi yap"
  deyince WP detayını okur ve kurallara uygun şekilde kodu yazar.
---

# Uygulayıcı Ajan Rehberi

## Tetik

Kullanıcı: **"progress.md oku ve WP-N'yi yap"**

---

## Akış

```
1. progress.md oku           → kendi lane'ini ve WP'ni bul
2. "Proje Gerçekleri" oku    → teknik bağlam
3. "✅ Tamamlanan İş Paketleri"ni oku → son değişikliklerin bağlamı
4. Başlamadan önce            → kendi lane'ini `Aktif`, WP durumunu `[~] Uygulanıyor` yap
5. WP adımlarını sırayla yap → sadece SAHİP dosyalara yaz
6. Tümü bitince               → test + analyze + WP'yi tamamlananlara taşı + commit
```

---

## Kod Kuralları

### Derleme
- `cd app` içinde çalış, repo kökünde değil
- Her `flutter` komutuna `--dart-define-from-file=env.json` geç
- Web testi: `flutter run -d chrome --web-port=5005 --dart-define-from-file=env.json`

### Repo Katmanı
- Her repository **çift implementasyonlu**: `supabase/` + `in_memory/`
- Yeni özellik ekliyorsan **ikisini de güncelle** yoksa demo/offline mod kırılır
- Arayüz değişikliği → `data/repositories/xxx_repository.dart` (abstract)

### Veritabanı
- Yeni migration → `supabase/migrations/NNNN_ad.sql` (sıralı, son numaradan devam)
- Migration sırası bozulmamalı (0001→...→0013→...)
- RLS zorunlu — istemci kontrolü kozmetik, güvenlik DB'de
- SECURITY DEFINER helper'lar: `is_group_member(gid)`, `can_see_user_sessions(target)`, `is_group_admin(gid)`

### Güvenlik
- `env.json`, `key.jks`, `key.properties` **commit etme**
- Commit öncesi `git status` ile gizli dosya kontrolü
- Supabase `service_role` key asla istemcide olmaz

### Dil
- Kullanıcıya görünen metinler **Türkçe**
- Kod/değişken isimleri **İngilizce**
- Gün sınırı her yerde **Europe/Istanbul**

---

## Paralel Çalışma Kuralları (Kritik)

1. **Sadece kendi WP'nin SAHİP dosyalarına yaz**
2. Başka WP'nin SAHİP dosyasına **ASLA dokunma** (okuyabilirsin)
3. DOKUNMA listesindeki dosyaları **kesinlikle değiştirme**
4. `progress.md`'de **sadece kendi lane'ini ve kendi WP bölümünü** düzenle
5. Yeni dosya eklemek serbest ama **yalnız kendi feature klasörüne**
6. Ortak dosya değişikliği gerekiyorsa → WP'de belirtilmiş olmalı, yoksa **dur ve kullanıcıya sor**

---

## Lane Disiplini

- `progress.md` üç canlı lane içerir: `Gemini`, `Claude`, `Codex`.
- Her agent yalnız kendi lane'inde çalışan WP kartını günceller.
- Bir WP başka ajana geçiyorsa, tek editte yeni lane'e taşınır ve kısa bir handoff notu yazılır.
- Başlatma, bloklanma, devretme ve tamamlanma gibi her anlamlı geçişte `progress.md` anında güncellenir.
- Başka lane'lerdeki kartlar yalnız okunur; reassign yoksa dokunma.

## progress.md Yaşam Döngüsü (Zorunlu)

`progress.md` plan listesi değil, canlı durum kaynağıdır. Eski metni kopyalayıp dosyanın
tamamını yeniden yazma. Her durum değişikliğinden hemen önce dosyayı yeniden oku ve yalnız
kendi lane'inle kendi WP kartına dar bir patch uygula.

### Başlatırken

1. Kendi lane'inde `**Durum:** [~] Aktif — WP-N ...` ve `**Aktif WP:** WP-N` yaz.
2. Plan Kuyruğu'ndaki kendi kartını `**Durum:** [~] Uygulanıyor — <ajan>` yap.
3. Kullanıcının açıkladığı güncel sürüm/faz etiketini koru. Dosyada `V6` yazıyorsa eski
   `V4`/`V5` başlıklarını veya eski plan metnini geri getirme.

### Bitirirken

1. Testler temiz olduktan sonra Plan Kuyruğu'ndaki **kendi WP kartını tamamen kaldır**.
2. Aynı kartı `## ✅ Tamamlanan İş Paketleri` başlığının hemen altına, en yeni tamamlanan
   iş olarak ekle. Kartta en az şu alanlar bulunur:
   - `### WP-N: Ad — YYYY-AA-GG ✅`
   - `Değişen dosyalar`, `Ne yapıldı`, `Test`
3. Aynı WP hem Plan Kuyruğu'nda hem Tamamlananlar'da **asla** bulunmaz; eski/tekrarlanan
   WP kartlarını çoğaltma.
4. Kendi lane'ini `Boşta`, `Aktif WP: —` yap. `Son WP numarası` yalnız yeni WP planlanıyorsa
   artırılır; tamamlanan eski WP yüzünden geriye alınmaz.
5. Tamamlanan iş listesi uzarsa en eski özeti Geçmiş tablosuna sıkıştır; fakat başlıkları
   (`## 🧭 Plan Kuyruğu`, `## 🚀 V6 Sonrası Planlanan Yeni İş Paketleri`,
   `## ✅ Tamamlanan İş Paketleri`) silme veya yeniden adlandırma.

---

## WP Bitirme Sırası

WP'nin tüm adımları `[x]` olduğunda:

### 1. Test Et
```bash
cd app
flutter analyze --dart-define-from-file=env.json
flutter test
```
- İkisi de temiz olmalı. **Hatayla commit atma — önce düzelt.**

### 2. progress.md Güncelle
- Yukarıdaki **progress.md Yaşam Döngüsü** adımlarını uygula: plan kartını kaldır, tamamlananlar başlığı altına tek özet olarak taşı ve lane'i boşalt.
- Dokümanı stale kopyadan geri yazma; güncel sürüm/faz etiketlerini ve başka ajanların eklediği WP'leri koru.

### 3. Commit At
```bash
git add -A
git commit -m "WP-N: [kısa açıklama]"
```
- **Push yapma** (kullanıcı istemediği sürece)
- WP başına **tek commit**

---

## Karar Alma

- WP'deki adımlarda belirsizlik varsa → WP'nin "Tuzaklar" bölümüne bak
- Geri dönüşü zor karar → `progress.md`'ye "⚠️ Soru" yaz, **dur ve kullanıcıya sor**
- Küçük teknik karar (değişken adı, widget seçimi) → kendin al, devam et

---

## Sık Karşılaşılan Tuzaklar

| Tuzak | Çözüm |
|---|---|
| `fromMap`'te kaldırılmış kolon | `grep -rn "kolon_adı" app/lib` ile tüm kalıntıları bul |
| Test fixture'da eski alan | Test dosyalarını da güncelle |
| `dashboardCardFor` imza değişimi | 19 kart widget'ı + `home_screen.dart` etkilenir |
| Migration sırası | Son migration numarasını `supabase/migrations/` dizininden oku |
| Presence tablosu `group_id` | KORUNUYOR — dokunma |
| `shared_preferences` key çakışması | Mevcut key'leri `core/prefs/` altında kontrol et |
