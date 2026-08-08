#!/usr/bin/env python3
"""WP-525: `docs/legal/*.md` -> yayinlanabilir statik HTML (GitHub Pages).

NEDEN VAR
=========
Play Console gizlilik politikasi icin **canli bir HTTPS adresi** ister; veri
silme beyani icin de ayri bir adres ister. Metinler repoda vardi ama hicbir
yerde yayinlanmiyordu ve `LEGAL_BASE_URL` hicbir ortam dosyasinda tanimli
degildi -- yani uygulamadaki "herkese acik gizlilik adresi" satiri da bos
gorunuyordu (`legal_documents.dart:15`).

SOZLESME (kapinin asil isi)
===========================
Uygulama adresi KOD ICINDE kuruyor: `legal_center_screen.dart` tam olarak
`legal/privacy-tr.html` ve `legal/privacy-en.html` yollarini istiyor. Site bu
dosyalari uretmezse kullanici 404 gorur ve bunu hicbir derleme hatasi
yakalamaz. `--check` bu yuzden dosya adlarini **koddan tarayarak** dogrular,
elle yazilmis bir listeden degil.

Disa bagimlilik yok: markdown -> HTML donusumu burada, yalniz `docs/legal`
icinde gercekten kullanilan alt kume icin yapilir (baslik, paragraf, kalin,
satir ici kod, madde listesi, tablo, satir sonu). Bilinmeyen bir yapi sessizce
yutulmaz; `--check` ham `|` veya `#` kalintisi birakan sayfada kirmizi duser.
"""

from __future__ import annotations

import argparse
import html
import re
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / "docs" / "legal"
APP_LIB = ROOT / "app" / "lib"

# Cikti adi -> (kaynak dosya, sayfa basligi, dil)
PAGES: dict[str, tuple[str, str, str]] = {
    "legal/privacy-tr.html": ("PRIVACY-POLICY.tr.md", "Gizlilik Politikası", "tr"),
    "legal/privacy-en.html": ("PRIVACY-POLICY.en.md", "Privacy Policy", "en"),
    "legal/terms-tr.html": ("TERMS-OF-USE.tr.md", "Kullanım Koşulları", "tr"),
    "legal/terms-en.html": ("TERMS-OF-USE.en.md", "Terms of Use", "en"),
    "legal/community-tr.html": ("COMMUNITY-GUIDELINES.tr.md", "Topluluk Kuralları", "tr"),
    "legal/community-en.html": ("COMMUNITY-GUIDELINES.en.md", "Community Guidelines", "en"),
    "legal/data-deletion-tr.html": ("ACCOUNT-DELETION.tr.md", "Hesap ve Veri Silme", "tr"),
    "legal/data-deletion-en.html": ("ACCOUNT-DELETION.en.md", "Account and Data Deletion", "en"),
    "legal/retention.html": ("DATA-RETENTION-SCHEDULE.md", "Veri Saklama Takvimi", "tr"),
}

# Play formunun istedigi iki adres. Bunlar uretilmezse Console kaydedilemez.
PLAY_REQUIRED = ("legal/privacy-tr.html", "legal/data-deletion-tr.html")

CSS = """
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body {
  margin: 0 auto; padding: 24px 20px 64px; max-width: 46rem;
  font: 16px/1.65 -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
  color: #17171b; background: #fbfbfd;
}
h1 { font-size: 1.6rem; line-height: 1.25; margin: 0 0 4px; }
h2 { font-size: 1.15rem; margin: 32px 0 8px; }
h3 { font-size: 1rem; margin: 24px 0 6px; }
p, li { margin: 8px 0; }
ul { padding-left: 22px; }
code {
  font: 0.9em/1.4 ui-monospace, "Cascadia Mono", Consolas, monospace;
  background: rgba(127,127,127,.16); padding: 1px 5px; border-radius: 4px;
}
.table-wrap { overflow-x: auto; margin: 12px 0; }
table { border-collapse: collapse; min-width: 100%; }
th, td { border: 1px solid rgba(127,127,127,.35); padding: 7px 10px; text-align: left; vertical-align: top; }
th { background: rgba(127,127,127,.12); font-weight: 600; }
nav.langs { margin: 0 0 24px; font-size: .95rem; }
nav.langs a { margin-right: 14px; }
a { color: #2f5fd0; }
footer { margin-top: 48px; padding-top: 16px; border-top: 1px solid rgba(127,127,127,.3); font-size: .85rem; opacity: .8; }
@media (prefers-color-scheme: dark) {
  body { color: #e9e9ee; background: #131318; }
  a { color: #8fb2ff; }
}
""".strip()


def _inline(text: str) -> str:
    """Satir ici bicimleme. HTML kacisi ONCE yapilir; sonra etiket uretilir."""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", r'<a href="\2">\1</a>', out)
    return out


def _table(rows: list[str]) -> str:
    cells = [[c.strip() for c in row.strip().strip("|").split("|")] for row in rows]
    head, body = cells[0], cells[2:]  # cells[1] ayirici satir
    parts = ['<div class="table-wrap"><table>', "<thead><tr>"]
    parts += [f"<th>{_inline(c)}</th>" for c in head]
    parts.append("</tr></thead><tbody>")
    for row in body:
        parts.append("<tr>" + "".join(f"<td>{_inline(c)}</td>" for c in row) + "</tr>")
    parts.append("</tbody></table></div>")
    return "".join(parts)


def markdown_to_html(source: str) -> str:
    lines = source.replace("\r\n", "\n").split("\n")
    out: list[str] = []
    # (metin, sert_satir_sonu). Markdown'da tek satir sonu YUMUSAK sarmadir;
    # sert satir sonu iki bosluklu satir sonudur. Bu ayrim kozmetik degil:
    # paragrafi satir satir isleseydik iki satira yayilan `**kalin**` metin
    # donusmez ve sayfada ham yildizlar kalirdi (ilk kosumda tam bu oldu).
    buffer: list[tuple[str, bool]] = []
    bullets: list[str] = []
    table: list[str] = []
    BR = "\x00BR\x00"

    def flush_paragraph() -> None:
        if buffer:
            joined = ""
            for index, (text, hard) in enumerate(buffer):
                if index:
                    joined += BR if buffer[index - 1][1] else " "
                joined += text
            out.append("<p>" + _inline(joined).replace(BR, "<br>") + "</p>")
            buffer.clear()

    def flush_bullets() -> None:
        if bullets:
            out.append("<ul>" + "".join(f"<li>{_inline(b)}</li>" for b in bullets) + "</ul>")
            bullets.clear()

    def flush_table() -> None:
        if table:
            out.append(_table(table))
            table.clear()

    def flush_all() -> None:
        flush_paragraph()
        flush_bullets()
        flush_table()

    for raw in lines:
        hard_break = raw.endswith("  ")
        line = raw.rstrip()
        stripped = line.strip()

        if stripped.startswith("|") and stripped.endswith("|"):
            flush_paragraph()
            flush_bullets()
            table.append(stripped)
            continue
        flush_table()

        if not stripped:
            flush_all()
            continue

        heading = re.match(r"^(#{1,3})\s+(.*)$", stripped)
        if heading:
            flush_all()
            level = len(heading.group(1))
            out.append(f"<h{level}>{_inline(heading.group(2))}</h{level}>")
            continue

        bullet = re.match(r"^[-*]\s+(.*)$", stripped)
        if bullet:
            flush_paragraph()
            bullets.append(bullet.group(1))
            continue
        flush_bullets()

        numbered = re.match(r"^\d+[.)]\s+(.*)$", stripped)
        if numbered:
            # Numarali madde metni numarasiyla birlikte korunur; docs/legal
            # icinde numaralar anlamlidir ("3) Saklama ve silme" gibi).
            buffer.append((stripped, True))
            continue

        buffer.append((stripped, hard_break))

    flush_all()
    return "\n".join(out)


def _page(title: str, lang: str, body: str, nav: str) -> str:
    return (
        "<!doctype html>\n"
        f'<html lang="{lang}"><head><meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{html.escape(title)} — Odak Kampı</title>\n"
        f"<style>{CSS}</style>\n"
        "</head><body>\n"
        f"{nav}\n{body}\n"
        "<footer>Odak Kampı · Focus Camp</footer>\n"
        "</body></html>\n"
    )


def _nav(current: str) -> str:
    links = [
        ("../index.html", "Ana sayfa / Home"),
        ("privacy-tr.html", "Gizlilik"),
        ("privacy-en.html", "Privacy"),
        ("terms-tr.html", "Koşullar"),
        ("terms-en.html", "Terms"),
        ("data-deletion-tr.html", "Veri silme"),
        ("data-deletion-en.html", "Data deletion"),
    ]
    parts = []
    for href, label in links:
        if href.endswith(current.split("/")[-1]):
            parts.append(f"<strong>{html.escape(label)}</strong>")
        else:
            parts.append(f'<a href="{href}">{html.escape(label)}</a>')
    return '<nav class="langs">' + " ".join(parts) + "</nav>"


def build(out_dir: Path) -> list[Path]:
    if out_dir.exists():
        shutil.rmtree(out_dir)
    (out_dir / "legal").mkdir(parents=True)

    written: list[Path] = []
    for target, (source_name, title, lang) in PAGES.items():
        source = LEGAL / source_name
        if not source.exists():
            raise SystemExit(f"Kaynak yasal metin yok: {source.relative_to(ROOT)}")
        body = markdown_to_html(source.read_text(encoding="utf-8"))
        path = out_dir / target
        path.write_text(_page(title, lang, body, _nav(target)), encoding="utf-8")
        written.append(path)

    index_body = ["<h1>Odak Kampı — Yasal / Legal</h1>"]
    index_body.append("<h2>Türkçe</h2><ul>")
    index_body.append('<li><a href="legal/privacy-tr.html">Gizlilik Politikası</a></li>')
    index_body.append('<li><a href="legal/terms-tr.html">Kullanım Koşulları</a></li>')
    index_body.append('<li><a href="legal/community-tr.html">Topluluk Kuralları</a></li>')
    index_body.append('<li><a href="legal/data-deletion-tr.html">Hesap ve Veri Silme</a></li>')
    index_body.append('<li><a href="legal/retention.html">Veri Saklama Takvimi</a></li>')
    index_body.append("</ul><h2>English</h2><ul>")
    index_body.append('<li><a href="legal/privacy-en.html">Privacy Policy</a></li>')
    index_body.append('<li><a href="legal/terms-en.html">Terms of Use</a></li>')
    index_body.append('<li><a href="legal/community-en.html">Community Guidelines</a></li>')
    index_body.append('<li><a href="legal/data-deletion-en.html">Account and Data Deletion</a></li>')
    index_body.append("</ul>")
    index = out_dir / "index.html"
    index.write_text(
        _page("Yasal / Legal", "tr", "\n".join(index_body), ""), encoding="utf-8"
    )
    written.append(index)

    # Jekyll'in `_` ile baslayan yollari yutmasini engeller; ayrica Pages
    # derlemesini hizlandirir.
    (out_dir / ".nojekyll").write_text("", encoding="utf-8")
    return written


def _paths_requested_by_app() -> set[str]:
    """Uygulamanin KOD ICINDE istedigi yasal sayfa yollari.

    Elle yazilmis liste kullanilmaz: kod degisip yeni bir sayfa istenirse
    kapi bunu kendiliginden gormeli.
    """
    found: set[str] = set()
    for dart in APP_LIB.rglob("*.dart"):
        text = dart.read_text(encoding="utf-8", errors="ignore")
        found.update(re.findall(r"'(legal/[A-Za-z0-9._-]+\.html)'", text))
        found.update(re.findall(r'"(legal/[A-Za-z0-9._-]+\.html)"', text))
    return found


def check() -> int:
    problems: list[str] = []
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "legal-site"
        build(out)

        for path in PLAY_REQUIRED:
            if not (out / path).exists():
                problems.append(f"Play formunun istedigi sayfa uretilmedi: {path}")

        requested = _paths_requested_by_app()
        if not requested:
            problems.append(
                "Uygulama kodunda hicbir 'legal/*.html' yolu bulunamadi -- "
                "tarama bozulmus olabilir, kapi bos yere yesil kalmasin."
            )
        for path in sorted(requested):
            if not (out / path).exists():
                problems.append(
                    f"Uygulama '{path}' istiyor ama site bu dosyayi uretmiyor (404 olurdu)."
                )

        for path in sorted(PAGES):
            text = (out / path).read_text(encoding="utf-8")
            body = text.split("</nav>", 1)[-1]
            if len(body) < 400:
                problems.append(f"{path} govdesi sasirtici derecede kisa ({len(body)} bayt).")
            for leftover in ("\n|", "\n#", "**"):
                if leftover in body:
                    problems.append(
                        f"{path} icinde islenmemis markdown kalintisi var: {leftover!r}"
                    )

    if problems:
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print(f"Yasal site sozlesmesi tamam: {len(PAGES) + 1} sayfa, "
          f"uygulamanin istedigi {len(_paths_requested_by_app())} yol karsilandi.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="build/legal-site", help="cikti dizini")
    parser.add_argument("--check", action="store_true",
                        help="uret ve sozlesmeyi dogrula (dosyaya yazmaz)")
    args = parser.parse_args()

    if args.check:
        return check()

    out = (ROOT / args.out) if not Path(args.out).is_absolute() else Path(args.out)
    written = build(out)
    print(f"{len(written)} sayfa yazildi -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
