#!/usr/bin/env python3
"""Generate the Firewatch collection of wallpapers.

Firewatch's look is not a gradient with noise in it, and treating it as one is the
usual way this comes out wrong. What makes it recognisable:

  * Colour arrives in flat bands. The sky in that game is a stack of hard-edged
    horizontal shapes, not a smooth ramp, and smoothing them is what turns the
    whole thing into generic wallpaper. Everything here is posterised at the end
    for exactly that reason, and the band count is deliberately small.
  * Depth comes from layered silhouettes, not perspective. Each ridge is one flat
    colour, and distance is carried by the colour getting lighter and hazier, so a
    far ridge sits behind a near one with no outline and no detail on either.
  * There is one hot accent per scene, almost always the sun or a fire, and the
    rest of the palette stays cold so the accent carries the eye.
  * Trees are silhouette shapes. A conifer is stacked triangles and a birch is a
    pale trunk with a sparse crown, because that is all you can see of either one
    against the sky at this scale.

Scenes are written as horizon, sky, accent, then terrain, because that is the order
the eye reads them in and it keeps each scene short.

Every scene renders a light and a dark variant. Not a brightness filter over the
same image: the dark variant is a different palette with the accent moved to the
fire, the way the game does it at night.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
SEED = 20261001

# Levels per channel after posterising. Six is close to the game's flat-colour
# count; higher and the banding stops reading as deliberate.
BANDS = 6


# --------------------------------------------------------------------- colour

def hsv(h, s, v):
    """h in degrees, s and v in 0..1, to an integer RGB triple."""
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
    return tuple(int(round((ch + m) * 255)) for ch in (r, g, b))


def mix(a, b, f):
    return tuple(int(round(a[i] + (b[i] - a[i]) * f)) for i in range(3))


# ------------------------------------------------------------------- painting

def vgrad(size, stops):
    """Multi-stop vertical gradient. stops is [(position 0..1, rgb), ...]."""
    w, h = size
    ys = np.linspace(0.0, 1.0, h, dtype=np.float32)
    out = np.zeros((h, 3), dtype=np.float32)
    stops = sorted(stops, key=lambda s: s[0])
    for i in range(len(stops) - 1):
        p0, c0 = stops[i]
        p1, c1 = stops[i + 1]
        m = (ys >= p0) & (ys <= p1)
        if not m.any():
            continue
        f = ((ys[m] - p0) / max(p1 - p0, 1e-6)).astype(np.float32)[:, None]
        out[m] = np.array(c0, np.float32) * (1 - f) + np.array(c1, np.float32) * f
    out[ys < stops[0][0]] = stops[0][1]
    out[ys > stops[-1][0]] = stops[-1][1]
    return np.repeat(out[:, None, :], w, axis=1)


def posterize(arr, bands=BANDS):
    """Snap to flat bands. The single most important step for this look."""
    q = 255.0 / (bands - 1)
    return np.clip(np.round(arr / q) * q, 0, 255).astype(np.uint8)


def ridge_points(w, y0, amp, freq, seed, octaves=4, tilt=0.0):
    """A silhouette skyline: summed sines, so it never repeats visibly."""
    rng = np.random.default_rng(seed)
    xs = np.linspace(0.0, 1.0, w, dtype=np.float32)
    ys = np.full(w, y0, dtype=np.float32)
    for k in range(octaves):
        f = freq * (2 ** k)
        ys += (amp / (k + 1.4)) * np.sin(
            2 * np.pi * f * xs + rng.uniform(0, 2 * np.pi)).astype(np.float32)
    ys += tilt * (xs - 0.5) * w * 0.02
    return ys


def draw_ridge(draw, w, h, points, colour):
    poly = [(int(x), int(y)) for x, y in enumerate(points)]
    poly += [(w, h + 10), (0, h + 10)]
    draw.polygon(poly, fill=colour)


def conifer(draw, x, base, ht, colour, rng):
    """A spruce silhouette: stacked triangles narrowing to the top."""
    tiers = rng.integers(4, 7)
    for i in range(tiers):
        f = i / max(tiers - 1, 1)
        top = base - ht * (0.28 + 0.72 * f)
        bot = base - ht * (0.62 * f)
        half = ht * (0.30 - 0.17 * f) * rng.uniform(0.86, 1.14)
        draw.polygon([(x, top), (x - half, bot), (x + half, bot)], fill=colour)
    draw.rectangle([x - ht * 0.018, base - ht * 0.10, x + ht * 0.018, base],
                   fill=colour)


def birch(draw, x, base, ht, bark, crown, rng, edge=None):
    """A birch: pale slender trunk, dark bark marks, sparse crown.

    edge is a one-pixel-darker pass drawn under the trunk. It is not decoration.
    Birch bark really is near-white, and near-white on the pale sky of a light
    variant is invisible: the first light-mode pass drew exactly that and the
    grove came out as a few floating leaves with no trunks at all. Drawing the
    silhouette a little wider first and the pale bark over it gives the outline
    that separates white from white.
    """
    tw = max(1, int(ht * 0.016))
    lean = rng.uniform(-0.035, 0.035) * ht

    def trunk(half, colour):
        draw.polygon([(x - half, base), (x + half, base),
                      (x + half + lean, base - ht), (x - half + lean, base - ht)],
                     fill=colour)

    if edge:
        trunk(tw + max(1, int(ht * 0.004)), edge)
    trunk(tw, bark)
    for _ in range(rng.integers(3, 7)):
        my = base - ht * rng.uniform(0.12, 0.82)
        mx = x + lean * (1 - (base - my) / ht) + rng.uniform(-tw, tw)
        mw = tw * rng.uniform(0.7, 1.5)
        draw.rectangle([mx - mw, my, mx + mw, my + max(1, ht * 0.012)], fill=crown)
    # Sparse canopy: a few overlapping blobs, not a solid oval.
    for _ in range(rng.integers(3, 6)):
        cx = x + lean + rng.uniform(-ht * 0.16, ht * 0.16)
        cy = base - ht * rng.uniform(0.74, 1.0)
        rx = ht * rng.uniform(0.07, 0.14)
        ry = ht * rng.uniform(0.05, 0.10)
        draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=crown)


def sun(draw, cx, cy, r, colour, glow=None):
    if glow:
        draw.ellipse([cx - r * 2.6, cy - r * 2.6, cx + r * 2.6, cy + r * 2.6], fill=glow)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour)


def stars(draw, size, n, seed, colour, ymax=0.62):
    rng = np.random.default_rng(seed)
    w, h = size
    for _ in range(n):
        x = int(rng.uniform(0, w))
        y = int(rng.uniform(0, h * ymax))
        r = 1 if rng.random() > 0.22 else 2
        draw.ellipse([x - r, y - r, x + r, y + r], fill=colour)


def glow_field(size, cx, cy, radius, colour, strength=0.5):
    """A soft radial wash. Applied before posterising so it bands like everything."""
    w, h = size
    xs = np.arange(w, dtype=np.float32)[None, :]
    ys = np.arange(h, dtype=np.float32)[:, None]
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / max(radius, 1e-6)
    m = np.clip(1.0 - d, 0.0, 1.0) ** 2.2 * strength
    return np.clip(m * 255, 0, 255).astype(np.float32)


# --------------------------------------------------------------------- scenes
#
# Each returns a float32 RGB array before posterising.

def _frame(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def pine_ridge(size, light):
    w, h = size
    horizon = h * 0.66
    if light:
        sky = vgrad(size, [(0.0, hsv(206, .55, .92)), (0.45, hsv(196, .45, .86)),
                           (0.72, hsv(38, .70, .96)), (1.0, hsv(30, .82, .90))])
        layers = [(hsv(200, .40, .70), .34, 1.5, 0.72), (hsv(202, .48, .55), .26, 2.6, 0.78),
                  (hsv(204, .55, .40), .20, 4.0, 0.86), (hsv(206, .58, .26), .15, 6.5, 0.94)]
        accent = hsv(44, .92, 1.0)
    else:
        sky = vgrad(size, [(0.0, hsv(232, .70, .40)), (0.45, hsv(224, .60, .52)),
                           (0.78, hsv(268, .48, .62)), (1.0, hsv(300, .55, .52))])
        layers = [(hsv(226, .34, .44), .30, 1.5, 0.74), (hsv(228, .40, .32), .24, 2.6, 0.80),
                  (hsv(230, .46, .21), .18, 4.0, 0.88), (hsv(232, .50, .12), .13, 6.5, 0.96)]
        accent = hsv(18, .96, 1.0)

    img = Image.fromarray(sky.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    if not light:
        stars(d, size, 90, SEED + 1, hsv(210, .20, .95))
    sun(d, w * 0.70, horizon - h * 0.10, min(w, h) * 0.062, accent)
    for i, (col, amp, freq, base_f) in enumerate(layers):
        pts = ridge_points(w, horizon + h * (0.02 + 0.10 * i),
                           h * amp * 0.30, freq, SEED + 10 + i)
        draw_ridge(d, w, h, pts, col)
    rng = np.random.default_rng(SEED + 5)
    for _ in range(46):
        x = int(rng.uniform(0, w))
        b = h * 1.02
        conifer(d, x, b, h * rng.uniform(0.10, 0.26), layers[-1][0], rng)
    return posterize(np.asarray(img, dtype=np.float32))


def pine_forest(size, light):
    """Tall trunks in the near ground, ridges showing through the gaps."""
    w, h = size
    horizon = h * 0.58
    if light:
        sky = vgrad(size, [(0.0, hsv(200, .48, .88)), (0.6, hsv(192, .40, .84)),
                           (1.0, hsv(34, .62, .92))])
        far = [hsv(196, .34, .66), hsv(198, .42, .52), hsv(200, .48, .38)]
        near = hsv(202, .55, .22)
    else:
        sky = vgrad(size, [(0.0, hsv(230, .64, .34)), (0.6, hsv(222, .54, .46)),
                           (1.0, hsv(276, .44, .56))])
        far = [hsv(226, .30, .40), hsv(228, .36, .28), hsv(230, .42, .18)]
        near = hsv(232, .48, .09)

    img = Image.fromarray(sky.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    if not light:
        stars(d, size, 70, SEED + 2, hsv(215, .18, .92))
    for i, col in enumerate(far):
        pts = ridge_points(w, horizon + h * 0.06 * i, h * 0.05, 2.0 + i * 1.6, SEED + 30 + i)
        draw_ridge(d, w, h, pts, col)
    rng = np.random.default_rng(SEED + 31)
    # Three depth passes, so the stand has air in it rather than being a hedge.
    #
    # Heights are a fraction of the frame and the bases sit near the bottom edge,
    # which is the whole reason the sky is visible at all. The first version added
    # a flat h * .18 to every tree on top of a range that already reached .95h, so
    # the tallest were 113% of the frame height and 73 of them filled the picture
    # edge to edge in near-black.
    for scale, col, count in ((0.30, far[-1], 26), (0.46, near, 16), (0.66, near, 10)):
        for _ in range(count):
            x = int(rng.uniform(-w * .02, w * 1.02))
            conifer(d, x, h * (1.02 + rng.uniform(0, .03)),
                    h * rng.uniform(.20, .34) * (scale / 0.66 + .55), col, rng)
    return posterize(np.asarray(img, dtype=np.float32))


def birch_grove(size, light):
    w, h = size
    horizon = h * 0.70
    if light:
        sky = vgrad(size, [(0.0, hsv(48, .40, .96)), (0.5, hsv(42, .48, .92)),
                           (1.0, hsv(196, .34, .88))])
        bark = hsv(44, .12, .99)
        crown = hsv(84, .34, .78)
        far = [hsv(96, .26, .74), hsv(92, .32, .62)]
        # The grove is darker than the sky, so the pale trunks read against it.
        outline = hsv(24, .46, .34)
    else:
        sky = vgrad(size, [(0.0, hsv(226, .52, .42)), (0.5, hsv(240, .44, .52)),
                           (1.0, hsv(268, .40, .56))])
        bark = hsv(210, .10, .92)
        crown = hsv(150, .28, .40)
        far = [hsv(168, .24, .44), hsv(172, .30, .32)]
        outline = hsv(210, .30, .16)

    img = Image.fromarray(sky.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    if not light:
        stars(d, size, 80, SEED + 3, hsv(220, .16, .92))
    sun(d, w * 0.26, horizon - h * 0.16, min(w, h) * 0.055,
        hsv(52, .90, 1.0) if light else hsv(14, .92, 1.0))
    # Kept low and given real amplitude. Sitting them at the horizon with 0.035h of
    # relief put a near-straight edge straight across the middle of the crowns.
    for i, col in enumerate(far):
        pts = ridge_points(w, horizon + h * (0.10 + 0.07 * i), h * 0.075,
                           1.6 + i * 1.9, SEED + 40 + i)
        draw_ridge(d, w, h, pts, col)
    rng = np.random.default_rng(SEED + 41)
    # 26 birches at 0.62 to 0.94h with a trunk 3.5% of that width filled the frame
    # and read as a barcode. Fewer, shorter, and the trunk narrows with height.
    for _ in range(13):
        x = int(rng.uniform(0, w))
        # Bases scattered around the bottom edge instead of all on one line, so the
        # grove has depth rather than reading as a row of stamps.
        birch(d, x, h * rng.uniform(0.94, 1.04), h * rng.uniform(0.40, 0.62), 
              bark, crown, rng, edge=outline)
    for _ in range(7):
        x = int(rng.uniform(0, w))
        birch(d, x, h * rng.uniform(0.92, 1.04), h * rng.uniform(0.22, 0.34), 
              bark, crown, rng, edge=outline)
    return posterize(np.asarray(img, dtype=np.float32))


def taiga(size, light):
    """The in-between forest: spruce and birch mixed, low sun, cold palette."""
    w, h = size
    horizon = h * 0.62
    if light:
        # Hue 214 at the top posterised to a flat lavender band that looked like a
        # mistake rather than a band. 202 keeps it blue but lands on a colour that
        # survives the posterise.
        sky = vgrad(size, [(0.0, hsv(202, .46, .82)), (0.35, hsv(200, .38, .86)),
                           (0.70, hsv(196, .30, .88)), (1.0, hsv(30, .58, .90))])
        bark = hsv(40, .10, .98)
        far = [hsv(150, .26, .66), hsv(146, .32, .52)]
        near = hsv(158, .40, .30)
        outline = hsv(196, .40, .26)
    else:
        sky = vgrad(size, [(0.0, hsv(228, .58, .34)), (0.55, hsv(218, .48, .44)),
                           (1.0, hsv(282, .40, .52))])
        bark = hsv(212, .10, .86)
        far = [hsv(196, .26, .38), hsv(200, .32, .27)]
        near = hsv(204, .40, .14)
        outline = hsv(214, .34, .10)

    img = Image.fromarray(sky.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    if not light:
        stars(d, size, 110, SEED + 4, hsv(218, .18, .93), ymax=0.55)
    # Moved off the tree line. At 0.44 it sat behind the stand and the accent, the
    # one warm thing in a cold palette, was half hidden by it.
    sun(d, w * 0.78, horizon - h * 0.16, min(w, h) * 0.062,
        hsv(46, .94, 1.0) if light else hsv(20, .96, 1.0))
    for i, col in enumerate(far):
        pts = ridge_points(w, horizon + h * 0.04 * i, h * 0.04, 2.2 + i * 1.8, SEED + 50 + i)
        draw_ridge(d, w, h, pts, col)
    rng = np.random.default_rng(SEED + 51)
    for _ in range(16):
        x = int(rng.uniform(0, w))
        if rng.random() < 0.68:
            conifer(d, x, h * 1.02, h * rng.uniform(0.16, 0.30), near, rng)
        else:
            birch(d, x, h * rng.uniform(0.94, 1.04), h * rng.uniform(0.14, 0.26), 
                  bark, far[-1], rng, edge=outline)
    return posterize(np.asarray(img, dtype=np.float32))


def mountain_ridge(size, light):
    w, h = size
    horizon = h * 0.74
    if light:
        sky = vgrad(size, [(0.0, hsv(204, .52, .90)), (0.5, hsv(198, .44, .86)),
                           (1.0, hsv(40, .66, .96))])
        layers = [(hsv(198, .30, .78), .30, 1.2, 0.62), (hsv(200, .36, .64), .26, 1.8, 0.70),
                  (hsv(202, .44, .50), .22, 2.8, 0.80), (hsv(204, .50, .36), .18, 4.4, 0.90),
                  (hsv(206, .56, .24), .14, 6.0, 1.00)]
        accent = hsv(48, .94, 1.0)
    else:
        sky = vgrad(size, [(0.0, hsv(234, .66, .36)), (0.5, hsv(226, .56, .48)),
                           (1.0, hsv(292, .50, .56))])
        layers = [(hsv(222, .28, .46), .30, 1.2, 0.64), (hsv(226, .34, .36), .26, 1.8, 0.72),
                  (hsv(230, .40, .26), .22, 2.8, 0.82), (hsv(234, .46, .17), .18, 4.4, 0.92),
                  (hsv(238, .52, .09), .14, 6.0, 1.00)]
        accent = hsv(16, .96, 1.0)

    img = Image.fromarray(sky.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    if not light:
        stars(d, size, 130, SEED + 6, hsv(222, .16, .94))
    sun(d, w * 0.62, horizon - h * 0.13, min(w, h) * 0.070, accent)
    for i, (col, amp, freq, bf) in enumerate(layers):
        pts = ridge_points(w, horizon + h * 0.055 * i, h * amp * 0.34, freq,
                           SEED + 60 + i, tilt=(-1 if i % 2 else 1) * 0.6)
        draw_ridge(d, w, h, pts, col)
    return posterize(np.asarray(img, dtype=np.float32))


def field(size, light):
    w, h = size
    horizon = h * 0.56
    if light:
        sky = vgrad(size, [(0.0, hsv(202, .46, .90)), (0.5, hsv(46, .44, .94)),
                           (1.0, hsv(38, .58, .90))])
        bands = [hsv(74, .44, .80), hsv(84, .48, .72), hsv(94, .46, .62),
                 hsv(104, .42, .50), hsv(112, .38, .38)]
        accent = hsv(50, .92, 1.0)
    else:
        sky = vgrad(size, [(0.0, hsv(232, .62, .34)), (0.5, hsv(250, .48, .48)),
                           (1.0, hsv(300, .46, .52))])
        bands = [hsv(168, .28, .46), hsv(172, .32, .38), hsv(178, .30, .30),
                 hsv(184, .28, .22), hsv(190, .26, .15)]
        accent = hsv(18, .94, 1.0)

    img = Image.fromarray(sky.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    if not light:
        stars(d, size, 100, SEED + 7, hsv(224, .16, .93))
    sun(d, w * 0.34, horizon - h * 0.11, min(w, h) * 0.062, accent)
    # Rolling ground as flat swells, then the same shapes again in bands, which is
    # what makes it read as a field rather than as a hill.
    prev = h * 0.62
    for i, col in enumerate(bands):
        y0 = horizon + (h - horizon) * (0.10 + 0.22 * i)
        pts = ridge_points(w, y0, h * 0.035, 1.4 + i * 1.5, SEED + 70 + i, octaves=3)
        draw_ridge(d, w, h, pts, col)
        prev = y0
    rng = np.random.default_rng(SEED + 71)
    # A lone tree, because a field with nothing in it is a plain gradient.
    tx = int(w * 0.72)
    ty = h * 0.70
    conifer(d, tx, ty, h * 0.20, bands[-1], rng)
    conifer(d, tx - int(w * .035), ty + h * .01, h * 0.14, bands[-1], rng)
    return posterize(np.asarray(img, dtype=np.float32))


def ocean(size, light):
    """Open water. Flat horizontal bands and a glitter path under the sun."""
    w, h = size
    horizon = h * 0.52
    if light:
        sky = vgrad(size, [(0.0, hsv(200, .52, .90)), (0.6, hsv(192, .40, .88)),
                           (1.0, hsv(36, .66, .96))])
        sea = [hsv(196, .52, .72), hsv(198, .56, .62), hsv(200, .58, .52),
               hsv(202, .58, .42), hsv(204, .56, .32)]
        accent = hsv(46, .94, 1.0)
    else:
        sky = vgrad(size, [(0.0, hsv(232, .68, .32)), (0.6, hsv(224, .56, .44)),
                           (1.0, hsv(300, .52, .54))])
        sea = [hsv(224, .44, .40), hsv(226, .48, .32), hsv(228, .50, .25),
               hsv(230, .50, .18), hsv(232, .48, .11)]
        accent = hsv(18, .96, 1.0)

    img = Image.fromarray(sky.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    if not light:
        stars(d, size, 120, SEED + 8, hsv(224, .16, .94), ymax=0.44)
    sx = w * 0.58
    sun(d, sx, horizon - h * 0.10, min(w, h) * 0.075, accent)

    # The sea as hard bands, drawn as flat shapes rather than a gradient.
    for i, col in enumerate(sea):
        y0 = horizon + (h - horizon) * (i / len(sea))
        y1 = horizon + (h - horizon) * ((i + 1) / len(sea))
        d.rectangle([0, y0, w, y1], fill=col)
    # Glitter: short horizontal dashes on the sun's path, widening towards the
    # viewer. This is the whole reason the water reads as water.
    rng = np.random.default_rng(SEED + 81)
    for i in range(150):
        f = rng.random() ** 0.6
        y = horizon + (h - horizon) * (0.04 + 0.94 * f)
        spread = w * (0.02 + 0.16 * f)
        x = sx + rng.normal(0, spread)
        ln = w * rng.uniform(0.004, 0.020) * (0.4 + f)
        a = int(210 * (1 - f * 0.55))
        d.rectangle([x - ln, y, x + ln, y + max(1.0, h * 0.0022)],
                    fill=mix(accent, sea[-1], f * 0.55) + (a,))
    return posterize(np.asarray(img, dtype=np.float32))


def reef(size, light):
    """Underwater. Light shafts from above, everything below in silhouette."""
    w, h = size
    if light:
        water = vgrad(size, [(0.0, hsv(190, .58, .92)), (0.5, hsv(196, .62, .74)),
                             (1.0, hsv(204, .58, .50))])
        shafts = hsv(48, .70, 1.0)
        rock = [hsv(200, .40, .58), hsv(204, .46, .42), hsv(208, .48, .28)]
        far = hsv(206, .40, .46)
    else:
        water = vgrad(size, [(0.0, hsv(206, .66, .52)), (0.5, hsv(214, .62, .34)),
                             (1.0, hsv(222, .58, .18))])
        shafts = hsv(196, .55, .95)
        rock = [hsv(212, .40, .34), hsv(218, .46, .22), hsv(224, .48, .12)]
        far = hsv(220, .40, .26)

    arr = water.copy()
    img = Image.fromarray(arr.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    # Shafts: wide at the top, converging, fading out with depth.
    #
    # Computed rather than drawn. Two earlier versions used PIL polygons with an
    # alpha byte, and on an RGB image PIL drops that byte, so the shafts came out
    # as opaque slabs of colour; adding a separate RGBA layer fixed the opacity but
    # left the edges as hard rectangles, which still reads as glass rather than as
    # light. Working in the array means the falloff can be a real gradient and the
    # shaft can dissolve before it reaches the seabed.
    rng = np.random.default_rng(SEED + 91)
    xs = np.arange(w, dtype=np.float32)[None, :]
    ys = np.arange(h, dtype=np.float32)[:, None]
    shaft = np.zeros((h, w), dtype=np.float32)
    for _ in range(7):
        x0 = rng.uniform(-w * .1, w * 1.1)
        top_w = rng.uniform(0.012, 0.040) * w
        bot_w = top_w * rng.uniform(1.7, 3.0)
        tilt = rng.uniform(-0.14, 0.14) * h
        # Half-width grows linearly with depth, so the shaft widens as it descends.
        half = top_w + (bot_w - top_w) * (ys / max(h - 1, 1))
        centre = x0 + tilt * (ys / max(h - 1, 1))
        m = np.clip(1.0 - np.abs(xs - centre) / np.maximum(half, 1.0), 0.0, 1.0)
        # Soft across the shaft, and gone by the seabed.
        m = m ** 2.4 * np.clip(1.0 - (ys / (h * 0.86)), 0.0, 1.0) ** 1.5
        shaft = np.maximum(shaft, m)
    shaft *= 0.42
    arr = water + shaft[..., None] * np.array(shafts, np.float32)[None, None, :]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    # Rocky silhouettes, layered.
    for i, col in enumerate(rock):
        pts = ridge_points(w, h * (0.52 + 0.13 * i), h * 0.05, 2.6 + i * 2.2, SEED + 95 + i)
        draw_ridge(d, w, h, pts, col)
    for _ in range(26):
        x = int(rng.uniform(0, w))
        y = int(rng.uniform(h * .74, h * 1.0))
        rw = rng.uniform(w * .01, w * .035)
        rh = rng.uniform(h * .03, h * .11)
        d.ellipse([x - rw, y - rh, x + rw, y + rh], fill=far)
    return posterize(np.asarray(img, dtype=np.float32))


def coral_reef(size, light):
    """Reef life as flat coloured forms, the one place this palette gets warm."""
    w, h = size
    if light:
        water = vgrad(size, [(0.0, hsv(188, .56, .94)), (1.0, hsv(200, .62, .62))])
        corals = [hsv(340, .66, .86), hsv(24, .72, .88), hsv(46, .74, .88),
                  hsv(160, .54, .78), hsv(196, .54, .82), hsv(282, .50, .82)]
        ground = hsv(202, .34, .40)
        far = hsv(198, .36, .54)
    else:
        water = vgrad(size, [(0.0, hsv(206, .62, .50)), (1.0, hsv(220, .58, .26))])
        corals = [hsv(348, .62, .72), hsv(20, .68, .74), hsv(42, .70, .74),
                  hsv(158, .50, .62), hsv(196, .50, .70), hsv(280, .48, .70)]
        ground = hsv(210, .34, .22)
        far = hsv(206, .36, .36)

    img = Image.fromarray(water.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(SEED + 101)
    pts = ridge_points(w, h * 0.80, h * 0.05, 2.0, SEED + 105)
    draw_ridge(d, w, h, pts, far)
    # Branching forms, built from tapering segments so they read as coral and not
    # as a scatter of circles.
    # Fewer and much larger. The first pass used 34 heads at 0.07 to 0.20h with a
    # branch width of 3.5% of that, which at 540px tall is one to four pixels: the
    # result read as scattered confetti rather than as coral.
    for _ in range(15):
        x = int(rng.uniform(0, w))
        y = int(rng.uniform(h * 0.74, h * 0.98))
        col = corals[int(rng.integers(0, len(corals)))]
        ht = h * rng.uniform(0.16, 0.34)
        ang = rng.uniform(-0.42, 0.42)
        # A trunk that tapers, then two arms branching off it. Widths are a
        # fraction of the head's height so the form holds together at any size.
        d.line([(x, y), (x + ang * ht * 0.4, y - ht * 0.62)],
               fill=col, width=max(4, int(ht * 0.075)))
        for seg in range(5):
            f = 0.28 + 0.72 * (seg / 4)
            sy = y - ht * f
            sx = x + ang * ht * 0.4 * f
            ln = ht * (0.13 - 0.017 * seg)
            d.line([(sx, sy), (sx + ln, sy - ln * 1.7)],
                   fill=col, width=max(3, int(ht * (0.055 - 0.007 * seg))))
    for i in range(2):
        p2 = ridge_points(w, h * (0.92 + 0.06 * i), h * 0.03, 3.0 + i * 2, SEED + 110 + i)
        draw_ridge(d, w, h, p2, ground if i == 0 else mix(ground, (0, 0, 0), .35))
    return posterize(np.asarray(img, dtype=np.float32))


def iridescent_clouds(size, light):
    """Cloud bands that shift hue along their length rather than sitting flat."""
    w, h = size
    if light:
        sky = vgrad(size, [(0.0, hsv(206, .46, .94)), (0.6, hsv(300, .26, .96)),
                           (1.0, hsv(36, .40, .96))])
        hue_a, hue_b, sat, val = 320, 96, .48, .98
    else:
        sky = vgrad(size, [(0.0, hsv(232, .70, .30)), (0.6, hsv(262, .52, .40)),
                           (1.0, hsv(20, .44, .46))])
        hue_a, hue_b, sat, val = 268, 44, .56, .86

    arr = sky.astype(np.float32)
    img = Image.fromarray(arr.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(SEED + 121)
    if not light:
        stars(d, size, 140, SEED + 122, hsv(228, .16, .94), ymax=0.50)

    # Clouds as stacked heads on a shared base, drawn as a few well-separated
    # clumps per row.
    #
    # The first pass put 7 to 13 lozenges in a row, each twice as wide as the gap
    # to its neighbour, at a tenth of the frame height. They overlapped into one
    # continuous band per row and the whole thing read as horizontal stripes rather
    # than as cloud. Fewer, rounder, taller, and with real gaps between the clumps.
    for row in range(6):
        fy = 0.16 + row * 0.135
        cy = h * fy
        scale = 0.62 + row * 0.15
        base_hue = hue_a + (hue_b - hue_a) * min(fy, 1.0)
        col = hsv(base_hue, sat * (0.72 + 0.28 * (1 - fy)), val * (0.96 - 0.055 * row))
        clumps = 3 + row // 2
        for k in range(clumps):
            cx = w * ((k + 0.5) / clumps) + rng.uniform(-w * .06, w * .06)
            cyk = cy + rng.uniform(-h * .02, h * .02)
            # A clump is a wide flat base with two or three humps sitting on it.
            rw = w * rng.uniform(0.055, 0.085) * scale
            rh = h * rng.uniform(0.030, 0.044) * scale
            d.ellipse([cx - rw * 1.5, cyk - rh * 0.30, cx + rw * 1.5, cyk + rh * 0.42],
                      fill=col)
            for j in range(3):
                ox = cx + (j - 1) * rw * 0.92
                hr = rw * rng.uniform(0.52, 0.78)
                d.ellipse([ox - hr, cyk - hr * rng.uniform(0.95, 1.45),
                           ox + hr, cyk + rh * 0.30], fill=col)
    return posterize(np.asarray(img, dtype=np.float32))


def campfire(size, light):
    """The night scene: ridge in silhouette, the fire as the only warm thing."""
    w, h = size
    horizon = h * 0.72
    if light:
        # Still light: the same composition as the dark one but before sunset.
        sky = vgrad(size, [(0.0, hsv(206, .54, .84)), (0.5, hsv(28, .60, .92)),
                           (1.0, hsv(18, .72, .86))])
        ridge_col = hsv(24, .58, .30)
        fire = hsv(38, .96, 1.0)
        ember = hsv(12, .92, .96)
    else:
        sky = vgrad(size, [(0.0, hsv(234, .74, .26)), (0.45, hsv(244, .62, .36)),
                           (1.0, hsv(20, .60, .42))])
        ridge_col = hsv(230, .54, .12)
        fire = hsv(30, .98, 1.0)
        ember = hsv(8, .94, .98)

    arr = sky.astype(np.float32)
    img = Image.fromarray(arr.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    if not light:
        stars(d, size, 190, SEED + 131, hsv(226, .16, .95))

    fx, fy = w * 0.50, horizon + h * 0.10
    # The wash the fire throws on the trees behind it, laid down before the ridge.
    g = glow_field(size, fx, fy - h * 0.05, min(w, h) * 0.52, fire, 0.42)
    add = g[..., None] * np.array(fire, np.float32)[None, None, :]
    img = Image.fromarray(np.clip(np.asarray(img, np.float32) + add, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)

    pts = ridge_points(w, horizon, h * 0.075, 2.2, SEED + 135)
    draw_ridge(d, w, h, pts, ridge_col)
    rng = np.random.default_rng(SEED + 136)
    for _ in range(30):
        x = int(rng.uniform(0, w))
        conifer(d, x, h * 1.02, h * rng.uniform(0.16, 0.34), ridge_col, rng)
    # Fire: stacked tapering flames, hot core to cool tip.
    for i, (col, sc) in enumerate(((ember, 1.0), (fire, 0.74), (hsv(52, .92, 1.0), 0.44))):
        hh = h * 0.085 * sc
        ww = h * 0.035 * sc
        top = fy - hh
        d.polygon([(fx - ww, fy), (fx + ww, fy),
                   (fx + ww * 0.28, top + hh * 0.34), (fx, top), (fx - ww * 0.28, top + hh * 0.34)],
                  fill=col)
    d.polygon([(fx - w * .035, fy + h * .004), (fx + w * .035, fy + h * .004),
               (fx + w * .012, fy - h * .012), (fx - w * .012, fy - h * .012)], fill=ember)
    for _ in range(22):
        sx = fx + rng.normal(0, w * 0.035)
        sy = fy - h * rng.uniform(0.09, 0.30)
        r = max(1.0, h * 0.0032 * rng.uniform(0.5, 1.4))
        d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=ember + (190,))
    return posterize(np.asarray(img, dtype=np.float32))


def lake(size, light):
    """Still water under a ridge, with the ridge reflected in it."""
    w, h = size
    horizon = h * 0.60
    if light:
        sky = vgrad(size, [(0.0, hsv(200, .50, .92)), (0.55, hsv(34, .52, .94)),
                           (1.0, hsv(28, .62, .90))])
        ridge = [hsv(198, .30, .74), hsv(202, .38, .56), hsv(206, .44, .38)]
        sea = hsv(200, .48, .56)
        accent = hsv(48, .92, 1.0)
    else:
        sky = vgrad(size, [(0.0, hsv(232, .70, .32)), (0.55, hsv(226, .52, .42)),
                           (1.0, hsv(296, .46, .50))])
        ridge = [hsv(224, .30, .42), hsv(228, .36, .30), hsv(232, .42, .19)]
        sea = hsv(226, .48, .26)
        accent = hsv(16, .96, 1.0)

    img = Image.fromarray(sky.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    if not light:
        stars(d, size, 140, SEED + 141, hsv(224, .16, .94))
    sun(d, w * 0.72, horizon - h * 0.14, min(w, h) * 0.060, accent)
    for i, col in enumerate(ridge):
        pts = ridge_points(w, horizon - h * 0.02 + h * 0.05 * i, h * (0.05 - 0.012 * i),
                           1.8 + i * 2.0, SEED + 145 + i)
        draw_ridge(d, w, horizon + 2, pts, col)
    # Water plane, then the reflection flipped and dimmed.
    d.rectangle([0, horizon, w, h], fill=sea)
    refl = img.crop((0, int(horizon * 0.55), w, int(horizon))).transpose(
        Image.FLIP_TOP_BOTTOM).filter(ImageFilter.GaussianBlur(h * 0.006))
    refl = Image.blend(Image.new("RGB", refl.size, sea), refl, 0.55)
    img.paste(refl, (0, int(horizon)))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(SEED + 151)
    for i in range(90):
        f = rng.random() ** 0.7
        y = horizon + (h - horizon) * f
        x = rng.uniform(0, w)
        ln = w * rng.uniform(0.006, 0.030) * (0.4 + f)
        d.rectangle([x - ln, y, x + ln, y + max(1.0, h * 0.0018)],
                    fill=mix(sea, ridge[-1], 0.5) + (int(150 * (1 - f * 0.6)),))
    return posterize(np.asarray(img, dtype=np.float32))


def dunes(size, light):
    w, h = size
    horizon = h * 0.48
    if light:
        sky = vgrad(size, [(0.0, hsv(198, .52, .92)), (0.5, hsv(30, .50, .94)),
                           (1.0, hsv(20, .64, .92))])
        sand = [hsv(38, .48, .84), hsv(34, .52, .74), hsv(30, .54, .62),
                hsv(26, .52, .48), hsv(22, .48, .34)]
        accent = hsv(50, .92, 1.0)
    else:
        sky = vgrad(size, [(0.0, hsv(230, .70, .32)), (0.5, hsv(258, .50, .42)),
                           (1.0, hsv(18, .48, .48))])
        sand = [hsv(28, .42, .50), hsv(24, .46, .40), hsv(20, .48, .30),
                hsv(16, .46, .21), hsv(12, .44, .13)]
        accent = hsv(18, .94, 1.0)

    img = Image.fromarray(sky.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    if not light:
        stars(d, size, 150, SEED + 161, hsv(224, .16, .94), ymax=0.40)
    sun(d, w * 0.50, horizon - h * 0.09, min(w, h) * 0.078, accent)
    for i, col in enumerate(sand):
        y0 = horizon + (h - horizon) * (i / len(sand))
        y1 = horizon + (h - horizon) * ((i + 1) / len(sand))
        pts = ridge_points(w, y0, h * 0.028, 1.2 + i * 1.3, SEED + 165 + i, octaves=3)
        poly = [(int(x), int(y)) for x, y in enumerate(pts)]
        poly += [(w, y1), (0, y1)]
        d.polygon(poly, fill=col)
    return posterize(np.asarray(img, dtype=np.float32))


SCENES = (
    ("ridge_pines", pine_ridge),
    ("forest_pines", pine_forest),
    ("forest_birch", birch_grove),
    ("taiga", taiga),
    ("mountain_ridge", mountain_ridge),
    ("field", field),
    ("dunes", dunes),
    ("ocean", ocean),
    ("lake", lake),
    ("reef", reef),
    ("coral_reef", coral_reef),
    ("clouds_iridescent", iridescent_clouds),
    ("campfire", campfire),
)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE.parent / "system/usr/share/backgrounds/Firewatch"
    w = int(sys.argv[2]) if len(sys.argv) > 2 else 2560
    h = int(sys.argv[3]) if len(sys.argv) > 3 else 1440
    out.mkdir(parents=True, exist_ok=True)

    total = 0
    for name, fn in SCENES:
        for light in (True, False):
            suffix = "light" if light else "dark"
            img = _frame(fn((w, h), light))
            path = out / f"{name}_{suffix}.jpg"
            img.save(path, "JPEG", quality=88, optimize=True, progressive=True)
            kb = path.stat().st_size // 1024
            total += kb
            print(f"  {path.name:28} {w}x{h}  {kb} KB")
    print(f"{len(SCENES) * 2} wallpapers, {total} KB total, in {out}")


if __name__ == "__main__":
    main()
