#!/usr/bin/env python3
"""Floatblue wallpapers.

The palette is taken from the Flat Remix GTK-Blue theme the desktop ships, so
the wallpaper and the desktop are the same blue: accent #2777ff, window #23252e,
headerbar #1a1c23, and the dark_3/dark_4 ramp #3d3846 / #241f31.

Every pattern is drawn twice, once for a light desktop and once for a dark one,
and each one treats the logo differently on purpose: some put it in the corner,
some centre it, some tile it as a faint watermark, one outlines it and one
leaves it out entirely so the pattern stands on its own.

The images are committed to the repository rather than drawn at build time. This
script stays alongside them so the set can be regenerated or extended, which is
the point of keeping it: a wallpaper collection you cannot reproduce is just a
folder of binaries.

    ./generate-floatblue-wallpapers.py [output-dir] [width] [height]
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# Flat Remix GTK-Blue supplies the accent, but the backgrounds here go deeper
# and more saturated than the desktop. An earlier pass used a near-white light
# background and a near-black dark one, and both read as empty grey with a blue
# tinge. Light is now a real blue that the shapes sit on top of, and dark is a
# saturated indigo rather than black.
ACCENT = (0x27, 0x77, 0xFF)          # straight from the theme
AZURE = (0x2E, 0x7C, 0xFF)
ROYAL = (0x1B, 0x4D, 0xE8)
INDIGO = (0x24, 0x1C, 0x8F)
VIOLET = (0x5B, 0x3D, 0xE8)
CYAN = (0x3A, 0xC2, 0xFB)
ACCENT_SOFT = (0x74, 0xAE, 0xFF)

DEEP = (0x08, 0x0E, 0x30)
DARK_BG = (0x14, 0x1E, 0x5E)
DARK_BG2 = (0x24, 0x25, 0x86)

LIGHT_BG = (0xC2, 0xDC, 0xFF)
LIGHT_BG2 = (0x7C, 0xB0, 0xFF)
INK = (0x0C, 0x14, 0x3E)

HERE = Path(__file__).resolve().parent
LOGO = HERE.parent / "branding" / "floatos-logo.png"

SEED = 20261001


# --------------------------------------------------------------------------- helpers

def gradient(size, top, bottom):
    """Vertical linear gradient as an RGB image."""
    w, h = size
    ramp = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
    top = np.array(top, dtype=np.float32)
    bottom = np.array(bottom, dtype=np.float32)
    rows = top[None, :] * (1 - ramp) + bottom[None, :] * ramp
    arr = np.repeat(rows[:, None, :], w, axis=1)
    return Image.fromarray(arr.astype(np.uint8), "RGB")


def radial_mask(size, cx, cy, radius, falloff=2.0):
    """Soft circular falloff, 1.0 at the centre down to 0.0 at the edge."""
    w, h = size
    xs = np.arange(w, dtype=np.float32)[None, :]
    ys = np.arange(h, dtype=np.float32)[:, None]
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / max(radius, 1.0)
    return np.clip(1.0 - d, 0.0, 1.0) ** falloff


def value_noise(size, octaves=5, seed=SEED):
    """Smooth fractal noise built by summing upscaled random grids."""
    w, h = size
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), dtype=np.float32)
    amp, total = 1.0, 0.0
    for octave in range(octaves):
        cells = 2 ** (octave + 1)
        base = rng.random((cells + 1, cells + 1)).astype(np.float32)
        layer = np.asarray(
            Image.fromarray((base * 255).astype(np.uint8), "L")
            .resize((w, h), Image.Resampling.BICUBIC),
            dtype=np.float32,
        ) / 255.0
        out += layer * amp
        total += amp
        amp *= 0.5
    return out / total


def tint(base, colour, mask):
    """Composite a flat colour over the base image using a float mask."""
    arr = np.asarray(base, dtype=np.float32)
    layer = np.array(colour, dtype=np.float32)[None, None, :]
    m = mask[..., None]
    out = arr * (1 - m) + layer * m
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def load_logo(px):
    logo = Image.open(LOGO).convert("RGBA")
    side = int(px * logo.width / logo.height)
    return logo.resize((side, side), Image.Resampling.LANCZOS)


def paste_logo(img, px, *, at=None, centre=None, opacity=0.18, tile=0, alpha_mask=None):
    """Put the logo on the wallpaper in one of a few ways.

    at      (x, y) top-left corner
    centre  True to dead centre
    tile    if non-zero, repeat the logo across the image at that size
    """
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))

    if tile:
        step = int(px * 1.9)
        for y in range(-step, img.height + step, step):
            for x in range(-step, img.width + step, step):
                l = load_logo(px).copy()
                l.putalpha(l.getchannel("A").point(lambda v: int(v * opacity * 0.55)))
                layer.alpha_composite(l, (x, y))
    else:
        logo = load_logo(px)
        if alpha_mask is not None:
            # keep only part of the mark, so it reads as part of the pattern
            a = np.asarray(logo.getchannel("A"), dtype=np.float32) / 255.0
            a *= alpha_mask(logo.width, logo.height)
            logo.putalpha(Image.fromarray((a * 255).astype(np.uint8), "L"))

        if centre:
            x = (img.width - logo.width) // 2
            y = (img.height - logo.height) // 2
        else:
            x, y = at if at else (img.width - logo.width - px // 4, img.height - logo.height - px // 4)

        logo.putalpha(logo.getchannel("A").point(lambda v: int(v * opacity)))
        layer.alpha_composite(logo, (x, y))

    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


# --------------------------------------------------------------------------- patterns

def aurora(size, light):
    """Soft overlapping glows, like light through water."""
    w, h = size
    img = gradient(size, LIGHT_BG2 if light else DEEP, LIGHT_BG if light else DARK_BG2)
    blobs = [
        (0.28, 0.32, 0.62, ACCENT, 0.55),
        (0.74, 0.24, 0.48, ACCENT_SOFT, 0.42),
        (0.55, 0.78, 0.55, CYAN if not light else VIOLET, 0.38),
        (0.88, 0.72, 0.38, VIOLET if not light else ROYAL, 0.30),
        (0.12, 0.80, 0.42, CYAN if not light else VIOLET, 0.24),
    ]
    for cx, cy, rad, colour, strength in blobs:
        m = radial_mask(size, w * cx, h * cy, w * rad, falloff=2.4) * strength
        img = tint(img, colour, m)
    img = img.filter(ImageFilter.GaussianBlur(radius=w / 90))
    return paste_logo(img, int(h * 0.17), centre=True, opacity=0.14 if light else 0.20)


def contours(size, light):
    """Elevation-map style contour lines from fractal noise.

    The lines have to be thin to read as contours. Thresholding too wide and the
    bands merge into a marbled mess, which is what the light variant did before.
    Every fifth line is drawn heavier so it reads like a real topo map.
    """
    w, h = size
    field = value_noise(size, octaves=4, seed=SEED)
    phase = field * 21.0
    index = np.floor(phase)
    dist = np.abs((phase - index) - 0.5) * 2.0

    heavy = (index % 5.0) < 0.5
    thin = np.clip(1.0 - dist / 0.055, 0.0, 1.0) * (~heavy)
    thick = np.clip(1.0 - dist / 0.13, 0.0, 1.0) * heavy
    mask = np.maximum(thin, thick)

    soft = np.asarray(
        Image.fromarray((mask * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(0.7)),
        dtype=np.float32,
    ) / 255.0

    img = gradient(size, LIGHT_BG if light else DEEP, LIGHT_BG2 if light else DARK_BG)
    img = tint(img, ROYAL if light else AZURE, soft * (0.80 if light else 0.80))
    return paste_logo(img, int(h * 0.13), tile=1, opacity=0.16)

def isogrid(size, light):
    """Isometric lattice, the graph paper you get in a 3D editor."""
    w, h = size
    img = gradient(size, LIGHT_BG2 if light else DARK_BG2, LIGHT_BG if light else DEEP)

    # Tint before drawing. Painting the glow on top wiped the lines out of the
    # middle and left what looked like plain moire in the corners.
    glow = radial_mask(size, w * 0.42, h * 0.38, w * 0.72, 1.9)
    img = tint(img, VIOLET if not light else LIGHT_BG, glow * (0.34 if not light else 0.40))

    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    line = ACCENT_SOFT if light else CYAN
    a = 120 if light else 150
    step = int(w / 15)
    reach = h * 2
    for i in range(-h, w + h, step):
        d.line([(i, 0), (i + reach, h)], fill=line + (a,), width=1)
        d.line([(i, 0), (i - reach, h)], fill=line + (a,), width=1)
    # every fourth line heavier, so it reads as a real lattice and not noise
    for i in range(-h, w + h, step * 4):
        d.line([(i, 0), (i + reach, h)], fill=line + (200 if not light else 180,), width=2)
        d.line([(i, 0), (i - reach, h)], fill=line + (200 if not light else 180,), width=2)

    img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    return paste_logo(img, int(h * 0.28), at=(int(w * 0.06), int(h * 0.56)), opacity=0.18)

def rings(size, light):
    """Concentric circles from an off-centre origin, thinning outward."""
    w, h = size
    img = gradient(size, LIGHT_BG2 if light else DEEP, LIGHT_BG if light else DARK_BG2)
    cx, cy = w * 0.68, h * 0.34

    glow = radial_mask(size, cx, cy, w * 0.8, 1.9)
    img = tint(img, VIOLET if not light else LIGHT_BG, glow * (0.30 if not light else 0.42))

    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    colour = CYAN if not light else ROYAL
    for i in range(1, 28):
        r = i * w * 0.046
        a = int((230 if not light else 190) * (1 - i / 34))
        width = 3 if i % 5 == 0 else 1
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=colour + (a,), width=width)
    img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    return paste_logo(img, int(h * 0.22), centre=True, opacity=0.20 if light else 0.26)

def halftone(size, light):
    """Dot matrix whose radius swells towards a focus point."""
    w, h = size
    img = gradient(size, LIGHT_BG2 if light else DARK_BG, LIGHT_BG if light else DEEP)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = max(14, w // 96)
    fx, fy = w * 0.62, h * 0.44
    colour = ROYAL if light else AZURE
    y = step // 2
    row = 0
    while y < h:
        x = step // 2 + (step // 2 if row % 2 else 0)
        while x < w:
            t = math.hypot(x - fx, y - fy) / (w * 0.75)
            r = max(0.0, (1.0 - t)) * step * 0.48
            if r > 0.6:
                a = int((190 if not light else 150) * min(1.0, r / (step * 0.42)))
                d.ellipse([x - r, y - r, x + r, y + r], fill=colour + (a,))
            x += step
        y += step
        row += 1
    img = Image.alpha_composite(img.convert("RGBA"), layer.filter(ImageFilter.GaussianBlur(0.5))).convert("RGB")
    return paste_logo(img, int(h * 0.15), at=(int(w * 0.07), int(h * 0.72)), opacity=0.15)


def waves(size, light):
    """Stacked sine lines, drifting out of phase."""
    w, h = size
    img = gradient(size, LIGHT_BG if light else DARK_BG2, LIGHT_BG2 if light else DEEP)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    lines = 46
    for i in range(lines):
        t = i / (lines - 1)
        base = h * (0.24 + 0.66 * t)
        amp = h * 0.055 * (0.35 + t)
        wl = w * (0.42 + 0.55 * (1 - t))
        phase = t * 2.4 + 0.6
        a = int((165 if not light else 145) * (0.35 + 0.65 * (1 - abs(t - 0.45) * 1.4)))
        a = max(0, min(255, a))
        pts = []
        for px in range(0, w + 8, 8):
            u = px / w
            y = base + math.sin(u * math.pi * 2 / wl * 2 + phase) * amp * (0.4 + u)
            pts.append((px, y))
        d.line(pts, fill=(AZURE if light else CYAN) + (a,), width=2, joint="curve")
    img = Image.alpha_composite(img.convert("RGBA"), layer.filter(ImageFilter.GaussianBlur(0.6))).convert("RGB")
    return paste_logo(img, int(h * 0.14), at=(int(w * 0.72), int(h * 0.10)), opacity=0.16)


def rays(size, light):
    """Radial burst from just below the bottom edge."""
    w, h = size
    img = gradient(size, LIGHT_BG2 if light else DARK_BG2, LIGHT_BG if light else DEEP)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = w * 0.5, h * 1.04
    rays = 46
    for i in range(rays):
        ang = math.pi * (i / (rays - 1))
        length = w * 1.7
        a = 70 if not light else 52
        d.line(
            [(cx, cy), (cx + math.cos(ang) * length, cy + math.sin(ang) * length)],
            fill=ACCENT + (a,),
            width=int(w / 300) + 1,
        )
    img = Image.alpha_composite(img.convert("RGBA"), layer.filter(ImageFilter.GaussianBlur(1.6))).convert("RGB")

    glow = radial_mask(size, cx, h * 0.78, w * 0.8, 1.8)
    img = tint(img, ACCENT_SOFT if not light else LIGHT_BG, glow * (0.30 if light else 0.34))
    return paste_logo(img, int(h * 0.24), centre=True, opacity=0.16 if light else 0.24)

def strata(size, light):
    """Layered horizon silhouettes, quiet and mostly empty at the top."""
    w, h = size
    img = gradient(size, LIGHT_BG if light else DARK_BG2, LIGHT_BG2 if light else DEEP)

    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rng = np.random.default_rng(SEED + 7)
    bands = 5
    for b in range(bands):
        t = b / (bands - 1)
        y0 = h * (0.60 + 0.085 * b)
        pts = [(0, h), (0, y0)]
        x = 0
        while x < w:
            step = w / 14
            y0 += rng.normal(0, h * 0.022)
            y0 = max(h * 0.55, min(h * 0.95, y0))
            pts.append((x, y0))
            x += step
        pts += [(w, h)]
        shade = 0.30 - 0.24 * t
        col = INDIGO if light else (0x0B, 0x12, 0x40)
        d.polygon(pts, fill=col + (int(255 * (shade + 0.30)),))
    img = Image.alpha_composite(img.convert("RGBA"), layer.filter(ImageFilter.GaussianBlur(0.7))).convert("RGB")

    glow = radial_mask(size, w * 0.5, h * 0.52, w * 0.48, 2.6)
    img = tint(img, ACCENT_SOFT if not light else LIGHT_BG, glow * (0.22 if light else 0.28))
    return paste_logo(img, int(h * 0.13), at=(int(w * 0.08), int(h * 0.12)), opacity=0.17)


def monogram(size, light):
    """A hairline grid with the mark tiled across it as a watermark."""
    w, h = size
    img = gradient(size, LIGHT_BG2 if light else DEEP, LIGHT_BG if light else DARK_BG2)

    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = int(w / 40)
    grid = ACCENT + (26 if light else 34,)
    for x in range(0, w + step, step):
        d.line([(x, 0), (x, h)], fill=grid, width=1)
    for y in range(0, h + step, step):
        d.line([(0, y), (w, y)], fill=grid, width=1)
    img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")

    glow = radial_mask(size, w * 0.5, h * 0.5, w * 0.62, 1.7)
    img = tint(img, LIGHT_BG if light else (0x10, 0x15, 0x2C), glow * (0.45 if light else 0.42))
    return paste_logo(img, int(h * 0.30), tile=1, opacity=0.30)

PATTERNS = (
    ("aurora", aurora),
    ("contours", contours),
    ("isogrid", isogrid),
    ("rings", rings),
    ("halftone", halftone),
    ("waves", waves),
    ("rays", rays),
    ("strata", strata),
    ("monogram", monogram),
)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE.parent / "system/usr/share/backgrounds/Floatblue"
    w = int(sys.argv[2]) if len(sys.argv) > 2 else 2560
    h = int(sys.argv[3]) if len(sys.argv) > 3 else 1440
    out.mkdir(parents=True, exist_ok=True)

    if not LOGO.is_file():
        sys.exit(f"error: logo not found at {LOGO}")

    total = 0
    for name, fn in PATTERNS:
        for light in (True, False):
            suffix = "light" if light else "dark"
            img = fn((w, h), light)
            path = out / f"{name}_{suffix}.jpg"
            img.save(path, "JPEG", quality=88, optimize=True, progressive=True)
            kb = path.stat().st_size // 1024
            total += kb
            print(f"  {path.name:26} {w}x{h}  {kb} KB")
    print(f"{len(PATTERNS) * 2} wallpapers, {total} KB total, in {out}")


if __name__ == "__main__":
    main()
