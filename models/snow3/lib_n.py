# -*- coding: utf-8 -*-
"""
lib_n.py — 2026-11-17. 설원 3판 자연 키트(n_*.py) 공용 부품. 아트 부서. (건물 부품 lib_a·lib_b 와 같은 자리)

사용자(2026-11-17): "나무랑 지형 이런것들 지금 맵 보고 좀 다듬은 다음에 넣어줘"
지금 맵: 숲 키트 상자 나무(Pine_A…)의 잎만 눈색으로 칠함 → 흰 상자 층이 눈밭에 묻힌다. 바위 = 같은 크기 Slate 상자 + 눈 판.
여기서 바꾸는 것
  가문비 층 = 가지 끝이 처진 별꼴 치마(각진 면). 윗덩이 NeedleLit · 아랫면 덩이 Needle(짙은 그늘) · 눈(SnowCap)은 윗면 안쪽만
             덮어 처진 가지 끝 초록이 남는다. 층마다 돌림·끝 길이·처짐·눈 덮는 정도 = 모델 파일의 손 표.
  바위 = 모서리 따낸 판(위에서 본 다각형 = 손 표) 두세 켜 + 턱마다 눈.
규칙
  - 전부 닫힌 덩이(로블록스는 뒷면을 안 그린다).
  - 눈 밑면 = 받침 면을 평행하게 옮겨 받침 *속에* 0.08~0.1 묻는다 → 겹친 면(반짝임) 0 + 눈과 받침 사이 틈 0.
  - 난수 없음: 모양 수치는 모델 파일의 표에서만.
  - 충돌은 lib.cbox(→ build_kit → tools/Snow_Inside3_data.luau). 보이는 메시는 건물처럼 Studio 에서 충돌 끔.
좌표: 블렌더 (x, y 뒤, z 위), 앞 = -y, 원점 = 밑동 가운데 땅(z 0). 땅 아래로 0.2~0.8 묻어 굴곡진 땅에서도 뜨지 않게.

부품
  loft(g, mat, rings, top, bottom)        고리(같은 꼭짓점 수, 아래→위)를 이은 기둥. 끝 = 평평한 뚜껑 또는 점(뾰족·들쭉날쭉)
  ring(x, y, z, r, n, rot)                 n각 고리
  stick(g, mat, p0, p1, r0, r1, n)         두 점 사이 가는 각기둥(가지·토막·통나무)
  roots(g, mat, x, y, r_in, table)         밑동 뿌리 쐐기(땅에 묻힘)
  tier(g, ...)                             가문비 층 한 켜(+ 눈)
  spruce(g, tiers, trunk, roots, spire, coll)   가문비 한 그루
  snow_cap(g, apex, ring, fr, ...)         꼭대기 점 + 둘레 점으로 된 받침 윗면에 얹는 눈
  gem(g, mat, c, rx, ry, h, up, lo, rot)   깎은 덩어리(덤불·잔가지 덩이)
  slab(g, mat, poly, z0, z1, ...)          깎은 바위 판 / slab_snow(g, top, ...) 그 윗면 눈
  loft_x(g, mat, stations, profile)        x 축을 따라 단면을 이은 덩이(눈더미·눈막이 밑 눈)
"""
import math

from mathutils import Matrix, Vector

from lib import cbox  # noqa: F401  (모델 파일이 N.cbox 로 쓴다)

RAD = math.radians
NEEDLE_K = (31.0, 52.0, 0.55, 0.62)   # 층 모양: 윗면 기울기 · 처진 끝 기울기(도) · 꺾이는 자리(끝까지 비율) · 골 반지름 비율


def solid(g, mat, vs, faces):
    g[mat].add_mesh([tuple(v) for v in vs], faces)


def ring(x, y, z, r, n, rot=0.0):
    return [(x + r * math.cos(rot + 2 * math.pi * i / n), y + r * math.sin(rot + 2 * math.pi * i / n), z) for i in range(n)]


def loft(g, mat, rings, top=None, bottom=None):
    """rings = [[(x,y,z)…]…] 아래→위(같은 수). top/bottom = None → 평평한 뚜껑(한 평면일 때만), 점 → 그 점으로 모은 부채"""
    n = len(rings[0])
    vs = [p for rg in rings for p in rg]
    f = []
    for k in range(len(rings) - 1):
        a, b = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            f += [(a + i, a + j, b + j), (a + i, b + j, b + i)]
    if bottom is None:
        f.append(tuple(range(n - 1, -1, -1)))
    else:
        c = len(vs)
        vs.append(bottom)
        f += [(c, (i + 1) % n, i) for i in range(n)]
    last = (len(rings) - 1) * n
    if top is None:
        f.append(tuple(last + i for i in range(n)))
    else:
        c = len(vs)
        vs.append(top)
        f += [(c, last + i, last + (i + 1) % n) for i in range(n)]
    solid(g, mat, vs, f)


def _frame(d):
    d = Vector(d).normalized()
    u = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))).normalized()
    return d, u, d.cross(u).normalized()


def stick(g, mat, p0, p1, r0, r1, n=4, rot=0.0, tip=False):
    """p0 → p1 각기둥(굵기 r0 → r1). tip = 끝을 뾰족하게(잔가지·노간주 순)"""
    p0, p1 = Vector(p0), Vector(p1)
    _, u, v = _frame(p1 - p0)

    def rg(p, r):
        return [p + r * (math.cos(rot + 2 * math.pi * i / n) * u + math.sin(rot + 2 * math.pi * i / n) * v) for i in range(n)]
    if tip:
        loft(g, mat, [rg(p0, r0)], top=p1)
    else:
        loft(g, mat, [rg(p0, r0), rg(p1, r1)])


def branch(g, mat, p0, p1, r0, r1, snow=None, sink=0.06, extra=0.08, te=0.2):
    """네모 가지(윗면이 하늘을 보게 45° 돌림). snow = (t0, t1) 가지를 따라 덮는 구간 → 윗면과 평행(sink 묻힘)하고 양옆으로 extra 넓은 눈 막대"""
    stick(g, mat, p0, p1, r0, r1, n=4, rot=math.pi / 4)
    if not snow:
        return
    p0, p1 = Vector(p0), Vector(p1)
    _, u, v = _frame(p1 - p0)
    up = -v
    h = math.sqrt(0.5)

    def rect(t):
        c, r = p0.lerp(p1, t), r0 + (r1 - r0) * t
        w, zb, zt = h * r + extra, h * r - sink, h * r + te
        return [c - u * w + up * zb, c + u * w + up * zb, c + u * w + up * zt, c - u * w + up * zt]
    loft(g, "SnowCap", [rect(snow[0]), rect(snow[1])])


def roots(g, mat, x, y, r_in, table, z_lo=-0.5):
    """밑동 뿌리 퍼짐: table = [(방향 도, 끝 반지름, 밑 반폭, 줄기에 붙는 높이)]. 세모 쐐기, 끝은 땅 위 0.12 로 살짝 드러나고 밑은 묻힌다"""
    for ang, reach, w, h in table:
        c, s = math.cos(RAD(ang)), math.sin(RAD(ang))
        si, co = -s, c

        def P(r, side, z):
            return (x + c * r + si * side, y + s * r + co * side, z)
        ri = r_in * 0.55
        loft(g, mat, [[P(ri, 0, h), P(ri, -w, z_lo), P(ri, w, z_lo)],
                      [P(reach, 0, 0.12), P(reach, -w * 0.35, z_lo), P(reach, w * 0.35, z_lo)]])


# ------------------------------------------------------------------ 눈
def snow_cap(g, apex, ring_pts, fr, sink=0.1, tc=0.7, te=0.4, push=0.15, mat="SnowCap"):
    """
    받침 윗면이 꼭대기 점 apex 와 둘레 점 ring_pts 로 된 부채(삼각형 apex·ring_i·ring_i+1)일 때, 각 ring_i 쪽으로 fr_i 만큼 덮는 눈.
    밑면 = 그 부분 삼각형을 sink 만큼 내린 것(받침 면과 평행·속에 묻힘). 윗면 = 가장자리 te(바깥으로 push 내밈) · 가운데 tc
    """
    ax, ay, az = apex
    k = len(ring_pts)
    bot = [(ax + f * (p[0] - ax), ay + f * (p[1] - ay), az + f * (p[2] - az) - sink) for p, f in zip(ring_pts, fr)]
    top = []
    for x, y, z in bot:
        dx, dy = x - ax, y - ay
        d = math.hypot(dx, dy) or 1.0
        top.append((x + push * dx / d, y + push * dy / d, z + sink + te))
    vs = [(ax, ay, az - sink)] + bot + top + [(ax, ay, az + tc)]
    f = []
    for i in range(k):
        j = (i + 1) % k
        f += [(0, 1 + j, 1 + i), (1 + i, 1 + j, 1 + k + j), (1 + i, 1 + k + j, 1 + k + i), (1 + 2 * k, 1 + k + i, 1 + k + j)]
    solid(g, mat, vs, f)


# ------------------------------------------------------------------ 가문비
def _upper(a, b, c, d):
    """네 점 a-b-c-d(고리 순) 사각을 위로 볼록하게(능선이 되게) 나누는 두 삼각형 — 그 위 눈 밑면 현(弦)이 늘 면 아래로 지나가게"""
    a, b, c, d = Vector(a), Vector(b), Vector(c), Vector(d)
    nrm = (b - a).cross(c - a)
    if nrm.z < 0:
        nrm = -nrm
    return ((0, 1, 2), (0, 2, 3)) if (d - a).dot(nrm) < 0 else ((0, 1, 3), (1, 2, 3))


def tier(g, cx, cy, za, R, rot, tips, droop, snow=None, sag=0.0, k=NEEDLE_K, lit="NeedleLit", dark="Needle"):
    """
    가문비 층 한 켜. (cx, cy) 가운데 · za 꼭대기(줄기에 붙는 곳) · R 가지 끝 반지름 · rot 돌림(도) · tips 가지 끝 길이 배수(손 표, 개수 = 가지 수)
    droop 가지 끝이 더 처지는 길이 · snow 가지마다 눈이 처진 부분을 덮는 비율(꺾임 0 → 끝 1, None = 눈 없음) · sag 휜 나무: +x 쪽 끝 더 처짐.
    윗덩이(lit) = 꼭대기 → 꺾임 고리(윗면 기울기 k[0]) → 끝 고리(처진 끝 k[1]) → 안쪽 뚜껑. 처진 띠는 능선이 서게 나눈다(_upper).
    아랫덩이(dark) = 끝 고리 → 아랫면 꼭지 → 뚜껑. 두 뚜껑은 끝 고리에서 만나고 안에서는 벌어져 겹치지 않는다.
    눈: 꼭대기에서 눈 끝선(꺾임 너머 snow 만큼)까지. 밑면 = 꼭대기·눈 끝선 사이 현을 0.25 내린 것 — 층 윗면이 위로 볼록해서 늘 층 속에 묻힌다.
        윗면 = 눈 끝선 위 te(바깥 push) · 꼭대기 위 tc(꺾임 고리보다 높게 셈)
    """
    al, be, m, v = k
    ta, tb = math.tan(RAD(al)), math.tan(RAD(be))
    n = len(tips)
    M, T = [], []
    for j in range(2 * n):
        th = RAD(rot) + j * math.pi / n
        i = j // 2
        if j % 2 == 0:
            r, dz = R * tips[i], droop
        else:
            r, dz = R * v * (tips[i] + tips[(i + 1) % n]) / 2, droop * 0.3
        dz += sag * max(0.0, math.cos(th))
        rm = m * r
        zm = za - rm * ta
        zt = zm - (r - rm) * tb - dz
        c, s = math.cos(th), math.sin(th)
        M.append((cx + rm * c, cy + rm * s, zm))
        T.append((cx + r * c, cy + r * s, zt))
    lo = min(p[2] for p in T)
    span = za - lo
    U, LB, LA = (cx, cy, lo + 0.30 * span), (cx, cy, lo + 0.45 * span), (cx, cy, lo + 0.55 * span)
    N2 = 2 * n
    A = (cx, cy, za)
    f = []
    for j in range(N2):
        jj = (j + 1) % N2
        q = (1 + j, 1 + N2 + j, 1 + N2 + jj, 1 + jj)
        f += [(0, 1 + j, 1 + jj), (1 + 2 * N2, 1 + N2 + jj, 1 + N2 + j)]
        f += [tuple(q[i] for i in t) for t in _upper(M[j], T[j], T[jj], M[jj])]
    solid(g, lit, [A] + M + T + [LA], f)
    f = []
    for j in range(N2):
        jj = (j + 1) % N2
        f += [(N2, jj, j), (N2 + 1, j, jj)]
    solid(g, dark, T + [U, LB], f)
    if snow:
        te, push, sink = 0.25 + 0.03 * R, 0.1 + 0.015 * R, 0.25
        vs_ = [snow[j // 2] if j % 2 == 0 else (snow[j // 2] + snow[(j // 2 + 1) % n]) / 2 for j in range(N2)]
        P = [tuple(Mj[i] + v_ * (Tj[i] - Mj[i]) for i in range(3)) for Mj, Tj, v_ in zip(M, T, vs_)]
        tc = te + 0.3
        for Mj, Pj in zip(M, P):                 # 꼭대기 위 높이: 눈 윗면이 꺾임 고리보다 0.5 te 위를 지나게
            rp = math.hypot(Pj[0] - cx, Pj[1] - cy)
            fm = math.hypot(Mj[0] - cx, Mj[1] - cy) / (rp + push)
            tc = max(tc, (Mj[2] + 0.5 * te - fm * (Pj[2] + te)) / (1 - fm) - za)
        bot, top = [], []
        for x, y, z in P:
            d = math.hypot(x - cx, y - cy) or 1.0
            bot.append((x, y, z - sink))
            top.append((x + push * (x - cx) / d, y + push * (y - cy) / d, z + te))
        vs = [(cx, cy, za - sink)] + bot + top + [(cx, cy, za + tc)]
        f = []
        for i in range(N2):
            j = (i + 1) % N2
            f += [(0, 1 + j, 1 + i), (1 + i, 1 + j, 1 + N2 + j), (1 + i, 1 + N2 + j, 1 + N2 + i), (1 + 2 * N2, 1 + N2 + i, 1 + N2 + j)]
        solid(g, "SnowCap", vs, f)
    return lo


def spruce(g, tiers, trunk, root_t, spire, coll):
    """
    가문비 한 그루.
      tiers  = [(가운데 x, y, 꼭대기 z, R, 돌림 도, 끝 배수 표, 처짐, 눈 표 또는 None, 휨 처짐)]  아래 층부터
      trunk  = [(x, y, z, 반지름)] 8각 줄기 고리(아래 → 위, 맨 아래는 땅 속)
      root_t = roots() 표
      spire  = ((x, y, z) 순 밑, 밑 반지름, (x, y, z) 끝)  4각 순
      coll   = (줄기 충돌 반폭, 높이) — 줄기 상자만(잎은 막지 않는다)
    """
    loft(g, "Bark", [ring(x, y, z, r, 8, math.pi / 8) for x, y, z, r in trunk])
    roots(g, "Bark", trunk[0][0], trunk[0][1], trunk[0][3], root_t)
    for row in tiers:
        tier(g, *row[:7], snow=row[7], sag=row[8])
    (sx, sy, sz), sr, tip = spire
    loft(g, "NeedleLit", [ring(sx, sy, sz, sr, 4, RAD(20))], top=tip)
    hw, h = coll
    x0, y0 = trunk[0][0], trunk[0][1]
    cbox(x0 - hw, x0 + hw, y0 - hw, y0 + hw, 0, h)


# ------------------------------------------------------------------ 덩어리·바위
def gem(g, mat, c, rx, ry, h, up, lo, rot=0.0, zu=0.62, zl=0.22):
    """깎은 덩어리: 꼭대기 점 → 윗고리(높이 zu·h, 점마다 반지름 up_i) → 아랫고리(zl·h, 반 칸 돌림, lo_i) → 밑 점. 돌려주는 값 = (꼭대기, 윗고리)"""
    k = len(up)
    x, y, z = c
    top = (x, y, z + h)
    U = [(x + rx * up[i] * math.cos(rot + 2 * math.pi * i / k), y + ry * up[i] * math.sin(rot + 2 * math.pi * i / k), z + h * zu) for i in range(k)]
    L = [(x + rx * lo[i] * math.cos(rot + 2 * math.pi * (i + 0.5) / k), y + ry * lo[i] * math.sin(rot + 2 * math.pi * (i + 0.5) / k), z + h * zl)
         for i in range(k)]
    vs = [top] + U + L + [(x, y, z)]
    f = []
    for i in range(k):
        j = (i + 1) % k
        f += [(0, 1 + i, 1 + j), (1 + i, 1 + k + i, 1 + j), (1 + k + i, 1 + k + j, 1 + j), (1 + 2 * k, 1 + k + j, 1 + k + i)]
    solid(g, mat, vs, f)
    return top, U


def slab(g, mat, poly, z0, z1, cham=0.5, foot=0.92, top=0.82, M=None):
    """
    깎은 바위 판. poly = 위에서 본 둘레(손 표, 볼록) = 높이 z1-cham 의 둘레. 밑 = poly × foot · 윗면 = poly × top(무게 중심 기준) → 모서리를 따낸 다면체.
    M = 4×4 행렬(기울임·돌림·옮김). 돌려주는 값 = 윗면 점(옮긴 뒤, 한 평면)
    """
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)

    def sc(s, z):
        return [(cx + s * (px - cx), cy + s * (py - cy), z) for px, py in poly]
    rings = [sc(foot, z0), sc(1.0, z1 - cham), sc(top, z1)]
    if M is not None:
        rings = [[tuple(M @ Vector(p)) for p in rg] for rg in rings]
    loft(g, mat, rings)
    return rings[-1]


def slab_snow(g, top_pts, s=0.8, off=(0.0, 0.0), sink=0.08, te=0.35, tc=0.6, push=0.15, mat="SnowCap"):
    """slab 이 돌려준 윗면에 얹는 눈: 윗면을 무게 중심 쪽으로 s 배 줄이고 off(x, y) 만큼 옮긴 다각형(윗면 평면 위) = 밑면(면 속 sink),
    가장자리 te · 가운데 tc 두께를 윗면 법선 쪽으로 쌓는다(기울어진 판에도 평행)"""
    P = [Vector(p) for p in top_pts]
    c = sum(P, Vector()) / len(P)
    nrm = Vector()
    for i in range(len(P)):
        a, b = P[i], P[(i + 1) % len(P)]
        nrm += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
    nrm.normalize()
    if nrm.z < 0:
        nrm = -nrm
    o = Vector((off[0], off[1], -(nrm.x * off[0] + nrm.y * off[1]) / nrm.z))
    base = [c + s * (p - c) + o for p in P]
    cc = c + o
    bot = [p - nrm * sink for p in base]
    top = []
    for p in base:
        d = p - cc
        d -= nrm * d.dot(nrm)
        top.append(p + nrm * te + d.normalized() * push)
    k = len(P)
    vs = bot + top + [cc + nrm * tc]
    f = [tuple(range(k - 1, -1, -1))]
    for i in range(k):
        j = (i + 1) % k
        f += [(i, j, k + j), (i, k + j, k + i), (2 * k, k + i, k + j)]
    solid(g, mat, vs, f)


def loft_x(g, mat, stations, profile, ends=None):
    """
    x 축을 따라 단면(profile = [(y, z)] 닫힌 다각형, 바닥 z = -0.2 기준)을 이은 덩이.
    stations = [(x, 높이 배수, 폭 배수, y 옮김)] — 맨 앞·맨 뒤는 ends(점 둘, 없으면 단면 가운데 바닥)로 모은다
    """
    rings = []
    for x, hs, ws, dy in stations:
        rings.append([(x, y * ws + dy, -0.2 + (z + 0.2) * hs) for y, z in profile])
    y_mid = sum(p[0] for p in profile) / len(profile)
    e0, e1 = ends or ((stations[0][0] - 1.5, y_mid + stations[0][3], -0.2), (stations[-1][0] + 1.5, y_mid + stations[-1][3], -0.2))
    loft(g, mat, rings, top=e1, bottom=e0)


def rot(rx=0.0, ry=0.0, rz=0.0, t=(0.0, 0.0, 0.0)):
    """옮김 @ 돌림(z) @ 기울임(y) @ 기울임(x), 도"""
    return Matrix.Translation(t) @ Matrix.Rotation(RAD(rz), 4, "Z") @ Matrix.Rotation(RAD(ry), 4, "Y") @ Matrix.Rotation(RAD(rx), 4, "X")
