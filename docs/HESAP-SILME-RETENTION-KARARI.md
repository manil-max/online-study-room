# Hesap Silme ve Veri Saklama Politikası — Karar Kaydı (WP-66)

> **Durum:** §0 varsayılanları **uygulama varsayılanı kabul edildi** (kullanıcı 2026-07-17 “bitene kadar” programı) · migration `0037_account_deletion_core.sql`  
> **Kanıt:** Veri envanteri `Kodda doğrulandı` · implementasyon WP-112+  
> **Not:** Prod SQL uygulaması WP-121 kapısı; hard-delete Edge WP-113

**Paralel ajanlar:** Claude WP-65 (`docs/AYLIK-RAPOR-KARAR.md` e-posta); Codex WP-68 widget. Bu belge yalnız retention/silme politikasıdır.

---

## 0. Özet (demo için tek bakış)

| Karar | Önerilen varsayılan (onaylanana kadar taslak) |
|---|---|
| Kullanıcıya “Hesabımı sil” | **Evet** — Ayarlar > Hesap |
| Model | **Soft-delete isteği → geri alma penceresi → planlı hard-delete** |
| Geri alma süresi | **14 gün** (Europe/Istanbul takvim günü) |
| Kalıcı silme onayı | Kullanıcı: onay metni + e-posta/şifre yeniden doğrulama; Admin: yalnız super-admin + audit |
| Export | Silmeden önce **isteğe bağlı JSON export** (oturumlar + profil özeti) |
| Soft-delete = silindi mi? | **Hayır** — hesap “silme bekliyor”; 14 gün sonra hard-delete |
| WP-65 e-posta | Silme isteği sonrası **rapor/opt-in gönderimi durur**; soft dönemde adres saklanır, hard’da silinir |

Bu varsayılanlar demo sonunda “OK” denebilir; red ise §5 alternatiflerinden seçilir. **Migration bu WP’de yok.**

---

## 1. Problem (neden karar kartı)

Backlog: hesap silme ilk teslimden bilinçli çıkarıldı; soft-delete yönü (ör. `group_members.left_at`) var ama **hesap düzeyi** silme, geri alma, saklama ve kalıcı silme yetkisi yazılı değil.  
Şemada birçok tablo `auth.users (id) on delete cascade` — Auth kullanıcısı silinirse bağlı satırlar **hemen** gider. Kontrollü “sil” UX’i olmadan hard Auth delete risklidir.

---

## 2. Veri envanteri (`Kodda doğrulandı`)

Kaynak: `supabase/migrations` (öz. `0001`, `0002`, `0017–0025`, storage `avatars` / feedback).

### 2.1 Sınıflar

| Sınıf | Örnek tablolar / yüzey | Kişisel mi? | Not |
|---|---|---|---|
| **A. Kimlik** | `auth.users`, `profiles` (display_name, avatar_url, animal, …) | Evet | `profiles.id` → `auth.users` CASCADE |
| **B. Çalışma içeriği** | `study_sessions`, `subjects`, yerel alarm/timer (cihaz) | Evet | İstatistik kaynağı |
| **C. Sosyal / grup** | `groups` (created_by), `group_members` (+ `left_at`), `class_messages`, `nudges`, `presence` | Karma | Üyelik soft-leave var; mesajlar grup bağlamında |
| **D. Oyunlaştırma** | `gamification_profiles`, `user_achievements`, `xp_ledger`, `achievements_dict` | Kısmen | `xp_ledger` append-only, istemci yazamaz |
| **E. Bildirim / hatırlatıcı** | `study_reminders`, `announcement_reads`, bildirim tercihleri | Evet | |
| **F. Destek / admin** | `feedback_tickets` (+ attachments storage), `feedback_ticket_notes`, `admin_audit_logs`, `admin_notifications`, `app_admins` | Karma | Denetim izi hukuki/operasyonel |
| **G. Storage** | bucket `avatars` (`<uid>/…`), feedback ekleri | Evet | Public avatar okuma politikası |
| **H. İstemci-yerel** | SharedPreferences, offline outbox, widget snapshot | Evet | Sunucu silinse bile cihazda kalabilir → logout/wipe |
| **I. Gelecek e-posta (WP-65)** | Opt-in, gönderim logu (henüz yok) | Evet | Bu politika ile hizalanmalı |

### 2.2 Mevcut silme davranışı (kod/şema)

| Davranış | Durum |
|---|---|
| Grup ayrılma | `group_members.left_at` set (soft) — hard row silme değil |
| Oturum silme | Kullanıcı kendi `study_sessions` satırını silebilir (RLS) |
| Auth user DELETE | Bağlı çoğu satır **CASCADE** (ani hard wipe) |
| Uygulama içi “Hesabı sil” | **Yok** (bilinçli ertelendi) |
| Admin hesap silme UI | **Yok** (tanımlı yetki yok) |

---

## 3. Alternatif modeller

| Model | Nasıl | Artı | Eksi | Öneri |
|---|---|---|---|---|
| **M1 — Anında hard-delete** | Auth user sil → CASCADE | Basit, “gerçekten gitti” | Geri alınamaz; hata/tıklama felaketi; destek yok | ❌ |
| **M2 — Yalnız soft-delete** | `profiles.deleted_at`, login engeli; veri kalır | Geri alınabilir; audit kolay | “Silindi” iddiası zayıf; depolama/KVKK riski | ⚠️ geçici |
| **M3 — Soft + gecikmeli hard (önerilen)** | İstek → 14g grace → job hard-delete | Geri alma + gerçek silme | Cron/Edge Function + durum makinesi | ✅ |
| **M4 — Anonimleştirme** | PII scrub, oturum süreleri grup istatistiğinde kalır | Grup geçmişi bozulmaz | XP/mesaj metni politikası karmaşık | Grup metni için **ek** kural |

**Seçim (taslak):** **M3**, grup sohbetinde kullanıcı satırları için hard aşamada **M4 parçası**: `class_messages` içeriği “Silinmiş üye” + boş metin veya mesaj silme (ürün: §5.3).

---

## 4. Önerilen yaşam döngüsü (M3)

```
Aktif
  → kullanıcı "Hesabımı sil" + yeniden doğrulama
  → Soft: deletion_requested_at = now (TR)
       • oturum açma engeli (veya yalnız "geri al" ekranı)
       • WP-65 mail / pazarlama kapalı
       • profil sosyal görünürlük kapalı (veya "siliniyor")
  → 14 gün içinde "Geri al" → Aktif
  → 14 gün dolunca (Europe/Istanbul gün sonu)
  → Hard pipeline (service-role, sunucu):
       1) storage avatar + feedback ekleri (sahip uid)
       2) opsiyonel export arşivi silinir
       3) auth.admin.deleteUser → CASCADE
       4) admin_audit_logs'a "account_hard_deleted" (PII’siz id hash)
```

### 4.1 Saklama süreleri (sınıf bazında)

| Sınıf | Soft dönemde | Hard sonrası hedef | Not |
|---|---|---|---|
| A Kimlik | Saklanır, login kısıtlı | Silinir | |
| B Oturumlar | Saklanır (export için) | CASCADE silinir | |
| C Grup üyelik | `left_at` veya silme bayrağı | Üyelik silinir | |
| C Mesajlar | Kalır | Anonimleştir veya sil (§5.3) | |
| D XP ledger | Kalır | CASCADE | Append-only; hard ile gider |
| E Hatırlatıcı | Pasif | Silinir | |
| F Feedback | Destek ticket açık kalabilir | **+90 gün** ticket sonra anonim/sil | Operasyon |
| F Admin audit | Saklanır | **≥ 1 yıl** meta (uid hash), PII yok | |
| G Storage | Kalır | Hard’da object delete | |
| H Cihaz | Logout + local wipe talimatı | Kullanıcı cihazı | |
| I E-posta log (WP-65) | Gönderim yok | Hard’da log retention **≤ 90 gün** sonra sil | WP-65 ile aynı sayı |

### 4.2 Yetkiler

| Aktör | Soft istek | Geri al | Hard’ı öne çek | Hard engelle |
|---|---|---|---|---|
| Kullanıcı (hesap sahibi) | Evet | Evet (14g) | Hayır (otomatik) | Geri al ile |
| Super-admin | Destek talebiyle evet | Evet | Evet (gerekçe + 2. onay) | Evet |
| Grup admini | Hayır (başkasının hesabı) | Hayır | Hayır | Hayır |
| Service-role | Yalnız sunucu job | — | Planlı job | — |

**UI metin (TR taslak):**  
“Hesabınız 14 gün boyunca askıya alınır. Bu sürede geri alabilirsiniz. Süre bitince çalışma kayıtlarınız, profiliniz ve rozetleriniz kalıcı silinir. Bu işlem geri alınamaz.”

### 4.3 Export (opsiyonel ama önerilen)

- Format: JSON (sessions, subjects, profile display fields) — e-posta/token yok  
- Tetik: silme diyalogunda “Önce verilerimi indir”  
- Implementasyon sonraki WP (Edge Function veya imzalı indirme)

---

## 5. Ürün seçim tablosu (onay kutuları)

Demo / ürün sahibi işaretler. Boş = taslak varsayılan (§0) geçerli sayılmaz; **yazılı seçim** gerekir.

### 5.1 Model

- [ ] M3 Soft + 14g + hard (**önerilen**)
- [ ] M3 ama grace: **7 gün**
- [ ] M3 ama grace: **30 gün**
- [ ] M2 yalnız soft (hard yok — önerilmez)
- [ ] M1 anında hard (önerilmez)

### 5.2 Geri alma / doğrulama

- [ ] Silme için **şifre veya e-posta magic re-auth** zorunlu (**önerilen**)
- [ ] Yalnız “SİL” yazarak onay (zayıf)
- [ ] Export zorunlu / isteğe bağlı / yok → **isteğe bağlı (önerilen)**

### 5.3 Grup mesajları hard sonrası

- [ ] Mesaj satırını sil (**önerilen** sade)
- [ ] Metni scrub + “Silinmiş üye”
- [ ] Mesajları olduğu gibi bırak (PII riski — önerilmez)

### 5.4 Admin

- [ ] Super-admin hard öne çekebilir + audit (**önerilen**)
- [ ] Admin asla silemez; yalnız kullanıcı self-serve

### 5.5 WP-65 hizası

- [ ] Soft’ta tüm e-posta gönderimi durur (**önerilen**)
- [ ] Yalnız pazarlama durur; sistem maili devam (ayrı liste gerekir)

---

## 6. Güvenlik ve RLS ilkeleri (implementasyon WP’sine taşınır)

1. Soft bayrak: örn. `profiles.deletion_requested_at timestamptz null` — istemci yalnız **kendi** satırına RPC ile yazar.  
2. Hard delete: **yalnız** SECURITY DEFINER / Edge + service-role; service-role istemciye/repoya girmez.  
3. `xp_ledger` istemciden DELETE yok (mevcut revoke korunur); hard Auth cascade veya sunucu.  
4. Audit: `admin_audit_logs` — action, actor_id, target_user_hash, timestamp; e-posta/ham ad yok.  
5. Rate limit: silme isteği günde 1.  
6. Çocuk hesabı / yasal yaş: ürün kararı yoksa “genel kullanıcı” varsayılır; hukuki danışmanlık bu kartın dışı.

---

## 7. Sonraki implementasyon WP’si (plan iskeleti)

| Dilim | Kapsam | Not |
|---|---|---|
| **WP-66-A** (ör. gelecek numara) | Migration: `deletion_requested_at`, RPC `request_account_deletion` / `cancel_account_deletion`, RLS | Geri alma SQL notu zorunlu |
| **WP-66-B** | Edge/cron: 14g hard pipeline + storage wipe | Staging dry-run |
| **WP-66-C** | Flutter Ayarlar UI + TR metin + export | Offline-first dikkat |
| **WP-66-D** | Admin destek ekranı (super-admin) | Audit |

**Geri alma (rollback) notu (A için):** kolon/RPC drop; bekleyen soft istekler listelenip manuel temizlenir.

Bu dilimler **bu WP’de kodlanmaz.**

---

## 8. WP-65 ile tutarlılık

| Konu | WP-66 taslağı |
|---|---|
| Opt-in mail | Soft silme → gönderim durur |
| Adres saklama | Soft: gerekli; hard: sil |
| Aylık rapor içeriği | Hard sonrası üretilmez |
| Sağlayıcı secret | Bu belgeye girmez (WP-65) |

Claude WP-65 belgesi yazıldığında §4.1 “I” satırı ve §5.5 ile çapraz kontrol edilir; çelişki olursa **daha sıkı** (daha az saklama) kazanır.

---

## 9. Kabul kontrol listesi (WP-66)

- [x] Veri envanteri sınıf sınıf yazıldı  
- [x] Soft/hard alternatifleri karşılaştırıldı  
- [x] Önerilen model + süre + yetki taslağı var  
- [x] Implementasyon dilimleri planlandı (kod yok)  
- [ ] Ürün sahibi §5 kutularını işaretledi / “§0 varsayılan OK” dedi  
- [ ] Onaydan sonra numaralı güvenlik WP’si `progress.md`’ye açılır  

**Etiket:** karar metni `Kodda doğrulandı` (envanter); nihai politika `Ürün kararı gerekiyor`.

---

## 10. Değişiklik günlüğü

| Tarih | Not |
|---|---|
| 2026-07-14 | WP-66 ilk karar taslağı (Grok). Migration/Auth/app kodu yok. Paralel: Claude WP-65, Codex WP-68. |
