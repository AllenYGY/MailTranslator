#!/usr/bin/env python3
"""Generate the MailTranslator app icon (.icns) programmatically.

Renders a macOS-style squircle icon at 4x supersampling with PIL+numpy:
gradient background, white envelope, and a circular "文A" badge.
Multiple color variants are produced; the default one becomes AppIcon.icns.

Usage: python3 tools/make_icon.py [--variant N] [--out-dir Resources]
"""

import argparse
import math
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 4            # supersampling factor
SIZE = 1024       # logical icon size
CANVAS = SIZE * SS
FONT_PATH = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_INDEX = 2    # Hiragino Sans GB W6


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(c1, c2, t):
    return tuple(round(a + (b - a) * t) for a, b in zip(c1, c2))


VARIANTS = {
    1: {  # Ocean: blue -> teal, closest to Mail.app but distinct
        "name": "ocean",
        "c1": hex_rgb("#2D7FF9"), "c2": hex_rgb("#12B5A5"),
        "envelope": (255, 255, 255), "flap_shade": hex_rgb("#E7EEF7"),
        "chevron": hex_rgb("#8FA6C0"),
        "badge_fill": (255, 255, 255), "badge_ring": None,
        "wen": hex_rgb("#2D7FF9"), "latin": hex_rgb("#0E9C8C"),
    },
    2: {  # Ember: orange -> coral, stands out in the Dock
        "name": "ember",
        "c1": hex_rgb("#FF8A3D"), "c2": hex_rgb("#F2445C"),
        "envelope": (255, 255, 255), "flap_shade": hex_rgb("#FBEDE8"),
        "chevron": hex_rgb("#D9A08F"),
        "badge_fill": (255, 255, 255), "badge_ring": None,
        "wen": hex_rgb("#F0563F"), "latin": hex_rgb("#E23B5C"),
    },
    3: {  # Porcelain: light plate, blue envelope
        "name": "porcelain",
        "c1": hex_rgb("#F4F7FB"), "c2": hex_rgb("#D3DDE9"),
        "envelope": hex_rgb("#2D6CDF"), "flap_shade": hex_rgb("#2459BB"),
        "chevron": (255, 255, 255),
        "badge_fill": (255, 255, 255), "badge_ring": hex_rgb("#2D6CDF"),
        "wen": hex_rgb("#2D6CDF"), "latin": hex_rgb("#0E9C8C"),
    },
}


def superellipse_mask(half):
    """L-mode mask of an Apple-style squircle fitting in 2*half box."""
    n = 4.6
    d = half * 2
    y, x = np.mgrid[0:d, 0:d].astype(np.float64)
    x = (x - half + 0.5) / half
    y = (y - half + 0.5) / half
    v = np.abs(x) ** n + np.abs(y) ** n
    edge = 1.0 / half  # ~1px antialias band at render scale
    a = np.clip((1.0 - v) / (n * edge) + 0.5, 0.0, 1.0)
    return Image.fromarray((a * 255).astype(np.uint8), "L")


def diagonal_gradient(size, c1, c2):
    y, x = np.mgrid[0:size, 0:size].astype(np.float64)
    t = (x / size + y / size) / 2.0
    t = np.clip((t - 0.08) / 0.84, 0.0, 1.0)  # stretch so corners hit pure colors
    arr = np.zeros((size, size, 3), np.uint8)
    for ch in range(3):
        arr[..., ch] = (c1[ch] + (c2[ch] - c1[ch]) * t).astype(np.uint8)
    return Image.fromarray(arr, "RGB")


def top_highlight(size, mask):
    """Soft light from the top, clipped to the squircle."""
    from PIL import ImageChops
    y = np.arange(size, dtype=np.float64)
    a = np.clip(1.0 - y / (size * 0.62), 0.0, 1.0) * 0.20
    alpha = np.repeat(a[:, None], size, axis=1)
    hl = Image.fromarray((alpha * 255).astype(np.uint8), "L")
    m = mask.resize((size, size)) if mask.size != (size, size) else mask
    return ImageChops.multiply(hl, m)


def draw_envelope(base, v, cx, cy, w, h, radius):
    """Envelope with flap shading, chevron lines and soft shadow."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, y0 = cx - w / 2, cy - h / 2
    x1, y1 = cx + w / 2, cy + h / 2

    # drop shadow
    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [x0, y0 + 22 * SS, x1, y1 + 22 * SS], radius * SS,
        fill=(20, 40, 60, 80))
    sh = sh.filter(ImageFilter.GaussianBlur(26 * SS))
    base.alpha_composite(sh)

    d.rounded_rectangle([x0, y0, x1, y1], radius * SS, fill=v["envelope"])

    # flap shade triangle (clipped by drawing inside the body rect)
    flap_y = y0 + (y1 - y0) * 0.56
    inset = 10 * SS
    d.polygon([(x0 + inset + radius * SS * 0.55, y0 + inset),
               (x1 - inset - radius * SS * 0.55, y0 + inset),
               (cx, flap_y)], fill=v["flap_shade"])

    # chevron V lines
    lw = 24 * SS
    vx0, vy0 = x0 + 20 * SS, y0 + 24 * SS
    vx1, _ = x1 - 20 * SS, y0 + 24 * SS
    d.line([(vx0, vy0), (cx, flap_y), (vx1, vy0)],
           fill=v["chevron"], width=lw, joint="curve")
    for px, py in [(vx0, vy0), (cx, flap_y), (vx1, vy0)]:
        d.ellipse([px - lw / 2, py - lw / 2, px + lw / 2, py + lw / 2],
                  fill=v["chevron"])

    base.alpha_composite(layer)


def draw_badge(base, v, cx, cy, r):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse(
        [cx - r, cy - r + 16 * SS, cx + r, cy + r + 16 * SS],
        fill=(20, 40, 60, 70))
    sh = sh.filter(ImageFilter.GaussianBlur(22 * SS))
    base.alpha_composite(sh)

    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=v["badge_fill"])
    if v["badge_ring"] is not None:
        rw = 12 * SS
        ri = r - rw * 1.6
        d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri],
                  outline=v["badge_ring"], width=rw)

    font = ImageFont.truetype(FONT_PATH, int(r * 0.98), index=FONT_INDEX)
    gap = r * 0.06
    w_wen = d.textlength("文", font=font)
    w_a = d.textlength("A", font=font)
    total = w_wen + gap + w_a
    x_wen = cx - total / 2 + w_wen / 2
    x_a = cx + total / 2 - w_a / 2
    ty = cy + r * 0.04
    d.text((x_wen, ty), "文", font=font, fill=v["wen"], anchor="mm")
    d.text((x_a, ty + r * 0.03), "A", font=font, fill=v["latin"], anchor="mm")

    base.alpha_composite(layer)


def render_variant(v):
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    half = int(412 * SS)  # squircle half-size -> 824 logical
    mask = superellipse_mask(half)

    grad = diagonal_gradient(half * 2, v["c1"], v["c2"]).convert("RGBA")
    grad.putalpha(mask)
    img.alpha_composite(grad, (int((CANVAS - half * 2) / 2),) * 2)

    hl = Image.new("RGBA", (CANVAS, CANVAS), (255, 255, 255, 0))
    hl.putalpha(top_highlight(CANVAS, mask))
    img.alpha_composite(hl)

    draw_envelope(img, v, cx=470 * SS, cy=492 * SS,
                  w=470 * SS, h=330 * SS, radius=36)
    draw_badge(img, v, cx=742 * SS, cy=724 * SS, r=168 * SS)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def build_icns(master_png, work_dir):
    iconset = work_dir / "AppIcon.iconset"
    iconset.mkdir(exist_ok=True)
    img = Image.open(master_png)
    for name, px in [("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
                     ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
                     ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
                     ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
                     ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)]:
        img.resize((px, px), Image.LANCZOS).save(iconset / name)
    out = work_dir / "AppIcon.icns"
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(out)],
                   check=True)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", type=int, default=1, choices=sorted(VARIANTS))
    ap.add_argument("--out-dir", type=Path,
                    default=Path(__file__).resolve().parent.parent / "Resources")
    args = ap.parse_args()

    icon_dir = args.out_dir / "Icon"
    icon_dir.mkdir(parents=True, exist_ok=True)

    masters = {}
    for num, v in VARIANTS.items():
        img = render_variant(v)
        p = icon_dir / f"icon-v{num}-{v['name']}-1024.png"
        img.save(p)
        masters[num] = p
        print(f"variant {num} ({v['name']}): {p}")

    chosen = masters[args.variant]
    icns = build_icns(chosen, args.out_dir)
    print(f"AppIcon.icns <- variant {args.variant}: {icns}")


if __name__ == "__main__":
    main()
