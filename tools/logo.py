#!/usr/bin/env python3
"""Generates the Piclo logo: "piclo" in bold lowercase pixel letters with
the owl from In the Woods beside it, as piclo/icons/logo.svg.

Plain black pixels, no grid lines or crosses, so the logo doesn't read as a
puzzle. The owl comes straight from piclo/data/packs/woods.lua, every
shaded square in black (its white eyes are the drawing's empty squares);
rerun this script after changing the owl.

Run from the repo root:  python3 tools/logo.py [preview.png]
Not shipped; the file it writes is.
"""

import re
import struct
import sys
import zlib

# Lowercase glyphs: 2 rows of ascender, 5 of x-height, 2 of descender.
FONT = {
    "p": [".....", ".....", "####.", "##.##", "##.##", "##.##", "####.", "##...", "##..."],
    "i": ["##", "..", "##", "##", "##", "##", "##", "..", ".."],
    "c": ["....", "....", ".###", "##..", "##..", "##..", ".###", "....", "...."],
    "l": ["##", "##", "##", "##", "##", "##", "##", "..", ".."],
    "o": [".....", ".....", ".###.", "##.##", "##.##", "##.##", ".###.", ".....", "....."],
}
WORD = "piclo"
LETTER_GAP = 1    # empty columns between letters
OWL_GAP = 2       # empty columns between the word and the owl
CELL = 20         # svg units per pixel


def owl_rows():
    src = open("piclo/data/packs/woods.lua").read()
    block = src[src.index('id = "woods/owl"'):]
    art = block[block.index("art = {"):block.index("}")]
    rows = [re.sub("[0-4]", "#", row) for row in re.findall(r'"([.0-4]+)"', art)]
    while rows and set(rows[0]) == {"."}:
        rows.pop(0)
    while rows and set(rows[-1]) == {"."}:
        rows.pop()
    return rows


def word_rows():
    rows = [""] * len(FONT[WORD[0]])
    for k, ch in enumerate(WORD):
        for r in range(len(rows)):
            rows[r] += ("." * LETTER_GAP if k else "") + FONT[ch][r]
    return rows


def build():
    """The word sits on the owl's perch: their bottom rows line up."""
    word, owl = word_rows(), owl_rows()
    h = max(len(word), len(owl))
    word = ["." * len(word[0])] * (h - len(word)) + word
    owl = ["." * len(owl[0])] * (h - len(owl)) + owl
    return [w + "." * OWL_GAP + o for w, o in zip(word, owl)]


def svg(grid):
    h, w = len(grid), len(grid[0])
    W, H = w * CELL, h * CELL
    # One path, a rect per run of pixels, so shared edges don't show seams.
    runs = [f"M{m.start() * CELL} {r * CELL}h{len(m.group()) * CELL}v{CELL}h-{len(m.group()) * CELL}z"
            for r, row in enumerate(grid) for m in re.finditer("#+", row)]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
            f'<path fill="#000000" d="{" ".join(runs)}"/>\n</svg>\n')


def png(grid, path, scale=8):
    """A quick preview, with no image library needed."""
    gray = {".": 255, "#": 0}
    raw = b"".join(
        b"\0" + bytes(gray[ch] for ch in row for _ in range(scale))
        for row in grid for _ in range(scale))
    w, h = len(grid[0]) * scale, len(grid) * scale

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    g = build()
    open("piclo/icons/logo.svg", "w").write(svg(g))
    print(f"logo: {len(g[0])} x {len(g)} pixels")
    for row in g:
        print(row)
    if len(sys.argv) > 1:
        png(g, sys.argv[1])
