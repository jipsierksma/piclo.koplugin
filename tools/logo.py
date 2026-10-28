#!/usr/bin/env python3
"""Generates the Piclo logo, piclo/icons/logo.svg: "piclo" in bold lowercase
pixel letters drawn as a solved nonogram, on a light grid with a few crosses
in the empty squares around the letters.

The picture is also a valid puzzle (spec/logo_spec.lua solves it by line
logic). That hinges on the l rising higher above the letters than the p
drops below them: with equal lengths the puzzle has more than one solution.
Found with the search in tools/drafts/logo_explore.

Run from the repo root:  python3 tools/logo.py
Not shipped; the file it writes is.
"""

# Lowercase glyphs: 3 rows above the letters (only the l uses all three),
# 5 rows of letter body, 2 rows below (the p's tail).
FONT = {
    "p": [".....", ".....", ".....", "####.", "##.##", "##.##", "##.##", "####.", "##...", "##..."],
    "i": ["..", "##", "..", "##", "##", "##", "##", "##", "..", ".."],
    "c": ["....", "....", "....", ".###", "##..", "##..", "##..", ".###", "....", "...."],
    "l": ["##", "##", "##", "##", "##", "##", "##", "##", "..", ".."],
    "o": [".....", ".....", ".....", ".###.", "##.##", "##.##", "##.##", ".###.", ".....", "....."],
}
WORD = "piclo"
LETTER_GAP = 1    # empty columns between letters
MARGIN = 1        # empty cells around the word
CELL = 40         # svg units per grid cell
FILL_GAP = 3      # white gap inside a filled cell, like the board
CROSS_EVERY = 3   # cross roughly every third empty cell touching a letter


def build():
    rows = [""] * len(FONT[WORD[0]])
    for k, ch in enumerate(WORD):
        for r in range(len(rows)):
            rows[r] += ("." * LETTER_GAP if k else "") + FONT[ch][r]
    w = len(rows[0]) + 2 * MARGIN
    pad = ["." * w] * MARGIN
    return pad + ["." * MARGIN + r + "." * MARGIN for r in rows] + pad


def crosses(grid):
    h, w = len(grid), len(grid[0])
    out, n = [], 0
    for r in range(h):
        for c in range(w):
            if grid[r][c] == "#":
                continue
            near = any(0 <= r + dr < h and 0 <= c + dc < w and grid[r + dr][c + dc] == "#"
                       for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)))
            if near:
                n += 1
                if (n * 7 + r * 3 + c) % CROSS_EVERY == 0:
                    out.append((r, c))
    return out


def svg(grid):
    h, w = len(grid), len(grid[0])
    W, H = w * CELL, h * CELL
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">']
    thin = " ".join(f"M{c * CELL} 0V{H}" for c in range(1, w)) + " " + \
        " ".join(f"M0 {r * CELL}H{W}" for r in range(1, h))
    # Theme.FAINT, thick enough to survive scaling down: e-ink washes out
    # thin light lines.
    parts.append(f'<path fill="none" stroke="#AAAAAA" stroke-width="3" d="{thin}"/>')
    parts.append(f'<rect x="1.5" y="1.5" width="{W - 3}" height="{H - 3}" fill="none" stroke="#AAAAAA" stroke-width="3"/>')
    i0, i1 = int(CELL * 0.3), int(CELL * 0.7)
    xs = " ".join(f"M{c * CELL + i0} {r * CELL + i0}L{c * CELL + i1} {r * CELL + i1}"
                  f"M{c * CELL + i1} {r * CELL + i0}L{c * CELL + i0} {r * CELL + i1}"
                  for r, c in crosses(grid))
    parts.append(f'<path fill="none" stroke="#555555" stroke-width="5" stroke-linecap="round" d="{xs}"/>')
    s = CELL - 2 * FILL_GAP
    fills = " ".join(f"M{c * CELL + FILL_GAP} {r * CELL + FILL_GAP}h{s}v{s}h-{s}z"
                     for r in range(h) for c in range(w) if grid[r][c] == "#")
    parts.append(f'<path fill="#000000" d="{fills}"/>')
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


if __name__ == "__main__":
    g = build()
    open("piclo/icons/logo.svg", "w").write(svg(g))
    print(f"logo: {len(g[0])} x {len(g)} cells")
    for row in g:
        print(row)
