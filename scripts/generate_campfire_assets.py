#!/usr/bin/env python3
"""WP-61: First-party procedural campfire PNG layers (RGBA).

Re-run from repo root:
  python3 scripts/generate_campfire_assets.py

No third-party stock art. Output: app/assets/campfire/ (+ 2.0x variants).
"""

from __future__ import annotations

import json
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "app" / "assets" / "campfire"


def write_png(path: Path, w: int, h: int, pixels: bytearray) -> None:
    assert len(pixels) == w * h * 4

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        raw.extend(pixels[y * stride : (y + 1) * stride])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def blank(w: int, h: int) -> bytearray:
    return bytearray(w * h * 4)


def put(px: bytearray, w: int, h: int, x: int, y: int, r: int, g: int, b: int, a: int) -> None:
    if a <= 0 or x < 0 or y < 0 or x >= w or y >= h:
        return
    i = (y * w + x) * 4
    oa = px[i + 3] / 255.0
    na = a / 255.0
    out_a = na + oa * (1 - na)
    if out_a <= 1e-6:
        return
    for c, v in enumerate((r, g, b)):
        oc = px[i + c] / 255.0
        nc = v / 255.0
        px[i + c] = int(round(((nc * na + oc * oa * (1 - na)) / out_a) * 255))
    px[i + 3] = int(round(out_a * 255))


def stamp_ellipse(px, w, h, cx, cy, rx, ry, color, soft=0.55):
    r, g, b, a0 = color
    x0 = max(0, int(cx - rx - 2))
    x1 = min(w - 1, int(cx + rx + 2))
    y0 = max(0, int(cy - ry - 2))
    y1 = min(h - 1, int(cy + ry + 2))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            nx = (x - cx) / max(rx, 1e-6)
            ny = (y - cy) / max(ry, 1e-6)
            d = nx * nx + ny * ny
            if d > 1.0:
                continue
            edge = 1.0 if soft <= 0 else max(0.0, min(1.0, (1.0 - d) / soft))
            a = int(a0 * edge)
            if a > 0:
                put(px, w, h, x, y, r, g, b, a)


def stamp_flame(px, w, h, cx, cy, height, width, color, lean=0.0, soft=0.4):
    r, g, b, a0 = color
    top = cy - height
    bot = cy
    x0 = max(0, int(cx - width - abs(lean) - 2))
    x1 = min(w - 1, int(cx + width + abs(lean) + 2))
    y0 = max(0, int(top - 2))
    y1 = min(h - 1, int(bot + 2))
    for y in range(y0, y1 + 1):
        t = (bot - y) / max(height, 1e-6)
        if t < 0 or t > 1:
            continue
        profile = math.sin(math.pi * min(1.0, t * 1.15)) * (1.0 - t * 0.15)
        half = width * max(0.08, profile)
        mid = cx + lean * t * height * 0.25
        for x in range(x0, x1 + 1):
            nx = abs(x - mid) / max(half, 1e-6)
            if nx > 1:
                continue
            edge = max(0.0, min(1.0, (1.0 - nx) / soft)) * (0.35 + 0.65 * t)
            a = int(a0 * edge)
            if a > 0:
                put(px, w, h, x, y, r, g, b, a)


def stamp_log(px, w, h, cx, cy, length, thickness, angle_deg, color):
    r, g, b, a0 = color
    ang = math.radians(angle_deg)
    ca, sa = math.cos(ang), math.sin(ang)
    half_l, half_t = length / 2, thickness / 2
    pad = length + thickness
    x0 = max(0, int(cx - pad))
    x1 = min(w - 1, int(cx + pad))
    y0 = max(0, int(cy - pad))
    y1 = min(h - 1, int(cy + pad))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dx, dy = x - cx, y - cy
            lx = dx * ca + dy * sa
            ly = -dx * sa + dy * ca
            if abs(lx) <= half_l - half_t:
                d = abs(ly) / max(half_t, 1e-6)
            else:
                ex = abs(lx) - (half_l - half_t)
                d = math.sqrt(ex * ex + ly * ly) / max(half_t, 1e-6)
            if d > 1:
                continue
            edge = max(0.0, min(1.0, (1.0 - d) / 0.35))
            ny = abs(ly) / max(half_t, 1e-6)
            shade = 0.75 + 0.25 * (1 - ny)
            a = int(a0 * edge)
            put(px, w, h, x, y, int(r * shade), int(g * shade), int(b * shade), a)


def gen_size(size: int, out_dir: Path) -> dict:
    cx = cy = size // 2
    inv: dict = {}

    px = blank(size, size)
    stamp_ellipse(px, size, size, cx, cy + size * 0.08, size * 0.42, size * 0.22, (42, 32, 22, 210), soft=0.5)
    stamp_ellipse(px, size, size, cx, cy + size * 0.06, size * 0.34, size * 0.16, (58, 44, 30, 160), soft=0.55)
    stamp_ellipse(px, size, size, cx, cy + size * 0.05, size * 0.22, size * 0.10, (34, 26, 18, 120), soft=0.6)
    write_png(out_dir / "ground.png", size, size, px)
    inv["ground.png"] = {"role": "zemin/açıklık", "w": size, "h": size}

    px = blank(size, size)
    stamp_ellipse(px, size, size, cx, cy + size * 0.04, size * 0.28, size * 0.14, (255, 140, 40, 90), soft=0.9)
    stamp_ellipse(px, size, size, cx, cy + size * 0.02, size * 0.16, size * 0.08, (255, 190, 80, 70), soft=0.85)
    write_png(out_dir / "glow.png", size, size, px)
    inv["glow.png"] = {"role": "sıcak zemin ışığı", "w": size, "h": size}

    px = blank(size, size)
    bark = (92, 58, 34, 240)
    bark2 = (72, 46, 28, 235)
    stamp_log(px, size, size, cx - size * 0.02, cy + size * 0.06, size * 0.38, size * 0.07, 18, bark)
    stamp_log(px, size, size, cx + size * 0.02, cy + size * 0.07, size * 0.36, size * 0.065, -22, bark2)
    stamp_log(px, size, size, cx, cy + size * 0.03, size * 0.28, size * 0.055, 8, (80, 52, 30, 220))
    write_png(out_dir / "wood.png", size, size, px)
    inv["wood.png"] = {"role": "odun yığını", "w": size, "h": size}

    px = blank(size, size)
    for i, ang in enumerate(range(0, 360, 28)):
        rad = math.radians(ang)
        sc = 0.9 + 0.1 * ((i * 3) % 5) / 5
        sx = cx + math.cos(rad) * size * 0.16
        sy = cy + size * 0.06 + math.sin(rad) * size * 0.09
        grey = 110 + (i * 17) % 40
        stamp_ellipse(
            px,
            size,
            size,
            sx,
            sy,
            size * 0.035 * sc,
            size * 0.028 * sc,
            (grey, grey - 4, grey - 10, 230),
            soft=0.4,
        )
    write_png(out_dir / "stones.png", size, size, px)
    inv["stones.png"] = {"role": "taş halka", "w": size, "h": size}

    px = blank(size, size)
    stamp_flame(px, size, size, cx, cy + size * 0.02, size * 0.36, size * 0.14, (220, 70, 20, 200), lean=-0.15, soft=0.45)
    stamp_flame(px, size, size, cx + size * 0.02, cy + size * 0.02, size * 0.32, size * 0.11, (200, 60, 15, 160), lean=0.2, soft=0.5)
    write_png(out_dir / "flame_back.png", size, size, px)
    inv["flame_back.png"] = {"role": "alev dış katman", "w": size, "h": size}

    px = blank(size, size)
    stamp_flame(px, size, size, cx, cy + size * 0.01, size * 0.30, size * 0.10, (255, 140, 30, 220), lean=0.08, soft=0.4)
    stamp_flame(px, size, size, cx - size * 0.015, cy + size * 0.01, size * 0.26, size * 0.08, (255, 120, 25, 180), lean=-0.12, soft=0.42)
    write_png(out_dir / "flame_mid.png", size, size, px)
    inv["flame_mid.png"] = {"role": "alev orta katman", "w": size, "h": size}

    px = blank(size, size)
    stamp_flame(px, size, size, cx, cy, size * 0.22, size * 0.06, (255, 230, 140, 230), lean=0.05, soft=0.5)
    stamp_ellipse(px, size, size, cx, cy + size * 0.01, size * 0.05, size * 0.035, (255, 250, 210, 200), soft=0.7)
    write_png(out_dir / "flame_front.png", size, size, px)
    inv["flame_front.png"] = {"role": "alev iç çekirdek", "w": size, "h": size}

    px = blank(size, size)
    stamp_ellipse(px, size, size, cx - size * 0.04, cy - size * 0.22, size * 0.10, size * 0.14, (160, 165, 175, 70), soft=0.85)
    stamp_ellipse(px, size, size, cx + size * 0.05, cy - size * 0.28, size * 0.12, size * 0.16, (150, 155, 165, 55), soft=0.9)
    stamp_ellipse(px, size, size, cx, cy - size * 0.34, size * 0.14, size * 0.12, (140, 148, 160, 40), soft=0.95)
    write_png(out_dir / "smoke.png", size, size, px)
    inv["smoke.png"] = {"role": "duman", "w": size, "h": size}

    px = blank(size, size)
    stamp_ellipse(px, size, size, cx, cy + size * 0.05, size * 0.10, size * 0.05, (80, 30, 10, 180), soft=0.6)
    for i in range(8):
        ang = i * math.pi / 4
        stamp_ellipse(
            px,
            size,
            size,
            cx + math.cos(ang) * size * 0.04,
            cy + size * 0.05 + math.sin(ang) * size * 0.02,
            size * 0.018,
            size * 0.012,
            (220, 90, 30, 160),
            soft=0.55,
        )
    write_png(out_dir / "coals.png", size, size, px)
    inv["coals.png"] = {"role": "boş/az durum közleri", "w": size, "h": size}

    ew, eh = size, size // 4
    px = blank(ew, eh)
    for k in range(4):
        ex = (k + 0.5) * (ew / 4)
        ey = eh * 0.55
        stamp_ellipse(px, ew, eh, ex, ey, eh * 0.28, eh * 0.28, (255, 160, 40, 230), soft=0.6)
        stamp_ellipse(px, ew, eh, ex, ey, eh * 0.14, eh * 0.14, (255, 230, 160, 220), soft=0.5)
    write_png(out_dir / "ember_sheet.png", ew, eh, px)
    inv["ember_sheet.png"] = {
        "role": "köz parçacık sprite sheet (4 kare)",
        "w": ew,
        "h": eh,
        "frames": 4,
    }
    return inv


def main() -> None:
    inv1 = gen_size(512, ROOT)
    inv2 = gen_size(1024, ROOT / "2.0x")
    manifest = {
        "package": "campfire_r2",
        "version": 1,
        "license": (
            "First-party procedural art generated for Odak Kampı (WP-61). "
            "All rights reserved to the project. No third-party stock."
        ),
        "source": "scripts/generate_campfire_assets.py (pure Python RGBA procedural)",
        "base_path": "assets/campfire/",
        "density": {
            "1.0x": {"canvas_px": 512, "files": inv1},
            "2.0x": {"canvas_px": 1024, "folder": "2.0x/", "files": inv2},
        },
        "layers_z_order_bottom_to_top": [
            "ground",
            "glow",
            "stones",
            "wood",
            "coals",
            "flame_back",
            "flame_mid",
            "flame_front",
            "smoke",
            "ember_sheet (particles)",
        ],
        "anchor": {
            "description": (
                "Fire base at canvas center (0.5, 0.5); ground/wood sit slightly "
                "below center (+0.05..0.08 cy)."
            ),
            "fire_origin_normalized": [0.5, 0.5],
        },
        "alpha": "Straight (non-premultiplied) RGBA PNG-32. No white matte.",
        "naming": "snake_case, English, no spaces: <layer>.png",
    }
    (ROOT / "inventory.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote assets under {ROOT}")


if __name__ == "__main__":
    main()
