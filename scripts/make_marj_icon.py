#!/usr/bin/env python3
"""Draws Marj's launcher icon and writes it into the Android resources.

The mark: an M written on a page's margin line. The left stem of the M
stands on the thin margin rule, which runs the whole height of the icon
the way it runs down a sheet of ruled paper.

Run from the repository root:  python3 scripts/make_marj_icon.py
(needs Pillow). Nothing else in the build calls this; the PNGs it writes
are committed.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

# The adaptive-icon canvas is 108 x 108 units; launchers show the middle
# 72 and may crop to a circle of 66.
CANVAS = 108.0
SUPERSAMPLE = 6

INK_TOP = (0x30, 0x55, 0xC9)
INK_BOTTOM = (0x20, 0x39, 0x93)
PAPER = (0xFF, 0xFF, 0xFF)
MARGIN = (0xFF, 0x8A, 0x73)

# The M: bottom left, top left, the dip, top right, bottom right.
STEM_LEFT, STEM_RIGHT = 38.0, 70.0
TOP, BOTTOM, DIP = 40.0, 69.0, 60.0
M_POINTS = [
    (STEM_LEFT, BOTTOM),
    (STEM_LEFT, TOP),
    ((STEM_LEFT + STEM_RIGHT) / 2, DIP),
    (STEM_RIGHT, TOP),
    (STEM_RIGHT, BOTTOM),
]
M_WIDTH = 6.2
MARGIN_WIDTH = 2.0


def _stroke(draw, points, width, colour, scale):
    """A line of even width with round ends and round corners: the round
    tip of a pen, set down all along the path."""
    r = width * scale / 2
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(2, int(math.dist((x0, y0), (x1, y1)) * scale))
        for i in range(steps + 1):
            t = i / steps
            x = (x0 + (x1 - x0) * t) * scale
            y = (y0 + (y1 - y0) * t) * scale
            draw.ellipse((x - r, y - r, x + r, y + r), fill=colour)


def mark(size, *, colour=PAPER, margin=None):
    """The mark alone, on a transparent 108-unit canvas, [size] px wide."""
    margin = MARGIN if margin is None else margin
    big = size * SUPERSAMPLE
    scale = big / CANVAS
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    half = MARGIN_WIDTH * scale / 2
    x = STEM_LEFT * scale
    draw.rectangle((x - half, 0, x + half, big), fill=margin + (255,))
    _stroke(draw, M_POINTS, M_WIDTH, colour + (255,), scale)
    return image.resize((size, size), Image.LANCZOS)


def background(size):
    """The ink the mark is written on: a little lighter at the top."""
    column = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        column.putpixel(
            (0, y),
            tuple(round(a + (b - a) * t) for a, b in zip(INK_TOP, INK_BOTTOM)),
        )
    return column.resize((size, size), Image.BILINEAR).convert("RGBA")


def legacy(size):
    """The whole icon for launchers without adaptive icons: the middle of
    the canvas on a rounded square."""
    canvas = round(size * CANVAS / 72)
    full = background(canvas)
    full.alpha_composite(mark(canvas))
    inset = (canvas - size) // 2
    icon = full.crop((inset, inset, inset + size, inset + size))
    big = size * SUPERSAMPLE
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, big - 1, big - 1), radius=big * 0.225, fill=255
    )
    icon.putalpha(mask.resize((size, size), Image.LANCZOS))
    return icon


DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}


def main():
    res = "android/app/src/main/res"
    if not os.path.isdir(res):
        sys.exit("run this from the repository root")
    for name, density in DENSITIES.items():
        folder = f"{res}/mipmap-{name}"
        adaptive = round(108 * density)
        mark(adaptive).save(f"{folder}/ic_launcher_foreground.png")
        mark(adaptive, colour=PAPER, margin=PAPER).save(
            f"{folder}/ic_launcher_monochrome.png"
        )
        legacy(round(48 * density)).save(f"{folder}/ic_launcher.png")
    # The same picture, large, for the README and the release page.
    os.makedirs("assets/icon", exist_ok=True)
    legacy(1024).save("assets/icon/marj.png")
    print("wrote the launcher icons")


if __name__ == "__main__":
    main()
