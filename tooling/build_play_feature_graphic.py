"""Build Google Play feature graphic (1024x500) from a source photo + headline text."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


def _load_font(size: int, bold: bool) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    fonts = Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts"
    candidates = (
        ["segoeuib.ttf", "arialbd.ttf", "calibrib.ttf"]
        if bold
        else ["segoeui.ttf", "arial.ttf", "calibri.ttf"]
    )
    for name in candidates:
        p = fonts / name
        if p.is_file():
            try:
                return ImageFont.truetype(str(p), size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def _paste_logo(
    canvas: Image.Image,
    logo_path: Path,
    max_h: int,
    margin: int,
) -> None:
    if not logo_path.is_file():
        return
    logo = Image.open(logo_path).convert("RGBA")
    lw, lh = logo.size
    scale = max_h / lh
    nw, nh = int(lw * scale), int(lh * scale)
    logo = logo.resize((nw, nh), Image.Resampling.LANCZOS)
    # Soft shadow
    shadow = Image.new("RGBA", (nw + 8, nh + 8), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((4, 4, nw + 4, nh + 4), radius=12, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(4))
    canvas.alpha_composite(shadow, (margin - 2, margin - 2))
    canvas.alpha_composite(logo, (margin, margin))


def _vignette(base: Image.Image, strength: float = 0.55) -> Image.Image:
    """Soft edge darkening (Play safe zones); smooth, no banding."""
    w, h = base.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = overlay.load()
    cx, cy = (w - 1) / 2, (h - 1) / 2
    max_d = ((cx * cx) + (cy * cy)) ** 0.5
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            dx = (x - cx) / max_d
            dy = (y - cy) / max_d
            d = (dx * dx + dy * dy) ** 0.5
            edge = max(0.0, d - 0.42) ** 1.55
            a = int(130 * strength * edge)
            if a > 0:
                c = (0, 0, 0, min(a, 95))
                px[x, y] = c
                if x + 1 < w:
                    px[x + 1, y] = c
                if y + 1 < h:
                    px[x, y + 1] = c
                    if x + 1 < w:
                        px[x + 1, y + 1] = c
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=3))
    return Image.alpha_composite(base.convert("RGBA"), overlay)


def build_feature_graphic(
    src_path: Path,
    out_path: Path,
    headline_lines: list[str],
    brand: str,
    *,
    crop_shift: float,
    crop_h_shift: float,
    logo_path: Path | None,
) -> None:
    w, h = 1024, 500
    img = Image.open(src_path).convert("RGB")
    img = ImageEnhance.Color(img).enhance(1.08)
    img = ImageEnhance.Contrast(img).enhance(1.08)
    img = ImageEnhance.Sharpness(img).enhance(1.12)

    sw, sh = img.size
    scale = max(w / sw, h / sh)
    nw, nh = int(sw * scale + 0.5), int(sh * scale + 0.5)
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)

    slack_y = nh - h
    slack_x = nw - w
    # Negative crop_shift moves the window UP (show more of top / faces).
    center_top = slack_y // 2
    top = int(center_top + crop_shift * slack_y)
    top = max(0, min(slack_y, top))
    # Positive crop_h_shift moves the window RIGHT (de-emphasize left-edge clutter).
    center_left = slack_x // 2
    left = int(center_left + crop_h_shift * slack_x)
    left = max(0, min(slack_x, left))
    img = img.crop((left, top, left + w, top + h))

    base = _vignette(img, strength=0.28).convert("RGBA")

    # Headline typography
    headline = "\n".join(headline_lines)
    font = _load_font(40, bold=True)
    draw_tmp = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    bbox = draw_tmp.multiline_textbbox((0, 0), headline, font=font, spacing=6)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]

    pad_x, pad_y = 40, 20
    pill_w = min(w - 100, tw + pad_x * 2)
    pill_h = th + pad_y * 2
    pill_x = (w - pill_w) // 2
    pill_y = h - pill_h - 28

    pill = Image.new("RGBA", (pill_w, pill_h), (0, 0, 0, 0))
    pm = ImageDraw.Draw(pill)
    r = 20
    pm.rounded_rectangle((0, 0, pill_w, pill_h), radius=r, fill=(12, 16, 28, 210))
    # Thin highlight edge
    pm.rounded_rectangle(
        (1, 1, pill_w - 2, pill_h - 2),
        radius=r - 1,
        outline=(255, 255, 255, 35),
        width=1,
    )
    base.paste(pill, (pill_x, pill_y), pill)

    draw = ImageDraw.Draw(base)
    tx = pill_x + (pill_w - tw) // 2 - bbox[0]
    ty = pill_y + (pill_h - th) // 2 - bbox[1]

    # Soft glow / stroke for readability on busy rugs
    for radius in (4, 3, 2, 1):
        alpha = 40 - radius * 8
        c = (0, 0, 0, max(0, alpha))
        for ox, oy in (
            (-radius, 0),
            (radius, 0),
            (0, -radius),
            (0, radius),
            (-radius, -radius),
            (radius, radius),
            (-radius, radius),
            (radius, -radius),
        ):
            draw.multiline_text(
                (tx + ox, ty + oy),
                headline,
                font=font,
                fill=c,
                spacing=6,
            )
    draw.multiline_text(
        (tx, ty),
        headline,
        font=font,
        fill=(248, 252, 255),
        spacing=6,
    )

    if logo_path and logo_path.is_file():
        _paste_logo(base, logo_path, max_h=56, margin=22)
    else:
        bf = _load_font(22, bold=True)
        draw.text((26, 22), brand, font=bf, fill=(0, 0, 0, 160))
        draw.text((25, 21), brand, font=bf, fill=(180, 235, 245))

    out_rgb = base.convert("RGB")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_rgb.save(out_path, "JPEG", quality=96, optimize=True)


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
        "--line1",
        default="When are you",
        help="First line of headline",
    )
    p.add_argument(
        "--line2",
        default="coming for a visit?",
        help="Second line of headline",
    )
    p.add_argument("--brand", default="ZumiTok", help="Fallback brand if no --logo")
    p.add_argument(
        "--logo",
        type=Path,
        default=Path("assets/images/zumitok_logo.png"),
        help="PNG logo (transparent). Use --no-logo for text brand only.",
    )
    p.add_argument(
        "--no-logo",
        action="store_true",
        help="Do not composite zumitok_logo.png",
    )
    p.add_argument(
        "--crop-shift",
        type=float,
        default=-0.28,
        help="Vertical crop bias in [-1,1]. Negative shows more TOP of photo (faces).",
    )
    p.add_argument(
        "--crop-h-shift",
        type=float,
        default=0.1,
        help="Horizontal crop bias in [-1,1]. Positive shifts view RIGHT.",
    )
    args = p.parse_args()
    if not args.src.is_file():
        print(f"Missing source: {args.src}", file=sys.stderr)
        return 1
    logo: Path | None = None if args.no_logo else args.logo
    if logo is not None and not logo.is_file():
        logo = None

    build_feature_graphic(
        args.src,
        args.out,
        [args.line1, args.line2],
        args.brand,
        crop_shift=args.crop_shift,
        crop_h_shift=args.crop_h_shift,
        logo_path=logo,
    )
    print(f"Wrote {args.out.resolve()} ({args.out.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
