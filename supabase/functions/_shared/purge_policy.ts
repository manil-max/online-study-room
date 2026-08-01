/**
 * `purge-accounts` saf karar mantığı — test edilebilir olsun diye ayrı modül.
 *
 * 🔴 Neden ayrı dosya: `index.ts` en üst seviyede `serve(...)` çağırır. Test
 * o dosyayı import etseydi gerçek bir HTTP sunucusu başlardı ve test asılırdı.
 * Saf kararları buraya taşımak, `serve` kablolamasına hiç dokunmadan davranışı
 * test edilebilir yapar (Supabase'in `_shared/` deseni; deploy sırasında
 * bundle'a dahil edilir).
 *
 * Buradaki iki fonksiyon ürünün en riskli iki kararını verir:
 *   * `authorizeCron` — yetkisiz bir isteğin kullanıcı verisi SİLMESİNİ engeller,
 *   * `classifyPurgeError` — hatanın yeniden denenebilir mi yoksa terminal mi
 *     olduğunu belirler; yanlış sınıflama ya sonsuz retry ya sessiz veri kaybı.
 */

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
}

/**
 * Purge zincirinin kendi sırrı.
 *
 * 🔴 `CRON_SECRET` bilerek İKİNCİL: aylık rapor cron'u onu kullanıyor.
 * Purge aktivasyonu `CRON_SECRET`'i döndürseydi rapor cron'u sessizce 401
 * almaya başlardı. Ayrı değişken = sıfır çakışma.
 */
export function purgeSecret(): string {
  return (
    Deno.env.get("PURGE_CRON_SECRET") ??
    Deno.env.get("CRON_SECRET") ??
    ""
  ).trim()
}

/** Yetkisizse 401 `Response`, yetkiliyse `null`. */
export function authorizeCron(req: Request): Response | null {
  const cronSecret = purgeSecret()
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  const headerSecret = req.headers.get("x-cron-secret") ?? ""
  const authHeader = req.headers.get("Authorization") ?? ""
  if (cronSecret && headerSecret === cronSecret) return null
  if (cronSecret && authHeader === `Bearer ${cronSecret}`) return null
  if (serviceKey && authHeader === `Bearer ${serviceKey}`) return null
  return new Response(JSON.stringify({ error: "Unauthorized" }), {
    status: 401,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

/** Ham hatayı kararlı bir hata koduna indirger (retry sınıflandırması). */
export function classifyPurgeError(err: unknown): string {
  const raw = String(err ?? "unknown")
  const lower = raw.toLowerCase()
  if (
    lower.includes("not authorized") ||
    lower.includes("unauthorized") ||
    lower.includes("401")
  ) {
    return "auth_unauthorized"
  }
  if (
    lower.includes("user not found") ||
    lower.includes("not_found") ||
    lower.includes("404")
  ) {
    return "user_not_found"
  }
  if (
    lower.includes("network") ||
    lower.includes("fetch failed") ||
    lower.includes("timeout")
  ) {
    return "network_error"
  }
  if (lower.includes("storage")) return "storage_error"
  if (
    lower.includes("permission") ||
    lower.includes("rls") ||
    lower.includes("42501")
  ) {
    return "permission_error"
  }
  const slug = raw.replace(/\s+/g, " ").slice(0, 120)
  return slug.length > 0 ? `purge_failed:${slug}` : "purge_failed"
}
