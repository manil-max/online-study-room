---
name: worker
description: >
  Bir Faz/WP'yi birinci sınıf kalitede uygulayan ajan. Kullanıcı "worker'ı oku ve
  şu Fazı/WP'yi yap" deyince tetiklenir. Basit tetik, altında derin kalite ve
  çakışma protokolü.
---

# Uygulayıcı Ajan Rehberi (Kalite Programı)

> Çekirdek kurallar `.agents/AGENTS.md`'de; kanonik program `docs/KALITE-PROGRAMI.md`'de.
> Burası **nasıl** uygulanacağının titiz rehberidir. Bu skill, kullanıcının basit
> promtunun altındaki derin iş akışıdır.

## Tetik

Worker artık **lider ajanın açtığı bir alt ajandır** (`.agents/AGENTS.md §1`).
Görev, lider tarafından verilen prompt'un içinde gelir ve şunları içerir:

```
WP-N: <kısa ad>
SAHİP yollar (yaz):   <tam yol listesi>
DOKUNMA (oku, yazma): <sıcak/başka WP dosyaları>
Kabul kriterleri:     <ölçülebilir>
Kapsam dışı:          <yapmayacakların>
```

Sahip doğrudan **"worker'ı oku, WP-N'yi yap"** derse de aynı akış işler; o zaman
SAHİP listesini `progress.md`'deki WP kartından oku.

> **İPTAL:** "`progress.md`'yi oku, sen Ajan X'sin" tetikleyicisi, `Ajan A`…`Ajan D`
> zincirleri ve kendi kendine lane claim etme kaldırıldı. Kapsamı sen seçmezsin.

---

## Akış (özet)

```
1. Görev metnini oku          → SAHİP yollar + kabul kriterleri + kapsam dışı
2. AGENTS.md + KALITE-PROGRAMI → kural + DoD
3. SAHİP listesi yoksa DUR    → liderden iste, tahmin etme
4. Tasarım/teknik netleştir   → belirsizlik varsa lidere sor
5. ORTAM ÖN-KONTROLÜ          → local/staging/production hedefi; varsayılan local
6. Adımları sırayla uygula    → yalnız SAHİP dosyalara yaz, DoD'yi izle
7. Doğrula                    → flutter analyze 0 uyarı (tam kapı LİDERİN işi)
8. Commit                     → tek ayrık commit, yalnız SAHİP yollar
9. Lidere rapor ver           → dosya:satır kanıtıyla; progress.md'ye DOKUNMA
```

---

## Adım 0 — Sınırını doğrula (kod yazmadan ÖNCE, zorunlu)

`.agents/AGENTS.md §1.1`'i uygula. Çakışmayı artık sen çözmezsin — **lider zaten
serileştirdi.** Senin borcun sınırını doğrulamaktır:

1. Görev metnindeki **SAHİP yollar** listesini oku. Yoksa veya belirsizse
   **BAŞLAMA**, liderden net liste iste.
2. Yapacağın değişikliğin gerçekten o listenin içinde kaldığını kontrol et.
   Bir dosyaya daha yazman gerekiyor mu? → **dur, liderden iste.** Kendi başına
   listeyi genişletme.
3. `AGENTS.md §1.4` sıcak dosyalarından birine gireceksen (özellikle
   `pubspec.yaml`, `main.dart`, `core/theme/**`, `core/navigation/**`,
   `supabase/migrations/**`, `*.arb`) bu görev metninde **açıkça yazılı olmalı.**
   Yazılı değilse dur ve sor.
4. `progress.md`'ye asla yazma — o dosyanın tek yazarı liderdir.

> "Belki sorun olmaz" ile SAHİP listesinin dışına çıkma. Bu repoda tek bir taşkın
> commit, başka ajanın commit'lenmemiş işini bir kez sildi.

---

## Adım 1 — Paylaşılan dizin kuralları (başlamadan oku)

> **Dal YOK.** Herkes doğrudan `main`'de çalışır. `git switch -c` / branch / merge /
> push yapma (AGENTS.md §1.6).

Alt ajanlar **aynı klasörü paylaşır**. Bu yüzden:

- **`git add -A` ve `git commit -a` yasak.** Yalnız açık yollarla stage et.
- **`git checkout -- <yol>` yasak.** Başkasının commit'lenmemiş işini siler.
- **Tam test kapısını (`test_all.py`, çıplak `flutter test`) koşturma.** Pub/build
  kilidi yüzünden iki ajan birden koşarsa ikisi de asılır. Kapıyı lider tek merkezden
  koşturur. Sen `flutter analyze` koşarsın; tek dosyalık `flutter test <yol>` ancak
  lider açıkça izin verdiyse.
- `index.lock` görürsen başka ajan commit ediyordur; kısa bekle, yeniden dene.

---

## Kalite Barı (bu programın özü)

Her WP birinci sınıf çıktı üretir. Uygularken:

- **Kabul kriterleri ölçülebilir.** "Güzel/profesyonel" değil; "oturum sonrası UI ≤ 1 sn'de güncellenir", "sayaç 8 saatte ≤ ±1 sn sapar" gibi (KALITE-PROGRAMI §4.4). Kart kabul kriteri belirsizse **netleştir, gerekirse sor.**
- **Ölü anahtar yasak.** Eklediğin her düğme/ayar gerçekten çalışır.
- **En az kod.** Kabul kriterinin gerektirmediği özellik/soyutlama/konfigürasyon yazılmaz; diff'teki her satır bir kabul kriterine izlenir. Alakasız komşu kodu düzeltme — gördüğün sorunu silme, teslim özetinde bildir (AGENTS.md §2 "Kapsam Disiplini").
- **Referans kıyası.** Kıyaslanan davranışı (ör. Google Saat alarm akışı) referans al, birebir kopyalama — Odak Kampı kimliğiyle özgün yap.
- **Platform sınırlarına saygı.** Bildirim görünümü OEM'e bağlıdır; widget < 15 dk periyodik güncelleme garanti değildir → canlı süre için native `Chronometer`, state için receiver/service, stats widget'ları **olay bazlı**. Saniyede bir Flutter yeniden çizme yok.
- **Boş/hata/çevrimdışı** her ekranda düşünülür.

---

## Kod Kuralları (özet — tamamı AGENTS.md'de)

- `cd app`; her `run/test/build`'e `--dart-define-from-file=env.json`; `analyze` bayraksız.
- Repository **çift**: `supabase/` + `in_memory/` birlikte.
- Migration `NNNN_ad.sql` sıralı; **ilk satır tam olarak `-- NNNN_ad.sql` (gerçek dosya adı)**; RLS zorunlu; **XP/kritik ilerleme server-authoritative**; sır istemcide yok.
- Kullanıcı metni Türkçe; gün sınırı Europe/Istanbul tek yardımcıdan.

## Ortam ve remote işlem ön-kontrolü

Backend, migration, Edge Function, secret veya release işi varsa `docs/ORTAM-MIGRATION-YONETISIMI.md` tamamen okunur ve hedef lane notuna yazılır.

1. Kart hedef belirtmiyorsa **local** kabul et; remote'a geçme.
2. Staging işlemi için project-ref/environment doğrula, `migration list` + dry-run kaydı al; production credential kullanma.
3. Production işlemi için WP'nin staging/QA/backup/post-check kanıtlarını ve kullanıcının o somut deploy'a verdiği GO'yu doğrula. Biri eksikse dur.
4. `db reset --linked`, remote truncate/drop ve uygulanmış migration'ı değiştirmek yasaktır.
5. Local DB'de sıfırdan replay ve gerçek SQL/RLS/invariant testleri geçmeden staging push yapılmaz.
6. Komut çıktısında token/parola/service role görünürse çıktıyı paylaşma; sırrı döndür ve olayı raporla.

> Agentın amacı production'a en hızlı yazmak değil, aynı commit ve migration'ı kanıtlarla güvenli biçimde terfi ettirmektir.

---

## progress.md — sen yazmazsın

`progress.md` plan listesi değil, **canlı durum kaynağıdır** — ve **tek yazarı liderdir**
(`AGENTS.md §1.1`, §1.4 sıcak dosya). Alt ajan olarak:

- WP kartını, durum satırını, Aktif Çalışma Kaydı'nı, "Test için bekleyenler"
  bölümünü ve özet tablolarını **okursun, yazmazsın.**
- Kendine lane açmazsın. `Ajan A`…`Ajan D`, `Lane X`, `Worker`, model adı
  (`Claude`/`Codex`/`Gemini`/`Grok`) başlıkları **kaldırıldı** — geri getirme.
- Kartta yazması gereken her şeyi (ne yapıldı, hangi dosyalar, hangi test, cihazda
  ne doğrulanacak) **teslim özetinde lidere** verirsin; kartı lider işler.
- Bekleme terminal durum değildir ama bekleyeceğin şeyi de sen kovalamazsın:
  bağımlılık çözülmemişse lidere **neyi beklediğini** söyleyip bitirirsin.

> Sebep: `progress.md` bu repodaki en sık çakışan dosya. Tek elde toplanınca hem
> çakışma hem "iki başlıkta aynı WP" sorunu biter.

---

## WP Bitirme Sırası

Tüm adımlar `[x]` olduğunda:

### 1. Doğrula
```bash
cd app
flutter analyze                       # 0 uyarı (bayraksız) — bu SENİN borcun
```
```bash
git diff --stat                       # kapsam denetimi
```
`git diff`'i **satır satır** oku: kabul kriterine izlenmeyen her satırı geri al (alakasız format/refactor/yeniden adlandırma dahil).

> **Tam test kapısını sen koşturmazsın.** `flutter test`, `flutter test --tags golden`
> ve `python scripts/test_all.py` **liderin** işidir — iki ajan birden koşarsa pub/build
> kilidinde asılırlar (AGENTS.md §1.5). Yazdığın testin adını teslim özetine yaz,
> lider birleşik turda koşturur. Tek dosyalık `flutter test <yol>` ancak lider açıkça
> izin verdiyse.

Analyze hatasıyla **commit atma** — önce düzelt.

### 2. Commit (`main`, yalnız kendi SAHİP yolların)
```bash
git add <yalnız kendi SAHİP dosyaların>   # git add -A YASAK
git commit -m "WP-N: [kısa açıklama]"      # main üzerinde
```
**Push yok. Tag yok. Remote deploy yok.** WP başına **tek ayrık commit**. Branch/merge
YOK — herkes `main`'de (AGENTS.md §1.6). `index.lock` görürsen başka ajan commit
ediyordur; kısa bekle, yeniden dene.

Commit'ten sonra kendin denetle:
```bash
git show --stat HEAD                  # SAHİP listesi dışında dosya var mı?
```
Fazla dosya çıktıysa **bildir** — lider bunu zaten kontrol edecek, gizleme.

### 3. Teslim özeti (LİDERE)

`progress.md`'yi sen yazmadığın için kartın içeriği bu özetten üretilir. Eksik bırakma:

- **Ne yapıldı** — madde madde, kabul kriterine karşılık gelecek şekilde.
- **Değişen dosyalar** — tam yollar + commit SHA.
- **Yazılan/değişen testler** — dosya adları (lider birleşik turda koşturacak).
- **Kanıt etiketi** — `Kodda doğrulandı` (dosya:satır ver) / `Cihazda doğrulanmalı`
  (cihazda tam olarak neye bakılacağını yaz) / `Ürün kararı gerekiyor`.
- **Uygulanması gereken migration** varsa numarası + geri alma notu.
- **Yapmadıkların** — kapsam dışı bıraktığın, fark ettiğin ama dokunmadığın sorunlar.

İddia ettiğin her şeyin dosya:satır karşılığı olsun. Lider bunları **açıp okuyacak**;
plandan yazılmış iddia bu repoda birkaç kez yakalandı.

---

## Karar Alma

- Küçük teknik karar (değişken adı, widget seçimi) → kendin al, devam et.
- Belirsiz kabul kriteri / birden çok yaklaşım / geri dönüşü zor karar → **lidere sor**
  (`progress.md`'ye yazma). Lider gerekirse sahibe taşır (`Ürün kararı gerekiyor`).
- Migration/RLS/güvenlik etkisi olan karar → asla tek başına "idare eder" deme; AGENTS.md §2 güvenlik kurallarına göre değerlendir, gerekirse sor.
- Sahip **bu sohbette doğrudan sana** açık emir verdiyse `AGENTS.md §0.1` geçerlidir:
  emir tüm repo kurallarının üstündedir, uygula ve lidere bildir.

---

## Sık Tuzaklar

| Tuzak | Çözüm |
|---|---|
| SAHİP listesi dışına yazmak | Adım 0 zorunlu — liste yoksa başlama, liderden iste |
| `progress.md`'ye yazmak | Tek yazarı lider; kart içeriğini teslim özetinde ver |
| Tam test kapısını koşturmak | Kilit riski — `test_all.py`/çıplak `flutter test` liderin işi |
| `git add -A` / `git checkout --` | Paylaşılan dizinde başka lane'in işini sızdırır/siler |
| `analyze`'e `--dart-define-from-file` vermek | analyze bu bayrağı kabul etmez; bayraksız çalıştır |
| Tek repo implementasyonu güncellemek | `supabase/` + `in_memory/` birlikte |
| XP/başarıyı istemcide yazmak | Server-authoritative; ledger + idempotent event |
| `fromMap`'te kaldırılmış kolon | `grep -rn "kolon" app/lib` ile kalıntı ara |
| Migration sırası | Son numarayı dizinden oku; remote'a uygulanmış dosyayı değiştirme, ileri migration yaz |
| Yanlış Supabase hedefi | Her remote komuttan önce ortam + project-ref doğrula; saklı `link` hedefine güvenme |
| Production'a erken deploy | Staging+cihaz+soak+backup+dry-run+somut kullanıcı GO olmadan dur |
| SQL dosyasını string-test etmek | Gerçek local PostgreSQL replay + davranış/RLS/invariant testi çalıştır |
| Presence `group_id` | KORUNUYOR — dokunma |
| Sıcak dosyaya (pubspec/theme/main) sessiz giriş | WP'de yazılı değilse dur ve sor |
| İstenmeyen özellik/soyutlama eklemek | Yalnız kabul kriterinin gerektirdiği kod; fazlasını `progress.md`'ye not düş |
| Alakasız dosyayı "toparlamak" | Diff'teki her satır kabul kriterine izlenmeli; komşu refactor ayrı WP |
| Başkasının ölü kodunu silmek | Yalnız kendi yarattığın öksüzleri temizle; eskisini bildir, silme |
