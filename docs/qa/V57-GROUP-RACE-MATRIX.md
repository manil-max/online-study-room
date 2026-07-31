# V57 — Grup yarış koşulu ve güvenlik kabul matrisi (WP-447)

Kapsam: gruptan **ayrılma**, **çıkarma (kick)**, **grup yasağı (ban)**, **kişiyi
engelleme (block)**, **dürtme susturma (mute)** ve **mesajı raporlama**
kavramlarının hem kendi içinde hem de **birbirine karşı** davranışı.

Kanıt dosyaları:

| Uç | Dosya | Kapsam |
| --- | --- | --- |
| İstemci | `app/test/data/group_race_matrix_wp447_test.dart` | 17 senaryo |
| Sunucu | `supabase/tests/036_group_departure_matrix.test.sql` | 26 iddia |
| Şema | `supabase/migrations/0111_group_membership_departure_guard.sql` | çıkış muhafızı |

---

## 1. Bulunan hata: ayrılma değişmezleri tek kapıda bekliyordu

WP-445 (`0108`) gruptan çıkışı sunucu-otoriter ve idempotent yaptı: `leave_group`
RPC'si advisory lock alır, komut anahtarını `group_leave_commands`'a yazar,
sahiplik ve son-yönetici kurallarını uygular, presence satırını temizler.

**Kapatılmayan şey eski kapıydı.** `group_members` üzerindeki `members_update_self`
politikası (`0008`) hâlâ şunu diyor:

```sql
using (user_id = auth.uid() or public.is_group_admin(group_id))
```

Yani authenticated her istemci, REST üzerinden kendi üyelik satırına doğrudan
`left_at = now()` yazabiliyordu. Bu yazma:

* advisory lock'u atlar → 20 hızlı tap gerçekten 20 ayrı mutasyon olur;
* `group_leave_commands` anahtarını hiç üretmez → retry "çıktım mı çıkmadım mı"
  belirsizliğine döner;
* `group_live_presence` temizliğini yapmaz → ayrılan kişi kamp ateşinde asılı kalır;
* **sahiplik kontrolünü hiç görmez** → grup sahibi kendini gruptan çıkarabilir.

Son madde ürünü kırıyor: sahipsiz grupta davet kodu yenilenemez, üye çıkarılamaz,
grup silinemez, `is_group_admin` hiç kimseye `true` dönmez. Geri dönüşü yok.

Aynı boşluk istemci tarafında da vardı: `InMemoryGroupRepository.leaveGroup`
sahibi reddediyordu, `removeMember` (kick yolu) hiçbir şey sormuyordu.

### Düzeltme

`0111` iki değişmezi **yazma yolundan bağımsız** hâle getiriyor — RLS `with check`
bunu yapamaz, çünkü eski satırı görmeden `left_at` geçişini (null → not null)
ayırt edemez:

```sql
create trigger group_members_departure_guard
  before update of left_at on public.group_members
  for each row execute function public.group_members_departure_guard();
```

Muhafız yalnız **aktif üyelikten çıkış** geçişini denetler:

1. `groups.created_by` satırı için çıkış → `owner_must_transfer_or_delete`
   (23514). Her yoldan: RPC, doğrudan UPDATE, ban.
2. `auth.uid() = new.user_id` iken RPC bayrağı yoksa → `use_leave_group_rpc`
   (23514). `leave_group` kendi yazmasından hemen önce
   `set_config('app.leave_group_command', …, true)` çağırır (transaction-local).

Bozmadığı şeyler, testte açıkça ölçülüyor: yöneticinin **başkasını** çıkarması
(`auth.uid() <> new.user_id`), `ban_group_member`, ve yeniden katılım
(`left_at → null`, muhafız erken döner).

---

## 2. İkinci bulgu: bellek-içi akışlar iptal edilemiyordu

`watchUserGroups` / `watchMembers` / `watchPrimaryGroupPreference`, hiç kapanmayan
bir broadcast controller üzerinde `async*` + `await for` kalıbını kullanıyordu.
Üretici sonsuza dek askıda kaldığı için `subscription.cancel()` **hiç
tamamlanmıyordu** — aboneliği iptal eden her test 30 sn'de zaman aşımına düşüyor.

İki cihazlı senaryonun bugüne dek yazılmamış olmasının sebebi büyük olasılıkla
buydu: yazan herkes asılıp vazgeçiyordu. Üçü de iptal edilebilir bir
`StreamController` yardımcısına taşındı.

## 3. Üçüncü bulgu: model eşzamanlılıkta sunucudan ayrışıyordu

`InMemoryGroupRepository.leaveGroup` komut anahtarını **işten sonra** kaydediyordu.
Sunucuda advisory lock 20 eşzamanlı çağrıyı sıraya sokar ve 19'u replay dalından
`left` alır; modelde kilit yok, hepsi aynı boş komut tablosunu görüyor ve ilki
dışındakiler `already_left` dönüyordu. Kullanıcıya zararı yok (UI ikisini de
başarı sayar) ama bu tam olarak WP-373'te özelliğin sessizce ölmesine yol açan
ayrışma sınıfı. Anahtar artık hiçbir `await`e uğramadan, senkron ayrılıyor.

---

## 4. Matris

| # | Senaryo | Kabul | İstemci | Sunucu |
| --- | --- | --- | --- | --- |
| 1 | 20× eşzamanlı leave tap | tek mutasyon, hata yok | ✅ | ✅ (advisory lock + replay) |
| 2 | Çevrimdışı hata → aynı anahtarla retry | tek çıkış, sahte hata yok | ✅ | ✅ |
| 3 | Başarısız deneme anahtarı tüketmez | çıkış hâlâ mümkün | ✅ | ✅ (`throws_ok` alt-işlemi geri alır) |
| 4 | İki cihaz: A çıkar, B canlı akış | restart beklemeden düzelir | ✅ | — (realtime) |
| 5 | İki cihaz: B'nin geç çıkışı farklı anahtarla | `already_left` | ✅ | ✅ |
| 6 | Sahip `leaveGroup` | reddedilir | ✅ | ✅ |
| 7 | Sahip kick yolundan | reddedilir | ✅ | ✅ **(yeni)** |
| 8 | Sahip ban yolundan | reddedilir | ✅ | ✅ |
| 9 | Üye kendi `left_at`'ini doğrudan yazar | reddedilir | — (REST yok) | ✅ **(yeni)** |
| 10 | Yönetici başkasını çıkarır | çalışır | ✅ | ✅ |
| 11 | Birincil grup: çıkılan grup birincil kalmaz | uzlaşır + revision artar | ✅ | ✅ (`0079` trigger) |
| 12 | Eski revision ile CAS yazması | reddedilir | ✅ | — |
| 13 | Ban → block/mute yaratmaz | yan etki 0 | ✅ | ✅ |
| 14 | Block → üyelik/ban değiştirmez | yan etki 0 | ✅ | ✅ |
| 15 | Mute → sohbet/üyelik etkilenmez | yan etki 0 | ✅ | ✅ |
| 16 | Rapor → block/mute/kick tetiklemez | yan etki 0 | ✅ | (WP-443 `035`) |
| 17 | Mute hesap kapsamlı: ikinci gruptan sızmaz | bypass 0 | ✅ | ✅ (`nudge_mutes`'ta `group_id` yok) |
| 18 | Çıkıp yeniden katılmak mute'u sıfırlamaz | bypass 0 | ✅ | — |
| 19 | Restart: çıkış/yasak/üye listesi tutarlı | gecikmiş görünüm 0 | ✅ | ✅ |
| 20 | Bir gruptaki yasak diğer grubu düşürmez | yan etki 0 | — | ✅ |

Kabul kriterlerine karşılık:

* **duplicate mutation 0** → 1, 2, 3, 9
* **gecikmiş "sonradan çıkmış" görünüm 0** → 4, 5, 19
* **muted nudge bypass 0** → 17, 18
* **kavramlar arası istenmeyen yan etki 0** → 13, 14, 15, 16, 20

---

## 5. Boşa düşme riski ve nasıl kapatıldı

Bu turda üç iddia, doğru sebeple değil **hiçbir sebeple** geçebilirdi:

* "susturulan kişinin dürtmesi düşmez" — hiç dürtme düşmüyorsa da geçerdi.
  Susturulmamış üçüncü kişinin dürtmesinin **düştüğü** de aynı testte ölçülüyor.
* "`nudge_mutes` grup kapsamlı değil" — tablo boşsa da geçerdi. Satırın
  gerçekten yazıldığı ayrı bir iddiayla sabitlendi.
* "yönetici olmayan kick/ban göremez" (WP-446'dan devralınan ders) — üye listesi
  hiç render edilmezse boşa geçer.

---

## 6. Dağıtım durumu

`0111` **replay bekliyor**: bu hostta yerel Supabase Docker motoru kalkmıyor,
migration yalnız CI'daki Database Gates iş akışında uygulanıp doğrulanıyor.

* Yerel head: `0111` (yalnız `tooling/release/deploy-contract.json` ve
  `supabase/tests/001_schema_contract.test.sql`).
* staging / production head: **`0100`** — değişmedi. Uzak head'ler ancak gerçek
  bir apply sonrası ilerler.
* Dağıtım kapıları (`deploy_enabled`, `release_enabled`) kapalı kalır; sahibin
  açık GO'su olmadan production apply yapılmaz.

### 🔴 Uygulama sırası uyarısı

`0111`'in ikinci kuralı (**kendi çıkışı yalnız `leave_group` RPC'sinden geçer**)
eski istemciler için **kırıcıdır**. WP-445 öncesi build'ler gruptan çıkmak için
`group_members` satırını doğrudan UPDATE ediyordu; `0111` uygulandığı anda o
build'lerde "gruptan çık" `23514` ile patlar.

Şu an risk yok — production head `0100`, yani `0108` (leave RPC) bile canlıda
değil. Ama apply sırası şudur ve bozulamaz:

1. `0108`'i içeren istemci sürümü **yayında ve yaygın** olmalı,
2. sonra `0111` uygulanmalı.

Tersi sırada uygulanırsa alanda "gruptan çıkamıyorum" hatası çıkar.

### Fixture düzeltmesi (aynı commit)

`010_primary_group_preference` ve `012_multi_group_presence_projection`, grup
**sahibini** ham UPDATE ile gruptan çıkararak fixture kuruyordu — yani ikisi de
kapatılan boşluğa yaslanıyordu. Düzeltme:

* İki testte de ikinci grubun sahibi beta yapıldı; alpha düz üye.
* `010` çıkışı artık gerçek `leave_group` RPC'sinden geçiyor (ölçtüğü şey zaten
  ayrılma davranışı).
* `012` ham UPDATE'i koruyor ama önce JWT talebini boşaltıyor: o iddia `0081`
  projeksiyon trigger'ını ölçüyor, `leave_group` kullanılsaydı presence satırını
  RPC'nin kendisi sileceği için trigger hiç sınanmazdı.
