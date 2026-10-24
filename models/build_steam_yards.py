# -*- coding: utf-8 -*-
"""
build_steam_yards.py — 2026-10-24. 슈네라이히 서비스 건물 뜰 일곱(Yard_*)을 건물 양옆·뒤 구역 전부로 넓힌다.

사용자(2026-10-24): "기능 건물 뒤에 있는 작은 공간 이런 것들 크기를 쭈욱 늘려도 좋을 듯. 빨간색 구역 정도로"
  + "은행은 금고 뒤가 그냥 쌩 벽이라 장식만 달아 둔 느낌 — 뒤 공간을 금고 공간으로 쭉 놓고, 건물 양쪽에 구멍을 뚫어 추가 공간을"
구역 = tools/snow_plan2.py YARD_ZONES(→ tools/snow_yard_zones.json): 양옆 방사 길 가 + 4.5(가스등 줄은 길 쪽), 뒤 고리관 받침 안쪽 r 125,
건물 '모두' 발자국에서 1 띄움. 뜰 틀은 건물과 같은 자리·각에 서므로 좌표는 건물 로컬(블렌더 x, y — 앞 -y 가 광장, 뒤 +y).
모든 덩이는 z >= 0(배치가 가장 낮은 면을 땅에 맞춘다 — 땅 밑으로 내려가면 뜰과 건물이 함께 뜬다). 뜰 바닥 = 마을 땅(0), 길·판은 얇게 얹는다.
울타리 = 돌 밑단 + 쇠 난간(Rail) + 돌 기둥, 구역 선 위. 문은 손으로 고른 자리. 안은 손 배치(자동 흩뿌리기 금지 — feedback-no-procedural-decor).
지을 때 충돌 상자가 구역 밖·울타리에 붙으면 알린다(zone_report).

  Yard_Smithy    대장간 마당: 뒤 큰 문 → 뒷문 길, 뒷벽 따라 일 길. 왼쪽 광석 더미·광석 수레·증기 해머 헛간(보일러), 오른쪽 바깥 화덕
                 (모루·숯 화로·담금질 통·칼 식힘대·연장 걸이)·숯가마(진짜 불)·통나무, 왼 날개 나무 마당, 오른 날개 발 숫돌·납품 수레·상자·물통
  Yard_Enhance   룬 시험장: 뒤 큰 문 → 룬 원(바닥 무늬) 가운데 공명탑(청록 수정), 둘레 룬 돌 기둥 넷, 왼쪽 그을린 과녁 셋, 오른쪽 룬 새김 작업대·룬 돌 상자
  Yard_Bank      금고 구역(울타리 대신 겉벽): 은행 옆문 → 옆 별관(왼 = 대여 금고·열쇠 창구, 오른 = 감정·환전 창구) → 금고실(쇠 벽·쇠창살 창, 금괴·금화)을
                 두르는 회랑(운반 레일·금 수레, 길드 금고 우리 셋, 동전 세는 기계) → 반대쪽 별관 → 은행. 금고실 앞벽 = 은행 뒷벽(반쯤 연 둥근 금고 문)
  Yard_Inn       마구간 마당: 마구간(칸 넷), 말 울타리(물통·건초 걸이·뛰어넘기 장대), 역마차, 건초 더미, 오른 날개 우물(도르래), 왼 날개 맥주 뜰(긴 탁자 둘)
  Yard_Potion    약초밭: 가운데 길 → 지나가는 유리 온실(앞뒤 문, 안 선반·화분·난로), 돋운 밭 넷, 왼쪽 벌통 셋·말리는 시렁, 오른쪽 손 펌프·퇴비 통·외바퀴 수레·분갈이 대
  Yard_Hospital  회복 정원: 뒷문 → 부활 자리(둥근 판·붉은 심장) → 팔각 정자 → 뒤 큰 문. 왼쪽 언 연못·걸상, 오른쪽 해시계와 화단 넷, 날개마다 열기 난로 기둥과 걸상
  Yard_General   노점 골목: 뒤 큰 문에서 건물 뒤까지 골목(양옆 노점 셋씩, 줄 깃발), 왼쪽 저울판·짐수레·상자, 오른쪽 의뢰 게시판·물통·상자
"""
import json
import math
import os
import sys

from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_steam as S  # noqa: E402
import hanok_lib as L_  # noqa: E402
import build_steam_inside as I  # noqa: E402
from build_steam_obs import sphere  # noqa: E402
from build_steam_inside import C, NPC, PROP, job, lantern, coal_bed  # noqa: E402
from build_steam_service import (snow, solid, frustum, bench, barrel, crate, ore_lumps, pine_tree,  # noqa: E402
                                 herb_bundle, sword_hilt_up, balance_scale, goods_row, half_ring_y,
                                 anvil_icon, rune_icon, flask_icon, sack_icon, heart_icon, horseshoe_icon, coin_icon)

ZONES = json.load(open(os.path.join(HERE, "..", "tools", "snow_yard_zones.json"), encoding="utf-8"))
RAIL_H = 3.4
_NOCHECK = {}


# ------------------------------------------------------------------ 공용
def _ang(a, b):
    return math.atan2(b[1] - a[1], b[0] - a[0])


def place(g, dx, dy, fn, rz=0.0):
    """fn 을 제 자리(0, 0)에서 지어 (dx, dy) 로 옮기고 rz(라디안) 돌린다 — 충돌 상자·불·소품·NPC 자리도 같이(돌릴 땐 소품·NPC 없이)"""
    key = I._cur[0]
    cl, pl, fl, nl = I.COLL[key], I.PROPS[key], I.FIRES.setdefault(key, []), I.NPCS.setdefault(key, [])
    n0 = [len(cl), len(pl), len(fl), len(nl)]
    L_.transformed(g, Matrix.Translation((dx, dy, 0.0)) @ Matrix.Rotation(rz, 4, "Z"), fn)
    c, s = math.cos(rz), math.sin(rz)

    def P(x, y):
        return dx + c * x - s * y, dy + s * x + c * y
    assert rz == 0.0 or (len(pl) == n0[1] and len(nl) == n0[3]), "돌린 묶음엔 소품·NPC 자리를 넣지 않는다"
    cl[n0[0]:] = [(*P(e[0], e[1]), e[2], e[3], e[4], e[5], e[6] + rz) for e in cl[n0[0]:]]
    pl[n0[1]:] = [(e[0], *P(e[1], e[2]), *e[3:]) for e in pl[n0[1]:]]
    fl[n0[2]:] = [(*P(e[0], e[1]), *e[2:]) for e in fl[n0[2]:]]
    nl[n0[3]:] = [(*P(e[0], e[1]), *e[2:]) for e in nl[n0[3]:]]


def unchecked(g, fn):
    """구역 검사에서 뺄 충돌 상자(울타리·구역 선 위 겉벽)"""
    key = I._cur[0]
    i0 = len(I.COLL[key])
    fn(g)
    _NOCHECK.setdefault(key, []).append((i0, len(I.COLL[key])))


def slab_poly(g, mat, poly, z0, z1):
    """볼록 다각형 판(z0..z1)"""
    n = len(poly)
    v = [(x, y, z0) for x, y in poly] + [(x, y, z1) for x, y in poly]
    f = [tuple(range(n)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    solid(g, mat, v, f)


def wedge_drift(g, a, b, side, d=1.2, h=0.5, inset=0.6):
    """a → b 를 따라 놓인 눈더미(side +1 = 왼 법선 쪽). 끝은 비스듬히"""
    L = math.dist(a, b)
    if L < 2.0:
        return
    ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    nx, ny = -uy * side, ux * side
    p0 = (a[0] + ux * inset, a[1] + uy * inset)
    p1 = (b[0] - ux * inset, b[1] - uy * inset)
    v = [(p0[0], p0[1], 0.0), (p1[0], p1[1], 0.0), (p1[0] + nx * d, p1[1] + ny * d, 0.0), (p0[0] + nx * d, p0[1] + ny * d, 0.0),
         (p0[0] + ux * 0.5, p0[1] + uy * 0.5, h), (p1[0] - ux * 0.5, p1[1] - uy * 0.5, h)]
    solid(g, "SnowDrift", v, [(0, 1, 2, 3), (0, 1, 5, 4), (3, 2, 5, 4), (0, 3, 4), (1, 2, 5)])


def pier_lamp(g, x, y, z0, lamp=True):
    """기둥 머리 등: 놋쇠 받침 · 유리 갓 · 불꽃 심지 · 네 귀 쇠살 · 놋쇠 지붕 + 눈"""
    g["Brass"].cyl(x, y, z0, 0.42, 0.32, 0.3, seg=8)
    g["Glass"].box(x, y, z0 + 0.85, 0.72, 0.72, 1.0)
    g["Glow"].box(x, y, z0 + 0.75, 0.2, 0.2, 0.38)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Iron"].box(x + sx * 0.38, y + sy * 0.38, z0 + 0.85, 0.08, 0.08, 1.06)
    S.pyramid(g, "Brass", x, y, z0 + 1.35, 1.0, 1.0, 0.45)
    S.pyramid(g, "SnowCap", x, y, z0 + 1.35, 1.0, 1.0, 0.45, frac=0.55, lift=0.06)
    if lamp:
        g["LampPt"].box(x, y, z0 + 0.85, 0.3, 0.3, 0.3)


def pier(g, x, y, rz, h=RAIL_H + 0.8, lamp=None):
    """울타리 돌 기둥(rz = 울타리 방향) + 밑 굽 + 갓돌 + 눈(또는 머리 등)"""
    g["StoneTrim"].obox(x, y, h / 2, 1.2, 1.2, h, rz=rz)
    g["StoneTrim"].obox(x, y, 0.35, 1.45, 1.45, 0.7, rz=rz)
    g["StoneTrim"].obox(x, y, h + 0.15, 1.5, 1.5, 0.3, rz=rz)
    if lamp is None:
        g["SnowCap"].obox(x, y, h + 0.38, 1.4, 1.4, 0.16, rz=rz)
        g["SnowCap"].obox(x, y, h + 0.52, 0.95, 0.95, 0.12, rz=rz)
    else:
        pier_lamp(g, x, y, h + 0.3, lamp)
    C(x, y, h / 2, 1.45, 1.45, h, rz)


def rail_piece(g, a, b):
    """돌 밑단 + 쇠 난간 한 토막(a → b): 아래·위 가로대, 긴 살(마름모 창끝)·짧은 살 번갈아, 밑단·윗대 위 눈, 양쪽 밑 눈더미"""
    L = math.dist(a, b)
    if L < 0.3:
        return
    an = _ang(a, b)
    cx, cy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    ux, uy = math.cos(an), math.sin(an)
    g["StoneTrim"].obox(cx, cy, 0.3, L, 0.8, 0.6, rz=an)
    g["SnowCap"].obox(cx, cy, 0.64, L, 0.62, 0.08, rz=an)
    g["Rail"].obox(cx, cy, 0.9, L, 0.12, 0.12, rz=an)
    g["Rail"].obox(cx, cy, RAIL_H - 0.2, L, 0.14, 0.14, rz=an)
    g["SnowCap"].obox(cx, cy, RAIL_H - 0.08, L, 0.22, 0.08, rz=an)
    n = max(1, int(L / 0.8))
    for k in range(n):
        u = (k + 0.5) * L / n - L / 2
        px, py = cx + ux * u, cy + uy * u
        tall = k % 2 == 0
        top = RAIL_H + (0.25 if tall else -0.1)
        g["Rail"].obox(px, py, (0.6 + top) / 2, 0.1, 0.1, top - 0.6, rz=an)
        if tall:
            g["Rail"].obox(px, py, top + 0.08, 0.17, 0.17, 0.17, rx=0.785, rz=an)
    for side in (-1, 1):
        wedge_drift(g, (a[0] - uy * side * 0.4, a[1] + ux * side * 0.4), (b[0] - uy * side * 0.4, b[1] + ux * side * 0.4), side, d=0.9, h=0.45)
    C(cx, cy, RAIL_H / 2, L, 0.8, RAIL_H, an)


def gate_arch(g, w, icon):
    """큰 문 쇠 아치(문 기둥 안쪽 면에서 솟음) + 세로 살 셋 + 매단 양면 그림 판(+ 눈). 문 가운데 = (0, 0), x = 울타리 방향"""
    r = w / 2 - 0.6
    zc = RAIL_H + 1.2
    half_ring_y(g, "Rail", 0, 0, zc, r - 0.16, r, 0.16, n=18)
    for x in (-r * 0.5, r * 0.5):
        h = math.sqrt(max(0.0, (r - 0.16) ** 2 - x * x))
        g["Rail"].box(x, 0, zc + h / 2, 0.08, 0.08, h)
    zt = zc + r - 0.16
    for x in (-0.7, 0.7):
        g["Iron"].box(x, 0, zt - 0.3, 0.05, 0.05, 0.6)
    zb = zt - 1.5
    g["Timber"].box(0, 0, zb, 2.6, 0.22, 1.8)
    g["Brass"].box(0, 0, zb + 0.94, 2.7, 0.26, 0.12)
    snow(g, 0, 0, zb + 1.0, 2.6, 0.3, t=0.1)
    if icon:
        icon(g, 0, -0.11, zb - 0.2, -1)
        icon(g, 0, 0.11, zb - 0.2, 1)


def fence(g, kind, gates=(), icon=None, skip=()):
    """뜰 울타리(구역 꺾은선 위). gates = ((bx, by, 폭, 큰 문), ...) — 그 점에서 가장 가까운 곳을 폭만큼 비우고 문 기둥(머리 등)을 세운다.
    큰 문 = 등 켠 기둥 + 쇠 아치 + 양면 그림 판(icon). skip = 울타리를 두지 않을 (s0, s1) 꺾은선 거리 구간"""
    pts = [tuple(p) for p in ZONES[kind]["fence"]]
    segs = list(zip(pts, pts[1:]))
    cum = [0.0]
    for a, b in segs:
        cum.append(cum[-1] + math.dist(a, b))

    def at(sv):
        for i, (a, b) in enumerate(segs):
            if sv <= cum[i + 1] + 1e-9 or i == len(segs) - 1:
                t = (sv - cum[i]) / max(1e-9, cum[i + 1] - cum[i])
                return (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])), _ang(a, b)

    def proj(p):
        best = None
        for i, (a, b) in enumerate(segs):
            L = cum[i + 1] - cum[i]
            ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
            t = max(0.0, min(L, (p[0] - a[0]) * ux + (p[1] - a[1]) * uy))
            d = math.hypot(a[0] + ux * t - p[0], a[1] + uy * t - p[1])
            if best is None or d < best[0]:
                best = (d, cum[i] + t)
        return best[1]

    holes = sorted([(proj((gx, gy)) - w / 2, proj((gx, gy)) + w / 2, w, big) for gx, gy, w, big in gates] + [(a, b, 0.0, None) for a, b in skip])

    def build(g):
        runs, s0 = [], 0.0
        for a, b, w, big in holes:
            runs.append((s0, a))
            s0 = b
        runs.append((s0, cum[-1]))
        piers = set()
        for s_a, s_b in runs:
            if s_b - s_a < 0.4:
                continue
            cuts = [s_a] + [c for c in cum[1:-1] if s_a + 0.3 < c < s_b - 0.3] + [s_b]
            for u0, u1 in zip(cuts, cuts[1:]):
                rail_piece(g, at(u0)[0], at(u1)[0])
            marks = [s_a, s_b]
            for i in range(1, len(segs)):
                c = cum[i]
                turn = abs((_ang(*segs[i]) - _ang(*segs[i - 1]) + math.pi) % (2 * math.pi) - math.pi)
                if s_a + 1.0 < c < s_b - 1.0 and turn > 0.2:
                    marks.append(c)
            marks = sorted(marks)
            extra = []
            for m0, m1 in zip(marks, marks[1:]):
                n = int((m1 - m0) / 9.0)
                extra += [m0 + (m1 - m0) * k / (n + 1) for k in range(1, n + 1)]
            piers |= {round(m, 3) for m in marks + extra}
        gate_ends = {}
        for a, b, w, big in holes:
            if big is not None:
                gate_ends[round(a, 3)] = big
                gate_ends[round(b, 3)] = big
        for m in sorted(piers):
            (x, y), an = at(m)
            if m in gate_ends:
                pier(g, x, y, an, h=RAIL_H + 1.6, lamp=bool(gate_ends[m]))
            else:
                pier(g, x, y, an)
        for a, b, w, big in holes:
            if big:
                (x, y), an = at((a + b) / 2)
                place(g, x, y, lambda q: gate_arch(q, w, icon), rz=an)
    unchecked(g, build)


def path(g, a, b, w, lv=0, mat="Stone"):
    """곧은 돌길 한 토막(a → b, 폭 w) + 밝은 테두리. lv = 겹치는 길끼리 윗면 높이를 달리해 깜빡임을 막는다(0.03 씩)"""
    L = math.dist(a, b)
    an = _ang(a, b)
    cx, cy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    z = 0.12 + lv * 0.03
    g["StoneTrim"].obox(cx, cy, (z - 0.015) / 2, L + 0.6, w + 0.6, z - 0.015, rz=an)
    g[mat].obox(cx, cy, z / 2, L, w, z, rz=an)


def lamp_post(g, x, y, h=5.6, lamp=True):
    """뜰 등 기둥: 무쇠 굽 · 가는 기둥 · 놋쇠 띠 · 머리 등"""
    g["Iron"].cyl(x, y, 0.0, 0.45, 0.38, 0.45, seg=10)
    g["Iron"].cyl(x, y, 0.45, 0.13, 0.11, h - 0.45, seg=8)
    g["Brass"].cyl(x, y, 1.3, 0.19, 0.19, 0.16, seg=8)
    pier_lamp(g, x, y, h, lamp)
    C(x, y, h / 2, 0.6, 0.6, h)


def fir(g, x, y, h=7.5):
    pine_tree(g, x, y, 0.0, h)
    C(x, y, 1.6, 0.8, 0.8, 3.2)


def wheel(g, x, y, z, r, axis="y", n=8, rim="Iron", spoke="Timber", t=0.22):
    """살 바퀴(테 · 살 n · 굴대통). axis = 굴대 방향(y: 바퀴가 x-z 면에 선다)"""
    def fn(q):
        half_ring_y(q, rim, 0, 0, 0, r - 0.18, r, t, n=14)
        L_.transformed(q, Matrix.Rotation(math.pi, 4, "Y"), lambda q2: half_ring_y(q2, rim, 0, 0, 0, r - 0.18, r, t, n=14))
        for k in range(n // 2):
            q[spoke].obox(0, 0, 0, 0.1, 0.1, 2 * r - 0.25, ry=k * math.pi / (n // 2))
        q["Brass"].hcyl(0, 0, 0, 0.22, t + 0.16, axis="y", seg=10)
    m = Matrix.Translation((x, y, z)) @ (Matrix.Rotation(math.pi / 2, 4, "Z") if axis == "x" else Matrix.Identity(4))
    L_.transformed(g, m, fn)


def dome(g, mat, x, y, z0, r, n=6, seg=16, frac=1.0):
    """반구(아래 z0). frac < 1 이면 꼭대기 쪽만(눈 모자)"""
    k0 = int(round(n * (1.0 - frac)))
    for k in range(k0, n):
        a0, a1 = math.pi / 2 * k / n, math.pi / 2 * (k + 1) / n
        g[mat].cyl(x, y, z0 + r * math.sin(a0), r * math.cos(a0), max(0.02, r * math.cos(a1)), r * (math.sin(a1) - math.sin(a0)), seg=seg)


def flat_heart(g, x, y, z, s=1.0, mat="SignRed"):
    """바닥에 깐 납작한 심장"""
    for sx in (-1, 1):
        g[mat].cyl(x + sx * 0.42 * s, y + 0.22 * s, z, 0.55 * s, 0.55 * s, 0.05, seg=14)
    g[mat].obox(x, y - 0.2 * s, z + 0.025, 1.05 * s, 1.05 * s, 0.05, rz=math.pi / 4)


def _in_poly(poly, p):
    sgn = 0
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        cr = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        if abs(cr) < 1e-9:
            continue
        s = 1 if cr > 0 else -1
        if sgn == 0:
            sgn = s
        elif s != sgn:
            return False
    return True


def _seg_d(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)


def zone_report(g, kind):
    """충돌 상자 네 귀가 구역 안이고 울타리 선에서 0.6 넘게 떨어졌나 · 땅 밑으로 내려간 덩이가 있나"""
    Z = ZONES[kind]
    skip = _NOCHECK.get(kind, [])
    fence_ = Z["fence"]
    bad = []
    for i, (cx, cy, cz, sx, sy, sz, rz) in enumerate(I.COLL[kind]):
        if any(a <= i < b for a, b in skip):
            continue
        c, s = math.cos(rz), math.sin(rz)
        for u, v in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2)):
            p = (cx + c * u - s * v, cy + s * u + c * v)
            inside = any(_in_poly(part, p) for part in Z["parts"])
            dmin = min(_seg_d(p, a, b) for a, b in zip(fence_, fence_[1:]))
            if not inside or dmin < 0.6:
                bad.append("(%.1f, %.1f) 크기 %.1f×%.1f 귀 (%.1f, %.1f) %s %.2f" % (cx, cy, sx, sy, p[0], p[1], "밖" if not inside else "울타리", dmin))
                break
    lows = [(v.co.z, k, tuple(round(c, 1) for c in v.co)) for k, grp in g.items() for v in grp.bm.verts if v.co.z < -0.02]
    low = min((v.co.z for grp in g.values() for v in grp.bm.verts), default=0.0)
    for z_, k_, co_ in sorted(lows)[:6]:
        print("      땅 밑 %s %s" % (k_, co_))
    print("    %s: 구역 검사 충돌 상자 %d 중 걸림 %d, 가장 낮은 점 %.2f" % (kind, len(I.COLL[kind]), len(bad), low))
    for b in bad[:12]:
        print("      걸림 " + b)
    if low < -0.02:
        _LOW.append("%s 덩이가 땅 밑으로 %.2f 내려갔다(뜰·건물이 뜬다)" % (kind, low))


_LOW = []


def yard_job(kind, fn, cut=None):
    def run(g):
        fn(g)
        zone_report(g, kind)
        if kind == "Yard_General":                                           # 마지막 뜰에서 모아 멈춘다(미리보기에서 다 보이게)
            assert not _LOW, "; ".join(_LOW)
    return job(kind, run, cut=cut)


# ------------------------------------------------------------------ 대장간 마당
def steam_hammer(g):
    """증기 해머(앞 -y): 검은 돌 기초 · 무쇠 모탕 + 강철 받침 · 달군 쇠막대 · 두 기둥(안쪽 미끄럼 쇠·볼트) · 윗보 · 증기 실린더(놋쇠 띠·뚜껑 볼트) ·
    피스톤 막대 · 들린 망치 머리 · 조작 손잡이와 밸브 막대 · 배기관(김) · 기대 둔 집게"""
    g["DarkStone"].box(0, 0, 0.3, 5.4, 4.2, 0.6)
    frustum(g, "Iron", 0, 0, 0.6, 2.8, 2.4, 1.9, 1.7, 1.7)
    g["Steel"].box(0, 0, 2.45, 1.5, 1.3, 0.3)
    g["Core"].box(-0.1, -0.1, 2.68, 1.25, 0.35, 0.18)
    for s in (-1, 1):
        g["Iron"].box(s * 2.0, 0, 4.8, 0.7, 1.3, 8.4)
        g["Iron"].box(s * 2.0, 0, 0.95, 1.2, 1.9, 0.7)
        g["Steel"].box(s * 1.58, 0, 5.6, 0.16, 0.5, 5.6)
        for z in (1.6, 4.0, 6.4, 8.6):
            g["Brass"].hcyl(s * 2.0, -0.7, z, 0.12, 0.1, axis="y", seg=6)
    g["Iron"].box(0, 0, 9.5, 5.8, 1.7, 1.0)
    g["Brass"].box(0, -0.86, 9.5, 5.9, 0.06, 0.25)
    g["Iron"].cyl(0, 0, 10.0, 1.0, 1.0, 2.6, seg=16)
    for z in (10.3, 11.3, 12.3):
        S.ring(g, "Brass", 0, 0, z, 1.0, 1.1, 0.15, n=16)
    g["Iron"].cyl(0, 0, 12.6, 1.15, 1.15, 0.3, seg=16)
    for k in range(8):
        a = k * math.pi / 4
        g["Brass"].cyl(0.95 * math.cos(a), 0.95 * math.sin(a), 12.9, 0.08, 0.08, 0.15, seg=6)
    g["Steel"].cyl(0, 0, 6.0, 0.22, 0.22, 4.0, seg=10)
    g["Iron"].box(0, 0, 5.1, 1.7, 1.4, 1.8)
    g["Steel"].box(0, 0, 4.05, 1.4, 1.2, 0.3)
    g["Brass"].box(0, -0.71, 5.1, 1.2, 0.04, 0.2)
    # 조작 손잡이(오른 기둥 앞) + 밸브까지 가는 막대 + 실린더 옆 밸브
    g["Iron"].hcyl(2.55, -0.85, 2.4, 0.18, 0.5, axis="x", seg=8)
    g["Iron"].obox(2.6, -1.15, 3.35, 0.14, 0.14, 2.1, rx=0.3)
    sphere(g, "Brass", (2.6, -1.45, 4.35), 0.2, sub=1)
    g["Steel"].box(2.75, -0.85, 6.4, 0.08, 0.08, 7.6)
    g["Brass"].hcyl(1.15, 0, 11.2, 0.3, 0.5, axis="x", seg=10)
    g["Iron"].hcyl(1.45, 0, 11.2, 0.45, 0.08, axis="x", seg=14)
    # 배기관 + 김
    S.pipe(g, [(0.5, 0.45, 12.9), (0.5, 0.45, 15.2)], 0.22, mat="Iron")
    S.vent(g, 0.5, 0.45, 15.5)
    # 집게 둘(받침에 기댐)
    g["Iron"].obox(-1.55, -1.45, 1.35, 0.1, 0.1, 2.5, ry=0.25)
    g["Iron"].obox(-1.3, -1.45, 1.35, 0.1, 0.1, 2.5, ry=0.33)
    C(0, 0, 0.3, 5.4, 4.2, 0.6)
    C(0, 0, 1.45, 2.8, 2.4, 1.7)
    for s in (-1, 1):
        C(s * 2.0, 0, 4.8, 1.2, 1.9, 8.4)


def yard_boiler(g, pipe_to):
    """세운 보일러(0, 0): 놋쇠 띠 두른 쇠 몸통 · 화실 쇠살 문(붉은 불빛) · 압력계 · 안전 밸브 · 굴뚝(김) · 해머로 가는 구리 관(pipe_to = 관 끝 x)"""
    S.banded_cyl(g, "Iron", 0, 0, 0.0, 1.4, 5.0, band="Brass", every=1.6, seg=16, cap="Iron")
    g["Brass"].box(0, -1.42, 1.2, 1.5, 0.14, 1.3)
    g["Core"].box(0, -1.46, 1.15, 1.1, 0.06, 0.8)
    for k in range(5):
        g["Iron"].box(-0.44 + k * 0.22, -1.52, 1.15, 0.07, 0.07, 0.9)
    g["Brass"].hcyl(0.55, -1.45, 3.6, 0.42, 0.14, axis="y", seg=16)
    g["Dial"].hcyl(0.55, -1.53, 3.6, 0.34, 0.04, axis="y", seg=16)
    g["Iron"].obox(0.62, -1.57, 3.67, 0.04, 0.02, 0.28, ry=-0.7)
    g["Brass"].cyl(-0.6, 0.2, 6.0, 0.18, 0.14, 0.6, seg=8)
    g["Iron"].obox(-0.3, 0.2, 6.65, 0.9, 0.08, 0.08, ry=0.15)
    g["Iron"].cyl(0.5, 0.5, 5.8, 0.35, 0.35, 8.6, seg=10)
    g["Iron"].cyl(0.5, 0.5, 14.4, 0.45, 0.45, 0.25, seg=10)
    S.vent(g, 0.5, 0.5, 14.95)
    S.pipe(g, [(-1.2, 0.0, 4.4), (pipe_to, 0.0, 4.4), (pipe_to, 0.0, 9.3)], 0.22, mat="Copper")
    g["Iron"].hcyl((-1.2 + pipe_to) / 2, 0.0, 4.95, 0.45, 0.08, axis="y", seg=14)       # 관 밸브 손바퀴
    g["Iron"].box((-1.2 + pipe_to) / 2, 0.0, 4.65, 0.08, 0.08, 0.4)
    C(0, 0, 2.5, 2.8, 2.8, 5.0)


def open_shed(g, w, d, h_eave, h_ridge, posts_x, floor="Stone"):
    """맞배 헛간(용마루 x 방향, 가운데 (0, 0)): 기둥 · 처마 보 · 함석 지붕 두 판 + 눈 · 용마루 보 · 양끝 박공 버팀 · 바닥 판"""
    g[floor].box(0, 0, 0.08, w - 0.6, d - 0.6, 0.16)
    for px in posts_x:
        for py in (-d / 2 + 0.3, d / 2 - 0.3):
            g["Timber"].box(px, py, h_eave / 2, 0.5, 0.5, h_eave)
            C(px, py, h_eave / 2, 0.5, 0.5, h_eave)
    for py in (-d / 2 + 0.3, d / 2 - 0.3):
        g["Timber"].box(0, py, h_eave - 0.3, w, 0.45, 0.6)
    half = d / 2 + 0.8
    rise = h_ridge - h_eave
    sl = math.atan2(rise, half)
    Ls = math.hypot(half, rise)
    for s in (-1, 1):
        cy, cz = s * half / 2, h_eave + rise / 2
        g["RoofMetal"].obox(0, cy, cz + 0.1, w + 1.2, Ls, 0.22, rx=-s * sl)
        g["SnowCap"].obox(0, cy * 0.96, cz + 0.32, w + 0.8, Ls - 0.5, 0.22, rx=-s * sl)
    g["Timber"].box(0, 0, h_ridge - 0.25, w, 0.4, 0.4)
    for px in (-w / 2 + 0.3, w / 2 - 0.3):
        g["Timber"].box(px, 0, h_eave + 0.1, 0.35, d - 0.6, 0.35)
        g["Timber"].box(px, 0, (h_eave + h_ridge) / 2, 0.3, 0.3, rise)


def hammer_shed(g):
    """증기 해머 헛간: 16×10 맞배 + 해머(왼) + 보일러(오른) + 돌 바닥"""
    open_shed(g, 16.0, 10.0, 10.6, 13.0, (-7.75, 0.0, 7.75))
    place(g, -2.5, 0.5, steam_hammer)
    place(g, 4.2, 1.6, lambda q: yard_boiler(q, -4.2 - 2.5 + 0.7))


def ore_cart(g):
    g["Wood"].box(0, 0, 1.6, 3.4, 2.0, 1.2)
    for z in (1.1, 2.1):
        g["Iron"].box(0, 0, z, 3.5, 2.1, 0.14)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Iron"].hcyl(sx * 1.1, sy * 1.1, 0.55, 0.55, 0.2, axis="y", seg=12)
    g["Iron"].obox(2.4, 0, 1.9, 1.6, 0.12, 0.12, ry=-0.4)
    ore_lumps(g, 0, 0, 2.1, r=0.9, n=7, seed=21)
    C(0, 0, 1.2, 3.6, 2.4, 2.4)


def brazier(g):
    """숯 화로: 쇠 그릇 · 다리 셋 · 숯불(진짜 불)"""
    g["Iron"].cyl(0, 0, 1.8, 0.9, 1.1, 0.7, seg=14)
    for k in range(3):
        a = k * 2 * math.pi / 3
        g["Iron"].obox(0.75 * math.cos(a), 0.75 * math.sin(a), 0.95, 0.16, 0.16, 1.9, rx=0.15 * math.sin(a), ry=-0.15 * math.cos(a))
    coal_bed(g, 0, 0, 2.35, 1.4, 1.4, size=0.5)
    C(0, 0, 1.25, 2.2, 2.2, 2.5)


def quench_tub(g):
    g["Wood"].box(0, 0, 0.8, 4.6, 1.8, 1.6)
    for x in (-2.2, 2.2):
        g["Iron"].box(x, 0, 0.85, 0.15, 1.9, 1.7)
    g["Iron"].box(0, 0, 1.55, 4.7, 1.9, 0.12)
    g["Glass"].box(0, 0, 1.52, 4.3, 1.5, 0.08)
    C(0, 0, 0.8, 4.7, 1.9, 1.7)


def sword_rack(g):
    """칼 식힘대: 기운 다리 넷 · 가로대 · 칼 넷(날 Steel · 손잡이 가죽)"""
    for sx in (-1.4, 1.4):
        for sy in (-1, 1):
            g["Timber"].obox(sx, sy * 0.4, 1.4, 0.2, 0.2, 2.6, rx=-sy * 0.3)
    g["Timber"].box(0, 0, 2.35, 3.2, 0.2, 0.2)
    for k, x in enumerate((-1.0, -0.3, 0.4, 1.1)):
        g["Steel"].obox(x, -0.4, 1.4, 0.07, 0.3, 2.4, rx=0.32)
        g["Leather"].obox(x, -0.75, 2.55, 0.14, 0.14, 0.7, rx=0.32)
    C(0, 0, 1.3, 3.4, 1.4, 2.6)


def tool_stand(g):
    """연장 걸이(길이 y): 기둥 둘 · 가로대 둘 · 망치 셋 · 집게 둘 · 줄"""
    for y in (-1.3, 1.3):
        g["Timber"].box(0, y, 1.6, 0.3, 0.3, 3.2)
    for z in (2.9, 1.9):
        g["Timber"].box(0, 0, z, 0.2, 2.9, 0.2)
    for k, y in enumerate((-0.9, 0.0, 0.9)):
        g["Timber"].box(-0.15, y, 2.3, 0.1, 0.1, 1.2)
        g["Iron"].box(-0.15, y, 1.7, 0.3, 0.55, 0.28)
    for y in (-0.45, 0.45):
        g["Iron"].obox(0.15, y, 1.3, 0.06, 0.06, 1.3, rx=0.1)
        g["Iron"].obox(0.15, y + 0.1, 1.3, 0.06, 0.06, 1.3, rx=-0.1)
    C(0, 0, 1.6, 0.6, 3.0, 3.2)


def charcoal_kiln(g):
    """숯가마(벌집꼴): 돌 굽 · 벽돌 반구 · 쇠 띠 둘 · 꼭대기 굴뚝(연기) · 앞 아치 쇠 문틀 + 반쯤 연 문짝 + 안 숯불(진짜 불)"""
    g["StoneTrim"].cyl(0, 0, 0, 3.8, 3.7, 0.6, seg=20)
    dome(g, "Brick", 0, 0, 0.6, 3.4, n=6, seg=20)
    for h in (1.0, 2.4):
        rr = math.sqrt(3.4 ** 2 - h * h)
        S.ring(g, "Iron", 0, 0, 0.6 + h - 0.1, rr - 0.02, rr + 0.12, 0.2, n=20)
    g["Brick"].cyl(0, 0, 3.6, 0.75, 0.6, 1.5, seg=12)
    g["Iron"].cyl(0, 0, 5.1, 0.75, 0.75, 0.2, seg=12)
    S.vent(g, 0, 0, 5.6)
    g["Iron"].box(0, -3.15, 1.55, 2.2, 0.7, 0.3)
    for s in (-1, 1):
        g["Iron"].box(s * 0.95, -3.1, 1.0, 0.3, 0.8, 1.2)
    g["Soot"].box(0, -2.9, 0.95, 1.6, 0.5, 1.1)
    coal_bed(g, 0, -3.0, 0.6, 1.2, 0.6, size=0.45)
    g["Iron"].obox(-1.55, -3.75, 1.0, 1.2, 0.12, 1.1, rz=1.1)
    C(0, 0, 1.6, 6.4, 6.4, 3.2)


def log_stack(g, length=3.2, rows=(4, 3, 2), r=0.35, axis="y"):
    """통나무 쌓음(긴 쪽 axis)"""
    for j, n in enumerate(rows):
        for k in range(n):
            u = (k - (n - 1) / 2) * 2 * r * 1.02
            z = r + j * r * 1.75
            if axis == "y":
                g["Timber" if (k + j) % 2 else "Wood"].hcyl(u, 0, z, r, length, axis="y", seg=8)
            else:
                g["Timber" if (k + j) % 2 else "Wood"].hcyl(0, u, z, r, length, axis="x", seg=8)
    w = rows[0] * 2 * r * 1.02
    top = r + (len(rows) - 1) * r * 1.75 + r
    snow(g, 0, 0, top - 0.05, *((0.6, length - 0.3) if axis == "y" else (length - 0.3, 0.6)), t=0.1)
    C(0, 0, top / 2, *((w, length) if axis == "y" else (length, w)), top)


def coal_heap(g):
    frustum(g, "Char", 0, 0, 0, 3.0, 2.6, 0.9, 0.8, 1.3)
    ore_lumps(g, 0, 0, 0.0, r=1.3, n=10, seed=41, mats=("Char", "Soot"))
    C(0, 0, 0.7, 3.0, 2.6, 1.4)


def sawhorse(g):
    """톱질 모탕(길이 x): X 다리 둘 · 얹은 통나무 · 걸쳐 둔 활톱"""
    for x in (-1.1, 1.1):
        for s in (-1, 1):
            g["Timber"].obox(x, 0, 0.82, 0.18, 0.18, 1.7, rx=s * 0.5)
    g["Timber"].box(0, 0, 1.25, 2.6, 0.2, 0.2)
    g["Wood"].hcyl(0.3, 0, 1.75, 0.42, 3.6, axis="x", seg=10)
    g["Timber"].box(0.4, -0.7, 2.6, 0.1, 0.1, 1.4)
    g["Timber"].box(1.6, -0.7, 2.6, 0.1, 0.1, 1.4)
    g["Timber"].box(1.0, -0.7, 3.25, 1.3, 0.08, 0.08)
    g["Steel"].box(1.0, -0.7, 1.95, 1.3, 0.04, 0.12)
    C(0, 0, 1.1, 3.6, 1.6, 2.2)


def chopping_block(g):
    g["Wood"].cyl(0, 0, 0, 0.75, 0.7, 1.0, seg=12)
    g["Char"].cyl(0, 0, 1.0, 0.68, 0.68, 0.03, seg=12)
    g["Timber"].obox(0.25, 0.1, 1.55, 0.12, 0.12, 1.3, ry=0.5)
    g["Steel"].obox(-0.05, 0.1, 1.05, 0.5, 0.08, 0.32, ry=0.5)
    for k, (x, y, rz) in enumerate(((1.4, 0.3, 0.2), (1.7, -0.4, 1.1), (1.2, -0.9, 2.3), (2.0, 0.4, 0.6), (1.6, 0.0, 1.8))):
        g["Wood" if k % 2 else "Timber"].obox(x, y, 0.2 + (k // 3) * 0.35, 1.0, 0.32, 0.3, rz=rz)
    C(0, 0, 0.6, 1.5, 1.5, 1.2)
    C(1.6, -0.2, 0.35, 1.6, 1.8, 0.7)


def treadle_grindstone(g):
    """발 숫돌(굴대 x): 나무 틀 · 돌 바퀴 · 물받이 · 발판·연결대 · 앉을 판"""
    for x in (-0.8, 0.8):
        g["Timber"].box(x, 0, 1.3, 0.25, 1.6, 0.25)
        for y in (-0.7, 0.7):
            g["Timber"].box(x, y, 0.65, 0.22, 0.22, 1.3)
    g["Stone"].hcyl(0, 0, 2.3, 1.15, 0.45, axis="x", seg=20)
    g["Iron"].hcyl(0, 0, 2.3, 0.12, 2.0, axis="x", seg=8)
    g["Wood"].box(0, 0, 1.25, 1.2, 1.4, 0.4)
    g["Glass"].box(0, 0, 1.47, 1.0, 1.2, 0.04)
    g["Timber"].obox(0, -1.3, 0.35, 0.3, 1.6, 0.1, rx=0.15)
    g["Iron"].box(0.9, -0.6, 1.4, 0.06, 0.06, 1.9)
    g["Timber"].box(0, 1.4, 1.1, 1.6, 0.6, 0.15)
    for x in (-0.6, 0.6):
        g["Timber"].box(x, 1.4, 0.5, 0.15, 0.15, 1.0)
    C(0, 0.2, 1.3, 2.0, 2.8, 2.6)


def hand_cart(g, crates=True):
    """납품 손수레(긴 쪽 y, 손잡이 -y): 짐칸 · 바퀴 둘(살) · 손잡이 · 받침 다리 · 상자·칼 자루"""
    g["Wood"].box(0, 0.4, 1.4, 2.4, 3.4, 0.25)
    for s in (-1, 1):
        g["Timber"].box(s * 1.15, 0.4, 1.9, 0.15, 3.4, 0.8)
    g["Timber"].box(0, 2.05, 1.9, 2.4, 0.15, 0.8)
    for s in (-1, 1):
        wheel(g, s * 1.45, 0.6, 1.0, 1.0, axis="x", n=8)
        g["Timber"].obox(s * 0.9, -2.2, 1.2, 0.14, 2.4, 0.14, rx=0.12)
    g["Iron"].hcyl(0, 0.6, 1.0, 0.09, 3.0, axis="x", seg=8)
    g["Timber"].box(0, -1.0, 0.55, 0.15, 0.15, 1.1)
    if crates:
        crate(g, -0.5, 0.8, 1.52, s=1.2)
        crate(g, 0.55, 0.2, 1.52, s=1.0, rz=0.25)
        sword_hilt_up(g, 0.5, 1.6, 1.6, blade=1.2)
        sword_hilt_up(g, 0.8, 1.5, 1.6, blade=1.2, lean=0.2)
    C(0, 0.0, 1.3, 2.8, 4.6, 2.6)


def yard_smithy(g):
    K = "Yard_Smithy"
    fence(g, K, gates=((4.0, 42.4, 8.0, True), (-46.0, 21.0, 7.5, False), (45.9, 21.0, 7.5, False)),
          icon=lambda q, x, y, z, f: anvil_icon(q, x - 0.2, y, z - 0.15, s=0.42, face=f))
    # 길: 뒷문(x 1..7) → 뒤 큰 문 · 뒷벽을 따라 두 옆 문을 잇는 일 길
    path(g, (4.0, 15.2), (4.0, 41.7), 5.0, lv=0)
    path(g, (-45.4, 21.0), (45.3, 21.0), 4.0, lv=1)
    for x in (0.0, 8.0):
        lamp_post(g, x, 24.2)
    for x in (-1.6, 9.6):
        fir(g, x, 38.2, h=7.5)
    # 왼쪽: 광석 더미 셋 + 광석 수레 · 증기 해머 헛간
    for k, (x, y, r) in enumerate(((-42.5, 27.6, 1.8), (-38.0, 30.8, 1.7), (-43.0, 31.7, 1.45))):
        ore_lumps(g, x, y, 0.0, r=r, n=14, seed=11 + k, mound=True)
        sphere(g, "SnowCap", (x + 0.2, y + 0.1, 1.18 * r), 0.47 * r, sub=1)
        C(x, y, 0.65 * r, 2.2 * r, 2.2 * r, 1.3 * r)
    place(g, -35.5, 25.8, ore_cart)
    place(g, -22.0, 30.5, hammer_shed)
    NPC(-21.0, 28.0, 0.16, -90.0)                                           # 해머 조작공(손잡이 곁에서 해머를 본다)
    # 오른쪽: 바깥 화덕(그을음 판) — 모루 · 숯 화로 · 담금질 통 · 칼 식힘대 · 연장 걸이 · 물통
    g["Soot"].box(18.5, 30.5, 0.03, 15.0, 11.0, 0.06)
    PROP("Anvil", 16.0, 29.5, 0.06, -20.0, 1.0)
    C(16.0, 29.5, 1.8, 2.0, 2.0, 3.3)
    place(g, 20.0, 32.6, brazier)
    place(g, 23.0, 27.3, quench_tub)
    place(g, 13.5, 34.4, sword_rack)
    place(g, 11.8, 29.0, tool_stand)
    barrel(g, 25.2, 33.9, 0.06, r=0.85, h=1.9)
    NPC(16.0, 27.0, 0.06, 180.0)                                            # 대장 도제(모루 앞)
    # 숯가마 · 통나무 · 숯 더미
    place(g, 37.0, 29.6, charcoal_kiln)
    place(g, 43.2, 25.6, log_stack)
    place(g, 31.0, 35.0, coal_heap)
    # 왼 날개: 나무 마당(큰 통나무 더미 · 톱질 모탕 · 장작 패는 그루터기)
    place(g, -29.0, 4.0, lambda q: log_stack(q, length=9.0, rows=(3, 2, 1), r=0.55))
    place(g, -34.0, 12.2, sawhorse)
    place(g, -27.2, 13.6, chopping_block)
    # 오른 날개: 발 숫돌 · 납품 수레 · 상자 · 물통
    place(g, 28.5, 3.0, treadle_grindstone)
    place(g, 31.6, 11.0, hand_cart)
    for x, y, s_, rz, z in ((26.6, 14.2, 2.0, 0.0, 0.0), (26.9, 11.7, 1.8, 0.3, 0.0), (26.6, 14.2, 1.5, 0.4, 2.0)):
        crate(g, x, y, z, s=s_, rz=rz)
        C(x, y, z + s_ / 2, s_, s_, s_, rz)
    barrel(g, 37.0, 15.6, 0.0, r=0.85, h=1.9)
    barrel(g, 35.2, 16.4, 0.0, r=0.85, h=1.9)


# ------------------------------------------------------------------ 강화소 룬 시험장
def rune_circle(g, r=7.5):
    """바닥 룬 원: 검은 돌 판 · 놋쇠 테 둘 · 청록 빛 테 · 글자 열둘"""
    g["DarkStone"].cyl(0, 0, 0, r, r, 0.12, seg=36)
    S.ring(g, "Brass", 0, 0, 0.12, r - 0.5, r - 0.2, 0.04, n=36)
    S.ring(g, "GlowTeal", 0, 0, 0.12, r - 1.35, r - 1.15, 0.03, n=36)
    S.ring(g, "Brass", 0, 0, 0.12, r - 2.9, r - 2.7, 0.04, n=36)
    for k in range(12):
        a = k * math.pi / 6 + math.pi / 12
        rr = r - 2.05
        g["GlowTeal"].obox(rr * math.cos(a), rr * math.sin(a), 0.135, 0.7, 0.18, 0.03, rz=a + (0.5 if k % 2 else -0.4))
        g["GlowTeal"].obox(rr * math.cos(a) + 0.15 * math.cos(a + 1.5), rr * math.sin(a) + 0.15 * math.sin(a + 1.5), 0.135, 0.18, 0.5, 0.03, rz=a)


def resonance_tower(g):
    """공명탑: 팔각 돌 받침 · 놋쇠 세 다리(구리 감은 줄) · 수정 받침 접시 · 위아래 뿔 청록 수정(빛) · 수정을 두른 놋쇠 고리 둘 · 꼭대기 피뢰 침"""
    g["StoneTrim"].cyl(0, 0, 0, 1.9, 1.7, 0.8, seg=8)
    g["StoneTrim"].cyl(0, 0, 0.8, 1.4, 1.3, 0.5, seg=8)
    for k in range(3):
        a = k * 2 * math.pi / 3
        x, y = 1.1 * math.cos(a), 1.1 * math.sin(a)
        g["Brass"].obox(x * 0.75, y * 0.75, 4.0, 0.22, 0.22, 5.6, rx=-0.09 * math.sin(a) * 1.6, ry=0.09 * math.cos(a) * 1.6)
        for j in range(5):
            zz = 2.2 + j * 0.7
            g["Copper"].cyl(x * (0.88 - j * 0.03), y * (0.88 - j * 0.03), zz, 0.2, 0.2, 0.12, seg=8)
    g["Brass"].cyl(0, 0, 6.6, 0.5, 1.0, 0.45, seg=12)
    frustum(g, "GlowTeal", 0, 0, 7.05, 0.15, 0.15, 1.1, 1.1, 1.0)
    frustum(g, "GlowTeal", 0, 0, 8.05, 1.1, 1.1, 0.12, 0.12, 1.6)
    g["LampPt"].box(0, 0, 8.2, 0.3, 0.3, 0.3)
    S.ring(g, "Brass", 0, 0, 7.6, 1.2, 1.4, 0.12, n=18)
    S.ring(g, "Brass", 0, 0, 8.6, 1.0, 1.2, 0.12, n=18)
    for k in range(3):
        a = k * 2 * math.pi / 3 + math.pi / 3
        g["Brass"].box(1.3 * math.cos(a), 1.3 * math.sin(a), 8.1, 0.1, 0.1, 1.1)
    g["Iron"].cyl(0, 0, 9.65, 0.06, 0.02, 1.4, seg=6)
    C(0, 0, 0.65, 3.6, 3.6, 1.3)
    C(0, 0, 4.0, 2.2, 2.2, 5.4)


def rune_pillar(g):
    """룬 돌 기둥: 돌 기둥 · 검은 룬 돌(빗김) · 청록 글자 · 놋쇠 바닥 테 · 위 눈"""
    g["StoneTrim"].box(0, 0, 2.0, 1.8, 1.8, 4.0)
    g["StoneTrim"].box(0, 0, 0.25, 2.2, 2.2, 0.5)
    g["DarkStone"].obox(0, 0, 4.85, 1.0, 1.2, 1.6, rz=0.3)
    g["GlowTeal"].obox(0, 0, 4.85, 1.05, 0.4, 0.8, rz=0.3)
    snow(g, 0, 0, 4.0, 1.7, 1.7, t=0.12)
    g["LampPt"].box(0, 0, 4.85, 0.3, 0.3, 0.3)
    S.ring(g, "Brass", 0, 0, 0.0, 1.4, 1.7, 0.06, n=16)
    C(0, 0, 2.0, 2.2, 2.2, 4.0)


def scorched_target(g):
    """그을린 과녁(앞 -y): 나무 기둥 둘 · 쇠판 · 그을음 · 탄 룬 자국"""
    for x in (-0.9, 0.9):
        g["Timber"].box(x, 0.2, 1.6, 0.3, 0.3, 3.2)
    g["Iron"].box(0, 0, 2.3, 2.2, 0.2, 2.2)
    g["Soot"].hcyl(0, -0.11, 2.3, 0.8, 0.04, axis="y", seg=16)
    g["GlowTeal"].obox(0.1, -0.14, 2.35, 0.9, 0.03, 0.1, ry=0.7)
    g["GlowTeal"].obox(-0.15, -0.14, 2.2, 0.6, 0.03, 0.1, ry=-0.5)
    g["Timber"].box(0, 0.2, 0.25, 2.4, 0.9, 0.3)
    snow(g, 0, 0, 3.4, 2.2, 0.3, t=0.08)
    C(0, 0.1, 1.7, 2.4, 0.9, 3.4)


def carving_bench(g):
    """룬 새김 작업대(앞 -y): 탁자 · 새기던 룬 돌판 · 정·망치 · 등 · 걸상"""
    g["Wood"].box(0, 0, 2.9, 4.0, 1.8, 0.25)
    for sx in (-1.8, 1.8):
        for sy in (-0.75, 0.75):
            g["Timber"].box(sx, sy, 1.4, 0.25, 0.25, 2.8)
    g["DarkStone"].box(-0.4, 0.1, 3.15, 1.8, 1.1, 0.25)
    g["GlowTeal"].box(-0.6, 0.1, 3.29, 0.8, 0.12, 0.03)
    g["GlowTeal"].box(-0.2, 0.1, 3.29, 0.12, 0.6, 0.03)
    g["Steel"].obox(0.9, -0.2, 3.1, 0.6, 0.08, 0.08, rz=0.4)
    g["Timber"].obox(1.3, 0.3, 3.1, 0.8, 0.12, 0.12, rz=-0.3)
    g["Iron"].box(1.6, 0.3, 3.12, 0.3, 0.22, 0.2)
    g["Brass"].cyl(-1.6, 0.5, 3.02, 0.25, 0.2, 0.2, seg=8)
    g["Glass"].box(-1.6, 0.5, 3.5, 0.5, 0.5, 0.6)
    g["Glow"].box(-1.6, 0.5, 3.45, 0.14, 0.14, 0.26)
    g["Wood"].cyl(0.3, -1.6, 0, 0.45, 0.45, 1.8, seg=10)
    C(0, 0, 1.5, 4.0, 1.8, 3.0)


def rune_crate(g):
    crate(g, 0, 0, 0.0, s=2.0)
    for k, (x, y) in enumerate(((-0.4, -0.3), (0.3, 0.2), (0.0, 0.5), (0.5, -0.4))):
        g["GlowTeal" if k % 2 else "DarkStone"].obox(x, y, 2.05, 0.45, 0.35, 0.3, rz=k * 0.8)
    C(0, 0, 1.0, 2.0, 2.0, 2.0)


def stone_bench(g):
    g["StoneTrim"].box(0, 0, 1.0, 4.0, 1.2, 0.4)
    snow(g, 0, 0, 1.2, 3.8, 1.0, t=0.12)
    for x in (-1.5, 1.5):
        g["StoneTrim"].box(x, 0, 0.4, 0.6, 1.0, 0.8)
    C(0, 0, 0.65, 4.0, 1.2, 1.3)


def yard_enhance(g):
    K = "Yard_Enhance"
    fence(g, K, gates=((0.0, 44.5, 8.0, True), (-24.8, 20.0, 7.0, False), (21.45, 20.0, 7.0, False)),
          icon=lambda q, x, y, z, f: rune_icon(q, x, y, z - 0.05, face=f))
    path(g, (-24.3, 20.0), (20.9, 20.0), 3.6, lv=1)
    path(g, (0.0, 38.4), (0.0, 43.7), 3.6, lv=0)
    place(g, 0.0, 31.0, rune_circle)
    place(g, 0.0, 31.0, resonance_tower)
    for sx in (-1, 1):
        for sy in (-1, 1):
            place(g, sx * 6.8, 31.0 + sy * 6.8, rune_pillar)
    for x, y in ((-17.6, 26.6), (-19.6, 31.6), (-21.2, 36.4)):                # 과녁은 원 가운데를 본다
        place(g, x, y, scorched_target, rz=math.atan2(31.0 - y, 0.0 - x) - math.pi / 2 + math.pi)
    place(g, 18.4, 30.0, carving_bench, rz=-math.pi / 2)
    NPC(16.6, 29.7, 0.0, 90.0)                                              # 룬 새김 장인(걸상에서 작업대를 본다)
    place(g, 19.6, 25.2, rune_crate)
    place(g, 20.8, 35.0, rune_crate)
    for x in (-8.0, 8.0):
        place(g, x, 16.9, stone_bench)
    for x in (-11.5, 11.5):
        lamp_post(g, x, 23.0)
    lamp_post(g, -17.6, 11.6)
    lamp_post(g, 16.9, 11.6)
    fir(g, -22.4, 39.0, h=7.0)
    fir(g, 21.0, 39.0, h=7.0)


# ------------------------------------------------------------------ 은행 금고 구역
BANK_OUT = [(-18.24, -6.0), (-24.32, -6.0), (-41.75, 33.0), (-20.0, 38.5), (20.0, 38.5), (45.92, 33.0), (25.21, -6.0), (18.24, -6.0)]
H_V = 12.4                     # 겉벽 꼭대기(지붕 윗면)
SR = (-9.5, 9.5, 15.0, 28.0)   # 금고실 겉면(x0, x1, y0, y1) — 앞벽 = 은행 뒷벽


def blind_window(g):
    """아치 벽감(벽 겉면 y = 0, 바깥 -y): 검은 돌 판 · 대리석 창턱 · 문설주 둘 · 반원 아치 테 + 이맛돌 · 쇠살 셋"""
    g["DarkStone"].box(0, -0.06, 6.6, 2.6, 0.12, 4.0)
    half_ring_y(g, "DarkStone", 0, -0.06, 8.6, 0.0, 1.3, 0.12, n=12)
    g["Marble"].box(0, -0.2, 4.45, 3.4, 0.4, 0.3)
    for s_ in (-1, 1):
        g["Marble"].box(s_ * 1.5, -0.15, 6.6, 0.4, 0.3, 4.0)
    half_ring_y(g, "Marble", 0, -0.15, 8.6, 1.3, 1.7, 0.3, n=12)
    g["Marble"].box(0, -0.25, 10.15, 0.6, 0.3, 0.7)
    for x in (-0.65, 0.0, 0.65):
        g["Iron"].box(x, -0.16, 7.0, 0.1, 0.08, 4.6)


def bank_pilaster_wall(g, a, b, inward, base=True, pil=True):
    """겉벽 바깥 면 장식: 검은 돌 밑동 · 대리석 붙임기둥(8.5 안팎마다) · 기둥 사이 아치 벽감 · 띠돌 · 위 처마 띠
    (금고는 창을 내지 않는다 — 1788 잉글랜드 은행 존 소운의 창 없는 바깥벽처럼 붙임기둥과 막힌 아치 창으로 꾸민다)"""
    L = math.dist(a, b)
    an = _ang(a, b)
    ux, uy = math.cos(an), math.sin(an)
    ox, oy = -inward[0], -inward[1]                     # 바깥 쪽
    cx, cy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    if base:
        g["DarkStone"].obox(cx + ox * 0.12, cy + oy * 0.12, 1.2, L, 0.24, 2.4, rz=an)
    g["Marble"].obox(cx + ox * 0.2, cy + oy * 0.2, H_V - 0.9, L, 0.4, 0.8, rz=an)
    g["Marble"].obox(cx + ox * 0.12, cy + oy * 0.12, 3.6, L, 0.24, 0.35, rz=an)                     # 띠돌
    n = max(1, int(L / 8.5))
    for k in range(n + 1 if pil else 0):
        u = -L / 2 + 0.9 + (L - 1.8) * k / n
        px, py = cx + ux * u, cy + uy * u
        g["Marble"].obox(px + ox * 0.25, py + oy * 0.25, (H_V - 1.3) / 2, 1.4, 0.5, H_V - 1.3, rz=an)
        g["Marble"].obox(px + ox * 0.35, py + oy * 0.35, 0.5, 1.8, 0.7, 1.0, rz=an)
        if k < n and (L - 1.8) / n > 4.6:
            u2 = u + (L - 1.8) / n / 2
            qx, qy = cx + ux * u2, cy + uy * u2
            place(g, qx, qy, blind_window, rz=math.atan2(ox, -oy))
    wedge_drift(g, (a[0] + ox * 0.25, a[1] + oy * 0.25), (b[0] + ox * 0.25, b[1] + oy * 0.25), 1 if (ux * oy - uy * ox) > 0 else -1, d=1.3, h=0.7)


def bank_walls(g):
    """겉벽(구역 선 위, 두께 1 · 높이 12.4) + 바깥 장식 + 지붕(볼록 셋) + 대리석 난간 + 눈 + 천장"""
    for i in range(len(BANK_OUT) - 1):
        a, b = BANK_OUT[i], BANK_OUT[i + 1]
        L = math.dist(a, b)
        an = _ang(a, b)
        ux, uy = math.cos(an), math.sin(an)
        nx, ny = uy, -ux                                # 오른 법선 = 안쪽(시계 방향으로 돈다)
        e0 = 0.0 if i == 0 else 0.5
        e1 = 0.0 if i == len(BANK_OUT) - 2 else 0.5
        cx = (a[0] + b[0]) / 2 + nx * 0.5 + ux * (e1 - e0) / 2
        cy = (a[1] + b[1]) / 2 + ny * 0.5 + uy * (e1 - e0) / 2
        g["StoneTrim"].obox(cx, cy, H_V / 2, L + e0 + e1, 1.0, H_V, rz=an)
        C(cx, cy, H_V / 2, L + e0 + e1, 1.0, H_V, an)
        bank_pilaster_wall(g, a, b, (nx, ny), pil=i not in (0, len(BANK_OUT) - 2))
        ix_, iy_ = (a[0] + b[0]) / 2 + nx * 1.12, (a[1] + b[1]) / 2 + ny * 1.12
        g["Wood"].obox(ix_, iy_, 1.6, L - 1.4, 0.24, 3.2, rz=an)
        g["Brass"].obox(ix_ + nx * 0.02, iy_ + ny * 0.02, 3.25, L - 1.4, 0.26, 0.12, rz=an)
        g["Marble"].obox(ix_ + nx * 0.1, iy_ + ny * 0.1, H_V - 1.15, L - 1.0, 0.45, 0.6, rz=an)
        g["Marble"].obox(cx, cy, H_V + 0.45, L + e0 + e1 + 0.3, 1.3, 0.9, rz=an)          # 난간 띠
        g["SnowCap"].obox(cx, cy, H_V + 1.0, L + e0 + e1, 1.1, 0.2, rz=an)
    parts = [[(-18.24, -6.0), (-24.32, -6.0), (-41.75, 33.0), (-20.0, 38.5), (-18.24, 38.5)],
             [(-18.24, 15.0), (18.24, 15.0), (18.24, 38.5), (-18.24, 38.5)],
             [(18.24, -6.0), (18.24, 38.5), (20.0, 38.5), (45.92, 33.0), (25.21, -6.0)]]
    for p_ in parts:
        slab_poly(g, "RoofMetal", p_, H_V - 0.5, H_V)
        slab_poly(g, "Marble", p_, H_V - 0.85, H_V - 0.5)                    # 천장(밝은 판)
    for p_ in parts:                                                         # 바닥(마을 땅 위 얇은 대리석) — 은행 바닥 판(±18.3, 15.3) 밖부터
        slab_poly(g, "Marble", [(math.copysign(18.3, x) if abs(abs(x) - 18.24) < 0.01 else x, 15.3 if abs(y - 15.0) < 0.01 else y) for x, y in p_],
                  0.0, 0.06)
    for p_ in parts:                                                         # 지붕 눈(판 전부 — 난간 띠 밑으로 들어간다)
        slab_poly(g, "SnowCap", p_, H_V, H_V + 0.25)
    # 별관 앞벽(광장 쪽) 바깥: 대리석 아치 벽감 + 놋쇠 금화 판 + 벽등
    for x0, x1 in ((-24.32, -18.24), (18.24, 25.21)):
        xm = (x0 + x1) / 2
        g["DarkStone"].box(xm, -6.05, 5.6, 2.8, 0.12, 6.0)
        half_ring_y(g, "Marble", xm, -6.15, 8.6, 1.4, 1.8, 0.3, n=12)
        for s in (-1, 1):
            g["Marble"].box(xm + s * 1.6, -6.15, 5.3, 0.4, 0.3, 6.6)
        g["Marble"].box(xm, -6.15, 2.4, 3.6, 0.3, 0.6)
        coin_icon(g, xm, -6.25, 6.0, -1)
        lamp = (xm - 2.4 if x0 < 0 else xm + 2.4)
        g["Iron"].box(lamp, -6.5, 7.6, 0.15, 0.9, 0.15)
        lantern(g, lamp, -7.0, 7.6, 6.7)


def strongroom(g):
    """금고실(쇠 벽 1.2, 앞벽 = 은행 뒷벽): 옆·뒤 벽에 쇠창살 창(회랑에서 금이 보이게) · 놋쇠 띠·리벳 · 검은 돌 바닥 판 ·
    가운데 금화 더미(은행 홀에서 둥근 금고 문 너머로 보인다) · 양옆 금괴 더미(나무 깔판) · 금화 자루 · 연 보물 궤짝 · 등 둘"""
    x0, x1, y0, y1 = SR
    t = 1.2
    W_LO, W_HI = 3.0, 8.0

    def wall_with_window(ax, a0, a1, fixed, w0, w1):
        """ax = 'x' 면 x 방향으로 뻗은 벽(y = fixed..fixed+t), 'y' 면 y 방향(x = fixed..fixed+t). 창 = w0..w1(벽 방향), 높이 W_LO..W_HI"""
        def B(u0, u1, z0, z1):
            if ax == "x":
                g["Iron"].box((u0 + u1) / 2, fixed + t / 2, (z0 + z1) / 2, u1 - u0, t, z1 - z0)
                C((u0 + u1) / 2, fixed + t / 2, (z0 + z1) / 2, u1 - u0, t, z1 - z0)
            else:
                g["Iron"].box(fixed + t / 2, (u0 + u1) / 2, (z0 + z1) / 2, t, u1 - u0, z1 - z0)
                C(fixed + t / 2, (u0 + u1) / 2, (z0 + z1) / 2, t, u1 - u0, z1 - z0)
        B(a0, w0, 0.0, H_V - 0.85)
        B(w1, a1, 0.0, H_V - 0.85)
        B(w0, w1, 0.0, W_LO)
        B(w0, w1, W_HI, H_V - 0.85)
        nb = int((w1 - w0) / 0.55)
        for k in range(nb):
            u = w0 + (k + 0.5) * (w1 - w0) / nb
            if ax == "x":
                g["Steel"].box(u, fixed + t / 2, (W_LO + W_HI) / 2, 0.16, 0.16, W_HI - W_LO)
            else:
                g["Steel"].box(fixed + t / 2, u, (W_LO + W_HI) / 2, 0.16, 0.16, W_HI - W_LO)
        for z in (W_LO + 1.6, W_HI - 1.6):
            if ax == "x":
                g["Brass"].box((w0 + w1) / 2, fixed + t / 2, z, w1 - w0, 0.24, 0.14)
            else:
                g["Brass"].box(fixed + t / 2, (w0 + w1) / 2, z, 0.24, w1 - w0, 0.14)
        if ax == "x":
            C((w0 + w1) / 2, fixed + t / 2, (W_LO + W_HI) / 2, w1 - w0, 0.3, W_HI - W_LO)
        else:
            C(fixed + t / 2, (w0 + w1) / 2, (W_LO + W_HI) / 2, 0.3, w1 - w0, W_HI - W_LO)
    wall_with_window("y", y0, y1, x0, 18.5, 23.5)
    wall_with_window("y", y0, y1, x1 - t, 18.5, 23.5)
    wall_with_window("x", x0, x1, y1 - t, -3.0, 3.0)
    # 겉 놋쇠 띠 · 리벳(회랑 쪽)
    for z in (2.4, 9.4):
        g["Brass"].box(x0 - 0.05, (y0 + y1) / 2, z, 0.12, y1 - y0, 0.25)
        g["Brass"].box(x1 + 0.05, (y0 + y1) / 2, z, 0.12, y1 - y0, 0.25)
        g["Brass"].box(0, y1 + 0.05, z, x1 - x0 + 0.2, 0.12, 0.25)
    for z in (1.2, 10.4):
        for k in range(9):
            y = y0 + 0.9 + k * (y1 - y0 - 1.8) / 8
            if not 18.0 < y < 24.0 or z > 9:
                for xx in (x0 - 0.06, x1 + 0.06):
                    g["Brass"].hcyl(xx, y, z, 0.1, 0.12, axis="x", seg=6)
    g["Brass"].box(0, y1 + 0.1, 9.9, 3.0, 0.1, 0.7)                        # 이름판(금고실)
    g["DarkStone"].box(0, (y0 + y1 - t) / 2, 0.1, x1 - x0 - 2 * t, y1 - y0 - t, 0.08)
    # 가운데 금화 더미
    frustum(g, "DarkStone", 0, 21.8, 0.14, 5.0, 4.2, 4.6, 3.8, 0.9)        # 단(은행 홀에서 금고 문 구멍 너머로 금이 보이게)
    g["Brass"].box(0, 21.8, 1.06, 4.7, 3.9, 0.06)
    L_.transformed(g, Matrix.Translation((0, 21.8, 1.08)) @ Matrix.Diagonal((1.1, 0.95, 0.3, 1.0)),
                   lambda q: dome(q, "SignGold", 0, 0, 0, 1.8, n=4, seg=18))

    def zs(x, y):                                                           # 둔덕 윗면 높이(납작한 타원 반구)
        return 1.08 + 0.54 * math.sqrt(max(0.0, 1 - (x / 1.98) ** 2 - ((y - 21.8) / 1.71) ** 2))
    for x, y, r in ((0.0, 21.8, 0.42), (-0.7, 21.3, 0.36), (0.8, 22.3, 0.38), (0.4, 21.0, 0.3), (-0.5, 22.5, 0.34), (1.3, 21.4, 0.28),
                    (-1.3, 22.0, 0.3), (0.1, 22.9, 0.28), (-0.2, 20.7, 0.26), (1.6, 22.6, 0.22), (-1.7, 21.2, 0.22)):
        sphere(g, "SignGold", (x, y, zs(x, y) + r * 0.45), r, sub=1)
    for k, (x, y, rz) in enumerate(((-0.6, 20.8, 0.3), (0.9, 22.9, 1.2), (-1.4, 22.3, 2.0))):
        L_.transformed(g, Matrix.Translation((x, y, zs(x, y) + 0.05)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(0.2, 4, "X"),
                       lambda q: frustum(q, "SignGold", 0, 0, 0, 0.85, 0.42, 0.68, 0.3, 0.3))
    for k in range(9):                                                      # 흘러내린 동전
        a = k * 0.7
        g["SignGold"].cyl(2.05 * math.cos(a), 21.8 + 1.7 * math.sin(a), 1.09, 0.2, 0.2, 0.06, seg=10)
    C(0, 21.8, 1.0, 5.0, 4.2, 2.0)
    # 양옆 금괴 더미(깔판 위 세 단, 단마다 엇갈림)
    for sx in (-1, 1):
        px, py = sx * 5.2, 18.6
        g["Timber"].box(px, py, 0.27, 3.0, 2.4, 0.26)
        for layer in range(3):
            for k in range(3):
                for j in range(2):
                    if layer % 2 == 0:
                        x, y = px - 0.95 + k * 0.95, py - 0.5 + j * 1.0
                        frustum(g, "SignGold", x, y, 0.4 + layer * 0.32, 0.85, 0.42, 0.68, 0.3, 0.3)
                    else:
                        x, y = px - 0.6 + j * 1.2, py - 0.8 + k * 0.8
                        L_.transformed(g, Matrix.Translation((x, y, 0.4 + layer * 0.32)) @ Matrix.Rotation(math.pi / 2, 4, "Z"),
                                       lambda q: frustum(q, "SignGold", 0, 0, 0, 0.85, 0.42, 0.68, 0.3, 0.3))
        C(px, py, 0.7, 3.0, 2.4, 1.4)
    # 금화 자루 · 연 보물 궤짝
    for k, (x, y) in enumerate(((-6.4, 24.4), (-5.2, 25.1), (6.6, 24.0))):
        sphere(g, "Canvas", (x, y, 0.75), 0.75, sub=2)
        g["Canvas"].cyl(x, y, 1.3, 0.3, 0.18, 0.5, seg=8)
        g["Leather"].cyl(x, y, 1.45, 0.24, 0.24, 0.1, seg=8)
        C(x, y, 0.75, 1.5, 1.5, 1.5)
    cx_, cy_ = 4.6, 24.8
    g["Wood"].box(cx_, cy_, 0.7, 2.4, 1.4, 1.2)
    for x in (cx_ - 1.0, cx_ + 1.0):
        g["Brass"].box(x, cy_, 0.7, 0.14, 1.46, 1.24)
    frustum(g, "SignGold", cx_, cy_, 1.3, 2.1, 1.1, 1.4, 0.7, 0.35)
    g["Wood"].obox(cx_, cy_ + 0.95, 1.95, 2.4, 0.16, 1.3, rx=-0.35)
    C(cx_, cy_, 0.7, 2.4, 1.4, 1.4)
    for x in (-4.0, 4.0):
        lantern(g, x, 21.0, H_V - 0.85, 8.8)


def deposit_cabinet(g, length, faces=(-1, 1), h=6.0):
    """대여 금고 함(긴 쪽 x, 두께 1.2): 나무 몸 · 대리석 갓 · 양면(faces) 놋쇠 서랍(열쇠 구멍 · 번호판) · 굽"""
    g["Wood"].box(0, 0, h / 2, length, 1.2, h)
    g["Marble"].box(0, 0, h + 0.12, length + 0.3, 1.5, 0.24)
    g["Timber"].box(0, 0, 0.2, length + 0.1, 1.3, 0.4)
    cols = int(length / 1.4)
    for f in faces:
        for i in range(cols):
            for j in range(4):
                x = -length / 2 + (i + 0.5) * length / cols
                z = 0.9 + j * (h - 1.3) / 4 + (h - 1.3) / 8
                g["Brass"].box(x, f * 0.62, z, length / cols - 0.18, 0.06, (h - 1.3) / 4 - 0.18)
                g["Iron"].box(x, f * 0.67, z, 0.16, 0.05, 0.16)
                g["Dial"].box(x, f * 0.66, z + 0.38, 0.4, 0.04, 0.12)
    C(0, 0, h / 2, length, 1.2, h)


def clerk_desk(g, length=6.0):
    """창구 책상(긴 쪽 y, 손님은 +x 쪽): 짙은 나무 앞판 · 대리석 윗판 · 놋쇠 띠 · 장부 · 잉크 · 종"""
    g["Timber"].box(0, 0, 1.6, 1.6, length, 3.2)
    for k in range(int(length / 1.5)):
        g["Wood"].box(0.82, -length / 2 + 0.75 + k * 1.5, 1.7, 0.06, 1.2, 2.2)
    g["Brass"].box(0.84, 0, 2.95, 0.08, length, 0.15)
    g["Marble"].box(0, 0, 3.35, 2.0, length + 0.3, 0.3)
    g["Leather"].box(0.1, -0.8, 3.58, 0.9, 1.2, 0.16)
    g["Char"].box(0.0, 0.6, 3.55, 0.4, 0.4, 0.1)
    g["Brass"].cyl(0.3, 1.6, 3.5, 0.28, 0.08, 0.3, seg=10)
    sphere(g, "Brass", (0.3, 1.6, 3.85), 0.08, sub=1)
    C(0, 0, 1.75, 2.0, length + 0.3, 3.5)


def key_board(g, length=5.0):
    """열쇠 판(벽에 붙임, 앞 +y): 나무 판 · 놋쇠 고리 줄 · 열쇠(놋쇠)와 번호표"""
    g["Wood"].box(0, 0, 6.0, length, 0.2, 2.6)
    g["Brass"].box(0, 0.12, 7.25, length + 0.1, 0.06, 0.12)
    for j in range(3):
        for i in range(int(length / 0.55)):
            x = -length / 2 + 0.3 + i * 0.55
            z = 6.9 - j * 0.8
            g["Brass"].box(x, 0.14, z, 0.05, 0.08, 0.05)
            if (i + j) % 3:
                g["Brass"].box(x, 0.16, z - 0.25, 0.08, 0.04, 0.38)
                g["Dial"].box(x, 0.16, z - 0.5, 0.18, 0.03, 0.12)


def wall_boxes(g, length, h=7.0):
    """벽 대여 금고(앞 +y): 나무 뒤판 · 놋쇠 서랍 줄 · 대리석 갓"""
    g["Wood"].box(0, 0.15, h / 2 + 0.3, length, 0.3, h)
    g["Marble"].box(0, 0.25, h + 0.42, length + 0.2, 0.6, 0.24)
    cols = int(length / 1.3)
    for i in range(cols):
        for j in range(5):
            x = -length / 2 + (i + 0.5) * length / cols
            z = 0.9 + j * (h - 0.6) / 5 + (h - 0.6) / 10
            g["Brass"].box(x, 0.33, z, length / cols - 0.16, 0.06, (h - 0.6) / 5 - 0.16)
            g["Iron"].box(x, 0.37, z, 0.15, 0.05, 0.15)
    C(0, 0.2, h / 2, length, 0.5, h)


def writing_desk(g):
    """손님 서랍 정리 책상(앞 -y): 탁자 · 칸막이 셋 · 걸상 · 등"""
    g["Wood"].box(0, 0, 2.9, 2.6, 1.3, 0.2)
    for x in (-1.15, 1.15):
        g["Timber"].box(x, 0, 1.4, 0.2, 1.2, 2.8)
    for x in (-1.3, 1.3):
        g["Timber"].box(x, 0.1, 4.0, 0.1, 1.4, 2.0)
    g["Timber"].box(0, 0.6, 4.0, 2.7, 0.1, 2.0)
    g["Brass"].box(0, -0.1, 3.05, 1.0, 0.7, 0.12)
    g["Wood"].cyl(0, -1.2, 0, 0.45, 0.45, 1.8, seg=10)
    C(0, 0, 1.5, 2.8, 1.4, 3.0)


def gold_cart_rails(g, x0, x1, y):
    """금 운반 레일(x 방향): 침목 · 강철 레일 둘 · 끝 막이"""
    n = int((x1 - x0) / 1.2)
    for k in range(n + 1):
        g["Timber"].box(x0 + k * (x1 - x0) / n, y, 0.1, 0.35, 2.0, 0.08)
    for s in (-1, 1):
        g["Steel"].box((x0 + x1) / 2, y + s * 0.7, 0.18, x1 - x0, 0.14, 0.12)
    for x in (x0 - 0.3, x1 + 0.3):
        g["Iron"].box(x, y, 0.5, 0.5, 2.0, 0.8)
        g["SignRed"].box(x, y, 0.95, 0.52, 2.02, 0.12)


def gold_cart(g):
    """금 수레(레일 위, 길이 x): 쇠 통(위 넓음) · 놋쇠 테 · 작은 바퀴 넷 · 금괴·금덩이 · 손잡이"""
    frustum(g, "Iron", 0, 0, 0.75, 2.2, 1.2, 2.8, 1.6, 1.3)
    g["Brass"].box(0, 0, 2.0, 2.9, 1.7, 0.12)
    for sx in (-0.8, 0.8):
        for sy in (-0.7, 0.7):
            g["Iron"].hcyl(sx, sy, 0.5, 0.32, 0.18, axis="y", seg=10)
    for k, (x, y, r) in enumerate(((-0.6, 0.0, 0.45), (0.3, 0.2, 0.5), (0.9, -0.3, 0.35), (-0.1, -0.35, 0.38))):
        sphere(g, "SignGold", (x, y, 1.95), r, sub=1)
    frustum(g, "SignGold", 0.2, 0.1, 2.15, 0.85, 0.42, 0.68, 0.3, 0.3)
    g["Iron"].obox(1.7, 0, 1.9, 0.9, 0.1, 0.1, ry=-0.4)
    C(0, 0, 1.3, 2.9, 1.7, 2.6)


def coin_counter(g):
    """동전 세는 기계(앞 -y): 놋쇠 몸 · 위 깔때기 · 옆 돌리는 손바퀴(손잡이) · 드러난 톱니 둘 · 숫자 창 · 아래 미끄럼통 + 동전 쟁반"""
    g["Brass"].box(0, 0, 1.5, 2.4, 1.6, 3.0)
    g["Iron"].box(0, 0, 0.15, 2.6, 1.8, 0.3)
    frustum(g, "Copper", 0, 0.1, 3.0, 0.6, 0.6, 1.8, 1.4, 1.0)
    for k in range(5):
        g["SignGold"].cyl(-0.3 + k * 0.15, 0.1, 3.85, 0.16, 0.16, 0.05, seg=8)
    g["Iron"].hcyl(1.32, 0, 2.0, 0.85, 0.12, axis="x", seg=16)
    g["Iron"].hcyl(1.32, 0, 2.0, 0.12, 0.4, axis="x", seg=8)
    for k in range(4):
        g["Iron"].obox(1.35, 0, 2.0, 0.08, 1.6, 0.08, rx=k * math.pi / 4)
    g["Wood"].hcyl(1.6, 0, 2.75, 0.1, 0.5, axis="x", seg=8)
    S.gear(g, "Iron", -0.6, -0.83, 2.2, 0.55, 12, 0.12)
    S.gear(g, "Copper", 0.2, -0.83, 2.45, 0.35, 9, 0.12)
    g["Dial"].box(0.0, -0.81, 1.15, 1.2, 0.04, 0.4)
    for k in range(4):
        g["Char"].box(-0.4 + k * 0.27, -0.84, 1.15, 0.14, 0.03, 0.26)
    g["Brass"].obox(0.0, -1.2, 0.85, 0.7, 0.9, 0.08, rx=0.5)
    g["Wood"].box(0.0, -1.75, 0.35, 1.4, 0.9, 0.3)
    for k in range(6):
        g["SignGold"].cyl(-0.45 + k * 0.18, -1.75, 0.5, 0.15, 0.15, 0.06 + 0.04 * (k % 3), seg=8)
    C(0, 0, 1.5, 2.6, 1.8, 3.0)
    C(0, -1.6, 0.4, 1.4, 1.2, 0.8)


def guild_cage(g, banner="Banner"):
    """길드 금고 우리(앞 -y, 5×3.2×6): 쇠 틀 · 촘촘한 살 · 문(자물쇠) · 안 궤짝 둘 · 매단 길드 깃발 · 놋쇠 이름판"""
    w, d, h = 5.0, 3.2, 6.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Iron"].box(sx * (w / 2 - 0.1), sy * (d / 2 - 0.1), h / 2, 0.22, 0.22, h)
    for z in (0.15, h - 0.1):
        g["Iron"].box(0, -d / 2 + 0.1, z, w, 0.18, 0.2)
        g["Iron"].box(0, d / 2 - 0.1, z, w, 0.18, 0.2)
        for sx in (-1, 1):
            g["Iron"].box(sx * (w / 2 - 0.1), 0, z, 0.18, d, 0.2)
    g["Iron"].box(0, 0, h, w, d, 0.1)
    for k in range(int(w / 0.4)):
        x = -w / 2 + 0.3 + k * 0.4
        if not -0.9 < x < 0.9:
            g["Rail"].box(x, -d / 2 + 0.1, h / 2, 0.08, 0.08, h - 0.3)
        g["Rail"].box(x, d / 2 - 0.1, h / 2, 0.08, 0.08, h - 0.3)
    for sx in (-1, 1):
        for k in range(int(d / 0.4)):
            g["Rail"].box(sx * (w / 2 - 0.1), -d / 2 + 0.3 + k * 0.4, h / 2, 0.08, 0.08, h - 0.3)
    for k in range(4):                                                      # 문(살 넷 + 가로대 · 자물쇠)
        g["Rail"].box(-0.6 + k * 0.4, -d / 2 + 0.05, 2.6, 0.08, 0.08, 4.9)
    for z in (0.6, 2.6, 4.6):
        g["Iron"].box(0, -d / 2 + 0.05, z, 1.6, 0.1, 0.12)
    g["Brass"].box(0.6, -d / 2 - 0.05, 2.6, 0.3, 0.12, 0.4)
    for x in (-1.2, 1.1):
        g["Wood"].box(x, 0.4, 0.6, 1.6, 1.1, 1.0)
        g["Brass"].box(x, 0.4, 1.12, 1.62, 1.12, 0.08)
    g["Iron"].box(0, 1.2, 5.6, 2.6, 0.1, 0.1)
    g[banner].box(0, 1.2, 4.4, 2.0, 0.06, 2.3)
    g["Brass"].box(0, 1.17, 3.9, 0.7, 0.04, 0.7)
    g["Brass"].box(0, -d / 2 - 0.12, h - 0.6, 2.0, 0.06, 0.45)
    C(0, 0, h / 2, w, d, h)


def magnifier_lamp(g):
    """감정 돋보기 등: 놋쇠 받침 · 꺾인 팔 둘 · 둥근 렌즈 테 + 유리 · 작은 불"""
    g["Brass"].cyl(0, 0, 0, 0.35, 0.3, 0.12, seg=10)
    g["Brass"].obox(0.15, 0, 0.6, 0.08, 0.08, 1.1, ry=0.3)
    g["Brass"].obox(0.55, 0, 1.2, 0.08, 0.08, 0.9, ry=1.2)
    S.ring(g, "Brass", 0.95, 0, 1.0, 0.28, 0.36, 0.06, n=14)
    g["Glass"].cyl(0.95, 0, 1.01, 0.28, 0.28, 0.03, seg=14)
    g["Glow"].box(0.95, 0, 1.25, 0.1, 0.1, 0.1)


def yard_bank(g):
    """금고 구역(울타리 대신 겉벽). 문은 은행 옆문뿐(별관 → 회랑 → 반대쪽 별관)"""
    unchecked(g, bank_walls)
    unchecked(g, strongroom)
    # 왼 별관: 대여 금고 열쇠 창구(NPC) · 뒤 벽 열쇠 판 · 벽 대여 금고 둘 · 손님 책상 둘 · 금고 함 두 줄
    place(g, -25.2, 7.5, clerk_desk)
    NPC(-27.0, 7.5, 0.0, 90.0)
    aL = _ang(BANK_OUT[1], BANK_OUT[2])                                     # 왼 바깥벽 방향(앞 → 뒤)
    for t_, fn in ((0.35, lambda q: key_board(q, 5.0)), (0.58, lambda q: wall_boxes(q, 8.0)), (0.82, lambda q: wall_boxes(q, 8.0))):
        a, b = BANK_OUT[1], BANK_OUT[2]
        px, py = a[0] + (b[0] - a[0]) * t_, a[1] + (b[1] - a[1]) * t_
        nx, ny = math.sin(aL), -math.cos(aL)                               # 안쪽(오른 법선)
        place(g, px + nx * 1.05, py + ny * 1.05, fn, rz=aL + math.pi)
    place(g, -16.0, 22.5, lambda q: deposit_cabinet(q, 9.0), rz=math.pi / 2)
    place(g, -25.0, 22.5, lambda q: deposit_cabinet(q, 11.0), rz=math.pi / 2)
    aT = _ang(BANK_OUT[2], BANK_OUT[3])
    for t_ in (0.3, 0.68):
        a, b = BANK_OUT[2], BANK_OUT[3]
        px, py = a[0] + (b[0] - a[0]) * t_, a[1] + (b[1] - a[1]) * t_
        nx, ny = math.sin(aT), -math.cos(aT)
        place(g, px + nx * 1.9, py + ny * 1.9, writing_desk, rz=aT)
    # 뒤 회랑: 금 운반 레일 + 금 수레 · 뒷벽 금화 무늬
    gold_cart_rails(g, -19.0, 19.0, 33.0)
    place(g, -6.0, 33.0, gold_cart)
    L_.transformed(g, Matrix.Translation((0, 37.5, 7.0)) @ Matrix.Rotation(math.pi / 2, 4, "X"),
                   lambda q: (q["Brass"].cyl(0, 0, 0, 2.4, 2.4, 0.15, seg=28), q["SignGold"].cyl(0, 0, 0.15, 1.9, 1.9, 0.08, seg=28)))
    coin_icon(g, 0, 37.2, 6.6, -1)
    # 오른 별관: 감정·환전 창구(NPC · 저울 · 돋보기 등 · 보석 쟁반) · 동전 세는 기계 · 길드 금고 우리 셋 · 벽 대여 금고
    place(g, 26.0, 7.5, lambda q: clerk_desk(q), rz=math.pi)
    NPC(27.8, 7.5, 0.0, -90.0)
    balance_scale(g, 25.9, 6.0, 3.5)
    L_.transformed(g, Matrix.Translation((26.2, 8.9, 3.5)) @ Matrix.Rotation(math.pi, 4, "Z"), magnifier_lamp)
    g["Leather"].box(25.6, 10.1, 3.55, 0.8, 0.9, 0.1)                        # 보석 쟁반
    for k, (dy, mat) in enumerate(((9.9, "SignRed"), (10.3, "GlowTeal"), (9.7, "SignPurple"))):
        sphere(g, mat, (25.4 + k * 0.25, dy, 3.68), 0.1, sub=1)
    place(g, 24.0, 22.0, coin_counter, rz=-math.pi / 2)
    aR = _ang(BANK_OUT[4], BANK_OUT[5])
    for t_, ban in ((0.23, "Banner"), (0.49, "SignBlue"), (0.75, "PaintGreen")):
        a, b = BANK_OUT[4], BANK_OUT[5]
        px, py = a[0] + (b[0] - a[0]) * t_, a[1] + (b[1] - a[1]) * t_
        nx, ny = math.sin(aR), -math.cos(aR)
        place(g, px + nx * 2.9, py + ny * 2.9, lambda q, b_=ban: guild_cage(q, b_), rz=aR)
    aRR = _ang(BANK_OUT[5], BANK_OUT[6])
    for t_ in (0.45, 0.68):
        a, b = BANK_OUT[5], BANK_OUT[6]
        px, py = a[0] + (b[0] - a[0]) * t_, a[1] + (b[1] - a[1]) * t_
        nx, ny = math.sin(aRR), -math.cos(aRR)
        place(g, px + nx * 1.05, py + ny * 1.05, lambda q: wall_boxes(q, 7.0), rz=aRR + math.pi)
    # 붉은 융단(한 바퀴 도는 길 안내, 겹치는 토막은 높이를 달리)
    for k, (a, b) in enumerate((((-21.2, -3.4), (-21.2, 16.6)), ((-20.5, 15.4), (-20.5, 30.6)), ((-21.7, 30.0), (21.7, 30.0)),
                                ((20.5, 30.6), (20.5, 15.4)), ((21.6, 16.6), (21.6, -3.4)))):
        z = 0.08 + 0.015 * (k % 2)
        L = math.dist(a, b)
        an = _ang(a, b)
        cx, cy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        g["Banner"].obox(cx, cy, z, L, 2.4, 0.04, rz=an)
        for sd in (-1, 1):
            g["Brass"].obox(cx - math.sin(an) * sd * 1.25, cy + math.cos(an) * sd * 1.25, z + 0.005, L, 0.12, 0.05, rz=an)
    # 등(천장에 매단)
    for x, y in ((-22.0, 2.0), (-21.0, 15.0), (-21.0, 27.0), (-32.0, 27.0), (-10.0, 33.0), (10.0, 33.0),
                 (22.0, 2.0), (21.0, 15.0), (21.0, 27.0), (33.0, 26.0)):
        lantern(g, x, y, H_V - 0.85, 8.6)


# ------------------------------------------------------------------ 여관 마구간 마당
def stable(g):
    """마구간(옛 뜰 그대로, 26×14, 칸 앞 -y): 나무 바닥 · 뒤·옆 벽 · 칸막이 셋 · 경사 함석 지붕 + 눈 · 칸 뒤 건초 · 여물통 · 안장 걸이 · 건초 더미 · 등 둘"""
    W, D = 26.0, 14.0
    g["Wood"].box(0, 0, 0.1, W, D, 0.2)
    C(0, 0, 0.1, W, D, 0.2)
    g["Timber"].box(0, 6.7, 4.6, 24.0, 0.6, 8.8)
    for x in (-12.0, 12.0):
        g["Timber"].box(x, 3.0, 4.6, 0.6, 8.0, 8.8)
        C(x, 3.0, 4.6, 0.6, 8.0, 8.8)
    C(0, 6.7, 4.6, 24.0, 0.6, 8.8)
    for x in (-6.0, 0.0, 6.0):
        g["Wood"].box(x, 3.7, 2.4, 0.4, 5.4, 4.4)
        g["Timber"].box(x, 1.0, 3.5, 0.5, 0.5, 6.6)
        C(x, 3.7, 2.4, 0.4, 5.4, 4.4)
    g["RoofMetal"].obox(0, 2.6, 9.6, 25.6, 9.6, 0.3, rx=0.18)
    g["SnowCap"].obox(0, 2.7, 9.95, 25.0, 9.0, 0.3, rx=0.18)
    for x in (-12.0, 12.0):
        g["Timber"].box(x, -1.4, 4.4, 0.5, 0.5, 8.6)
    for cx in (-9.0, -3.0, 3.0, 9.0):
        g["SignGold"].obox(cx, 6.0, 0.6, 3.6, 0.8, 0.8, rz=0.05)
        g["Timber"].box(cx, 6.2, 4.5, 3.0, 0.6, 1.4)
        g["SignGold"].box(cx, 6.1, 5.0, 2.8, 0.4, 0.5)
        C(cx, 6.0, 0.6, 3.6, 0.8, 0.8)
    g["Wood"].box(-8.0, -4.0, 1.0, 6.0, 1.2, 1.4)
    g["Glass"].box(-8.0, -4.0, 1.62, 5.6, 0.9, 0.08)
    C(-8.0, -4.0, 0.9, 6.0, 1.2, 1.4)
    g["Timber"].box(-3.2, -4.6, 1.8, 1.4, 0.3, 0.3)
    for x in (-3.8, -2.6):
        g["Timber"].box(x, -4.6, 1.0, 0.2, 0.6, 1.6)
    g["Leather"].obox(-3.2, -4.6, 2.15, 1.2, 1.0, 0.45, rx=0.1)
    C(-3.2, -4.6, 1.2, 1.4, 0.8, 2.0)
    for k, (x, y, z) in enumerate(((4.5, -4.5, 0.2), (6.0, -4.6, 0.2), (5.2, -4.5, 1.2))):
        g["SignGold"].box(x, y, z + 0.5, 1.4, 1.0, 1.0)
        g["Timber"].box(x, y, z + 0.5, 1.45, 1.05, 0.12)
    C(5.2, -4.5, 1.2, 3.0, 1.2, 2.0)
    for x in (-6.0, 6.0):
        lantern(g, x, 2.2, 9.2, 6.4)
    # 뒷벽 바깥(뒤 큰 문에서 처음 보이는 면): 덧댄 널 · 작은 창 둘 · 가운데 건초 다락문(X 버팀 · 삐져나온 건초) · 편자 판 · 처마 밑 눈
    for k in range(17):
        x = -11.5 + k * 1.44
        if abs(abs(x) - 7.0) > 1.0 and abs(x) > 1.8:
            g["Timber"].box(x, 7.06, 4.6, 0.16, 0.14, 8.6)
    for sx in (-1, 1):
        g["WinGlass"].box(sx * 7.0, 7.02, 5.6, 1.4, 0.06, 1.1)
        for z in (5.0, 6.2):
            g["Timber"].box(sx * 7.0, 7.1, z, 1.7, 0.14, 0.16)
        for x in (sx * 7.0 - 0.78, sx * 7.0 + 0.78):
            g["Timber"].box(x, 7.1, 5.6, 0.16, 0.14, 1.36)
        g["Timber"].box(sx * 7.0, 7.1, 5.6, 0.08, 0.1, 1.1)
        snow(g, sx * 7.0, 7.25, 4.95, 1.6, 0.3, t=0.08)
    g["Wood"].box(0, 7.05, 6.4, 2.8, 0.12, 2.2)
    for s_ in (-1, 1):
        g["Timber"].obox(0, 7.13, 6.4, 3.2, 0.1, 0.14, ry=s_ * 0.66)
        g["Timber"].box(s_ * 1.45, 7.13, 6.4, 0.16, 0.12, 2.4)
    for z in (5.25, 7.55):
        g["Timber"].box(0, 7.13, z, 3.06, 0.12, 0.16)
    g["SignGold"].obox(0.3, 7.2, 7.3, 1.2, 0.3, 0.25, rz=0.2)
    g["Iron"].box(0, 7.35, 8.3, 0.1, 0.5, 0.1)
    horseshoe_icon(g, 0, 7.15, 3.3, face=1)


def paddock(g, x0, x1, y0, y1, gate):
    """말 울타리(나무 기둥 3.2 마다 · 가로대 둘 · 기둥 머리 눈). gate = (x 가운데, 폭) — 앞(y0) 쪽 열린 곳"""
    gx, gw = gate

    def run(a, b):
        L = math.dist(a, b)
        an = _ang(a, b)
        cx, cy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        for z in (1.4, 2.7):
            g["Timber"].obox(cx, cy, z, L, 0.18, 0.28, rz=an)
            g["SnowCap"].obox(cx, cy, z + 0.17, L, 0.2, 0.06, rz=an)
        n = max(1, int(L / 3.2))
        for k in range(n + 1):
            px, py = a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n
            g["Timber"].box(px, py, 1.6, 0.32, 0.32, 3.2)
            snow(g, px, py, 3.2, 0.3, 0.3, t=0.1)
        C(cx, cy, 1.5, L, 0.4, 3.0, an)
    run((x0, y0), (gx - gw / 2, y0))
    run((gx + gw / 2, y0), (x1, y0))
    run((x1, y0), (x1, y1))
    run((x1, y1), (x0, y1))
    run((x0, y1), (x0, y0))


def horse_jump(g):
    for x in (-1.8, 1.8):
        g["Timber"].box(x, 0, 1.1, 0.3, 0.3, 2.2)
        g["Timber"].box(x, 0, 0.1, 0.9, 0.9, 0.2)
    for k, z in enumerate((0.8, 1.6)):
        g["Paint" if k else "SignRed"].hcyl(0, 0, z, 0.12, 3.8, axis="x", seg=8)
    C(0, 0, 1.0, 3.9, 0.9, 2.0)


def water_trough(g, length=4.0):
    g["Wood"].box(0, 0, 0.6, length, 1.2, 1.2)
    for x in (-length / 2 + 0.2, length / 2 - 0.2):
        g["Iron"].box(x, 0, 0.63, 0.12, 1.25, 1.25)
    g["Glass"].box(0, 0, 1.15, length - 0.3, 0.9, 0.06)
    C(0, 0, 0.6, length, 1.2, 1.2)


def hay_rack(g):
    """건초 걸이(기댄 나무 살 통 + 건초)"""
    g["Timber"].box(0, 0, 1.6, 3.0, 0.2, 0.2)
    g["Timber"].box(0, 0, 0.6, 3.0, 0.9, 0.2)
    for k in range(7):
        g["Timber"].obox(-1.35 + k * 0.45, -0.2, 1.1, 0.08, 0.08, 1.1, rx=0.4)
    g["SignGold"].box(0, 0.05, 1.3, 2.8, 0.7, 0.7)
    for x in (-1.4, 1.4):
        g["Timber"].box(x, 0.2, 1.0, 0.2, 0.2, 2.0)
    C(0, 0, 1.0, 3.0, 1.0, 2.0)


def hay_bales(g):
    for k, (x, y, z, rz) in enumerate(((0, 0, 0, 0.0), (1.6, 0.1, 0, 0.05), (0.8, 0.05, 1.0, -0.05), (0.3, 1.25, 0, 0.1))):
        g["SignGold"].obox(x, y, z + 0.5, 1.5, 1.1, 1.0, rz=rz)
        for s in (-0.35, 0.35):
            g["Timber"].obox(x + s * math.cos(rz), y + s * math.sin(rz), z + 0.5, 0.06, 1.14, 1.04, rz=rz)
    snow(g, 0.8, 0.05, 2.0, 1.3, 0.9, t=0.12)
    C(0.8, 0.6, 1.0, 3.2, 2.4, 2.0)


def coach(g):
    """역마차(긴 쪽 y, 앞 -y): 녹색 칠 몸통(놋쇠 띠 · 창 · 문) · 지붕 난간 + 짐(가죽 가방·궤짝) + 눈 · 마부석·발판 · 큰 뒷바퀴 · 작은 앞바퀴 · 굴대·판스프링 · 앞 등 둘 · 끌채"""
    g["PaintGreen"].box(0, 0.4, 3.4, 3.0, 4.2, 2.8)
    g["PaintGreen"].box(0, 0.4, 1.9, 2.6, 3.6, 0.4)
    for z in (2.15, 4.75):
        g["Brass"].box(0, 0.4, z, 3.08, 4.28, 0.12)
    for sx in (-1, 1):
        for y in (-0.6, 1.4):
            g["WinGlass"].box(sx * 1.52, y, 3.9, 0.06, 1.1, 1.0)
            g["Brass"].box(sx * 1.54, y, 3.9, 0.04, 1.25, 1.15)
        g["Timber"].box(sx * 1.53, 0.4, 3.0, 0.04, 0.12, 1.6)
        g["Brass"].box(sx * 1.56, 0.85, 3.1, 0.06, 0.12, 0.25)
    g["Timber"].box(0, 0.4, 4.95, 3.3, 4.6, 0.25)
    for sx in (-1, 1):
        g["Brass"].box(sx * 1.55, 0.4, 5.35, 0.06, 4.4, 0.06)
        for y in (-1.6, 0.4, 2.4):
            g["Brass"].box(sx * 1.55, y, 5.2, 0.06, 0.06, 0.4)
    g["Leather"].box(-0.5, 0.0, 5.45, 1.4, 1.6, 0.8)
    g["Wood"].box(0.6, 1.2, 5.4, 1.2, 1.4, 0.7)
    g["Brass"].box(0.6, 1.2, 5.78, 1.24, 0.1, 0.06)
    snow(g, 0.0, 0.4, 5.85, 2.8, 4.0, t=0.15)
    g["Timber"].box(0, -2.4, 4.2, 2.8, 1.2, 0.25)
    g["Leather"].box(0, -2.3, 4.45, 2.4, 0.9, 0.25)
    g["Timber"].obox(0, -3.0, 3.3, 2.6, 0.2, 1.6, rx=-0.4)
    g["Timber"].box(0, -1.3, 2.6, 0.5, 2.2, 0.3)
    for sx in (-1, 1):
        wheel(g, sx * 1.75, 1.8, 1.4, 1.4, axis="x", n=12)
        wheel(g, sx * 1.6, -1.6, 1.0, 1.0, axis="x", n=10)
        g["Iron"].obox(sx * 1.2, 1.8, 1.75, 0.15, 1.6, 0.12, rx=0.05)
        g["Iron"].obox(sx * 1.1, -1.6, 1.4, 0.15, 1.4, 0.12)
        g["Brass"].cyl(sx * 1.45, -2.9, 4.4, 0.18, 0.14, 0.25, seg=8)
        g["Glass"].box(sx * 1.45, -2.9, 4.9, 0.5, 0.5, 0.7)
        g["Glow"].box(sx * 1.45, -2.9, 4.85, 0.14, 0.14, 0.3)
        g["Brass"].box(sx * 1.45, -2.9, 5.3, 0.6, 0.6, 0.12)
        g["Timber"].obox(sx * 0.6, -4.6, 0.95, 0.14, 4.0, 0.14, rx=0.12)
    g["Iron"].hcyl(0, 1.8, 1.4, 0.1, 3.6, axis="x", seg=8)
    g["Iron"].hcyl(0, -1.6, 1.0, 0.1, 3.3, axis="x", seg=8)
    g["Timber"].box(0, -6.4, 0.85, 1.4, 0.14, 0.14)
    C(0, 0.4, 3.0, 3.6, 5.4, 6.0)
    C(0, -2.4, 2.2, 3.4, 1.6, 4.4)


def well(g):
    """우물: 돌 둘레 · 나무 기둥 둘 · 지붕(맞배) + 눈 · 도르래 굴대 · 손잡이 · 밧줄 · 두레박"""
    g["StoneTrim"].cyl(0, 0, 0, 1.6, 1.55, 1.3, seg=16)
    g["Char"].cyl(0, 0, 1.3, 1.25, 1.25, 0.02, seg=16)
    S.ring(g, "StoneTrim", 0, 0, 1.3, 1.25, 1.65, 0.18, n=16)
    snow(g, 0, 1.45, 1.48, 1.0, 0.3, t=0.08)
    for x in (-1.5, 1.5):
        g["Timber"].box(x, 0, 2.5, 0.3, 0.3, 5.0)
    g["Timber"].hcyl(0, 0, 3.8, 0.2, 3.3, axis="x", seg=10)
    g["Iron"].obox(2.0, 0, 3.8, 0.8, 0.12, 0.12)
    g["Iron"].box(2.35, 0, 3.5, 0.12, 0.12, 0.6)
    g["Wood"].hcyl(2.35, 0, 3.2, 0.1, 0.4, axis="y", seg=8)
    g["Canvas"].cyl(0.0, 0, 2.2, 0.05, 0.05, 1.6, seg=6)
    g["Wood"].cyl(0.0, 0, 1.7, 0.35, 0.4, 0.55, seg=10)
    g["Iron"].cyl(0.0, 0, 1.95, 0.42, 0.42, 0.08, seg=10)
    for s in (-1, 1):
        g["RoofMetal"].obox(0, s * 0.85, 5.35, 3.6, 2.0, 0.15, rx=-s * 0.5)
        g["SnowCap"].obox(0, s * 0.82, 5.5, 3.3, 1.8, 0.15, rx=-s * 0.5)
    C(0, 0, 0.65, 3.2, 3.2, 1.3)


def beer_table(g, length=5.0):
    """맥주 뜰 긴 탁자(긴 쪽 y) + 양쪽 긴 걸상 + 잔 · 초 등"""
    g["Wood"].box(0, 0, 2.6, 1.6, length, 0.2)
    for y in (-length / 2 + 0.5, length / 2 - 0.5):
        g["Timber"].box(0, y, 1.3, 1.2, 0.2, 2.6)
    for s in (-1, 1):
        g["Wood"].box(s * 1.8, 0, 1.5, 0.8, length, 0.2)
        for y in (-length / 2 + 0.5, length / 2 - 0.5):
            g["Timber"].box(s * 1.8, y, 0.7, 0.2, 0.2, 1.4)
        snow(g, s * 1.8, 0, 1.6, 0.6, length - 0.2, t=0.06)
    for k, y in enumerate((-1.6, -0.4, 1.2)):
        g["Glass"].cyl(0.35 * (1 if k % 2 else -1), y, 2.7, 0.18, 0.2, 0.5, seg=8)
        g["SignGold"].cyl(0.35 * (1 if k % 2 else -1), y, 2.72, 0.16, 0.16, 0.35, seg=8)
    g["Brass"].cyl(0, 0.4, 2.7, 0.2, 0.2, 0.08, seg=8)
    g["Glass"].box(0, 0.4, 3.0, 0.3, 0.3, 0.5)
    g["Glow"].box(0, 0.4, 2.95, 0.1, 0.1, 0.2)
    C(0, 0, 1.35, 1.6, length, 2.7)
    for s in (-1, 1):
        C(s * 1.8, 0, 0.8, 0.8, length, 1.6)


def yard_inn(g):
    K = "Yard_Inn"
    fence(g, K, gates=((2.5, 42.47, 8.5, True), (-39.55, 21.0, 7.5, False), (36.4, 21.0, 7.5, False)),
          icon=lambda q, x, y, z, f: horseshoe_icon(q, x, y, z - 0.0, face=f))
    path(g, (2.5, 41.7), (2.5, 23.0), 5.0, lv=0)
    path(g, (-39.0, 21.0), (35.8, 21.0), 4.0, lv=1)
    path(g, (-8.0, 15.2), (-8.0, 19.0), 4.0, lv=2)                          # 뒷문(x -11..-5) → 일 길
    place(g, -14.0, 31.0, stable)
    NPC(-5.0, 26.6, 0.0, 0.0)                                               # 마구간지기(옛 뜰 자리)
    paddock(g, 7.0, 26.0, 25.0, 37.5, (14.2, 4.6))
    place(g, 22.4, 35.6, water_trough)
    place(g, 9.6, 35.8, hay_rack)
    place(g, 16.5, 31.4, horse_jump)
    place(g, 29.6, 29.6, hay_bales)
    place(g, -33.0, 29.2, coach)
    for x in (-0.3, 5.3):
        lamp_post(g, x, 23.9)
    # 오른 날개 우물 · 왼 날개 맥주 뜰
    place(g, 28.4, 12.0, well)
    place(g, -28.0, 10.5, beer_table)
    place(g, -30.6, 16.0, beer_table)
    lamp_post(g, -24.0, 5.6)
    lamp_post(g, -34.6, 17.4)
    fir(g, -42.0, 31.0, h=7.0)
    fir(g, 39.0, 30.6, h=7.0)


# ------------------------------------------------------------------ 약초밭
def greenhouse(g, w=12.0, d=9.0, he=4.6, hr=7.4, door=5.0):
    """유리 온실(가운데 (0, 0), 앞뒤 -y·+y 에 문 door 폭): 돌 밑단 · 쇠 기둥·서까래 · 반투명 유리 벽·지붕(맑은 창유리는 Studio 에서 틀만 보였다) · 지붕 환기창(쇠 손잡이로 들림) ·
    서까래·밑단 눈 · 안 양옆 선반과 화분 · 작은 쇠 난로 + 굴뚝(김) · 문짝(연 채)"""
    t = 0.5
    for s in (-1, 1):                                                       # 옆 밑단(긴 쪽)
        g["StoneTrim"].box(s * (w / 2 - t / 2), 0, 0.4, t, d, 0.8)
        C(s * (w / 2 - t / 2), 0, he / 2, t, d, he)
    for yy in (-d / 2 + t / 2, d / 2 - t / 2):                              # 앞뒤 밑단(문 비움)
        for s in (-1, 1):
            a, b = s * door / 2, s * w / 2
            g["StoneTrim"].box((a + b) / 2, yy, 0.4, abs(b - a), t, 0.8)
            C((a + b) / 2, yy, he / 2, abs(b - a), t, he)
    # 기둥(2 마다) · 처마 보 · 앞뒤 박공
    for s in (-1, 1):
        for k in range(int(d / 2) + 1):
            y = -d / 2 + 0.2 + k * (d - 0.4) / int(d / 2)
            g["Iron"].box(s * (w / 2 - 0.25), y, (0.8 + he) / 2, 0.14, 0.14, he - 0.8)
        g["Iron"].box(s * (w / 2 - 0.25), 0, he, 0.18, d, 0.18)
        g["Glass"].box(s * (w / 2 - 0.25), 0, (0.8 + he) / 2, 0.05, d - 0.2, he - 0.8)
    for yy in (-d / 2 + 0.25, d / 2 - 0.25):
        for s in (-1, 1):
            a, b = s * door / 2, s * (w / 2 - 0.25)
            g["Glass"].box((a + b) / 2, yy, (0.8 + he) / 2, abs(b - a), 0.05, he - 0.8)
            g["Iron"].box(s * door / 2, yy, he / 2 + 0.2, 0.16, 0.16, he - 0.4)
        g["Iron"].box(0, yy, he - 0.1, door + 0.2, 0.16, 0.16)
        v = [(-w / 2 + 0.25, yy, he), (w / 2 - 0.25, yy, he), (0, yy, hr)]
        g["Glass"].add_mesh([(p[0], p[1] - 0.025, p[2]) for p in v] + [(p[0], p[1] + 0.025, p[2]) for p in v],
                               [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
    half = w / 2 - 0.25
    sl = math.atan2(hr - he, half)
    Ls = math.hypot(half, hr - he)
    for s in (-1, 1):
        cx, cz = s * half / 2, (he + hr) / 2
        g["Glass"].obox(cx, 0, cz, Ls, d - 0.2, 0.05, ry=s * sl)
        for k in range(int(d / 1.5) + 1):
            y = -d / 2 + 0.25 + k * (d - 0.5) / int(d / 1.5)
            g["Iron"].obox(cx, y, cz + 0.06, Ls, 0.12, 0.12, ry=s * sl)
            g["SnowCap"].obox(cx, y, cz + 0.16, Ls - 0.2, 0.2, 0.06, ry=s * sl)
        g["SnowCap"].obox(s * (half - 0.9), 0, he + 0.55, 1.6, d - 0.3, 0.1, ry=s * sl)   # 처마 쪽 쌓인 눈
    g["Iron"].box(0, 0, hr, 0.2, d, 0.2)
    # 지붕 환기창(오른 판 가운데, 들린 유리 + 쇠 손잡이 막대)
    g["Iron"].obox(half * 0.45, 0.0, he + (hr - he) * 0.55 + 0.35, 2.0, 1.6, 0.08, ry=sl + 0.35)
    g["Glass"].obox(half * 0.45, 0.0, he + (hr - he) * 0.55 + 0.42, 1.8, 1.4, 0.04, ry=sl + 0.35)
    g["Iron"].box(half * 0.75, 0.6, (he + hr) / 2 - 1.6, 0.06, 0.06, 3.2)
    # 안: 양옆 선반(화분 줄) · 난로 · 굴뚝
    for s in (-1, 1):
        x = s * (w / 2 - 1.25)
        g["Wood"].box(x, 0, 2.2, 1.4, d - 2.6, 0.15)
        for y in (-d / 2 + 1.6, d / 2 - 1.6):
            g["Timber"].box(x, y, 1.1, 1.2, 0.15, 2.2)
        for k in range(5):
            y = -d / 2 + 1.9 + k * (d - 3.8) / 4
            g["Brick"].cyl(x, y, 2.28, 0.32, 0.38, 0.45, seg=8)
            sphere(g, ("Felt", "PaintGreen", "Felt")[k % 3], (x, y, 2.95), 0.4, sub=1)
        C(x, 0, 1.15, 1.4, d - 2.6, 2.3)
    sx_, sy_ = -w / 2 + 1.0, d / 2 - 1.2
    g["Iron"].cyl(sx_, sy_, 0, 0.45, 0.45, 1.3, seg=10)
    g["Core"].box(sx_ + 0.46, sy_, 0.6, 0.04, 0.4, 0.3)
    g["Iron"].cyl(sx_, sy_, 1.3, 0.12, 0.12, hr - 1.3 + 1.2, seg=8)
    S.vent(g, sx_, sy_, hr + 1.6)
    C(sx_, sy_, 0.65, 1.0, 1.0, 1.3)
    # 문짝(앞뒤 하나씩 바깥으로 연 채)
    def leaf(q):
        for y in (-1.15, 1.15):
            q["Iron"].box(0, y, 2.15, 0.1, 0.1, 4.1)
        for z in (0.15, 2.2, 4.15):
            q["Iron"].box(0, 0, z, 0.1, 2.4, 0.1)
        q["Glass"].box(0, 0, 2.15, 0.04, 2.2, 3.9)
        q["Brass"].box(0.08, 0.9, 2.0, 0.08, 0.12, 0.3)
    for yy, s in ((-d / 2, -1), (d / 2, 1)):
        place(g, door / 2 + 0.3, yy + s * 1.1, leaf, rz=0.3 * s)


def raised_bed(g, seed, length=7.0):
    """돋운 밭(긴 쪽 y): 나무 틀 · 흙 · 풀 덩이 · 꽃(눈 덮인 겨울 약초)"""
    import random
    rnd = random.Random(seed)
    g["Timber"].box(0, 0, 0.4, 3.0, length, 0.8)
    g["Char"].box(0, 0, 0.82, 2.7, length - 0.3, 0.05)
    n = int(length / 1.35)
    for k in range(n):
        y = -length / 2 + 0.7 + k * (length - 1.4) / max(1, n - 1)
        sphere(g, ("Felt", "PaintGreen", "Felt")[(seed + k) % 3], (rnd.uniform(-0.4, 0.4), y, 1.15), rnd.uniform(0.45, 0.6), sub=1)
        if (seed + k) % 2:
            sphere(g, ("SignPurple", "SignRed", "SignGold")[seed % 3], (rnd.uniform(-0.3, 0.3), y, 1.7), 0.2, sub=1)
        else:
            sphere(g, "SnowCap", (rnd.uniform(-0.2, 0.2), y + 0.2, 1.55), 0.25, sub=1)
    snow(g, 1.42, 0, 0.8, 0.16, length - 0.1, t=0.08)
    snow(g, -1.42, 0, 0.8, 0.16, length - 0.1, t=0.08)
    C(0, 0, 0.5, 3.0, length, 1.0)


def beehive(g):
    """벌통: 다리 받침 · 상자 셋(테) · 맞배 작은 지붕 + 눈 · 드나드는 틈"""
    for sx in (-0.5, 0.5):
        for sy in (-0.5, 0.5):
            g["Timber"].box(sx, sy, 0.3, 0.15, 0.15, 0.6)
    for k in range(3):
        z = 0.6 + k * 0.55
        g["Wood"].box(0, 0, z + 0.25, 1.3, 1.3, 0.5)
        g["Timber"].box(0, 0, z + 0.5, 1.36, 1.36, 0.06)
    g["Char"].box(0, -0.66, 0.75, 0.6, 0.04, 0.08)
    for s in (-1, 1):
        g["RoofMetal"].obox(s * 0.4, 0, 2.5, 1.0, 1.6, 0.08, ry=s * 0.55)
        g["SnowCap"].obox(s * 0.38, 0, 2.6, 0.9, 1.5, 0.1, ry=s * 0.55)
    C(0, 0, 1.25, 1.4, 1.4, 2.5)


def drying_rack(g):
    """말리는 시렁(긴 쪽 x): 기둥 넷 · 가로대 둘 · 매단 약초 다발"""
    for x in (-1.9, 1.9):
        for y in (-0.5, 0.5):
            g["Timber"].box(x, y, 1.7, 0.2, 0.2, 3.4)
    for y in (-0.5, 0.5):
        g["Timber"].box(0, y, 3.3, 4.0, 0.15, 0.15)
        snow(g, 0, y, 3.38, 3.9, 0.18, t=0.06)
    for k in range(6):
        herb_bundle(g, -1.5 + k * 0.6, 0.5 if k % 2 else -0.5, 3.2, mat=("Felt", "PaintGreen", "SignPurple")[k % 3])
    C(0, 0, 1.7, 4.0, 1.2, 3.4)


def hand_pump(g):
    """손 펌프 + 물받이: 돌 받침 · 무쇠 몸통 · 주둥이 · 들린 손잡이(놋쇠 끝) · 물통"""
    g["StoneTrim"].box(0, 0, 0.3, 1.2, 1.2, 0.6)
    g["Iron"].cyl(0, 0, 0.6, 0.28, 0.24, 2.2, seg=10)
    g["Iron"].cyl(0, 0, 2.8, 0.3, 0.2, 0.3, seg=10)
    g["Iron"].obox(0, -0.45, 2.15, 0.16, 0.7, 0.16, rx=0.3)
    g["Iron"].obox(0, 0.55, 3.05, 0.1, 1.2, 0.1, rx=-0.45)
    sphere(g, "Brass", (0, 1.05, 3.35), 0.12, sub=1)
    g["Iron"].box(0, 0.1, 2.95, 0.12, 0.12, 0.4)
    g["StoneTrim"].box(0, -1.5, 0.45, 2.6, 1.1, 0.9)
    g["Glass"].box(0, -1.5, 0.86, 2.3, 0.8, 0.06)
    C(0, 0, 1.4, 1.2, 1.2, 2.8)
    C(0, -1.5, 0.45, 2.6, 1.1, 0.9)


def compost_bin(g):
    for s in (-1, 1):
        g["Timber"].box(s * 1.15, 0, 0.7, 0.15, 2.4, 1.4)
        g["Timber"].box(0, s * 1.15, 0.7, 2.4, 0.15, 1.4)
        for k in range(3):
            g["Wood"].box(s * 1.2, 0, 0.25 + k * 0.45, 0.06, 2.3, 0.3)
    frustum(g, "Char", 0, 0, 0, 2.2, 2.2, 1.2, 1.2, 1.2)
    sphere(g, "SnowCap", (0, 0, 1.0), 0.6, sub=1)
    C(0, 0, 0.7, 2.4, 2.4, 1.4)


def wheelbarrow(g):
    """외바퀴 수레(앞 +y 바퀴, 손잡이 -y)"""
    frustum(g, "Iron", 0, 0.1, 0.8, 1.0, 1.4, 1.4, 2.0, 0.6)
    g["Char"].box(0, 0.1, 1.38, 1.2, 1.8, 0.04)
    wheel(g, 0, 1.4, 0.55, 0.55, axis="x", n=6)
    for s in (-1, 1):
        g["Timber"].obox(s * 0.55, -0.6, 0.95, 0.1, 2.6, 0.1, rx=-0.15)
        g["Timber"].box(s * 0.5, -0.5, 0.4, 0.1, 0.1, 0.8)
    C(0, 0.0, 0.7, 1.6, 3.0, 1.4)


def potting_bench(g):
    g["Wood"].box(0, 0, 2.6, 3.2, 1.2, 0.15)
    g["Wood"].box(0, 0, 0.9, 3.0, 1.0, 0.1)
    for sx in (-1.45, 1.45):
        for sy in (-0.45, 0.45):
            g["Timber"].box(sx, sy, 1.3, 0.15, 0.15, 2.6)
    for k in range(4):
        g["Brick"].cyl(-1.1 + k * 0.7, 0.1, 2.68, 0.25, 0.3, 0.38, seg=8)
        if k % 2:
            sphere(g, "Felt", (-1.1 + k * 0.7, 0.1, 3.2), 0.3, sub=1)
    for k in range(3):
        g["Brick"].cyl(-0.8 + k * 0.6, 0.0, 1.0, 0.22, 0.26, 0.3, seg=8)
    g["Canvas"].box(1.0, 0.0, 1.2, 0.8, 0.6, 0.5)
    C(0, 0, 1.35, 3.2, 1.2, 2.7)


def yard_potion(g):
    K = "Yard_Potion"
    fence(g, K, gates=((0.0, 44.47, 7.5, True), (-21.44, 20.0, 7.0, False), (24.04, 20.0, 7.0, False)),
          icon=lambda q, x, y, z, f: flask_icon(q, x, y, z - 0.1, face=f))
    path(g, (-20.9, 20.0), (23.5, 20.0), 3.5, lv=1)
    path(g, (0.0, 21.8), (0.0, 31.6), 3.5, lv=0)
    path(g, (0.0, 40.4), (0.0, 43.7), 3.5, lv=0)
    place(g, 0.0, 36.0, greenhouse)
    g["Stone"].box(0, 36.0, 0.06, 4.8, 8.6, 0.12)                           # 온실 안 길
    for i, x in enumerate((-9.0, -4.0, 4.0, 9.0)):
        place(g, x, 27.0, lambda q, s_=5 + i: raised_bed(q, s_))
    for x, y in ((-15.4, 25.6), (-16.4, 30.0), (-17.4, 34.4)):
        place(g, x, y, beehive)
    place(g, -13.4, 38.6, drying_rack)
    place(g, 15.0, 25.6, hand_pump)
    place(g, 18.6, 33.0, compost_bin)
    place(g, 14.4, 30.4, wheelbarrow, rz=0.5)
    place(g, 13.6, 37.6, potting_bench)
    NPC(13.6, 36.2, 0.0, 180.0)                                             # 약초 키우는 이
    for x in (-12.0, 12.0):
        lamp_post(g, x, 22.6)
    fir(g, -19.6, 40.0, h=7.0)
    fir(g, 20.6, 39.4, h=7.0)


# ------------------------------------------------------------------ 회복 정원
def respawn_plaza(g):
    """부활 자리(둥근 판 r 4.6): 밝은 돌 판 · 대리석 테 · 놋쇠 테 · 가운데 붉은 심장"""
    g["StoneTrim"].cyl(0, 0, 0, 4.6, 4.6, 0.2, seg=32)
    S.ring(g, "Marble", 0, 0, 0.2, 3.6, 4.2, 0.03, n=32)
    S.ring(g, "Brass", 0, 0, 0.2, 2.6, 2.85, 0.04, n=32)
    flat_heart(g, 0, 0, 0.2, s=1.3)


def gazebo(g, r=6.0):
    """팔각 정자(가운데 (0, 0), r 6 — 앞뒤 칸이 R6 폭 4 보다 넓게): 돌 바닥 두 단 · 쇠 기둥 여덟(놋쇠 머리) · 앞뒤(±y)는 비운 낮은 난간 · 테 보 · 구리 팔각 돔 + 놋쇠 꼭지 + 눈 · 둥근 걸상 둘"""
    g["StoneTrim"].cyl(0, 0, 0, r + 0.9, r + 0.9, 0.25, seg=8)
    g["StoneTrim"].cyl(0, 0, 0.25, r + 0.4, r + 0.4, 0.25, seg=8)
    C(0, 0, 0.25, 2 * r + 0.8, 2 * r + 0.8, 0.5)
    pts = [(r * math.cos(math.radians(22.5 + 45 * k)), r * math.sin(math.radians(22.5 + 45 * k))) for k in range(8)]
    for x, y in pts:
        g["Iron"].cyl(x, y, 0.5, 0.17, 0.15, 4.4, seg=8)
        g["Brass"].cyl(x, y, 4.75, 0.24, 0.24, 0.2, seg=8)
        C(x, y, 2.7, 0.4, 0.4, 4.4)
    for k in range(8):
        a, b = pts[k], pts[(k + 1) % 8]
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        an = _ang(a, b)
        L = math.dist(a, b)
        g["Iron"].obox(mx, my, 4.75, L, 0.18, 0.3, rz=an)
        if abs(mx) < 0.5 * r and abs(my) > 0.5 * r:                         # 앞뒤 칸은 비운다
            continue
        g["Rail"].obox(mx, my, 1.6, L, 0.1, 0.1, rz=an)
        g["Rail"].obox(mx, my, 2.35, L, 0.12, 0.12, rz=an)
        for j in range(5):
            t_ = (j + 0.5) / 5
            g["Rail"].box(a[0] + (b[0] - a[0]) * t_, a[1] + (b[1] - a[1]) * t_, 1.45, 0.07, 0.07, 1.9)
        C(mx, my, 1.45, L, 0.3, 1.9, an)
        # 안쪽 걸상(난간 칸 앞)
        ix, iy = mx * 0.8, my * 0.8
        g["Wood"].obox(ix, iy, 1.55, L * 0.9, 0.7, 0.12, rz=an)
        g["Iron"].box(ix, iy, 1.0, 0.12, 0.12, 1.0)
    for k in range(6):                                                      # 팔각 돔(구리)
        a0, a1 = math.pi / 2 * k / 6, math.pi / 2 * (k + 1) / 6
        rr = r + 0.7
        g["Copper"].cyl(0, 0, 4.95 + 3.0 * math.sin(a0), rr * math.cos(a0), max(0.05, rr * math.cos(a1)), 3.0 * (math.sin(a1) - math.sin(a0)), seg=8)
    for k in range(3, 6):                                                   # 꼭대기 쪽 눈
        a0, a1 = math.pi / 2 * k / 6, math.pi / 2 * (k + 1) / 6
        rr = r + 0.75
        g["SnowCap"].cyl(0, 0, 4.98 + 3.0 * math.sin(a0), rr * math.cos(a0) * 0.98, max(0.05, rr * math.cos(a1) * 0.98), 3.0 * (math.sin(a1) - math.sin(a0)), seg=8)
    g["Brass"].cyl(0, 0, 7.95, 0.35, 0.12, 0.9, seg=8)
    sphere(g, "Brass", (0, 0, 9.0), 0.25, sub=1)
    lantern(g, 0, 0, 7.2, 5.9)


def frozen_pond(g, r=4.8):
    """언 연못: 돌 둘레(조각 열여섯) · 얼음 판 · 눈 얹은 가장자리 · 얼음 위 금"""
    g["Glass"].cyl(0, 0, 0, r, r, 0.12, seg=24)
    for k in range(16):
        a = k * math.pi / 8
        g["StoneTrim"].obox((r + 0.35) * math.cos(a), (r + 0.35) * math.sin(a), 0.3, 1.0, 2.0, 0.6, rz=a)
        if k % 3 == 0:
            g["SnowCap"].obox((r + 0.35) * math.cos(a), (r + 0.35) * math.sin(a), 0.65, 0.8, 1.6, 0.12, rz=a)
    for k, (a, L) in enumerate(((0.3, 2.5), (1.9, 1.8), (3.6, 2.2), (5.0, 1.5))):
        g["SnowCap"].obox(1.2 * math.cos(a), 1.2 * math.sin(a), 0.13, L, 0.06, 0.01, rz=a + 0.6)
    for k in range(16):
        a = k * math.pi / 8
        C((r + 0.35) * math.cos(a), (r + 0.35) * math.sin(a), 0.3, 1.0, 2.0, 0.6, a)


def sundial(g):
    """해시계: 돌 받침(뿔대 · 기둥) · 대리석 판 · 놋쇠 판(시각 눈금 열둘) · 놋쇠 세모 바늘"""
    frustum(g, "StoneTrim", 0, 0, 0, 1.8, 1.8, 1.1, 1.1, 0.5)
    g["StoneTrim"].cyl(0, 0, 0.5, 0.45, 0.4, 2.4, seg=10)
    g["Marble"].cyl(0, 0, 2.9, 1.15, 1.15, 0.15, seg=20)
    g["Brass"].cyl(0, 0, 3.05, 1.0, 1.0, 0.04, seg=20)
    for k in range(12):
        a = k * math.pi / 6
        g["Char"].obox(0.82 * math.cos(a), 0.82 * math.sin(a), 3.1, 0.22, 0.05, 0.02, rz=a)
    v = [(0.0, -0.04, 3.09), (0.0, -0.04, 3.85), (0.0, 0.9, 3.09), (0.0, 0.04, 3.09), (0.0, 0.04, 3.85), (0.0, 0.9, 3.091)]
    solid(g, "Brass", [(-0.04, 0.0, 3.09), (-0.04, 0.0, 3.85), (-0.04, 0.9, 3.09), (0.04, 0.0, 3.09), (0.04, 0.0, 3.85), (0.04, 0.9, 3.09)],
          [(0, 1, 2), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (0, 2, 5, 3)])
    C(0, 0, 1.5, 1.8, 1.8, 3.0)


def planter(g, s=2.6, seed=0):
    """돌 화단(네모): 돌 틀 · 흙 · 키 작은 떨기나무 · 겨울 장미 · 눈"""
    g["StoneTrim"].box(0, 0, 0.45, s, s, 0.9)
    g["Char"].box(0, 0, 0.92, s - 0.4, s - 0.4, 0.04)
    for k, (x, y, r) in enumerate(((-0.45, -0.4, 0.55), (0.5, 0.35, 0.5), (0.3, -0.5, 0.4), (-0.4, 0.5, 0.42))):
        sphere(g, "Felt", (x, y, 1.25), r, sub=1)
        sphere(g, ("SignRed", "Paint", "SignPurple")[(k + seed) % 3], (x + 0.1, y - 0.1, 1.25 + r * 0.8), 0.13, sub=1)
    sphere(g, "SnowCap", (0.0, 0.0, 1.5), 0.45, sub=1)
    C(0, 0, 0.45, s, s, 0.9)


def radiant_heater(g):
    """열기 난로 기둥(감정 열기): 무쇠 굽 · 기둥 · 구리 코일 · 빛나는 심 · 우산꼴 반사판 · 놋쇠 꼭지"""
    g["Iron"].cyl(0, 0, 0, 0.7, 0.6, 0.35, seg=10)
    g["Iron"].cyl(0, 0, 0.35, 0.16, 0.14, 4.0, seg=8)
    for k in range(6):
        S.ring(g, "Copper", 0, 0, 2.5 + k * 0.28, 0.35, 0.5, 0.12, n=12)
    g["Core"].cyl(0, 0, 2.45, 0.25, 0.25, 1.75, seg=10)
    g["Iron"].cyl(0, 0, 4.35, 1.4, 0.25, 0.6, seg=12)
    g["Brass"].cyl(0, 0, 4.95, 0.2, 0.08, 0.4, seg=8)
    S.ring(g, "SnowCap", 0, 0, 4.7, 0.3, 1.05, 0.12, n=12)
    g["LampPt"].box(0, 0, 3.2, 0.3, 0.3, 0.3)
    C(0, 0, 2.2, 1.0, 1.0, 4.4)


def yard_hospital(g):
    K = "Yard_Hospital"
    fence(g, K, gates=((0.0, 42.5, 8.0, True), (-55.1, 22.0, 7.5, False), (51.4, 22.0, 7.5, False)),
          icon=lambda q, x, y, z, f: heart_icon(q, x, y, z - 0.1, face=f))
    path(g, (0.0, 15.2), (0.0, 17.5), 5.0, lv=0)
    path(g, (-54.5, 22.0), (50.8, 22.0), 4.0, lv=1)
    path(g, (0.0, 26.2), (0.0, 27.4), 4.0, lv=0)
    path(g, (0.0, 40.6), (0.0, 41.7), 4.0, lv=0)
    place(g, 0.0, 21.8, respawn_plaza)
    NPC(6.4, 19.6, 0.2, 0.0)                                                # 간호사(뒷문을 본다 — 부활해 나오는 사람을 맞는다)
    place(g, 0.0, 34.0, gazebo)
    # 왼쪽 언 연못 + 걸상 둘 · 오른쪽 해시계 + 화단 넷 + 걸상
    place(g, -31.0, 31.0, frozen_pond)
    bench(g, -39.2, 31.0, 0.0, 5.0, axis="y", mat="Wood")
    bench(g, -22.8, 31.0, 0.0, 5.0, axis="y", mat="Wood")
    for x in (-39.2, -22.8):
        snow(g, x, 31.0, 1.82, 1.3, 4.6, t=0.1)
    place(g, 30.0, 30.0, sundial)
    for k, (x, y) in enumerate(((26.0, 26.0), (34.0, 26.0), (26.0, 34.0), (34.0, 34.0))):
        place(g, x, y, lambda q, s_=k: planter(q, seed=s_))
    bench(g, 30.0, 36.4, 0.0, 4.4, axis="x", mat="Wood")
    snow(g, 30.0, 36.4, 1.82, 4.0, 1.3, t=0.1)
    for x in (-8.0, 8.0):
        lamp_post(g, x, 25.4)
    for x in (-15.6, 15.6):
        lamp_post(g, x, 33.4)
    for x, y in ((-45.0, 30.0), (-50.0, 27.4), (-21.6, 37.2), (45.0, 30.0), (50.0, 27.0), (21.6, 37.2), (-36.0, 13.0), (36.0, 13.0)):
        fir(g, x, y, h=7.5)
    # 날개: 열기 난로 기둥 + 마주 본 걸상 둘
    for s in (-1, 1):
        place(g, s * 31.5, 6.0, radiant_heater)
        for x in (27.5, 35.5):
            bench(g, s * x, 6.0, 0.0, 5.0, axis="y", mat="Leather")


# ------------------------------------------------------------------ 노점 골목
def stall(g, color, seed):
    """노점(앞 -y): 판매대(물건) · 뒤 기둥 둘 높게 · 앞 기둥 둘 낮게 → 앞으로 숙인 줄무늬 천 지붕 + 눈 · 뒤 상자"""
    g["Wood"].box(0, 0, 1.65, 5.0, 1.5, 3.3)
    g["Timber"].box(0, 0, 3.4, 5.3, 1.8, 0.2)
    goods_row(g, -2.3, 2.3, 0, 3.5, seed=seed, depth=1.2)
    for x in (-2.4, 2.4):
        g["Timber"].box(x, 2.4, 3.8, 0.25, 0.25, 7.6)
        g["Timber"].box(x, -1.0, 3.3, 0.25, 0.25, 6.6)
    sl = math.atan2(7.6 - 6.6, 3.4)
    Ls = math.hypot(3.4 + 1.0, 1.0)
    for k in range(5):
        x = -2.4 + (k + 0.5) * 0.96
        g[color if k % 2 else "Canvas"].obox(x, 0.7, 7.15, 0.96, Ls, 0.12, rx=sl)
    g["SnowCap"].obox(0, 0.75, 7.3, 4.6, Ls - 0.4, 0.14, rx=sl)
    for k in range(5):                                                      # 앞 처마 술 장식
        x = -2.4 + (k + 0.5) * 0.96
        g[color if k % 2 else "Canvas"].box(x, -1.45, 6.4, 0.9, 0.06, 0.5)
    crate(g, -1.4, 2.0, 0.0, s=1.4)
    crate(g, 1.5, 2.0, 0.0, s=1.2, rz=0.2)
    C(0, 0, 1.75, 5.3, 1.8, 3.5)
    C(-1.4, 2.0, 0.7, 1.4, 1.4, 1.4)
    C(1.5, 2.0, 0.6, 1.2, 1.2, 1.2)
    for x in (-2.4, 2.4):
        C(x, 2.4, 3.8, 0.3, 0.3, 7.6)


def bunting(g, a, b, z=7.4, mats=("SignRed", "SignBlue", "SignGold", "Canvas")):
    """줄 깃발: 처진 줄(세 토막) + 세모(마름모) 천"""
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    pts = [(a[0], a[1], z), (mid[0], mid[1], z - 0.8), (b[0], b[1], z)]
    for p, q in zip(pts, pts[1:]):
        L = math.dist(p, q)
        an = math.atan2(q[1] - p[1], q[0] - p[0])
        tilt = math.atan2(q[2] - p[2], math.hypot(q[0] - p[0], q[1] - p[1]))
        g["Canvas"].obox((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, (p[2] + q[2]) / 2, L, 0.05, 0.05, ry=-tilt, rz=an)
        n = int(L / 0.8)
        for k in range(n):
            t = (k + 0.5) / n
            x, y, zz = p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t
            g[mats[k % len(mats)]].obox(x, y, zz - 0.3, 0.42, 0.03, 0.42, rx=0.0, rz=an, ry=math.pi / 4)


def platform_scale(g):
    """저울판(앞 -y): 쇠 테 나무 판 · 뒤 기둥 · 큰 눈금판(놋쇠 테 · 바늘) · 저울대(추) · 판 위 자루 둘"""
    g["Iron"].box(0, 0, 0.15, 3.0, 3.0, 0.3)
    g["Wood"].box(0, 0, 0.33, 2.8, 2.8, 0.06)
    g["Iron"].box(0, 1.7, 2.2, 0.5, 0.5, 4.4)
    g["Brass"].hcyl(0, 1.42, 4.6, 1.0, 0.16, axis="y", seg=20)
    g["Dial"].hcyl(0, 1.33, 4.6, 0.86, 0.04, axis="y", seg=20)
    for k in range(10):
        a = math.pi * 1.25 - k * math.pi * 1.5 / 9
        g["Char"].obox(0.7 * math.cos(a), 1.3, 4.6 + 0.7 * math.sin(a), 0.16, 0.02, 0.05, ry=-a)
    g["Iron"].obox(0.2, 1.28, 4.85, 0.05, 0.02, 0.7, ry=-0.5)
    g["Iron"].box(0, 1.7, 3.3, 3.2, 0.14, 0.14)
    g["Iron"].box(-1.2, 1.7, 3.05, 0.4, 0.4, 0.4)
    for k, (x, y) in enumerate(((-0.5, -0.3), (0.6, 0.2))):
        sphere(g, "Canvas", (x, y, 0.95), 0.6, sub=2)
        g["Canvas"].cyl(x, y, 1.4, 0.25, 0.15, 0.4, seg=8)
        g["Leather"].cyl(x, y, 1.5, 0.2, 0.2, 0.08, seg=8)
    C(0, 0, 0.18, 3.0, 3.0, 0.36)
    C(0, 1.7, 2.2, 0.6, 0.6, 4.4)


def notice_board(g):
    """의뢰 게시판(양면, 긴 쪽 x): 기둥 둘 · 판 · 맞배 작은 지붕 + 눈 · 붙인 종이(살짝 기움) · 붉은 핀"""
    for x in (-2.7, 2.7):
        g["Timber"].box(x, 0, 2.8, 0.35, 0.35, 5.6)
    g["Wood"].box(0, 0, 3.4, 5.0, 0.3, 2.8)
    g["Timber"].box(0, 0, 4.85, 5.4, 0.4, 0.15)
    g["Timber"].box(0, 0, 1.95, 5.4, 0.4, 0.15)
    for s in (-1, 1):
        g["RoofMetal"].obox(0, s * 0.45, 5.75, 6.0, 1.1, 0.12, rx=-s * 0.5)
        g["SnowCap"].obox(0, s * 0.42, 5.88, 5.8, 1.0, 0.14, rx=-s * 0.5)
    import random
    rnd = random.Random(9)
    for f in (-1, 1):
        for k, (x, z) in enumerate(((-1.7, 3.9), (-0.6, 4.0), (0.6, 3.8), (1.7, 4.0), (-1.2, 2.8), (0.1, 2.7), (1.3, 2.9))):
            g["Dial" if k % 3 else "Canvas"].obox(x, f * 0.17, z, 0.9, 0.02, 1.0, ry=rnd.uniform(-0.12, 0.12))
            g["SignRed"].box(x, f * 0.19, z + 0.4, 0.08, 0.03, 0.08)
    C(0, 0, 2.8, 5.8, 0.5, 5.6)


def yard_general(g):
    K = "Yard_General"
    fence(g, K, gates=((0.0, 44.5, 8.5, True), (-36.08, 19.0, 7.5, False), (38.9, 19.0, 7.5, False)),
          icon=lambda q, x, y, z, f: sack_icon(q, x, y, z - 0.1, face=f))
    path(g, (0.0, 15.4), (0.0, 43.7), 6.0, lv=0)
    path(g, (-35.5, 19.0), (38.3, 19.0), 4.0, lv=1)
    colors = ("SignBlue", "SignRed", "SignGold")
    for i, by in enumerate((24.0, 30.5, 37.0)):
        place(g, -3.95, by, lambda q, c=colors[i], s_=80 + i: stall(q, c, s_), rz=math.pi / 2)
        place(g, 3.95, by, lambda q, c=colors[(i + 1) % 3], s_=83 + i: stall(q, c, s_), rz=-math.pi / 2)
        NPC(-5.65, by, 0.0, 90.0)
        NPC(5.65, by, 0.0, -90.0)
    for by in (21.6, 28.1, 34.6):                                           # 노점 뒤 기둥(가운데 ± 2.4)끼리
        bunting(g, (-6.35, by), (6.35, by))
    place(g, -20.0, 27.6, platform_scale)
    NPC(-22.4, 27.0, 0.0, 90.0)                                             # 저울지기(판 옆에서 판을 본다)
    place(g, -27.4, 33.4, lambda q: hand_cart(q, crates=False))
    for x, y, s_, rz, z in ((-14.0, 35.6, 2.0, 0.0, 0.0), (-11.9, 35.9, 1.6, 0.25, 0.0), (-13.9, 35.6, 1.4, -0.2, 2.0), (-22.0, 8.0, 2.0, 0.1, 0.0),
                            (-24.1, 8.8, 1.6, -0.2, 0.0), (14.2, 35.2, 1.8, 0.15, 0.0)):
        crate(g, x, y, z, s=s_, rz=rz)
        C(x, y, z + s_ / 2, s_, s_, s_, rz)
    place(g, 20.0, 26.0, notice_board)
    for x, y in ((27.0, 33.0), (28.6, 32.2), (27.6, 34.4), (24.0, 8.0), (25.6, 7.4)):
        barrel(g, x, y, 0.0, r=0.8, h=1.9)
    for x in (-9.5, 9.5):
        lamp_post(g, x, 21.8)
        lamp_post(g, x, 40.0)
    fir(g, -31.0, 35.0, h=7.0)
    fir(g, 33.0, 34.4, h=7.0)


JOBS = [
    ("Yard_Smithy", "YdSmithy", yard_job("Yard_Smithy", yard_smithy)),
    ("Yard_Enhance", "YdEnh", yard_job("Yard_Enhance", yard_enhance)),
    ("Yard_Bank", "YdBank", yard_job("Yard_Bank", yard_bank)),
    ("Yard_Inn", "YdInn", yard_job("Yard_Inn", yard_inn)),
    ("Yard_Potion", "YdPot", yard_job("Yard_Potion", yard_potion)),
    ("Yard_Hospital", "YdHosp", yard_job("Yard_Hospital", yard_hospital)),
    ("Yard_General", "YdGen", yard_job("Yard_General", yard_general)),
]
