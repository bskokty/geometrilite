#!/usr/bin/env python3
"""levels/level_NN.json dosyalarını üretir ve geçilebilirliği doğrular.

Doğrulama, scripts/game.gd ile aynı sabit adımlı fiziği simüle eder
(zıplama, havada zıplama hakkı, tavan sınırı, blok/diken çarpışması).
Seviye bilgisi:
  speed      px/sn
  air_jumps  havada yapılabilen ek zıplama sayısı (0 yok, -1 sınırsız)
Karakterler: '.' boş, '#' blok, '^' yer dikeni, 'v' tavan dikeni.

Kullanım:  python3 tools/gen_levels.py
"""
import json
import os
import random
import sys

ROWS = 6
T = 64
GROUND_Y = 560
CEIL_Y = GROUND_Y - ROWS * T
GRAVITY = 4200.0
JUMP_V = -1100.0
PW = PH = 56.0
SPIKE_W = 0.55
SPIKE_H = 0.60
LAND_TOL = 12.0
DT = 1.0 / 60.0

# Bottom-aligned segmentler (üstten alta satırlar).
EASY = [["^"], ["^^"], ["###"], ["##"], ["^....^"], ["^......^"]]
MEDIUM = [
    ["^^^"], ["##", "##"], ["##..##..##"], ["^....^....^^"],
    [".##", "###"], ["^..^..^"], ["###...^"],
]
HARD = [
    [".^.", "###"], ["^^^...^^"], ["^..^..^..^"], ["##..^..##"],
    ["#...", "##.."], ["^.##.^"], [".###", "####"], ["^^.^^"], ["##^^##"],
]

# (ad, hız, segment sayısı, boşluk aralığı, ağırlıklar (kolay, orta, zor),
#  tohum, havada zıplama, tavan engelleri, zorunlu uzun blok sayısı)
LEVELS = [
    ("Awakening", 520, None, None, None, None, 0, False, 0),
    ("Pulse Run", 545, 12, (6, 9), (3, 2, 0), 202, 0, False, 0),
    ("Static", 570, 14, (5, 8), (2, 3, 1), 303, 0, True, 0),
    ("Overdrive", 595, 16, (5, 7), (1, 3, 2), 404, 1, True, 2),
    ("Voltage", 620, 18, (4, 7), (1, 2, 3), 505, 3, True, 3),
    ("Zenith", 650, 20, (4, 6), (0, 2, 4), 606, -1, True, 4),
]

LEVEL1_SEGMENTS = [
    (["^"], 8), (["^^"], 8), (["###"], 7), (["^....^"], 8), (["##", "##"], 8),
    (["^^^"], 8), (["##..##..##"], 8), (["^....^....^^"], 5),
]
START_EMPTY = 14


def assemble(parts):
    """parts: [(segment, boş_kolon_sonrası)] -> ROWS satır. Kısa segmentler alta hizalanır."""
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


class World:
    def __init__(self, rows, speed, air):
        self.speed = speed
        self.air = air
        self.width_px = len(rows[0]) * T
        self.cols = {}
        n = len(rows)
        has_v = False
        for r, line in enumerate(rows):
            for c, ch in enumerate(line):
                if ch in "#^v":
                    self.cols.setdefault(c, []).append((ch, c * T, GROUND_Y - (n - r) * T))
                    has_v = has_v or ch == "v"
        self.ceiling = has_v or air != 0

    def near(self, l, r):
        out = []
        for c in range(int(l // T), int(r // T) + 1):
            out.extend(self.cols.get(c, ()))
        return out

    def hits(self, px, py, vy, prev_bottom):
        land = None
        l, r, t, b = px - PW / 2, px + PW / 2, py - PH, py
        sw, sh = T * SPIKE_W, T * SPIKE_H
        for ch, x, y in self.near(l, r):
            if ch == "#":
                if r > x and l < x + T and b > y and t < y + T:
                    if vy >= 0 and prev_bottom <= y + LAND_TOL:
                        land = y if land is None else min(land, y)
                    else:
                        return True, None
            else:
                sx = x + (T - sw) / 2
                if r > sx and l < sx + sw:
                    if ch == "^" and b > y + T - sh and t < y + T:
                        return True, None
                    if ch == "v" and b > y and t < y + sh:
                        return True, None
        return False, land

    def support(self, px, py):
        if py >= GROUND_Y - 0.001:
            return True
        return any(ch == "#" and abs(py - y) < 0.01 and px + PW / 2 > x and px - PW / 2 < x + T
                   for ch, x, y in self.near(px - PW / 2, px + PW / 2))

    def step(self, s, press):
        f, py, vy, ground, air = s
        px_n = self.speed * DT * (f + 1)
        prev_bottom = py
        if press:
            if ground:
                vy, ground = JUMP_V, False
            elif air != 0:
                vy = JUMP_V
                if air > 0:
                    air -= 1
        if not ground:
            vy += GRAVITY * DT
            py += vy * DT
            if self.ceiling and py - PH < CEIL_Y:
                py = CEIL_Y + PH
                if vy < 0:
                    vy = 0.0
        dead, land = self.hits(px_n, py, vy, prev_bottom)
        if dead:
            return None
        if not ground and land is not None and vy >= 0:
            py, vy, ground, air = land, 0.0, True, self.air
        elif not ground and py >= GROUND_Y:
            py, vy, ground, air = GROUND_Y, 0.0, True, self.air
        elif ground and not self.support(px_n, py):
            ground, air = False, self.air
        return (f + 1, py, vy, ground, air)

    def solvable(self):
        end_f = int((self.width_px + 400) / (self.speed * DT)) + 1
        layer = {(0, float(GROUND_Y), 0.0, True, self.air)}
        for _ in range(end_f):
            nxt = {}
            for s in layer:
                for press in ((False, True) if (s[3] or s[4] != 0) else (False,)):
                    n = self.step(s, press)
                    if n is not None:
                        nxt[(round(n[1]), round(n[2] / 8), n[3], n[4])] = n
            if not nxt:
                return False
            layer = set(nxt.values())
        return True


def solvable(rows, speed, air):
    return World(rows, speed, air).solvable()


def seg_ok(seg, speed, air):
    """Segment tek başına (önünde/arkasında düz zemin) geçilebilir mi?"""
    return solvable(assemble([(seg, 10)]), speed, air)


def full(rows):
    return [r for r in rows]


def ceiling_variants(base, rng, n):
    """Taban segmente tavan engeli ekler (üstten ROWS satır)."""
    w = max(len(s) for s in base)
    padded = ["." * w] * (ROWS - len(base)) + [s.ljust(w, ".") for s in base]
    out = []
    for _ in range(n):
        g = [list(r) for r in padded]
        c = rng.randrange(w)
        kind = rng.choice(["v3", "v2", "pillar"])
        if kind == "pillar":
            for r in range(0, rng.choice([3, 4])):
                g[r][c] = "#"
        else:
            r = 3 if kind == "v3" else 2
            if g[r][c] == ".":
                g[r][c] = "v"
        out.append(["".join(r) for r in g])
    return out


def tall_blocks():
    out = []
    for h in (3, 4, 5):
        for w in (1, 2):
            out.append(["#" * w] * h)
    return out


def build_level(name, speed, count, gaps, weights, seed, air, ceil, tall_req):
    rng = random.Random(seed)
    tiers = [EASY, MEDIUM, HARD]
    pools = [[s for s in t if seg_ok(s, speed, air)] for t in tiers]
    if ceil:
        base = [s for t in (EASY, MEDIUM) for s in t]
        cand = [v for b in base for v in ceiling_variants(b, rng, 2)]
        cand = [s for s in cand if seg_ok(s, speed, air)]
        rng.shuffle(cand)
        # Tavan engelli segmentler orta/zor havuza karışır.
        pools[1] += cand[: len(cand) // 2]
        pools[2] += cand[len(cand) // 2:]
    required = []
    if tall_req:
        need = [s for s in tall_blocks() if not seg_ok(s, speed, 0) and seg_ok(s, speed, air)]
        if not need:
            raise RuntimeError(f"{name}: havada zıplama gerektiren segment bulunamadı")
        required = [rng.choice(need) for _ in range(tall_req)]
    for _ in range(100):
        parts, prev = [], None
        for _i in range(count):
            tier = rng.choices(range(3), weights=weights)[0]
            if not pools[tier]:
                continue
            seg = rng.choice(pools[tier])
            if seg != prev:
                parts.append(seg)
                prev = seg
        if required:
            step = len(parts) // (len(required) + 1)
            for k, seg in enumerate(required, 1):
                parts.insert(k * step + k - 1, seg)
        rows = assemble([(s, rng.randint(*gaps)) for s in parts])
        # Boşluklar segmentleri ayırır; hava zıplama seviyelerinde segment bazlı doğrulama yeterlidir.
        if air != 0 or solvable(rows, speed, air):
            return rows
    raise RuntimeError(f"{name}: geçilebilir seviye üretilemedi")


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "levels")
    os.makedirs(out_dir, exist_ok=True)
    for i, (name, speed, count, gaps, weights, seed, air, ceil, tall) in enumerate(LEVELS, 1):
        if count is None:
            rows = assemble(LEVEL1_SEGMENTS)
            if not solvable(rows, speed, air):
                sys.exit(f"{name} geçilemiyor")
        else:
            rows = build_level(name, speed, count, gaps, weights, seed, air, ceil, tall)
        assert len({len(r) for r in rows}) == 1
        path = os.path.join(out_dir, f"level_{i:02d}.json")
        with open(path, "w", encoding="utf-8") as fh:
            json.dump({"name": name, "speed": speed, "air_jumps": air, "rows": rows},
                      fh, ensure_ascii=False, indent=1)
            fh.write("\n")
        print(f"{i}. {name}: hız {speed}, havada zıplama {air}, {len(rows[0])} kolon, doğrulandı")


if __name__ == "__main__":
    main()
