import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:online_study_room/core/net/timeout_http_client.dart';

/// WP-548: WP-542 ile eklenen 10 sn'lik global HTTP tavanı, gerekçesinde
/// "yok" denilen dosya yüklemelerini kesiyordu.
///
/// Bağımsız bir regresyon denetimi ölçtü: `storage_client` yüklemeyi
/// `MultipartRequest` + `send()` ile yapar ve `send()` ancak gövdenin tamamı
/// gittikten sonra döner — yani tavan tüm yüklemeye uygulanıyordu. Geri
/// bildirim / şikâyet / SSS ekranları 5 MB'a kadar görsele izin veriyor;
/// yavaş bağlantıda ek 10 sn'de bitmez, `uploadReportAttachment` hatayı yutup
/// `null` döner ve **şikâyet eki sessizce düşer**.
///
/// Sözleşme: REST/Auth turları tavana tabidir (asılı kalan bir REST çağrısı
/// sayacı kilitliyordu — tavanın var olma sebebi buydu), Storage turları
/// değildir.
void main() {
  http.StreamedResponse ok(http.BaseRequest request) => http.StreamedResponse(
    const Stream<List<int>>.empty(),
    200,
    request: request,
  );

  test('storage yuklemesi tavana takilmaz', () async {
    // Tavandan uzun suren bir storage turu: gercek yavas yuklemenin modeli.
    final client = TimeoutHttpClient(
      _SlowClient(const Duration(milliseconds: 120), ok),
      const Duration(milliseconds: 20),
    );

    final response = await client.send(
      http.Request(
        'POST',
        Uri.parse('https://proje.supabase.co/storage/v1/object/report_attachments/u/1.jpg'),
      ),
    );

    expect(response.statusCode, 200);
  });

  test('REST turu tavana takilir', () async {
    final client = TimeoutHttpClient(
      _SlowClient(const Duration(milliseconds: 120), ok),
      const Duration(milliseconds: 20),
    );

    await expectLater(
      client.send(
        http.Request(
          'GET',
          Uri.parse('https://proje.supabase.co/rest/v1/study_sessions'),
        ),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('auth turu da tavana tabidir', () async {
    final client = TimeoutHttpClient(
      _SlowClient(const Duration(milliseconds: 120), ok),
      const Duration(milliseconds: 20),
    );

    await expectLater(
      client.send(
        http.Request(
          'POST',
          Uri.parse('https://proje.supabase.co/auth/v1/token'),
        ),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('storage yolu tanima: yalniz /storage/v1/ muaf', () {
    bool storage(String url) => TimeoutHttpClient.isStorageRequest(
      http.Request('GET', Uri.parse(url)),
    );

    expect(storage('https://p.supabase.co/storage/v1/object/avatars/a.png'), isTrue);
    expect(storage('https://p.supabase.co/rest/v1/rpc/group_daily_totals'), isFalse);
    // Sorgu dizesinde gecen benzer metin muafiyet uretmemeli.
    expect(storage('https://p.supabase.co/rest/v1/x?note=/storage/v1/'), isFalse);
  });
}

class _SlowClient extends http.BaseClient {
  _SlowClient(this._delay, this._respond);

  final Duration _delay;
  final http.StreamedResponse Function(http.BaseRequest request) _respond;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(_delay);
    return _respond(request);
  }
}
