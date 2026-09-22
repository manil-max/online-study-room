/**
 * WP-906: iOS teslimine FCM `apns` blogu. **Saf** — ag, env, zaman yok
 * (zaman `nowSeconds` ile verilir), boylece Deno testinden dogrudan cagrilir.
 *
 * Neden gerekli: dispatcher Android icin bilerek data-only mesaj yollar
 * (WP-303; bildirimi Dart ciziyor). iOS'ta data-only mesaj uygulama arka
 * plandayken/kapaliyken **hic gorunmez**; sistemin cizmesi icin APNs
 * payload'inda `aps.alert` olmalidir. Bu yuzden yalniz `platform === "ios"`
 * olan cihazlara bu blok eklenir.
 *
 * 🔴 Android mesaji BYTE-BYTE AYNI kalmalidir: `withApns` iOS olmayan her
 * teslimde aldigi nesnenin KENDISINI dondurur (kopya bile degil).
 */

export type ApnsDelivery = {
  outbox_id: string
  notification_type: string
  payload: Record<string, unknown>
  locale: string
  /** `claim_push_deliveries` 0144'ten beri doner; yoksa Android sayilir. */
  platform?: string | null
}

export type PushContent = { title: string; body: string }

export function isIosDelivery(delivery: ApnsDelivery): boolean {
  return String(delivery.platform ?? "").trim().toLowerCase() === "ios"
}

/**
 * iOS kilit ekraninda gorunecek metin.
 *
 * Android'de `update` metni cihazda, uygulamanin diliyle yeniden kurulur
 * (WP-773/779, `localizedUpdatePush`); payload'daki title/body `release.yml`in
 * SABIT Turkce metnidir. iOS'ta sistem bildirimi uygulama kod calistirmadan
 * cizer, yani ayni yerellestirme burada, cihazin kayitli diliyle
 * (`push_devices.locale` = uygulama dili, `activeAppLocale.languageCode`)
 * yapilir. Metinler `app/lib/l10n/app_{tr,en}.arb` `pushUpdate*` anahtarlarinin
 * birebir kopyasidir — ARB degisirse burasi da degismelidir.
 *
 * Diger tipler (`nudge`, `self_test`) dispatcher'da zaten dile gore
 * kuruluyor; `announcement`/`feedback_message` insanin yazdigi metni tasir
 * ve oldugu gibi gider.
 */
export function iosAlertContent(delivery: ApnsDelivery, content: PushContent): PushContent {
  if (delivery.notification_type !== "update") return content
  const language = delivery.locale.toLowerCase().split(/[-_]/)[0]
  const version = String(delivery.payload.version_name ?? "").trim()
  const isBeta = String(delivery.payload.target_channel ?? "").trim() === "beta"
  if (language === "tr") {
    return {
      title: isBeta ? "Odak Kampı Beta güncellendi" : "Odak Kampı güncellendi",
      body: version ? `${version} sürümü indirilmeye hazır.` : "Yeni sürüm indirilmeye hazır.",
    }
  }
  return {
    title: isBeta ? "Focus Camp Beta updated" : "Focus Camp updated",
    body: version ? `Version ${version} is ready to download.` : "A new version is ready to download.",
  }
}

/** Android `ttl` ile ayni omur (index.ts `android.ttl`). */
function ttlSeconds(notificationType: string): number {
  return ["self_test", "timer_sync"].includes(notificationType) ? 60 : 3600
}

export function apnsBlock(
  delivery: ApnsDelivery,
  content: PushContent,
  nowSeconds: number,
): Record<string, unknown> {
  const expiration = String(Math.floor(nowSeconds) + ttlSeconds(delivery.notification_type))

  if (delivery.notification_type === "timer_sync") {
    // Gorunur bildirim DEGIL: yalniz uygulamayi uyandiran sessiz sinyal.
    // APNs sessiz push icin push-type `background` + oncelik 5 ister.
    return {
      headers: {
        "apns-push-type": "background",
        "apns-priority": "5",
        "apns-expiration": expiration,
        "apns-collapse-id": `timer_sync:${String(delivery.payload.run_id ?? delivery.outbox_id)}`,
      },
      payload: { aps: { "content-available": 1 } },
    }
  }

  const alert = iosAlertContent(delivery, content)
  return {
    headers: {
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": expiration,
    },
    payload: {
      aps: {
        alert: { title: alert.title, body: alert.body },
        sound: "default",
      },
    },
  }
}

/**
 * iOS teslimde `message`'a `apns` ekler; digerlerinde `message`'in kendisini
 * dondurur (Android istegi degismez). `data` iki platformda da aynidir:
 * dokunma yonlendirmesi ve on plan gosterimi ondan okur.
 */
export function withApns<T extends Record<string, unknown>>(
  delivery: ApnsDelivery,
  content: PushContent,
  message: T,
  nowSeconds: number = Date.now() / 1000,
): T | (T & { apns: Record<string, unknown> }) {
  if (!isIosDelivery(delivery)) return message
  return { ...message, apns: apnsBlock(delivery, content, nowSeconds) }
}
