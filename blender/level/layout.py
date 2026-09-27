"""군도 레벨 설계: 섬 높이맵/재질, 건물·식생 배치, 산책로, 연락선 항로, 적 스폰, 분위기 구역.

좌표는 Blender 월드(XY 평면, Z=높이, +Y=북쪽) 로 설계하고 내보낼 때 Roblox 로 변환한다.
    Roblox (x, y, z) = (x_b, z_b, -y_b),  yaw 동일.

실행:  python blender/level/layout.py      -> src/ 아래 Luau 데이터 모듈 생성
"""

import json
import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))

from noise_np import Noise2D, smoothstep, lerp  # noqa: E402

ROOT = HERE.parents[1]
MANIFEST = json.loads((ROOT / "assets" / "manifest.json").read_text())
OUT_DIR = ROOT / "src" / "ReplicatedStorage" / "Shared" / "World" / "Generated"

CELL = 4.0
SEA_FLOOR = -36.0
DECK = 7.0
MAT_NAMES = ["Sand", "Mud", "Ground", "LeafyGrass", "Grass", "Rock", "Slate", "Pebble", "Limestone"]
M = {n: i for i, n in enumerate(MAT_NAMES)}
ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"

N = Noise2D(20260927)
N2 = Noise2D(777)


# ─────────────────────────────────────────────────────────────
# 유틸
# ─────────────────────────────────────────────────────────────

def disk(X, Y, cx, cy, r, feather):
    d = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2)
    return 1.0 - smoothstep(r, r + feather, d)


def rect(X, Y, x0, x1, y0, y1, feather):
    fx = smoothstep(x0 - feather, x0, X) * (1 - smoothstep(x1, x1 + feather, X))
    fy = smoothstep(y0 - feather, y0, Y) * (1 - smoothstep(y1, y1 + feather, Y))
    return fx * fy


def segment_dist(X, Y, p0, p1):
    ax, ay = p0
    bx, by = p1
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    t = np.clip(((X - ax) * dx + (Y - ay) * dy) / max(L2, 1e-9), 0, 1)
    px, py = ax + t * dx, ay + t * dy
    return np.sqrt((X - px) ** 2 + (Y - py) ** 2)


def stamp(h, mask, value):
    return h * (1 - mask) + value * mask


def rot2(x, y, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return (x * c - y * s, x * s + y * c)


def marker_local(asset, name):
    """매니페스트 마커(Roblox 로컬) -> Blender 로컬 (x, y, z)."""
    for m in MANIFEST[asset]["markers"]:
        if m["name"] == name:
            p = m["pos"]
            return (p[0], -p[2], p[1])
    raise KeyError(f"{asset}.{name}")


def marker_world(pl, name):
    lx, ly, lz = marker_local(pl["a"], name)
    s = pl.get("s", 1.0)
    rx, ry = rot2(lx * s, ly * s, pl["r"])
    return (pl["p"][0] + rx, pl["p"][1] + ry, pl["p"][2] + lz * s)


class Island:
    def __init__(self, name, x0, x1, y0, y1):
        # Roblox Terrain:WriteVoxels 는 4 stud 격자에 정렬된 Region3 만 허용 → 경계는 4의 배수
        for v in (x0, x1, y0, y1):
            assert v % 4 == 0, f"{name}: 지형 경계 {v} 가 4의 배수가 아님"
        self.name = name
        self.x0, self.y0 = x0, y0
        self.nx = int(round((x1 - x0) / CELL))
        self.ny = int(round((y1 - y0) / CELL))
        xs = x0 + (np.arange(self.nx) + 0.5) * CELL
        ys = y0 + (np.arange(self.ny) + 0.5) * CELL
        self.X, self.Y = np.meshgrid(xs, ys)   # [ny, nx]
        self.h = None
        self.mat = None

    def edge_fade(self, width=24.0):
        """그리드 경계는 바다 바닥과 정확히 일치하도록."""
        X, Y = self.X, self.Y
        x1 = self.x0 + self.nx * CELL
        y1 = self.y0 + self.ny * CELL
        d = np.minimum.reduce([X - self.x0, x1 - X, Y - self.y0, y1 - Y])
        f = smoothstep(0, width, d)
        self.h = SEA_FLOOR + (self.h - SEA_FLOOR) * f

    def sample(self, x, y):
        fx = (x - self.x0) / CELL - 0.5
        fy = (y - self.y0) / CELL - 0.5
        i = int(np.clip(np.floor(fx), 0, self.nx - 2))
        j = int(np.clip(np.floor(fy), 0, self.ny - 2))
        tx, ty = np.clip(fx - i, 0, 1), np.clip(fy - j, 0, 1)
        h = self.h
        return float((h[j, i] * (1 - tx) + h[j, i + 1] * tx) * (1 - ty) + (h[j + 1, i] * (1 - tx) + h[j + 1, i + 1] * tx) * ty)

    def contains(self, x, y, margin=0):
        return self.x0 + margin <= x <= self.x0 + self.nx * CELL - margin and self.y0 + margin <= y <= self.y0 + self.ny * CELL - margin

    def slope(self):
        gy, gx = np.gradient(self.h, CELL)
        return np.sqrt(gx * gx + gy * gy)

    def assign_materials(self, beach_r=None):
        h = self.h
        sl = self.slope()
        mat = np.full(h.shape, M["Mud"], dtype=np.int32)
        mat[h < -6] = M["Sand"]
        mat[(h >= -6) & (h < 0.6)] = M["Mud"]
        mat[(h >= 0.6) & (h < 1.6)] = M["Ground"]
        mat[(h >= 1.6) & (h < 7)] = M["LeafyGrass"]
        mat[h >= 7] = M["Grass"]
        mat[(sl > 0.9) & (h > 2)] = M["Rock"]
        mat[(h >= 16)] = M["Slate"]
        self.mat = mat
        return mat

    def encode(self):
        """행 단위 문자열 목록. Roblox Z 순서: k=0 은 가장 북쪽(Blender y 최대) 행.
        높이: 셀당 2문자 (0.1 stud 정밀도).  재질: RLE (재질문자 + (길이-1)문자, 최대 64)."""
        hq = np.clip(np.round((self.h + 64.0) * 10.0), 0, 4095).astype(np.int32)
        hs, ms = [], []
        for k in range(self.ny):
            j = self.ny - 1 - k
            row_h = hq[j]
            row_m = self.mat[j]
            hs.append("".join(ALPHA[v >> 6] + ALPHA[v & 63] for v in row_h))
            runs = []
            i = 0
            while i < len(row_m):
                v = int(row_m[i])
                n = 1
                while i + n < len(row_m) and int(row_m[i + n]) == v and n < 64:
                    n += 1
                runs.append(ALPHA[v] + ALPHA[n - 1])
                i += n
            ms.append("".join(runs))
        return hs, ms

    def roblox_origin(self):
        return (self.x0, -(self.y0 + self.ny * CELL))


# ─────────────────────────────────────────────────────────────
# 1) 안개늪 섬 (Mistmire)
# ─────────────────────────────────────────────────────────────

SW_C = (700.0, 0.0)
SW_R = (470.0, 390.0)

# 산책로(보드워크) 폴리라인 — 데크 높이 7
VILLAGE_PATHS = [
    [(312, 0), (374, 0), (435.7, 0)],
    [(374, 0), (374, 46)],
    [(374, 46), (540, 46)],
    [(540, 46), (540, 0), (484.3, 0)],
    [(374, 0), (374, -46)],
    [(374, -46), (540, -46)],
    [(460, -46), (460, -18.3)],
    [(540, -46), (540, 0)],
    [(540, 46), (600, 46)],
    [(636, 46), (700, 80), (780, 120)],
    [(540, -46), (640, -46), (700, -100)],
]
JUNCTIONS = [(374, 0), (374, 46), (540, 46), (540, 0), (374, -46), (540, -46), (460, -46), (640, -46), (700, 80)]
RAMPS = [  # (상단 끝점, 하단 방향 끝점) — 경사로는 상단에서 하단 쪽으로 16 stud
    ((312, 0), (296, 0)),
    ((780, 120), (796, 128)),
    ((700, -100), (712, -111)),
]
BRIDGES = [((600, 46), (636, 46))]


def build_swamp():
    isl = Island("Mistmire", 88, 1312, -520, 520)
    X, Y = isl.X, isl.Y
    lx, ly = X - SW_C[0], Y - SW_C[1]
    r = np.sqrt((lx / SW_R[0]) ** 2 + (ly / SW_R[1]) ** 2)
    r = r + 0.07 * N.fbm(X / 240, Y / 240, 4)
    # 바다 선반
    sea = lerp(-1.6, SEA_FLOOR, smoothstep(1.0, 1.3, r))
    # 해안/내륙
    beach = lerp(1.6, -1.6, smoothstep(0.9, 1.0, r))
    mosaic = 0.05 + 2.2 * N.fbm(X / 85, Y / 85, 5) + 0.7 * N2.fbm(X / 22, Y / 22, 3)
    hummock = 3.2 * np.clip(N2.fbm(X / 48 + 11, Y / 48 - 7, 4) - 0.12, 0, None) * 2.2
    interior = mosaic + hummock
    hills = 17.0 * smoothstep(190, 330, ly) * (0.55 + 0.45 * N.fbm(X / 70, Y / 70, 4)) * (1 - smoothstep(0.82, 0.97, r))
    ridge = 9.0 * np.clip(N.ridged(X / 120, Y / 120) - 0.55, 0, None) * 3 * (1 - smoothstep(0.75, 0.95, r)) * smoothstep(60, 200, ly)
    land = lerp(beach, interior + hills + ridge, smoothstep(0.97, 0.84, r))
    h = np.where(r > 1.0, sea, land)
    h = np.where((r > 0.97) & (r <= 1.0), np.minimum(land, beach), h)

    # ── 스탬프 ──
    # 마을 얕은 연못 (수상 가옥 아래)
    ev = ((X - 448) / 138) ** 2 + (Y / 112) ** 2 + 0.28 * N2.fbm(X / 60, Y / 60, 3)
    vil = 1 - smoothstep(0.85, 1.15, ev)
    h = stamp(h, vil, -1.9 + 0.35 * N2.fbm(X / 30, Y / 30))
    # 선착장 해변 + 마을 경사로까지 모래 길
    h = stamp(h, rect(X, Y, 222, 300, -16, 16, 14), 1.25)
    h = stamp(h, disk(X, Y, 233, 0, 10, 10), 1.25)
    # 감시탑 둔덕
    h = stamp(h, disk(X, Y, 300, 130, 14, 16), 1.8)
    # 어부 오두막 물웅덩이
    h = stamp(h, disk(X, Y, 270, -120, 16, 14), -1.7)
    # 흔들다리 아래 수로
    h = stamp(h, rect(X, Y, 598, 638, 10, 82, 10), -3.2)
    # 동쪽 경사로 착지 + 마녀 오두막으로 가는 둑길
    h = stamp(h, disk(X, Y, 796, 128, 7, 8), 1.25)
    d = segment_dist(X, Y, (796, 128), (872, 118))
    h = stamp(h, 1 - smoothstep(6, 12, d), 0.9 + 0.3 * N2.fbm(X / 20, Y / 20))
    # 마녀 오두막 연못
    h = stamp(h, disk(X, Y, 880, 150, 24, 14), -1.9)
    h = stamp(h, disk(X, Y, 880, 122, 6, 6), 0.3)
    # 남동 경사로 착지 + 사당으로 가는 둑길
    h = stamp(h, disk(X, Y, 712, -111, 7, 8), 1.25)
    for (p0, p1) in (((712, -111), (790, -200)), ((790, -200), (880, -262)), ((880, -262), (900, -248))):
        d = segment_dist(X, Y, p0, p1)
        h = np.maximum(h, stamp(h, 1 - smoothstep(7, 13, d), 0.7 + 0.25 * N2.fbm(X / 18, Y / 18)))
    # 사당 해자 (기단 주변 물)
    moat = disk(X, Y, 900, -200, 50, 10)
    h = stamp(h, moat, -1.8)
    h = stamp(h, disk(X, Y, 900, -248, 7, 5), -0.8)
    isl.h = h
    isl.edge_fade()
    isl.assign_materials()
    # 해변 모래
    beachmask = (r > 0.86) & (r < 1.06) & (isl.h > -4) & (isl.h < 3.0)
    isl.mat[beachmask] = M["Sand"]
    isl.mat[(rect(X, Y, 222, 300, -16, 16, 0) > 0.5)] = M["Sand"]
    # 둑길 = Ground/Pebble
    for (p0, p1) in (((712, -111), (790, -200)), ((790, -200), (880, -262)), ((796, 128), (872, 118))):
        d = segment_dist(X, Y, p0, p1)
        isl.mat[(d < 6) & (isl.h > 0)] = M["Pebble"]
    return isl


# ─────────────────────────────────────────────────────────────
# 2) 항구섬 (Harbor)
# ─────────────────────────────────────────────────────────────

HB_C = (-900.0, 0.0)
HB_R = (285.0, 240.0)


def build_harbor():
    isl = Island("Harbor", -1280, -500, -360, 360)
    X, Y = isl.X, isl.Y
    lx, ly = X - HB_C[0], Y - HB_C[1]
    r = np.sqrt((lx / HB_R[0]) ** 2 + (ly / HB_R[1]) ** 2) + 0.06 * N.fbm(X / 200 + 40, Y / 200, 4)
    sea = lerp(-1.6, SEA_FLOOR, smoothstep(1.0, 1.3, r))
    beach = lerp(2.0, -1.6, smoothstep(0.88, 1.0, r))
    hills = 3.0 + 16.0 * (1 - smoothstep(0.0, 0.9, r)) * (0.55 + 0.45 * N.fbm(X / 110, Y / 110, 4)) + 1.5 * N2.fbm(X / 30, Y / 30, 3)
    land = lerp(beach, hills, smoothstep(0.96, 0.8, r))
    h = np.where(r > 1.0, sea, land)
    # 광장 평탄화 + 부두 해변 길
    h = stamp(h, disk(X, Y, -705, 0, 42, 22), 3.0)
    h = stamp(h, rect(X, Y, -660, -612, -14, 14, 16), lerp(1.25, 3.0, smoothstep(-620, -662, X)))
    h = stamp(h, disk(X, Y, -618, 0, 8, 8), 1.25)
    # 감시탑 언덕 정상 평탄화
    h = stamp(h, disk(X, Y, -830, 140, 10, 12), h[np.unravel_index(np.argmin(np.abs(X - -830) + np.abs(Y - 140)), X.shape)])
    # 남쪽 어촌 물웅덩이
    h = stamp(h, disk(X, Y, -880, -228, 18, 12), -1.6)
    isl.h = h
    isl.edge_fade()
    isl.assign_materials()
    isl.mat[(r > 0.86) & (r < 1.06) & (isl.h > -4) & (isl.h < 3.2)] = M["Sand"]
    isl.mat[(disk(X, Y, -705, 0, 40, 0) > 0.5)] = M["Pebble"]
    isl.mat[(rect(X, Y, -660, -612, -8, 8, 0) > 0.5)] = M["Pebble"]
    return isl


# ─────────────────────────────────────────────────────────────
# 3) 등대 바위섬
# ─────────────────────────────────────────────────────────────

LH_C = (-80.0, 330.0)


def build_lighthouse_rock():
    isl = Island("LighthouseRock", -220, 60, 188, 468)
    X, Y = isl.X, isl.Y
    d = np.sqrt((X - LH_C[0]) ** 2 + (Y - LH_C[1]) ** 2) + 10 * N.fbm(X / 40, Y / 40, 4)
    cliff = lerp(6.0, -4.0, smoothstep(34, 46, d))
    sea = lerp(-4.0, SEA_FLOOR, smoothstep(46, 110, d))
    h = np.where(d < 46, cliff, sea)
    h = h + 1.5 * N2.fbm(X / 12, Y / 12, 3) * (d < 44)
    h = stamp(h, disk(X, Y, LH_C[0], LH_C[1], 16, 6), 6.0)
    # 난파선 모래톱
    bank = disk(X, Y, -10, 425, 22, 26)
    h = np.maximum(h, stamp(h, bank, -3.2 + 1.0 * N2.fbm(X / 15, Y / 15)))
    # 바위 암초
    for (cx, cy, rr) in ((-150, 290, 12), (40, 380, 10), (-165, 400, 14)):
        h = np.maximum(h, 4.0 * (1 - smoothstep(0, rr, np.sqrt((X - cx) ** 2 + (Y - cy) ** 2))) + (h - 0.0) * 0 - 2.0 + 4 * N2.fbm(X / 8, Y / 8) * (np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) < rr))
    isl.h = h
    isl.edge_fade()
    isl.assign_materials()
    isl.mat[(isl.h > -2) & (d < 50)] = M["Rock"]
    isl.mat[(isl.h > 4.5) & (d < 20)] = M["Slate"]
    isl.mat[(bank > 0.3)] = M["Sand"]
    return isl


# ─────────────────────────────────────────────────────────────
# 배치
# ─────────────────────────────────────────────────────────────

class Placer:
    def __init__(self, islands, seed=5):
        self.islands = islands
        self.items = []
        self.rng = np.random.default_rng(seed)
        self.blockers = []   # (x, y, r)
        self.path_segs = []

    def height(self, x, y):
        for isl in self.islands:
            if isl.contains(x, y, 6):
                return isl.sample(x, y)
        return SEA_FLOOR

    def add(self, asset, x, y, z=None, yaw=0.0, scale=1.0, block=None, island=None):
        if asset not in MANIFEST:
            raise KeyError(asset)
        if z is None:
            z = self.height(x, y)
        pl = {"a": asset, "p": (float(x), float(y), float(z)), "r": float(yaw), "s": float(scale)}
        if island:
            pl["i"] = island
        self.items.append(pl)
        if block:
            self.blockers.append((x, y, block))
        return pl

    def blocked(self, x, y, r):
        for (bx, by, br) in self.blockers:
            if (x - bx) ** 2 + (y - by) ** 2 < (r + br) ** 2:
                return True
        for (p0, p1, w) in self.path_segs:
            if float(segment_dist(np.array(x), np.array(y), p0, p1)) < w + r:
                return True
        return False

    def boardwalk(self, pts, island):
        for p0, p1 in zip(pts[:-1], pts[1:]):
            dx, dy = p1[0] - p0[0], p1[1] - p0[1]
            L = math.hypot(dx, dy)
            yaw = math.degrees(math.atan2(dy, dx))
            n = max(1, math.ceil((L - 1.0) / 16.0))
            step = L / n
            for k in range(n):
                t = (k + 0.5) * step / L
                x, y = p0[0] + dx * t, p0[1] + dy * t
                variant = "BoardwalkStraightB" if self.rng.random() < 0.22 else "BoardwalkStraight"
                self.add(variant, x, y, 0.0, yaw, island=island)
            self.path_segs.append((p0, p1, 8.0))

    def scatter(self, asset_choices, region_fn, count, min_r, height_ok, island, z_mode="terrain", yaw_rand=True, scale=(0.85, 1.2), tries=40000, z_offset=0.0, block_r=None):
        placed = 0
        pts = []
        isl = next(i for i in self.islands if i.name == island)
        x0, x1 = isl.x0, isl.x0 + isl.nx * CELL
        y0, y1 = isl.y0, isl.y0 + isl.ny * CELL
        for _ in range(tries):
            if placed >= count:
                break
            x = self.rng.uniform(x0, x1)
            y = self.rng.uniform(y0, y1)
            if not region_fn(x, y):
                continue
            h = isl.sample(x, y)
            if not height_ok(h):
                continue
            if any((x - px) ** 2 + (y - py) ** 2 < min_r * min_r for px, py in pts):
                continue
            if self.blocked(x, y, min_r * 0.5):
                continue
            asset = asset_choices[self.rng.integers(len(asset_choices))]
            z = 0.0 if z_mode == "water" else h
            s = float(self.rng.uniform(*scale))
            self.add(asset, x, y, z + z_offset, float(self.rng.uniform(0, 360)) if yaw_rand else 0.0, s, island=island)
            if block_r:
                self.blockers.append((x, y, block_r * s))
            pts.append((x, y))
            placed += 1
        return placed


def swamp_layout(P):
    I = "Mistmire"
    # 선착장
    dock = P.add("FerryDock", 215, 0, 0.0, 0, block=60, island=I)
    # 주점 & 가옥
    P.add("Longhouse", 460, 0, 0.0, 0, block=30, island=I)
    P.add("StiltHouseA", 398, 60.8, 0.0, 0, block=16, island=I)
    P.add("StiltHouseB", 452, 59.8, 0.0, 0, block=16, island=I)
    P.add("StiltHutC", 506, 58.8, 0.0, 0, block=14, island=I)
    P.add("StiltHouseB", 398, -59.8, 0.0, 180, block=16, island=I)
    P.add("StiltHouseA", 514, -60.8, 0.0, 180, block=16, island=I)
    # 시장 광장
    P.add("DeckPlatform", 440, -61.3, 0.0, 0, block=16, island=I)
    P.add("DeckPlatform", 464, -61.3, 0.0, 0, block=16, island=I)
    P.add("MarketStallA", 440, -66.5, DECK, 180, island=I)
    P.add("MarketStallB", 465, -66.5, DECK, 180, island=I)
    P.add("NoticeBoard", 452.5, -71.5, DECK, 180, island=I)
    P.add("Bench", 452.5, -55.5, DECK, 0, island=I)
    # 산책로
    for pts in VILLAGE_PATHS:
        P.boardwalk(pts, I)
    for (x, y) in JUNCTIONS:
        P.add("BoardwalkJunction", x, y, 0.0, 0, island=I)
    for (top, low) in RAMPS:
        dx, dy = low[0] - top[0], low[1] - top[1]
        L = math.hypot(dx, dy)
        yaw = math.degrees(math.atan2(dy, dx))
        cx, cy = top[0] + dx / L * 8, top[1] + dy / L * 8
        P.add("BoardwalkRamp", cx, cy, 0.0, yaw, island=I)
        P.path_segs.append((top, (top[0] + dx / L * 16, top[1] + dy / L * 16), 8.0))
    for (p0, p1) in BRIDGES:
        P.add("RopeBridge", (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, 0.0, math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0])), island=I)
        P.path_segs.append((p0, p1, 6.0))
    # 해안/기타 건물
    P.add("Watchtower", 300, 130, P.height(300, 130) - 0.4, 15, block=12, island=I)
    P.add("StiltHutC", 270, -120, 0.0, 200, block=14, island=I)
    P.add("FishRack", 292, -104, P.height(292, -104), 110, block=7, island=I)
    P.add("Rowboat", 256, -100, 0.0, 70, island=I)
    P.add("Rowboat", 190, 34, 0.0, 95, island=I)
    P.add("Signpost", 290, 12, P.height(290, 12), 180, island=I)
    P.add("TorchPost", 300, -12, P.height(300, -12), 0, island=I)
    P.add("TorchPost", 300, 12, P.height(300, 12), 0, island=I)
    P.add("Campfire", 262, 56, P.height(262, 56), 0, block=10, island=I)
    P.add("CargoPile", 244, -26, P.height(244, -26), 20, block=8, island=I)
    # 마녀 오두막 & 사당
    P.add("WitchHut", 880, 150, 0.0, 0, block=26, island=I)
    P.add("MireShrine", 900, -200, 0.0, 0, block=56, island=I)
    for (x, y, yaw) in ((820, -170, 30), (955, -255, -20), (845, -275, 60), (770, -240, 10)):
        P.add("RuinPillar", x, y, P.height(x, y) - 0.3, yaw, block=5, island=I)
    P.add("RuinArch", 760, -215, P.height(760, -215) - 0.3, 45, block=8, island=I)
    for (x, y) in ((800, -198), (870, -260), (740, -150), (820, 120), (852, 122)):
        P.add("TorchPost", x, y, P.height(x, y), 0, island=I)
    P.add("Shipwreck", 1150, -330, -1.0, 140, island=I)
    # 식생
    def swamp_region(x, y):
        return ((x - SW_C[0]) / SW_R[0]) ** 2 + ((y - SW_C[1]) / SW_R[1]) ** 2 < 0.93 and not (330 <= x <= 560 and -95 <= y <= 95)
    P.scatter(["CypressA", "CypressB", "CypressC"], swamp_region, 70, 26, lambda h: -2.2 < h < 5.5, I, block_r=4)
    P.scatter(["Mangrove"], lambda x, y: 0.8 < ((x - SW_C[0]) / SW_R[0]) ** 2 + ((y - SW_C[1]) / SW_R[1]) ** 2 < 1.05, 22, 30, lambda h: -2.5 < h < 1.0, I, block_r=5)
    P.scatter(["DeadTree"], swamp_region, 16, 40, lambda h: -2.0 < h < 4.0, I, block_r=3)
    P.scatter(["SwampBush"], swamp_region, 50, 12, lambda h: 0.4 < h < 12, I)
    P.scatter(["Reeds"], lambda x, y: ((x - SW_C[0]) / SW_R[0]) ** 2 + ((y - SW_C[1]) / SW_R[1]) ** 2 < 1.0, 70, 10, lambda h: -1.2 < h < 0.5, I)
    P.scatter(["LilyPads"], lambda x, y: ((x - SW_C[0]) / SW_R[0]) ** 2 + ((y - SW_C[1]) / SW_R[1]) ** 2 < 0.95, 45, 16, lambda h: -3.0 < h < -0.7, I, z_mode="water", scale=(0.8, 1.3))
    P.scatter(["FallenLog"], swamp_region, 10, 40, lambda h: 0.3 < h < 3.0, I, block_r=10)
    P.scatter(["GlowMushrooms"], lambda x, y: (x > 700 and swamp_region(x, y)), 18, 30, lambda h: 0.2 < h < 3.0, I)
    return dock


def harbor_layout(P):
    I = "Harbor"
    dock = P.add("FerryDock", -600, 0, 0.0, 180, block=60, island=I)
    P.add("Well", -705, 0, 3.0, 0, block=5, island=I)
    P.add("MarketStallA", -690, 30, 3.0, 0, block=7, island=I)
    P.add("MarketStallB", -722, 30, 3.0, 0, block=7, island=I)
    P.add("NoticeBoard", -690, -30, 3.0, 180, block=5, island=I)
    P.add("Bench", -724, -28, 3.0, 180, island=I)
    P.add("Bench", -740, 0, 3.0, 90, island=I)
    for (x, y) in ((-672, 16), (-672, -16), (-738, 18), (-738, -18)):
        P.add("LampPost", x, y, 3.0, 0, island=I)
    P.add("Signpost", -652, 10, P.height(-652, 10), 0, island=I)
    P.add("CargoPile", -640, 24, P.height(-640, 24), 10, block=8, island=I)
    P.add("CargoPile", -644, -26, P.height(-644, -26), -30, block=8, island=I)
    P.add("Campfire", -640, -95, P.height(-640, -95), 0, block=10, island=I)
    P.add("Rowboat", -628, -58, P.height(-628, -58) + 0.2, 80, island=I)
    P.add("Rowboat", -632, 64, P.height(-632, 64) + 0.2, 100, island=I)
    P.add("Watchtower", -830, 140, P.height(-830, 140) - 0.4, -20, block=12, island=I)
    P.add("StiltHutC", -880, -228, 0.0, 180, block=14, island=I)
    P.add("FishRack", -905, -205, P.height(-905, -205), 20, block=7, island=I)
    P.add("Longhouse", -800, -60, P.height(-800, -60) - 7.2, 90, block=30, island=I)
    for k in range(6):
        x = -752
        y = -60 + k * 13
        P.add("Fence", x, y + 60, P.height(x, y + 60), 90, island=I)

    def region(x, y):
        return ((x - HB_C[0]) / HB_R[0]) ** 2 + ((y - HB_C[1]) / HB_R[1]) ** 2 < 0.85 and ((x + 705) ** 2 + y ** 2) > 60 ** 2
    P.scatter(["BroadleafTree"], region, 38, 30, lambda h: 3 < h < 20, I, block_r=5)
    P.scatter(["SwampBush"], region, 25, 16, lambda h: 2 < h < 20, I)
    P.scatter(["Reeds"], lambda x, y: True, 10, 14, lambda h: -1.0 < h < 0.4, I)
    return dock


def lighthouse_layout(P):
    I = "LighthouseRock"
    P.add("Lighthouse", LH_C[0], LH_C[1], 2.0, 200, block=20, island=I)
    P.add("Shipwreck", -10, 425, -1.0, 30, island=I)
    P.add("Rowboat", -40, 300, 0.2, 40, island=I)


# ─────────────────────────────────────────────────────────────
# 연락선 항로
# ─────────────────────────────────────────────────────────────

def catmull_rom_closed(pts, samples=40, alpha=0.5):
    P = [np.array(p, dtype=float) for p in pts]
    n = len(P)
    out = []
    ctrl_index = []
    for i in range(n):
        p0, p1, p2, p3 = P[(i - 1) % n], P[i], P[(i + 1) % n], P[(i + 2) % n]
        def tj(ti, a, b):
            return ti + max(np.linalg.norm(b - a), 1e-6) ** alpha
        t0 = 0.0
        t1 = tj(t0, p0, p1)
        t2 = tj(t1, p1, p2)
        t3 = tj(t2, p2, p3)
        ctrl_index.append(len(out))
        for k in range(samples):
            t = t1 + (t2 - t1) * k / samples
            A1 = (t1 - t) / (t1 - t0) * p0 + (t - t0) / (t1 - t0) * p1
            A2 = (t2 - t) / (t2 - t1) * p1 + (t - t1) / (t2 - t1) * p2
            A3 = (t3 - t) / (t3 - t2) * p2 + (t - t2) / (t3 - t2) * p3
            B1 = (t2 - t) / (t2 - t0) * A1 + (t - t0) / (t2 - t0) * A2
            B2 = (t3 - t) / (t3 - t1) * A2 + (t - t1) / (t3 - t1) * A3
            C = (t2 - t) / (t2 - t1) * B1 + (t - t1) / (t2 - t1) * B2
            out.append(C)
    return out, ctrl_index


def ferry_route(dock_swamp, dock_harbor):
    ms = marker_world(dock_swamp, "FerryMoor")
    mh = marker_world(dock_harbor, "FerryMoor")
    ctrl = [
        (ms[0], ms[1]), (ms[0], ms[1] + 90), (125, 175), (40, 240), (-120, 250), (-300, 225), (-450, 175), (mh[0], mh[1] + 100),
        (mh[0], mh[1]), (mh[0], mh[1] - 95), (-470, -185), (-330, -250), (-150, -275), (20, -255), (110, -185), (ms[0], ms[1] - 95),
    ]
    dense, idx = catmull_rom_closed(ctrl, samples=60)
    dense.append(dense[0])
    seg = [np.linalg.norm(dense[i + 1] - dense[i]) for i in range(len(dense) - 1)]
    cum = np.concatenate([[0.0], np.cumsum(seg)])
    total = float(cum[-1])
    stop_s = {"Mistmire": float(cum[idx[0]]), "Harbor": float(cum[idx[8]])}
    # 균일 재샘플 (6 stud)
    step = 6.0
    n = int(total // step)
    us = np.linspace(0, total, n, endpoint=False)
    pts = []
    for u in us:
        k = int(np.searchsorted(cum, u, side="right") - 1)
        k = min(k, len(seg) - 1)
        f = (u - cum[k]) / max(seg[k], 1e-9)
        p = dense[k] + (dense[k + 1] - dense[k]) * f
        pts.append((float(p[0]), float(p[1])))
    return pts, total, stop_s


# ─────────────────────────────────────────────────────────────
# 내보내기 (Luau)
# ─────────────────────────────────────────────────────────────

def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def fmt(v, n=2):
    r = round(float(v), n)
    if r == int(r):
        return str(int(r))
    return f"{r}"


def write_luau(path, body):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")
    print("[layout] wrote", path.relative_to(ROOT), f"({len(body) // 1024} KB)")


def export(islands, P, route, extras):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    # 1) 지형
    names = []
    for isl in islands:
        hs, ms = isl.encode()
        ox, oz = isl.roblox_origin()
        body = [
            "--!strict",
            "-- 자동 생성 파일 (blender/level/layout.py). 직접 수정하지 마세요.",
            f"-- 섬: {isl.name}  ({isl.nx} x {isl.ny} 셀, 셀 {int(CELL)} stud)",
            "return {",
            f"\tName = {lua_str(isl.name)},",
            f"\tOriginX = {fmt(ox)},",
            f"\tOriginZ = {fmt(oz)},",
            f"\tCell = {int(CELL)},",
            f"\tNX = {isl.nx},",
            f"\tNZ = {isl.ny},",
            "\tHeightOffset = -64,",
            "\tHeightScale = 0.1,",
            "\t-- 행(Z) 단위: 셀당 2문자 높이",
            "\tHeights = {",
            *[f"\t\t{lua_str(row)}," for row in hs],
            "\t},",
            "\t-- 행(Z) 단위 RLE: (재질, 길이-1) 문자쌍",
            "\tMaterials = {",
            *[f"\t\t{lua_str(row)}," for row in ms],
            "\t},",
            "}",
            "",
        ]
        write_luau(OUT_DIR / f"Terrain_{isl.name}.luau", "\n".join(body))
        names.append(isl.name)
    # 2) 배치
    lines = ["--!strict", "-- 자동 생성 파일 (blender/level/layout.py). 직접 수정하지 마세요.", "-- a=에셋, p=Roblox 위치, r=Y축 회전(도), s=스케일, i=섬", "", "export type Placement = { a: string, p: { number }, r: number, s: number, i: string? }", "", "local Placements: { Placement } = {"]
    for pl in P.items:
        x, y, z = pl["p"]
        isl = f", i = {lua_str(pl['i'])}" if "i" in pl else ""
        lines.append(f"\t{{ a = {lua_str(pl['a'])}, p = {{ {fmt(x)}, {fmt(z)}, {fmt(-y)} }}, r = {fmt(pl['r'], 1)}, s = {fmt(pl['s'], 3)}{isl} }},")
    lines.append("}")
    lines.append("")
    lines.append("return Placements")
    lines.append("")
    write_luau(OUT_DIR / "Placements.luau", "\n".join(lines))
    # 3) 항로
    pts, total, stops = route
    body = ["--!strict", "-- 자동 생성 파일 (blender/level/layout.py). 직접 수정하지 마세요.", "-- 연락선 순환 항로: 6 stud 간격 샘플 (Roblox X, Z), 수면 Y=0", "return {",
            f"\tLength = {fmt(total, 3)},", "\tStops = {"]
    for name, s in stops.items():
        body.append(f"\t\t{{ Name = {lua_str(name)}, S = {fmt(s, 3)} }},")
    body.append("\t},")
    body.append("\tPoints = {")
    for (x, y) in pts:
        body.append(f"\t\t{{ {fmt(x)}, {fmt(-y)} }},")
    body.append("\t},")
    body.append("}")
    body.append("")
    write_luau(OUT_DIR / "FerryRouteData.luau", "\n".join(body))
    # 4) 기타 (스폰, 구역, 적)
    ex = ["--!strict", "-- 자동 생성 파일 (blender/level/layout.py). 직접 수정하지 마세요.", "return {"]
    ex.append("\tTerrainModules = { " + ", ".join(lua_str(n) for n in names) + " },")
    ex.append("\tMaterialNames = { " + ", ".join(lua_str(n) for n in MAT_NAMES) + " },")
    ex.append(f"\tSeaFloor = {fmt(SEA_FLOOR)},")
    ex.append("\tSeaBounds = { MinX = -1700, MaxX = 1700, MinZ = -1000, MaxZ = 1000 },")
    for key in ("SpawnPoints", "EnemySpawns", "Zones", "Buoys"):
        ex.append(f"\t{key} = {{")
        for item in extras[key]:
            parts = []
            for k, v in item.items():
                if isinstance(v, str):
                    parts.append(f"{k} = {lua_str(v)}")
                elif isinstance(v, (list, tuple)):
                    parts.append(f"{k} = {{ " + ", ".join(fmt(x) for x in v) + " }")
                elif isinstance(v, bool):
                    parts.append(f"{k} = {'true' if v else 'false'}")
                else:
                    parts.append(f"{k} = {fmt(v)}")
            ex.append("\t\t{ " + ", ".join(parts) + " },")
        ex.append("\t},")
    ex.append("}")
    ex.append("")
    write_luau(OUT_DIR / "WorldData.luau", "\n".join(ex))


def rb(x, y, z):
    """Blender -> Roblox 위치."""
    return [x, z, -y]


def main():
    islands = [build_swamp(), build_harbor(), build_lighthouse_rock()]
    P = Placer(islands)
    dock_s = swamp_layout(P)
    dock_h = harbor_layout(P)
    lighthouse_layout(P)
    route = ferry_route(dock_s, dock_h)
    # 부표: 항로 오른쪽 40 stud, 약 260 stud 간격
    pts = route[0]
    buoys = []
    step = int(260 / 6)
    for k in range(step // 2, len(pts), step):
        p0 = np.array(pts[k - 1]); p1 = np.array(pts[(k + 1) % len(pts)])
        d = p1 - p0
        d /= np.linalg.norm(d)
        right = np.array([d[1], -d[0]])
        q = np.array(pts[k]) + right * 40
        # 섬/암초 근처 제외
        h = P.height(q[0], q[1])
        if h < -10:
            buoys.append({"P": rb(q[0], q[1], 0)})
    spawn = [{"Name": "Harbor", "P": rb(-705, -14, 3.2)}, {"Name": "Mistmire", "P": rb(460, -12, DECK + 0.2)}]
    shrine = next(p for p in P.items if p["a"] == "MireShrine")
    boss = marker_world(shrine, "BossSpawn")
    enemies = [
        {"Type": "BogCrawler", "P": rb(700, -160, P.height(700, -160)), "Radius": 40, "Count": 4},
        {"Type": "BogCrawler", "P": rb(790, -60, P.height(790, -60)), "Radius": 36, "Count": 3},
        {"Type": "BogCrawler", "P": rb(640, -230, P.height(640, -230)), "Radius": 40, "Count": 4},
        {"Type": "BogCrawler", "P": rb(830, 40, P.height(830, 40)), "Radius": 30, "Count": 3},
        {"Type": "MudBrute", "P": rb(815, -250, P.height(815, -250)), "Radius": 22, "Count": 1},
        {"Type": "MudBrute", "P": rb(960, -110, P.height(960, -110)), "Radius": 22, "Count": 1},
        {"Type": "MudBrute", "P": rb(720, -300, P.height(720, -300)), "Radius": 22, "Count": 1},
        {"Type": "BogWitch", "P": rb(855, 190, P.height(855, 190)), "Radius": 26, "Count": 2},
        {"Type": "BogWitch", "P": rb(945, 120, P.height(945, 120)), "Radius": 22, "Count": 1},
        {"Type": "MireLord", "P": rb(boss[0], boss[1], boss[2]), "Radius": 30, "Count": 1, "Boss": True, "ArenaRadius": 34},
    ]
    zones = [
        {"Name": "Shrine", "Kind": "Sphere", "P": rb(900, -200, 0), "Radius": 75, "Priority": 3},
        {"Name": "Village", "Kind": "Box", "P": rb(445, 0, 10), "Size": [300, 80, 220], "Priority": 2},
        {"Name": "Swamp", "Kind": "Ellipse", "P": rb(SW_C[0], SW_C[1], 0), "Size": [SW_R[0] * 2 + 60, 200, SW_R[1] * 2 + 60], "Priority": 1},
        {"Name": "Harbor", "Kind": "Ellipse", "P": rb(HB_C[0], HB_C[1], 0), "Size": [HB_R[0] * 2 + 80, 200, HB_R[1] * 2 + 80], "Priority": 1},
        {"Name": "Lighthouse", "Kind": "Sphere", "P": rb(LH_C[0], LH_C[1], 0), "Radius": 120, "Priority": 1},
    ]
    export(islands, P, route, {"SpawnPoints": spawn, "EnemySpawns": enemies, "Zones": zones, "Buoys": buoys})
    counts = {}
    for it in P.items:
        counts[it["a"]] = counts.get(it["a"], 0) + 1
    print("[layout] placements:", len(P.items), dict(sorted(counts.items())))
    print(f"[layout] route length {route[1]:.0f} studs, stops {route[2]}")
    # 레벨 렌더용 캐시
    cache = {"islands": [{"name": i.name, "x0": i.x0, "y0": i.y0, "nx": i.nx, "ny": i.ny} for i in islands],
             "items": P.items, "route": route[0], "stops": route[2]}
    (ROOT / "assets" / "level_cache.json").write_text(json.dumps(cache))
    for isl in islands:
        np.savez_compressed(ROOT / "assets" / f"terrain_{isl.name}.npz", h=isl.h.astype(np.float32), m=isl.mat.astype(np.uint8))
    return islands, P, route


if __name__ == "__main__":
    main()
