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
