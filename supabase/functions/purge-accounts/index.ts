import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  authorizeCron,
  classifyPurgeError,
  corsHeaders,
  purgeSecret,
} from "../_shared/purge_policy.ts"


/**
 * Purge'ün kendi secret'ı.
 *
 * 🔴 `CRON_SECRET` bilerek KULLANILMIYOR (yalnız geriye dönük uyumluluk için
 * yedek olarak okunuyor): o değişkeni `collect-reports` ve `send-report` de
 * paylaşıyor ve `0035`teki rapor cron'u onu `app.settings.cron_secret` DB
 * ayarından gönderiyor. Purge aktivasyonu `CRON_SECRET`'i döndürseydi aylık
 * rapor cron'u sessizce 401 almaya başlardı. Ayrı değişken = sıfır çakışma.
 */
function makeAdminClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )
}

/// `ReturnType<typeof createClient>` jenerikleri kisitlariyla ornekler ve
/// sema tipi `never`e duser. Fabrikadan turetmek gercek tipi verir.
type SupabaseAdminClient = ReturnType<typeof makeAdminClient>

/**
 * WP-113 / WP-127 / WP-464: süresi dolan hesap silme isteklerini işler.
 *
 * WP-464 öncesi bu dosya doğruydu ama ÖLÜYDÜ: onu çağıran hiçbir şey yoktu
 * (ne cron, ne workflow). `0113` zamanlayıcıyı bağladı; bu sürüm de kartın
 * saydığı yapısal açıkları kapatıyor:
 *
 *   1. Claim artık atomik — `claim_account_deletion_jobs` RPC'si
 *      `for update skip locked` ile seçip aynı ifadede `processing` yazar.
 *      Eskiden select + update ayrıydı ve update'in SONUCU OKUNMUYORDU, yani
 *      iki worker aynı kullanıcıyı iki kez silmeye çalışabiliyordu.
 *   2. Çökmüş worker kurtarması — lease süresi dolan `processing` satırı
 *      yeniden claim edilir. Eskiden o satır bir daha HİÇ seçilmiyordu.
 *   3. Storage sayfalama — eskiden yalnız ilk 100 nesne siliniyordu, gerisi
 *      sessizce kalıyordu.
 *   4. Ara adım hataları artık sessiz değil; her biri kontrol edilir ve işi
 *      retry kuyruğuna düşürür.
 *   5. Tamamlanma izi — `deleteUser` cascade ile istek satırını sildiği için
 *      geriye kanıt kalmıyordu. Artık `record_account_purge_outcome` PII'siz
 *      (sha256 uid) bir denetim satırı yazar.
 *   6. WP-545: storage temizliği tek bucket'ta (`avatars`) kalmıştı. Kullanıcı
 *      klasörü taşıyan diğer iki bucket'a ve silinen grupların avatar
 *      nesnelerine hiç dokunulmuyordu. Kapsam artık tek yerde (aşağıdaki
 *      liste + grup döngüsü) durur ve yasal metinlerle aynı şeyi söyler.
 *   7. WP-549: `deleteUser` DOLAYLI `restrict` FK zincirlerine takılıyordu —
 *      `auth.users` cascade'i bir ara tabloyu silerken o ara tablonun kendi
 *      `restrict` çocukları zinciri düşürüyordu (`live_study_segments`,
 *      `study_sessions.live_run_id`, `global_timer_commands.device_id`,
 *      `moderation_appeals.sanction_id`) ve `group_delete` adımı
 *      `ugc_reports.context_group_id` yüzünden atıyordu. Şema tarafı
 *      `0124_account_purge_indirect_restrict_chains.sql`te çözüldü; burada
 *      grup sahipliği devrinin gerçekten olduğu doğrulanır (aşağıdaki
 *      `groups_owner_recheck`).
 *
 * Retry (WP-127): attempt_count < MAX_PURGE_ATTEMPTS olan işler seçilir.
 * Hata sonrası attempt < 5 → 'scheduled' (yeniden dene); >= 5 → 'failed'
 * terminal. last_error_code gerçek hata sınıfını taşır.
 */
const MAX_PURGE_ATTEMPTS = 5
const LEASE_SECONDS = 1800
const STORAGE_PAGE_SIZE = 100

/**
 * Ara adımların sessizce yutulmasını engeller.
 *
 * 🔴 Bu fonksiyonun varlık sebebi: eski sürümde e-posta kuyruğu, storage
 * silme, grup devri ve sohbet scrub adımlarının HİÇBİRİ hata kontrolü
 * yapmıyordu. Bir adım sessizce başarısız olsa bile akış `deleteUser`a kadar
 * devam ediyor, kullanıcı siliniyor ve arkada temizlenmemiş veri kalıyordu.
 */
function must<T extends { error: unknown }>(result: T, step: string): T {
  if (result?.error) {
    throw new Error(`${step}: ${String((result.error as { message?: string })?.message ?? result.error)}`)
  }
  return result
}

/**
 * WP-545: purge'ün temizlediği storage bucket'ları — TEK LISTE.
 *
 * 🔴 Bu liste WP-545'e kadar tek elemanlıydı (`avatars`). Kullanıcının
 * yüklediği geri bildirim ve şikâyet fotoğrafları hesap silindikten sonra
 * ham uid'li klasörlerinde duruyordu; yasal sayfa ise yalnız "avatar
 * dosyaları" diyordu. Beyan ile kod aynı şeyi söylemiyordu.
 *
 * Listeye girme ölçütü TEK: nesne yolunun ilk klasörü ham `auth.uid()` mi?
 * Silme `list(uid)` ile çalışır; başka bir anahtarla saklanan bir bucket bu
 * yoldan asla bulunmaz — hata bile vermez, sessizce sıfır nesne döner.
 *
 *   • avatars                    — `<uid>/avatar.jpg` (`0002_avatars_storage.sql:30`)
 *   • feedback_attachments       — `<uid>/...`        (`0072_...:31`)
 *   • report_attachments         — `<uid>/...`        (`0096_...:69`)
 *   • ticket_message_attachments — `<uid>/...`        (`0138_...:163`)
 *
 * Son ikisinin dayanağı aynı: bunlar kullanıcının KENDİ içeriğidir ve dosyayı
 * işaret eden satır (`feedback_tickets`, `ugc_reports`) `auth.users`'a
 * `on delete cascade` ile bağlıdır — satır zaten gidiyor. Nesneyi bırakmak
 * "delil saklamak" olmazdı; hiçbir satırın işaret etmediği bir fotoğraf
 * bırakırdı. Retention kararı §5.6 kapsam notu bunu açık yazıyor: kullanıcının
 * kendi bileti / kendi raporu cascade ile silinmeye devam eder.
 *
 * 🔴 `group-avatars` (`0049`) bu listede DEĞİL — ama kapsam dışında da
 * değil: AYRI bir anahtarla, aşağıda grup döngüsünde temizlenir.
 *   1. Yol anahtarı `groups.id`, kullanıcı uid'si DEĞİL
 *      (`groups_avatar_path_format` check'i + `is_group_admin((...)[1]::uuid)`
 *      politikası). `list(uid)` orada hiçbir zaman bir şey bulmaz; bu listeye
 *      eklemek ölçüm değil sahte güven üretirdi.
 *   2. Nesne grubun malıdır, yükleyenin değil. Sahibi silinen grup aşağıda
 *      en eski aktif üyeye DEVREDİLİR ve yaşamaya devam eder; o dalda
 *      avatara dokunmak başkalarının verisini silmek olurdu.
 *   3. Grup üyesiz kalıp GERÇEKTEN silindiğinde nesne aşağıda grup id'siyle
 *      düşürülür. `0049` bunu bir tetikleyiciyle yapıyordu ama `0054` onu
 *      KALDIRDI (Storage artık `storage.objects`ten doğrudan silmeye izin
 *      vermiyor) ve yerine söz verilen "periyodik storage-audit" hiçbir
 *      zaman yazılmadı. Yani WP-545 öncesi silinen her grubun avatarı
 *      sonsuza kadar sahipsiz kalıyordu.
 *
 * Sözleşme: `supabase/tests/049_account_purge_storage_scope.test.sql`.
 */
const USER_OWNED_STORAGE_BUCKETS = [
  "avatars",
  "feedback_attachments",
  "report_attachments",
  // WP-778 — 0138 KARAR 4. Vaka yazışmasına eklenen fotoğraf; yol anahtarı
  // `foldername(name)[1] = auth.uid()` (`0138_...:167`), yani üstteki ölçütü
  // aynı şekilde karşılar ve `list(uid)` onu gerçekten bulur.
  "ticket_message_attachments",
] as const

type StoragePurgeReport = {
  removed: Record<string, number>
  failures: string[]
}

/**
 * Bir bucket'ta TEK bir klasörü SAYFALAYARAK siler; 100 nesne sınırı yoktur.
 *
 * Klasör adı kasıtlı olarak `uid` değil `folder`: `avatars` /
 * `feedback_attachments` / `report_attachments` için uid'dir, `group-avatars`
 * için `groups.id`'dir. Aynı sayfalama iki durumda da geçerlidir.
 */
async function purgeStorageFolder(
  admin: SupabaseAdminClient,
  bucket: string,
  folder: string,
): Promise<number> {
  let removed = 0
  // Her turda BAŞTAN okunur: bir önceki tur o nesneleri zaten sildiği için
  // offset ilerletmek gerekmez (ilerletmek tam tersine, kayan liste yüzünden
  // nesne atlardı). Sayfa dolu geldiği sürece devam eder.
  const MAX_PAGES = 200
  for (let page = 0; page < MAX_PAGES; page++) {
    const listed = await admin.storage
      .from(bucket)
      .list(folder, { limit: STORAGE_PAGE_SIZE })
    must(listed, `storage_list:${bucket}`)
    const files = listed.data ?? []
    if (files.length === 0) break

    const paths = files.map((f) => `${folder}/${f.name}`)
    must(
      await admin.storage.from(bucket).remove(paths),
      `storage_remove:${bucket}`,
    )
    removed += paths.length

    if (files.length < STORAGE_PAGE_SIZE) break
  }
  return removed
}

/**
 * Her bucket AYRI denenir: birinin patlaması diğerlerini engellemez ve sonuç
 * bucket bazında raporlanır (`results[].storage`).
 *
 * 🔴 Ama en az bir bucket patladıysa çağıran YINE DE atar — bu fonksiyon
 * kendi başına atmaz, kısmi sonucu döndürür. Sebep §4'te yazılı: sessizce
 * devam etmek `deleteUser`a kadar gider, kullanıcı silinir, dosyaları kalır ve
 * istek satırı cascade ile gittiği için bir daha HİÇ denenemez. `avatars`
 * temizliği WP-464'ten beri tam olarak bu toleransı taşıyor; yeni bucket'lar
 * aynısını taşır.
 */
async function purgeUserStorage(
  admin: SupabaseAdminClient,
  uid: string,
): Promise<StoragePurgeReport> {
  const report: StoragePurgeReport = { removed: {}, failures: [] }
  for (const bucket of USER_OWNED_STORAGE_BUCKETS) {
    try {
      report.removed[bucket] = await purgeStorageFolder(admin, bucket, uid)
    } catch (err) {
      const message = String((err as { message?: string })?.message ?? err)
      report.failures.push(`${bucket} (${message})`)
    }
  }
  return report
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const denied = authorizeCron(req)
    if (denied) return denied

    const body = await req.json().catch(() => ({}))
    const limit = Math.min(Number(body.limit ?? 5), 20)
    const dryRun = body.dry_run === true

    const admin = makeAdminClient()

    // Aktivasyon: zamanlayıcının çalışması için `0113`teki runtime config
    // satırı yazılmalı. `dispatch-push`taki `configure_dispatch` deseninin
    // aynısı — secret istek gövdesinde TAŞINMAZ, fonksiyon kendi ortamından
    // okur. Yapılandırma yazılmadıkça `_request_scheduled_account_purge()`
    // sessizce çıkar ve sağlık `not_configured` der.
    if (body.action === "configure_purge") {
      const secret = purgeSecret()
      if (!secret) {
        return new Response(
          JSON.stringify({ error: "purge_secret_missing" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        )
      }
      const { error } = await admin
        .from("account_purge_runtime_config")
        .upsert({
          singleton: true,
          functions_base_url: Deno.env.get("SUPABASE_URL") ?? "",
          cron_secret: secret,
          updated_at: new Date().toISOString(),
        })
      if (error) {
        // Secret hiçbir hata mesajına yazılmaz.
        console.error("configure_purge failed", error.message)
        return new Response(
          JSON.stringify({ error: "configure_purge_failed" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        )
      }
      return new Response(
        JSON.stringify({ configured: true }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    // Salt-okunur sağlık. Hiçbir iş claim etmez, hiçbir hesap silmez.
    // `configuration_status` burada kritik: yapılandırılmamış bir kuyruk sıfır
    // hata üretir ve "sağlıklı" görünür.
    if (body.action === "purge_health") {
      const { data, error } = await admin.rpc("get_account_purge_health")
      if (error) {
        console.error("purge_health failed", error.message)
        return new Response(
          JSON.stringify({ error: "purge_health_failed" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        )
      }
      return new Response(
        JSON.stringify({ health: Array.isArray(data) ? data[0] : data }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    type Job = {
      id: string
      user_id: string
      attempt_count: number
      purge_after: string | null
      recovered_from_stale?: boolean
    }
    let jobs: Job[] = []

    if (dryRun) {
      // Dry-run hiçbir satırı claim ETMEZ; yalnız neyin sırada olduğunu okur.
      const { data, error } = await admin
        .from("account_deletion_requests")
        .select("id, user_id, attempt_count, purge_after")
        .in("status", ["scheduled", "failed"])
        .lt("attempt_count", MAX_PURGE_ATTEMPTS)
        .lte("purge_after", new Date().toISOString())
        .order("purge_after", { ascending: true })
        .limit(limit)
      if (error) throw error
      jobs = (data ?? []) as Job[]
    } else {
      // 🔴 Tek kapı: seçim ve işaretleme aynı ifadede, `skip locked` ile.
      // Claim'i kazanamayan worker o işi hiç görmez.
      const { data, error } = await admin.rpc("claim_account_deletion_jobs", {
        p_limit: limit,
        p_lease_seconds: LEASE_SECONDS,
        p_max_attempts: MAX_PURGE_ATTEMPTS,
      })
      if (error) throw error
      jobs = (data ?? []) as Job[]
    }

    if (!jobs.length) {
      return new Response(
        JSON.stringify({ processed: 0, dry_run: dryRun, message: "no due jobs" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        },
      )
    }

    const results: Array<Record<string, unknown>> = []

    for (const job of jobs) {
      const uid = job.user_id
      const id = job.id
      // Hata yolunda da raporlanabilsin diye `try` DIŞINDA durur: hangi
      // bucket temizlendi, hangisi patladı sorusu bir sonraki denemeye
      // kalmamalı.
      let storage: StoragePurgeReport = { removed: {}, failures: [] }
      try {
        if (!dryRun) {
          // E-posta kuyruğu: pending işleri iptal et.
          must(
            await admin
              .from("email_job_queue")
              .update({ status: "abandoned", error_log: "account_deletion" })
              .eq("user_id", uid)
              .eq("status", "pending"),
            "email_queue_abandon",
          )

          storage = await purgeUserStorage(admin, uid)
          if (storage.failures.length) {
            // Toplu atma: her bucket ölçüldü (ilk hata diğerlerini gizlemedi)
            // ve iş retry kuyruğunda kalıyor — kullanıcı artık dosyaları
            // arkada dururken silinmiyor.
            throw new Error(
              `storage_purge failed for ${storage.failures.join(", ")}`,
            )
          }

          // Grup ownership: created_by bu kullanıcı ise en eski aktif üyeye
          // devret, aktif üye yoksa grubu sil.
          const owned = must(
            await admin.from("groups").select("id").eq("created_by", uid),
            "groups_owned_fetch",
          )
          for (const g of owned.data ?? []) {
            const members = must(
              await admin
                .from("group_members")
                .select("user_id, joined_at")
                .eq("group_id", g.id)
                .is("left_at", null)
                .neq("user_id", uid)
                .order("joined_at", { ascending: true })
                .limit(1),
              "group_members_fetch",
            )
            if (members.data?.length) {
              must(
                await admin
                  .from("groups")
                  .update({ created_by: members.data[0].user_id })
                  .eq("id", g.id),
                "group_owner_transfer",
              )
            } else {
              // 🔴 WP-549: bu adim `0124`e BAGIMLIDIR. `0124` oncesi
              // `ugc_reports.context_group_id -> groups` FK'si `on delete
              // restrict` idi (`0104:12`) ve raporu YAZAN kullanici silinen
              // kullanicidan farkli olabildigi icin o satiri hicbir cascade
              // temizlemiyordu. Sonuc: o grupta bir kez sikayet acilmissa bu
              // `delete` FK ihlaliyle atiyor, `must(...)` isi retry kuyruguna
              // dusuruyor, 5 deneme yaniyor ve hesap terminal `failed` oluyordu
              // -- yani hesap HIC silinmiyordu. `0124` FK'yi `set null`a cevirdi
              // ve baglami `context_group_id_snapshot`ta dondurdu: kanit kalir,
              // silme akar. Sozlesme: `supabase/tests/050_*.test.sql` §3.
              must(
                await admin.from("groups").delete().eq("id", g.id),
                "group_delete",
              )
              // 🔴 WP-545: grubun avatar nesnesi. `0049` bunu bir
              // tetikleyiciyle düşürüyordu, `0054` onu kaldırdı (Storage
              // artık DB'den doğrudan silmeye izin vermiyor) ve yerine söz
              // verilen periyodik storage-audit hiç yazılmadı — silinen her
              // grubun fotoğrafı sahipsiz kalıyordu.
              //
              // Anahtar `groups.id`, uid DEĞİL; bu bucket kullanıcı uzayı
              // değildir, o yüzden `USER_OWNED_STORAGE_BUCKETS`e giremez.
              //
              // Şu SIRA bilinçlidir: önce satır, sonra nesne. Ters sırada
              // `group_delete` bir FK'ye takılıp atsaydı grup HAYATTA kalır
              // ama fotoğrafı silinmiş olurdu — henüz silinmemiş bir grubun
              // üyelerinin verisini bozmak, bir nesnenin sızmasından ağırdır.
              await purgeStorageFolder(admin, "group-avatars", String(g.id))
            }
          }

          // 🔴 WP-549 son kapı: `deleteUser`dan ÖNCE hiçbir grup artık bu
          // kullanıcıya ait OLMAMALI.
          //
          // Sebep: `groups.created_by -> auth.users` `on delete cascade`
          // (`0001:27`). Yukarıdaki döngü devri `update(...)` ile yapıyor ve
          // `must()` yalnız `error` alanına bakıyor — Supabase `update`i
          // hiçbir satır eşleşmediğinde de hatasız döner. Yani devir SESSİZCE
          // 0 satır güncellemiş olsaydı `created_by` bu kullanıcıda kalır ve
          // `deleteUser` cascade'i, İÇİNDE AKTİF ÜYELERİ OLAN bir grubu ve
          // (`group_members`, `class_messages`, `nudges`, `group_bans` …)
          // üçüncü kişilerin verisini sessizce yok ederdi.
          //
          // Bu kontrol o sessiz yıkımı, işi retry kuyruğunda tutan bir hataya
          // çevirir. §4'teki "sessizce devam etme" ilkesinin aynısı.
          const stillOwned = must(
            await admin.from("groups").select("id").eq("created_by", uid),
            "groups_owner_recheck",
          )
          if (stillOwned.data?.length) {
            throw new Error(
              `groups_owner_recheck: ${stillOwned.data.length} group(s) still ` +
                `owned by the account; deleteUser would cascade-delete them`,
            )
          }

          // Sohbet scrub. Retention kararı §5.3: metin scrub edilir, satır
          // grup geçmişini bozmamak için durur.
          must(
            await admin
              .from("class_messages")
              .update({ body: "[silindi]" })
              .eq("user_id", uid),
            "class_messages_scrub",
          )

          const { error: delErr } = await admin.auth.admin.deleteUser(uid)
          if (delErr) throw delErr

          // 🔴 Denetim izi CASCADE'den ÖNCE değil sonra yazılır ve istek
          // satırına bağlı değildir; `deleteUser` o satırı silmiş olabilir.
          // PII yok: sunucu tarafında sha256(uid) saklanır.
          const { error: auditErr } = await admin.rpc(
            "record_account_purge_outcome",
            {
              p_request_id: id,
              p_user_id: uid,
              p_outcome: "completed",
              p_attempt_count: job.attempt_count ?? 0,
              p_error_code: null,
              p_purge_after: job.purge_after,
            },
          )
          if (auditErr) {
            // Kullanıcı gerçekten silindi; denetim yazılamadıysa bunu
            // yutmuyoruz ama işi de "başarısız" sayıp tekrar silmeye
            // çalışmıyoruz — silinecek kullanıcı kalmadı.
            console.error("purge audit write failed", id, auditErr.message)
          }

          const { data: completedRows, error: completeErr } = await admin
            .from("account_deletion_requests")
            .update({
              status: "completed",
              completed_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
              last_error_code: null,
            })
            .eq("id", id)
            .select("id")

          if (completeErr) {
            console.warn(
              "purge complete update skipped/failed (likely cascade delete)",
              id,
              completeErr.message,
            )
          } else if (!completedRows?.length) {
            console.info(
              "purge complete: request row already gone (ON DELETE CASCADE after deleteUser)",
              id,
            )
          }
        }

        results.push({
          id,
          user_id: uid,
          status: dryRun ? "dry_run_ok" : "completed",
          recovered_from_stale: job.recovered_from_stale ?? false,
          storage: storage.removed,
        })
      } catch (err) {
        const attempt = (job.attempt_count ?? 0) + 1
        const code = classifyPurgeError(err)
        const nextStatus = attempt >= MAX_PURGE_ATTEMPTS ? "failed" : "scheduled"
        if (!dryRun) {
          const { error: updErr } = await admin
            .from("account_deletion_requests")
            .update({
              status: nextStatus,
              attempt_count: attempt,
              last_error_code: code,
              claimed_at: null,
              updated_at: new Date().toISOString(),
            })
            .eq("id", id)
          if (updErr) {
            // Bunu yutmak, işin `processing`de asılı kalması demekti. Lease
            // kurtarması yine de devreye girer, ama iz bırakmadan geçmeyiz.
            console.error("purge status writeback failed", id, updErr.message)
          }

          // Terminal başarısızlık da denetim izine girer: "neden silinmedi"
          // sorusunun cevabı kalmalı.
          if (nextStatus === "failed") {
            const { error: auditErr } = await admin.rpc(
              "record_account_purge_outcome",
              {
                p_request_id: id,
                p_user_id: uid,
                p_outcome: "failed",
                p_attempt_count: attempt,
                p_error_code: code,
                p_purge_after: job.purge_after,
              },
            )
            if (auditErr) {
              console.error("purge audit write failed", id, auditErr.message)
            }
          }
        }
        results.push({
          id,
          user_id: uid,
          status: nextStatus,
          attempt_count: attempt,
          error_code: code,
          terminal: nextStatus === "failed",
          storage: storage.removed,
          storage_failures: storage.failures,
        })
        console.error("purge failed", id, code, String(err))
      }
    }

    return new Response(
      JSON.stringify({ processed: results.length, dry_run: dryRun, results }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    })
  }
})
