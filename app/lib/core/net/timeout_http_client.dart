import 'package:http/http.dart' as http;

/// WP-542: Supabase'in REST/Auth isteklerine tek bir üst sınır.
///
/// Realtime websocket bu istemciden geçmez; kalıcı bağlantı etkilenmez.
///
/// 🔴 WP-548 — bu sınıfın ilk hâlindeki gerekçe YANLIŞTI. Yorumda "uygulamada
/// büyük dosya yükleme yoktur, storage yalnız `getPublicUrl` ve küçük `remove`
/// çağrılarında kullanılır" yazıyordu. Ölçüldü: DÖRT `uploadBinary` çağrı yeri
/// var (`report_attachment_upload.dart`, `supabase_admin_repository.dart`,
/// `supabase_auth_repository.dart`, `supabase_group_repository.dart`) ve geri
/// bildirim / şikâyet / SSS ekranları 5 MB'a kadar görsele izin veriyor
/// (`maxWidth`/`maxHeight` vermeden). `storage_client` yüklemeyi
/// `MultipartRequest` + `send()` ile yapar; `send()` ancak gövdenin tamamı
/// gittikten sonra döner, yani tavan TÜM YÜKLEMEYE uygulanıyordu. Yavaş
/// bağlantıda 5 MB'lık ek 10 sn'de bitmez → `TimeoutException` →
/// `uploadReportAttachment` hatayı yutup `null` döner → şikâyet eki SESSİZCE
/// düşerdi.
///
/// Bu yüzden storage yolu tavandan MUAFTIR. Storage zaten kendi boyut/istisna
/// sözleşmesine sahip; asılı kalan bir yükleme kullanıcıya görünür (gösterge
/// döner), asılı kalan bir REST çağrısı ise sayacı kilitliyordu — tavanın asıl
/// sebebi oydu.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(this._inner, this._timeout);

  final http.Client _inner;
  final Duration _timeout;

  /// Supabase Storage uç noktası: `<proje>/storage/v1/...`
  static bool isStorageRequest(http.BaseRequest request) =>
      request.url.path.contains('/storage/v1/');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (isStorageRequest(request)) return _inner.send(request);
    return _inner.send(request).timeout(_timeout);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
