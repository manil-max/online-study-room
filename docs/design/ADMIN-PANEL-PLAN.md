# Yönetim Paneli — envanter, kusur ve sıfırdan tasarım planı (WP-691)

> **Durum:** karar belgesi + envanter. **FAZ 1 = plan; bu turda kod yazılmadı.**
> **Tetikleyen:** sahip paneli reddetti:
> *"admin kısmı sıkıntılı, ne adam akıllı görüntüleyebiliyorum ne de o ekranda
> şikâyetleri sorunları raporları cevaplayıp admin işlemleri yapabiliyorum."*
> *"mevcut özelliklerinin listesini çıkarıp, gerekli olan şeylerin listesini
> çıkarılıp, en mantıklı en kullanışlı en kapsamlı bir planı baştan tasarlayın.
> kökten değişiklik istiyorum."*
> **Sayılar:** `docs/design/DESKTOP-UI-SPEC.md`'den alınır, yeniden türetilmez.
> **Kanıt kuralı:** bu belgedeki her envanter maddesi `dosya:satır` ya da komut
> çıktısı taşır (`.agents/skills/hunter/SKILL.md §0`). Ölçemediklerim §8'de.

---

## 0. Tek cümlelik teşhis

**Sunucu tarafı hazır; ekran onu atıyor.**

Bu bir "arayüz çirkin" kusuru değil. Ölçüm şunu gösteriyor: sunucu şikâyetin
içeriğini, ekini, bağlam mesajlarını, hedefin ceza geçmişini ve yaptırımı geri
alma yolunu **zaten döndürüyor**; istemci modeli bu alanların bir kısmını hiç
ayrıştırmıyor, bir kısmını ayrıştırıp hiç çizmiyor. Sahibin "neyi şikâyet
ettiğini anlayamıyorum" cümlesinin karşılığı bir düzen hatası değil, **veri
kaybı**dır (§2.1).

Sahibin hipotezi — *"teknik kısım hallolmuştur belki de ama arayüz çok kötü"* —
**DOĞRULANDI.** Kanıt §7'de.

---

## 1. MEVCUT ENVANTER (ölçüldü)

Panele tek giriş: **Ayarlar → Yönetim** (`app/lib/features/profile/settings_screen.dart:338-349`).
`grep -rn "AdminScreen" app/lib/` → tanımı dışında **tek** çağrı yeri budur.
Kısayol yok, masaüstü kabuğunda sekmesi yok.

Kabuk: `app/lib/features/admin/admin_screen.dart:40-81` — `DefaultTabController(length: 7)`
+ `TabBar(isScrollable: true)` + `TabBarView`. Toplam 9 dosya, 2787 satır.

### 1.1 Sekme sekme

| # | sekme | dosya | okuma | yazma eylemleri |
|---|---|---|---|---|
| 1 | Özet | `tabs/admin_dashboard_tab.dart` (139) | `admin_dashboard_summary` | **yok** (salt okuma, döşemeler tıklanamaz) |
| 2 | Kullanıcılar | `tabs/admin_users_tab.dart` (374) | edge fn `admin-user-actions{list_users}` | şifre sıfırla · askıya al (5 basamak) · askıyı kaldır · soft delete |
| 3 | Gruplar | `tabs/admin_groups_tab.dart` (194) | `from('groups').select()` | üye at (elle UUID) · grubu sil |
| 4 | Raporlar | `tabs/admin_reports_tab.dart` (609) | `admin_feedback_tickets` | durum değiştir · yanıtla · iç not ekle · arşivle · ek görüntüle |
| 5 | **UGC** | `tabs/admin_moderation_tab.dart` (578) + `widgets/moderation_queue_card.dart` (365) | `admin_ugc_report_groups` · `admin_ugc_report_detail` · `admin_moderation_appeals` | durum · yaptırım (9 basamak) · karantina · id kopyala · itiraz kararı |
| 6 | Duyurular | `tabs/admin_announcements_tab.dart` (361) | `from('announcements')` | oluştur · sil |
| 7 | Denetim | `tabs/admin_audit_log_tab.dart` (57) | `admin_audit_logs` (limit 100) | **yok** |

🔴 5. sekmenin adı koda gömülü ham `'UGC'` dizesidir
(`admin_screen.dart:56`) — yerelleştirilmemiş, kısaltma, kullanıcıya hiçbir şey
söylemiyor. Öbür altı sekme `l10n`'dan gelir. Sahibin gördüğü sekme adı
"UGC"dir; şikâyetlerin durduğu yer orasıdır.

### 1.2 Ne yaptığı belli olmayan düğmeler (sahibin 3. cümlesi)

> *"her şeye göremediğin bazı tuş gibi bir şeyler var, basıyon, tuş neyi ne
> olduğu belli değil."*

`grep -rn "IconButton\|PopupMenuButton\|FloatingActionButton" app/lib/features/admin/`
çıktısı + tek tek okuma:

| yer | görünen şey | gerçekte ne yapıyor | kusur |
|---|---|---|---|
| `admin_reports_tab.dart:57-65` | yalnız `inventory_2` ikonu | arşiv/aktif görünümü değiştirir | **`tooltip` yok, etiket yok** |
| `admin_reports_tab.dart:89-97` | aynı ikon (ikinci kopya) | aynı iş | **`tooltip` yok** |
| `admin_reports_tab.dart:232-258` | çip, üstünde **"Tamamlandı"** | biletle arşivler / arşivden çıkarır | **etiket yalan**: yazı "Tamamlandı", iş "Arşivle"; aynı çip ters yönde de çalışır ve yazısı değişmez |
| `moderation_queue_card.dart:284` | üç nokta | Yaptırım Uygula · Karantina · Kopyala | `tooltip` yok → varsayılan "Menüyü göster"; **ban yolu burada saklı** |
| `moderation_queue_card.dart:164` | renkli çip ("Açık") | durum menüsü açar | menü olduğunu gösteren ok/işaret yok |
| `admin_announcements_tab.dart:18-26` | `+` FAB | duyuru oluşturma diyaloğu | `tooltip` yok (FAB'ın varsayılanı yoktur) |
| `admin_reports_tab.dart:276` | üç nokta | bilet durumunu değiştirir | tooltip **var** (`adminDurumuDegistir`) — doğru örnek |

Yani sahip haklı ve sayı ölçülü: **6 etiketsiz/yanlış etiketli kontrol**,
bunlardan biri (arşiv çipi) doğrudan yanlış şey yazıyor.

### 1.3 Yarım eylemler — UI var, çağrı yok / çağrı var, UI yok

Deponun kayıtlı hata sınıfı: *"bitmiş backend + bağlanmamış UI"*. Panelde
**üç** örneği var.

**(a) Yaptırımı geri alma — sunucu hazır, düğme yok.**
```
$ grep -rn "revokeSanction" app/lib/ app/test/
app/lib/data/repositories/admin_moderation_repository.dart:53
app/lib/data/repositories/in_memory/in_memory_admin_moderation_repository.dart:159
app/lib/data/repositories/supabase/supabase_admin_moderation_repository.dart:226
app/test/features/admin/moderation_enforcement_wp441_test.dart:201
app/test/features/admin/moderation_enforcement_wp441_test.dart:218
```
`app/lib/features/**` içinde **sıfır** çağrı yeri. Üç repository uygulaması,
edge function yolu (`'action': 'moderation_revoke'`) ve **yeşil bir test**
(`geri alınan yaptırım etkisini yitirir`) var; **panelde bir yanlış banı geri
alacak düğme yok.** Test yeşil, özellik yok.

**(b) Yaptırım geçmişi — sağlayıcı var, hiç izlenmiyor.**
`moderationSanctionsProvider` (`app/lib/data/providers/admin_moderation_providers.dart:41-49`)
yalnız iki yerde geçiyor ve ikisi de `ref.invalidate`:
`admin_moderation_tab.dart:168`, `admin_users_tab.dart:190`. **Hiçbir yerde
`ref.watch` edilmiyor** → hedefin ceza geçmişi hiçbir ekranda çizilmiyor.
Sağlayıcının kendi yorumu (`admin_moderation_providers.dart:37-39`) şunu iddia
ediyor: *"Kart hangi basamağın şu an yürürlükte olduğunu buradan okur"* —
**bu cümle yalandır**, hiçbir kart okumuyor. Ayrıca dinleyicisiz `family`
sağlayıcıyı `invalidate` etmek Riverpod 3'te işlemsizdir.

**(c) Sunucuda olup istemcide hiç adı geçmeyen RPC'ler.**
Migration'lardaki `admin_*` fonksiyon adları tek tek `app/lib/` içinde arandı:

| RPC | `app/lib/` içinde | sonuç |
|---|---|---|
| `admin_reporter_abuse_score` | **yok** | kötüye kullanan şikâyetçiyi ayırt etme yolu erişilemez |
| `admin_begin_moderation_sanction` | yok (edge fn içinden çağrılıyor) | beklenen, kusur değil |
| `admin_finish_moderation_sanction` | yok (edge fn içinden) | beklenen, kusur değil |
| `admin_revoke_moderation_sanction` | yok (edge fn içinden) | sunucu tarafı hazır → (a)'ya bak |
| `get_account_purge_health` · `claim_account_deletion_jobs` · `record_account_purge_outcome` | **yok** | hesap silme kuyruğunun sağlığı panelde **hiç görünmüyor** |

**(d) UI eylemi var ama RPC'si yok:** ölçümde böyle bir madde **çıkmadı.**
Panelin bastığı her düğmenin sunucu karşılığı var. Kusur ters yönde.

---

## 2. İŞ AKIŞI KUSURLARI — sahibin üç cümlesinin koddaki karşılığı

### 2.1 *"neyi şikâyet ettiğini tam anlayamıyorum"*

**Kuyruk kartında içerik yok.** `ModerationQueueCard.build`
(`moderation_queue_card.dart:44-104`) yalnız şunları çizer:
hedef türü + gerekçe etiketleri (`:106-119`), şikâyet edilen kimliği (`:77-80`),
şikâyet eden kimliği (`:82-88`), bekleme süresi + rapor sayısı (`:133-138`),
önem/SLA/karantina rozetleri (`:215-263`). **Şikâyet edilen metin, mesaj,
profil ya da grup adı kartın hiçbir yerinde geçmez.** Liste tamamen kimlik +
sayaçtan ibarettir — sahibin tarifi birebir budur.

**İçerik alt sayfada var; ama sunucunun gönderdiğinin yarısı yolda kayboluyor.**
Sunucu (`supabase/migrations/0097_moderation_report_detail.sql:73-83`) şunu
döndürür:

```
report:  id · target_type · target_id · reason · details · content_snapshot
         · attachment_path · status · created_at
context: ±11 mesaj (body, display_name, avatar_url, created_at, is_target)
history: report_count · sanctions[](action, reason, created_at)
```

İstemci modeli `ModerationCaseDetail`
(`app/lib/data/repositories/admin_moderation_repository.dart:86-100`) yalnız
**5 alan** taşır: `snapshot`, `details`, `contextMessages`, `reportCount`,
`sanctionReasons`. Ayrıştırma yeri `supabase_admin_moderation_repository.dart:177-194`.
Düşen alanlar:

| sunucunun gönderdiği | istemcide | sonuç |
|---|---|---|
| `report.attachment_path` | **ayrıştırılmıyor** | 🔴 kullanıcının şikâyetine eklediği **ekran görüntüsü admin'e hiç gösterilmiyor** |
| `report.reason` | ayrıştırılmıyor | detay sayfasında gerekçe yok (yalnız kartta toplu) |
| `report.created_at` / `status` | ayrıştırılmıyor | "ne zaman geldi, hangi durumda" detayda yok |
| `context[].created_at` / `avatar_url` / `user_id` | ayrıştırılmıyor | bağlam mesajları zamansız, tıklanamaz |
| `history.sanctions[].action` / `.created_at` | **atılıyor** (`:190-193` yalnız `reason` alır) | "bu kişiye daha önce ne yapıldı" cevapsız |

Ek kanıtı: `supabase/migrations/0096_report_attachments.sql` private
`report_attachments` bucket'ını **ve admin SELECT politikasını** kuruyor;
`ugc_reports.attachment_path` kolonu var. `grep -rn "attachmentPath" app/lib/`
çıktısındaki tek yönetici okuyucu `admin_reports_tab.dart:191` — o **destek
bileti** ekidir, başka bucket. Yani: *kullanıcı şikâyetine kanıt fotoğrafı
yüklüyor, sunucu admin'e vermeye hazır, panel istemiyor.*

**Detay sayfasının kendisi de ham.** `_ModerationDetailSheet`
(`admin_moderation_tab.dart:240-283`): başlıksız `SelectableText(snapshot)`,
başlıksız `SelectableText(details)`, etiketsiz `ListTile` listesi, sonra
`Text('Raporlar: 3')` ve gerekçelerin çıplak `Text` dökümü (`:275-276`).
Hangi yazının ne olduğunu söyleyen tek bir başlık yok.

**İtiraz kartı da aynı hastalıkta.** `ModerationAppeal` modeli
`sanctionAction`, `appellantId`, `createdAt`, `decisionNote` taşır
(`app/lib/data/models/moderation_appeal.dart:70-84`). `_AppealCard`
(`admin_moderation_tab.dart:501-550`) **yalnız** `sanctionReason` ve
`statement` çizer. Yani admin, **hangi cezaya** itiraz edildiğini görmeden
"Onayla / Bozup Kaldır" düğmelerine basıyor.

**Denetim sekmesi de aynı.** `AdminAuditLog` modeli `adminId` ve
`targetUserEmail` alanlarını ayrıştırıyor
(`app/lib/data/models/admin_audit_log.dart:18,21`), sekme
(`admin_audit_log_tab.dart:36-47`) **ikisini de çizmiyor**: ham
`targetUserId` UUID'si + `action` + `reason` + `createdAt.toString()`.
Kaydın "kim yaptı" sütunu ekranda yok.

### 2.2 *"onay verdim, bu adam nasıl başlayacağımı bilmiyorum"*

Bir şikâyeti bugün karara bağlama yolu, adım adım ölçüldü:

| # | eylem | yer |
|---|---|---|
| 1 | Ayarlar → Yönetim | `settings_screen.dart:347` |
| 2 | 5. sekme "UGC"ye geç | `admin_screen.dart:55-58` |
| 3 | Kartın **gövdesine** dokun (görünür ipucu yok) | `moderation_queue_card.dart:46` `InkWell(onTap: onOpenDetail)` |
| 4 | Alt sayfada içeriği oku | `admin_moderation_tab.dart:221-227` |
| 5 | **Alt sayfayı kapat** — içinde tek bir karar düğmesi yok | `admin_moderation_tab.dart:240-283` |
| 6 | Üç noktaya bas → "Yaptırım Uygula" | `moderation_queue_card.dart:284-321` |
| 7 | İkinci alt sayfa: basamak seç + gerekçe yaz → Onayla | `admin_moderation_tab.dart:291-391` |
| 8 | Durum çipine bas → "Çözüldü" | `moderation_queue_card.dart:164-199` |

🔴 **Kök neden: kanıtın göründüğü yüzey ile kararın verildiği yüzey aynı anda
ekranda değil.** 4. adımda içeriği görürsün ama hiçbir şey yapamazsın;
6-8. adımlarda karar verirsin ama içeriği artık görmüyorsun. Sahibin
"nasıl başlayacağımı bilmiyorum"u tam olarak bu.

Ayrıca:
- **İki ayrı gerekçe alanı** (5-7. adımda yaptırım gerekçesi, karantinada ayrı
  `askReason` diyaloğu `admin_moderation_tab.dart:212-219`) — aynı vaka için
  aynı şeyi iki kez yazdırıyor.
- **Karar sonrası geri bildirim = tek `SnackBar`** (`:131-133`), yalnız yeni
  durumun adı. Vaka kuyruktan düşmez, "sırada ne var" yoktur, **geri al yoktur.**
- 3. adımda kart `reportIds.isEmpty` ise `onOpenDetail` **null**'dır
  (`admin_moderation_tab.dart:80-82`): kart hiç açılmaz ve **neden açılmadığını
  söylemez** — sessiz ölü dokunuş.

### 2.3 *"banlama farklı yere gidiyorum herhalde"*

**Sahip haklı: ban için üç ayrı yer, iki farklı basamak listesi var.**

| yol | nereden | basamaklar | hangi boru hattı |
|---|---|---|---|
| A | UGC sekmesi → kart → **üç nokta** → "Yaptırım Uygula" | **9**: `ModerationAction.values` (`admin_moderation_tab.dart:336-342`) — noAction, warn, nameReset, mute24h, suspend24h/7d/14d/30d, banPermanent | `applySanction` → edge fn `admin-user-actions{moderation_sanction}` |
| B | Kullanıcılar sekmesi → kart → "Askıya Al" | **5**: `kAdminSuspensionLadder` (`admin_users_tab.dart:19-25`) — suspend24h/7d/14d/30d, banPermanent | aynı `applySanction` |
| C | Kullanıcılar sekmesi → "Sil" | — | `performUserAction('soft_delete_user')` → **başka** edge fn yolu (`supabase_admin_repository.dart:298-320`) |

🔴 **Vakadan kişiye köprü yok.** UGC kartındaki şikâyet edilen kişinin
Kullanıcılar sekmesindeki kaydına gidecek hiçbir bağlantı yok; tek yardım
üç noktadaki "Kopyala" (`moderation_queue_card.dart:292-301`) — UUID'yi panoya
alıyorsun, sekme değiştiriyorsun, listede **arama kutusu olmadığı için**
(`admin_users_tab.dart:44-56`: filtre yok, arama yok, sayfalama yok) gözle
arıyorsun.

Aynı kusurun Gruplar'daki hâli daha sert: "Üye At" seni **elle UUID yazdıran
bir metin kutusuna** sokuyor (`admin_groups_tab.dart:68-77`,
`adminHedefKullaniciIdZorunlu`) — grubun üye listesini gösteren hiçbir ekran
yok.

### 2.4 Bunlara ek, ölçümde çıkan üç kusur daha

- 🔴 **Filtre çıkmazı.** Raporlar sekmesinde tür çipleri liste **boş
  olmadığında** çiziliyor (`admin_reports_tab.dart:76-100`, `index == 0` dalı);
  boş durumda yalnız arşiv ikonu var (`:51-68`). Bir türe filtreleyip sonuç
  boş gelirse **filtreyi kaldıracak kontrol ekranda yoktur** — sekmeden çıkıp
  dönmek gerekir.
- **Sabit 2 sütun.** `admin_dashboard_tab.dart:53-59` `GridView.count(crossAxisCount: 2)`.
  Bu, `DESKTOP-UI-SPEC.md §3 A2`'de adı konmuş kusurun aynısıdır
  (spec'te `personal_stats_view.dart` için yazılmıştı). Döşeme tavanı yok.
- **Panelde masaüstü kolu hiç yok.**
  `grep -rn "Desktop\|isDesktop\|LayoutBuilder" app/lib/features/admin/` → iki
  sonuç, ikisi de tesadüf (`viewInsets`, çip `maxWidth: 148`). Yani Windows'ta
  panel 2000 px'e gerilmiş bir telefon `TabBar`'ıdır; `DESKTOP-UI-SPEC.md`'nin
  hiçbir kuralı buraya uygulanmamıştır.
- Küçük sızıntı: `admin_groups_tab.dart:56-57`'deki iki `TextEditingController`
  hiç `dispose` edilmiyor.

---

## 3. İHTİYAÇ LİSTESİ — bu üründe neyin olması gerekir

Ürünün kendi özelliklerinden türetildi (şikâyet, itiraz, yaptırım, destek
bileti, grup, duyuru, hesap silme, denetim). "İş" sütunu kaba tahmindir.

| # | ihtiyaç | neden | bugün | iş |
|---|---|---|---|---|
| 1 | **Şikâyeti içeriğiyle görmek** (metin + ek + bağlam + zaman) | Karar veremezsin | yarım: metin var, **ek yok**, alanlar düşüyor (§2.1) | orta |
| 2 | **Kanıtın yanında karar vermek** | 8 adım → 1 ekran | yok (§2.2) | büyük |
| 3 | **Hedefin dosyası**: ceza geçmişi, aktif kısıt, önceki şikâyetler | Aynı kişiye ikinci kez ceza yazmamak | sağlayıcı var, **çizilmiyor** (§1.3b) | orta |
| 4 | **Yaptırımı geri alma** | Yanlış ban geri dönebilmeli | sunucu hazır, **düğme yok** (§1.3a) | küçük |
| 5 | **Tek yaptırım yüzeyi** | Bugün 3 yer, 2 liste (§2.3) | yok | orta |
| 6 | **İtirazı, itiraz edilen cezayla birlikte görmek** | Kör onay veriliyor | `sanctionAction` çizilmiyor (§2.1) | küçük |
| 7 | **Kişi arama** (e-posta/ad/UUID) | Vakadan kişiye geçiş yolu | yok (`admin_users_tab.dart:44-56`) | küçük |
| 8 | **Grup üye listesi** | "Üye At" elle UUID istiyor | yok (§2.3) | orta |
| 9 | **Destek bileti kutusu**: yanıtlanmamış olan üstte | Sahip "cevaplayamıyorum" diyor | yanıt akışı **var** ve çalışıyor; sıralama/okunmamış işareti yok | küçük |
| 10 | **Denetim kaydında "kim yaptı"** | Hesap verebilirlik | alan var, çizilmiyor (§2.1) | küçük |
| 11 | **Hesap silme kuyruğu sağlığı** | Yasal yükümlülük; işlerse sessiz, bozulursa sessiz | `get_account_purge_health` var, **panelde yok** (§1.3c) | orta |
| 12 | **Kötüye kullanan şikâyetçi** | Şikâyet silahı olabiliyor | `admin_reporter_abuse_score` var, **çağrılmıyor** | küçük |
| 13 | **Duyuru** | Var ve çalışıyor | var | — |
| 14 | Yönetici rol yönetimi (`app_admins`) | — | yok, elle SQL | **kapsam dışı** — tek yöneticili ürün |

### Korunacaklar (atılmayacak)

Bunlar ölçülüp doğru bulundu; yeniden yazılmaz, taşınır:

- Bütün **repository + RPC katmanı** (`admin_repository.dart`,
  `admin_moderation_repository.dart` ve Supabase uygulamaları). Sözleşme
  testleri var (`app/test/data/supabase_wire_admin_test.dart`).
- **Yaptırım basamağı sözleşmesi** ve idempotency anahtarı (WP-441/625);
  `app/test/features/admin/moderation_enforcement_wp441_test.dart` 20 iddia.
- **Gerekçe zorunluluğu** — boş gerekçe sunucuya hiç gitmiyor
  (`admin_moderation_tab.dart:212-219`, `admin_users_tab.dart:88-95`).
- **Çıkar çatışması kapısı** — yönetici kendi yaptırımının itirazına karar
  veremiyor (`admin_moderation_tab.dart:521-528`).
- **Destek bileti yazışması** (`showFeedbackTicketConversation`) + iç notlar +
  ek görüntüleyici — çalışıyor.
- **Duyuru silmede açık onay** (`admin_announcements_tab.dart:69-87`) ve testi.
- **Karantina** — geri alınabilir, gerekçeli.
- Kart yüksekliği sıçramama kabulü (`moderation_queue_card.dart:9-15`).

---

## 4. TASARIM — sıfırdan

### 4.1 Ana kavram: panel bir **iş kuyruğudur**

Sahip panele *izlemeye* gelmiyor (özet döşemeleri tıklanamaz ve kimse
bakmıyor); *aramaya* da gelmiyor. **Bekleyen işi bitirmeye** geliyor:
şikâyet, itiraz, destek bileti. Öyleyse panelin ana ekranı **tek bir birleşik
kuyruk**tur; kişi/grup arama bu kuyruğun **yardımcısıdır**, kardeşi değil.

Bu, yedi sekmeyi **üç yüzeye** indirir:

| yüzey | içindekiler | eski karşılığı |
|---|---|---|
| **Kuyruk** (varsayılan) | şikâyet vakaları · itirazlar · destek biletleri — tek liste, tür filtresi ile | sekme 4 + 5 |
| **Kişiler & Gruplar** | arama kutusu, kişi dosyası, grup dosyası (üye listesi dahil) | sekme 2 + 3 |
| **Kayıt & Yayın** | denetim kaydı · duyurular · sistem sağlığı (silme kuyruğu, özet sayıları) | sekme 1 + 6 + 7 |

🔴 Sahip *"iki üç tane butonla işlerini değiştirip arayüzlü bir tane sekme
izleyeceksen bu işi yapmasın"* dedi. Bu yüzden **sekme sayısını düşürmek tek
başına teslim değildir**; teslimin özü §4.2'deki **tek ekranda karar**
akışıdır. Sekme birleşmesi onun sonucudur, sebebi değil.

### 4.2 Şikâyet inceleme akışı — **master–detay, üç bölmeli**

Arketip: `DESKTOP-UI-SPEC.md §3 A1`. Karar gerekçesi: kanıt ile karar **aynı
anda** ekranda olmak zorunda (§2.2 kök nedeni). Tam ekran inceleme bunu
sağlamaz — kuyruğa dönmek gerekir, "sırada ne var" kaybolur.

```
┌─ 280 ──────┬─ detay (≤760) ─────────────┬─ dosya (≤320) ─┐
│ KUYRUK     │  ŞİKÂYET EDİLEN İÇERİK     │  HEDEF DOSYASI │
│ ▸ vaka     │  ─ metin / mesaj (blok)    │  ad · avatar   │
│ ▸ vaka  ●  │  ─ EK GÖRSEL (§2.1 (a))    │  aktif kısıt   │
│ ▸ itiraz   │  ─ ±5 bağlam mesajı        │  ceza geçmişi  │
│ ▸ bilet    │  ─ şikâyet edenin yazdığı  │  önceki şikâyet│
│            │    açıklama (`details`)    │  şikâyetçi     │
│            │  ─ gerekçe · zaman · sayı  │    güven skoru │
│ [filtre]   │  ══ KARAR ŞERİDİ (sabit) ══│                │
└────────────┴────────────────────────────┴────────────────┘
```

- **Karar şeridi detay bölmesinin altına sabitlenir** — kaydırmayla kaybolmaz.
  (`Scaffold.bottomSheet` **kullanılmaz** — hafızadaki tuzak; `Column` +
  `Expanded` ile kurulur.)
- Karar şeridi: `[Gerekçesiz kapat] [Uyar] [Kısıtla ▾] [Karantina] [Çözüldü]`
  — **tek gerekçe alanı**, şeridin içinde, hepsi için ortak.
- Karardan sonra: satır kuyruktan düşer, **imleç kendiliğinden sıradaki vakaya
  geçer**, üstte 10 sn "Geri al" şeridi belirir. Sahibin
  *"nasıl başlayacağımı bilmiyorum"*unun cevabı bu iki davranıştır.
- Kart artık gövde `InkWell`'i değil, **seçilebilir liste satırı**dır
  (`hoverColor` + `focusColor`, `DESKTOP-UI-SPEC.md §4`).

### 4.3 Her eylem için sözleşme

| eylem | nerede | yazan | basınca | geri alınır mı | teyit |
|---|---|---|---|---|---|
| Durumu değiştir | karar şeridi, birincil | "Çözüldü" / "Reddet" | vaka kapanır, sıradakine geçer | ✅ 10 sn şerit + kalıcı çip | hayır |
| Uyar | karar şeridi | "Uyar" | `warn` yaptırımı | ✅ geri al | hayır |
| Kısıtla | karar şeridi, `▾` menü | "Kısıtla · 24 saat / 7 gün / 14 / 30 / **Kalıcı yasak**" | ilgili basamak | ✅ `revokeSanction` | 🔴 **evet**, süre + hedef adı yazılı |
| Karantina | karar şeridi | "İçeriği gizle" | üçüncü kişilere kapanır, silinmez | ✅ aynı düğme | hayır |
| İtirazı onayla / boz | itiraz detayı | "Cezayı sürdür" / "Cezayı kaldır" | — | "kaldır" ✅, "sürdür" 🔴 kalıcı | 🔴 **evet** ("sürdür" için) |
| Grubu sil | grup dosyası | "Grubu sil" | — | ❌ | 🔴 **evet**, grup adı **yazdırılır** |
| Hesabı sil | kişi dosyası | "Hesabı sil (soft)" | — | ❌ | 🔴 **evet**, e-posta yazdırılır |
| Şifre sıfırla | kişi dosyası | "Şifre sıfırlama e-postası gönder" | e-posta gider | ❌ (zararsız) | hayır |
| Duyuru sil | Kayıt & Yayın | "Sil" | — | ❌ | 🔴 evet (**bugün de var**, korunur) |
| Arşivle | bilet detayı | 🔴 **"Arşivle" / "Arşivden çıkar"** — "Tamamlandı" değil | listeden çıkar | ✅ | hayır |

### 4.4 🔴 Tehlikeli eylem kuralı (bağlayıcı)

1. **İki kademe.** Geri alınamayan her eylem (silme, kalıcı yasak, itirazı
   kalıcı reddetme) **hedefin adını/e-postasını yazdıran** bir diyalog ister.
   Tek dokunuşla yıkım yok.
2. **Geri alınabilen hiçbir eylem teyit istemez** — bunun yerine 10 saniyelik
   "Geri al" şeridi. Teyit enflasyonu teyidi öldürür.
3. **Gerekçe her zaman zorunlu, ama bir kez sorulur.** Bugünkü iki ayrı gerekçe
   alanı (§2.2) tek alana iner.
4. **Geri alma yolu her zaman görünür olmalı.** Yaptırım uygulanan kişinin
   dosyasında aktif kısıt satırının yanında kalıcı bir **"Kısıtı kaldır"**
   düğmesi durur (`revokeSanction`, §1.3a). Şerit kaybolduktan sonra da yol
   açık kalır.
5. **Kalıcı yasak ayrı görünür.** Süreli basamaklarla aynı menüde ama ayırıcı
   altında, `error` renginde, ayrı yazılı teyitle.
6. **Yaptırım uygulanan kişiye ne söylendiği ekranda yazar.** Yönetici cezayı
   verirken kullanıcının göreceği metni görür.

### 4.5 Masaüstü ve telefon düzeni (spec merdiveni — sayı üretilmez)

| genişlik | Kuyruk | Kişiler & Gruplar | Kayıt & Yayın |
|---|---|---|---|
| `minimal` <640 | tek sütun; satıra dokun → tam ekran detay | liste → tam ekran dosya | tek sütun |
| `compact` 640–1007 | aynı + daraltılmış rail (52) | aynı | 2 sütun döşeme |
| `expanded` 1008–1199 | aynı, açık rail (248) | aynı | 4 sütun döşeme |
| `large` 1200–1599 | **2 bölme**: 280 kuyruk + ≤760 detay | 280 liste + ≤760 dosya | 4 döşeme + 2 grafik |
| `xlarge` ≥1600 | **3 bölme**: 280 + ≤760 + ≤320 hedef dosyası | aynı + ilişkili vakalar sütunu | 6 döşeme |

Diğer ölçüler doğrudan spec'ten: bölme aralığı **16**, liste satırı min **40**,
ızgara oluğu **24**, ızgara tavanı **1440**, döşeme tavanı **320**, form sütunu
**760**, düz metin **600**, kart yarıçapı **8/6/4**, sayfa kenarı **24/20/12**,
birincil düğme **40**, imleç hedefi tabanı **24**, ikon **20** (liste ikonu 32),
etiket↔kontrol **12**, düğmeler arası **8**.

Sekme yerine **`NavigationRail`** kullanılır (üç yüzey, `Ctrl+1..3`);
`isScrollable: true` yatay `TabBar` (`admin_screen.dart:45`) düşer — 7 sekmenin
masaüstünde kaydırılması sahibin "parça parça" şikâyetinin bir parçası.

**Telefon:** üç yüzey alt gezinme çubuğu; kuyruk satırına dokunma tam ekran
detay açar, karar şeridi altta sabit kalır (aynı bileşen, tek bölme).

### 4.6 Kesin kurallar

- Bugün masaüstünde görünen **hiçbir veri kaybolmaz**; §2.1'de düşen alanlar
  **eklenir**.
- Veri katmanı, RPC adları, edge function sözleşmeleri **ellenmez**
  (`DESKTOP-UI-SPEC.md §7` ile aynı ilke).
- Yeni RPC yazılmaz. Gereken her şey sunucuda var (§7).
- Renk/tema token'ları ellenmez (uyarı rozeti dersi yürürlükte).
- Yalnız-ikon **her** düğmede `Tooltip` zorunlu — sözleşme testiyle sabitlenir.

---

## 5. FAZLAMA

Sıra bağlayıcıdır: **WP-A önce**, çünkü B/C/D onun çizdiği bölme iskeletine
oturur. B ve C, A bittikten sonra **paralel** verilebilir.

### WP-A — Kabuk + üç yüzey + masaüstü bölmeleri
- **SAHİP:** `app/lib/features/admin/admin_screen.dart`,
  `app/lib/features/admin/shell/**` (yeni),
  `app/test/features/admin/admin_shell_layout_test.dart` (yeni)
- **Kabul (önce kırmızı):**
  1. 1280 px'te `AdminScreen` monte edilir → `DesktopMasterDetail` **bulunur**,
     master sütunu **280 px**.
  2. 800 px'te tek bölme; 1600 px'te **üç** bölme.
  3. `TabBar` **bulunmaz**; `NavigationRail` bulunur ve 3 hedefi vardır.
  4. Hiçbir gezinme etiketi ham dize değildir — `'UGC'` (bugün
     `admin_screen.dart:56`) l10n anahtarına bağlıdır.
- **Bağımlılık:** yok.

### WP-B — Şikâyet inceleme: kanıt + karar tek ekranda
- **SAHİP:** `app/lib/features/admin/queue/**` (yeni),
  `app/lib/features/admin/tabs/admin_moderation_tab.dart`,
  `app/lib/features/admin/widgets/moderation_queue_card.dart`,
  `app/lib/data/repositories/admin_moderation_repository.dart` (**yalnız
  `ModerationCaseDetail` alanları**),
  `app/lib/data/repositories/supabase/supabase_admin_moderation_repository.dart`
  (**yalnız ayrıştırma**), `app/lib/data/repositories/in_memory/in_memory_admin_moderation_repository.dart`,
  `app/test/features/admin/moderation_review_flow_test.dart` (yeni)
- **Kabul (önce kırmızı):**
  1. `ModerationCaseDetail` `attachmentPath`, `reason`, `createdAt` ve
     `sanctions[].action` **taşır**; sahte RPC yanıtından ayrıştırılır.
  2. Ek yolu dolu bir vaka seçilir → **görsel önizleme düğmesi bulunur**
     (bugün hiç yok).
  3. Vaka seçili iken **hem** içerik metni **hem** "Çözüldü" düğmesi **aynı
     anda** ağaçtadır (bugün imkânsız).
  4. Karar verilince sonraki vaka seçilir ve "Geri al" şeridi belirir.
  5. İtiraz detayında `sanctionAction` etiketi bulunur.
- **Bağımlılık:** WP-A.

### WP-C — Yaptırım yüzeyini birleştir + geri alma
- **SAHİP:** `app/lib/features/admin/sanctions/**` (yeni),
  `app/lib/features/admin/tabs/admin_users_tab.dart`,
  `app/test/features/admin/admin_sanction_surface_test.dart` (yeni)
- **Kabul (önce kırmızı):**
  1. Basamak listesi **tek** yerden gelir: `kAdminSuspensionLadder`
     (`admin_users_tab.dart:19`) ile UGC listesinin
     (`admin_moderation_tab.dart:336`) **aynı** kaynaktan türediği sözleşme
     testiyle sabitlenir.
  2. Aktif kısıtı olan bir kullanıcının dosyasında **"Kısıtı kaldır"** düğmesi
     bulunur ve basınca `revokeSanction` çağrılır — bugün `app/lib/features/`
     içinde sıfır çağrı yeri.
  3. `moderationSanctionsProvider` **`ref.watch` edilir** ve geçmiş çizilir
     (bugün yalnız `invalidate`).
  4. Kalıcı yasak, hedefin e-postası **yazılmadan** uygulanmaz.
  5. Vakadan hedefin dosyasına tek dokunuşla gidilir.
- **Bağımlılık:** WP-A. (B ile paralel olabilir; ikisi ayrı SAHİP yollarında.)

### WP-D — Kişi/grup arama, denetim kaydı, sistem sağlığı, etiketler
- **SAHİP:** `app/lib/features/admin/directory/**` (yeni),
  `app/lib/features/admin/tabs/admin_groups_tab.dart`,
  `app/lib/features/admin/tabs/admin_audit_log_tab.dart`,
  `app/lib/features/admin/tabs/admin_dashboard_tab.dart`,
  `app/lib/features/admin/tabs/admin_reports_tab.dart`,
  `app/test/features/admin/admin_directory_test.dart` (yeni)
- **Kabul (önce kırmızı):**
  1. Kişi listesinde arama kutusu var; e-posta parçasıyla filtreler.
  2. Grup dosyası **üye listesi** gösterir; "Üye At" elle UUID **istemez**
     (bugün `admin_groups_tab.dart:68-77`).
  3. Denetim satırı **admin kimliğini** ve varsa hedef **e-postasını** çizer
     (alanlar `admin_audit_log.dart:18,21`'de var, çizilmiyor).
  4. Boş sonuç ekranında **filtreyi temizleme** kontrolü bulunur
     (§2.4 çıkmazı).
  5. Arşiv düğmesinin/çipinin metni **"Arşivle"**dir; `profileTamamland`
     ("Tamamlandı") anahtarı bu dosyada **hiç geçmez**.
  6. Özet ızgarası sabit 2 sütun değildir; genişliğe göre 2/4/6 ve döşeme
     ≤320 px.
  7. Yalnız-ikon her düğmede `tooltip` var — sözleşme testi tüm
     `app/lib/features/admin/**` üzerinde koşar.
- **Bağımlılık:** WP-A.

### WP-E (opsiyonel, sahip onayına bağlı) — hesap silme kuyruğu paneli
- **SAHİP:** `app/lib/features/admin/health/**` (yeni),
  `app/lib/data/repositories/admin_repository.dart`,
  `app/lib/data/repositories/supabase/supabase_admin_repository.dart`,
  `app/test/features/admin/admin_purge_health_test.dart` (yeni)
- **Kabul:** `get_account_purge_health` çağrılır ve durumu ekranda görünür;
  kuyruk bozukken kart `error` rengine döner. Bugün `app/lib/` içinde bu RPC'nin
  **hiç adı geçmiyor**.
- **Bağımlılık:** WP-A. **Sahibin 4. sorusuna bağlı** (§6).

---

## 6. 🔴 SAHİBE SORULACAK KARARLAR

**S1 — Panel Ayarlar'ın altında kalsın mı, ayrı bir yüzey mi olsun?**
Bugün tek giriş `Ayarlar → Yönetim` (`settings_screen.dart:347`); masaüstünde
üç tık derinlikte.
**Önerim: ayrı yüzey.** `Ctrl+Shift+A` ile açılan tam ekran bir yönetim
penceresi; Ayarlar'daki satır da kalır. Gerekçe: panel günlük iş yüzeyi, ayar
değil; ayrıca beş sekmelik ana gezinme değişmemeli
(`DESKTOP-UI-SPEC.md §7`).

**S2 — Yedi sekme üçe iniyor. Duyurular "Kayıt & Yayın" içine mi girsin?**
Duyuru bir *yayın* işi, bir *kuyruk* işi değil; ama en sık kullandığın şey o
olabilir.
**Önerim: girsin.** Gerekçe: duyuru ayda birkaç kez kullanılıyor, kuyruk her
gün; kendi sekmesini hak etmiyor. Yanılıyorsam söyle, Kuyruk'un yanında dördüncü
yüzey yaparım.

**S3 — Ban/askı: anında uygulanıp geri alınabilir mi olsun, yoksa her seferinde
teyit mi istesin?**
**Önerim: ikisi de, ayrımlı.** Süreli kısıtlar (24 saat – 30 gün) **teyitsiz**
uygulanır + 10 sn "Geri al" + dosyada kalıcı "Kısıtı kaldır". **Kalıcı yasak ve
silme** hedefin e-postasını yazdıran teyit ister. Gerekçe: her şeye teyit
koymak teyidi görünmez yapar; asıl güvenlik ağı geri alınabilirliktir ve
sunucusu (`revokeSanction`) **zaten yazılmış**, panelde düğmesi yok.

**S4 — Hesap silme kuyruğunun sağlığı panelde görünsün mü (WP-E)?**
Bugün hiçbir yerde görünmüyor; silme işi sessizce bozulursa kimse fark etmez ve
bu yasal bir yükümlülük.
**Önerim: evet, ama en sona.** Gerekçe: A–D senin şikâyetlerini kapatıyor; bu
madde senin görmediğin ama patlarsa pahalı olan bir risk. Sırayı bozmadan
eklenebilir.

---

## 7. "TEKNİK KISIM HALLOLMUŞ MUDUR?" — sahibin hipotezi **DOĞRULANDI**

Sahibin *"teknik kısım hallolmuştur belki de"* cümlesini çürütmeye çalıştım;
çürütemedim. Ölçümler:

1. **İçerik sunucudan tam geliyor.** `0097_moderation_report_detail.sql:73-83`
   snapshot, gerekçe, açıklama, **ek yolu**, durum, zaman, ±11 bağlam mesajı,
   rapor sayısı ve tam yaptırım geçmişini döndürüyor. İstemci bunların
   yarısını ayrıştırmıyor (§2.1).
2. **Ek dosyası için depolama ve yetki hazır.**
   `0096_report_attachments.sql` private `report_attachments` bucket'ını ve
   admin SELECT politikasını kuruyor; `ugc_reports.attachment_path` kolonu var.
3. **Geri alma sunucuda var, testi yeşil.**
   `admin_revoke_moderation_sanction` migration'da; repository yolu
   `supabase_admin_moderation_repository.dart:226-249`; test
   `moderation_enforcement_wp441_test.dart:201` "geri alınan yaptırım etkisini
   yitirir". `app/lib/features/**`'te çağrı yeri **yok**.
4. **Yetki fail-closed.** `is_super_admin()` `app_admins` tablosuna bakıyor
   (`0045_feedback_reload.sql:42-54`), `auth.uid()` kullanıyor, istemci kimlik
   göndermiyor; `true` dışında her şey `false`
   (`supabase_wire_admin_test.dart:118-145`).
5. **Yaptırım motoru sağlam:** idempotency, üst üste binmeyen kısıt, süre
   dolması, bayat `pending` uzlaştırması, SLA/önem sunucudan
   (`moderation_enforcement_wp441_test.dart`, 20 iddia).

**Karşı kanıt aradım, tek bir gerçek sunucu boşluğu buldum ve o da küçük:**
`admin_set_ugc_report_group_status`'un `open` yazamadığı iddiası
(`admin_moderation_tab.dart:108-110` yorumu) **artık geçersiz** — `0105` sonrası
dört durum da yazılabiliyor (`moderation_case.dart:60-72`). Yani yorum bayat,
sunucu daha iyi durumda.

**Sonuç:** yeniden yazılacak olan **sunum katmanıdır**. Bu WP'lerde yeni RPC,
yeni migration, yeni edge function **gerekmiyor**.

---

## 8. ÖLÇEMEDİM

- **Çalışan uygulamada panelin nasıl göründüğü.** Bu tur kod/test yazılmadı
  (FAZ 1 = plan); Windows'ta panel açılıp ekran görüntüsü alınmadı. Düzenle
  ilgili bütün iddialarım `build()` ağacının okunmasına dayanıyor.
- **Sunucudaki gerçek veri.** RPC'lerin canlı ortamda ne döndürdüğü
  koşturulmadı; iddialar migration gövdesinden okundu. Yerel replay bu hostta
  Docker nedeniyle çalışmıyor (bilinen kısıt).
- **Yaptırım basamaklarının auth tarafındaki gerçek etkisi.** Testler edge
  function sözleşmesini ölçüyor, gerçek Supabase auth'u değil.
- **`admin_reporter_abuse_score`'un ne döndürdüğü** — gövdesi okunmadı, yalnız
  varlığı ve `app/lib/` içinde hiç geçmediği ölçüldü.
- **Telefon düzeni.** Bütün ölçümler masaüstü şikâyeti üzerinden yapıldı;
  telefonda panelin bugün nasıl davrandığı sınanmadı.

---

## 9. YALANLADIĞIM BELGELER

| yer | yazan | gerçek |
|---|---|---|
| `app/lib/data/providers/admin_moderation_providers.dart:37-39` | *"Kart hangi basamağın şu an yürürlükte olduğunu buradan okur"* | **Hiçbir kart okumuyor.** `moderationSanctionsProvider` yalnız iki `invalidate` çağrısında geçiyor, hiç `watch` edilmiyor. |
| `app/lib/features/admin/tabs/admin_moderation_tab.dart:108-110` | *"Sunucu RPC'si `open` yazamadığı için … tam `open` restorasyonu `0105` yaptırım diliminde eklenecek"* | `0105` **geldi**; dört durum da yazılabiliyor (`moderation_case.dart:60-72`). Yorum bayat. |
| `app/lib/data/repositories/admin_moderation_repository.dart:52` | *"Yaptırımı geri alır"* | Doğru — ama **hiçbir ekrandan çağrılmıyor**; kullanıcı için bu özellik yoktur. |
