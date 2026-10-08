#!/usr/bin/env python3
"""levels/level_NN.json dosyalarını üretir ve her birinin geçilebilir olduğunu doğrular.

Doğrulama game.gd ile aynı sabit adımlı fiziği simüle eder. Çift zıplama
modellenmez (yalnızca tek zıplamayla geçilebilirlik aranır), yani seviyeler
çift zıplamayla ancak daha kolay olur.

Kullanım:  python3 tools/gen_levels.py
"""
import json
import os
import random
import sys

ROWS = 6
T = 64
GROUND_Y = 560
GRAVITY = 4200.0
JUMP_V = -1100.0
PW = PH = 56.0
SPIKE_W = 0.55
SPIKE_H = 0.60
LAND_TOL = 12.0
DT = 1.0 / 60.0

# Segmentler: satırlar üstten alta, alta hizalı. '^' diken, '#' blok.
EASY = [["^"], ["^^"], ["###"], ["##"], ["^....^"], ["^......^"]]
MEDIUM = [
    ["^^^"], ["##", "##"], ["##..##..##"], ["^....^....^^"],
    [".##", "###"], ["^..^..^"], ["###...^"],
]
HARD = [
    [".^.", "###"], ["^^^...^^"], ["^..^..^..^"], ["##..^..##"],
    ["#...", "##.."], ["^.##.^"], [".###", "####"],
    ["^^.^^"], ["##^^##"],
]

# (ad, hız, segment sayısı, boşluk aralığı, havuz ağırlıkları (kolay, orta, zor), tohum)
LEVELS = [
    ("Level 1", 520, None, None, None, None),   # el yapımı sıralama
    ("Level 2", 545, 12, (6, 9), (3, 2, 0), 202),
    ("Level 3", 570, 14, (5, 8), (2, 3, 1), 303),
    ("Level 4", 595, 16, (5, 7), (1, 3, 2), 404),
    ("Level 5", 620, 18, (4, 7), (1, 2, 3), 505),
    ("Level 6", 650, 20, (4, 6), (0, 2, 4), 606),
]

LEVEL1_SEGMENTS = [
    (["^"], 8), (["^^"], 8), (["###"], 7), (["^....^"], 8), (["##", "##"], 8),
    (["^^^"], 8), (["##..##..##"], 8), (["^....^....^^"], 5),
]
START_EMPTY = 14


def assemble(parts):
    """parts: [(segment_rows, boş_kolon_sonrası)] -> ROWS uzunluklu satır listesi."""
    grid = [[] for _ in range(ROWS)]

    def add(cols):
        w = max(len(s) for s in cols)
        padded = ["." * w] * (ROWS - len(cols)) + [s.ljust(w, ".") for s in cols]
        for r in range(ROWS):
            grid[r].append(padded[r])

    add(["." * START_EMPTY])
    for seg, after in parts:
        add(seg)
        add(["." * after])
    return ["".join(r) for r in grid]


def tiles(rows):
    n = len(rows)
    return [(ch, c * T, GROUND_Y - (n - r) * T)
            for r, line in enumerate(rows) for c, ch in enumerate(line) if ch in "#^"]


def hits(px, py, vy, prev_bottom, tl):
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
    return any(ch == "#" and abs(py - y) < 0.01 and px + PW / 2 > x and px - PW / 2 < x + T
               for ch, x, y in tl)


def step(state, jump, tl, speed):
    f, py, vy, ground = state
    px_n = speed * DT * (f + 1)
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


def solvable(rows, speed):
    tl = tiles(rows)
    end_f = int((len(rows[0]) * T + 400) / (speed * DT)) + 1
    stack = [(0, float(GROUND_Y), 0.0, True)]
    seen = set()
    while stack:
        s = stack.pop()
        key = (s[0], round(s[1], 3), round(s[2], 3), s[3])
        if key in seen:
            continue
        seen.add(key)
        if s[0] >= end_f:
            return True
        for jump in ((False, True) if s[3] else (False,)):
            n = step(s, jump, tl, speed)
            if n is not None:
                stack.append(n)
    return False


def pool_for(speed):
    """Tek başına (düz zeminde) geçilebilen segmentleri döndürür."""
    def ok(seg):
        rows = assemble([(seg, 12)])
        return solvable(rows, speed)
    return [[s for s in tier if ok(s)] for tier in (EASY, MEDIUM, HARD)]


def build_level(name, speed, count, gaps, weights, seed):
    rng = random.Random(seed)
    pools = pool_for(speed)
    for _ in range(200):
        parts = []
        prev = None
        for _i in range(count):
            tier = rng.choices(range(3), weights=weights)[0]
            if not pools[tier]:
                continue
            seg = rng.choice(pools[tier])
            if seg == prev:
                continue
            prev = seg
            parts.append((seg, rng.randint(*gaps)))
        rows = assemble(parts)
        if solvable(rows, speed):
            return rows
    raise RuntimeError(f"{name}: geçilebilir seviye üretilemedi")


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "levels")
    os.makedirs(out_dir, exist_ok=True)
    for i, (name, speed, count, gaps, weights, seed) in enumerate(LEVELS, 1):
        if count is None:
            rows = assemble(LEVEL1_SEGMENTS)
            if not solvable(rows, speed):
                sys.exit(f"{name} geçilemiyor")
        else:
            rows = build_level(name, speed, count, gaps, weights, seed)
        assert len({len(r) for r in rows}) == 1
        path = os.path.join(out_dir, f"level_{i:02d}.json")
        with open(path, "w", encoding="utf-8") as fh:
            json.dump({"name": name, "speed": speed, "rows": rows}, fh, ensure_ascii=False, indent=1)
            fh.write("\n")
        print(f"{name}: hız {speed}, {len(rows[0])} kolon, geçilebilir: True")


if __name__ == "__main__":
    main()
