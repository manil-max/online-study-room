# Ajan Kullanım Kılavuzu (senin için tek sayfa)

> Ajanları (Claude / Gemini / Codex) nasıl süreceğinin kısa el kitabı. Güncel WP listesi her zaman `progress.md`'dedir. Sistem kuralları: `.agents/AGENTS.md`.

## 1. Prompt kalıpların (kopyala-yapıştır)

| Ne için | Yazacağın prompt |
|---|---|
| Kısa istekten plan | `planner'ı oku, şunu planla: <tek cümle istek>` |
| Fazı WP'lere bölme | `planner'ı oku, Saat programını WP'lere böl` |
| İş yaptırma | `worker'ı oku, WP-N'yi yap` |
| WP dışı küçük iş (kod ortaksa) | `worker'ı oku` + ne istediğin (çakışma kontrolü çalışsın) |
| WP dışı, koda dokunmayan iş | Doğrudan yaz (araştır, açıkla, düzelt) |

**Not:** "worker'ı oku" tek başına ajanı kurallara yönlendirir ama hangi işi yapacağını bilmez. **Her zaman WP numarasını ekle:** `worker'ı oku, WP-44'ü yap`.

## 2. Ajan sana çakışma sorusu sorarsa
Üç cevaptan biri:
- `WP-M bitene kadar bekle`
- `kapsamı sadece <X dosya/alan> ile sınırla, başla`
- `onun yerine WP-K'yı yap`

## 3. Senin (insan) kapıların — ajan bunları KAPATAMAZ
Ajan en fazla **"otomatik test geçti"**ye kadar götürür. Gerisi sende:
1. **Dağıtım** — `progress.md`'den WP seç, bağımlılığa uy, ayrı ajanlara ayrık WP ver.
2. **Çakışma kararı** — ajan uyarırsa yukarıdaki 3 cevaptan biri.
3. **Gerçek cihaz QA + kabul** — APK'yı Samsung/Pixel'de dene; beklediğin gibiyse kabul, değilse geri gönder.
4. **Canlı Supabase migration** — WP-38'in verdiği SQL'i SQL Editor'da sırayla uygula.
6. **Ürün kararları + sürüm** — `Ürün kararı gerekiyor` etiketliler ve sürüm etiketi (`git tag vN && git push origin vN`).

## 4. Günlük ritim
1. `progress.md` → hazır/bağımsız WP'leri gör.
2. Her ajana bir WP: `worker'ı oku, WP-N'yi yap`.
3. Uyarı gelirse karar ver; bitince cihazda dene → kabul.
4. Kabulde çalışma kaydını kapat; migration gerekiyorsa uygula.
5. Yeni iş lazımsa: `planner'ı oku, şunu planla: …`.

## 5. Hangi ajana hangi iş (model)
`progress.md` her WP'de öneriyor:
- **🔴 Opus** → native / riskli / büyük (ör. WP-40–43).
- **🟣 Pro** → orta (ör. WP-38/39).
- **🔵 Sonnet** → küçük UI (ör. WP-44/45).
En güçlü modeli en riskli işe ver.

## 6. Şu an dağıtıma hazır (anlık — güncel liste `progress.md`)
- **Hemen paralel (çakışmasız):** WP-37, WP-38, WP-44, WP-45.
- **V8-A zinciri:** WP-40 (temel) → sonra WP-41 ve WP-42 (ikisi sırayla, paralel değil) → sonra WP-43.

## 7. Sürüm
v7 yayında (özellik sürümü). İlk **kalite-kapılı** stable önerisi **v8 "Güven Sürümü"** — kalite kapısından (AGENTS.md §3) geçmeden numara kesinleşmez.
