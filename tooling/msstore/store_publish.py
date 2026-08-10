# -*- coding: utf-8 -*-
"""Microsoft Store'a MSIX PAKET GUNCELLEMESI gonderir (WP-669).

NEDEN BU API: Microsoft'un iki ayri gonderim API'si var ve ikisi ayni seyi
yapmiyor.

  1. "Microsoft Store submission API for MSI or EXE app"
     https://learn.microsoft.com/en-us/windows/apps/publish/store-submission-api
     Taban adres `https://api.store.microsoft.com`, kapsam
     `https://api.store.microsoft.com/.default`. Belge paket turunu ACIKCA
     sinirliyor: "Use the Microsoft Store submission API for MSI or EXE app".
     Paket turu alani `packageType | String | Required [exe, msi]`. MSIX YOK.

  2. "Microsoft Store submission API" (kullandigimiz)
     https://learn.microsoft.com/en-us/windows/uwp/monetize/create-and-manage-submissions-using-windows-store-services
     Taban adres `https://manage.devcenter.microsoft.com/v1.0/my/`, kimlik
     dogrulama Azure AD v1 client_credentials, `resource=` degeri
     `https://manage.devcenter.microsoft.com`. Paket akisinin tamami MSIX
     pivotuna baglanmis (`?pivots=store-installer-msix`) ve paket kaynagi
     `.appx/.msix` dosya adiyla ornekleniyor.

Yani MSIX icin "yeni" API degil, bu API dogru olan. Yanlisini secmek sahibe
konsol isi cikartirdi: MSI/EXE API'sinde paket, Store'a YUKLENMEZ, kendi
sunucunda barindirdigin bir URL olarak verilir -- bizim hattimizin urettigi
imzasiz MSIX oraya hic girmez.

NE OTOMATIKLESIYOR: yalniz PAKET GUNCELLEMESI. Ilk gonderimi (listeleme metni,
yas derecelendirmesi, fiyat, ekran goruntuleri) sahip Partner Center'da ELLE
yapar; API bunu yapamaz -- belge sart kosuyor:
"Before you can create a submission for a given app using this API, you must
first create one submission for the app in Partner Center, including answering
the age ratings questionnaire."

TAHMIN YOK: `verify` kipi ONCE OKUR. Paket kimligi, yayinci ve yayinda olan
surum Partner Center'dan LISTELENIR; repo degiskenlerine guvenilmez. Play
tarafinda ayni karar verildi (iz adi tahmin edilmez, API'den listelenir).

TEK KAYNAK: magaza notlari `app/assets/release_notes.json`den TURETILIR.
"What's new in this version" alani 1500 karakter siniri tasir:
https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/add-and-edit-store-listing-info
"This field has a 1500 character limit. (Previously, this field was called
Release notes)."
"""
import argparse
import io
import json
import os
import sys
import time
import zipfile

# Store ID sir degildir; magaza sayfasinin adresinde gorunur.
# Partner Center -> Product identity -> Store ID.
STORE_ID = "9PCS5SRM93CX"

BASE = "https://manage.devcenter.microsoft.com/v1.0/my"
RESOURCE = "https://manage.devcenter.microsoft.com"
TOKEN_URL = "https://login.microsoftonline.com/%s/oauth2/token"

# Store listeleme alani siniri (yukaridaki belge).
MAX_NOTE = 1500

# Azure Blob'a tek `Put Blob` cagrisiyla yazilabilen ust sinir 256 MiB'dir.
# Bizim paketimiz ~30 MB; buyurse blok listesi gerekir, o yuzden fail-closed.
MAX_UPLOAD_BYTES = 200 * 1024 * 1024

CREDENTIAL_VARS = ("MS_STORE_TENANT_ID", "MS_STORE_CLIENT_ID", "MS_STORE_CLIENT_SECRET")

# Yanit-only alanlar: PUT govdesine geri yazilmaz.
RESPONSE_ONLY = ("id", "status", "statusDetails", "fileUploadUrl")

# Commit sonrasi bu durumlar isi KIRMIZI dusurur.
FAILED_STATUS = (
    "CommitFailed",
    "PreProcessingFailed",
    "CertificationFailed",
    "PublishFailed",
    "ReleaseFailed",
    "Canceled",
)


# ------------------------------------------------------------------ MSIX
def read_msix_identity(path):
    """MSIX'in KENDI icinden kimligi okur.

    Paket adini/surumu komut satirindan ya da repo degiskeninden okumak,
    "bayrak sessizce yok sayildi" hatasini goremez. Tek dogru kaynak paketin
    icindeki `AppxManifest.xml`dir.
    """
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if "AppxManifest.xml" not in names:
            raise ValueError("MSIX icinde AppxManifest.xml yok: %s" % path)
        raw = archive.read("AppxManifest.xml")
    return parse_appx_identity(raw)


def parse_appx_identity(raw):
    import xml.etree.ElementTree as ET

    root = ET.fromstring(raw)
    identity = None
    for element in root.iter():
        if element.tag.rsplit("}", 1)[-1] == "Identity":
            identity = element
            break
    if identity is None:
        raise ValueError("AppxManifest.xml icinde Identity dugumu yok")
    out = {}
    for key in ("Name", "Publisher", "Version"):
        value = identity.get(key)
        if not value:
            raise ValueError("AppxManifest Identity/%s bos" % key)
        out[key] = value
    return out


def parse_version(text):
    """Store paket surumu DORT alanlidir; uc alanli metin sessizce kabul edilmez."""
    parts = str(text).split(".")
    if len(parts) != 4:
        raise ValueError("Paket surumu dort alanli olmali: %r" % text)
    try:
        return tuple(int(p) for p in parts)
    except ValueError:
        raise ValueError("Paket surumu sayisal olmali: %r" % text)


def derive_build_number(version):
    """Paket surumunden build numarasini TURETIR; elle yazilmaz.

    Stable Windows paketi `1.0.<patch>.0` semasindadir (windows-release.yml) ve
    build numarasi = patch. Dorduncu alan 0 DEGILSE elimizdeki paket bir BETA
    paketidir (`1.0.<patch>.<sira>`); beta Store'a gonderilmez, o yuzden burada
    durur -- yanlis kanalin paketini magazaya yuklemek geri alinmasi en pahali
    hatalardan biri.
    """
    major, minor, patch, revision = parse_version(version)
    if (major, minor) != (1, 0):
        raise ValueError("Beklenmeyen surum onegi: %s (1.0.x.y bekleniyor)" % version)
    if revision != 0:
        raise ValueError(
            "Dorduncu alan 0 degil: %s -- bu bir BETA paketi, Store'a gonderilmez"
            % version
        )
    if patch <= 0:
        raise ValueError("Gecersiz build numarasi: %s" % version)
    return patch


def assert_identity_matches(package, app):
    """Paketin kimligi Partner Center'daki uygulamayla ayni mi.

    Eslesmezse gonderim reddedilir; bunu CI'da yakalamak, koca bir surum
    kosumundan sonra Partner Center'dan ogrenmekten ucuzdur.
    """
    problems = []
    for manifest_key, app_key, label in (
        ("Name", "packageIdentityName", "paket kimlik adi"),
        ("Publisher", "publisherName", "yayinci"),
    ):
        want = (app.get(app_key) or "").strip()
        got = (package.get(manifest_key) or "").strip()
        if not want:
            problems.append("Partner Center %s alani bos geldi (%s)" % (app_key, label))
        elif want != got:
            problems.append("%s uyusmuyor: pakette %r, magazada %r" % (label, got, want))
    if problems:
        raise ValueError("; ".join(problems))


def assert_version_is_newer(new_version, existing_packages):
    """Ayni ya da daha eski surum Store tarafindan reddedilir."""
    new_tuple = parse_version(new_version)
    for package in existing_packages or []:
        old = package.get("version")
        if not old:
            continue
        if new_tuple <= parse_version(old):
            raise ValueError(
                "Yeni paket surumu ilerlemiyor: %s <= %s (%s)"
                % (new_version, old, package.get("fileName"))
            )


def plan_packages(existing, new_file_name):
    """Eski paketleri SILINECEK, yeni paketi YUKLENECEK olarak isaretler.

    Eskileri birakmak, magazada iki surumun yan yana kalmasi demek.
    """
    if not new_file_name:
        raise ValueError("yeni paket adi bos")
    planned = []
    for package in existing or []:
        name = package.get("fileName")
        if name == new_file_name:
            raise ValueError(
                "Ayni dosya adi zaten gonderimde: %s -- surum artmadan yeniden "
                "yuklenemez" % name
            )
        item = dict(package)
        item["fileStatus"] = "PendingDelete"
        planned.append(item)
    planned.append(
        {
            "fileName": new_file_name,
            "fileStatus": "PendingUpload",
            # Belge: guncelleme cagrisinda bu iki alan ZORUNLU, degeri
            # Windows 8.x disi hedeflerde yok sayilir.
            "minimumDirectXVersion": "None",
            "minimumSystemRam": "None",
        }
    )
    return planned


# ------------------------------------------------------------------ notlar
def build_note(release, lang):
    """Bir surum kaydindan tek dilde magaza notu uretir (Play ile ayni kural)."""
    if lang == "tr":
        parts = list(release.get("highlights", [])) + list(release.get("fixes", []))
    elif lang == "en":
        parts = list(release.get("highlightsEn", [])) + list(release.get("fixesEn", []))
    else:
        raise ValueError("bilinmeyen dil: %s" % lang)

    if not parts:
        raise ValueError("%s icin madde yok; bos not yayinlanmaz" % lang)

    out = []
    used = 0
    for part in parts:
        line = "• " + part.strip()
        cost = len(line) + (1 if out else 0)
        if used + cost > MAX_NOTE:
            break
        out.append(line)
        used += cost

    if not out:
        head = parts[0].strip()
        out = ["• " + head[: MAX_NOTE - 4] + "…"]

    note = "\n".join(out)
    assert len(note) <= MAX_NOTE, len(note)
    return note


def find_release(doc, build_number):
    for release in doc["releases"]:
        if int(release["buildNumber"]) == int(build_number):
            return release
    raise ValueError("release_notes.json icinde build %s yok" % build_number)


def load_notes(path, build_number):
    raw = io.open(path, "rb").read()
    doc = json.loads(raw.decode("utf-8-sig"))
    release = find_release(doc, build_number)
    return {"tr": build_note(release, "tr"), "en": build_note(release, "en")}


def apply_release_notes(listings, notes):
    """`What's new in this version` alanini her dil icin yazar.

    Dil anahtarlari Partner Center'dan gelir (`tr-tr`, `en-us` gibi); burada
    TAHMIN EDILMEZ, gelen anahtarlar uzerinde dolasilir.
    """
    if not listings:
        raise ValueError("Gonderimde hic magaza listelemesi yok; not yazilamaz")
    touched = []
    for lang, listing in listings.items():
        base = listing.get("baseListing")
        if base is None:
            raise ValueError("%s listelemesinde baseListing yok" % lang)
        note = notes["tr"] if lang.lower().startswith("tr") else notes["en"]
        if len(note) > MAX_NOTE:
            raise ValueError("%s notu %s karakter (sinir %s)" % (lang, len(note), MAX_NOTE))
        base["releaseNotes"] = note
        touched.append(lang)
    return touched


# ------------------------------------------------------------------ kimlik
def credentials():
    """Uc secret'i FAIL-CLOSED okur. Yarim yapilandirma da durdurur."""
    present = {name: os.environ.get(name, "").strip() for name in CREDENTIAL_VARS}
    missing = [name for name, value in present.items() if not value]
    if missing:
        raise SystemExit(
            "Microsoft Store kimligi eksik (%d/%d dolu). Eksik: %s\n"
            "Ucu birden gerekir; yarim yapilandirmayla gonderim YAPILMAZ."
            % (len(CREDENTIAL_VARS) - len(missing), len(CREDENTIAL_VARS), ", ".join(missing))
        )
    return present


def access_token(creds):
    import requests

    response = requests.post(
        TOKEN_URL % creds["MS_STORE_TENANT_ID"],
        data={
            "grant_type": "client_credentials",
            "client_id": creds["MS_STORE_CLIENT_ID"],
            "client_secret": creds["MS_STORE_CLIENT_SECRET"],
            "resource": RESOURCE,
        },
        timeout=120,
    )
    if response.status_code >= 400:
        # Secret govdeye yazilmaz; yalniz durum kodu ve Azure'un hata kodu.
        try:
            detail = response.json().get("error_description", "")[:400]
        except Exception:
            detail = ""
        raise SystemExit(
            "Azure AD jetonu alinamadi (%s). %s" % (response.status_code, detail)
        )
    return response.json()["access_token"]


def make_session(token):
    import requests

    session = requests.Session()
    session.headers["Authorization"] = "Bearer %s" % token
    session.headers["Content-Type"] = "application/json"
    return session


def call(session, method, url, **kwargs):
    response = session.request(method, url, timeout=600, **kwargs)
    if response.status_code >= 400:
        raise SystemExit(
            "Store API %s %s -> %s\n%s"
            % (method, url.split("?")[0], response.status_code, response.text[:2000])
        )
    return response.json() if response.content else {}


# ------------------------------------------------------------------ kipler
def app_url(app_id):
    return "%s/applications/%s" % (BASE, app_id)


def verify(session, app_id, msix_path=None):
    """ONCE OKUR: kimlik, yayinci, yayindaki surum. Hicbir sey yazmaz."""
    app = call(session, "GET", app_url(app_id))
    sys.stdout.write("Store ID          : %s\n" % app.get("id"))
    sys.stdout.write("Uygulama adi      : %s\n" % app.get("primaryName"))
    sys.stdout.write("Paket kimlik adi  : %s\n" % app.get("packageIdentityName"))
    sys.stdout.write("Yayinci           : %s\n" % app.get("publisherName"))
    sys.stdout.write("Paket ailesi      : %s\n" % app.get("packageFamilyName"))
    sys.stdout.write("Ilk yayin         : %s\n" % app.get("firstPublishedDate"))

    pending = app.get("pendingApplicationSubmission")
    published = app.get("lastPublishedApplicationSubmission")
    sys.stdout.write(
        "Bekleyen gonderim : %s\n" % (pending.get("id") if pending else "(yok)")
    )
    sys.stdout.write(
        "Son yayinlanan    : %s\n" % (published.get("id") if published else "(yok)")
    )

    if not published:
        sys.stdout.write(
            "\n🔴 Bu uygulamanin YAYINLANMIS gonderimi yok. Bu API ilk gonderimi\n"
            "   yapamaz: sahip Partner Center'da bir kez elle gonderim yapmali\n"
            "   (yas derecelendirmesi anketi dahil).\n"
        )
        return 1

    submission = call(
        session, "GET", "%s/submissions/%s" % (app_url(app_id), published["id"])
    )
    packages = submission.get("applicationPackages", []) or []
    sys.stdout.write("\nYayindaki paketler (%d):\n" % len(packages))
    for package in packages:
        sys.stdout.write(
            "  - %-40s surum=%-12s mimari=%-6s durum=%s\n"
            % (
                package.get("fileName"),
                package.get("version"),
                package.get("architecture"),
                package.get("fileStatus"),
            )
        )
    sys.stdout.write(
        "Listeleme dilleri : %s\n"
        % (", ".join(sorted(submission.get("listings", {}).keys())) or "(yok)")
    )

    if msix_path:
        package = read_msix_identity(msix_path)
        sys.stdout.write(
            "\nYerel paket       : ad=%s surum=%s\n" % (package["Name"], package["Version"])
        )
        assert_identity_matches(package, app)
        assert_version_is_newer(package["Version"], packages)
        sys.stdout.write("Kimlik ve surum ilerlemesi TAMAM.\n")
    return 0


def zip_package(msix_path, work_dir):
    """Store, paketleri TEK bir ZIP arsivi icinde bekler."""
    name = os.path.basename(msix_path)
    zip_path = os.path.join(work_dir, "submission.zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.write(msix_path, name)
    size = os.path.getsize(zip_path)
    if size > MAX_UPLOAD_BYTES:
        raise SystemExit(
            "Arsiv cok buyuk (%.1f MB); tek cagrilik yukleme siniri asildi."
            % (size / 1048576.0)
        )
    sys.stdout.write("arsiv: %s (%.1f MB, icinde %s)\n" % (zip_path, size / 1048576.0, name))
    return zip_path, name


def put_blob(url, path):
    import requests

    with io.open(path, "rb") as handle:
        response = requests.put(
            url,
            data=handle,
            headers={
                "x-ms-blob-type": "BlockBlob",
                "Content-Type": "application/zip",
            },
            timeout=1800,
        )
    if response.status_code >= 400:
        raise SystemExit(
            "Arsiv yuklenemedi (%s): %s" % (response.status_code, response.text[:1000])
        )
    sys.stdout.write("arsiv yuklendi (HTTP %s)\n" % response.status_code)


def upload(session, app_id, msix_path, notes, allow_delete_pending, poll_seconds):
    package = read_msix_identity(msix_path)
    sys.stdout.write(
        "Yerel paket: ad=%s surum=%s yayinci=%s\n"
        % (package["Name"], package["Version"], package["Publisher"])
    )

    app = call(session, "GET", app_url(app_id))
    assert_identity_matches(package, app)

    pending = app.get("pendingApplicationSubmission")
    if pending:
        if not allow_delete_pending:
            raise SystemExit(
                "Bu uygulamanin BEKLEYEN gonderimi var (id=%s). Ustune yazmiyorum:\n"
                "Partner Center'da yarim kalmis bir is olabilir. Once orada bitir ya\n"
                "da --allow-delete-pending ile bilerek sil." % pending["id"]
            )
        sys.stdout.write("bekleyen gonderim siliniyor: %s\n" % pending["id"])
        call(
            session,
            "DELETE",
            "%s/submissions/%s" % (app_url(app_id), pending["id"]),
        )

    if not app.get("lastPublishedApplicationSubmission"):
        raise SystemExit(
            "Yayinlanmis gonderim yok. Bu API ILK gonderimi yapamaz; sahip Partner\n"
            "Center'da bir kez elle gonderim yapmali (yas derecelendirmesi dahil)."
        )

    submission = call(session, "POST", "%s/submissions" % app_url(app_id))
    submission_id = submission["id"]
    sys.stdout.write("gonderim olusturuldu: %s\n" % submission_id)

    existing = submission.get("applicationPackages", []) or []
    assert_version_is_newer(package["Version"], existing)

    body = {k: v for k, v in submission.items() if k not in RESPONSE_ONLY}
    body["applicationPackages"] = plan_packages(existing, os.path.basename(msix_path))
    touched = apply_release_notes(body.get("listings", {}), notes)
    sys.stdout.write("not yazilan diller: %s\n" % ", ".join(touched))

    call(
        session,
        "PUT",
        "%s/submissions/%s" % (app_url(app_id), submission_id),
        data=json.dumps(body).encode("utf-8"),
    )
    sys.stdout.write("gonderim govdesi guncellendi\n")

    import tempfile

    work_dir = tempfile.mkdtemp(prefix="msstore-")
    zip_path, _ = zip_package(msix_path, work_dir)
    put_blob(submission["fileUploadUrl"], zip_path)

    call(
        session,
        "POST",
        "%s/submissions/%s/commit" % (app_url(app_id), submission_id),
    )
    sys.stdout.write("commit gonderildi; durum bekleniyor...\n")

    deadline = time.time() + poll_seconds
    status = "CommitStarted"
    detail = {}
    while time.time() < deadline:
        state = call(
            session,
            "GET",
            "%s/submissions/%s/status" % (app_url(app_id), submission_id),
        )
        status = state.get("status", "")
        detail = state.get("statusDetails", {}) or {}
        sys.stdout.write("  durum: %s\n" % status)
        if status != "CommitStarted":
            break
        time.sleep(20)

    for kind in ("errors", "warnings"):
        for item in detail.get(kind, []) or []:
            sys.stdout.write(
                "  %s: %s %s\n" % (kind, item.get("code"), item.get("details"))
            )

    if status in FAILED_STATUS:
        raise SystemExit("Gonderim BASARISIZ: %s" % status)
    if status == "CommitStarted":
        raise SystemExit(
            "Commit %d saniyede sonuclanmadi; Partner Center'dan izle (gonderim %s)."
            % (poll_seconds, submission_id)
        )
    sys.stdout.write(
        "GONDERILDI. Sertifikasyon birkac saat-birkac gun surer; sonucu Partner\n"
        "Center gosterir (gonderim %s).\n" % submission_id
    )
    return 0


# --------------------------------------------------------------- self-test
def _fake_msix(path, name, publisher, version):
    manifest = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10">'
        '<Identity Name="%s" Publisher="%s" Version="%s" ProcessorArchitecture="x64" />'
        "</Package>"
    ) % (name, publisher, version)
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("AppxManifest.xml", manifest)
    return path


def self_test():
    """API'siz kosar. Hattan ONCE kosar. Kimlik bilgisi gerektirmez."""
    import tempfile

    failures = []

    def check(name, condition):
        if not condition:
            failures.append(name)

    def raises(name, fn, exc=ValueError):
        try:
            fn()
        except exc:
            check(name, True)
            return
        except Exception as error:  # yanlis tipte hata da kusurdur
            failures.append("%s (beklenmeyen hata: %r)" % (name, error))
            return
        failures.append(name)

    work = tempfile.mkdtemp(prefix="msstore-selftest-")

    # --- MSIX kimligi paketin ICINDEN okunuyor
    msix = _fake_msix(
        os.path.join(work, "odak.msix"),
        "MuhlisAnlZKAN.FocusCamp",
        "CN=AA270E61-F2DB-45C7-92C0-02B413FF6EF6",
        "1.0.66.0",
    )
    identity = read_msix_identity(msix)
    check("kimlik pakettten okunuyor", identity["Name"] == "MuhlisAnlZKAN.FocusCamp")
    check("surum pakettten okunuyor", identity["Version"] == "1.0.66.0")

    empty = os.path.join(work, "bos.msix")
    with zipfile.ZipFile(empty, "w") as archive:
        archive.writestr("baska.xml", "<x/>")
    raises("manifestsiz paket reddediliyor", lambda: read_msix_identity(empty))

    # --- surum semasi
    check("dort alanli surum ayristiriliyor", parse_version("1.0.66.0") == (1, 0, 66, 0))
    raises("uc alanli surum reddediliyor", lambda: parse_version("1.0.66"))
    raises("sayisal olmayan surum reddediliyor", lambda: parse_version("1.0.x.0"))

    # --- build numarasi paketten turetiliyor
    check("stable paketten build turetiliyor", derive_build_number("1.0.66.0") == 66)
    raises("BETA paketi Store'a gonderilmiyor", lambda: derive_build_number("1.0.66.3"))
    raises("beklenmeyen onek reddediliyor", lambda: derive_build_number("2.0.1.0"))
    raises("sifir patch reddediliyor", lambda: derive_build_number("1.0.0.0"))

    app = {
        "packageIdentityName": "MuhlisAnlZKAN.FocusCamp",
        "publisherName": "CN=AA270E61-F2DB-45C7-92C0-02B413FF6EF6",
    }
    assert_identity_matches(identity, app)
    check("dogru kimlik geciyor", True)
    raises(
        "yanlis kimlik adi reddediliyor",
        lambda: assert_identity_matches(
            dict(identity, Name="Baska.Ad"), app
        ),
    )
    raises(
        "yanlis yayinci reddediliyor",
        lambda: assert_identity_matches(dict(identity, Publisher="CN=Baskasi"), app),
    )
    raises(
        "magazadan bos kimlik gelirse durur",
        lambda: assert_identity_matches(identity, {"packageIdentityName": "", "publisherName": ""}),
    )

    # --- surum ilerlemesi
    published = [{"fileName": "eski.msix", "version": "1.0.65.0"}]
    assert_version_is_newer("1.0.66.0", published)
    check("ileri surum geciyor", True)
    raises("ayni surum reddediliyor", lambda: assert_version_is_newer("1.0.65.0", published))
    raises("geri surum reddediliyor", lambda: assert_version_is_newer("1.0.64.0", published))

    # --- paket plani
    planned = plan_packages(published, "yeni.msix")
    check("eski paket silinmek uzere isaretleniyor", planned[0]["fileStatus"] == "PendingDelete")
    check("yeni paket yuklenmek uzere isaretleniyor", planned[-1]["fileStatus"] == "PendingUpload")
    check("yeni paket adi tasiniyor", planned[-1]["fileName"] == "yeni.msix")
    check(
        "zorunlu alanlar var",
        planned[-1]["minimumDirectXVersion"] == "None"
        and planned[-1]["minimumSystemRam"] == "None",
    )
    check("eski paket kaydi korunuyor", len(planned) == 2)
    raises(
        "ayni dosya adi reddediliyor",
        lambda: plan_packages(published, "eski.msix"),
    )

    # --- notlar
    long_item = "x" * 1400
    release = {
        "highlights": [long_item, long_item],
        "fixes": ["kisa bir duzeltme"],
        "highlightsEn": ["only one"],
        "fixesEn": [],
    }
    tr = build_note(release, "tr")
    check("1500 siniri asilmiyor", len(tr) <= MAX_NOTE)
    check("sigmayan madde ATILIYOR", tr.count("•") == 1)
    huge = build_note({"highlights": ["y" * 2000]}, "tr")
    check("tek dev madde kirpiliyor", 0 < len(huge) <= MAX_NOTE)
    check("kirpma isaretleniyor", huge.endswith("…"))
    raises("bos girdi hata veriyor", lambda: build_note({"highlights": [], "fixes": []}, "tr"))

    notes = {"tr": "• Turkce", "en": "• English"}
    listings = {
        "tr-tr": {"baseListing": {"releaseNotes": "eski"}},
        "en-us": {"baseListing": {"releaseNotes": "old"}},
    }
    touched = apply_release_notes(listings, notes)
    check("iki dil de yazildi", sorted(touched) == ["en-us", "tr-tr"])
    check("tr notu Turkce", listings["tr-tr"]["baseListing"]["releaseNotes"] == "• Turkce")
    check("en notu Ingilizce", listings["en-us"]["baseListing"]["releaseNotes"] == "• English")
    raises("listelemesiz gonderim reddediliyor", lambda: apply_release_notes({}, notes))
    raises(
        "baseListing yoksa durur",
        lambda: apply_release_notes({"tr-tr": {}}, notes),
    )
    raises(
        "sinir asan not reddediliyor",
        lambda: apply_release_notes(
            {"tr-tr": {"baseListing": {}}}, {"tr": "z" * (MAX_NOTE + 1), "en": "x"}
        ),
    )

    # --- kimlik bilgisi FAIL-CLOSED (yarim yapilandirma dahil)
    saved = {name: os.environ.get(name) for name in CREDENTIAL_VARS}
    try:
        for name in CREDENTIAL_VARS:
            os.environ.pop(name, None)
        raises("kimlik yoksa durur", credentials, SystemExit)
        os.environ["MS_STORE_TENANT_ID"] = "t"
        os.environ["MS_STORE_CLIENT_ID"] = "c"
        raises("YARIM yapilandirma da durduruyor", credentials, SystemExit)
        os.environ["MS_STORE_CLIENT_SECRET"] = "   "
        raises("bosluk dolu secret sayilmaz", credentials, SystemExit)
        os.environ["MS_STORE_CLIENT_SECRET"] = "s"
        check("uc deger dolunca geciyor", credentials()["MS_STORE_CLIENT_ID"] == "c")
    finally:
        for name, value in saved.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value

    # --- yanit-only alanlar PUT govdesine sizmiyor
    sample = {
        "id": "1",
        "status": "PendingCommit",
        "statusDetails": {},
        "fileUploadUrl": "https://example.invalid/sas",
        "listings": {},
        "visibility": "Public",
    }
    body = {k: v for k, v in sample.items() if k not in RESPONSE_ONLY}
    check("yanit-only alanlar cikariliyor", set(body) == {"listings", "visibility"})

    # --- gercek dosya: her iki dil de uretiliyor ve sinira uyuyor
    here = os.path.dirname(os.path.abspath(__file__))
    notes_path = os.path.join(here, "..", "..", "app", "assets", "release_notes.json")
    raw = io.open(notes_path, "rb").read()
    doc = json.loads(raw.decode("utf-8-sig"))
    for release in doc["releases"][:5]:
        for lang, key in (("tr", "highlights"), ("en", "highlightsEn")):
            if not release.get(key):
                continue
            note = build_note(release, lang)
            check(
                "build %s/%s sinira uyuyor" % (release["buildNumber"], lang),
                0 < len(note) <= MAX_NOTE,
            )

    if failures:
        sys.stdout.write("SELF-TEST KIRMIZI:\n")
        for name in failures:
            sys.stdout.write("  - %s\n" % name)
        return 1
    sys.stdout.write("self-test: gecti\n")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["self-test", "inspect", "verify", "upload"])
    parser.add_argument("--msix")
    parser.add_argument("--app-id", default=STORE_ID)
    parser.add_argument("--build-number", type=int)
    parser.add_argument("--notes", default="app/assets/release_notes.json")
    parser.add_argument("--allow-delete-pending", action="store_true")
    parser.add_argument("--poll-seconds", type=int, default=900)
    args = parser.parse_args()

    if args.mode == "self-test":
        return self_test()

    if args.mode == "inspect":
        # Kimlik bilgisi GEREKTIRMEZ: yerel paketin ne tasidigini gosterir.
        if not args.msix:
            raise SystemExit("inspect icin --msix zorunlu")
        identity = read_msix_identity(args.msix)
        for key in ("Name", "Publisher", "Version"):
            sys.stdout.write("%-12s %s\n" % (key, identity[key]))
        sys.stdout.write("BuildNumber  %s\n" % derive_build_number(identity["Version"]))
        return 0

    session = make_session(access_token(credentials()))

    if args.mode == "verify":
        return verify(session, args.app_id, args.msix)

    if not args.msix:
        raise SystemExit("upload icin --msix zorunlu")
    # Build numarasi PAKETTEN turetilir. Elle girilen bir sayi, v65'te
    # yasandigi gibi yanlis surumun notlarini yayinlamanin yoludur.
    derived = derive_build_number(read_msix_identity(args.msix)["Version"])
    if args.build_number and args.build_number != derived:
        raise SystemExit(
            "Verilen build numarasi paketle uyusmuyor: %s vs %s"
            % (args.build_number, derived)
        )
    sys.stdout.write("build numarasi (paketten turetildi): %s\n" % derived)
    notes = load_notes(args.notes, derived)
    for lang, text in sorted(notes.items()):
        sys.stdout.write("not[%s] %s karakter\n" % (lang, len(text)))
    return upload(
        session,
        args.app_id,
        args.msix,
        notes,
        args.allow_delete_pending,
        args.poll_seconds,
    )


if __name__ == "__main__":
    sys.exit(main())
