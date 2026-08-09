/**
 * WP-625 — admin yaptırım kararları, davranış testleri.
 *
 * Çalıştırma (repo kökü):
 *   deno test --no-lock supabase/functions/
 *
 * 🔴 İki uçlu iddia: **askı süreli ve kayıtlı olmalı, kalıcı yasak kalıcı
 * kalmalı.** Denetim iki hata buldu ve ikisi de "tek yönlü" düşünmekten
 * çıkmıştı:
 * * "Askıya Al" süresiz ban kuruyordu (kayıt yok, geri alma yok, dolma yok);
 * * bir uyarıyı geri almak ilgisiz kalıcı yasağı da kaldırıyordu.
 *
 * Bu yüzden her testin karşıt tarafı da burada: süre kısaldı diye kalıcı
 * yasağın süreli olmadığını, geri alma kapandı diye askının geri
 * alınamadığını sanmayalım.
 */

import {
  assert,
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts"

import {
  authBanDurationFor,
  isLadderAction,
  legacyIdempotencyKey,
  legacyLadderActionFor,
  PERMANENT_BAN_DURATION,
  requiresAuthBan,
  shouldClearAuthBanOnRevoke,
} from "./admin_sanction_policy.ts"

const TARGET = "11111111-1111-4111-8111-111111111111"

Deno.test("eski 'Askıya Al' süreli ve kayıtlı bir basamağa çevrilir", () => {
  const mapped = legacyLadderActionFor("suspend_user")
  assertEquals(mapped, "suspend_24h")
  // Süre kalıcı olmamalı: eski dal `suspend_permanent` ile AYNI değeri
  // yazıyordu, kullanıcı kendiliğinden hiç açılmıyordu.
  const duration = authBanDurationFor(mapped!)
  assertEquals(duration, "24h")
  assert(duration !== PERMANENT_BAN_DURATION)
})

Deno.test("kalıcı yasak kalıcı kalır", () => {
  assertEquals(legacyLadderActionFor("suspend_permanent"), "ban_permanent")
  assertEquals(authBanDurationFor("ban_permanent"), PERMANENT_BAN_DURATION)
})

Deno.test("basamak süreleri artar ve hiçbiri süresiz değildir", () => {
  const ladder = ["suspend_24h", "suspend_7d", "suspend_14d", "suspend_30d"]
  const hours = ladder.map((action) => {
    const value = authBanDurationFor(action)
    assert(value !== null, `${action} auth ban süresi yok`)
    return Number(value!.replace("h", ""))
  })
  assertEquals(hours, [24, 168, 336, 720])
  for (const value of hours) {
    assert(value < Number(PERMANENT_BAN_DURATION.replace("h", "")))
  }
})

Deno.test("susturma ve uyarı auth tarafına inmez", () => {
  for (const action of ["no_action", "warn", "name_reset", "mute_24h"]) {
    assertEquals(authBanDurationFor(action), null, action)
    assertFalse(requiresAuthBan(action), action)
    assert(isLadderAction(action), action)
  }
})

Deno.test("bilinmeyen basamak kabul edilmez", () => {
  assertFalse(isLadderAction("shadowban"))
  assertFalse(isLadderAction("suspend_user"))
  assertEquals(legacyLadderActionFor("delete_everything"), null)
})

Deno.test("eski çağrının anahtarı dakika kovasına sabitlenir", () => {
  const base = Date.parse("2026-08-09T10:15:00.000Z")
  const first = legacyIdempotencyKey("suspend_user", TARGET, base)
  const sameMinute = legacyIdempotencyKey("suspend_user", TARGET, base + 59_000)
  const nextMinute = legacyIdempotencyKey("suspend_user", TARGET, base + 61_000)
  assertEquals(first, sameMinute)
  assert(first !== nextMinute)
  // Farklı eylem aynı kovaya düşmez; yoksa uyarı ile askı tek kayıt sanılırdı.
  assert(first !== legacyIdempotencyKey("warn_user", TARGET, base))
})

Deno.test("uyarıyı geri almak auth ban'ına dokunmaz", () => {
  for (const action of ["warn", "mute_24h", "name_reset", "no_action"]) {
    assertFalse(
      shouldClearAuthBanOnRevoke({ revokedAction: action, softDeleted: false }),
      action,
    )
  }
})

Deno.test("askıyı geri almak auth ban'ını kaldırır", () => {
  for (const action of ["suspend_24h", "suspend_7d", "ban_permanent"]) {
    assert(
      shouldClearAuthBanOnRevoke({ revokedAction: action, softDeleted: false }),
      action,
    )
  }
})

Deno.test("silinmiş hesap geri alma yoluyla açılmaz", () => {
  assertFalse(
    shouldClearAuthBanOnRevoke({
      revokedAction: "suspend_7d",
      softDeleted: true,
    }),
  )
})

Deno.test("eksik/bozuk aksiyon geri alma yolunda fail-closed", () => {
  assertFalse(shouldClearAuthBanOnRevoke({ revokedAction: null, softDeleted: false }))
  assertFalse(
    shouldClearAuthBanOnRevoke({ revokedAction: undefined, softDeleted: false }),
  )
})
