# -*- coding: utf-8 -*-
"""
scene_snow_town3.py — 설원 마을 3판 어댑터 (2026-11-14). snow_plan4 표 → mapshot 장면. 규칙은 Snow_Town3.luau 와 같다.
돌리기: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/mapshot/scene_snow_town3.py
출력: C:\\claude\\맵사진\\설원마을3판\\  (환경변수 MAPSHOT_OUT 으로 바꿈)
건물: models/snow3/b_*.py 가 지어지면 진짜 모델, 없거나 오류면 회색 상자 + 지붕. 남는 건물 셋은 옛 키트(build_steam_town.JOBS)를 20초 안에 지으면 진짜.
미리보기와 Studio 가 다른 점: 바위 흔들기(jit) 없음, 건물 안 충돌·창유리 없음, 둘레 지형은 json 4 스터드 칸을 합친 상자, 나무는 세모 덩어리.
"""
import importlib
import math
import os
import sys
import time

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "models"))
sys.path.insert(0, os.path.join(ROOT, "models", "snow3"))
import mapshot as ms  # noqa: E402
import snow_plan4 as P  # noqa: E402
import snow_plan2 as P2  # noqa: E402

OUT = os.environ.get("MAPSHOT_OUT", r"C:\claude\맵사진\설원마을3판")
CX, CZ, BASE = P.CX, P.CZ, P.BASE
BOT = BASE - 0.5
ROCK, SNOW = (85, 86, 92), (238, 243, 247)
ROAD, PLAZA = (112, 106, 98), (104, 99, 94)
notes = []


def W(u, v):
    return CX + u, CZ + v


t0 = time.time()
g = P.build_grid()

# ---------------------------------------------------------------- 건물(블렌더에서 먼저 — clear_scene 이 있어서)
import hanok_lib as L  # noqa: E402

L.clear_scene()
S = ms.Scene("설원마을3판", bounds=(-5360, -4436, -4200, -3476))


def real_model(kind):
    try:
        mod = importlib.import_module({"Sn3_Smithy": "b_smithy", "Sn3_General": "b_general", "Sn3_Potion": "b_potion", "Sn3_Ticket": "b_ticket",
                                       "Sn3_Enhance": "b_enhance", "Sn3_Bank": "b_bank", "Sn3_Mast": "b_mast", "Sn3_Clock": "b_clock", "Sn3_Inn": "b_inn", "Sn3_Hospital": "b_hospital", "Sn3_Gate": "b_gate"}[kind])
    except KeyError:
        return None
    except Exception as e:
        notes.append("%s 불러오기 오류 → 회색 상자: %s" % (kind, str(e)[:100]))
        return None
    import lib as K
    t = time.time()
    try:
        objs, tris, _ = K.build_model(mod, zfix=False)
    except Exception as e:
        notes.append("%s 짓기 오류 → 회색 상자: %s" % (kind, str(e)[:100]))
        return None
    notes.append("%s 진짜 모델 %.1fs %d tri" % (kind, time.time() - t, sum(tris.values())))
    return objs


def restyle(objs):
    """키트 재질(diffuse_color)을 렌더 재질로. 불빛 재질은 발광"""
    for ob in objs:
        if ob.name.endswith(("_Vent", "_LampPt", "WinGlass")):
            ob.hide_render = True
            ob.hide_viewport = True
            continue
        for i, sl in enumerate(ob.material_slots):
            m = sl.material
            c = tuple(int(round(lin2srgb(v) * 255)) for v in m.diffuse_color[:3])
            emit = 2.5 if any(k in m.name for k in ("Glow", "Fire", "Ember", "Coal")) else 0.0
            ob.material_slots[i].material = ms.make_mat(c, emit, "k")


def lin2srgb(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def blk(x, y, z, yaw, w, d, h, wall=(150, 150, 154), roof=(110, 100, 96)):
    """회색 상자 + 세모 지붕. 로블록스 로컬(x 폭, z 깊이)을 yaw 로 돌려 앉힌다"""
    a = math.radians(yaw)
    c, s = math.cos(a), math.sin(a)

    def tr(px, py, pz):
        return (x + px * c + pz * s, y + py, z - px * s + pz * c)

    hw, hd = w / 2, d / 2
    hr = h * 0.78
    v = [tr(sx * hw, 0, sz * hd) for sx in (-1, 1) for sz in (-1, 1)] + [tr(sx * hw, hr, sz * hd) for sx in (-1, 1) for sz in (-1, 1)]
    F = [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
    S.convex("building", v, F, wall)
    ov = 1.5
    rv = [tr(sx * (hw + ov), hr - 0.5, sz * (hd + ov)) for sx in (-1, 1) for sz in (-1, 1)] + [tr(sx * (hw + ov), h, 0) for sx in (-1, 1)]
    S.convex("building", rv, [[0, 2, 5, 4], [1, 3, 5, 4], [0, 1, 4], [2, 3, 5], [0, 1, 3, 2]], roof)


HEIGHT = {"Sn3_Clock": 100, "Sn3_Smithy": 30, "Sn3_Enhance": 30, "Sn3_Bank": 30, "Sn3_Inn": 36, "Sn3_Potion": 30, "Sn3_Hospital": 30,
          "Sn3_General": 30, "Sn3_Ticket": 16, "Sn3_Mast": 46, "Sn3_Gate": 22}
ph = []
for name, u, v, yaw, h, fore, no, kr in P.PADS:
    x, z = W(u, v)
    y = BASE + h
    w, d = P.SIZE[name]
    objs = real_model(name)
    if objs:
        restyle(objs)
        S.place(objs, x, y, z, yaw)
        if name == "Sn3_Clock":
            from mathutils import Vector as _V
            top = max((ob.matrix_world @ _V(c)).z for ob in objs for c in ob.bound_box)
            S.landmark(x, top + 0.5, z)
            notes.append("랜드마크 = 진짜 시계탑 꼭대기 y %.1f" % top)
    else:
        ph.append(name)
        if name == "Sn3_Clock":
            S.boxes("building", [(x - 9, x + 9, y, y + 4, z - 9, z + 9), (x - 6, x + 6, y + 4, y + 70, z - 6, z + 6)], (118, 84, 70))
            blk(x, y + 70, z, yaw, 15, 15, 30, (118, 84, 70), (80, 80, 86))
            S.boxes("prop", [(x - 0.5, x + 0.5, y + 99, y + 108, z - 0.5, z + 0.5)], (184, 145, 63))
        else:
            blk(x, y, z, yaw, w, d, HEIGHT[name])
    if name == "Sn3_Clock" and not objs:
        S.landmark(x, y + 101, z)
notes.append("회색 상자로 대신한 건물: %s" % ", ".join(ph))

# 남는 건물 셋 — 옛 키트
import build_steam_town as T  # noqa: E402

KEEP_H = {"Figuren_HQ": (83, 75, 62), "Observatory": (52, 55, 55), "Casino_Gate": (23, 23, 18)}
for kind, x, z, yaw in P.KEEP:
    job = next((j for j in T.JOBS if j[0] == kind), None)
    done = False
    if job:
        t = time.time()
        try:
            grp = T.G(job[1])
            job[2](grp)
            objs = []
            for k in T.PAL:
                ob = grp[k].finish()
                if len(ob.data.polygons) == 0:
                    bpy.data.objects.remove(ob, do_unlink=True)
                else:
                    objs.append(ob)
            dt = time.time() - t
            if dt > 20:
                notes.append("%s 짓는 데 %.0fs — 느려서 상자로 대신" % (kind, dt))
                for ob in objs:
                    bpy.data.objects.remove(ob, do_unlink=True)
            else:
                restyle(objs)
                S.place(objs, x, BASE, z, yaw)
                notes.append("%s 옛 키트 진짜 모델 %.1fs" % (kind, dt))
                done = True
        except Exception as e:
            notes.append("%s 옛 키트 오류 → 상자: %s" % (kind, str(e)[:100]))
    if not done:
        w, d, h = KEEP_H[kind]
        blk(x, BASE, z, yaw, w, d, h)

# ---------------------------------------------------------------- 땅 표 → 상자
walkable = np.full((P.NV, P.NU), np.nan)
Hh = np.array(g.G)
Kk = np.array(g.K)
okm = np.isin(Kk, (P.K_GROUND, P.K_TERR, P.K_SLAB, P.K_STEP, P.K_PAVE))
walkable[okm] = BASE + Hh[okm]
S.walk_grid(CX + P.U0, CZ + P.V0, 1.0, walkable)


def mask_rects(mask, x0, z0, c):
    """참 칸 마스크 → 가로줄 합치고 같은 줄 이어붙인 직사각형 (x0, x1, z0, z1)"""
    nz, nx = mask.shape
    runs = {}
    out = []
    prev = {}
    for j in range(nz):
        cur = {}
        row = mask[j]
        i = 0
        while i < nx:
            if row[i]:
                k = i
                while k < nx and row[k]:
                    k += 1
                key = (i, k)
                if key in prev:
                    cur[key] = prev[key]
                else:
                    cur[key] = [i, k, j, j]
                cur[key][3] = j
                i = k
            else:
                i += 1
        for key, r in prev.items():
            if key not in cur:
                out.append(r)
        prev = cur
    out += list(prev.values())
    return [(x0 + r[0] * c, x0 + (r[1]) * c, z0 + r[2] * c, z0 + (r[3] + 1) * c) for r in out]


# 맨바닥(마을 고원): 격자에서 땅·바위·단 등 고원 안 전부의 밑판
plate = (Kk != P.K_OUT) & (Kk != P.K_WALL)
gr = mask_rects(plate, CX + P.U0, CZ + P.V0, 1.0)
S.boxes("ground", [(a, b, BOT - 1.0, BASE, c, d) for a, b, c, d in gr], SNOW)
notes.append("고원 밑판 상자 %d" % len(gr))

# 둘레 지형: json 4 스터드 칸 중 고원 밑판 밖
import json  # noqa: E402

gj = json.load(open(os.path.join(ROOT, "tools", "snow_town_ground.json"), encoding="utf-8"))
st, jx0, jz0 = gj["st"], gj["x0"], gj["z0"]
rows = gj["rows"]
ctx = {}
for j, row in enumerate(rows):
    for i, h in enumerate(row):
        if h < -900:
            continue
        x, z = jx0 + i * st, jz0 + j * st
        ui, vi = int(round(x - CX - P.U0)), int(round(z - CZ - P.V0))
        if 0 <= ui < P.NU and 0 <= vi < P.NV and plate[vi, ui]:
            continue
        hh = BASE if 59.4 <= h <= 60.3 else h
        ctx.setdefault(round(hh, 1), []).append((j, i))
nctx = 0
for h, cells in ctx.items():
    m = np.zeros((len(rows), len(rows[0])), bool)
    for j, i in cells:
        m[j, i] = True
    rects = mask_rects(m, jx0 - st / 2, jz0 - st / 2, st)
    nctx += len(rects)
    S.boxes("context", [(a, b, min(h, BASE) - 30, h, c, d) for a, b, c, d in rects], (92, 94, 100) if h > 61 else SNOW)
notes.append("둘레 지형 상자 %d (높이 %d 종)" % (nctx, len(ctx)))

# 단·바위·판·넓은 단·길
terr_snow, terr_rock, rock_b, rock_s, plaza_r = [], [], [], [], []


def rock_snow(body_rows, snow_rows, x0, x1, z0, z1, top):
    if top - BOT <= 1:
        snow_rows.append((x0, x1, BOT, top, z0, z1))
        return
    body_rows.append((x0, x1, BOT, top - 0.2, z0, z1))
    snow_rows.append((x0 - 0.15, x1 + 0.15, top - 0.6, top, z0 - 0.15, z1 + 0.15))


for nm, u0, u1, v0, v1, h, mat in P.TERRACES:
    x0, z0 = W(u0, v0)
    x1, z1 = W(u1, v1)
    if mat == "돌바닥":
        plaza_r.append((x0, x1, BOT, BASE + h, z0, z1))
    else:
        rock_snow(terr_rock, terr_snow, x0, x1, z0, z1, BASE + h)
S.boxes("path", plaza_r, PLAZA)
S.boxes("terrace", terr_rock, ROCK)
S.boxes("terrace", terr_snow, SNOW)
for b in P.ALL_ROCKS:
    u0, u1, v0, v1, h = b[1]
    x0, z0 = W(u0, v0)
    x1, z1 = W(u1, v1)
    rock_snow(rock_b, rock_s, x0, x1, z0, z1, BASE + h)
# 바위 몸통 톤 규칙(Studio 빌더도 같게): fx = floor(x0), fz = floor(z0) (상자 서북 모서리 월드 스터드), t = (7*fx + 13*fz) % 3
#   t 0 → 밝기 x0.94, 1 → x1.00, 2 → x1.06 (바위색 85,86,92 에 곱함). 바위 몸통만(윗면 눈·단·넓은 단은 그대로)
TONE = (0.94, 1.0, 1.06)
by_t = ([], [], [])
for r_ in rock_b:
    by_t[(7 * int(math.floor(r_[0])) + 13 * int(math.floor(r_[4]))) % 3].append(r_)
for t_, rows_ in enumerate(by_t):
    S.boxes("rock", rows_, tuple(min(255, int(round(c_ * TONE[t_]))) for c_ in ROCK))
S.boxes("snowcap", rock_s, SNOW)
S.boxes("step", [(CX + s[1], CX + s[2], BOT, BASE + s[5], CZ + s[3], CZ + s[4]) for s in P.STEPS], ROCK)
S.boxes("slab", [(CX + s[0], CX + s[1], BOT, BASE + s[4], CZ + s[2], CZ + s[3]) for s in P.SLABS], SNOW)
for nm, w, x0, z0, x1, z1, top in P.path_pieces(g):
    ln = math.hypot(x1 - x0, z1 - z0)
    S.oriented("path", (x0 + x1) / 2, top + 0.15, (z0 + z1) / 2, ln, w, 0.2, x1 - x0, z1 - z0, ROAD)
# 체스판 연병장 8x8 칸
cx0, cz0, cx1, cz1 = P.CHESS[1], P.CHESS[2], P.CHESS[3], P.CHESS[4]
n8 = 8
for a in range(n8):
    for b in range(n8):
        S.boxes("path", [(cx0 + (cx1 - cx0) * a / n8, cx0 + (cx1 - cx0) * (a + 1) / n8, BOT, BASE + 0.25, cz0 + (cz1 - cz0) * b / n8, cz0 + (cz1 - cz0) * (b + 1) / n8)],
                (200, 200, 205) if (a + b) % 2 else (60, 60, 64))

# ---------------------------------------------------------------- 소품: 가스등(진짜 키트) · 나무
lamp_objs = None
try:
    import build_steam as BS
    gl = T.G("Lamp")
    BS.gas_lamp(gl)
    lamp_objs = []
    for k in T.PAL:
        ob = gl[k].finish()
        if len(ob.data.polygons) == 0:
            bpy.data.objects.remove(ob, do_unlink=True)
        else:
            lamp_objs.append(ob)
    restyle(lamp_objs)
    for ob in lamp_objs:
        ob.hide_render = True
except Exception as e:
    notes.append("가스등 키트 오류 → 기둥 상자: %s" % str(e)[:100])
trees = lamps = 0
for kind, u, v, yaw, sc in P.PROPS:
    x, z = W(u, v)
    q = g.at(u, v)
    y = BASE + (g.G[q[1]][q[0]] if q else 0.0)
    if kind == "Gas_Lamp":
        lamps += 1
        if lamp_objs:
            M, ins = S.instance(lamp_objs, x, y, z, yaw, "prop")
            for o in ins:
                o.hide_render = False
            from mathutils import Vector
            pw = M @ Vector((0, -1.6, 11.0))
            S.lights.append((pw.x, pw.z, -pw.y, (255, 185, 110), 250.0))
        else:
            S.boxes("prop", [(x - 0.3, x + 0.3, y, y + 11, z - 0.3, z + 0.3)], (58, 60, 66))
            S.boxes("prop", [(x - 0.6, x + 0.6, y + 11, y + 12.5, z - 0.6, z + 0.6)], (255, 190, 90), 6.0)
            S.light(x, y + 11.5, z, (255, 185, 110), 250.0)
    else:
        trees += 1
        hgt = (60 if kind != "Birch_A" else 45) * sc
        S.boxes("prop", [(x - 0.5 * sc * 2, x + 0.5 * sc * 2, y, y + hgt * 0.3, z - 0.5 * sc * 2, z + 0.5 * sc * 2)], (70, 50, 38))
        for k in range(3):
            S.cone("prop", x, y + hgt * (0.2 + 0.2 * k), z, hgt * (0.3 - 0.07 * k), hgt * 0.42, (200, 214, 228) if k else (160, 182, 200), 8)
notes.append("소품: 가스등 %d, 나무 %d" % (lamps, trees))

# 비행선 계류탑 쪽 비행선은 생략(미리보기용 큰 덩어리 아님)
notes.append("장면 짓기 %.0fs, 상자 %d" % (time.time() - t0, S.nobj))
res = ms.run(S, OUT)
with open(os.path.join(OUT, "설원마을3판_어댑터메모.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(notes) + "\n")
print("\n".join(notes))
print(res)
