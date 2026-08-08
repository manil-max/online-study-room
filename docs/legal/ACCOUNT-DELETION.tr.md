# Hesap ve Veri Silme — Focus Camp / Odak Kampı

**Sürüm:** 2026-08-08 · **Uygulama:** Focus Camp (Türkçe cihazlarda **Odak Kampı**)
· Paket adı: `com.manilmax.online_study_room`

Bu sayfa hesabını ve verilerini nasıl sildireceğini anlatır.

## Uygulamadan silme

1. **Ayarlar → Hesabımı yönet → Hesabı sil** yolunu izle.
2. Güvenlik için şifreni yeniden sorar.
3. İstek kaydedilir ve **14 günlük geri alma penceresi** başlar.
4. Bu 14 gün içinde tekrar giriş yaparsan istek **iptal** olur ve hesabın
   olduğu gibi devam eder.
5. Süre dolduğunda hesabın ve kişisel verilerin sunucudan kalıcı olarak
   silinir. Silme işini zamanlanmış bir sunucu görevi yürütür; elle bir onay
   beklemez.

## Uygulamaya giremiyorsan

Uygulamaya erişemiyorsan silme talebini mağaza sayfasındaki geliştirici
e-posta adresine yazabilirsin. Talebi işleme almak için hesabının e-posta
adresini doğrulamamız gerekir.

## Silinen veriler

- Hesap kaydı ve kimlik doğrulama bilgisi (e-posta)
- Profil: görünen ad, avatar, kamp hayvanı, tercihler
- Çalışma oturumları ve bunlara bağlı istatistik/XP kayıtları
- Grup üyelikleri
- Kendi açtığın destek biletleri, sorduğun sorular ve gönderdiğin şikâyetler
- Yüklediğin bütün dosyalar: profil fotoğrafın (`avatars`), destek ve geri
  bildirim biletlerine eklediğin fotoğraflar (`feedback_attachments`) ve
  şikâyet bildirirken eklediğin fotoğraflar (`report_attachments`)
- Senden sonra üyesi kalmayan ve bu yüzden silinen grupların fotoğrafları
  (`group-avatars`)

## Silinmeyen veya takma kimliğe çevrilen veriler

Bazı kayıtlar hesap silinse de **kimliğinden koparılarak** kalır. Bunun sebebi
diğer kullanıcıların güvenliğidir: bir moderasyon kararının veya destek
kaydının kime ait olduğu tamamen silinirse, kötüye kullanım geçmişi de silinmiş
olur.

- Moderasyon ve yönetim denetim kayıtları: kimlik alanı boşaltılır, yerine
  **geri çevrilemez bir özet (hash)** kalır. Ham kimlik gider.
- Destek/geri bildirim kayıtları: aynı şekilde kimlikten koparılır.
- Grup sohbet mesajları: gönderen kimliği düşer; mesaj grup geçmişinde
  kimliksiz kalır.
- Devam eden grupların fotoğrafı (`group-avatars`): bir grubun fotoğrafını sen
  yüklediğin için bile olsa o dosya **gruba** aittir, sana değil. Hesabın
  silindikten sonra grup başka üyeleriyle devam ediyorsa fotoğrafı da kalır ve
  grup silinene kadar durur. Bu dosyanın yolunda senin kimliğin geçmez,
  grubun kimliği geçer. Grup senden sonra üyesiz kalırsa hem grup hem
  fotoğrafı silinir.
- Yasal olarak tutulması gereken kayıtlar, gerektiği süre boyunca saklanır.

Bu kayıtlardan kimliğin geri üretilemez.

## Süre

Geri alma penceresi **14 gündür**. Pencere dolduktan sonra kalıcı silme
zamanlanmış görevle yürütülür.

## İletişim

Uygulama içi **Ayarlar → Geri bildirim** ya da mağaza sayfasındaki geliştirici
e-posta adresi.
