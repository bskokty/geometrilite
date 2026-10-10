#!/usr/bin/env python3
"""Sonsuz seviye sistemi için doğrulanmış engel parçası havuzlarını üretir (levels/segments.json).

Oyun (scripts/game.gd) her seviye numarasını bu havuzlardan, seviye numarasına göre
deterministik biçimde kurar. Her parça, o seviyenin hız ve havada zıplama ayarıyla,
önünde ve arkasında düz zemin varken tek başına geçilebilir olacak şekilde
scripts/game.gd ile aynı sabit adımlı fizikte simüle edilerek doğrulanır.
Parçalar arasındaki boşluk, zıplama menzilinden büyük tutulduğu için parçalar birbirinden
bağımsız geçilebilir.

Karakterler: '.' boş, '#' blok, '^' yer dikeni, 'v' tavan dikeni.

Kullanım:  python3 tools/gen_segments.py
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

PROFILE_LEVELS = 12                 # bu seviyeden sonra ayarlar sabit kalır, parça sayısı artar
START_EMPTY = 12
SPEEDS = [420 + 25 * i for i in range(PROFILE_LEVELS)]
AIR = [0, 0, 0, 0, 0, 1, 1, 2, 3, -1, -1, -1]
WEIGHTS = [None, (4, 2, 0), (3, 3, 0), (2, 3, 1), (2, 3, 2), (1, 3, 2), (1, 3, 3),
           (1, 2, 3), (0, 2, 4), (0, 2, 5), (0, 2, 5), (0, 1, 6)]
COUNTS = [0, 10, 12, 13, 14, 15, 16, 18, 19, 20, 21, 22]
TALL = [0, 0, 0, 0, 0, 2, 2, 3, 3, 4, 4, 4]
# Giriş seviyesi: yavaş, tek zıplamayla kolay, geniş boşluklu; sabit dizilim.
# Yalnızca zamanlama toleransı >= EASY_MS olan parçalar (tek diken, 1 yüksek bloklar, aralıklı diken çifti).
LEVEL1_FIXED = [
    (["^"], 9), (["^"], 9), (["##"], 9), (["^....^"], 9), (["###"], 9),
    (["^"], 9), (["^......^"], 9), (["##"], 9), (["^"], 7),
]
# İlk seviyelerde yalnızca bu sade, tek hamlelik parçalar kullanılır (ilk engeline göre ölçülen tolerans
# birleşik parçalardaki ikinci engelin zorluğunu göstermez). İki yüksek blok 4. seviyeden önce çıkmaz.
SIMPLE = [["^"], ["##"], ["###"], ["^....^"], ["^......^"]]
WHITELIST = {2: SIMPLE, 3: SIMPLE + [["##..##..##"], ["###...^"]]}
EASY_MS = 230      # bu toleransın üstü "kolay"
MEDIUM_MS = 150    # bu toleransın üstü "orta", altı "zor"
MAX_PER_TIER = 12


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


def solvable_from(world, state):
    """Verilen durumdan seviyenin sonuna kadar (mükemmel oyunla) hayatta kalınabilir mi?"""
    end_f = int((world.width_px + 400) / (world.speed * DT)) + 1
    layer = {(round(state[1]), round(state[2] / 8), state[3], state[4]): state}
    for _ in range(end_f - state[0]):
        nxt = {}
        for s in layer.values():
            for press in ((False, True) if (s[3] or s[4] != 0) else (False,)):
                n = world.step(s, press)
                if n is not None:
                    nxt[(round(n[1]), round(n[2] / 8), n[3], n[4])] = n
        if not nxt:
            return False
        layer = nxt
    return True


def window_ms(seg, speed):
    """İlk engeli geçmek için zıplama zamanlamasının toleransı (ms), havada zıplama olmadan.

    Zemindeki küp bir kare kalkış yaparsa ve ilk engelin önünde değil ötesinde inip
    (sonrasında mükemmel oyunla) segmenti bitirebiliyorsa o kalkış anı "geçerli" sayılır.
    Çok erken zıplayıp engelden önce inmek sayılmaz. Değer ne kadar büyükse segment o kadar
    bağışlayıcıdır; 0 = tek zıplamayla başlanamaz/geçilemez.
    """
    rows = assemble([(seg, 8)])
    world = World(rows, speed, 0)
    cols = [c for c in range(len(rows[0])) if any(rows[r][c] in "#^v" for r in range(ROWS))]
    xl, xr = min(cols) * T, (max(cols) + 1) * T
    ok = 0
    for f in range(max(0, int((xl - 450) / (speed * DT))), int(xr / (speed * DT)) + 1):
        s = (f, float(GROUND_Y), 0.0, True, 0)
        s = world.step(s, True)
        while s is not None and not s[3]:
            s = world.step(s, False)
        if s is None:
            continue
        landing_x = speed * DT * s[0]
        if s[1] >= GROUND_Y - 1 and landing_x < xl - 10:
            continue  # engelden önce yere indi: zorluğu temsil etmez
        if solvable_from(world, s):
            ok += 1
    return ok * 1000.0 / 60.0


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


def pools_for(level, rng):
    """Parçaları, o seviyenin hızındaki zamanlama toleransına göre kolay/orta/zor diye ayırır."""
    speed, air = SPEEDS[level - 1], AIR[level - 1]
    cands = [s for t in (EASY, MEDIUM, HARD) for s in t]
    if level >= 4:
        base = [s for t in (EASY, MEDIUM) for s in t]
        cands += [v for b in base for v in ceiling_variants(b, rng, 1) if clearance_ok(v)]
    tiers = {"easy": [], "medium": [], "hard": []}
    seen = set()
    for seg in cands:
        key = tuple(seg)
        if key in seen or not seg_ok(seg, speed, air):
            continue
        seen.add(key)
        ms = window_ms(seg, speed)
        tiers["easy" if ms >= EASY_MS else "medium" if ms >= MEDIUM_MS else "hard"].append(seg)
    tall = []
    if TALL[level - 1]:
        tall = [s for s in tall_blocks() if not seg_ok(s, speed, 0) and seg_ok(s, speed, air)]
        if not tall:
            raise RuntimeError(f"seviye {level}: havada zıplama gerektiren parça yok")
    out = {}
    for name in ("easy", "medium", "hard"):
        rng.shuffle(tiers[name])
        out[name] = tiers[name][:MAX_PER_TIER]
    out["tall"] = tall
    return out


MIN_WINDOW_MS = 100   # bundan dar zamanlama toleranslı (insan için fazla keskin) parça kullanılmaz
MIN_CLEARANCE = 2 * T   # tavan engeli ile yakınındaki zemin engeli arasında en az 2 kutu boşluk (küp 56 px)


def _rows6(seg):
    w = max(len(r) for r in seg)
    return ["." * w] * (ROWS - len(seg)) + [r.ljust(w, ".") for r in seg]


def clearance_ok(seg):
    """Tavandan sarkan bir engelin altından geçilecek dikey boşluk, insanlar için yeterli mi?

    Simülatör mikro zamanlamayla dar boşlukları 'geçilebilir' sayabilir; bu süzgeç, tavan engeli ile
    aynı veya komşu kolondaki zemin engeli arasında en az MIN_CLEARANCE piksel boşluk ister.
    """
    rows = _rows6(seg)
    w = len(rows[0])
    ceil_bottom, floor_top = {}, {}
    for c in range(w):
        k = 0
        while k < ROWS and rows[k][c] == "#":
            k += 1
        if k:
            ceil_bottom[c] = CEIL_Y + k * T
        for r in range(ROWS):
            ch = rows[r][c]
            if ch == "v":
                ceil_bottom[c] = min(ceil_bottom.get(c, 1e9), CEIL_Y + r * T + T * SPIKE_H) if c in ceil_bottom else CEIL_Y + r * T + T * SPIKE_H
            elif ch == "^":
                floor_top[c] = min(floor_top.get(c, 1e9), CEIL_Y + (r + 1) * T - T * SPIKE_H)
            elif ch == "#" and r >= k:
                floor_top[c] = min(floor_top.get(c, 1e9), CEIL_Y + r * T)
    for c, yb in ceil_bottom.items():
        for dc in (-1, 0, 1):
            yt = floor_top.get(c + dc)
            if yt is not None and yt - yb < MIN_CLEARANCE:
                return False
    return True


def drop_unfair(levels):
    """Havuzlardan, dikey boşluğu insanlar için fazla dar olan parçaları çıkarır."""
    removed = 0
    for prof in levels:
        for tier, pool in prof.get("pools", {}).items():
            keep = [seg for seg in pool if clearance_ok(seg)
                    and (tier == "tall" or window_ms(seg, prof["speed"]) >= MIN_WINDOW_MS)]
            removed += len(pool) - len(keep)
            prof["pools"][tier] = keep
    return removed


def apply_whitelist(levels):
    """WHITELIST'teki seviyelerde havuzu sade parçalarla sınırlar, ağırlıkları yalnızca kolaya çevirir."""
    for lv, allowed in WHITELIST.items():
        prof = levels[lv - 1]
        everything = [seg for tier in ("easy", "medium", "hard") for seg in prof["pools"].get(tier, [])]
        keep = [seg for seg in everything if seg in allowed]
        missing = [seg for seg in allowed if seg not in keep]
        if missing:
            raise RuntimeError(f"seviye {lv}: sade parça havuzda yok: {missing}")
        prof["pools"] = {"easy": keep, "medium": [], "hard": [], "tall": []}
        prof["weights"] = [1, 0, 0]


def profile(level):
    speed, air = SPEEDS[level - 1], AIR[level - 1]
    gap_min = -(-int(4.25 * speed / 520 * 100) // 100) + 2  # menzil + 2 kolon
    prof = {
        "speed": speed, "air": air, "ceil": level >= 4,
        "gaps": [gap_min, gap_min + 3],
        "weights": list(WEIGHTS[level - 1] or (1, 0, 0)),
        "count": COUNTS[level - 1], "tall": TALL[level - 1],
    }
    if level == 1:
        prof["fixed"] = [[seg, gap] for seg, gap in LEVEL1_FIXED]
    return prof


def build_profile(level):
    rng = random.Random(1000 + level)
    prof = profile(level)
    if level == 1:
        rows = assemble(LEVEL1_FIXED)
        if not solvable(rows, prof["speed"], 0):
            raise RuntimeError("seviye 1 geçilemiyor")
        prof["pools"] = {}
    else:
        prof["pools"] = pools_for(level, rng)
    return level, prof


def main():
    import multiprocessing
    out_path = os.path.join(os.path.dirname(__file__), "..", "levels", "segments.json")
    with multiprocessing.Pool(min(4, os.cpu_count() or 1)) as pool:
        results = dict(pool.imap_unordered(build_profile, range(1, PROFILE_LEVELS + 1)))
    levels = [results[i] for i in range(1, PROFILE_LEVELS + 1)]
    apply_whitelist(levels)
    drop_unfair(levels)
    for i, prof in enumerate(levels, 1):
        sizes = {k: len(v) for k, v in prof["pools"].items()}
        print(f"seviye {i}: hız {prof['speed']}, havada zıplama {prof['air']}, boşluk {prof['gaps']}, havuz {sizes}")
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump({"version": 1, "start_empty": START_EMPTY, "profile_levels": PROFILE_LEVELS,
                   "levels": levels}, fh, ensure_ascii=False, separators=(",", ":"))
        fh.write("\n")
    print("yazıldı:", os.path.normpath(out_path))


if __name__ == "__main__":
    main()
