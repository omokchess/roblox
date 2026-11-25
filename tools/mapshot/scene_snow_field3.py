# -*- coding: utf-8 -*-
"""
scene_snow_field3.py — 설원 필드 어댑터 (2026-11-19, 기획 부서). snow_field3_plan 표 → mapshot 장면.
돌리기: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/mapshot/scene_snow_field3.py
출력: C:\\claude\\맵사진\\설원필드\\ (환경변수 MAPSHOT_OUT 으로 바꿈). MAPSHOT_LATTICE 로 재는 격자(기본 8).
장면: 필드 땅(구역 높이 판 — 바위 몸 + 눈 판 2, 호수는 얼음) · 바닷가 벼랑 · 단 사이 바위(기존) · 새 바위(몸 세 톤 + 윗면 눈) · 새 눈 판 ·
  필드 장식(호수 바위·마른 나무·폐허·휴식처·큰 바위 — 상자, 기울기는 무시) · 굴 입구 셋(땅 위 부품) · 나무 185(숲 키트 상자 표 그대로, 잎 눈색) ·
  마을 3판 대역(단·바위·판 = 둘레 상자 context, 건물 = 회색 상자, 시계탑 = 높이 107.5 기둥).
재는 땅 = 필드(마을 빼고)만. 열림 비율 분모 = 필드 땅 넓이(S.region_area). 바위 kind = 새 바위 + 기존 단 사이 바위(크기 위계).
미리보기와 Studio 가 다른 점: 바위 흔들기 없음, 장식 상자 기울기 없음, 마을은 대역, 길은 포장 안 한 눈(맨바닥으로 셈).
"""
import json
import math
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "tools"))
import mapshot as ms  # noqa: E402
import snow_field3_plan as P  # noqa: E402
import snow_plan4 as P4  # noqa: E402

OUT = os.environ.get("MAPSHOT_OUT", r"C:\claude\맵사진\설원필드")
LATTICE = float(os.environ.get("MAPSHOT_LATTICE", "8"))
SNOW, ROCK, CROCK, CROCK2 = (238, 243, 247), (85, 86, 92), (100, 110, 106), (88, 97, 95)
LAND_ROCK, ICE = (96, 104, 104), (186, 212, 228)
SLAB = (233, 239, 245)
notes = []
t0 = time.time()

F = P.Field()
B = F.B
S = ms.Scene("설원필드", bounds=(P.GX0, P.GX1, P.GZ0, P.GZ1))
land = ~np.isin(B.K, (P.K_SEA, P.K_CLIFF, P.K_TOWN))
S.region_area = float(land.sum())


def mask_rects(mask, x0, z0, c):
    """참 칸 마스크 → 가로줄 합치고 같은 줄 이어붙인 직사각형 (x0, x1, z0, z1) — scene_snow_town3 와 같은 방법"""
    nz, nx = mask.shape
    out, prev = [], {}
    for j in range(nz):
        cur = {}
        row = mask[j]
        idx = np.flatnonzero(np.diff(np.concatenate(([0], row.astype(np.int8), [0]))))
        for i, k in zip(idx[::2], idx[1::2]):
            key = (int(i), int(k))
            cur[key] = prev.get(key, [int(i), int(k), j, j])
            cur[key][3] = j
        for key, r in prev.items():
            if key not in cur:
                out.append(r)
        prev = cur
    out += list(prev.values())
    return [(x0 + r[0] * c, x0 + r[1] * c, z0 + r[2] * c, z0 + (r[3] + 1) * c) for r in out]


# ---------------------------------------------------------------- 땅(필드 + 마을 고원) — 높이마다 바위 몸 + 눈 판 2
lv = np.round(B.G, 2)
for h in np.unique(lv[~np.isnan(lv)]):
    m = (lv == h) & ~np.isin(B.K, (P.K_SEA, P.K_CLIFF))
    rects = mask_rects(m, P.GX0, P.GZ0, 1.0)
    if abs(h - P.FP.ICE) < 0.01:
        S.boxes("ground", [(a, b, h - 4, h, c, d) for a, b, c, d in rects], ICE)
        continue
    S.boxes("ground", [(a, b, -24, h - 2, c, d) for a, b, c, d in rects], LAND_ROCK)
    S.boxes("ground", [(a, b, h - 2, h, c, d) for a, b, c, d in rects], SNOW)
    notes.append("땅 높이 %.1f 상자 %d" % (h, len(rects)))
# 바닷가 벼랑
S.boxes("context", [(x0, x1, -24, top - 2.2, z0, z1) for x0, x1, z0, z1, top in B.cliffs], CROCK)
S.boxes("context", [(x0, x1, top - 2.2, top - 0.2, z0, z1) for x0, x1, z0, z1, top in B.cliffs], SNOW)
# 단 사이 바위(기존)
for col in (0, 1):
    rows = [w for w in B.wedges if w[4] == col]
    S.boxes("rock", [(bx[0], bx[1], -24, top - 2.2, bx[2], bx[3]) for _, bx, lo, top, c in rows], CROCK if col == 1 else CROCK2)
    S.boxes("snowcap", [(bx[0], bx[1], top - 2.2, top - 0.2, bx[2], bx[3]) for _, bx, lo, top, c in rows], SNOW)
# 새 바위 — 마을과 같은 톤 규칙(서북 귀로 세 톤) + 윗면 눈 0.6
TONE = (0.94, 1.0, 1.06)
by_t, caps, lows = ([], [], []), [], []
for si, ri, k, x0, x1, z0, z1, top, bot in F.boxes:
    if top - bot - P.BURY <= 1:
        lows.append((x0, x1, bot, top, z0, z1))
        continue
    by_t[(7 * int(math.floor(x0)) + 13 * int(math.floor(z0))) % 3].append((x0, x1, bot, top - 0.2, z0, z1))
    caps.append((x0 - 0.15, x1 + 0.15, top - 0.6, top, z0 - 0.15, z1 + 0.15))
for t_, rows in enumerate(by_t):
    S.boxes("rock", rows, tuple(min(255, int(round(c * TONE[t_]))) for c in ROCK))
S.boxes("snowcap", caps + lows, SNOW)
S.boxes("slab", [(x0, x1, bot, top, z0, z1) for x0, x1, z0, z1, top, bot in F.slabs], SLAB)
notes.append("새 바위 상자 %d · 눈 판 %d" % (len(F.boxes), len(F.slabs)))

# ---------------------------------------------------------------- 필드 장식·굴 입구(돌린 상자, 기울기 무시)
GCOL = {"Snow": SNOW, "SnowCap": SNOW, "Drift": SNOW, "IceSnow": SNOW, "RockSnow": SNOW, "StoneSnow": SNOW, "Icicle": (210, 230, 240),
        "LakeRock": (52, 56, 62), "LakeRock2": (66, 70, 76), "CliffRock": (70, 74, 80), "PillarRock": (80, 84, 90), "Rock": CROCK, "Rock2": CROCK2,
        "DeadWood": (214, 210, 200), "DeadWood2": (150, 146, 140), "Burnt": (52, 46, 42), "Char": (46, 40, 36), "Char2": (60, 52, 46),
        "RuinStone": (120, 116, 110), "RuinStone2": (100, 96, 92), "Plinth": (130, 126, 120), "Plinth2": (112, 108, 104),
        "Timber": (110, 82, 58), "Plank": (120, 92, 66), "Post": (100, 76, 54), "Iron": (60, 62, 66), "Iron2": (78, 80, 84),
        "Stone": (130, 128, 124), "Stone2": (112, 110, 106), "Stone3": (146, 142, 136), "RestStone": (126, 122, 116), "FireRock": (70, 66, 62)}
skip = {"IceCrack", "LakeIce", "Soot", "Sign"}
c_, h_, p_ = {}, {}, {}
for b in P.FP.BOXES:
    g, cx, cy, cz, sx, sy, sz = b[:7]
    if g in skip:
        continue
    col = GCOL.get(g, (110, 110, 110))
    c_.setdefault(col, []).append((cx, -cz, cy))
    h_.setdefault(col, []).append((sx / 2, sz / 2, sy / 2))
    p_.setdefault(col, []).append(math.radians(b[7] if len(b) > 7 else 0.0))
for p in P.TP.parts:
    kind, cx, cy, cz, sx, sy, sz = p[:7]
    if kind in P.TUNNEL_UNDER or (len(p) > 7 and abs(p[7]) > 1e-6):
        continue
    g_ = B.G[P.cj(cz), P.ci(cx)]
    if np.isnan(g_) or cy + sy / 2 < g_ + 0.3:
        continue
    col = GCOL.get(kind, (96, 92, 88))
    c_.setdefault(col, []).append((cx, -cz, cy))
    h_.setdefault(col, []).append((sx / 2, sz / 2, sy / 2))
    p_.setdefault(col, []).append(math.radians(p[8] if len(p) > 8 else 0.0))
for col in c_:
    S._cubes("prop", col, 0.0, c_[col], h_[col], p_[col])
# 휴식처 모닥불·폐허 화덕 불빛
S.light(P.FP.rx, P.FP.ry_ + 3, P.FP.rz, (255, 170, 90), 600.0)
ch = [m for m in P.FP.MARKS if m[0] == "Ember"][0]
S.light(ch[1], ch[2] + 1, ch[3], (255, 150, 70), 500.0)

# ---------------------------------------------------------------- 나무 — 숲 키트 상자 표(models/forest/build_kit_forest.py, 원점 = 밑동, +Y 위) 잎만 눈색
KIT = {
    "Pine_A": [("Wood", (0, 1.5, 0), (4.4, 3, 4.4), 45), ("Wood", (0, 19, 0), (3, 36, 3), 0), ("LeafB", (0, 10, 0), (17, 5, 17), 0),
               ("LeafA", (0, 15, 0), (14.5, 5, 14.5), 45), ("LeafB", (0, 20, 0), (12, 5, 12), 0), ("LeafA", (0, 25, 0), (9.5, 5, 9.5), 45),
               ("LeafB", (0, 30, 0), (7, 5, 7), 0), ("LeafA", (0, 35, 0), (4.5, 5, 4.5), 45), ("LeafB", (0, 39.5, 0), (2.4, 4, 2.4), 0)],
    "Pine_B": [("Wood", (0, 1.2, 0), (3.6, 2.4, 3.6), 30), ("Wood", (0, 14, 0), (2.4, 26, 2.4), 0), ("LeafB", (0, 8, 0), (13, 4, 13), 15),
               ("LeafA", (0, 12, 0), (11, 4, 11), 60), ("LeafB", (0, 16, 0), (8.5, 4, 8.5), 15), ("LeafA", (0, 20, 0), (6, 4, 6), 60),
               ("LeafB", (0, 24, 0), (3.6, 4, 3.6), 15), ("LeafA", (0, 27.5, 0), (1.8, 3, 1.8), 60)],
    "Birch_A": [("Wood", (0, 1, 0), (3, 2, 3), 20), ("Wood", (0, 11, 0), (2, 20, 2), 0), ("Wood", (0.8, 23, 0), (1.6, 6, 1.6), 0),
                ("LeafA", (0.5, 24, 0), (9, 7, 8), 15), ("LeafB", (-2, 21, 2), (7, 5, 6), -10), ("LeafA", (2.5, 28, -1), (6, 5, 6), 40),
                ("LeafB", (3, 20, -3), (6, 4, 5), 20), ("LeafA", (0, 31, 0.5), (4, 3, 4), 0)],
}
TCOL = {"Wood": (92, 70, 52), "LeafA": (232, 240, 248), "LeafB": (196, 212, 228)}
tc, th, tp = {}, {}, {}
for kind, x, y, z, yaw, sc in P.FP.TREES:
    a = math.radians(yaw)
    for part, (lx, ly, lz), (sx, sy, sz), ry in KIT[kind]:
        ox, oz = (lx * math.cos(a) + lz * math.sin(a)) * sc, (-lx * math.sin(a) + lz * math.cos(a)) * sc
        tc.setdefault(part, []).append((x + ox, -(z + oz), y + ly * sc))
        th.setdefault(part, []).append((sx * sc / 2, sz * sc / 2, sy * sc / 2))
        tp.setdefault(part, []).append(math.radians(yaw + ry))
for part in tc:
    S._cubes("prop", TCOL[part], 0.0, tc[part], th[part], tp[part])
notes.append("나무 %d 그루(숲 키트 상자 표)" % len(P.FP.TREES))

# ---------------------------------------------------------------- 마을 3판 대역(재지 않는다 — 필드에서 보이는 덩어리만)
CX, CZ, BASE = P4.CX, P4.CZ, P4.BASE
S.boxes("context", [(CX + t[1], CX + t[2], BASE - 0.5, BASE + t[5], CZ + t[3], CZ + t[4]) for t in P4.TERRACES], SNOW)
S.boxes("context", [(CX + b[0], CX + b[1], BASE - 0.5, BASE + b[4] - 0.2, CZ + b[2], CZ + b[3]) for _, b in P4.ALL_ROCKS], ROCK)
S.boxes("context", [(CX + b[0] - 0.15, CX + b[1] + 0.15, BASE + b[4] - 0.6, BASE + b[4], CZ + b[2] - 0.15, CZ + b[3] + 0.15) for _, b in P4.ALL_ROCKS], SNOW)
HGT = {"Sn3_Clock": 107.5, "Sn3_Inn": 36, "Sn3_Mast": 46, "Sn3_Ticket": 16, "Sn3_Gate": 22}
for name, u, v, yaw, h, fore, no, kr in P4.PADS:
    r = P4.pad_rect(name, u, v, yaw)
    y0 = BASE + h
    if name == "Sn3_Clock":
        S.boxes("building", [(CX + u - 9, CX + u + 9, y0, y0 + 70, CZ + v - 9, CZ + v + 9), (CX + u - 6, CX + u + 6, y0 + 70, y0 + 100, CZ + v - 6, CZ + v + 6)], (118, 84, 70))
        S.boxes("building", [(CX + u - 1, CX + u + 1, y0 + 100, y0 + 107.5, CZ + v - 1, CZ + v + 1)], (184, 145, 63))
    else:
        S.boxes("building", [(CX + r[0], CX + r[1], y0, y0 + HGT.get(name, 30), CZ + r[2], CZ + r[3])], (150, 146, 150))
KEEP_H = {"Figuren_HQ": (83, 75, 62), "Observatory": (52, 55, 55), "Casino_Gate": (23, 23, 18)}
for kind, x, z, yaw in P4.KEEP:
    w, d, h = KEEP_H[kind]
    S.boxes("building", [(x - w / 2, x + w / 2, BASE, BASE + h, z - d / 2, z + d / 2)], (140, 136, 142))

# ---------------------------------------------------------------- 랜드마크 · 걷는 땅
for name, x, y, z in P.lm_points(F):
    S.landmark(x, y, z)
    notes.append("랜드마크 %s (%.0f, %.1f, %.0f)" % (name, x, y, z))
walk = np.full(B.G.shape, np.nan)
ok = np.isin(F.K, (P.K_GROUND, P.K_SLAB, P.K_ICE))
walk[ok] = F.Gw[ok]
S.walk_grid(P.GX0, P.GZ0, 1.0, walk)
notes.append("장면 짓기 %.0fs, 상자 %d" % (time.time() - t0, S.nobj))
print("\n".join(notes), flush=True)

res = ms.run(S, OUT, lattice=LATTICE)

# ---------------------------------------------------------------- 사진 목표: 화면 아래 절반이 맨 눈(70% 넘음)인 사진 수, 30 안 짙은 물건
from mathutils import Vector  # noqa: E402
R = ms.Rays()
js = json.load(open(os.path.join(OUT, "설원필드_shots.json"), encoding="utf-8"))
L = ["사진 목표: 아래 절반 맨바닥 % (70 넘으면 '아래 절반이 맨 눈') · 30 안 짙은 물건(바위·건물·소품) % (3 이상이면 '가까이 물건 보임')"]
nbare = nnear = 0
for e in js["shots"]:
    ex, ey, ez = e["eye"]
    lx, _, lz = e["look"]
    heading = math.atan2(-lz, lx)
    cat, dist, gid = R.cast(Vector(ms.rbx_to_bl(ex, ey, ez)), ms.view_dirs(heading, 64, 36))
    c = cat.reshape(36, 64)
    d = dist.reshape(36, 64)
    bare = float((c[18:] == ms.BARE).mean() * 100)
    near = float(((c == ms.THING) & (d < 30)).mean() * 100)
    if not e["label"].startswith("L"):
        nbare += bare > 70
        nnear += near >= 3
    L.append("  %-3s 아래 절반 맨바닥 %3.0f%%%s · 가까이 짙은 물건 %5.1f%%%s" % (e["label"], bare, " ← 맨 눈" if bare > 70 else "", near, " ← 없음" if near < 3 else ""))
L.append("무작위 12장: 아래 절반이 맨 눈 %d장 (목표 ≤ 2) · 가까이 짙은 물건 보임 %d장" % (nbare, nnear))
with open(os.path.join(OUT, "설원필드_사진목표.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(L) + "\n")
with open(os.path.join(OUT, "설원필드_어댑터메모.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(notes) + "\n")
print("\n".join(L))
print(res)
