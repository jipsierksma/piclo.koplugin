#!/usr/bin/env python3
"""Generates piclogic/icons/wordmark.svg: "PICTURE / LOGIC" as a solved
nonogram on a coarse grid, so cells (and their crosses) stay big on e-ink.

Run from the repo root:  python3 tools/wordmark.py
Not shipped; the SVG it writes is.
"""

FONT = {  # 5 rows per glyph, '#' = filled
    "P": ["###.", "#..#", "###.", "#...", "#..."],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "C": [".###", "#...", "#...", "#...", ".###"],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#..#", "#..#", "#..#", "#..#", ".##."],
    "R": ["###.", "#..#", "###.", "#.#.", "#..#"],
    "E": ["####", "#...", "###.", "#...", "####"],
    "L": ["#...", "#...", "#...", "#...", "####"],
    "O": [".##.", "#..#", "#..#", "#..#", ".##."],
    "G": [".###", "#...", "#.##", "#..#", ".###"],
}
LINES = ["PICTURE", "LOGIC"]
CELL = 40          # svg units per grid cell
MARGIN = 1         # empty cells around the lettering
LINE_GAP = 1       # empty rows between the two words
FILL_GAP = 3       # white gap inside a filled cell, like the board
CROSS_EVERY = 3    # cross roughly every third empty cell touching a letter


def word_rows(word):
    rows = ["" for _ in range(5)]
    for k, ch in enumerate(word):
        for r in range(5):
            rows[r] += ("." if k else "") + FONT[ch][r]
    return rows


def build_grid():
    words = [word_rows(w) for w in LINES]
    width = max(len(w[0]) for w in words) + 2 * MARGIN
    grid = [["."] * width for _ in range(MARGIN)]
    for i, rows in enumerate(words):
        if i:
            grid += [["."] * width for _ in range(LINE_GAP)]
        left = (width - len(rows[0])) // 2
        for row in rows:
            line = ["."] * width
            for c, ch in enumerate(row):
                line[left + c] = ch
            grid.append(line)
    grid += [["."] * width for _ in range(MARGIN)]
    return grid


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
    parts.append(f'<path fill="none" stroke="#DDDDDD" stroke-width="2" d="{thin}"/>')
    parts.append(f'<rect x="1" y="1" width="{W - 2}" height="{H - 2}" fill="none" stroke="#AAAAAA" stroke-width="2"/>')
    i0, i1 = int(CELL * 0.3), int(CELL * 0.7)
    xs = " ".join(f"M{c * CELL + i0} {r * CELL + i0}L{c * CELL + i1} {r * CELL + i1}"
                  f"M{c * CELL + i1} {r * CELL + i0}L{c * CELL + i0} {r * CELL + i1}"
                  for r, c in crosses(grid))
    parts.append(f'<path fill="none" stroke="#777777" stroke-width="4" stroke-linecap="round" d="{xs}"/>')
    s = CELL - 2 * FILL_GAP
    fills = " ".join(f"M{c * CELL + FILL_GAP} {r * CELL + FILL_GAP}h{s}v{s}h-{s}z"
                     for r in range(h) for c in range(w) if grid[r][c] == "#")
    parts.append(f'<path fill="#000000" d="{fills}"/>')
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


if __name__ == "__main__":
    g = build_grid()
    open("piclogic/icons/wordmark.svg", "w").write(svg(g))
    print(f"wordmark: {len(g[0])} x {len(g)} cells")
    for row in g:
        print("".join(row))
