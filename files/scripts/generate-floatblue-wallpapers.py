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

# ------------------------------------------------------------------ palettes
#
# These used to be module-level constants: one blue, for every wallpaper. That gave
# nine wallpapers that were nine arrangements of the same colour, and a desktop
# where changing the background never changed anything you could name afterwards.
#
# Each palette fills the same thirteen slots, so a pattern neither knows nor cares
# which one it draws with. The slots are not decorative. DEEP/DARK_BG/DARK_BG2 and
# LIGHT_BG/LIGHT_BG2 are the backgrounds the shapes sit on, INK is the dark linework,
# and the seven upper ones are shape colours roughly from most saturated to softest.
# A palette that gets that relationship wrong reads as mud rather than as a colour,
# which is the thing to avoid here.
#
# Raspberry Pi Foundation's raspberry red is #C51A4A. It anchors the prismatic
# palette below rather than being a shade invented for this, and the rest of that
# palette is a hue rotation away from it.
class Palette:
    __slots__ = ("name", "accent", "azure", "royal", "indigo", "violet", "cyan",
                 "soft", "deep", "dark_bg", "dark_bg2", "light_bg", "light_bg2",
                 "ink", "rainbow")

    def __init__(self, name, accent, azure, royal, indigo, violet, cyan, soft,
                 deep, dark_bg, dark_bg2, light_bg, light_bg2, ink,
                 rainbow=False):
        self.name = name
        # rainbow=True means the background is a real hue sweep rather than a
        # gradient between two shades of one colour. See spectrum().
        self.rainbow = rainbow
        self.accent, self.azure, self.royal, self.indigo = accent, azure, royal, indigo
        self.violet, self.cyan, self.soft = violet, cyan, soft
        self.deep, self.dark_bg, self.dark_bg2 = deep, dark_bg, dark_bg2
        self.light_bg, self.light_bg2, self.ink = light_bg, light_bg2, ink


def _palette(name, accent, deep, dark_bg, dark_bg2, light_bg, light_bg2,
             azure=None, royal=None, indigo=None, violet=None, cyan=None,
             soft=None, ink=None, rainbow=False):
    """Build a palette whose shape colours are derived when not given.

    Every palette below gives its own shape colours, because a hand-picked ramp is
    what keeps a hue from turning into grey. The defaults here exist so a new
    palette needs three lines instead of thirteen.
    """
    def lighten(c, f):
        return tuple(min(255, round(v + (255 - v) * f)) for v in c)

    accent = accent
    return Palette(
        name,
        accent=accent,
        azure=azure or lighten(accent, 0.12),
        royal=royal or tuple(round(v * 0.76) for v in accent),
        indigo=indigo or tuple(round(v * 0.42) for v in accent),
        violet=violet or tuple(min(255, round(v * 0.72 + 60)) for v in accent),
        cyan=cyan or lighten(accent, 0.42),
        soft=soft or lighten(accent, 0.68),
        deep=deep, dark_bg=dark_bg, dark_bg2=dark_bg2,
        light_bg=light_bg, light_bg2=light_bg2,
        ink=ink or tuple(round(v * 0.2) for v in deep), rainbow=rainbow)


# Flat Remix GTK-Blue, unchanged. This is the desktop's own accent, so it stays the
# one palette guaranteed to look deliberate against the theme.
BLUE = _palette(
    "blue", (0x27, 0x77, 0xFF),
    deep=(0x08, 0x0E, 0x30), dark_bg=(0x14, 0x1E, 0x5E), dark_bg2=(0x24, 0x25, 0x86),
    light_bg=(0xC2, 0xDC, 0xFF), light_bg2=(0x7C, 0xB0, 0xFF),
    azure=(0x2E, 0x7C, 0xFF), royal=(0x1B, 0x4D, 0xE8), indigo=(0x24, 0x1C, 0x8F),
    violet=(0x5B, 0x3D, 0xE8), cyan=(0x3A, 0xC2, 0xFB), soft=(0x74, 0xAE, 0xFF),
    ink=(0x0C, 0x14, 0x3E))

RASPBERRY = _palette(
    "raspberry", (0xC5, 0x1A, 0x4A),
    deep=(0x2A, 0x05, 0x14), dark_bg=(0x5A, 0x0C, 0x2C), dark_bg2=(0x8C, 0x14, 0x42),
    light_bg=(0xFF, 0xD9, 0xE2), light_bg2=(0xF2, 0x8E, 0xAA),
    azure=(0xE0, 0x3C, 0x63), royal=(0x9E, 0x12, 0x3C), indigo=(0x5C, 0x0E, 0x3C),
    violet=(0xB0, 0x2E, 0x8C), cyan=(0xFF, 0x6E, 0x8A), soft=(0xFF, 0xA8, 0xBC),
    ink=(0x33, 0x03, 0x12))

EMBER = _palette(
    "ember", (0xE8, 0x5A, 0x14),
    deep=(0x2B, 0x0D, 0x03), dark_bg=(0x5E, 0x22, 0x06), dark_bg2=(0x96, 0x3C, 0x0C),
    light_bg=(0xFF, 0xE3, 0xC4), light_bg2=(0xF6, 0xAE, 0x63),
    azure=(0xF5, 0x8A, 0x2E), royal=(0xC4, 0x3E, 0x08), indigo=(0x6E, 0x22, 0x06),
    violet=(0xD9, 0x3F, 0x4A), cyan=(0xFF, 0xC2, 0x59), soft=(0xFF, 0xD9, 0x9C),
    ink=(0x33, 0x11, 0x02))

AMBER = _palette(
    "amber", (0xF0, 0xA8, 0x12),
    deep=(0x2B, 0x1C, 0x02), dark_bg=(0x5F, 0x40, 0x06), dark_bg2=(0x96, 0x6C, 0x0E),
    light_bg=(0xFF, 0xF2, 0xD2), light_bg2=(0xF3, 0xC6, 0x5E),
    azure=(0xFF, 0xC9, 0x3C), royal=(0xC9, 0x82, 0x06), indigo=(0x6B, 0x46, 0x04),
    violet=(0xE0, 0x7A, 0x1E), cyan=(0xFF, 0xE6, 0x8A), soft=(0xFF, 0xF0, 0xBE),
    ink=(0x33, 0x22, 0x03))

EMERALD = _palette(
    "emerald", (0x18, 0xA8, 0x58),
    deep=(0x03, 0x24, 0x18), dark_bg=(0x08, 0x4E, 0x30), dark_bg2=(0x10, 0x7A, 0x4A),
    light_bg=(0xD2, 0xF5, 0xE0), light_bg2=(0x86, 0xD6, 0xA8),
    azure=(0x2C, 0xC8, 0x74), royal=(0x0E, 0x84, 0x44), indigo=(0x08, 0x4C, 0x3C),
    violet=(0x22, 0xA0, 0x84), cyan=(0x5C, 0xE8, 0xA8), soft=(0x9A, 0xF0, 0xC6),
    ink=(0x04, 0x2A, 0x1C))

LIME = _palette(
    "lime", (0x6E, 0xC2, 0x0E),
    deep=(0x18, 0x26, 0x03), dark_bg=(0x33, 0x54, 0x08), dark_bg2=(0x55, 0x86, 0x10),
    light_bg=(0xEC, 0xF9, 0xD6), light_bg2=(0xB8, 0xE4, 0x7C),
    azure=(0x94, 0xDC, 0x38), royal=(0x4E, 0x92, 0x08), indigo=(0x2E, 0x52, 0x06),
    violet=(0x54, 0xB0, 0x2E), cyan=(0xC2, 0xEE, 0x7A), soft=(0xDC, 0xF7, 0xB0),
    ink=(0x1C, 0x2C, 0x04))

TEAL = _palette(
    "teal", (0x0E, 0xA5, 0x9E),
    deep=(0x02, 0x22, 0x28), dark_bg=(0x06, 0x48, 0x50), dark_bg2=(0x0C, 0x72, 0x7E),
    light_bg=(0xD2, 0xF2, 0xF4), light_bg2=(0x82, 0xCE, 0xD4),
    azure=(0x22, 0xC4, 0xBC), royal=(0x0A, 0x82, 0x7C), indigo=(0x06, 0x4A, 0x54),
    violet=(0x18, 0x8C, 0xB8), cyan=(0x5A, 0xE2, 0xE2), soft=(0xA8, 0xEC, 0xEE),
    ink=(0x03, 0x28, 0x2E))

VIOLET = _palette(
    "violet", (0x7A, 0x3C, 0xE8),
    deep=(0x18, 0x08, 0x38), dark_bg=(0x30, 0x18, 0x6C), dark_bg2=(0x4C, 0x28, 0x9E),
    light_bg=(0xE8, 0xDC, 0xFC), light_bg2=(0xB4, 0x96, 0xEC),
    azure=(0x9A, 0x62, 0xF5), royal=(0x5A, 0x26, 0xC4), indigo=(0x36, 0x18, 0x72),
    violet=(0xA0, 0x3C, 0xD8), cyan=(0xC8, 0x8C, 0xF8), soft=(0xDE, 0xC0, 0xFC),
    ink=(0x1C, 0x0C, 0x3E))

# Raspberry red rotated through the whole wheel. Every slot here is a genuine
# different hue rather than a tint of one, and that is the difference between a
# rainbow and a single colour that got lighter in places.
PRISMATIC = _palette(
    "prismatic", (0xE8, 0x1C, 0x3C),
    deep=(0x14, 0x04, 0x2E), dark_bg=(0x2E, 0x0C, 0x52), dark_bg2=(0x50, 0x14, 0x7E),
    light_bg=(0xF6, 0xE8, 0xF8), light_bg2=(0xC0, 0x9A, 0xE8),
    azure=(0xF0, 0x8A, 0x12), royal=(0xE8, 0xC8, 0x0C), indigo=(0x1C, 0xA8, 0x4A),
    violet=(0x18, 0x8C, 0xC8), cyan=(0x6A, 0x3C, 0xE0), soft=(0xF0, 0x6E, 0xA8),
    ink=(0x1A, 0x06, 0x30), rainbow=True)

# One palette per pattern, deliberately not rotated round the list. Repeating a
# colour across two patterns is what makes a set look chosen rather than sampled,
# and it also means the two light and two dark variants of neighbouring patterns
# are not all fighting each other on screen.
PALETTES = (
    BLUE, RASPBERRY, EMERALD, PRISMATIC,
    AMBER, TEAL, VIOLET, EMBER, LIME,
)

HERE = Path(__file__).resolve().parent
LOGO = HERE.parent / "branding" / "floatos-logo.png"

SEED = 20261001


# --------------------------------------------------------------------------- helpers

# The palette the generator is currently drawing with. Set by main() before each
# wallpaper. A module-level one rather than a parameter because gradient() is
# called from inside every pattern and threading a palette through all nine would
# have been nine edits for no gain; the generator is strictly sequential, so there
# is nothing to race against.
_PALETTE = None


def set_palette(pal):
    global _PALETTE
    _PALETTE = pal


def hsv_to_rgb(h, s, v):
    """h in degrees, s and v in 0..1. Standard HSV, no external colour library."""
    h = (h % 360.0) / 60.0
    c = v * s
    x = c * (1.0 - abs(h % 2.0 - 1.0))
    m = v - c
    if h < 1:   r, g, b = c, x, 0.0
    elif h < 2: r, g, b = x, c, 0.0
    elif h < 3: r, g, b = 0.0, c, x
    elif h < 4: r, g, b = 0.0, x, c
    elif h < 5: r, g, b = x, 0.0, c
    else:        r, g, b = c, 0.0, x
    return tuple((channel + m) for channel in (r, g, b))


# Raspberry Pi Foundation's raspberry red, #C51A4A, as a hue in degrees. It is the
# anchor the spectrum starts from rather than a tint invented here: 338 degrees is
# where that red sits on the wheel, so sweeping the wheel from it puts raspberry
# where it belongs instead of parking red somewhere arbitrary.
PI_RASPBERRY_HUE = 338.0


def spectrum(size, light, *, turns=0.85, saturation=0.68, value=0.94):
    """A real hue sweep, as opposed to a single hue made paler in places.

    This is what a rainbow wallpaper actually needs. A palette that only recolours
    the shapes leaves a one-note background no matter how many hues it holds, which
    is what the prismatic palette looked like before this existed: nine different
    colours in the shapes and a flat violet wall behind all of them.

    The sweep runs mostly horizontally, because a vertical one reads as a colour
    cast at the top of the screen and a horizontal one reads as a spectrum, and it
    carries a little diagonal drift so the bands are not dead straight. Value and
    saturation drop towards the dark variant so the shapes sitting on top still
    have something to sit against.
    """
    w, h = size
    xs = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :]
    ys = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]

    # Diagonal drift, and the hue runs most of the way round the wheel. Not the
    # whole way: a full 360 across the width puts the same hue at both edges, and
    # the seam where they meet is plainly visible as a band in the corner.
    sweep = xs + ys * 0.18
    hue = (PI_RASPBERRY_HUE + sweep * 360.0 * turns).astype(np.float32)
    hue = np.repeat(hue, h, axis=0)[:h, :w]

    if light:
        # The light variant was washed out at the first pass: dropping saturation
        # for a pale background is backwards, because the shapes on top are the
        # pale part. Saturation stays high and only the value comes down.
        s, v = saturation, min(1.0, value * 0.88)
    else:
        s, v = saturation, value * 0.55

    c = v * s
    hp = hue / 60.0
    x = c * (1.0 - np.abs(hp % 2.0 - 1.0))
    m = v - c
    seg = np.floor(hp) % 6

    r = np.select([seg == 0, seg == 1, seg == 2, seg == 3, seg == 4, seg == 5],
                  [c, x, 0.0, 0.0, x, c]) + m
    g = np.select([seg == 0, seg == 1, seg == 2, seg == 3, seg == 4, seg == 5],
                  [x, c, c, 0.0, 0.0, x]) + m
    b = np.select([seg == 0, seg == 1, seg == 2, seg == 3, seg == 4, seg == 5],
                  [0.0, 0.0, x, c, c, x]) + m

    arr = np.stack([r, g, b], axis=-1)
    return Image.fromarray(np.clip(arr * 255.0, 0, 255).astype(np.uint8), "RGB")


def gradient(size, top, bottom):
    """Vertical linear gradient as an RGB image.

    A palette flagged rainbow gets the spectrum instead. That flag is the only
    difference between "this wallpaper has nine colours in it" and "this wallpaper
    is actually a rainbow", and keeping it here means every pattern gets the
    behaviour without each one having to ask for it.
    """
    if _PALETTE is not None and _PALETTE.rainbow:
        return spectrum(size, _LIGHT[0])
    w, h = size
    ramp = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
    top = np.array(top, dtype=np.float32)
    bottom = np.array(bottom, dtype=np.float32)
    rows = top[None, :] * (1 - ramp) + bottom[None, :] * ramp
    arr = np.repeat(rows[:, None, :], w, axis=1)
    return Image.fromarray(arr.astype(np.uint8), "RGB")


# Set alongside the palette, because a rainbow gradient needs to know which
# variant it is drawing: the light and dark sweeps are not the same image with the
# brightness pulled down, they are weighted differently so the shapes read on both.
_LIGHT = [False]


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

def aurora(size, light, pal):
    """Soft overlapping glows, like light through water."""
    w, h = size
    img = gradient(size, pal.light_bg2 if light else pal.deep, pal.light_bg if light else pal.dark_bg2)
    blobs = [
        (0.28, 0.32, 0.62, pal.accent, 0.55),
        (0.74, 0.24, 0.48, pal.soft, 0.42),
        (0.55, 0.78, 0.55, pal.cyan if not light else pal.violet, 0.38),
        (0.88, 0.72, 0.38, pal.violet if not light else pal.royal, 0.30),
        (0.12, 0.80, 0.42, pal.cyan if not light else pal.violet, 0.24),
    ]
    for cx, cy, rad, colour, strength in blobs:
        m = radial_mask(size, w * cx, h * cy, w * rad, falloff=2.4) * strength
        img = tint(img, colour, m)
    img = img.filter(ImageFilter.GaussianBlur(radius=w / 90))
    return paste_logo(img, int(h * 0.17), centre=True, opacity=0.14 if light else 0.20)


def contours(size, light, pal):
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

    img = gradient(size, pal.light_bg if light else pal.deep, pal.light_bg2 if light else pal.dark_bg)
    img = tint(img, pal.royal if light else pal.azure, soft * (0.80 if light else 0.80))
    return paste_logo(img, int(h * 0.13), tile=1, opacity=0.16)

def isogrid(size, light, pal):
    """Isometric lattice, the graph paper you get in a 3D editor."""
    w, h = size
    img = gradient(size, pal.light_bg2 if light else pal.dark_bg2, pal.light_bg if light else pal.deep)

    # Tint before drawing. Painting the glow on top wiped the lines out of the
    # middle and left what looked like plain moire in the corners.
    glow = radial_mask(size, w * 0.42, h * 0.38, w * 0.72, 1.9)
    img = tint(img, pal.violet if not light else pal.light_bg, glow * (0.34 if not light else 0.40))

    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    line = pal.soft if light else pal.cyan
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

def rings(size, light, pal):
    """Concentric circles from an off-centre origin, thinning outward."""
    w, h = size
    img = gradient(size, pal.light_bg2 if light else pal.deep, pal.light_bg if light else pal.dark_bg2)
    cx, cy = w * 0.68, h * 0.34

    glow = radial_mask(size, cx, cy, w * 0.8, 1.9)
    img = tint(img, pal.violet if not light else pal.light_bg, glow * (0.30 if not light else 0.42))

    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    colour = pal.cyan if not light else pal.royal
    for i in range(1, 28):
        r = i * w * 0.046
        a = int((230 if not light else 190) * (1 - i / 34))
        width = 3 if i % 5 == 0 else 1
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=colour + (a,), width=width)
    img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    return paste_logo(img, int(h * 0.22), centre=True, opacity=0.20 if light else 0.26)

def halftone(size, light, pal):
    """Dot matrix whose radius swells towards a focus point."""
    w, h = size
    img = gradient(size, pal.light_bg2 if light else pal.dark_bg, pal.light_bg if light else pal.deep)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = max(14, w // 96)
    fx, fy = w * 0.62, h * 0.44
    colour = pal.royal if light else pal.azure
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


def waves(size, light, pal):
    """Stacked sine lines, drifting out of phase."""
    w, h = size
    img = gradient(size, pal.light_bg if light else pal.dark_bg2, pal.light_bg2 if light else pal.deep)
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
        d.line(pts, fill=(pal.azure if light else pal.cyan) + (a,), width=2, joint="curve")
    img = Image.alpha_composite(img.convert("RGBA"), layer.filter(ImageFilter.GaussianBlur(0.6))).convert("RGB")
    return paste_logo(img, int(h * 0.14), at=(int(w * 0.72), int(h * 0.10)), opacity=0.16)


def rays(size, light, pal):
    """Radial burst from just below the bottom edge."""
    w, h = size
    img = gradient(size, pal.light_bg2 if light else pal.dark_bg2, pal.light_bg if light else pal.deep)
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
            fill=pal.accent + (a,),
            width=int(w / 300) + 1,
        )
    img = Image.alpha_composite(img.convert("RGBA"), layer.filter(ImageFilter.GaussianBlur(1.6))).convert("RGB")

    glow = radial_mask(size, cx, h * 0.78, w * 0.8, 1.8)
    img = tint(img, pal.soft if not light else pal.light_bg, glow * (0.30 if light else 0.34))
    return paste_logo(img, int(h * 0.24), centre=True, opacity=0.16 if light else 0.24)

def strata(size, light, pal):
    """Layered horizon silhouettes, quiet and mostly empty at the top."""
    w, h = size
    img = gradient(size, pal.light_bg if light else pal.dark_bg2, pal.light_bg2 if light else pal.deep)

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
        col = pal.indigo if light else (0x0B, 0x12, 0x40)
        d.polygon(pts, fill=col + (int(255 * (shade + 0.30)),))
    img = Image.alpha_composite(img.convert("RGBA"), layer.filter(ImageFilter.GaussianBlur(0.7))).convert("RGB")

    glow = radial_mask(size, w * 0.5, h * 0.52, w * 0.48, 2.6)
    img = tint(img, pal.soft if not light else pal.light_bg, glow * (0.22 if light else 0.28))
    return paste_logo(img, int(h * 0.13), at=(int(w * 0.08), int(h * 0.12)), opacity=0.17)


def monogram(size, light, pal):
    """A hairline grid with the mark tiled across it as a watermark."""
    w, h = size
    img = gradient(size, pal.light_bg2 if light else pal.deep, pal.light_bg if light else pal.dark_bg2)

    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = int(w / 40)
    grid = pal.accent + (26 if light else 34,)
    for x in range(0, w + step, step):
        d.line([(x, 0), (x, h)], fill=grid, width=1)
    for y in range(0, h + step, step):
        d.line([(0, y), (w, y)], fill=grid, width=1)
    img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")

    glow = radial_mask(size, w * 0.5, h * 0.5, w * 0.62, 1.7)
    img = tint(img, pal.light_bg if light else (0x10, 0x15, 0x2C), glow * (0.45 if light else 0.42))
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

    if len(PALETTES) < len(PATTERNS):
        sys.exit(f"error: {len(PATTERNS)} patterns but only {len(PALETTES)} palettes")

    total = 0
    for (name, fn), pal in zip(PATTERNS, PALETTES):
        set_palette(pal)
        for light in (True, False):
            suffix = "light" if light else "dark"
            _LIGHT[0] = light
            img = fn((w, h), light, pal)
            path = out / f"{name}_{suffix}.jpg"
            img.save(path, "JPEG", quality=88, optimize=True, progressive=True)
            kb = path.stat().st_size // 1024
            total += kb
            print(f"  {path.name:26} {pal.name:10} {w}x{h}  {kb} KB")
    print(f"{len(PATTERNS) * 2} wallpapers, {total} KB total, in {out}")


if __name__ == "__main__":
    main()
