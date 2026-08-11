import 'package:flutter/material.dart';

import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-D (`docs/design/ADMIN-PANEL-PLAN.md` §3 madde 7 / §5 WP-D kabul 1 ve 4) —
/// yonetim panelinin **yeniden kullanilabilir** arama ve bos-sonuc parcalari.
///
/// Neden ayri dosya: ayni iki kusur iki ayri yuzeyde duruyordu.
///   * Kisi/grup listelerinde arama kutusu **hic yoktu**
///     (`admin_users_tab.dart:44-56`, `admin_groups_tab.dart:30-37`): vakadan
///     kisiye gecis "UUID'yi kopyala, sekme degistir, gozle ara" idi (§2.3).
///   * Bir filtre sonuc vermeyince filtreyi **kaldiracak kontrol ekranda
///     yoktu** (§2.4 "filtre cikmazi"): sekmeden cikip donmek gerekiyordu.
///
/// Ikisi de tek bir yuzeye ozgu degil, o yuzden bilesenler burada durur ve
/// grup dizini, uye secici ve rapor kuyrugu ayni parcayi kullanir.

/// Kullanicinin yazdigi parca [fields] alanlarindan **herhangi birinde**
/// geciyor mu?
///
/// Kucuk/buyuk harf ve bas/son bosluk onemsizdir; bos sorgu her satiri gecirir.
/// `null` alanlar (e-postasi bilinmeyen uye) sessizce atlanir — arama onlari
/// eleyip listeyi yalanlamaz, yalnizca o alandan eslesmez.
bool adminMatchesQuery(String query, Iterable<String?> fields) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  for (final field in fields) {
    if (field == null) continue;
    if (field.toLowerCase().contains(needle)) return true;
  }
  return false;
}

/// Dizin arama kutusu.
///
/// Degeri **cagiran** tutar ([value]); boylece "Filtreyi temizle" kontrolu
/// kutunun icini de gercekten bosaltabilir (kendi state'inde tutulsaydi
/// temizleme yazi kutusunda gorunmezdi — kullanicinin gordugu sey yalan
/// olurdu).
class AdminSearchField extends StatefulWidget {
  const AdminSearchField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.fieldKey,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  /// Testin **bu** kutuyu digerinden ayirmasi icin (ornegin grup dizini ile
  /// uye secicinin kutusu ayni anda ekranda olabilir).
  final Key? fieldKey;

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(AdminSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    // 🔴 `admin_groups_tab.dart:56-57` iki controller'i hic `dispose`
    // etmiyordu (PLAN §2.4 kucuk sizinti). Ayni hatayi burada tekrarlamiyoruz.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: widget.fieldKey,
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.search, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: widget.value.isEmpty
            ? null
            : IconButton(
                // PLAN §4.6: yalniz-ikon her dugmede `Tooltip` zorunlu.
                tooltip: l10n.adminAramayiTemizle,
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => widget.onChanged(''),
              ),
      ),
    );
  }
}

/// Bos sonuc ekrani — ve §2.4 cikmazinin cikisi.
///
/// [onClearFilter] verildiginde ekranda **filtreyi kaldiran** bir kontrol
/// durur. Verilmediginde (gercekten hic kayit yoksa) yalnizca mesaj cizilir;
/// olmayan bir filtreyi temizleten dugme gostermek de yalan olurdu.
///
/// `Center` **degil** `Column(mainAxisSize: min)`: bu parca hem `Center`
/// icine hem de kaydirilabilir bir listenin icine konur; `Center` sinirsiz
/// yukseklikte patlar ve "asagi cek-yenile" jestini olduren bir kabuk uretir.
class AdminEmptyResult extends StatelessWidget {
  const AdminEmptyResult({required this.message, this.onClearFilter, super.key});

  final String message;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.search_off_outlined,
          size: 32,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (onClearFilter != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onClearFilter,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 20),
            label: Text(l10n.adminFiltreyiTemizle),
          ),
        ],
      ],
    );
  }
}
