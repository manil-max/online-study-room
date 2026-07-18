# beta-v30 — Sahip onay tick listesi

| Alan | Değer |
|---|---|
| Tag | `beta-v30` |
| versionName / Code | `1.0.30` / **30** |
| Kanal | GitHub **beta** (prerelease APK) |
| Tarih | 2026-07-18 |
| Önkoşul SQL | **0039–0043 canlıda uygulandı** (sahip ✓) |
| Ayrıntılı adımlar | [`BETA-TEST-KILAVUZU.md`](./BETA-TEST-KILAVUZU.md) |

> Her satırı cihazda dene → **☐** → **[x]** yap. Bloker varsa not yaz.  
> **Stable değil** — sadece beta onayı.

---

## 0. Kurulum

| # | Madde | Sonuç |
|---|---|---|
| 0.1 | GitHub Release `beta-v30` APK indi / yüklendi | ☐ |
| 0.2 | Launcher: **Odak Kampı BETA** (stable ile karışmaz) | ☐ |
| 0.3 | Giriş kalıcı (InMemory’ye düşmez) | ☐ |
| 0.4 | Ayarlar → **Yeni istatistik ekranı (Beta)** **AÇ** | ☐ |

---

## 1. Analitik ızgara (flag AÇIK)

| # | Madde | Sonuç | Not |
|---|---|---|---|
| 1.1 | İstatistikler ızgara render (crash yok) | ☐ | |
| 1.2 | Kart ekle / çıkar / boyut | ☐ | |
| 1.3 | Layout kalıcı (kill → reopen) | ☐ | |
| 1.4 | Dönem: bugün / hafta / ay / **yıl** / **özel** | ☐ | |
| 1.5 | “Geçen döneme göre” kıyas | ☐ | |
| 1.6 | Flag **KAPA** → eski ListView birebir | ☐ | |

---

## 2. Grup analitiği (0039–0041)

| # | Madde | Sonuç | Not |
|---|---|---|---|
| 2.1 | Üye hesap: grup katkı / liderlik kartları veri | ☐ | |
| 2.2 | Non-üye: yetkisiz/boş, crash yok | ☐ | |

---

## 3. Dil / RTL (WP-155)

| # | Madde | Sonuç | Not |
|---|---|---|---|
| 3.1 | Arapça + RTL hizalama | ☐ | |
| 3.2 | Almanca dil seçimi | ☐ | |
| 3.3 | Türkçe’ye dönüş OK | ☐ | |

---

## 4. Profil paketi (WP-151/152/154/166)

| # | Madde | Sonuç | Not |
|---|---|---|---|
| 4.1 | Seviye / görevler / kozmetik görünür | ☐ | |
| 4.2 | Onboarding (yeni veya reset hesap) | ☐ | |
| 4.3 | Verilerimi dışa aktar → JSON / paylaşım | ☐ | |

---

## 5. Widget / bildirim / SSOT (WP-134–137)

| # | Madde | Sonuç | Not |
|---|---|---|---|
| 5.1 | Widget canlı süre (Chronometer) | ☐ | |
| 5.2 | Bildirim başlat / mola / durdur | ☐ | |
| 5.3 | Kill sonrası süre uyumu (SSOT) | ☐ | |

---

## 6. Geri bildirim (WP-168)

| # | Madde | Sonuç | Not |
|---|---|---|---|
| 6.1 | Düz öneri (eksiz) → başarı + DB satırı | ☐ | |
| 6.2 | Ekli görsel (bucket varsa) | ☐ | |
| 6.3 | Oturum yoksa **net** mesaj (jenerik değil) | ☐ | |

---

## 7. Hızlı duman

| # | Madde | Sonuç | Not |
|---|---|---|---|
| 7.1 | Açık / koyu tema | ☐ | |
| 7.2 | Airplane mode kısa → crash yok | ☐ | |
| 7.3 | textScale ~1.3 makul | ☐ | |

---

## İmza

| | |
|---|---|
| Genel | ☐ Beta **GO** · ☐ GO with notes · ☐ **NO-GO** |
| Blokerler | |
| Cihaz / Android | |
| İmza / tarih | |

---

## Ajan notu

- Push: `main` + tag `beta-v30` → CI Release APK (`githubBeta`).
- Migrations canlı: sahip uyguladı (0039–0043).
- WP-169 görev listesi kartı: **plan onayı ayrı**; bu betada yok.
