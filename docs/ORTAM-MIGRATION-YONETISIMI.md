# Ortam, Migration ve Yayın Yönetişimi

> Durum: Kanonik operasyon sözleşmesi · 2026-07-20
> Öncelik: `docs/KALITE-PROGRAMI.md` ile birlikte uygulanır; çelişkide Kalite Programı kazanır.

## 1. Amaç

Beta istemci, deneysel migration veya agent çalışması production kullanıcılarının süre, XP, başarım, görev ve grup verisine dokunamaz. Her değişiklik aynı kanonik migration zincirinden local → staging → production yönünde terfi eder; ortam başına ayrı SQL çatalları tutulmaz.

## 2. Ortam modeli

| Ortam | Uygulama kanalı | Supabase | Veri | İzin verilen amaç |
|---|---|---|---|---|
| `local` | Debug/test | Docker üzerindeki Supabase CLI stack | Seed/sentetik | Geliştirme, reset, yıkıcı test |
| `staging` | Beta | Ayrı Supabase projesi | Test hesapları/sentetik | Migration, RLS, cihaz QA, soak |
| `production` | Stable | Mevcut canlı Supabase projesi | Gerçek kullanıcı | Yalnız kabul edilmiş sürüm |

Kilit kurallar:

- Beta artefaktı yalnız staging backend'e; stable artefaktı yalnız production backend'e bağlanır.
- Ortam uyuşmazlığında uygulama **fail-closed** davranır; sessiz InMemory veya diğer Supabase projesine düşmez.
- Beta/stable aynı git deposu ve aynı kaynak koddan üretilir; kanal, backend ve paket kimliği build-time yapılandırmadır.
- Yan yana kurulum hedeflenir: beta için ayrı Android application id/uygulama adı/görsel işaret; stable imza anahtarı korunur.
- Production verisi staging'e kopyalanmaz. Test verisi seed ile üretilir; gerekirse yalnız anonimleştirilmiş/sentetik fixture kullanılır.

## 3. Tek migration zinciri

`supabase/migrations/` tek kanonik kaynaktır. `staging_migrations/` veya `production_sql/` gibi çatallar yasaktır.

Bir migration'ın yaşam döngüsü:

1. Yeni dosya, mevcut en yüksek numaranın bir fazlasıyla oluşturulur.
2. Boş local DB'de `supabase db reset` ile bütün zincir baştan uygulanır.
3. SQL davranış testleri gerçek local PostgreSQL üzerinde çalışır; dosyada metin arayan test tek başına kanıt sayılmaz.
4. Veri/RLS/invariant/post-check testleri geçer.
5. Staging `migration list` + `db push --dry-run` çıktısı incelenir.
6. Staging'e uygulanır ve beta cihaz QA/soak yapılır.
7. Production için ayrıca backup, dry-run, etki özeti ve açık ürün sahibi onayı alınır.
8. Aynı migration production'a terfi eder; sonrasında post-check ve yayın sonrası doğrulama yapılır.

Bir remote ortama uygulanmış migration dosyası artık **immutable** kabul edilir. Hata varsa dosya geriye dönük değiştirilmez; yeni ileri-düzeltme migration'ı yazılır.

## 4. Mevcut canlı DB baseline prosedürü

`0001–0062` SQL Editor üzerinden elle çalıştırıldığı için CLI geçmişi gerçek şemayla aynı olmayabilir. Doğrudan `db push` yapılmaz.

Zorunlu sıra:

1. Production hedefi salt-okunur tanımlanır; çalışma boyunca production freeze sürer.
2. Şema, fonksiyon, politika, trigger, cron ve kritik tablo invariant envanteri alınır.
3. `supabase migration list` ile local/remote geçmiş farkı çıkarılır.
4. Her migration için “şemada gerçekten mevcut ve doğru” kanıtı üretilir.
5. Yalnız kanıtlanan sürümler `migration repair --status applied` ile geçmiş tablosuna işlenir.
6. `0056` fonksiyon gövdesi, `0060/0062` cron/finalizer durumu ve XP/session toplamları ayrıca doğrulanır.
7. Baseline raporu olmadan staging veya production push yapılmaz.

`migration repair` yalnız geçmiş kaydını değiştirir; şema düzeltmesi değildir. Körlemesine kullanılmaz.

## 5. Production güvenlik kapısı

Production'a yazan her komut için aşağıdaki altı kanıt aynı WP'de bulunur:

- Hedef project-ref/environment açıkça `production` olarak gösterildi.
- Backup/export veya geri dönüş stratejisi hazır.
- Staging'de aynı commit + aynı migration zinciri geçti.
- `db push --dry-run` beklenen migration listesini gösterdi.
- Veri koruma invariant'ları migration öncesi ve sonrası tanımlı.
- Kullanıcı o **somut deploy** için açık onay verdi.

Genel “tam yetki” veya geçmiş bir onay gelecekteki production deploy onayı yerine geçmez.

Production'da yasaklar:

- `supabase db reset --linked`
- Remote schema/table truncate/drop veya toplu delete; açık WP + backup + özel onay yoksa
- SQL Editor'dan normal migration deploy'u
- Uygulanmış migration dosyasını değiştirmek
- `service_role`, DB parolası veya access token'ı repoya/loga/yanıta yazmak
- Kritik hatayı `exception when others` ile yutup migration'ı başarılı göstermek

SQL Editor yalnız belgelenmiş acil durum prosedüründe, exact SQL + backup + kullanıcı onayıyla kullanılabilir; sonrasında değişiklik yeni migration ile kanonik zincire alınır.

## 6. Agent otomasyon sınırı

Agentlar otomatik yapabilir:

- CLI sürümünü doğrulama/pinleme
- Local stack başlatma ve sıfırdan migration replay
- Seed, SQL, pgTAP/RLS/invariant testleri
- Staging dry-run/push ve post-check
- Beta build, sürüm manifesti ve test raporu
- Production dry-run ve uygulanacak değişiklik raporu

Agentlar açık deploy onayı olmadan yapamaz:

- Production migration/Edge Function/secret deploy etmek
- Production veri düzeltmesi/backfill çalıştırmak
- Stable tag/release/push oluşturmak
- Production migration geçmişini `repair` etmek

## 7. Build ve sürüm kimliği

Her artefakt şu kimliği taşımalıdır:

- Kanal: `beta` veya `stable`
- Uygulama sürümü + benzersiz build number
- Git commit SHA
- Backend ortamı: `staging` veya `production`
- Beklenen migration head

Aynı version/build numarası farklı kod veya ekonomiyle yeniden kullanılmaz. Beta örneği `1.0.42-beta.1+4201`, stable örneği `1.0.42+42` olabilir; kesin sürüm release WP'sinde belirlenir.

## 8. Veri invariant'ları

Migration ve release kapısı en az şunları doğrular:

- `study_sessions` satır sayısı ve toplam `duration_seconds` beklenmedik azalmaz.
- Kullanıcı/gün toplamları migration öncesi/sonrası açıklanabilir fark dışında eşittir.
- `gamification_profiles.xp = sum(xp_ledger.xp_amount)`.
- Aynı kullanıcı/başarım/kademe için çift ledger veya çift pending ödül yoktur.
- Manuel, uygulama sayacı ve native sayaç aynı kişisel/grup/XP/başarım sözleşmesine girer.
- RLS ile başka kullanıcının private/secret progress'i ve doğrudan kritik DML reddedilir.
- Cron/finalizer “kurulmuş görünüyor” değil, test fixture üzerinde gerçekten çalışır.
- Europe/Istanbul gün ve hafta sınırları kanıtlanır.

## 9. Kurtarma süresince geçici freeze

WP-225–232 tamamlanıp ürün kabulü alana kadar:

- `0063_equal_study_sources.sql` production'a uygulanmaz.
- Yeni production migration veya stable sürüm çıkmaz.
- Production'da yalnız salt-okunur audit yapılır.
- Beta mevcut haliyle production backend'e yeni test yazımı yapmaz; staging ayrımı kurulana kadar veri değiştiren beta testi durur.
