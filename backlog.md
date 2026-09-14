# backlog.md — Açık Adaylar

> Güncelleme: **2026-09-11**. Aktif iş ve kabul kuyruğu [progress.md](progress.md).
> Önceki metin bütünüyle [tarihçede](backlog-history-2026-09-11.md) korunur.
> Buradaki adayların varlığı uygulama/deploy izni değildir; seçilen iş WP'ye dönüşür.

## Kodda doğrulanmış açık

- **Cihaz dilini yarım sabitleyen testler — KAPANDI (WP-829):** 12 dosya
  düzeltildi, `test-locale-pin` kapısı eşleşmeyi zorunlu kılıyor.
  `activeAppLocale`in iki yazarı olması ürün kusuru değil (WP-826 dersi).
- **Günlük hedefin geçmişe uygulanması — sunucuda KAPANDI (WP-828, 0141):**
  yerelde kırmızı→yeşil kanıtlı; uzak DB'ye uygulanması ayrı sahip GO'su bekliyor.
  Kalan iki sınır: (1) Dart çevrimdışı ayna `achievement_ledger_engine.dart`
  geçmişi hâlâ tek (bugünkü) hedefle hesaplıyor — sunucu otoriter olduğu için
  rozet vermez ama çevrimdışı önizleme farklı sayı gösterebilir; ölçülmeden iş
  açılmaz. (2) 0141 öncesi `goal_progress_events` satırlarında dondurulmuş hedef
  yok (null) — bu satırlar "sınır yok" sırrını yeni açamaz; bilinçli seçim.

## Ölçüm / kabul açığı — hata olduğu henüz kanıtlanmış değil

- **Beklenmeyen asenkron işlemler:** son tur `discarded_futures` için 149 aday
  kaydetti; sayı bu tur yeniden ölçülmedi ve 149 hata demek değil. Öncelik
  kullanıcı verisi yazan işlemler. Toplu `unawaited` eklemek çözüm sayılmaz.
- **WP-760 `_refreshPromotionVerdict`:** native yazımdan sonra `prefs.reload()`
  davranışını gerçekten bozulunca düşen testle ölçme borcu. Önceki teşhis ve
  deneyler [backlog tarihçesinin son bölümünde](backlog-history-2026-09-11.md).
- **`name_reset` tekrarı:** son tur tek aktif ad sıfırlama kuralının sunucuda
  bulunmadığını not etmiş; etkisi ve gerekliliği ölçülmeden yeni iş açılmaz.
- **WP-276 / WP-277 kabul uzlaşması:** hesap silmenin staging uçtan uca
  provası ile başarım/görev/grup matrisi eski kabul borçlarıdır. Yeni deploy ve
  sağlık kanıtlarıyla eşleştirilmeden kapanmış sayılmaz; aynı operasyon da
  eski kart açık diye otomatik tekrarlanmaz.
- **Eski QA maddeleri:** [canlı kabul kuyruğu](progress.md#test-için-bekleyenler).
  Arşive taşınmaları kabul edildikleri anlamına gelmez.

## Ürün / dağıtım kararı bekleyenler

- **Windows Store WP-259–262:** temiz VM/ikinci PC, Private Audience ve public
  kabul kayıtları yeniden uzlaştırılmalı. v83 Windows derlemesi başarılıdır;
  bu, Microsoft Store kabulü değildir.
- **Play production:** son kayıt alpha 83 kapalı testtir; production başvurusu
  ve güncel Console gereklilikleri ayrı doğrulanır. “AAB yolu yok” eski iddiası
  geçersizdir: release workflow'u `play` appbundle üretir.
- **WP-69 aylık rapor / WP-279:** DNS + Resend ile canlıya alma için eski karar
  borcu korunur; bu tur karara bağlanmadı.
- **WP-67 yeni grafik türleri:** eski brief yeni özellik izni sayılmaz; mevcut
  grafiklerle çakışma ve ihtiyaç önce karşılaştırılmalı.
- **Tablet yatay düzeni WP-361:** sahibin “tableti boşver” kararıyla parkta;
  kendiliğinden yeniden açılmaz.

## Yeniden yapılacak iş olmayanlar

Sınav geri sayımı (üç kayıt ve hesap senkronu), v49/v51/v54/v57 uygulama
başlıkları ve WP-766 test düzeltmesi eski açık listeden çıkarıldı. Tarihçeleri
korunuyor; bu sınıflama eksik cihaz kabulünü kapatmaz. Çoklu grup desteği için
eski “tek gruba mı odaklanmalı?” sorusu güncel ürün kararı değildir.

Ürün kapsamı ve reddedilen fikirler [Ürün Politikaları](docs/URUN-POLITIKALARI.md)
içindedir; tarihsel rakip önerileri bu kararların önüne geçmez.
