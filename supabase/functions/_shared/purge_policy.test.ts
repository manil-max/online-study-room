/**
 * `purge-accounts` karar mantığı — davranış testleri.
 *
 * Çalıştırma (repo kökü):
 *   deno test --no-lock supabase/functions/
 *
 * 🔴 Bu dosyanın varlık sebebi: altı Edge Function (1601 satır) **hiç test
 * edilmemişti** ve `purge-accounts` kullanıcı verisini kalıcı olarak siler.
 * `deno check` yalnız tiplerin tuttuğunu söyler; yetkilendirmenin gerçekten
 * kapalı olduğunu söylemez.
 */

import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts"

import { authorizeCron, classifyPurgeError, purgeSecret } from "./purge_policy.ts"

function withEnv(vars: Record<string, string | null>, run: () => void) {
  const previous: Record<string, string | undefined> = {}
  for (const [key, value] of Object.entries(vars)) {
    previous[key] = Deno.env.get(key)
    if (value === null) Deno.env.delete(key)
    else Deno.env.set(key, value)
  }
  try {
    run()
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key)
      else Deno.env.set(key, value)
    }
  }
}

const request = (headers: Record<string, string>) =>
  new Request("https://example.test/purge", { headers })

// ─── purgeSecret ───────────────────────────────────────────────────────────

Deno.test("purgeSecret oncelikle PURGE_CRON_SECRET okur", () => {
  withEnv({ PURGE_CRON_SECRET: "purge-key", CRON_SECRET: "rapor-key" }, () => {
    assertEquals(purgeSecret(), "purge-key")
  })
})

// 🔴 `CRON_SECRET`i `collect-reports` ve `send-report` paylasiyor. Purge onu
// EZERSE aylik rapor cron'u sessizce 401 almaya baslar.
Deno.test("purgeSecret yalniz kendi anahtari yokken CRON_SECRET'e duser", () => {
  withEnv({ PURGE_CRON_SECRET: null, CRON_SECRET: "rapor-key" }, () => {
    assertEquals(purgeSecret(), "rapor-key")
  })
})

Deno.test("purgeSecret bosluklari kirpar", () => {
  withEnv({ PURGE_CRON_SECRET: "  key  ", CRON_SECRET: null }, () => {
    assertEquals(purgeSecret(), "key")
  })
})

// ─── authorizeCron ─────────────────────────────────────────────────────────

Deno.test("dogru x-cron-secret basligi yetki verir", () => {
  withEnv({ PURGE_CRON_SECRET: "key", SUPABASE_SERVICE_ROLE_KEY: null }, () => {
    assertEquals(authorizeCron(request({ "x-cron-secret": "key" })), null)
  })
})

Deno.test("Bearer <cron secret> yetki verir", () => {
  withEnv({ PURGE_CRON_SECRET: "key", SUPABASE_SERVICE_ROLE_KEY: null }, () => {
    assertEquals(
      authorizeCron(request({ Authorization: "Bearer key" })),
      null,
    )
  })
})

Deno.test("Bearer <service role key> yetki verir", () => {
  withEnv({ PURGE_CRON_SECRET: "key", SUPABASE_SERVICE_ROLE_KEY: "svc" }, () => {
    assertEquals(
      authorizeCron(request({ Authorization: "Bearer svc" })),
      null,
    )
  })
})

// 🔴 EN KRITIK TEST: yetkisiz istek kullanici verisi SILEMEZ.
Deno.test("yanlis secret 401 ile reddedilir", async () => {
  await withEnvAsync(
    { PURGE_CRON_SECRET: "key", SUPABASE_SERVICE_ROLE_KEY: "svc" },
    async () => {
      const response = authorizeCron(request({ "x-cron-secret": "yanlis" }))
      assertNotEquals(response, null)
      assertEquals(response!.status, 401)
      assertEquals(await response!.json(), { error: "Unauthorized" })
    },
  )
})

Deno.test("basliksiz istek reddedilir", () => {
  withEnv({ PURGE_CRON_SECRET: "key", SUPABASE_SERVICE_ROLE_KEY: "svc" }, () => {
    assertEquals(authorizeCron(request({}))?.status, 401)
  })
})

// 🔴 Fail-closed: hicbir secret tanimli degilse yetki VERILMEMELI. Aksi hâlde
// yanlis yapilandirilmis bir ortamda purge herkese acik olurdu.
Deno.test("hicbir secret tanimli degilse istek reddedilir", () => {
  withEnv(
    {
      PURGE_CRON_SECRET: null,
      CRON_SECRET: null,
      SUPABASE_SERVICE_ROLE_KEY: null,
    },
    () => {
      assertEquals(authorizeCron(request({ "x-cron-secret": "" }))?.status, 401)
      assertEquals(authorizeCron(request({ Authorization: "Bearer " }))?.status, 401)
    },
  )
})

// Bos secret'la bos baslik ESLESMEMELI (`"" === ""` tuzagi).
Deno.test("bos secret bos baslikla eslesmez", () => {
  withEnv(
    { PURGE_CRON_SECRET: "", CRON_SECRET: null, SUPABASE_SERVICE_ROLE_KEY: "" },
    () => {
      assertEquals(authorizeCron(request({ "x-cron-secret": "" }))?.status, 401)
    },
  )
})

// ─── classifyPurgeError ────────────────────────────────────────────────────

Deno.test("hata siniflari kararli kodlara indirgenir", () => {
  const cases: Array<[unknown, string]> = [
    ["Not authorized", "auth_unauthorized"],
    ["HTTP 401", "auth_unauthorized"],
    ["User not found", "user_not_found"],
    ["status 404", "user_not_found"],
    ["fetch failed", "network_error"],
    ["request timeout", "network_error"],
    ["storage bucket missing", "storage_error"],
    ["permission denied", "permission_error"],
    ["error 42501", "permission_error"],
  ]
  for (const [input, expected] of cases) {
    assertEquals(classifyPurgeError(input), expected, `girdi: ${input}`)
  }
})

Deno.test("bilinmeyen hata slug'a indirgenir ve 120 karakteri asmaz", () => {
  const code = classifyPurgeError("x".repeat(500))
  assertEquals(code.startsWith("purge_failed:"), true)
  assertEquals(code.length <= "purge_failed:".length + 120, true)
})

Deno.test("bos/null hata yine de kararli bir kod uretir", () => {
  // Kod bos donerse retry sinifi kaybolur ve is sonsuz donguye girebilir.
  assertEquals(classifyPurgeError(null), "purge_failed:unknown")
  assertEquals(classifyPurgeError(""), "purge_failed")
})

// ─── yardimci ──────────────────────────────────────────────────────────────

async function withEnvAsync(
  vars: Record<string, string | null>,
  run: () => Promise<void>,
) {
  const previous: Record<string, string | undefined> = {}
  for (const [key, value] of Object.entries(vars)) {
    previous[key] = Deno.env.get(key)
    if (value === null) Deno.env.delete(key)
    else Deno.env.set(key, value)
  }
  try {
    await run()
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key)
      else Deno.env.set(key, value)
    }
  }
}
