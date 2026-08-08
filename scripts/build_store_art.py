"""WP-528: Play Console listing gorselleri (ikon + one cikan grafik).

Kaynak UYDURULMADI: uygulamanin GERCEKTEN yayinladigi adaptive icon
foreground'u kullanilir (app/android/app/src/stable/.../ic_launcher_foreground.png).
Play, listing ikonunun uygulamanin ikonuyla ayni olmasini bekler; yeni bir logo
tasarlamak hem yanlis olurdu hem de logo sahibin kardesinde.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "references" / "play-store"
OUT.mkdir(parents=True, exist_ok=True)

FG = ROOT / "app/android/app/src/stable/res/mipmap-xxxhdpi/ic_launcher_foreground.png"
FONT = ROOT / "app/assets/fonts/Inter-Variable.ttf"

# Uygulamanin kamp atesi paleti (assets/campfire ve tema presetleriyle uyumlu
# sicak ton). Duz renk secildi: gradyan store kucuk boyutta kirli gorunuyor.
CREAM = (250, 245, 231, 255)
NIGHT = (26, 30, 46, 255)
EMBER = (251, 201, 129, 255)


def artwork() -> Image.Image:
    """Foreground'u seffaf kenarlarindan kirpar."""
    image = Image.open(FG).convert("RGBA")
    box = image.split()[3].getbbox()
    return image.crop(box)


def store_icon() -> Path:
    """512x512, seffaflik YOK, kare. Play maskeyi kendi uygular."""
    size = 512
    canvas = Image.new("RGBA", (size, size), CREAM)
    art = artwork()
    margin = int(size * 0.11)
    target = size - 2 * margin
    scale = min(target / art.width, target / art.height)
    art = art.resize(
        (max(1, int(art.width * scale)), max(1, int(art.height * scale))),
        Image.LANCZOS,
    )
    canvas.alpha_composite(
        art, ((size - art.width) // 2, (size - art.height) // 2)
    )
    path = OUT / "play-icon-512.png"
    canvas.convert("RGB").save(path, "PNG")
    return path


def feature_graphic(title_text: str, subtitle_text: str, name: str) -> Path:
    """1024x500. Play bunu kirpabilir ve ustune metin bindirebilir; bu yuzden
    yazi sol yarida ve kenarlardan uzak durur.

    Ilk denemede "isik" duz opak bir daire olarak cizildi ve YAZIYI YUTTU.
    Simdi gercek yumusak gecis: radyal gradyan MASKE olarak kullaniliyor.
    """
    width, height = 1024, 500
    canvas = Image.new("RGBA", (width, height), NIGHT)

    # Yumusak sicak isik.
    #
    # 🔴 `Image.radial_gradient` KULLANILMIYOR. O gradyan 255'e ancak KOSEGEN
    # mesafede ulasir; karenin kenar ortasinda deger ~180'de kalir, yani alfa
    # sifirlanmaz ve karenin kenari duz bir DIKEY CIZGI olarak gorunur. Iki
    # denemede de tam bu oldu ve olculdu (x=434 ve x=262'de arka plan sicramasi).
    # Maske burada es merkezli dairelerle uretilir: yaricapin disinda deger
    # kesin olarak 0'dir, yani gorunur kenar matematiksel olarak imkansiz.
    glow_center = (width - 250, height // 2)
    glow_radius = 560
    mask = Image.new("L", (width, height), 0)
    mask_draw = ImageDraw.Draw(mask)
    for step in range(glow_radius, 0, -2):
        value = int(255 * (1 - step / glow_radius) ** 1.6 * 0.55)
        mask_draw.ellipse(
            [
                glow_center[0] - step,
                glow_center[1] - step,
                glow_center[0] + step,
                glow_center[1] + step,
            ],
            fill=value,
        )
    mask = mask.filter(ImageFilter.GaussianBlur(18))
    glow = Image.new("RGBA", (width, height), EMBER[:3] + (255,))
    canvas.paste(glow, (0, 0), mask)

    art = artwork()
    art_height = 320
    scale = art_height / art.height
    art = art.resize((int(art.width * scale), art_height), Image.LANCZOS)
    art_x = width - art.width - 120
    canvas.alpha_composite(art, (art_x, (height - art.height) // 2))

    draw = ImageDraw.Draw(canvas)
    title = ImageFont.truetype(str(FONT), 72)
    subtitle = ImageFont.truetype(str(FONT), 30)

    draw.text((72, 190), title_text, font=title, fill=(255, 252, 245, 255))
    draw.text((74, 288), subtitle_text, font=subtitle, fill=EMBER)

    # Yazi gorseli ezmemeli: metin kutusu ile artwork'un sol kenari olculur.
    right_edge = max(
        draw.textbbox((72, 190), title_text, font=title)[2],
        draw.textbbox((74, 288), subtitle_text, font=subtitle)[2],
    )
    if right_edge > art_x - 40:
        raise SystemExit(
            f"Yazi gorsele giriyor: metin {right_edge}px, gorsel {art_x}px"
        )

    path = OUT / name
    canvas.convert("RGB").save(path, "PNG")
    print(f"  metin sag kenari {right_edge}px, gorsel {art_x}px'de basliyor")
    return path


# TR ve EN listeleri AYRI gorsel ister: EN kullaniciya Turkce yazili bir
# grafik gostermek, iki dilli listenin butun amacini bozar. Ikon dil bagimsiz
# (uzerinde yazi yok), o yuzden tek dosya yeter.
produced_files = (
    store_icon(),
    feature_graphic(
        "Odak Kampı",
        "Arkadaşlarınla birlikte çalış",
        "play-feature-graphic-1024x500.png",
    ),
    feature_graphic(
        "Focus Camp",
        "Study together with friends",
        "play-feature-graphic-en-1024x500.png",
    ),
)

for produced in produced_files:
    with Image.open(produced) as check:
        print(f"{produced.name}: {check.size} {check.mode} "
              f"{produced.stat().st_size // 1024} KB")
