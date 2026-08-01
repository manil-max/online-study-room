#!/usr/bin/env python3
"""İstemci ↔ sunucu sözleşme kapısı: Dart/Edge çağrıları ile SQL şeması.

Usage (repo root):
  python scripts/backend_contract_audit.py
  python scripts/backend_contract_audit.py --self-test

🔴 Bu kapının varlık sebebi somut ve tekrar eden bir arıza sınıfıdır:

  * WP-373 — cihaz senkronu WP-341'den beri ölüydü. Dart ucu bir sinyal
    yolluyordu, sunucu ucu onu hiç üretmiyordu. Hiçbir test görmedi.
  * WP-449/450 — istemci `p_interval_days` gönderdi, sunucuda o parametre
    yoktu. Sahadaki her görev yazımı `PGRST202` alırdı.
  * WP-472 bunu `upsert_user_task` için iki uçlu testle kapattı — ama
    **yalnız o bir fonksiyon için**. Aynı boşluk 74 çağrı daha için açıktı.
  * Bu kapı kurulurken bulunan üçüncü örnek: `get_user_study_summary`
    hiçbir migration'da tanımlı değil, WP-152'den beri "Verilerimi dışa
    aktar" çıktısındaki `summary` alanı **her zaman null**.

Sebep sınıfı hep aynı: Dart testlerinin tamamı `InMemory*Repository`
kullanır, `Supabase*Repository` sınıflarının **hiçbiri** hiçbir testte
örneklenmez. pgTAP sunucu ucunu tek başına doğrular. Yani iki uç da yeşil
görünürken **aradaki tel kopuk** olabilir; kopukluk yalnız gerçek cihazda,
yayından sonra görünür.

Denetlenen üç yüzey:

1. **RPC adı** — Dart/Edge `.rpc('ad')` çağrısının migration zincirinde bir
   karşılığı var mı.
2. **RPC parametreleri** — gönderilen anahtar kümesini kabul eden **bir**
   overload var mı ve o overload'ın zorunlu (default'suz) parametreleri
   karşılanıyor mu.
3. **Tablo sütunu** — `.from('t').select('a, b')` içindeki her sütun `t`'de
   gerçekten var mı.

Bilinçli sınırlar (yanlış pozitif denetimi kullanılamaz kılar):
  * `params:` bir değişkense veya `...spread`/koşullu anahtar içeriyorsa
    çağrı **atlanır** — statik olarak kanıtlanamaz.
  * `.select()` (argümansız) her şeyi seçer, atlanır.
  * View'lar ve parse edilemeyen tablolar sütun denetimine girmez.

`--self-test`: kapının **gerçekten kırmızıya döndüğünü** kanıtlar. Yeşil bir
denetim, denetimin çalıştığını kanıtlamaz (bkz. l10n Gate probe adımı ve
`ci-kapisi-yesil-sanilmaz-dogrulanir` dersi).
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
DART_ROOT = ROOT / "app" / "lib"
EDGE_ROOT = ROOT / "supabase" / "functions"

# `auth.users` gibi şema dışı tablolar ve PostgREST'in kendi yüzeyleri.
UNPARSED_TABLE_EXEMPTIONS = {
    # Migration'da `create table` ile değil, Supabase platformu tarafından
    # sağlanan tablolar. Sütunlarını repo bilmez, denetleyemez.
    "users",
    "objects",
    "buckets",
}


# --------------------------------------------------------------------------
# Ortak yardımcılar
# --------------------------------------------------------------------------
def balance(text: str, start: int, opener: str = "(", closer: str = ")") -> int:
    """`start` açılış karakterinden SONRAKİ indeks; eşleşen kapanışı döner.

    Dize içindeki parantezler sayılmaz; aksi hâlde bir sonraki çağrının
    argümanları bu çağrıya sızar ve uydurma bulgu üretir.
    """
    depth, index, quote = 1, start, None
    while index < len(text) and depth > 0:
        char = text[index]
        if quote:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = None
        elif char in ("'", '"'):
            quote = char
        elif char == opener:
            depth += 1
        elif char == closer:
            depth -= 1
        index += 1
    return index - 1


def split_top_level(body: str) -> list[str]:
    """Yalnız en dış seviyedeki virgüllerden böler."""
    parts, depth, current = [], 0, ""
    for char in body:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        if char == "," and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += char
    if current.strip():
        parts.append(current)
    return parts


# --------------------------------------------------------------------------
# SQL ucu
# --------------------------------------------------------------------------
_CONSTRAINT = re.compile(
    r"^\s*(primary\s+key|foreign\s+key|unique|check|constraint|exclude|like)\b",
    re.I,
)


def _sql_text() -> str:
    files = sorted(MIGRATIONS.glob("*.sql"))
    if not files:
        raise SystemExit(f"migration dizini boş veya yok: {MIGRATIONS}")
    return "\n".join(
        path.read_text(encoding="utf-8", errors="replace").replace("\r\n", "\n")
        for path in files
    )


def _parse_signature(body: str) -> list[tuple[str, bool]]:
    """(parametre adı, default'u var mı) listesi."""
    result = []
    for part in split_top_level(body):
        part = part.strip()
        if not part:
            continue
        mode = re.match(r"(?:in|out|inout|variadic)\s+", part, re.I)
        if mode:
            part = part[mode.end():]
        name = re.match(r"([a-zA-Z_][a-zA-Z0-9_]*)", part)
        if not name:
            continue
        optional = bool(re.search(r"\bdefault\b|:=", part, re.I))
        result.append((name.group(1), optional))
    return result


def sql_schema(sql: str):
    """(fonksiyon overload'ları, tablo sütunları, view adları)."""
    functions: dict[str, list[list[tuple[str, bool]]]] = defaultdict(list)
    for match in re.finditer(
        r"create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?([a-z0-9_]+)\s*\(",
        sql,
        re.I,
    ):
        signature = _parse_signature(sql[match.end(): balance(sql, match.end())])
        shape = tuple(name for name, _ in signature)
        known = {tuple(n for n, _ in s) for s in functions[match.group(1)]}
        if shape not in known:
            functions[match.group(1)].append(signature)

    tables: dict[str, set[str]] = defaultdict(set)
    for match in re.finditer(
        r"create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-z0-9_]+)\s*\(",
        sql,
        re.I,
    ):
        body = sql[match.end(): balance(sql, match.end())]
        for part in split_top_level(body):
            if _CONSTRAINT.match(part):
                continue
            column = re.match(r'\s*"?([a-z_][a-z0-9_]*)"?\s', part)
            if column:
                tables[match.group(1)].add(column.group(1))

    # Tek ALTER birden çok virgüllü ADD COLUMN taşıyabilir; yalnız ilkini
    # almak "eksik sütun" uydurur (crown_rank bu yüzden yanlış raporlanmıştı).
    for match in re.finditer(
        r"alter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?(?:public\.)?([a-z0-9_]+)\b",
        sql,
        re.I,
    ):
        statement = sql[match.end():]
        end = statement.find(";")
        if end != -1:
            statement = statement[:end]
        table = tables[match.group(1)]
        for add in re.finditer(
            r"add\s+column\s+(?:if\s+not\s+exists\s+)?\"?([a-z_][a-z0-9_]*)\"?",
            statement,
            re.I,
        ):
            table.add(add.group(1))
        for drop in re.finditer(
            r"drop\s+column\s+(?:if\s+exists\s+)?\"?([a-z_][a-z0-9_]*)\"?",
            statement,
            re.I,
        ):
            table.discard(drop.group(1))
        for rename in re.finditer(
            r"rename\s+column\s+\"?([a-z_][a-z0-9_]*)\"?\s+to\s+\"?([a-z_][a-z0-9_]*)\"?",
            statement,
            re.I,
        ):
            table.discard(rename.group(1))
            table.add(rename.group(2))

    views = {
        m.group(1)
        for m in re.finditer(
            r"create\s+(?:or\s+replace\s+)?(?:materialized\s+)?view\s+"
            r"(?:if\s+not\s+exists\s+)?(?:public\.)?([a-z0-9_]+)",
            sql,
            re.I,
        )
    }
    return functions, tables, views


# --------------------------------------------------------------------------
# İstemci ucu (Dart + Edge TypeScript)
# --------------------------------------------------------------------------
_RPC_CALL = re.compile(r"\.rpc(?:<[^>]*>)?\(")
_FROM_CALL = re.compile(r"\.from\(\s*['\"]([a-z0-9_]+)['\"]\s*\)")


def _client_sources():
    for path in sorted(DART_ROOT.rglob("*.dart")):
        yield path
    if EDGE_ROOT.is_dir():
        for path in sorted(EDGE_ROOT.rglob("*.ts")):
            yield path


def rpc_calls(path: Path, text: str):
    """(satır, ad, gönderilen anahtarlar, params var mı, statik mi)."""
    for match in _RPC_CALL.finditer(text):
        args = text[match.end(): balance(text, match.end())]
        name = re.match(r"\s*['\"]([a-z0-9_]+)['\"]", args)
        if not name:
            continue
        line = text[: match.start()].count("\n") + 1

        keys: list[str] = []
        has_params = False
        static = True
        # Dart: params: {...}   Edge/TS: ikinci konumsal argüman {...}
        block = re.search(r"params\s*:\s*(?:<[^>]*>)?\s*\{", args)
        if block is None and path.suffix == ".ts":
            block = re.search(r",\s*\{", args)
        if block:
            has_params = True
            inner = args[block.end(): balance(args, block.end(), "{", "}")]
            # Yalnız EN ÜST SEVİYE anahtarlar. `x ? 'overturned' : 'upheld'`
            # gibi bir üçlü ifadenin değeri de `'ad':` desenine uyar ama
            # anahtar değildir.
            for entry in split_top_level(inner):
                key = re.match(r"\s*['\"]?([a-z_][a-z0-9_]*)['\"]?\s*:", entry)
                if key:
                    keys.append(key.group(1))
            if "..." in inner or re.search(r"\bif\s*\(", inner):
                static = False
        elif re.search(r"params\s*:", args):
            has_params, static = True, False
        yield line, name.group(1), keys, has_params, static


def select_columns(text: str):
    """(satır, tablo, sütunlar) — yalnız zincirde HEMEN gelen `.select('…')`."""
    for match in _FROM_CALL.finditer(text):
        nxt = re.match(r"\s*\.select\(\s*['\"]([^'\"]*)['\"]\s*\)", text[match.end():])
        if not nxt:
            continue
        line = text[: match.start()].count("\n") + 1
        raw = nxt.group(1)
        # Gömülü ilişkiler: `author:profiles(name)` / `profiles!fk(...)`
        raw = re.sub(r"[a-z0-9_!:]+\s*\([^)]*\)", "", raw, flags=re.I)
        columns = []
        for piece in raw.split(","):
            column = piece.strip()
            if not column or column == "*":
                continue
            column = column.split(":")[-1].strip()
            column = re.sub(r"::.*$", "", column).strip()
            if re.fullmatch(r"[a-z_][a-z0-9_]*", column):
                columns.append(column)
        yield line, match.group(1), columns


# --------------------------------------------------------------------------
# Denetim
# --------------------------------------------------------------------------
def audit() -> tuple[list[str], str]:
    functions, tables, views = sql_schema(_sql_text())
    errors: list[str] = []
    rpc_count = column_count = 0

    for path in _client_sources():
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = path.relative_to(ROOT).as_posix()

        for line, name, keys, has_params, static in rpc_calls(path, text):
            rpc_count += 1
            if name not in functions:
                errors.append(
                    f"{rel}:{line}: `{name}` RPC'si hiçbir migration'da "
                    f"tanımlı değil (çağrı sahada PGRST202 alır)"
                )
                continue
            if not (has_params and static):
                continue
            sent = set(keys)
            for signature in functions[name]:
                names = {n for n, _ in signature}
                required = {n for n, optional in signature if not optional}
                if sent <= names and required <= sent:
                    break
            else:
                shapes = " | ".join(
                    "(" + ", ".join(n for n, _ in s) + ")" for s in functions[name]
                )
                errors.append(
                    f"{rel}:{line}: `{name}` çağrısının anahtarları "
                    f"({', '.join(sorted(sent)) or '-'}) hiçbir overload'a "
                    f"uymuyor; sunucu imzaları: {shapes}"
                )

        for line, table, columns in select_columns(text):
            if table in views or table in UNPARSED_TABLE_EXEMPTIONS:
                continue
            if table not in tables:
                continue
            for column in columns:
                column_count += 1
                if column not in tables[table]:
                    errors.append(
                        f"{rel}:{line}: `{table}` tablosunda `{column}` sütunu "
                        f"yok (mevcut: {', '.join(sorted(tables[table]))})"
                    )

    summary = (
        f"{rpc_count} RPC çağrısı / "
        f"{sum(len(v) for v in functions.values())} sunucu imzası, "
        f"{column_count} sütun referansı / {len(tables)} tablo"
    )
    return errors, summary


SELF_TEST_PROBE = ROOT / "app" / "lib" / "data" / "_contract_gate_probe.dart"
SELF_TEST_SOURCE = """// GEÇİCİ KAPI PROBU — backend_contract_audit.py --self-test tarafından
// yazılır ve hemen silinir. Repoda kalıcı olarak bulunmamalıdır.
class ContractGateProbe {
  ContractGateProbe(this._client);
  final dynamic _client;

  Future<void> unknownRpc() async =>
      await _client.rpc('bu_rpc_hicbir_migrationda_yok', params: {'p_x': 1});

  Future<void> unknownColumn() async =>
      await _client.from('profiles').select('id, boyle_bir_sutun_yok');
}
"""


def self_test() -> int:
    """Kapının kırmızıya döndüğünü kanıtlar."""
    baseline, _ = audit()
    SELF_TEST_PROBE.write_text(SELF_TEST_SOURCE, encoding="utf-8")
    try:
        probed, _ = audit()
    finally:
        SELF_TEST_PROBE.unlink(missing_ok=True)

    new = [e for e in probed if e not in baseline]
    expected = ("bu_rpc_hicbir_migrationda_yok", "boyle_bir_sutun_yok")
    caught = {token: any(token in e for e in new) for token in expected}

    print("self-test — kapı probu:")
    for token, hit in caught.items():
        print(f"  {'yakalandı' if hit else 'KAÇIRILDI'}: {token}")
    if not all(caught.values()):
        print("FAIL: kapı sessizce etkisiz — proba kırmızı dönmedi.")
        return 1
    print(f"OK: kapı iki probu da reddetti ({len(new)} yeni bulgu).")
    return 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()

    errors, summary = audit()
    if errors:
        print(f"FAIL ({len(errors)}):")
        for error in errors:
            print(f"  - {error}")
        print(f"\ntaranan: {summary}")
        return 1
    print(f"OK: istemci ↔ sunucu sözleşmesi tutarlı — {summary}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
