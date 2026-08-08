# Ajan Kullanım Kılavuzu (senin için tek sayfa)

> Ajanları nasıl süreceğinin kısa el kitabı. Güncel WP listesi her zaman `progress.md`'dedir.
> Sistem kuralları: `.agents/AGENTS.md`.

## 1. Çalışma modeli — tek muhatap

**Sen yalnız lider ajanla konuşursun.** Lider işi böler, alt ajanları kendisi açar,
çıktılarını denetler, testi koşturur, `progress.md`'yi yazar.

Yani artık **birden fazla sohbete tek tek prompt kopyalamıyorsun.** Bir tane söylüyorsun,
lider dağıtıyor.

| Eskiden | Şimdi |
|---|---|
| 3–4 ayrı sohbet açardın | Tek sohbet |
| Her birine ayrı prompt yapıştırırdın | Lidere tek cümle |
| Ajanlar birbirini "çakışma var mı" diye sorardı | Lider zaten sıraya koyar |
| Sana çakışma sorusu gelirdi | Gelmez — lider çözer |

## 2. Prompt kalıpların (kopyala-yapıştır)

| Ne için | Yazacağın prompt |
|---|---|
| Kısa istekten plan | `planner'ı oku, şunu planla: <tek cümle istek>` |
| İş yaptırma | `worker'ı oku, WP-N'yi yap` |
| Birden çok iş | `WP-N, WP-M, WP-K'yı yap` — lider dalgayı kendi kurar |
| Test | `tester'ı oku ve teste başla` |
| Koda dokunmayan iş | Doğrudan yaz (araştır, açıkla, raporla) |

## 3. Senin (insan) kapıların — ajan bunları KAPATAMAZ

Ajan en fazla **"otomatik test geçti"**ye kadar götürür. Gerisi sende:

1. **Gerçek cihaz QA + kabul** — APK'yı telefonda dene; beklediğin gibiyse kabul et,
   değilse geri gönder.
2. **Ürün kararları** — `Ürün kararı gerekiyor` etiketli maddeler.
3. **Yayın tetiği** — migration apply + tag + release yalnız sen
   **"cihaz testine gönder"** (veya net eşdeğeri) dediğinde başlar.
   Sen demeden lider bunlara dokunmaz.

## 4. Günlük ritim

1. Lidere ne istediğini söyle (tek cümle yeter).
2. Lider planlar → onaylarsın.
3. Lider alt ajanlara dağıtır, bitince **birleşik testi** koşturur ve sana sonucu
   rakamla söyler ("15 kapı, 0 kırmızı, 2 atlandı").
4. Sen cihazda denersin → kabul edersin.
5. Yayın istiyorsan tetik cümlesini yazarsın.

## 5. Lider sana rapor verirken neye bakacaksın

- **Rakam var mı?** "Testler geçti" yetmez; kaç kapı, kaçı kırmızı, kaçı atlandı.
- **Atlanan kapı yeşil değildir.** Sebebi yazılmalı.
- **Kanıt etiketi var mı?** `Kodda doğrulandı` / `Cihazda doğrulanmalı` /
  `Ürün kararı gerekiyor`.
- **Cihazda neye bakacağın yazıyor mu?** Yazmıyorsa iste.

## 6. Bilinen boşluk (dürüst kayıt)

Android tarafında **hiçbir gerçek çalışma zamanı testi yok.** Entegrasyon testi Windows'ta
koşuyor, native testler JVM'de sahte veriyle koşuyor. v58'deki geri sayım çökmesi tam bu
boşluktan geçti. Emülatör kapısı planlı iştir (`docs/TEST-SISTEMI.md`).

## 7. Sürüm

Güncel sürüm ve yayın zinciri `progress.md` → **Proje Gerçekleri** bölümündedir.
Buraya sabit sürüm numarası yazma — eskiyor.
