# V57 yönetici yüzeyi envanteri

> Tarih: 2026-08-01 · WP-486 ilk çıktı · Yöntem: yedi sekmenin UI, provider,
> repository, durum ve yıkıcı eylem yollarının kod denetimi. Bu turda kozmetik
> tercih uygulanmadı; aşağıda problem ile tercih açıkça ayrıldı.

## Yönetici kabuğu

Erişim `adminIsSuperAdminProvider` ile sunucuda doğrulanıyor; loading, yetkisiz ve
hata durumları birbirinden ayrılmış. Yedi sekmeli `isScrollable` TabBar dar ekranda
taşmıyor fakat sekme keşfi yatay kaydırmaya bağlı. Sekmeler ortak bir liste araç
çubuğu, arama, filtre, sayfalama veya standart retry/empty bileşeni paylaşmıyor.

## Yedi sekme

| Sekme | Veri ve eylemler | Durum kapsamı | Dar ekran / yıkıcı eylem | Karar |
|---|---|---|---|---|
| Özet | `adminDashboardSummaryProvider` → `fetchDashboardSummary`; kullanıcı, grup, oturum, açık rapor sayıları | Skeleton, genel hata, pull-to-refresh var | Sabit iki sütun ve `childAspectRatio: 1.75`; büyük yazı ölçeğinde sıkışma riski. Yıkıcı eylem yok | **Problem:** responsive grid testi yok. **Tercih:** kartlardan ilgili sekmeye geçiş/trend eklemek |
| Kullanıcılar | `adminUsersProvider` → `fetchUsers`; parola sıfırlama, askıya al/kaldır, soft-delete | Loading/error/empty/data ve pull-to-refresh var | Eylemler `Wrap`; mutasyonlar dialog + zorunlu gerekçe kullanıyor. Arama, filtre ve sayfalama yok | **Problem:** büyüyen kullanıcı listesi işletilemez. **Tercih:** kart yoğunluğu ve toplu eylem |
| Gruplar | `adminGroupsProvider` → `fetchGroups`; üyeyi at, grubu sil | Loading/error/empty/data ve refresh var | Dialog + gerekçe var; üyeyi atmak için ham user UUID giriliyor. Arama/sayfalama yok | **Problem:** UUID ile operasyon hata eğilimli; hedef kişi doğrulama/önizleme yok. **Tercih:** grup detayına drill-down |
| Raporlar | Aktif/arşiv provider'ları; tür filtresi, durum değiştirme, attachment, iç notlar ve mesaj dizisi | Loading/error/empty/data, filtre ve refresh var; WP-485 realtime/push migration'ı bekliyor | Kart eylemleri `Wrap`; attachment ve not dialogları var. Durum değişimi doğrudan menü seçimiyle uygulanıyor | **Problem:** hata tekrar-dene standardı ve status değişimi için geri alma/onay yok. **Tercih:** liste yoğunluğu |
| UGC moderasyon | Ayrı `AdminModerationRepository`; kuyruk, detay, yaptırım, karantina, itiraz | Loading/error/empty/data, retry ve refresh; alt itiraz akışı ayrıca durumlu | Yaptırım bottom-sheet + zorunlu gerekçe; quarantine dialog; itiraz kararı onaylı | **Güçlü taban. Problem:** arama/öncelik filtresi/sayfalama yok. **Tercih:** masaüstü iki panelli görünüm |
| Duyurular | `adminAnnouncementsProvider`; all/group/user hedefli oluşturma, silme | Loading/error/empty/data ve refresh var | Oluşturma dialogu dar ekranda scroll olur. **Silme tek dokunuşla ve onaysız.** Hedef ID boş kalabilir; boş başlık/mesaj sessiz no-op; controller'lar dispose edilmiyor | **Problem (P0):** yıkıcı onay ve form doğrulama eksik. **Problem (P1):** hedef önizleme yok |
| Denetim | `adminAuditLogsProvider` → `fetchAuditLogs`; salt-okunur kayıt listesi | Loading/error/empty/data ve refresh var | `createdAt.toString()` ve ham hedef ID; filtre, arama, sayfalama, kopyalama/export yok | **Problem:** gerçek olay incelemesi için zaman/aktör/hedef okunabilirliği ve filtre eksik. **Tercih:** export |

## Çapraz bulgular

1. **Standart boş/hata hali yok.** Birçok sekmede `RefreshIndicator` altında
   `Center` dönüyor; içerik scrollable olmadığı için boş/hata halinde pull-to-refresh
   güvenilir bir çıkış değildir. Bazı sekmeler retry butonu gösterirken bazıları
   yalnız genel hata metni gösteriyor.
2. **Liste ölçeği tasarlanmamış.** Kullanıcı, grup, duyuru ve audit provider'ları
   bütün koleksiyonu tek seferde getiriyor; query/search/page sözleşmesi yok.
3. **Operasyon geri bildirimi tutarsız.** Kullanıcı/grup mutasyonları başarı ve
   hata SnackBar'ı verirken duyuru silme yalnız hata gösteriyor; rapor ve moderasyon
   kendi desenlerini kullanıyor.
4. **Tarih ve kimlik sunumu tutarsız.** Raporlar yerelleştirilmiş tarih etiketi
   kullanıyor; audit ham `DateTime.toString()` ve UUID gösteriyor.
5. **Repository hata metinleri UI sözleşmesine sızıyor.** Önceki sayımda admin
   repository katmanında yoğun gömülü Türkçe literal bulundu. Kullanıcıya gösterilecek
   hata kodu/yerelleştirme ile tanı mesajı ayrılmalı.
6. **Test dağılımı dengesiz.** Moderasyon ve rapor akışları görece güçlü; dashboard,
   audit ve announcements için dar ekran, empty/error recovery ve destructive
   confirmation regresyon testleri eksik.

## Önerilen düzeltme sırası

1. **P0 — Duyuru güvenliği:** silme onayı; hedef zorunluluğu; alan bazlı form
   hatası; controller dispose; mutasyon sırasında çift gönderimi engelleme.
2. **P1 — Ortak durum bileşeni:** scrollable empty/error + görünür retry; bütün
   sekmelerde aynı başarı/hata dili.
3. **P1 — İşletilebilir listeler:** önce kullanıcılar ve audit için sunucu taraflı
   arama/filtre/sayfalama; sonra gruplar/duyurular.
4. **P1 — Audit okunabilirliği:** Europe/Istanbul tarih formatı, aktör/hedef
   ayrımı, kopyalanabilir kimlik ve eylem filtresi.
5. **P2 — Responsive profesyonelleştirme:** 320 px + büyük yazı ölçeği matrisi,
   dashboard grid adaptasyonu ve geniş ekranda navigation rail/iki panel kararı.
6. **P2 — l10n/hata sözleşmesi:** repository iç mesajlarını makine kodlarına,
   kullanıcı metnini UI l10n katmanına taşıma.

## İlk uygulama kartı önerisi

**WP-486A — Duyuru oluşturma/silme güvenlik kapısı.** Kabul: silme açık onay
olmadan çalışmaz; group/user hedefi boşken gönderilemez; başlık/mesaj hatası alanın
yanında görünür; başarı/hata görünürdür; aynı işlem çift gönderilemez; dialog
controller'ları dispose edilir; 320 px ve 1.6× text scale widget testleri geçer.

Bu sıra güvenlik ve operasyon riskine göre öneridir. Kozmetik/navigation tercihi
kodlanmadan önce ürün sahibi seçimi hâlâ gereklidir.
