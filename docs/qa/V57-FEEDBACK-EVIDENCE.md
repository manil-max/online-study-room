# V57 — Geri bildirim akışı kanıt dosyası (WP-434)

> **Kapsam:** WP-434 bir denetim iş paketidir. Bu turda **ürün kodu ve migration
> değişmedi**; akışın bugünkü gerçeği okunarak tek olay zinciri çıkarıldı ve
> bulguların her biri otomatik testle kilitlendi.
> **Kanıt etiketi:** `Kodda doğrulandı` (dosya/satır okunarak).
> **Test dosyası:** `app/test/features/feedback_flow_wp434_test.dart` — 10 test,
> hepsi yeşil.
> **Devir:** WP-435 (sunucu tek gerçeği), WP-436 (watermark/rozet),
> WP-437 (deneyim), WP-438 (E2E kapısı).

---

## 1. Bugünkü olay zinciri (tek çizelge)

| # | Olay | Yazan | Nereye yazılır | Otorite mi, projeksiyon mu |
|---|---|---|---|---|
| 1 | Bilet açılışı (ilk metin) | kullanıcı | `feedback_tickets` satırı; `subject` + **`message`** | **Otorite** — ama mesaj dizisinin dışında |
| 2 | Kullanıcı devam mesajı | kullanıcı | `feedback_ticket_messages` (RPC `send_feedback_ticket_message`) | **Otorite** |
| 3 | Admin yanıtı | admin | `feedback_ticket_messages` **+ ayrıca** `announcements` satırı | **İki otorite** — tek olay, iki kanal |
| 4 | Admin yanıtı push | trigger | `notification_outbox` (`route=feedback_ticket`) | Projeksiyon |
| 5 | Okundu | kullanıcı/admin | `feedback_ticket_messages.read_at` (RPC `mark_feedback_ticket_messages_read`) | **Otorite** (yalnız mesaj kanalı) |
| 6 | Duyuru okundu | kullanıcı | duyuru okuma kaydı (`readAnnouncementIdsProvider`) | **Ayrı otorite** (mesaj kanalıyla ilişkisiz) |
| 7 | Durum/arşiv | admin | `feedback_tickets.status` / `archived_at` (RPC) | Otorite; mesaj geçmişini taşımaz |

Rozet yüzeyleri (`Profil → Ayarlar → Geri bildirim → bilet`) mesaj kanalını
`unreadFeedbackReplyCountProvider` üzerinden okur
(`app/lib/data/providers/admin_providers.dart:87`), duyuru kanalını
`unreadAnnouncementCountProvider` üzerinden okur
(`app/lib/data/providers/notification_providers.dart:41`) ve
`settingsBadgeCountProvider` ikisini **toplar**
(`app/lib/data/providers/admin_providers.dart:98`).

### Sözleşme olarak kilitlenen (bugün doğru) bağlar

* Bir mesajın tek `id`'si ve tek `ticket_id`'si var; gönderim sırası korunuyor.
* İki bilet eşzamanlı yazışırken mesaj karşı bilete düşmüyor.
* Katılımcı olmayan kullanıcı yazışmayı ne okuyabiliyor ne yazabiliyor ne
  okundu işaretleyebiliyor (`_requireTicketParticipant`,
  `in_memory_admin_repository.dart:351`; sunucuda RLS + RPC rol türetimi,
  `supabase/migrations/0074_feedback_ticket_conversations.sql:40` ve `:95`).
* `sender_role` istemciden alınmıyor; RPC `auth.uid()` ve bilet sahipliğinden
  türetiyor (`0074:95-101`).
* Yeniden fetch aynı kimlik ve sırayı veriyor (aynı damgalı mesaj yoksa).

---

## 2. Bulgular

Her bulgu: kök neden · kanıt · sahibi · testte çevrilecek satır.

### B1 — Biletin ilk mesajı kanonik dizide yok *(WP-435)*

Bilet açılışındaki metin yalnız `feedback_tickets.message` içinde
(`supabase_admin_repository.dart:163`), `feedback_ticket_messages` boş kalıyor
(`0074:20`). Sonuç: kullanıcının yazdığı ilk metnin kalıcı `message_id`'si yok;
yazışma penceresi bilet yeni açıldığında **"henüz yanıt yok"** diyor
(`feedback_tickets_screen.dart:240`), yani kullanıcı kendi mesajını konuşmada
göremiyor. Tek mesajın tek kimliği kabul kriteri bu yüzden bugün sağlanmıyor.

* **Test:** `biletin ilk mesajı kanonik mesaj dizisinde yok`
* **Çevrilecek iddia:** `fetchTicketMessages(...) isEmpty` →
  `messages.first.message == ticket.message`.

### B2 — Mesaj gönderimi idempotent değil *(WP-435)*

`send_feedback_ticket_message` yalnız `p_ticket_id` + `p_message` alıyor
(`0074:62`); istemci kaynaklı komut kimliği yok
(`supabase_admin_repository.dart:458`). Zaman aşımı sonrası yeniden deneme
ikinci satır üretir; kullanıcı "iki kez gönderildi" görür.

* **Test:** `aynı mesaj iki kez gönderilince iki satır oluşur (idempotent değil)`
* **Çevrilecek iddia:** `messages.length == 2` → `1` (aynı `client_message_id`).

### B3 — Sıra imleci yok, sıra `created_at`e bağlı *(WP-435)*

Liste `.order('created_at')` ile geliyor (`supabase_admin_repository.dart:445`);
eşit damgalı iki mesaj için kanonik bir tie-breaker (`message_seq`) yok. Model
`fromMap` da ne `message_seq` ne `client_message_id` okuyor
(`feedback_ticket_message.dart:39`). "Refresh/relogin sonrası aynı sıra" garanti
edilemiyor.

* **Test:** `mesaj modelinde istemci kimliği ve sıra imleci yok`
* **Çevrilecek iddia:** kaynakta `message_seq` / `client_message_id` yok →
  var olmalı ve sıra bu imleçten okunmalı.

### B4 — Tek admin yanıtı iki rozet olayı üretiyor *(WP-436)*

Admin yanıtı hem mesaj satırı hem de kullanıcıya hedefli `announcements` satırı
yazıyor (`0074:115-131`). `settingsBadgeCountProvider` iki kanalı topladığı için
**bir yanıt rozeti 2 artırıyor**.

* **Test:** `tek admin yanıtı rozeti iki kez artırır ve okununca sönmez`
  (bugün ölçülen değer: `2`)
* **Çevrilecek iddia:** `settingsBadgeCountProvider == 2` → `1`.

### B5 — Okundu yalnız bir kanalı kapatıyor, rozet asılı kalıyor *(WP-436)*

`mark_feedback_ticket_messages_read` sadece `feedback_ticket_messages.read_at`
yazıyor (`0074:137`); yanıtın duyuru kopyası okunmamış kalıyor. Kullanıcı
yazışmadaki her şeyi okusa bile Ayarlar/Profil rozeti **1'de takılı** kalıyor —
ancak Bildirim Merkezi'nden duyuruya ayrıca dokunulursa sıfırlanıyor
(`announcements_screen.dart:112`).

* **Test:** aynı test, ikinci yarısı (okundu sonrası ölçülen değer: `1`)
* **Çevrilecek iddia:** okundu sonrası `1` → `0`.
* **Not:** WP-435 kartı bu işi `mark_support_thread_read` adlı bir RPC'ye
  bağlıyor; **böyle bir fonksiyon repoda yok** (`supabase/`, `app/lib`,
  `app/test` taramasında sıfır eşleşme). Kapatılacak gerçek yol
  `mark_feedback_ticket_messages_read` + duyuru okuma kaydıdır.

### B6 — Yazışma açıkken canlılık yok *(WP-436)*

Pencere mesajları tek seferlik `fetchTicketMessages` ile alıp yerel `_messages`
listesinde tutuyor; stream/realtime aboneliği yok
(`feedback_tickets_screen.dart:104` ve `:141`). Pencere açıkken gelen admin
yanıtı ekrana düşmüyor; kullanıcı pencereyi kapatıp açmadan göremiyor. Veri
kaybı yok — yalnız canlılık yok.

* **Test:** `yazışma açıkken gelen yeni yanıt ekrana düşmez`
* **Çevrilecek iddia:** `find.text('Canlı yanıt.') findsNothing` →
  `findsOneWidget`.

### B7 — Okundu işareti "görüldü" değil "fetch edildi" anlamına geliyor *(WP-436)*

`_load()` mesajları çeker ve **hemen ardından** okundu işaretler; ilk kare
çizilmeden önce ack gidiyor (`feedback_tickets_screen.dart:147-157`). Yükleme
hata verse bile fetch başarılıysa işaret düşmüş olur. WP-436'nın "fetch etmek
tek başına okundu saymaz" kriteri bugün sağlanmıyor.

* **Test:** *yok* — bu bulgunun ölçülebilir kilidi görünürlük sözleşmesi
  kurulunca (WP-436) yazılmalı; bugün davranışsal olarak ayırt edilemiyor.

### B8 — Repository çifti sapması, kusuru testlerde görünmez yapıyor *(WP-435)*

InMemory `sendTicketMessage` admin yanıtında duyuru satırı üretmiyor
(`in_memory_admin_repository.dart:260`), sunucu üretiyor (`0074:115`). Bu sapma
yüzünden B4/B5 çift sayımı yalnız gerçek backend'de görünüyordu; WP-421 rozet
testleri yeşil kaldığı hâlde sahada rozet yanlış davranıyordu.

* **Test:** `sunucu admin yanıtında ikinci kanal üretir, InMemory üretmez`
* **Çevrilecek iddia:** duyuru sayısı değişmiyor → iki uçlu davranış eşitlenmeli.

### B9 — Push'un `feedback_ticket` yolu ölü *(WP-437 / bildirim yüzeyi)*

Trigger, admin yanıtı push'una `route=feedback_ticket` + `feedback_ticket_id`
koyuyor (`0074:185-210`) ve servis bunu payload'a yazıyor
(`app_push_notification_service.dart:267`). Fakat bildirim eklentisi
`onDidReceiveNotificationResponse` **olmadan** başlatılıyor
(`app_push_notification_service.dart:94`): dokunma payload'ı hiçbir yere
yönlenmiyor. Bildirim Merkezi'nden duyuruya dokunmak da yalnız **bilet
listesine** gidiyor, ilgili bilete değil (`announcements_screen.dart:127`).

* **Kapsam freni:** Bu bulgu WP-434'te yalnız kayda geçti; düzeltmesi WP-437
  deneyim kartında değerlendirilmeli (sıcak dosya/bildirim yüzeyi sahipliği
  gerekiyorsa Ajan H entegrasyon kapısına yazılır).

---

## 3. WP-435 için hazır girdi (özet)

1. İlk mesajı bir kez kanonik diziye backfill et (B1) — eklemeli, geri
   alınabilir.
2. `client_message_id` ile idempotent insert (B2).
3. `message_seq` sıra imleci + hem sunucu hem istemci sıralamasının bu imleci
   kullanması (B3).
4. Tek admin-yanıt olayının **tek** okunmamış gerçeği üretmesi; duyuru kopyası
   ya kaldırılır ya da aynı watermark'tan türetilir (B4/B5). Kartta adı geçen
   `mark_support_thread_read` yok; mevcut RPC genişletilir.
5. Repository çiftinin (Supabase/InMemory) yan etkilerinin eşitlenmesi (B8).

## 4. Doğrulama

```bash
cd app
flutter analyze
flutter test --dart-define-from-file=env.json test/features/feedback_flow_wp434_test.dart
```

Sonuç (2026-07-30): `analyze` 0 uyarı · 10/10 test yeşil. Cihaz kanıtı bu
kartta gerekmiyor; cihazda doğrulanacak satırlar WP-438 → Ajan H WP-465/466.
