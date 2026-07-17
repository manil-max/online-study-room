# Veri Saklama Takvimi — Odak Kampı

**Sürüm:** 2026-07-17  
**Kaynak karar:** `docs/HESAP-SILME-RETENTION-KARARI.md` §0 önerilen varsayılanlar (ürün onayıyla uygulanır).

| Veri | Soft / grace | Hard / anonimleştirme |
|---|---|---|
| Hesap (auth + profil) | Silme isteği + **14 gün** geri alma | Auth user + PII purge |
| Çalışma oturumları | Grace süresince saklanır | Kullanıcıya bağlı silinir |
| Grup üyeliği | Soft leave zaten var | Üyelik kapanır; grup devri/silme kuralı |
| Sohbet | Grace | “Silinmiş üye” / scrub (ürün kuralı) |
| XP / ledger | Grace | Kullanıcı satırları |
| Feedback | Destek süreci + ~90 gün | PII scrub |
| Admin audit | ≥1 yıl | Hash / minimum kayıt |
| Avatar storage | Grace | Object silme |
| Aylık e-posta opt-in | İstek anında false | Adres hard’da silinir |
| Sentry | Olay saklama süresi sağlayıcı ayarı | PII gönderilmez (tasarım) |
| Cihaz prefs / offline | Logout / wipe | Yerel silme |

**Not:** Hard-delete pipeline (Edge/cron) WP-112–114 tamamlanana kadar “planlanan”dır; bu belge ürün hedefini tarif eder.
