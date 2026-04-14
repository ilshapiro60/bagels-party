"""Build Google Play feature graphic (1024x500) from a source photo + headline text."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def _load_font(size: int, bold: bool) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    fonts = Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts"
    candidates: list[str] = []
    if bold:
        candidates += ["segoeuib.ttf", "arialbd.ttf", "calibrib.ttf"]
    else:
        candidates += ["segoeui.ttf", "arial.ttf", "calibri.ttf"]
    for name in candidates:
        p = fonts / name
        if p.is_file():
            try:
                return ImageFont.truetype(str(p), size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def build_feature_graphic(
    src_path: Path,
    out_path: Path,
    headline: str,
    brand: str,
) -> None:
    w, h = 1024, 500
    img = Image.open(src_path).convert("RGB")
    sw, sh = img.size
    scale = max(w / sw, h / sh)
    nw, nh = int(sw * scale + 0.5), int(sh * scale + 0.5)
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left, top = (nw - w) // 2, (nh - h) // 2
    img = img.crop((left, top, left + w, top + h))

    bar_h = 168
    bar = Image.new("RGBA", (w, bar_h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bar)
    for i in range(bar_h):
        a = int(200 * ((i + 1) / bar_h) ** 0.85)
        bd.rectangle((0, i, w, i + 1), fill=(8, 12, 22, min(a, 235)))
    base = img.convert("RGBA")
    base.paste(bar, (0, h - bar_h), bar)
    img = base.convert("RGB")

    draw = ImageDraw.Draw(img)
    font = _load_font(40, bold=True)
    brand_font = _load_font(24, bold=False)

    bbox = draw.textbbox((0, 0), headline, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = max(20, (w - tw) // 2)
    ty = h - bar_h + (bar_h - th) // 2 - 4
    for dx, dy in ((2, 2), (1, 1)):
        draw.text((tx + dx, ty + dy), headline, font=font, fill=(0, 0, 0))
    draw.text((tx, ty), headline, font=font, fill=(255, 255, 255))

    bx, by = 26, 20
    draw.text((bx + 1, by + 1), brand, font=brand_font, fill=(0, 0, 0))
    draw.text((bx, by), brand, font=brand_font, fill=(128, 222, 234))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, "JPEG", quality=93, optimize=True)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("src", type=Path, help="Source photo (any size)")
    p.add_argument(
        "-o",
        "--out",
        type=Path,
        default=Path("docs/store/play-feature-graphic-1024x500.jpg"),
        help="Output path (.jpg or .png)",
    )
    p.add_argument(
        "--headline",
        default="When are you coming for a visit?",
        help="Headline text (keep short for legibility)",
    )
    p.add_argument("--brand", default="ZumiTok", help="Small brand text top-left")
    args = p.parse_args()
    if not args.src.is_file():
        print(f"Missing source: {args.src}", file=sys.stderr)
        return 1
    build_feature_graphic(args.src, args.out, args.headline, args.brand)
    print(f"Wrote {args.out.resolve()} ({args.out.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
