// WP-625 — Admin yaptırım kararlarının SAF hâli.
//
// Neden ayrı modül: `admin-user-actions/index.ts` en üst seviyede `serve(...)`
// çağırır, test onu import edemez (gerçek sunucu başlar, test asılır). Aynı
// desen `purge_policy.ts`te kullanıldı; karar mantığı burada, kablo orada.
//
// Bu modülün kapattığı iki hata (denetim: `docs/denetim/DENETIM-sunucu-admin.md`):
//
// 1. **KANAMA K2 — "Askıya Al" 100 yıllık, kaydı olmayan ban kuruyordu.**
//    `suspend_user` dalı `876000h` yazıyordu ve `moderation_sanctions`'a
//    HİÇBİR satır düşmüyordu: askı Moderasyon sekmesinde görünmüyor, geri
//    alınamıyor, kendiliğinden dolmuyordu. Artık her eski çağrı WP-441
//    basamağına çevrilir; süre basamaktan gelir ve kayıt her zaman yazılır.
//
// 2. **RİSK R1 — bir UYARIYI geri almak, ilgisiz kalıcı yasağı kaldırıyordu.**
//    `moderation_revoke` auth ban'ını koşulsuz siliyordu. Auth tarafına hiç
//    dokunmamış bir basamağın (uyarı, susturma, ad sıfırlama) geri alınması
//    artık auth'a da dokunmaz.
//
// 🔴 Kalıcı yasak KALICI kalır: aşağıdaki tek yerde tanımlı süre yalnız
// `ban_permanent` ve `soft_delete_user` içindir; süresiz askı diye bir şey
// yoktur.

/// GoTrue `ban_duration` biçiminde "pratikte sonsuz".
export const PERMANENT_BAN_DURATION = '876000h'

/// `name_reset` basamağının profile yazdığı yer tutucu ad.
///
/// 🔴 WP-813: bu dize `admin-user-actions/index.ts` içinde **iki ayrı yerde**
/// elle yazılıydı (yaptırım hattı + eski `reset_user_name` dalı). WP-813 üçüncü
/// bir okuma yeri ekliyor: geri alma, adı ancak hedef HÂLÂ bu yer tutucudaysa
/// onarır. Üç yerde ayrı yaşayan bir dize, birinde değişince sessizce bozulur —
/// yer tutucu değişse geri alma hiçbir zaman eşleşmez ve kimse hata görmez.
export const MODERATION_NAME_PLACEHOLDER = 'İsimsiz kullanıcı'

/// Auth tarafında hesabı kapatan basamaklar ve süreleri.
///
/// Bu tablo aynı zamanda "hangi yaptırım auth'a dokunur" sorusunun TEK
/// cevabıdır; geri alma kararı da buradan okunur.
const AUTH_BAN_DURATIONS: Readonly<Record<string, string>> = Object.freeze({
  suspend_24h: '24h',
  suspend_7d: '168h',
  suspend_14d: '336h',
  suspend_30d: '720h',
  ban_permanent: PERMANENT_BAN_DURATION,
})

/// Auth tarafına inmeyen basamaklar.
///
/// `mute_24h` bilerek burada: susturulan kullanıcı uygulamayı okumaya devam
/// eder, yalnız yazamaz (WP-441). Auth ban kurmak onu tamamen dışarı atardı.
const NON_AUTH_LADDER_ACTIONS: readonly string[] = Object.freeze([
  'no_action',
  'warn',
  'name_reset',
  'mute_24h',
])

/// Eski (basamak öncesi) eylem adlarının WP-441 karşılıkları.
///
/// 🔴 `suspend_user` → `suspend_24h`: arayüzde süre sorulmayan "Askıya Al"
/// düğmesinin karşılığı en KISA basamaktır. Eski istemciler hâlâ bu adı
/// gönderiyor; süresiz ban yerine 24 saatlik, kayıtlı ve kendiliğinden dolan
/// bir askı uygulamak tek güvenli yorumdur. Daha ağırını isteyen yönetici
/// basamağı açıkça seçer.
/// 🔴 `suspend_permanent` → `ban_permanent`: kalıcı olan kalıcı kalır, ama
/// artık kaydı vardır ve geri alınabilir.
const LEGACY_LADDER_ALIASES: Readonly<Record<string, string>> = Object.freeze({
  mute_24h: 'mute_24h',
  warn_user: 'warn',
  suspend_user: 'suspend_24h',
  suspend_24h: 'suspend_24h',
  suspend_7d: 'suspend_7d',
  suspend_14d: 'suspend_14d',
  suspend_30d: 'suspend_30d',
  suspend_permanent: 'ban_permanent',
})

/// Yaptırım basamağı geçerli mi? (Bilinmeyen basamak kayıt bile açmamalı.)
export function isLadderAction(action: string): boolean {
  return action in AUTH_BAN_DURATIONS ||
    NON_AUTH_LADDER_ACTIONS.includes(action)
}

/// Basamak auth tarafında hesabı kapatıyor mu?
export function requiresAuthBan(action: string | null | undefined): boolean {
  return typeof action === 'string' && action in AUTH_BAN_DURATIONS
}

/// Basamağın `ban_duration` değeri; auth'a dokunmayan basamakta `null`.
export function authBanDurationFor(action: string): string | null {
  return AUTH_BAN_DURATIONS[action] ?? null
}

/// Eski eylem adının basamak karşılığı; eski ad değilse `null`.
export function legacyLadderActionFor(action: string): string | null {
  return LEGACY_LADDER_ALIASES[action] ?? null
}

/// Eski çağrılar idempotency anahtarı göndermiyor; dakika kovasından türetilir:
/// aynı dakikadaki yeniden denemeler tek yaptırım açar.
export function legacyIdempotencyKey(
  action: string,
  targetUserId: string,
  nowMs: number,
): string {
  return `legacy-${action}-${targetUserId}-${Math.floor(nowMs / 60000)}`
}

/// Geri alınan yaptırım auth ban'ını da kaldırmalı mı?
///
/// İki kapı var ve ikisi de bir hatayı kapatıyor:
/// * basamak auth'a hiç dokunmadıysa (uyarı/susturma/ad sıfırlama) auth'a
///   dokunulmaz — yoksa ilgisiz bir askı/yasak sessizce kalkıyordu;
/// * hedef "soft delete" edilmişse ban kaldırılmaz — silinmiş hesap, eski bir
///   uyarının geri alınmasıyla tekrar giriş yapabilir hâle gelmemeli.
export function shouldClearAuthBanOnRevoke(input: {
  revokedAction: string | null | undefined
  softDeleted: boolean
}): boolean {
  return requiresAuthBan(input.revokedAction) && !input.softDeleted
}

/// Geri alınan yaptırım kullanıcının **adını** geri yüklemeli mi?
///
/// 🔴 WP-813 ölçülen kusur: `name_reset` kısıtlayıcı sayılmadığı için
/// (`moderation_sanction.dart`, `nameReset.isRestrictive == false`) sert teyit
/// istemez (`sanction_ladder.dart:62-63`), uygulandıktan sonra 10 saniyelik
/// "Geri al" şeridi çıkar ve düğme `moderation_revoke`u çağırır. O dal satırı
/// `revoked` yapıp yalnız auth ban'ına bakıyordu; adı geri yazan tek kod eski
/// `restore_user_name` dalıydı ve `app/lib` içinde **sıfır** çağrı yeri vardı.
/// Yönetici BAŞARI mesajı görüyor, kullanıcının adı yer tutucuda kalıyordu.
///
/// **Tasarım C — koşullu onarım.** Ad ancak hedefin şu anki adı moderasyonun
/// koyduğu yer tutucuysa geri yazılır:
/// * *Tasarım A* (koşulsuz onarım) kullanıcının bu arada kendi seçtiği adı
///   ezerdi. "Geri al" bir moderasyon işlemini geri alır, kullanıcının kendi
///   kararını değil.
/// * *Tasarım B* (sert teyit + ayrı "adı geri yükle" düğmesi) yeni yüzey ve
///   yeni l10n anahtarı isterdi; bu tur yalanı kapatıyor, yüzey açmıyor.
///
/// Yan fayda: soft-delete edilmiş hesabın adı `Silinmiş Kullanıcı`dır, yer
/// tutucuya eşit değildir — eski bir ad sıfırlamayı geri almak silinmiş
/// hesabın adını diriltmez.
export function shouldRestoreNameOnRevoke(input: {
  revokedAction: string | null | undefined
  currentDisplayName: string | null | undefined
}): boolean {
  return input.revokedAction === 'name_reset' &&
    input.currentDisplayName === MODERATION_NAME_PLACEHOLDER
}
