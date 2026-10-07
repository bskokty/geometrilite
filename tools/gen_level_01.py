#!/usr/bin/env python3
"""Level 1'i üretir (levels/level_01.json) ve fiziği game.gd ile aynı sabitlerle
simüle ederek seviyenin geçilebilir olduğunu doğrular.

Kullanım:  python3 tools/gen_level_01.py
"""
import json
import os
import sys

ROWS = 6
T = 64
GROUND_Y = 560
GRAVITY = 4200.0
JUMP_V = -1100.0
SPEED = 520.0
PW = PH = 56.0
SPIKE_W = 0.55
SPIKE_H = 0.60
LAND_TOL = 12.0
DT = 1.0 / 60.0

# (parça, sonrasındaki boş kolon sayısı)
SEGMENTS = [
    (["^"], 8),                                  # tek diken
    (["^^"], 8),                                 # çift diken
    (["...", "...", "###"], 7),                  # 3 geniş, 1 yüksek blok
    (["^....^"], 8),                             # iki ayrı tek diken
    (["..", "##", "##"], 8),                     # 2 yüksek, 2 geniş blok
    (["^^^"], 8),                                # üçlü diken
    (["..", "..", "##..##..##"], 8),             # 3 adet 2 geniş, 1 yüksek basamak
    (["^....^....^^"], 5),                      # 1-1-2 diken grupları
]
START_EMPTY = 14


def build():
    """Her parça, ROWS satıra sağdan hizalı (alt satırlar) yerleştirilir."""
    grid = [[] for _ in range(ROWS)]

    def add(cols):
        # cols: ROWS uzunluklu string listesi (üst->alt) ya da kısa liste (alttan hizalı)
        w = max(len(s) for s in cols)
        padded = ["." * w] * (ROWS - len(cols)) + [s.ljust(w, ".") for s in cols]
        for r in range(ROWS):
            grid[r].append(padded[r])

    def gap(n):
        add(["." * n])

    gap(START_EMPTY)
    for seg, after in SEGMENTS:
        add(seg)
        gap(after)
    rows = ["".join(r) for r in grid]
    return rows


def tiles(rows):
    out = []
    n = len(rows)
    for r, line in enumerate(rows):
        for c, ch in enumerate(line):
            if ch in "#^":
                out.append((ch, c * T, GROUND_Y - (n - r) * T))
    return out


def hits(px, py, vy, prev_bottom, tl):
    """game.gd ile aynı çarpışma. py = alt kenar, px = merkez. (ölüm, iniş_y)"""
    land = None
    l, r, t, b = px - PW / 2, px + PW / 2, py - PH, py
    for ch, x, y in tl:
        if ch == "#":
            if r > x and l < x + T and b > y and t < y + T:
                if vy >= 0 and prev_bottom <= y + LAND_TOL:
                    land = y if land is None else min(land, y)
                else:
                    return True, None
        else:
            sw, sh = T * SPIKE_W, T * SPIKE_H
            sx = x + (T - sw) / 2
            sy = y + T - sh
            if r > sx and l < sx + sw and b > sy and t < y + T:
                return True, None
    return False, land


def support(px, py, tl):
    if py >= GROUND_Y - 0.001:
        return True
    for ch, x, y in tl:
        if ch == "#" and abs(py - y) < 0.01 and px + PW / 2 > x and px - PW / 2 < x + T:
            return True
    return False


def step(state, jump, tl):
    f, py, vy, ground = state
    px = SPEED * DT * f  # f, adımdan önceki kare
    px_n = SPEED * DT * (f + 1)
    prev_bottom = py
    if ground and jump:
        vy = JUMP_V
        ground = False
    if not ground:
        vy += GRAVITY * DT
        py += vy * DT
    dead, land = hits(px_n, py, vy, prev_bottom, tl)
    if dead:
        return None
    if not ground and land is not None and vy >= 0:
        py, vy, ground = land, 0.0, True
    elif not ground and py >= GROUND_Y:
        py, vy, ground = GROUND_Y, 0.0, True
    elif ground and not support(px_n, py, tl):
        ground = False
    return (f + 1, py, vy, ground)


def solvable(rows):
    tl = tiles(rows)
    end_f = int((len(rows[0]) * T + 400) / (SPEED * DT)) + 1
    start = (0, float(GROUND_Y), 0.0, True)
    seen = set()
    stack = [start]
    while stack:
        s = stack.pop()
        key = (s[0], round(s[1], 3), round(s[2], 3), s[3])
        if key in seen:
            continue
        seen.add(key)
        if s[0] >= end_f:
            return True
        for jump in (False, True) if s[3] else (False,):
            n = step(s, jump, tl)
            if n is not None:
                stack.append(n)
    return False


def main():
    rows = build()
    width = len(rows[0])
    assert all(len(r) == width for r in rows)
    ok = solvable(rows)
    print(f"kolon sayısı: {width}, geçilebilir: {ok}")
    if not ok:
        sys.exit(1)
    out = {"name": "Level 1", "speed": int(SPEED), "rows": rows}
    path = os.path.join(os.path.dirname(__file__), "..", "levels", "level_01.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    for r in rows:
        print(r)


if __name__ == "__main__":
    main()
