# -*- coding: utf-8 -*-
"""
sanctuary_plan.py — 탑의 성역 리메이크 배치표. (2026-09-27)

jeolhwa_plan.py, snow_plan.py 와 같은 방식이다. **자리는 전부 이 표에 손으로 적는다.**
원 둘레에 기둥·난간을 두르는 것 같은 규칙적인 반복만 코드에 맡긴다.
이 파일은 표를 평면도(PNG)로 그리고, 겹침·땅 검사를 하고, Studio 가 읽을 Sanctuary_data.luau 를 뽑는다.

  탑은 섬 가운데 (400, -1467). 둘레 r 178 에 흰 돌 안뜰 단(Terrace)을 올리고 가장자리 r 172 에 열주 28.
  북(+Z, 평원 쪽)으로 큰길: 쌍 반사지, 수호상 네 쌍, 청등, 오벨리스크, 측백 줄, 섬 끝에 큰 문.
  동·서로 작은 길 끝에 원형 사당, 남으로 정자 뜰. 사분면 잔디에 떨어진 탑 조각, 꽃나무, 부러진 상.
  섬 가장자리 r 640 에 군데군데 무너진 난간.

좌표: u = x - 400, v = z + 1467 (v>0 가 북). 각 θ 는 x = cos, z = sin (θ=90 이 북).
yaw 는 도, 0 이면 모델 앞(-Z)이 남(-Z)을 본다. 180 이면 북.
돌리는 법: python tools/sanctuary_plan.py [출력.png] [배율]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from plan_png import Canvas  # noqa: E402

CX, CZ = 400.0, -1467.0
TERRACE_R = 178.0
RING_R = 172.0
N_COL = 28
PLINTH_R = 98.0

# 모델 발자국 반폭 (로컬 X, Z). 블렌더 치수에서 옮겼다
FOOT = {
    "Col_Intact": (3.7, 3.7), "Col_BrokenA": (3.7, 3.7), "Col_BrokenB": (3.7, 3.7), "Col_Fallen": (15.0, 6.0),
    "Great_Gate": (34.0, 8.5), "Tholos": (17.0, 22.0), "Pavilion": (13.8, 13.8), "Guardian": (4.2, 5.2),
    "Lantern_Blue": (1.5, 1.5), "Obelisk": (3.5, 3.5), "Bench": (3.6, 1.3), "Cypress": (3.2, 3.2),
    "Cypress_Tall": (3.2, 3.2), "Blossom": (5.5, 6.0), "Blossom_B": (5.5, 5.5), "Chunk_Rib": (21.5, 11.5),
    "Chunk_Block": (12.0, 8.5), "Balustrade": (0.6, 20.0), "Statue_Broken": (8.5, 8.5),
}

# 열주 상태. k 번 기둥은 θ = 6.43 + 12.857k (0 번이 동쪽 바로 북). I 멀쩡, A 반 부러짐, B 밑동, F 쓰러져 단 밖에 누움
# 북쪽 반(방문객이 마주 보는 쪽)은 거의 서 있고, 남쪽으로 갈수록 무너졌다
COL_STATE = "IIIAIII" + "IIIIIFI" + "IBAIIFB" + "AIIBIFI"

# 길 { 이름, 방향 각, 시작 r, 끝 r, 폭 }
WAYS = [
    ("북 큰길", 90, 191, 660, 24),
    ("동 길", 0, 191, 436, 16),
    ("서 길", 180, 191, 436, 16),
    ("남 길", 270, 191, 402, 16),
]

# 반사지 { u 가운데, v0, v1, 폭 }
POOLS = [(-44, 230, 600, 22), (44, 230, 600, 22)]

# 놓을 것 { 모델, u, v, yaw, 땅에 묻을 깊이 }
ITEMS = [
    # --- 북 큰길 ---
    ("Great_Gate", 0, 668, 180, 0),
    ("Guardian", -19, 262, -90, 0), ("Guardian", 19, 262, 90, 0),
    ("Guardian", -19, 382, -90, 0), ("Guardian", 19, 382, 90, 0),
    ("Guardian", -19, 502, -90, 0), ("Guardian", 19, 502, 90, 0),
    ("Guardian", -19, 622, -90, 0), ("Guardian", 19, 622, 90, 0),
    ("Obelisk", -44, 214, 0, 0), ("Obelisk", 44, 214, 0, 0), ("Obelisk", -44, 616, 0, 0), ("Obelisk", 44, 616, 0, 0),
    ("Bench", -28.4, 300, 90, 0), ("Bench", 28.4, 300, -90, 0), ("Bench", -28.4, 540, 90, 0), ("Bench", 28.4, 540, -90, 0),
    # --- 동·서 사당, 남 정자 뜰 ---
    ("Tholos", 470, 0, 90, 0),
    ("Tholos", -470, 0, -90, 0),
    ("Pavilion", 0, -450, 0, 0),
    ("Blossom", -28, -422, 0, 0), ("Blossom_B", 28, -422, 40, 0), ("Blossom_B", -28, -478, 200, 0), ("Blossom", 28, -478, 120, 0),
    ("Bench", -20, -450, 90, 0), ("Bench", 20, -450, -90, 0),
    ("Obelisk", -14, -404, 0, 0), ("Obelisk", 14, -404, 0, 0),
    # --- 길 들머리 측백 (안뜰 계단 양옆) ---
    ("Cypress_Tall", 204, 22, 0, 0), ("Cypress_Tall", 204, -22, 0, 0),
    ("Cypress_Tall", -204, 22, 0, 0), ("Cypress_Tall", -204, -22, 0, 0),
    ("Cypress_Tall", 22, -204, 0, 0), ("Cypress_Tall", -22, -204, 0, 0),
    # --- 북동 ---
    ("Chunk_Rib", 196, 356, 30, 3), ("Chunk_Block", 430, 300, 15, 1),
    ("Blossom", 262, 236, 0, 0), ("Blossom_B", 296, 256, 60, 0), ("Blossom", 238, 300, 140, 0),
    ("Statue_Broken", 150, 520, 200, 0), ("Bench", 280, 190, 180, 0),
    # --- 북서 ---
    ("Chunk_Block", -196, 470, -20, 1), ("Chunk_Rib", -336, 236, 150, 3),
    ("Blossom_B", -252, 336, 0, 0), ("Blossom", -296, 384, 80, 0), ("Blossom", -210, 392, 160, 0),
    ("Statue_Broken", -150, 300, 160, 0),
    # --- 남동 ---
    ("Chunk_Rib", 262, -236, -60, 3), ("Blossom", 336, -300, 0, 0), ("Blossom_B", 376, -250, 90, 0),
    ("Statue_Broken", 150, -330, 20, 0), ("Chunk_Block", 440, -386, 40, 1),
    # --- 남서 ---
    ("Chunk_Block", -250, -284, 70, 1), ("Blossom", -334, -334, 0, 0), ("Blossom_B", -292, -384, 30, 0),
    ("Statue_Broken", -160, -262, -30, 0), ("Chunk_Rib", -462, -206, 100, 3),
    # --- 대각선 초소 넷 (r 420). 오벨리스크 하나에 청등 둘, 꽃나무 하나 ---
    ("Obelisk", 297, 297, 45, 0), ("Obelisk", -297, 297, -45, 0), ("Obelisk", -297, -297, 45, 0), ("Obelisk", 297, -297, -45, 0),
    ("Blossom", 318, 330, 0, 0), ("Blossom_B", -330, 318, 0, 0), ("Blossom", -318, -262, 0, 0), ("Blossom_B", 262, -318, 0, 0),
    # --- 숲 무더기 (사분면마다 둘). 측백 몇 그루를 꽃나무로 두른다 ---
    ("Cypress_Tall", 360, 470, 0, 0), ("Cypress", 380, 500, 0, 0), ("Cypress", 340, 506, 0, 0), ("Blossom", 396, 452, 30, 0),
    ("Blossom_B", 330, 440, 90, 0),
    ("Cypress", 520, 170, 0, 0), ("Cypress_Tall", 548, 190, 0, 0), ("Blossom", 560, 140, 0, 0), ("Cypress", 510, 220, 0, 0),
    ("Cypress_Tall", -372, 480, 0, 0), ("Cypress", -400, 450, 0, 0), ("Blossom_B", -346, 452, 60, 0), ("Cypress", -406, 510, 0, 0),
    ("Cypress", -540, 196, 0, 0), ("Cypress_Tall", -520, 160, 0, 0), ("Blossom", -566, 170, 0, 0), ("Blossom_B", -500, 212, 0, 0),
    ("Cypress_Tall", 420, -470, 0, 0), ("Cypress", 392, -500, 0, 0), ("Blossom_B", 452, -500, 120, 0),
    ("Cypress", 540, -190, 0, 0), ("Cypress_Tall", 566, -214, 0, 0), ("Blossom", 530, -240, 0, 0),
    ("Cypress_Tall", -410, -470, 0, 0), ("Cypress", -380, -500, 0, 0), ("Blossom", -440, -506, 200, 0), ("Cypress", -436, -440, 0, 0),
    ("Cypress", -540, -170, 0, 0), ("Blossom_B", -566, -200, 0, 0), ("Cypress_Tall", -520, -226, 0, 0),
    # --- 안뜰(단 위) 청등 여덟. 네 길 사이 ---
    ("Lantern_Blue", 115.5, 47.8, 0, 0), ("Lantern_Blue", 47.8, 115.5, 0, 0), ("Lantern_Blue", -47.8, 115.5, 0, 0),
    ("Lantern_Blue", -115.5, 47.8, 0, 0), ("Lantern_Blue", -115.5, -47.8, 0, 0), ("Lantern_Blue", -47.8, -115.5, 0, 0),
    ("Lantern_Blue", 47.8, -115.5, 0, 0), ("Lantern_Blue", 115.5, -47.8, 0, 0),
]

# 청등 { u, v } 길 가장자리. 큰길은 수호상 사이에
LAMPS = [(-15.5, 202), (15.5, 202), (-15.5, 322), (15.5, 322), (-15.5, 442), (15.5, 442), (-15.5, 562), (15.5, 562),
         (-15.5, 646), (15.5, 646)]
LAMPS += [(297 + 8, 297 - 8), (297 - 8, 297 + 8), (-297 - 8, 297 - 8), (-297 + 8, 297 + 8),
          (-297 - 8, -297 + 8), (-297 + 8, -297 - 8), (297 + 8, -297 + 8), (297 - 8, -297 - 8)]
for r in (240, 300, 360):   # 동·서·남 길 양옆
    LAMPS += [(r, 11), (r, -11), (-r, 11), (-r, -11), (11, -r), (-11, -r)]

# 측백 줄. 반사지 바깥 u ±70, 북으로 36 마다 (키 큰 것과 번갈아)
CYPRESS_ROW = [(-70, 236 + 36 * k) for k in range(11)] + [(70, 236 + 36 * k) for k in range(11)]

# 가장자리 난간이 남은 구간 { θ0, θ1 } 도. 네 길 들머리(0, 90, 180, 270)는 비운다
BALU_R = 640.0
BALU_ARCS = [(8, 38), (46, 82), (98, 128), (140, 172), (188, 214), (226, 262), (278, 300), (312, 352)]


def polar(th, r):
    a = math.radians(th)
    return CX + r * math.cos(a), CZ + r * math.sin(a)


def uv(u, v):
    return CX + u, CZ + v


# ------------------------------------------------------------------ 땅
def terrain():
    L = open(os.path.join(HERE, "sanctuary_height.txt"), encoding="utf-8").read().split("\n")
    x0, z0, st, nx, nz = map(int, L[0].split())
    rows = [list(map(float, r.split())) for r in L[1:1 + nz]]
    return x0, z0, st, nx, nz, rows


T = terrain()


def ground(x, z):
    x0, z0, st, nx, nz, rows = T
    i, j = (x - x0) / st, (z - z0) / st
    i0, j0 = int(math.floor(i)), int(math.floor(j))
    vals = []
    for dj in (0, 1):
        for di in (0, 1):
            ii, jj = min(nx - 1, max(0, i0 + di)), min(nz - 1, max(0, j0 + dj))
            vals.append(rows[jj][ii])
    if any(v < -900 for v in vals):
        return None
    fi, fj = i - i0, j - j0
    return (vals[0] * (1 - fi) * (1 - fj) + vals[1] * fi * (1 - fj) + vals[2] * (1 - fi) * fj + vals[3] * fi * fj)


def terrace_top():
    """안뜰 단 윗면. 탑 기단 밖(r 98..178) 땅보다 0.6 높게"""
    hi = -1e9
    for r in range(int(PLINTH_R), int(TERRACE_R) + 1, 4):
        for d in range(0, 360, 6):
            g = ground(*polar(d, r))
            if g is not None:
                hi = max(hi, g)
    return round(hi + 0.6, 2)


TT = terrace_top()


# ------------------------------------------------------------------ 펼치기
def columns():
    out = []
    for k in range(N_COL):
        th = 6.4286 + 12.857 * k
        st = COL_STATE[k]
        x, z = polar(th, RING_R)
        if st == "F":
            fx, fz = polar(th, 196)
            out.append(("Col_Fallen", fx, fz, -th, 0.0, k))
        else:
            out.append(({"I": "Col_Intact", "A": "Col_BrokenA", "B": "Col_BrokenB"}[st], x, z, -th, 0.0, k))
    return out


def lintels():
    out = []
    for k in range(N_COL):
        k1 = (k + 1) % N_COL
        if COL_STATE[k] == "I" and COL_STATE[k1] == "I":
            th = 6.4286 + 12.857 * (k + 0.5)
            x, z = polar(th, RING_R * math.cos(math.radians(12.857 / 2)))
            out.append((x, z, -(th + 90.0)))
    return out


def balustrades():
    out = []
    step = math.degrees(40.0 / BALU_R)
    for a0, a1 in BALU_ARCS:
        n = int((a1 - a0) / step)
        for j in range(n):
            th = a0 + step * (j + 0.5)
            x, z = polar(th, BALU_R)
            g = ground(x, z)
            if g is None or g < 7.0:
                continue
            out.append((x, z, -th))
    return out


def all_items():
    """(모델, x, z, yaw, 묻을 깊이)"""
    out = []
    for m, u, v, yaw, sink in ITEMS:
        x, z = uv(u, v)
        out.append((m, x, z, yaw, sink))
    for m, x, z, yaw, sink, _ in columns():
        out.append((m, x, z, yaw, sink))
    for k, (u, v) in enumerate(CYPRESS_ROW):
        x, z = uv(u, v)
        out.append(("Cypress_Tall" if k % 2 else "Cypress", x, z, (k * 47) % 360, 0))
    for u, v in LAMPS:
        x, z = uv(u, v)
        out.append(("Lantern_Blue", x, z, 0, 0))
    for x, z, yaw in balustrades():
        out.append(("Balustrade", x, z, yaw, 0))
    return out


def rect(m, x, z, yaw, pad=0.0):
    hx, hz = FOOT[m]
    hx, hz = hx + pad, hz + pad
    a = math.radians(yaw)
    c, s = math.cos(a), math.sin(a)
    pts = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, lz = sx * hx, sz * hz
        # 로블록스 CFrame.Angles(0, a, 0): X 는 (cos a, -sin a), Z 는 (sin a, cos a)
        pts.append((x + lx * c + lz * s, z - lx * s + lz * c))
    return pts


def overlap(p, q):
    def axes(P):
        return [(P[(k + 1) % 4][1] - P[k][1], -(P[(k + 1) % 4][0] - P[k][0])) for k in range(2)]
    for ax in axes(p) + axes(q):
        pa = [ax[0] * x + ax[1] * z for x, z in p]
        qa = [ax[0] * x + ax[1] * z for x, z in q]
        if max(pa) <= min(qa) or max(qa) <= min(pa):
            return False
    return True


def way_rects():
    out = []
    for name, th, r0, r1, w in WAYS:
        a = math.radians(th)
        ux, uz = math.cos(a), math.sin(a)
        nx, nz = -uz * w / 2, ux * w / 2
        x0, z0 = CX + ux * r0, CZ + uz * r0
        x1, z1 = CX + ux * r1, CZ + uz * r1
        out.append((name, [(x0 + nx, z0 + nz), (x1 + nx, z1 + nz), (x1 - nx, z1 - nz), (x0 - nx, z0 - nz)]))
    return out


def pool_rects():
    out = []
    for u, v0, v1, w in POOLS:
        x0, z0 = uv(u - w / 2 - 1.6, v0 - 1.6)
        x1, z1 = uv(u + w / 2 + 1.6, v1 + 1.6)
        out.append([(x0, z0), (x1, z0), (x1, z1), (x0, z1)])
    return out


def check():
    msgs = []
    items = all_items()
    R = [(m, x, z, rect(m, x, z, y, 0.6)) for m, x, z, y, s in items]
    for i in range(len(R)):
        for j in range(i + 1, len(R)):
            a, b = R[i], R[j]
            if {a[0], b[0]} == {"Balustrade"}:
                continue
            if overlap(a[3], b[3]):
                msgs.append("겹침 %s(%.0f,%.0f) ~ %s(%.0f,%.0f)" % (a[0], a[1], a[2], b[0], b[1], b[2]))
    ways = way_rects()
    for m, x, z, r in R:
        if m in ("Great_Gate", "Balustrade"):
            continue
        for name, w in ways:
            if overlap(r, w):
                msgs.append("길 막음 %s(%.0f,%.0f) ~ %s" % (m, x, z, name))
        for p in pool_rects():
            if overlap(r, p):
                msgs.append("반사지 %s(%.0f,%.0f)" % (m, x, z))
        d = math.hypot(x - CX, z - CZ)
        on_terrace = d < TERRACE_R
        if m.startswith("Col_") and m != "Col_Fallen":
            continue
        # 단(안뜰) 가장자리에 걸치면 안 된다
        for px, pz in r:
            dd = math.hypot(px - CX, pz - CZ)
            if (dd < TERRACE_R) != on_terrace and m != "Col_Fallen":
                msgs.append("단 가장자리에 걸침 %s(%.0f,%.0f)" % (m, x, z))
                break
        for px, pz in r:
            g = ground(px, pz)
            if g is None or g < 6.5:
                msgs.append("땅 밖 %s(%.0f,%.0f) 모서리 땅 %s" % (m, x, z, g))
                break
    return msgs


# ------------------------------------------------------------------ 평면도
def render(path, sc):
    x0, z0, st, nx, nz, rows = T
    reg = (x0, z0, x0 + st * (nx - 1), z0 + st * (nz - 1))
    C = Canvas(*reg, sc)
    C.rect(*reg, "#3d6488")
    for j, row in enumerate(rows):
        for i, h in enumerate(row):
            if h < -900:
                continue
            x, z = x0 + i * st, z0 + j * st
            col = "#cdbf94" if h < 6.5 else "#5c8a4a"
            C.rect(x - st / 2, z - st / 2, x + st / 2, z + st / 2, col)
    C.circle(CX, CZ, TERRACE_R, "#e9e6dc")
    C.circle(CX, CZ, PLINTH_R, "#cfcabc")
    C.circle(CX, CZ, 36, "#8e8a80")
    for name, w in way_rects():
        C.poly(w, "#e9e6dc")
    for p in pool_rects():
        C.poly(p, "#3b6e8f")
    for x, z, yaw in lintels():
        C.poly([(x + 19 * math.cos(math.radians(-yaw)), z + 19 * math.sin(math.radians(-yaw))),
                (x - 19 * math.cos(math.radians(-yaw)), z - 19 * math.sin(math.radians(-yaw)))] * 1 +
               [(x - 19 * math.cos(math.radians(-yaw)) + 0.1, z - 19 * math.sin(math.radians(-yaw)) + 0.1)], "#24478f")
    colmap = {"Great_Gate": "#c9a24a", "Tholos": "#c9a24a", "Pavilion": "#24478f", "Guardian": "#f4f2ea",
              "Lantern_Blue": "#7acaff", "Obelisk": "#c9a24a", "Bench": "#bbbbbb", "Cypress": "#1f3f2a",
              "Cypress_Tall": "#1f3f2a", "Blossom": "#f3d7e0", "Blossom_B": "#f3d7e0", "Chunk_Rib": "#8e8a80",
              "Chunk_Block": "#8e8a80", "Balustrade": "#f4f2ea", "Statue_Broken": "#d8d4c8", "Col_Intact": "#24478f",
              "Col_BrokenA": "#5a6fa0", "Col_BrokenB": "#8a96b8", "Col_Fallen": "#a09c90"}
    for m, x, z, y, s in all_items():
        C.poly(rect(m, x, z, y), colmap.get(m, "#ff00ff"))
        if m not in ("Balustrade",):
            a = math.radians(y)
            fz = -FOOT[m][1]
            C.circle(x + fz * math.sin(a), z + fz * math.cos(a), 1.5, "#ff3030")
    C.save(path)


# ------------------------------------------------------------------ Luau
def lua(v):
    if isinstance(v, str):
        return '"' + v + '"'
    if isinstance(v, (int, float)):
        return ("%.3f" % v).rstrip("0").rstrip(".")
    return "{" + ", ".join(lua(x) for x in v) + "}"


def emit(path):
    lines = ["-- sanctuary_plan.py 가 적은 표. 손으로 고치지 말고 sanctuary_plan.py 를 고쳐 다시 뽑는다", "local D = {}",
             "D.CX, D.CZ, D.TT = %s, %s, %s" % (lua(CX), lua(CZ), lua(TT)),
             "D.TERRACE_R, D.RING_R, D.PLINTH_R = %s, %s, %s" % (lua(TERRACE_R), lua(RING_R), lua(PLINTH_R))]
    tables = [("ITEMS", [list(t) for t in all_items()]), ("LINTELS", [list(t) for t in lintels()]),
              ("WAYS", [list(w) for w in WAYS]), ("POOLS", [list(p) for p in POOLS])]
    for name, rows in tables:
        lines.append("D.%s = {" % name)
        for r in rows:
            lines.append("\t" + lua(r) + ",")
        lines.append("}")
    lines.append("return D")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "sanctuary_plan.png")
    sc = float(sys.argv[2]) if len(sys.argv) > 2 else 0.6
    render(out, sc)
    emit(os.path.join(HERE, "Sanctuary_data.luau"))
    msgs = check()
    items = all_items()
    kinds = {}
    for m, *_ in items:
        kinds[m] = kinds.get(m, 0) + 1
    print("안뜰 단 윗면 %.2f, 놓을 것 %d, 인방 %d" % (TT, len(items), len(lintels())))
    print(", ".join("%s %d" % kv for kv in sorted(kinds.items())))
    for m in msgs:
        print(m)
    print("검사 %d 건" % len(msgs))
