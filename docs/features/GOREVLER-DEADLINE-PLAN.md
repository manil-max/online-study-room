# Görevler — Deadline modeli (WP-196→200)

| Alan | Değer |
|---|---|
| Tarih | 2026-07-18 |
| Kaynak | WP-188 yeniden tasarım · ürün sahibi onayı |
| Donuk | Timer / widget / FGS / XP backend / Home dashboard **motoru** |

---

## 1. Kilitli ürün tasarımı

| Kural | Değer |
|---|---|
| Görev | Serbest metin (çalışmaya bağlı değil) |
| Kapsam kutuları | **YOK** (günlük/haftalık sabit kutu yok) |
| Bitiş | Her görevin kendi `dueAt` (nullable = süresiz) |
| Giriş (a) | **Tarih** → o günün sonu 23:59 Europe/Istanbul |
| Giriş (b) | **Kalan süre** → `now + Duration` |
| Sıra | En yakın bitiş üstte; süresiz en altta |
| Renk | Kalan süre spektrumu (uzak sakin → sarı → turuncu → kırmızı; gecikti koyu kırmızı; süresiz nötr) |
| Tekrar | **v1 yok** (tek seferlik) |
| Tamamlanınca | Üstü çizili + soluk → aktif listeden düşer → “tamamlananlar” |
| Gecikti | Silinmez; aktifte üstte kırmızı “gecikti” |
| Home kartı | Gör + renk + işaretle (**ekleme yok**) |
| Araçlar | Tam CRUD yönetimi |

---

## 2. Model (`UserTask`)

```
id, title, dueAt?, done (completed), completedAt?, createdAt, sortOrder
```

- `TaskScope` / periodKey **kaldırıldı**
- Prefs: `user_tasks_v2.$userKey` (tek liste)
- Eski `user_tasks_v1.*` **yoksayılır**

---

## 3. Faz haritası

| WP | Faz | Kapsam |
|---|---|---|
| **196** | F0 | Plan + model + repo (tek liste) |
| **197** | F1 | dueAt hesap + sıralama + renk motoru |
| **198** | F2 | Saat→Araçlar; Görevler alt-sekme CRUD |
| **199** | F3 | Home kartı (gör/renk/işaretle) |
| **200** | F4 | Cila (gecikti rozeti, a11y, smoke) |

---

## 4. UI yüzeyleri

| Yüzey | Yetki |
|---|---|
| Alt-nav “Araçlar” (eski Saat) | Icon strip: Saat · Alarm · Timer · Krono · Dünya · **Görevler** |
| Araçlar → Görevler | Ekle (tarih veya süre), düzenle, sil, işaretle, tamamlananlar |
| Home dashboard kartı | Yalnız aktif liste; en yakın N; tik |

---

## 5. XP / sunucu

v1: **XP yok**, sunucu tablosu yok (prefs mirror).
