/**
 * WP-906 — iOS `apns` blogu davranis testleri.
 *
 * Calistirma (repo koku):
 *   deno test --no-lock --allow-env supabase/functions/
 *
 * Iki sinav: (1) Android mesaji hicbir kosulda degismez (WP-303 data-only
 * sozlesmesi), (2) iOS mesaji sistemin arka planda cizebilecegi `aps.alert`
 * tasir ve `update` metni cihazin dilinde kurulur.
 */

import {
  assertEquals,
  assertStrictEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts"

import { type ApnsDelivery, apnsBlock, iosAlertContent, isIosDelivery, withApns } from "./apns.ts"

const now = 1_800_000_000

function delivery(overrides: Partial<ApnsDelivery> = {}): ApnsDelivery {
  return {
    outbox_id: "11111111-1111-1111-1111-111111111111",
    notification_type: "nudge",
    payload: { schema_version: "1", route: "nudge" },
    locale: "tr",
    platform: "android",
    ...overrides,
  }
}

function androidMessage(): Record<string, unknown> {
  return {
    token: "tok",
    data: { notification_type: "nudge", title: "T", body: "B" },
    android: { priority: "HIGH", ttl: "3600s" },
  }
}

const content = { title: "Ayşe seni dürttü 👋", body: "Seni çalışmaya çağırıyor." }

// ─── Android: byte-byte ayni ────────────────────────────────────────────────

Deno.test("android teslimde mesaj nesnesinin kendisi doner (kopya yok)", () => {
  const message = androidMessage()
  const before = JSON.stringify({ message })
  const result = withApns(delivery(), content, message, now)
  assertStrictEquals(result, message)
  assertEquals(JSON.stringify({ message: result }), before)
  assertEquals("apns" in result, false)
})

Deno.test("platform kolonu yoksa/null ise Android sayilir (eski sema)", () => {
  for (const platform of [undefined, null, "", "ANDROID", "web"]) {
    const message = androidMessage()
    const result = withApns(delivery({ platform }), content, message, now)
    assertStrictEquals(result, message, `platform=${String(platform)}`)
  }
})

Deno.test("her bildirim tipinde android degismez", () => {
  for (const type of ["nudge", "announcement", "update", "self_test", "timer_sync", "feedback_message"]) {
    const message = androidMessage()
    assertStrictEquals(withApns(delivery({ notification_type: type }), content, message, now), message)
  }
})

// ─── iOS: aps.alert ─────────────────────────────────────────────────────────

Deno.test("isIosDelivery buyuk/kucuk harf ve bosluk toleransli", () => {
  assertEquals(isIosDelivery(delivery({ platform: "ios" })), true)
  assertEquals(isIosDelivery(delivery({ platform: " iOS " })), true)
  assertEquals(isIosDelivery(delivery({ platform: "android" })), false)
})

Deno.test("iOS mesaji data'yi korur ve aps.alert + sound ekler", () => {
  const message = androidMessage()
  const result = withApns(delivery({ platform: "ios" }), content, message, now) as Record<string, unknown>
  assertEquals(result.token, message.token)
  assertEquals(result.data, message.data)
  assertEquals(result.android, message.android)
  assertEquals(result.apns, {
    headers: {
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": String(now + 3600),
    },
    payload: {
      aps: {
        alert: { title: content.title, body: content.body },
        sound: "default",
      },
    },
  })
  // Girdi nesnesi degismedi.
  assertEquals("apns" in message, false)
})

Deno.test("self_test iOS'ta 60 sn omurlu gorunur bildirimdir", () => {
  const block = apnsBlock(delivery({ platform: "ios", notification_type: "self_test" }), content, now)
  assertEquals((block.headers as Record<string, string>)["apns-expiration"], String(now + 60))
  assertEquals((block.payload as { aps: { alert: unknown } }).aps.alert, {
    title: content.title,
    body: content.body,
  })
})

Deno.test("timer_sync iOS'ta sessiz arka plan sinyalidir (alert yok)", () => {
  const block = apnsBlock(
    delivery({ platform: "ios", notification_type: "timer_sync", payload: { run_id: "run-1" } }),
    { title: "", body: "" },
    now,
  )
  assertEquals(block, {
    headers: {
      "apns-push-type": "background",
      "apns-priority": "5",
      "apns-expiration": String(now + 60),
      "apns-collapse-id": "timer_sync:run-1",
    },
    payload: { aps: { "content-available": 1 } },
  })
})

Deno.test("announcement/feedback metni oldugu gibi gider", () => {
  const typed = { title: "Duyuru", body: "Yarın bakım var." }
  for (const type of ["announcement", "feedback_message", "nudge", "self_test"]) {
    assertEquals(iosAlertContent(delivery({ platform: "ios", notification_type: type, locale: "en" }), typed), typed)
  }
})

// ─── iOS: update metni cihaz dilinde (ARB pushUpdate* kopyasi) ──────────────

const fixedTurkish = { title: "Odak Kampı", body: "Yeni sürüm hazır." }

Deno.test("update: Ingilizce cihaz Ingilizce metin alir (payload Turkcesi degil)", () => {
  const d = delivery({
    platform: "ios",
    notification_type: "update",
    locale: "en",
    payload: { version_name: "1.0.90", target_channel: "stable" },
  })
  assertEquals(iosAlertContent(d, fixedTurkish), {
    title: "Focus Camp updated",
    body: "Version 1.0.90 is ready to download.",
  })
})

Deno.test("update: Turkce cihaz, beta kanali ve surumsuz govde", () => {
  const d = delivery({
    platform: "ios",
    notification_type: "update",
    locale: "tr-TR",
    payload: { version_name: "", target_channel: "beta" },
  })
  assertEquals(iosAlertContent(d, fixedTurkish), {
    title: "Odak Kampı Beta güncellendi",
    body: "Yeni sürüm indirilmeye hazır.",
  })
})

Deno.test("update: bilinmeyen dil Ingilizceye duser", () => {
  const d = delivery({
    platform: "ios",
    notification_type: "update",
    locale: "de",
    payload: { version_name: "2.0.0", target_channel: "beta" },
  })
  assertEquals(iosAlertContent(d, fixedTurkish), {
    title: "Focus Camp Beta updated",
    body: "Version 2.0.0 is ready to download.",
  })
})

Deno.test("update iOS mesajinda alert yerellesir, data payload'i degismez", () => {
  const d = delivery({
    platform: "ios",
    notification_type: "update",
    locale: "en",
    payload: { version_name: "1.0.90", target_channel: "stable" },
  })
  const message = { token: "tok", data: { title: "Odak Kampı", body: "Yeni sürüm hazır." } }
  const result = withApns(d, fixedTurkish, message, now) as Record<string, unknown>
  assertEquals(result.data, message.data)
  const aps = ((result.apns as Record<string, unknown>).payload as { aps: { alert: unknown } }).aps
  assertEquals(aps.alert, { title: "Focus Camp updated", body: "Version 1.0.90 is ready to download." })
})
