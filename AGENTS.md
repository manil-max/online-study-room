# AGENTS.md — AI Ajan Kuralları

> Bu dosya, projede çalışan yapay zekâ ajanlarının (Claude Code vb.) uyması gereken çalışma
> kurallarıdır. Kullanıcı "**agents.md oku ve devam et**" dediğinde, ajan bu dosyayı okur ve
> aşağıdaki akışı uygular.
>
> Proje bilgileri → `project.md` · İlerleme takibi → `progress.md`

---

## 0. Her Oturumun Başında (İŞE BAŞLAMADAN ÖNCE)

1. **`project.md`'yi oku** → projeyi, vizyonu, mimariyi, kararları ve açık soruları anla.
2. **`progress.md`'yi oku** → nerede kaldığımızı, hangi fazın/alt-fazın aktif olduğunu bul.
3. Aktif (`[~]`) veya sıradaki yapılacak (`[ ]`) **mini fazı** belirle.
4. Mini faza başlamadan önce ne yapacağını kısaca özetle; belirsizlik varsa kullanıcıya sor.

> Bu adım atlanmaz. Proje bağlamını anlamadan koda dokunma.

---

## 1. Çalışma Birimi: "Mini Faz"

İş, `progress.md`'deki **alt-faz / madde** düzeyinde küçük parçalar (mini faz) hâlinde yürütülür.
Aynı anda tek bir mini faza odaklan; bitmeden diğerine geçme.

---

## 2. Her Mini Faz BİTİNCE (zorunlu sıra)

Bir mini faz tamamlandığında, sırasıyla:

### 2.1 Dokümanları güncelle
- `progress.md`: tamamlanan maddeyi `[x]` yap; gerekiyorsa "Yapılanlar Günlüğü"ne kısa not ekle;
  "Aktif Faz / Sıradaki adım" özetini güncelle.
- `project.md`: bu mini fazda bir **karar** verildiyse, açık soru kapandıysa veya mimari/veri
  modeli değiştiyse ilgili bölümü ve "Karar Günlüğü"nü güncelle.

### 2.2 Test et
- Mini fazın çıktısını **test et** (uygun yöntemle: `flutter test`, uygulamayı çalıştırıp
  davranışı gözlemleme, `flutter analyze` vb.).
- Test sonuçlarını dürüstçe raporla. **Hata varsa commit ATMA** — önce düzelt.

### 2.3 Sorun yoksa commit at
- Testler temizse anlamlı bir commit mesajıyla commit at (mini faz başına bir commit).
- Küçük, odaklı commit'ler tercih edilir.
- Commit mesajı Türkçe veya İngilizce olabilir; ne yapıldığını net anlatmalı.
- **Push yapma** (kullanıcı istemedikçe). Sadece yerel commit.

---

## 3. Genel İlkeler

- **Sıra önemli:** önce dokümanı güncelle → sonra test et → sorun yoksa commit at.
- Büyük/geri dönüşü zor kararları tek başına verme; `project.md` > Açık Sorular'a ekleyip
  kullanıcıya sor.
- Kullanıcı **Türkçe** konuşuyor; açıklamaları sade tut, jargonu çevir.
- Kod ve teknik isimler İngilizce; kullanıcıya görünen (UI) metinler Türkçe.
- Gizli anahtarları (Supabase service_role vb.) repoya koyma.
- Bir mini faz biter bitmez kullanıcıya kısa durum özeti ver ve sıradaki mini fazı söyle.
