# WP-169 — Günlük / haftalık görev listesi kartı (PLAN)

| Alan | Değer |
|---|---|
| Tarih | 2026-07-18 |
| Tür | **Ürün + teknik plan** — **kod yok** · onay bekler |
| İstek | Kartlar bölümünde kullanıcının kendine **günlük / haftalık** görev atadığı liste; yapıldıkça tik / üstü çizili |
| ⛔ Donuk | Timer / widget / FGS (WP-134–137); mevcut XP ledger yazımı; admin |
| Bağımlılık | Analytics grid (WP-158–164) + flag · `istanbulDay` / `startOfWeek` (WP-146 ruhu) |
| Onay | **STOP** — ürün onayı olmadan implementasyon WP açılmaz |

> Bu belge karar ve kapsam içindir. Onay sonrası ayrı uygulama WP’leri (öneri: WP-170+) claim edilir.

---

## 1. Problem / vizyon

Kullanıcı, “bugün 2 pomodoro”, “bu hafta 10 saat matematik” gibi **kişisel** maddeleri uygulama içinde tutmak istiyor. Mevcut **WP-154 quest** satırları sistem tanımlı / salt görüntü; kullanıcı oluşturamaz. Bu özellik **kullanıcı tanımlı to-do / hedef listesi**dir — gamification quest ile karıştırılmaz (isimlendirme: “Görevlerim” / “Listem”).

**Başarı tanımı (cihaz):** Kartta madde ekle → tikle → üstü çizili → dönem sınırında doğru sıfırlama/arşiv → offline ve yeniden açılışta kalıcı.

---

## 2. Domain modeli

```text
UserTask {
  id: String                 // uuid v4
  title: String              // trim; 1…80 karakter (feedback subject ile hizalı)
  scope: daily | weekly      // enum
  completed: bool
  createdAt: DateTime        // UTC sakla; UI Istanbul
  completedAt: DateTime?     // tamamlanınca set; geri alınınca null
  sortOrder: int             // liste sırası (0..)
  periodKey: String          // hangi gün/hafta dilimine ait (aşağıda)
}
```

### 2.1 `periodKey` (Europe/Istanbul)

| scope | periodKey formatı | Üretim |
|---|---|---|
| `daily` | `d:YYYY-MM-DD` | `istanbulDay(now)` → tarih |
| `weekly` | `w:YYYY-MM-DD` | `startOfWeek(istanbulDay(now))` Pazartesi (mevcut `study_stats.startOfWeek`) |

Aynı `id` dönemler arası taşınmaz: dönem değişince **yeni boş liste** veya arşiv (karar §4).

### 2.2 Sınırlar (v1)

| Kural | Değer |
|---|---|
| Max madde / dönem / scope | 20 (UI + repo clamp) |
| Max başlık | 80 char |
| Boş başlık | red |
| Çoklu scope aynı kartta | Evet: sekmeler veya bölümlü liste (Günlük / Haftalık) |
| Paylaşım / grup görevi | **v1 yok** |

---

## 3. Kalıcılık — v1 önerisi

### Öneri: **v1 yalnız lokal prefs** (cihaz), repository **çift arayüz** hazır

| Seçenek | Artı | Eksi |
|---|---|---|
| **A. Lokal prefs (önerilen v1)** | Hızlı; RLS/migration yok; offline doğal; ızgara flag ile uyumlu | Cihaz değişince kayıp; çok cihaz senkron yok |
| B. Supabase tablo + RLS (v1) | Çok cihaz | Migration, RLS, silme/export kapsamı, test maliyeti — özellik keşfi yavaşlar |
| C. Hibrit hemen | — | Erken karmaşıklık |

**Gerekçe:** v1 keşif özelliği; veri hassasiyeti düşük (kişisel not); analytics layout da v1’de prefs. Cloud sync **v1.1** (ayrı WP + `user_tasks` migration) — export (WP-152) o zaman JSON’a eklenir.

### 3.1 Repository sözleşmesi (çift implementasyon zorunlu)

```dart
abstract class UserTaskRepository {
  Future<List<UserTask>> load({required TaskScope scope, required String periodKey});
  Future<void> saveAll(TaskScope scope, String periodKey, List<UserTask> tasks);
  // veya CRUD: add / toggle / reorder / remove
}
```

| Impl | Davranış |
|---|---|
| `in_memory/` | Map bellek; test seed |
| `supabase/` **v1** | **Prefs mirror** (SharedPreferences) — *sunucu yazmaz*; ileride gerçek PostgREST ile değiştirilir |
| `supabase/` **v1.1** | Tablo + RLS `user_id = auth.uid()` |

> “Supabase impl = prefs” kulağa garip gelebilir ama mevcut “configured → supabase repo ailesi” seçicisini bozmadan demo/offline parity sağlar. Alternatif: tek `PrefsUserTaskRepository` her iki moda inject — onayda netleştirilir.

### 3.2 Prefs anahtarı

```
user_tasks_v1.<userId>.<scope>.<periodKey> → JSON list
// userId yoksa (anon demo): user_tasks_v1.local....
```

Hesap değişince izolasyon (onboarding WP-166 per-user paterni).

---

## 4. Sıfırlama / arşiv / tamamlanınca UI

Kullanıcı hem “üstü çizili kalsın” hem “listeden düşsün” ima etti → **ürün kararı** gerekir. Plan önerisi:

### 4.1 Dönem geçişi (otomatik)

| Strateji | Davranış | Öneri |
|---|---|---|
| **Sıfırla (hard)** | Yeni `periodKey` → boş liste; eski key prefs’te kalır (opsiyonel TTL 14 gün) | **v1 varsayılan** — basit |
| Arşivle | Eski dönem salt-okunur “Geçmiş” | v1.1 |
| Taşı (roll-forward) | Tamamlanmamışları yeni döneme kopyala | **Ürün kararı** — varsayılan **kapalı** (sürpriz çoğalma) |

**Gün sınırı:** her okumada `periodKey == currentKey(scope, now)`; değilse current yükle (eski yazma yok).

### 4.2 Tamamlanınca aynı dönem içinde

| Mod | UI | Öneri |
|---|---|---|
| **Üstü çizili + altta grupla** | `completed: true` → strikethrough; tik geri alınabilir; sıralama: açıklar üstte, tamamlananlar altta | **v1 varsayılan** |
| Listeden düş | Toggle → listeden çıkar (undo snackbar) | İkinci tercih / ayar |
| İkisini de | Ayar: “Tamamlananları gizle” switch (kart içi) | v1 küçük eforla eklenebilir |

**Öneri paketi:** strikethrough + alta yığ + kart menüsünde “Tamamlananları gizle” (prefs bool). Sil = kalıcı remove.

### 4.3 Haftalık sınır

- `startOfWeek` = mevcut yardımcılar (`Europe/Istanbul`, Pazartesi).
- DST: `istanbulDay` instant → date; hafta key tarih string — WP-146 ile uyumlu test.

---

## 5. Entegrasyon yüzeyi

### 5.1 Seçenekler

| | Analitik kart `taskList` | Ana sayfa dashboard kartı | İkisi |
|---|---|---|---|
| Keşfedilebilirlik | Flag arkasında; beta kullanıcı | Her gün ana ekran | Max |
| Motor | `grid_reflow` + `AnalyticsCardType` | `DashboardCardType` + home layout keys | İki registry |
| Risk | Stats flag/layout bozulması | Ana sayfa sıcak yüzey | Çift bakım |
| v1 efor | Orta | Orta | Yüksek |

### 5.2 Öneri

**v1: yalnız `AnalyticsCardType.taskList` (kişisel katalog)**  
- `analytics_grid_v1` flag arkasında (default kapalı → eski Stats bozulmaz).  
- Varsayılan personal layout’a **eklenmez** (kullanıcı “kart ekle” ile ekler) → mevcut 22 kart düzeni şaşırtmaz.  
- Ana sayfa kartı = **v1.1** (ayrı WP), analytics’te doğrulandıktan sonra `DashboardCardType.userTasks` + home edit.

**Neden değil sadece ana sayfa:** İstek “kartlar bölümü / analitik özelleştirme” ile uyumlu; home timer/presence riski daha yüksek.

### 5.3 UI iskeleti (kart)

```
┌─ Görevlerim ────────── [+] ─┐
│ [Günlük] [Haftalık]          │
│ ☐ 2 saat matematik           │
│ ☑ Pomodoro ×3   (üstü çizili)│
│ (boş durum: “Madde ekle”)    │
└──────────────────────────────┘
```

- Min boyut: w=3 h=3 (6 sütun grid); max w=6 h=6.  
- Ekle: bottom sheet / dialog (başlık + scope).  
- Tik: 48dp Semantics; TalkBack “tamamlandı / tamamlanmadı”.  
- Sürükle-sırala: v1 opsiyonel (sortOrder ± buton veya ReorderableListView — küçük listelerde).

### 5.4 Registry değişiklikleri (onay sonrası kod)

- `AnalyticsCardType.taskList`  
- `analytics_card_registry` builder  
- l10n title/subtitle  
- `defaultPersonalLayout` **değişmez** (bilinçli)  
- Group katalogda **yok** (`isGroupOnly = false`, personal only filter)

---

## 6. XP bağı (opsiyonel — v1 dışı)

| | |
|---|---|
| İstek | Madde tamamlayınca XP? |
| Kural | **Server-authoritative** — istemci `gamification_profiles.xp` yazamaz (0043 guard) |
| v1 | **Yok** — yalnız checklist; motivasyon görsel (tik animasyonu) |
| v1.1+ | Ledger event `user_task_completed` + günlük cap + idempotent key `(user, taskId, periodKey)` SECURITY DEFINER RPC |

Quest dict (WP-154) ile birleştirme **yapılmaz** (farklı sahiplik modeli).

---

## 7. Faz / WP dilimleme (onay sonrası)

| WP | Kapsam | SAHİP (öneri) | DOKUNMA |
|---|---|---|---|
| **WP-169** | Bu plan | `docs/features/GOREV-LISTESI-KART-PLAN.md` | kod |
| **WP-170** | Model + `UserTaskRepository` (prefs + in_memory) + periodKey + unit test | `data/models/user_task.dart`, `data/repositories/**/user_task*` | stats UI yok |
| **WP-171** | `AnalyticsCardType.taskList` + kart UI + ekle/tik/sil + l10n TR/EN/de/ar | `features/stats/analytics/**` | home dashboard, timer |
| **WP-172** (opsiyonel) | Ana sayfa kartı | `features/home/**` | analytics flag |
| **WP-173** (opsiyonel) | Cloud sync + RLS migration | `supabase/migrations/0044_*` | — |
| **WP-174** (opsiyonel) | XP ledger bağ | achievements/ledger | client XP yazma yok |

Numaralar onay anındaki “son WP”a göre kayabilir; progress’te güncellenir.

---

## 8. l10n (TR / EN / de / ar)

| Key (taslak) | TR |
|---|---|
| `taskListTitle` | Görevlerim |
| `taskListDaily` | Günlük |
| `taskListWeekly` | Haftalık |
| `taskListAdd` | Madde ekle |
| `taskListEmpty` | Bu dönem için madde yok |
| `taskListHint` | Kısa bir hedef yaz |
| `taskListHideCompleted` | Tamamlananları gizle |
| `taskListDelete` | Sil |
| `taskListCompletedSemantic` | Tamamlandı |
| `taskListIncompleteSemantic` | Tamamlanmadı |

EN/de/ar: EN baseline + de/ar (mevcut AR-DE baseline notu ile uyumlu).

---

## 9. Test planı

| Katman | Senaryo |
|---|---|
| Unit | `periodKey` günlük gece yarısı Istanbul; hafta Pazartesi sınırı; DST örnekleri |
| Unit | max 20 clamp; boş title red; toggle completedAt |
| Unit | dönem değişince yeni liste (eski key izole) |
| Widget | kart boş / dolu / gizle tamamlanan; 48dp tik |
| Integration | prefs persist kill-restart (mock prefs) |
| Cihaz | flag off → taskList yok; flag on + ekle → kalıcı; dil AR RTL |

---

## 10. Kabul kriterleri (uygulama WP’leri için)

1. Kullanıcı günlük ve haftalık madde ekleyip tikleyebilir; üstü çizili (veya onaylanan gizle modu).  
2. Gün / hafta sınırı `Europe/Istanbul` ile doğru; yeni dönemde beklenen liste davranışı (karar §4).  
3. `analytics_grid_v1=false` iken Stats **birebir** eski; layout default bozulmaz.  
4. `flutter analyze` 0; ilgili testler yeşil.  
5. Repository çift (in_memory + supabase ailesi).  
6. XP istemcide yazılmaz.  
7. l10n TR/EN/de/ar key parity.

---

## 11. Riskler

| Risk | Azaltma |
|---|---|
| Gün/hafta sınırı bug | Tek yardımcı `istanbulDay`/`startOfWeek`; birim test |
| Offline | v1 prefs zaten offline; cloud sonra |
| Mevcut ızgara/flag bozulması | Yeni enum + default layout’a ekleme; flag arkasında |
| Quest UI karışıklığı | Farklı kopya: “Görevlerim” vs sistem “Görevler” |
| Prefs şişmesi | Eski periodKey TTL / max 8 period sakla |
| Ana sayfa + stats çift kaynak | v1 tek yüzey (analytics) |

---

## 12. Açık ürün kararları (onayda işaretle)

1. **Tamamlanınca:** ☐ strikethrough alta · ☐ listeden düş · ☐ gizle switch  
2. **Dönem geçişi:** ☐ hard sıfırla · ☐ tamamlanmayanı taşı · ☐ arşiv UI  
3. **v1 yüzey:** ☐ yalnız analytics kart (öneri) · ☐ yalnız home · ☐ ikisi  
4. **Cloud sync v1?** ☐ hayır (öneri) · ☐ evet (migration)  
5. **XP v1?** ☐ hayır (öneri) · ☐ ledger taslağı hemen  

---

## 13. Bitiş

- Plan dosyası: `docs/features/GOREV-LISTESI-KART-PLAN.md`  
- **Kod yazılmadı.**  
- Sonraki adım: sahip/ürün onayı → WP-170+ claim.

*Kanıt etiketi: `Kodda doğrulandı` (mevcut ızgara/quest/istanbul yardımcıları okuma) · uygulama `Ürün kararı gerekiyor`.*
