# Moderasyon Planı — admin tarafını çalışır hâle getirme

> Durum tespiti 2026-07-28, v55 sonrası. Kaynak: kod okuması (plan değil).
> Numaralar öneridir; `progress.md`'ye alınırken kesinleşir. Son kullanılan: WP-411.

## Bugün elimizde ne var

**Çalışan altyapı**
- Şikâyet kaydı dört yüzeyden: sohbet mesajı, grup, grup adı, sosyal profil
- `content_snapshot` — içerik şikâyet anında donduruluyor, sonradan silinse de duruyor
- `reporter_id` kayıtlı; `unique (reporter_id, target_type, target_id, reason)` ile aynı kişi aynı şeyi tekrar şikâyet edemiyor
- Yaptırım fonksiyonları: `suspend_user`, `unsuspend_user`, `soft_delete_user`, `send_password_reset`, `remove_group_member`, `delete_group`
- Denetim kaydı: `admin_audit_logs` — hem `target_user_id` hem `target_user_email`, gerekçe zorunlu
- Engelleme (0092) ve grup yasağı (0093) ayrı ve çalışıyor
- Ad süzgeci (WP-392) — uygunsuz ad girişte reddediliyor

**Çalışmayan / eksik**
- UGC kuyruğunda yalnız durum değiştirilebiliyor; yaptırıma köprü yok
- Kuyrukta ham UUID görünüyor, ad yok — ne şikâyet edenin ne edilenin
- Bağlam yok: şikâyet edilen mesajın etrafındaki konuşma görünmüyor
- Kişinin geçmişi yok: daha önce kaç şikâyet, kaç yaptırım
- Tek yaptırım seviyesi: `ban_duration: '876000h'` (100 yıl). Uyarı, geçici susturma, süreli askı yok
- İçerik şikâyeti admin'e bildirim atmıyor (push tetikleyicisi `feedback_tickets` üzerinde, `ugc_reports` üzerinde değil)
- `app_admins` tek seviye — kolon yok, üyelik = tam yetki
- `reporter_id ... on delete cascade` — şikâyet eden hesabını silerse kanıt da siliniyor

---

## Faz A — v56: kuyruğu kullanılabilir yap

Bunlar olmadan moderasyon fiilen yok; kuyruk açılır, bakılır, hiçbir şey yapılamaz.

### WP-412 — Kuyrukta kimlik okunabilirliği
Ad + avatar göster, ID'yi gizle. Hem şikâyet eden hem şikâyet edilen için.
Kural: **gösterilen ad, işlem yapılan ID, loglanan ikisi birden.**
ID kartın altında kopyalanabilir küçük metin olarak dursun (destek yazışması için gerekir).
Desen zaten repoda: `admin_audit_logs` ad ve ID'yi birlikte saklıyor — kuyruğa uygulanmamış sadece.

### WP-413 — Şikâyet detay ekranı
Kartın açılışı:
- Tam `content_snapshot` (şu an 3 satırda kesiliyor)
- **Bağlam**: şikâyet edilen mesajın çevresindeki ±5 mesaj. Tek mesaj bağlamsız çoğu zaman karar verilemez
- **Kişinin geçmişi**: bu hedefe daha önce kaç şikâyet geldi, hangi yaptırımlar uygulandı
- Şikâyetçinin serbest açıklaması (`details`)

### WP-414 — Basamaklı yaptırım
Karttan tek tık, gerekçe zorunlu, hepsi denetim kaydına:

| Basamak | Karşılığı |
|---|---|
| Uyar | Kullanıcıya bildirim, kayıt tutulur, erişim kısıtlanmaz |
| Adı sıfırla | Görünen ad nötr değere döner, yeniden seçmeye zorlanır |
| Sustur | 24 saat — yazamaz, okuyabilir |
| Askıya al | 7 / 14 / 30 gün (`ban_duration` saat kabul ediyor: 168h / 336h / 720h) |
| Kalıcı | Mevcut 876000h yolu |

Her basamak tek tıkla geri alınabilir.
"Adı sıfırla" uygunsuz kullanıcı adı ve grup adı için doğru ceza — grubu tamamen silmeye gerek kalmıyor.

### WP-415 — Tekilleştirme
Aynı hedefe gelen şikâyetler tek kartta, "8 şikâyet" rozetiyle.
Yoksa spam dalgasında kuyruk kullanılamaz hâle gelir.

### WP-416 — İçerik şikâyetinde admin push
`_enqueue_support_ticket_admin_push` tetikleyicisinin eşini `ugc_reports` insert'üne bağla.
Şu an destek kutusundan gelen şikâyet bildirim atıyor, sohbetten gelen sessizce bekliyor.
**Bu bir mağaza uyum maddesi** — aşağıdaki nota bak.

---

## Faz B — v57: sen uyurken de çalışsın

Tek kişilik moderasyon ekibinin gerçek sorunu: 8 saat uyuyorsun, içerik görünür kalıyor.

### WP-417 — Eşik tabanlı otomatik karantina
N farklı kişi X süre içinde aynı içeriği şikâyet ederse içerik **otomatik gizlenir**, inceleme bekler.
Silme değil gizleme — yanlışsa geri alınır. Otomatik yaptırım kullanıcıya değil içeriğe uygulanır.

### WP-418 — Şiddet kademesi ve SLA
`illegal` ve `hate` kuyruğun başına, ayrı SLA.
Panoda: kaç açık şikâyet, **en eskisi kaç saattir bekliyor**, ortalama çözüm süresi.
Ölçmeden moderasyonun çalışıp çalışmadığını bilemezsin.

### WP-419 — Kötü niyetli şikâyetçi
Şikâyet mekanizması silah olarak kullanılır. `reporter_id` zaten kayıtlı:
reddedilme oranı yüksek olan kişinin şikâyetleri düşük öncelik alsın ve WP-417 eşiğine sayılmasın.

### WP-420 — Toplu işlem
Spam dalgasında tek tek tıklanmaz. Çoklu seçim → tek aksiyon.

---

## Faz C — v58: tek kişi kalma, yasal tarafı kapat

### WP-421 — Rol katmanı
`app_admins` şu an tek seviye. İkiye ayır:
- **moderatör**: içerik görür, yaptırım uygular
- **admin**: ek olarak rol atar, duyuru yayınlar, hesap siler

### WP-422 — Grup yöneticisine devir
Grup içi şikâyet önce grup yöneticisine düşsün; çözülmezse veya ağır kademeyse sana yükselsin.
WP-393 grup yasağı altyapısı zaten var, üstüne biner.

### WP-423 — İtiraz ve geri bildirim
İki yön: şikâyetçiye sonuç bildirimi, yaptırım uygulanana itiraz hakkı.
Hata yapacaksın; itiraz yolu olmayan sistemde hata kalıcı olur.

### WP-424 — Kanıt saklama
`reporter_id ... on delete cascade` düzeltilmeli: hesap silinince şikâyet kaydı da gidiyor.
Kaydı koru, kimliği anonimleştir. `purge-accounts` yolu da bu gözle gözden geçirilmeli.

### WP-425 — Denetim kaydı değişmez olsun
Admin kendi işlem izini silememeli — `admin_audit_logs` üzerinde delete/update yetkisi kalkmalı.

---

## Mağaza uyum notu

Apple App Store 1.2 (kullanıcı üretimi içerik) dört şey istiyor:
filtre · şikâyet mekanizması · kullanıcı engelleme · yayınlanmış iletişim kanalı.
**Dördü de bizde var** (WP-392 · UGC şikâyet · 0092 engelleme · destek kutusu).

Ama aynı madde şikâyetlere **24 saat içinde işlem** yapılmasını da istiyor.
Bildirim gelmeden bunu garanti edemeyiz — bu yüzden WP-416 kozmetik değil, uyum maddesi.
Google Play Kullanıcı Üretimi İçerik politikası da benzer şartlar koyuyor.

---

## Sıralama gerekçesi

Faz A olmadan diğerlerinin anlamı yok — kuyruk zaten kullanılamıyor.
Faz B ölçek ve kötüye kullanım; kullanıcı sayısı artınca zorunlu hâle gelir.
Faz C delegasyon ve yasal dayanıklılık; tek kişiyle yürütülemeyeceği noktada gerekir.
