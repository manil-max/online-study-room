#!/usr/bin/env python3
"""CI kapisi: cok satirli `script:` blogu olan action adimlarini yasaklar.

🔴 WP-572 — neden var (kok neden olculdu)

`reactivecircus/android-emulator-runner` adiminin `script:` alani TEK BIR kabuk
betigi olarak kosmaz; her SATIR ayri bir `/usr/bin/sh -c` cagrisiyla calisir.
Yani degisken atamalari, `set -u`/`set -e` ve fonksiyonlar SONRAKI SATIRA
GECMEZ. Kanit, kosum 31281652153 (job 93163879845):

    [command]/usr/bin/sh -c echo "GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-...}"
    GITHUB_WORKSPACE=/home/runner/work/online-study-room/online-study-room
    ...
    mkdir: cannot create directory '': No such file or directory

`GITHUB_WORKSPACE` tanimliydi; `LOG_DIR` atamasi baska bir kabukta kaldigi icin
bos genisledi. Sonucu: **Android sayac smoke testi CI'da hic kosmadi.** Kapi
vardi, olctugu sey yoktu -- v58'de acilista coken geri sayim/pomodoro hatasini
(Dart `setInt` -> native `getInt`) yakalamasi gereken tek is buydu.

Bu kapi ayni tuzagin geri dogmasini engeller: cok satirli `script:` yasak, tek
satir + repo icindeki bir `.sh` zorunlu, ve o `.sh` GERCEKTEN var olmali
("kural yaziliydi, cagiran yoktu" hatasi bu repoda defalarca uretime cikti).

Kullanim:  python scripts/ci/verify_ci_script_wiring.py
Cikis:     0 = gecti, 1 = kirmizi (sebep stdout'ta)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW_DIR = REPO_ROOT / ".github" / "workflows"

# `script:` alanini bloklu kabuk gibi DEGIL, satir satir kosturan action'lar.
# Yeni bir tanesi eklenirse buraya yazilir; liste niyet belgesidir.
LINE_BY_LINE_ACTIONS = ("reactivecircus/android-emulator-runner",)


def _iter_steps(text: str):
    """(action_adi, script_govdesi, satir_no) uretir — kaba ama yeterli tarama.

    YAML ayristirmiyoruz bilerek: repo'da PyYAML bagimliligi yok ve kapinin
    kendisi bir bagimlilik yuzunden atlanirsa yine kapisiz kalirdik.
    """
    lines = text.split("\n")
    current_action: str | None = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        m = re.match(r"^-?\s*uses:\s*(\S+)", stripped)
        if m:
            current_action = m.group(1)
            continue
        m = re.match(r"^script:\s*(.*)$", stripped)
        if m and current_action:
            body_indent = len(line) - len(line.lstrip())
            inline = m.group(1).strip()
            if inline in ("|", ">", "|-", ">-", "|+", ">+"):
                block: list[str] = []
                for follow in lines[i + 1 :]:
                    if follow.strip() == "":
                        block.append("")
                        continue
                    if len(follow) - len(follow.lstrip()) <= body_indent:
                        break
                    block.append(follow.strip())
                yield current_action, [b for b in block if b], i + 1
            else:
                yield current_action, [inline] if inline else [], i + 1
            current_action = None


def main() -> int:
    problems: list[str] = []
    checked = 0

    for wf in sorted(WORKFLOW_DIR.glob("*.yml")):
        text = wf.read_text(encoding="utf-8")
        for action, body, lineno in _iter_steps(text):
            if not any(action.startswith(a) for a in LINE_BY_LINE_ACTIONS):
                continue
            checked += 1
            rel = wf.relative_to(REPO_ROOT).as_posix()

            # Yorum satirlari da AYRI bir `sh -c` cagrisidir; zararsizdir ama
            # gercek komut sayisini gizlememeleri icin ayiklanir.
            commands = [b for b in body if not b.startswith("#")]
            if len(commands) != 1:
                problems.append(
                    f"{rel}:{lineno} — `{action}` adiminin `script:` blogu "
                    f"{len(commands)} komut satiri iceriyor. Bu action her satiri "
                    "AYRI bir `sh -c` ile kosar: degisken atamalari ve `set -u` "
                    "sonraki satira GECMEZ. Tek satir olmali ve butun mantik "
                    "repo icindeki bir `.sh` dosyasinda durmali."
                )
                continue

            command = commands[0]
            script_paths = re.findall(r"(\S*scripts/[\w./-]+\.sh)", command)
            if not script_paths:
                problems.append(
                    f"{rel}:{lineno} — `{action}` tek satir kosuyor ama repo "
                    f"icindeki bir `.sh` cagirmiyor: {command!r}. Mantik "
                    "workflow'da gomulu kalirsa satir-satir tuzagi geri doner."
                )
                continue

            for raw in script_paths:
                # Yol `../scripts/...` gibi goreli yazilir (adimin
                # `working-directory`si `app/`). Repo koku tek dogru capa.
                resolved = REPO_ROOT / ("scripts/" + raw.split("scripts/", 1)[1])
                if not resolved.exists():
                    problems.append(
                        f"{rel}:{lineno} — cagrilan betik YOK: {resolved}. "
                        "Cagiran var, cagrilan yok = kapisiz kapi."
                    )

    if checked == 0:
        problems.append(
            "Hicbir satir-satir kosan action adimi bulunamadi. Kapi kendini "
            "olcemiyor: ya tarama bozuldu ya da is silindi — ikisi de sessizce "
            "gecilemez."
        )

    if problems:
        print("KIRMIZI — CI script baglantisi:")
        for p in problems:
            print("  - " + p)
        return 1

    print(f"GECTI — {checked} satir-satir action adimi tek satir + var olan .sh")
    return 0


if __name__ == "__main__":
    sys.exit(main())
