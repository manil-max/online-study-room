# V57 sonrası sayaç/widget senkron kanıtı

> Tarih: 2026-08-01 · Kapsam: kod, protokol, migration ve cihazsız otomatik test
> · Gerçek iki-cihaz/OEM testi bu turda kullanıcı tarafından hariç tutuldu.

## Sonuç

Geri bildirim tek bir hatadan oluşmuyordu. Dört ayrı kusur/boşluk bulundu:

| Bulgu | Karar | Kanıt / sonuç |
|---|---|---|
| Daha önce görülmüş snapshot yeniden kurulmadan atlanıyor | **Doğrulandı ve düzeltildi** | `global_timer_v2_seen_*` yalnız olay dedup bilgisi olmasına rağmen yerel ayna eksik olsa da erken `return` üretiyordu. Planner artık önce yerel/sunucu farkını hesaplıyor; aynı `state_version` eksik aynayı yeniden kuruyor. |
| 150 sn heartbeat lease açık çalışma niyeti gibi kullanılıyor | **Doğrulandı ve düzeltildi** | Android native FGS ayakta kalırken Dart isolate askıya alınabilir. `0119` kısa lease'i tazelik sinyali olarak tutuyor; `abandoned` terminali yalnız 12 saatlik bounded recovery grace sonrasında veriliyor. İstemci bu penceredeki koşuyu `sync delayed` gerçeğiyle göstermeye devam ediyor. |
| Yaşam döngüsünde heartbeat kırılgan | **Doğrulandı ve güçlendirildi** | Sahip cihaz hide/pause öncesi ve resume'da hemen heartbeat gönderiyor; eşzamanlı çağrılar tek in-flight istekte birleşiyor. 60 sn periyodik tur korunuyor. |
| Countdown/pomodoro widget çalışırken `00:00` gösteriyor | **Doğrulandı ve düzeltildi** | Native widget yalnız stopwatch dalında Chronometer çalıştırıyordu. Faz hedef saniyesi ortak prefs/native komut sözleşmesine eklendi; API 24+ `setChronometerCountDown` ile kalan süre sayılıyor. |

## “Başta göründü, sonra kayboldu” kök nedeni

Soğuk açılış güvenliği ayna projeksiyonunu önce yerelden temizliyor. Aynı koşunun
sunucu `state_version` değeri cihazda daha önce “görüldü” diye kayıtlıysa eski
koordinatör snapshot'ı duplicate sayıp hiçbir directive üretmiyordu. Sonuç:
sunucuda koşu açık olsa bile telefon aynayı yeniden kuramıyordu. Bu yol artık
`gorulmus snapshot eksik yerel aynayi yeniden kurar` regresyon testiyle kilitli.

İkinci bağımsız kaybolma yolu heartbeat'ti. Dart timer arka planda 150 saniyeden
uzun askıya alınırsa cron koşuyu `abandoned` yapıyor, karşı cihaz da haklı olarak
kapatıyordu. `0119_global_timer_lease_recovery_grace.sql` açık çalışma ile
controller tazeliğini ayırıyor. Migration yalnız repoya eklendi; staging veya
production'a uygulanmadı.

## Otomatik kanıt

- Hedefli Flutter paketi: **26/26 geçti**.
- Android native Kotlin derleme + JVM testleri: **geçti**.
- Yeni Kotlin testleri stopwatch yukarı sayımını, countdown kalan süreyi ve
  hedef sonundaki `00:00` duruşunu ölçüyor.
- `flutter analyze`: **0 sorun**.
- Contract, contract self-test, l10n, Android l10n, migration-head, deploy guard
  ve release preflight: **7/7 geçti**.
- Tam cihazsız tester turu (`python scripts/test_all.py --full`): **16 kapının
  13'ü geçti, 0 kırmızı, 3 ortam nedeniyle atlandı**. Atlananlar Deno kurulu
  olmadığı için iki Edge kapısı ve Docker engine çalışmadığı için yerel pgTAP
  replay'idir; yeni `0119` migration'ı bu nedenle remote/veritabanı üzerinde
  henüz çalıştırılmış sayılmaz.
- Kapsam ratchet'i geçti: genel **%65.23** (22304/34191), kritik **%58.92**;
  dokunulmamış üretim dosyası **33**.
- `scripts/test_all.py` artık `android-unit` kapısını varsayılan T2 turunda
  çalıştırıyor. Önceki tester yalnız Dart/Flutter paketini çalıştırdığı için
  `StudyWidgetProviders.kt` davranışını derlemiyor veya test etmiyordu.

## Cihaz olmadan doğrulanamayan son matris

| Senaryo | Otomatik durum | Fiziksel kanıt |
|---|---|---|
| A'da başlat → B uygulamasında ve widget'ta görünür | Protokol/planner testli | Bekliyor |
| B daha önce gördü → uygulama kapanıp açıldı → ayna geri gelir | Regresyon testli | Bekliyor |
| Kaynak ekran kapalı/arka planda 3+ dakika → B kaybolmaz | Lease/grace testli | Bekliyor |
| B widget “Durdur” → A durur | Kuyruk/CAS sözleşmesi testli | Bekliyor |
| Countdown ve pomodoro widget kalan süreyi sayar | Kotlin saf projeksiyon testli | Bekliyor |
| Uygulama process'i tamamen öldürülmüşken widget start hemen diğer cihaza gider | **Desteklenmiyor:** native yalnız kalıcı outbox yazar, Dart flush açılışta olur | Ürün/mimari kararı gerekli |

## Release kararı

Kod ve cihazsız kapılar açısından düzeltme adayı hazırdır. Ancak WP-482 tamamlandı
veya v58 release-ready sayılamaz: `0117–0119` staging replay, iki fiziksel cihaz
matrisi, Android release build ve beta soak hâlâ zorunlu son kapılardır.
İki cihazın da bu istemci düzeltmelerini alması gerektiğinden yalnız migration
uygulamak mevcut v57 kurulumlarında snapshot/widget sorununu bütünüyle çözmez.
