"""GitHub Release govdesi: `app/assets/release_notes.json`dan TR + EN (WP-773).

Neden var: `softprops/action-gh-release` `generate_release_notes` ile yalniz
"**Full Changelog**: compare linki" uretiyordu. Uygulama icindeki guncelleme
penceresi GitHub govdesini oldugu gibi gosterir ve govde BOS olmadigi icin
bundled nota hic inmiyordu; kullanici surum notu yerine bir link goruyordu
(sahip, cihazda, v77). Govde artik uygulamanin kendi not kaynagindan turetilir:
ikinci bir metin tutmak v59'daki "surum ile not ayristi" hatasinin yoludur
(bkz. `play_publish.py`).

Kullanim:
    python release_body.py --self-test
    python release_body.py --notes app/assets/release_notes.json \
        --build-number 78 --tag v78 --out release-body.md

Build bulunamazsa (beta etiketleri `release_notes.json`a girmez) govde
uygulama ici notlara isaret eden kisa bir yedektir; is akisi DUSMEZ.
"""
import argparse
import io
import json
import os
import sys

LABELS = {
    "en": {"highlights": "Highlights", "fixes": "Fixes", "notes": "Notes"},
    "tr": {"highlights": "Öne çıkanlar", "fixes": "Düzeltmeler", "notes": "Notlar"},
}
IN_APP_HINT = (
    "Release notes are also shown inside the app: Settings → About → Update notes.\n"
    "Sürüm notları uygulama içinde de görünür: Ayarlar → Hakkında → Güncelleme notları.\n"
)


def _items(release, key, lang):
    if lang == "en":
        value = release.get(key + "En") or release.get(key) or []
    else:
        value = release.get(key) or []
    return [str(item).strip() for item in value if str(item).strip()]


def _title(release, lang):
    if lang == "en":
        return str(release.get("titleEn") or release.get("title") or "").strip()
    return str(release.get("title") or "").strip()


def section(release, lang):
    out = io.StringIO()
    title = _title(release, lang)
    if title:
        out.write("## %s\n\n" % title)
    for key in ("highlights", "fixes", "notes"):
        items = _items(release, key, lang)
        if not items:
            continue
        out.write("**%s**\n" % LABELS[lang][key])
        for item in items:
            out.write("- %s\n" % item)
        out.write("\n")
    return out.getvalue()


def build_body(release):
    """EN ustte (GitHub'in dili), TR altta. Bos girdi hata: sessiz bos govde
    tam olarak duzeltilen kusurdur."""
    en = section(release, "en")
    tr = section(release, "tr")
    if not en.strip() and not tr.strip():
        raise ValueError("release_notes.json girdisi bos: baslik ve madde yok")
    parts = [p for p in (en, tr) if p.strip()]
    return "\n---\n\n".join(parts) + "\n" + IN_APP_HINT


def fallback_body(tag):
    return (
        "## %s\n\n"
        "This build has no entry in release_notes.json (beta or hotfix tag).\n"
        "Bu derlemenin release_notes.json girdisi yok (beta ya da acil düzeltme etiketi).\n\n"
        % tag
    ) + IN_APP_HINT


def find_release(doc, build_number):
    for release in doc.get("releases", []):
        if int(release.get("buildNumber", -1)) == int(build_number):
            return release
    return None


def render(notes_path, build_number, tag):
    with open(notes_path, "r", encoding="utf-8-sig") as handle:
        doc = json.load(handle)
    release = find_release(doc, build_number)
    if release is None:
        return fallback_body(tag), False
    return build_body(release), True


def self_test():
    doc = {
        "releases": [
            {
                "buildNumber": 78,
                "title": "TR başlık",
                "highlights": ["TR madde bir", "TR madde iki"],
                "fixes": [],
                "notes": [],
                "titleEn": "EN title",
                "highlightsEn": ["EN item"],
                "fixesEn": ["EN fix"],
                "notesEn": [],
            },
            {"buildNumber": 79, "title": "", "highlights": [], "fixes": [], "notes": []},
        ]
    }
    body = build_body(find_release(doc, 78))
    checks = [
        ("EN ustte, TR altta", body.index("EN title") < body.index("TR başlık")),
        ("maddeler madde isaretiyle", "- EN item\n" in body and "- TR madde iki\n" in body),
        # EN alani bossa TR'ye duser (Dart `forLocale` ile ayni kural); iki
        # dilde de bos olan bolum hic yazilmaz.
        ("bos bolum yazilmaz", "**Notes**" not in body and "**Notlar**" not in body
         and "**Düzeltmeler**" not in body),
        ("EN bos alan TR'ye duser", "**Fixes**" in body and "- EN fix\n" in body),
        ("iki dil ayraci", "\n---\n" in body),
        ("uygulama ici ipucu", "Güncelleme notları" in body),
        ("bulunamayan build yedek govde", "release_notes.json" in fallback_body("beta-v4402")),
    ]
    try:
        build_body(find_release(doc, 79))
        checks.append(("bos girdi hata firlatir", False))
    except ValueError:
        checks.append(("bos girdi hata firlatir", True))
    failed = [name for name, ok in checks if not ok]
    if failed:
        sys.stderr.write("self-test KIRMIZI: %s\n" % ", ".join(failed))
        return 1
    sys.stdout.write("release_body self-test: %d/%d yesil\n" % (len(checks), len(checks)))
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--notes")
    parser.add_argument("--build-number", type=int)
    parser.add_argument("--tag", default="")
    parser.add_argument("--out")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not (args.notes and args.build_number and args.out):
        parser.error("--notes, --build-number ve --out zorunlu")
    body, found = render(args.notes, args.build_number, args.tag)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(body)
    sys.stdout.write(
        "govde yazildi: %s (%s, %d karakter)\n"
        % (args.out, "notlardan" if found else "YEDEK: build bulunamadi", len(body))
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
