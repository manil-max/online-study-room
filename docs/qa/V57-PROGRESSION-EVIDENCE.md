# V57 — Seri ve bütün ilerleme kabul matrisi (WP-455)

Kapsam: WP-453'ün seri motoru ile WP-454'ün alevinin **tek tek değil birbirine
ve komşu kavramlara karşı** davranışı — hangi olay seriyi ilerletir, grace kaç
kez uygulanır, kişisel/grup farklı hedeflerle aynı günde ne olur, gün sınırı
nerede kesilir, oturum türü ayrımcılık yapar mı, görev tamamlama sızar mı, iki
cihaz çift artış üretir mi ve ekrandaki sayı sunucudakiyle aynı mı.

Kanıt dosyaları:

| Uç | Dosya | Kapsam |
| --- | --- | --- |
| İstemci | `app/test/data/progression_matrix_wp455_test.dart` | 34 test |
| Sunucu | `supabase/tests/038_progression_matrix.test.sql` | 20 iddia |
| Motor | `supabase/migrations/0112_goal_streak_projection.sql` | WP-453 Faz 2 |
| Fixture | `app/test/fixtures/goal_streak_parity_v1.json` | WP-453 Faz 1 |

Kapılar: `flutter test` hedefli 34/34, mutasyonla sınandı (aşağıda §3).

---

## 1. Matris

| # | Senaryo | Kabul | İstemci | Sunucu |
| --- | --- | --- | --- | --- |
| 1 | Hedef tamamlandı | seri +1 | ✅ | ✅ (037) |
| 2 | Uygulama açıldı | artış yok | ✅ | ✅ (037) |
| 3 | Sayaç başladı | artış yok | ✅ | ✅ (037) |
| 4 | Kısmi ilerleme | artış yok | ✅ | ✅ (037) |
| 5 | Gelecek günün tamamlaması | bugüne girmez | ✅ | ✅ (037) |
| 6 | Tek kaçırma | seri korunur | ✅ | ✅ |
| 7 | İki ardışık kaçırma | sıfırlanır, sayım kalır | ✅ | ✅ (037) |
| 8 | Tekrar grace (6 gün, 5 boşluk) | her kaçırmada tekrar | ✅ | ✅ (037) |
| 9 | Durum geçişleri 0/1/2/3 gün | tamamlandı/bekliyor/riskte/bitti | ✅ | ✅ |
| 10 | Kişisel–grup aynı gün | ledger'lar ayrı | ✅ | ✅ |
| 11 | Aynı kimlik, iki kapsam türü | iki ayrı ledger | ✅ | ✅ (037) |
| 12 | Kişisel–grup **farklı hedef** | biri geçer biri geçmez | — | ✅ |
| 13 | Grup hedefi = üye toplamı | tek kişinin günü değil | — | ✅ |
| 14 | Aynı olay iki kez | tek sayılır | ✅ | ✅ |
| 15 | Aynı anahtar çelişkili içerik | sessiz kabul yok | ✅ | ✅ (037) |
| 16 | Olay anahtarı biçimi | iki uçta birebir | ✅ | ✅ |
| 17 | 23:59 / 00:01 | farklı hedef günleri | ✅ | ✅ |
| 18 | Grup saat dilimi | gün başka yerde kesilir | ✅ | ✅ |
| 19 | manual / live oturum | hedefe eşit sayılır | ✅ | ✅ |
| 20 | Sıfır süreli oturum | katkı vermez | ✅ | ✅ |
| 21 | Görev tamamlama | seri ilerletmez | ✅ | — |
| 22 | Görev geri alma | geçmişi silmez | ✅ | — |
| 23 | İki cihaz aynı ledger | aynı sayı | ✅ | — |
| 24 | İki cihaz aynı günü bildirir | tek satır, çift artış 0 | ✅ | ✅ |
| 25 | Hedefe **tam eşit** gün | kabul edilir | — | ✅ |
| 26 | Hedefin 1 dk altı | reddedilir | — | ✅ |
| 27 | Ekran ↔ projeksiyon | dört durumda aynı sayı | ✅ | — |

Kart kabul kriterlerine karşılık:

* **yanlış artış 0** → 1–5, 20, 21, 25, 26
* **çift XP/reward 0** → 14, 15, 16, 24
* **kişisel-grup sızıntısı 0** → 10–13, 18
* **UI/server state farkı 0** → 27 · **ve §4'teki açık bulgu**

---

## 2. Yalnız sunucuda görünen satırlar

12, 13, 25 ve 26 istemcide taklit edilemez, çünkü kararı istemci vermiyor:
`record_goal_completion` günün toplamını `study_sessions`'tan kendisi okuyup
hedefle karşılaştırıyor. `038` bunu gerçek veriyle kuruyor:

* alpha bugün 5400 sn (3600 `live` + 1800 `manual`), beta 3600 sn.
* Kişisel hedef 180 dk → alpha **geçemiyor**; grup hedefi 120 dk → grup
  toplamı 9000 sn ile **geçiyor**. Aynı gün, aynı kişi, iki farklı sonuç.
* Sonrasında kişisel ledger 0 satır, grup ledger 1 satır: sızıntı yok.
* Hedef tam 90 dk yapılınca 5400 = 5400 **kabul**, 91 dk yapılınca **ret** —
  `>` / `>=` hatasının görünür olduğu tek yer burası.

19 numaralı satır kodda iki kaynağa iniyor: kronometre, geri sayım ve pomodoro
üçü de `StudySource.live` yazıyor (`study_providers.dart`), elle giriş `manual`.
Yani "manual/native/pomodoro/countdown" ayrımı hedef hesabında **yok** ve
olmamalı; `_goal_day_seconds` kaynağa hiç bakmıyor.

---

## 3. Mutasyon turu

| Mutasyon | Beklenen | Sonuç |
| --- | --- | --- |
| Grace kaldır (`> 2` → `> 1`) | grace ve ayrışma testleri kırmızı | **7 kırmızı** ✅ |
| Kapsam türünü yok say (`scope` → `scope.id`) | sızıntı testi kırmızı | **1 kırmızı** ✅ |

İkinci mutasyonu **yalnız** "aynı kimlik iki ledger demektir" testi yakaladı.
Bu tesadüf değil: diğer sızıntı senaryolarında kişisel ve grup kimlikleri
zaten farklı olduğu için tür alanını düşürmek gözlemlenebilir bir fark
üretmiyor. Farkın görünür olduğu durum, **aynı kimliğin iki kapsamda birden
kullanılması**; test bilerek o durumu kuruyor. (WP-451'de aynı sınıftan bir
test zaafı çıkmıştı — orada da çözüm iddiayı sertleştirmek değil, farkın
görünür olduğu senaryoyu kurmaktı.)

---

## 4. 🔴 Açık bulgu — "seri" kelimesinin üç farklı tanımı

Kartın kabul kriteri **"UI/server state farkı 0"**. Bu kriter bugün
**sağlanmıyor** ve sebebi WP-453/454'te yapılan bir hata değil: repo'da
birbirinden bağımsız doğmuş **üç** seri tanımı yan yana yaşıyor.

Aynı geçmiş — 1, 3 ve 5 Temmuz hedefe ulaşıldı; 2 ve 4 kaçırıldı:

| # | Tanım | Nerede | Bu geçmişte | Ekranda nerede |
| --- | --- | --- | --- | --- |
| 1 | `goal_streak_projection` | `0112` (WP-453) | **3** | WP-454 alevi |
| 2 | `_achievement_metrics.streak_days` | `0025` gövdesi | **1** | `fire_streak` XP eşiği |
| 3 | `currentStreakWithFreezes` | `gamification.dart` | **1** veya **3** | bugünkü seri göstergesi |

* (1) tek kaçırmayı **otomatik** affeder ve bunu sınırsız tekrar eder.
* (2) hiç affetmez: `exit when day_secs < goal_secs` ile ilk eksik günde durur.
* (3) affeder **ama tüketilebilir bir bakiyeden** (`profiles.streak_freezes`)
  düşerek: bakiye 0 ise 1, bakiye 2 ise 3 sayar ve bakiyeyi **harcar**.

Bu, WP-453 kartının açıkça yasakladığı karışımın ta kendisi: *"otomatik tek-gün
grace, tüketilen `streak_freezes` bakiyesiyle karıştırılmaz."* Motor bu ayrımı
doğru kuruyor; ayrışma motorun dışında, henüz hizalanmamış iki eski yüzeyde.

**Kullanıcıya ne olarak görünür:** WP-454 alevi bir ekrana yerleştirildiği anda
kullanıcı "serin 3" ile "7 güne 6 kaldı" (yani seri 1) ifadelerini aynı
uygulamada yan yana görür. Alev şu an **hiçbir ekrana bağlı değil**
(`GoalStreakFlame`in `lib/` içinde çağrı yeri yok), bu yüzden bugün sahada
görünen bir çelişki **yok**. Ayrışma, alev yerleştirilmeden kapatılmalı.

**Neden bu WP'de kapatmadım.** Hizalamanın tek anlamlı yönü (2) ve (3)'ü (1)'e
taşımaktır; bu, `streak_days` metriğini grace'li hâle getirmek demektir ve
`fire_streak` XP eşikleri (7/30/150/365/730/1000 gün) o metrikten besleniyor.
Yani değişiklik **mevcut kullanıcıların seri sayısını ve kazandıkları XP
kademesini geriye dönük yükseltir** — bir kabul matrisi WP'sinin sessizce
yapacağı bir iş değil, ekonomi kararı. Ayrıca `streak_freezes` bakiyesinin ne
olacağı (kaldırılacak mı, başka bir işe mi bağlanacak) ayrı bir üründür.

**Testler bulguyu gizlemiyor, sabitliyor.** İstemcide `🔴 üç tanım aynı
geçmişte aynı sayıyı vermiyor`, sunucuda `isnt(...)` iddiası farkın bugünkü
değerini pinliyor. Ayrışma kapatıldığında **bu iki test kırmızıya döner** ve
kasten güncellenir — sessizce doğru hâle gelmesini istemiyoruz.

**Sahibe soru:** seri tanımı tek kaynağa (`0112`) çekilsin mi? Çekilirse
`fire_streak` kademeleri mevcut kullanıcılarda yükselecek.

---

## 5. Yan gözlem — bellek-içi ledger'da yarış

`InMemoryGoalStreakRepository.watchProjection` bir `async*`: ilk değeri yield
ettikten **sonra** `_changes` akışına abone oluyor. Broadcast controller
abonelikten önceki olayları düşürdüğü için, ilk okumanın hemen ardından gelen
bir `ingestCanonicalEvent` **sessizce kaybolur**.

Etkisi sınırlı: bu repository yalnız demo/offline yolunda kullanılıyor
(`SupabaseConfig.isConfigured` false iken), gerçek yolda Supabase realtime
akışı var ve kayıp değişiklik bir sonraki okumada zaten yakalanıyor. Kayda
geçiyorum çünkü testte gerçek bir kırmızıya sebep oldu ve sebebi "test
flaky" değil, repository'nin davranışıydı.
