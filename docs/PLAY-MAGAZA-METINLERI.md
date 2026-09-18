# Play mağaza metinleri — WP-839

Sahip Play Console → **Mağazada görünme → Mağaza girişi** altında dil ekleyip aşağıdaki
metinleri yapıştırır. Türkçe (`tr-TR`) şu an **yok**, İngilizce varsayılan dildir.

Uzunluk sınırları Play tarafından zorunlu tutulur: uygulama adı **30**, kısa açıklama **80**,
tam açıklama **4000** karakter. Aşağıdaki metinlerin sayıları parantezde yazılı.

> Metinlerdeki her iddia uygulamada **var olan** bir özelliğe karşılık gelir: sayaç ve odak
> seansı, gruplar, kamp ateşi (grup canlı durumu), liderlik tablosu, rozetler, istatistikler,
> alarm/saat, ana ekran kartları, ana ekran widget'ları, çevrimdışı çalışma, Google ile giriş.
> Yeni bir özellik uydurulmadı; mağaza metni ürünün önünde gitmez.

---

## Türkçe (`tr-TR`)

### Uygulama adı (30)
```
Focus Camp: Odak ve Çalışma
```
(27 karakter)

### Kısa açıklama (80)
```
Odak sayacı, çalışma grupları ve istatistiklerle çalışma alışkanlığını kur.
```
(74 karakter)

### Tam açıklama (4000)
```
Focus Camp, çalışma sürenizi ölçen ve düzenli çalışmayı bir alışkanlığa çeviren bir odak uygulamasıdır. Tek başına çalışın ya da arkadaşlarınızla aynı kamp ateşinin etrafında toplanın.

ODAK SAYACI
• Dersinizi seçin, sayacı başlatın, uygulamayı kapatsanız bile süre işlemeye devam etsin.
• Bildirimden kalan süreyi görün, tek dokunuşla duraklatın.
• Günlük hedefinizi belirleyin, gün içindeki ilerlemenizi anlık izleyin.

BİRLİKTE ÇALIŞMA
• Grup kurun ya da davet koduyla bir gruba katılın.
• Kamp ateşinde kimin o an çalıştığını görün; yalnız çalışırken bile yanınızda biri olsun.
• Grup liderlik tablosuyla haftanın temposunu takip edin.

İLERLEMENİZİ GÖRÜN
• Günlük, haftalık ve aylık istatistikler; ders bazında dağılım.
• Hangi saatlerde daha verimli olduğunuzu gösteren ısı haritası.
• Seri takibi ve kazanılan rozetler; emeğiniz kayıt altında kalsın.

ANA EKRANINIZ SİZE AİT
• Kartları ekleyin, taşıyın, boyutlandırın; panonuzu kendinize göre kurun.
• Telefonunuzun ana ekranına widget ekleyin, uygulamayı açmadan süreyi görün.
• Onlarca hazır tema arasından seçin; koyu ve açık tema desteklenir.

SAAT VE GÖREVLER
• Alarm ve zamanlayıcılar, sınav geri sayımı, görev listesi.
• Ders çalışma düzeninizi tek uygulamada toplayın.

BAĞLANTI KOPSA DA ÇALIŞIR
• İnternet olmadan da sayaç işler; bağlantı gelince veriniz eşitlenir.
• Aynı hesapla birden fazla cihaz kullanabilirsiniz.

HESAP
• E-posta ve şifreyle ya da Google hesabınızla tek dokunuşla girin.
• Verilerinizi dilediğiniz zaman silebilirsiniz; hesap silme uygulama içinden yapılır.

Focus Camp öğrenciler, sınava hazırlananlar ve düzenli çalışmak isteyen herkes için tasarlandı. Reklam yok, dikkat dağıtan bildirim yok; sadece siz ve çalışma süreniz.

Gizlilik politikası: https://manil-max.github.io/online-study-room/legal/privacy-tr.html
Kullanım koşulları: https://manil-max.github.io/online-study-room/legal/terms-tr.html
```
(yaklaşık 1750 karakter)

---

## İngilizce (`en-US`) — mevcut sayfanın karşılığı

Sahip mevcut İngilizce metni beğeniyorsa değiştirmesine gerek yok. Değiştirmek isterse
Türkçenin birebir karşılığı:

### Uygulama adı (30)
```
Focus Camp: Study Timer
```

### Kısa açıklama (80)
```
Build a study habit with a focus timer, study groups and real statistics.
```

### Tam açıklama
Türkçe metnin çevirisi; başlıklar: FOCUS TIMER · STUDY TOGETHER · SEE YOUR PROGRESS ·
YOUR HOME SCREEN · CLOCK AND TASKS · WORKS OFFLINE · ACCOUNT. Yasal bağlantılar
`privacy-en.html` ve `terms-en.html`.

---

## Ekran görüntüleri

Türkçe mağaza sayfasında **Türkçe arayüzlü** ekran görüntüleri görünmeli. Şu an yüklü olanlar
İngilizce ise Play onları Türkçe sayfada da gösterir; bu, TR kullanıcıda ilk izlenimi düşürür.

**Üretildi (v86, WP-839).** Kareler uygulamanın **gerçek** ekranlarından, Türkçe arayüzle ve
yeni karşılama temasıyla (`campfire_day`) çekiliyor; böylece mağazadaki görsel ile uygulamanın
kendisi tutarlı oluyor. Yeniden üretmek için (app/ içinde):

```
STORE_SHOT_DIR=<klasör> flutter test test/marketing/store_shots_wp839_test.dart   --dart-define-from-file=env.json --tags=golden
```

Çıkan dosyalar 1080x1920 (masaüstünde `focus-camp-magaza-kareleri` klasörü), yükleme sırası:

1. `01-ana-ekran.png` — "Süreni ölç, panonu kendin kur": çalışan sayaç, bugünün toplamı, hedef çubuğu, grup sıralaması.
2. `02-kamp-atesi.png` — "Birlikte çalış": kamp ateşi sahnesi, çalışan üyeler ve süreleri, grup hedefi.
3. `03-istatistik.png` — "İlerlemeni gör": haftalık toplamlar, saat dağılımı, ders bazında pasta grafik.
4. `04-rozetler.png` — "Emeğin kayıtlı kalsın": seri, aktif gün, rekor, taç ve XP ilerlemesi.
5. `05-tema.png` — "Kendine göre ayarla": hazır temalar, seçili karşılama teması başta.

Kareler **örnek hesapla** çekilir (WP-853, `app/test/marketing/store_seed.dart`): yaklaşık 3 haftalık
oturum, 4 ders (Matematik, Fizik, Türkçe, İngilizce), koşan bir sayaç, bir grup. Gerçek kişisel veri yok;
örnek veriler çekim anına göre üretilir.

---

## Sahip adımları

1. Play Console → **Mağazada görünme → Mağaza girişi**.
2. Dil listesinden **Türkçe (tr-TR)** ekle.
3. Yukarıdaki üç metni yapıştır, kaydet.
4. Aynı sayfada **Telefon ekran görüntüleri** bölümüne yukarıdaki 5 kareyi sırayla yükle.
5. Değişiklikler **Yayın özeti** sayfasından incelemeye gönderilir; mağaza metni değişikliği
   uygulama sürümünden bağımsızdır, yeni bir sürüm gerektirmez.
