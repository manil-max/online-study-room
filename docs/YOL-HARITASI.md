# Odak Kampı — Kaliteye Geçiş Yol Haritası

> ⚠️ **Bu belge [KALITE-PROGRAMI.md](./KALITE-PROGRAMI.md)'ye taşındı.** Güncel ve kanonik plan orasıdır; bu dosya arşiv/kaynak olarak kalır.
>
> Tarih: 2026-07-12 · Durum: **Onay bekliyor, kod değişikliği yok**
> Sunum (etkileşimli): https://claude.ai/code/artifact/bac7ff5d-1ba9-4306-868e-64b6fbae292d
> Teknik karşılığı: [TEKNIK-PLAN.md](./TEKNIK-PLAN.md)

## İlke değişimi

Artık amaç bir paketi bitirip "çalışıyor" demek değil; mevcut sistemin ve her
özelliğin kalitesini profesyonel seviyeye (Apple / Google / Samsung) çıkarmak.
Süre ve maliyet önemli değil; ölçüt tek: **en iyi kalite.**

### Yeni çalışma ilkeleri (her WP'ye tabi)
1. **Bitiş Tanımı (DoD)** — yazılı kabul kriterleri karşılanmadan paket kapanmaz.
2. **Ölü anahtar yok** — her düğme/ayar gerçek bir etki üretir.
3. **Cihazda test** — native işler (foreground service, widget, alarm) gerçek Android'de kanıtlanır.
4. **Referans kalite** — tasarım, kıyaslanan uygulamayla yan yana konur.
5. **Migration disiplini** — sunucu bağımlılığı canlı şema adımıyla birlikte teslim.
6. **Tek gerçek kaynak** — aynı veri ekran/widget/bildirimde aynı sayıyı gösterir.

## Kod kanıtlı durum denetimi

| # | Alan | Bulgu (kanıt) | Hedef |
|---|---|---|---|
| B1 | Tema motoru | 10 palet `app_theme.dart`'ta aynı `_bg`/`_card` zeminini paylaşıyor; yalnız `primary`/`accent` değişiyor | Zemin+yüzey+gradyan+şekil+tipografi+ışık değiştiren gerçek motor + mood temalar |
| B2 | Saat sekmesi | `clock_screen.dart`: büyük saat metni + eski `StudyTimerCard` | Saat/Dünya Saati/Alarm/Kronometre/Zamanlayıcı/Odak — bağımsız saat uygulaması |
| B3 | Başarım | İki sistem çakışıyor; `achievement_engine.dart`'ta `currentStreak/perfectWeeks=0`, grup günleri boş | Tek motor, doğru hesap, XP→taç her yerde |
| B4 | Widget/senkron | `study_providers.dart` yalnız `AndroidWidgetSnapshot.timer` push ediyor; stats/leaderboard widget'ları placeholder; foreground service yok | Foreground service + canlı chronometer; tüm widget'lar gerçek veriyle |
| B5 | Bilgi mimarisi | `settings_screen.dart`: "Başarı Yolculuğum" Ayarlar>Hesap içinde gömülü | Profil: Çalışma kayıtlarım · Başarımlar · Ayarlar (üç eş giriş) |
| B6 | Küçük düzenler | Stats sıralama en altta; gruplar sırası hedef→ateş→trend | Sıralamayı trendin üstüne; ateş en üste; animasyon kısalt |

## Sürümlere bölünmüş yol haritası

### v8 — Hızlı kazanımlar & sağlamlık
- **WP-A** İstatistik grup düzeni: sıralamayı "grup günlük trendi"nin üstüne al. *(istek 3)*
- **WP-B** Gruplar sekmesi: kamp ateşi en üste; animasyon kısalt; sıra ateş→hedef→sıralama. *(istek 4)*
- **WP-C** Senkron denetimi: stats/leaderboard widget'larını gerçek veriyle besle; geç güncelleme bugları. *(istek 2)*
- **WP-D** Profil IA: başarımları ayarlardan çıkar → Çalışma kayıtlarım · Başarımlar · Ayarlar. *(istek 7, 8)*

### v9 — Her yerde canlı sayaç (native temel)
- **WP-E** Foreground service + canlı bildirim: yalnız HH:MM:SS + Durdur/Başlat, app kapalıyken çalışır. *(istek 1)*
- **WP-F** Ana ekran widget paritesi: widget'tan başlat/durdur, app açmadan; bildirimle aynı canlı saat. *(istek 1, 2)*

### v10 — Saat (dünya devleriyle yarışan sekme)
- **WP-G1** Saat çekirdeği: Saat/Dünya Saati/Kronometre/Zamanlayıcı, akıcı animasyon.
- **WP-G2** Alarm motoru: sesli, tam ekran çalar, tekrar/erteleme; cihazda güvenilir.
- **WP-G3** Widget & bildirim uyumu: ana ekran kalitesiyle aynı tasarım sistemi. *(istek 5)*

### v11 — Tema Motoru
- **WP-H1** Motor + token refactor: zemin/yüzey/gradyan/şekil/ışık/tipografiyi paletten ayır.
- **WP-H2** İlk tema paketi: karakterli mood temaları.
- **WP-H3** İleri özelleştirme: duvar kağıdından dinamik renk, indirilebilir paketler (opsiyonel). *(istek 6)*

### v12 — Başarım & Sosyal Profil 2.0
- **WP-I** Birleşik kademeli başarım: tek motor, doğru hesap, XP→taç her yerde.
- **WP-J** Herkese açık profil: seçilebilir rozetler, istatistikler, seri alevi; gruptan tıkla→profil.
- **WP-K** Grup/İstatistik zenginleştirme + yeni bildirim türleri. *(istek 7, 8)*

## Açık kararlar (kullanıcı)
1. Hangi alandan başlayalım? (öneri: v8 hızlı kazanımlar + senkron)
2. Native foreground service onayı? (item 1/2/5 için şart)
3. Tema motoru derinliği? (tam motor / mood paketleri / duvar kağıdı dinamik / indirilebilir)
4. Saat kapsamı? (Dünya Saati, Alarm, Kronometre, Zamanlayıcı + opsiyonel Uyku/ekran koruyucu)

## Notlar
- Bildirim Merkezi sunucu özellikleri için `0020–0023` migration'ları canlı Supabase'e uygulanmalı.
- Aynı prompt Codex'e de verildi (paralel plan); çıktılar hizalanacak.
