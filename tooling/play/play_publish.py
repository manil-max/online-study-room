# -*- coding: utf-8 -*-
"""Play Developer API ile AAB yukler ve "Yenilikler" metnini yazar.

NEDEN AYRI BIR BETIK: yukleme adiminin iki parcasi var -- API cagrilari ve
kullaniciya gorunen metnin uretilmesi. Ikincisi bir is akisi YAML'ina gomulurse
hicbir yerde sinanamaz. Burada duruyor, `--self-test` ile kendini sinar ve
hattan once kosar.

TEK KAYNAK: magaza notlari `app/assets/release_notes.json`den TURETILIR.
Elle ikinci bir metin tutmak, v59'da yasandigi gibi surumle notun ayrisma
yoludur. Play alan basina 500 karakter siniri koyar; kirpma madde sinirinda
yapilir, cumle ortasindan degil.
"""
import argparse
import io
import json
import os
import sys
import time

PACKAGE_NAME = "com.manilmax.online_study_room"
BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"

# Play "Yenilikler" alani. Asilirsa API 400 doner ve is yukleme SONRASI duser.
MAX_NOTE = 500


def build_note(release, lang):
    """Bir surum kaydindan tek dilde magaza notu uretir.

    `lang` 'tr' ya da 'en'. Baslik ATILIR: Play zaten surum adini kendi
    gosterir, basligi tekrarlamak 500 karakterin buyuk kismini yer.
    """
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
        # +1: maddeler arasi satir sonu (ilk madde haric).
        cost = len(line) + (1 if out else 0)
        if used + cost > MAX_NOTE:
            break
        out.append(line)
        used += cost

    if not out:
        # Tek madde bile sigmiyorsa kirpmak zorundayiz; sonu acikca isaretle.
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
    return [
        {"language": "tr-TR", "text": build_note(release, "tr")},
        {"language": "en-US", "text": build_note(release, "en")},
    ]


# --------------------------------------------------------------------- API
def credentials():
    from google.oauth2 import service_account
    import google.auth.transport.requests

    raw = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON", "")
    if not raw.strip():
        raise SystemExit("PLAY_SERVICE_ACCOUNT_JSON bos; yukleme yapilmaz.")
    info = json.loads(raw)
    creds = service_account.Credentials.from_service_account_info(
        info, scopes=[SCOPE]
    )
    creds.refresh(google.auth.transport.requests.Request())
    return creds


def call(session, method, url, **kwargs):
    response = session.request(method, url, timeout=600, **kwargs)
    if response.status_code >= 400:
        raise SystemExit(
            "Play API %s %s -> %s\n%s"
            % (method, url.split("?")[0], response.status_code, response.text[:2000])
        )
    return response.json() if response.content else {}


def make_session(creds):
    import requests

    session = requests.Session()
    session.headers["Authorization"] = "Bearer %s" % creds.token
    return session


def verify(session):
    """Yetkiyi ve iz adlarini OLCER. Iz adi tahmin edilmez, listelenir."""
    edit = call(session, "POST", "%s/%s/edits" % (BASE, PACKAGE_NAME))
    edit_id = edit["id"]
    try:
        tracks = call(
            session, "GET", "%s/%s/edits/%s/tracks" % (BASE, PACKAGE_NAME, edit_id)
        )
        sys.stdout.write("Yetki TAMAM. Izler:\n")
        for track in tracks.get("tracks", []):
            codes = []
            for release in track.get("releases", []):
                codes.extend(release.get("versionCodes", []) or [])
            sys.stdout.write(
                "  - %-16s surum kodlari: %s\n"
                % (track.get("track"), ", ".join(str(c) for c in codes) or "(bos)")
            )
    finally:
        session.delete(
            "%s/%s/edits/%s" % (BASE, PACKAGE_NAME, edit_id), timeout=120
        )


def upload(session, aab_path, track, notes, status):
    size = os.path.getsize(aab_path)
    sys.stdout.write("AAB: %s (%.1f MB)\n" % (aab_path, size / 1048576.0))

    edit = call(session, "POST", "%s/%s/edits" % (BASE, PACKAGE_NAME))
    edit_id = edit["id"]
    sys.stdout.write("edit=%s\n" % edit_id)

    with io.open(aab_path, "rb") as handle:
        bundle = call(
            session,
            "POST",
            "%s/%s/edits/%s/bundles?uploadType=media" % (UPLOAD, PACKAGE_NAME, edit_id),
            data=handle,
            headers={"Content-Type": "application/octet-stream"},
        )
    version_code = int(bundle["versionCode"])
    sys.stdout.write("yuklendi, surum kodu=%s\n" % version_code)

    call(
        session,
        "PUT",
        "%s/%s/edits/%s/tracks/%s" % (BASE, PACKAGE_NAME, edit_id, track),
        json={
            "track": track,
            "releases": [
                {
                    "versionCodes": [str(version_code)],
                    "status": status,
                    "releaseNotes": notes,
                }
            ],
        },
    )
    sys.stdout.write("iz guncellendi: %s (%s)\n" % (track, status))

    call(session, "POST", "%s/%s/edits/%s:commit" % (BASE, PACKAGE_NAME, edit_id))
    sys.stdout.write("ISLENDI. Play Console'da gorunmesi birkac dakika surer.\n")
    return version_code


# --------------------------------------------------------------- self-test
def self_test():
    """Metin uretecinin kendi kapisi. API'siz kosar, hattan ONCE kosar."""
    failures = []

    def check(name, condition):
        if not condition:
            failures.append(name)

    long_item = "x" * 400
    release = {
        "highlights": [long_item, long_item],
        "fixes": ["kisa bir duzeltme"],
        "highlightsEn": ["only one"],
        "fixesEn": [],
    }
    tr = build_note(release, "tr")
    check("500 siniri asilmiyor", len(tr) <= MAX_NOTE)
    check("sigmayan madde ATILIYOR", tr.count("•") == 1)

    # Tek madde bile sigmiyorsa kirpilir ama BOS donmez.
    huge = build_note({"highlights": ["y" * 900]}, "tr")
    check("tek dev madde kirpiliyor", 0 < len(huge) <= MAX_NOTE)
    check("kirpma isaretleniyor", huge.endswith("…"))

    # Bos girdi sessizce bos not URETMEZ.
    try:
        build_note({"highlights": [], "fixes": []}, "tr")
        check("bos girdi hata veriyor", False)
    except ValueError:
        check("bos girdi hata veriyor", True)

    # Gercek dosya: her iki dil de uretiliyor ve sinira uyuyor.
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
    parser.add_argument("mode", choices=["self-test", "verify", "upload"])
    parser.add_argument("--aab")
    parser.add_argument("--track")
    parser.add_argument("--build-number", type=int)
    parser.add_argument("--notes", default="app/assets/release_notes.json")
    parser.add_argument("--status", default="completed")
    args = parser.parse_args()

    if args.mode == "self-test":
        return self_test()

    session = make_session(credentials())
    if args.mode == "verify":
        verify(session)
        return 0

    for name in ("aab", "track", "build_number"):
        if not getattr(args, name):
            raise SystemExit("upload icin --%s zorunlu" % name.replace("_", "-"))
    notes = load_notes(args.notes, args.build_number)
    for note in notes:
        sys.stdout.write(
            "not[%s] %s karakter\n" % (note["language"], len(note["text"]))
        )
    upload(session, args.aab, args.track, notes, args.status)
    return 0


if __name__ == "__main__":
    sys.exit(main())
