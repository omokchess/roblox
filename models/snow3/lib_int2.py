# -*- coding: utf-8 -*-
"""
snow3/lib_int2.py — 2026-11-18 아트 2팀. 2팀 건물(여관·병원·물약·강화소·동문·계류탑) 내부 소품 + 구멍 막이 + 1인칭 내부 렌더.
lib.py · lib_a.py · lib_b.py 는 공용이라 고치지 않고 여기에 더한다(b_inn · b_hospital · b_potion · b_enhance · b_gate · b_mast 만 쓴다).

사용자(2026-11-18): "각 건물의 특색이 잘 드러나도록 내부 인테리어를 채워주고, 건물 내부에 있는 모든 오브젝트들의 퀄리티를 극상으로 올려줘.
지금 테마에 맞는 수준에서 퀄리티의 극상이니까, 극사실주의로 만들면 안 돼."
양식: 각지고 굵직한 블록감(약간 두툼한 비례), 단색 재질 + 놋쇠/구리 2단 디테일(테·리벳·손잡이). 상자 하나로 때운 물건 금지,
잘게 부서진 잡음·사진 질감·가는 실물 크기 금지. 1인칭 눈높이 4.5 에서 실루엣이 또렷하게.

■ 렌더(같은 자리 전/후): blender -b -P models/snow3/lib_int2.py -- <before|after> [Sn3_Inn ...]
     → models/snow3/render/<이름>_int_<시점>_<before|after>.png   (작업대 렌더, 그림자 끔 — 안이 보이게. 창유리·김·등 표지 숨김)
   사진판: python models/snow3/lib_int2.py -- sheet   (PIL 있는 시스템 파이썬 — 블렌더 안 파이썬엔 PIL 없음) → models/snow3/render/int2_sheet.png (시점마다 전 | 후)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

try:                                   # 소품 함수는 블렌더 안에서만(사진판 _sheet 는 PIL 만 쓴다)
    from mathutils import Matrix
    import lib as K
    from lib import bx, LOG
    L, I, S, SVC = K.L, K.I, K.S, K.SVC
except ImportError:                    # pragma: no cover
    K = None


# ================================================================== 놓기 도우미
def put(g, x, y, z, rz, fn, *a, **kw):
    """fn(q, ...) 을 제 좌표(원점 = 바닥 가운데, 앞 = -y)로 지어 (x, y, z) 에 rz(라디안) 돌려 놓는다. 충돌 상자는 coll 로 따로"""
    return L.transformed(g, Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z"), fn, *a, **kw)


def wpt(x, y, rz, lx, ly):
    c, s = math.cos(rz), math.sin(rz)
    return x + c * lx - s * ly, y + s * lx + c * ly


def coll(x, y, z, rz, lx0, lx1, ly0, ly1, lz0, lz1):
    """제 좌표 상자 → 세계 축 상자(돌린 네 귀의 둘레 상자) 충돌"""
    pts = [wpt(x, y, rz, a, b) for a in (lx0, lx1) for b in (ly0, ly1)]
    K.cbox(min(p[0] for p in pts), max(p[0] for p in pts), min(p[1] for p in pts), max(p[1] for p in pts), z + lz0, z + lz1)


def no_vent(g, fn, *a, **kw):
    """fn 이 단 김(Vent) 표지를 버리고 짓는다 — Studio 는 Vent 덩이 하나에 김 하나(상자 전체에서 피어남)라 건물마다 김 자리를 하나만 둔다"""
    def run(q):
        r = fn(q, *a, **kw)
        q["Vent"].bm.clear()
        return r
    return L.transformed(g, Matrix.Identity(4), run)


def prism(q, mat, pts, ax, c0, c1):
    """볼록 다각형(pts = [(u, z)], 반시계) 을 ax('x' = 다각형이 x-z 평면, y 로 c0..c1 밀어냄 / 'y' = y-z 평면, x 로)"""
    n = len(pts)
    c0, c1 = min(c0, c1), max(c0, c1)
    if ax == "x":                     # (u, z) 반시계 다각형의 법선 = x × z = -y → c0 면은 그대로, c1 면은 거꾸로, 옆면은 바깥으로
        v = [(u, c0, z) for u, z in pts] + [(u, c1, z) for u, z in pts]
        f = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))] + [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]
    else:                             # 법선 = y × z = +x → c0 면은 거꾸로, c1 면은 그대로
        v = [(c0, u, z) for u, z in pts] + [(c1, u, z) for u, z in pts]
        f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    q[mat].add_mesh(v, f)               # (2팀 2차) 처음부터 바깥으로 감음 — 얇은 기둥은 finish 의 법선 맞춤이 안쪽으로 뒤집기도 했다(그림 산 RockC 뒷면)


# ================================================================== 구멍 막이(공용 함수 gable_logs · gable_boards · roof_gable 의 틈)
def gable_seal(g, ax, c, R, t=None, mat="DarkLog", drop=2.1):
    """
    박공벽 꼭대기 막이: 박공 서까래 자리(벽 위)를 따라 비스듬한 띠 둘 — 아래 끝 = 서까래 밑선 - drop(통나무 켜 계단 세모 틈을 메움),
    위 끝 = 개판 밑 + 0.12(서까래 높이만큼 비는 틈을 메움). 두께 0.8t 로 통나무 켜(1.0t / 0.84t) 속에 묻혀 틈에서만 보인다.
    실제 통나무집도 박공 맨 위는 물매대로 깎은 통나무 + 박공 서까래가 벽 위에 앉는다.
    ax = 박공벽이 뻗은 축(lib.gable_logs 와 같음), c = 벽 가운데 선, R = lib.RoofFrame(제 좌표 — 돌린 지붕이면 같은 돌림 안에서 부른다)
    """
    t = LOG if t is None else t
    tt = 0.8 * t
    H = R.half - 0.15
    for s in (-1, 1):
        a, b = sorted((0.0, s * H))
        prism(g, mat, [(a, R.zb(a) - drop), (b, R.zb(b) - drop), (b, R.zt(b) + 0.12), (a, R.zt(a) + 0.12)], ax, c - tt / 2, c + tt / 2)


def eave_block(g, R, y0, y1, mat="Timber"):
    """처마 막이판: 옆벽 위 처마도리 위, 서까래 사이(벽 윗선 ~ 개판 밑)를 길게 막는다(새 막이 — 실제 지붕의 frieze block).
    y0..y1 = 두 박공벽 가운데 선(제 좌표). 막이판 윗면은 벽 바깥면 자리 개판 밑보다 0.1 위(개판 속)"""
    H = R.half
    for s in (-1, 1):
        x0, x1 = sorted((s * (H - 1.0), s * (H - 0.08)))
        bx(g, mat, x0, x1, y0, y1, R.z_seat - 0.05, R.zt(H) + 0.1)


_STN = (1.6, 1.1, 1.9, 1.3, 1.5, 1.0, 1.8, 1.2)          # 돌 길이 손 순서(켜마다 시작을 바꿔 엇갈림)


def stone_face(g, ax, c, face, u0, u1, z0, z1, rows_h=0.9, proud=0.1, mat="Stone", seed=0):
    """돌 쌓은 면: 면(ax 축을 따라, 자리 c, 바깥 = face 부호)에 켜마다 길이 다른 돌(줄눈 0.08)을 proud 만큼 내밀어 붙인다.
    몸은 부르는 쪽이 StoneTrim(모르타르 빛)으로 지어 줄눈이 보이게"""
    n = max(1, int(round((z1 - z0) / rows_h)))
    rh = (z1 - z0) / n
    n0, n1 = sorted((c - face * 0.05, c + face * proud))
    for r in range(n):
        u, k = u0, (r * 3 + seed) % len(_STN)
        while u < u1 - 0.25:
            ln = min(_STN[k % len(_STN)], u1 - u)
            k += 1
            a, b = u + 0.04, u + ln - 0.04
            za, zb = z0 + r * rh + 0.04, z0 + (r + 1) * rh - 0.04
            if ax == "x":
                bx(g, mat, a, b, n0, n1, za, zb)
            else:
                bx(g, mat, n0, n1, a, b, za, zb)
            u += ln


def painting(q, w=4.0, h=2.8, frame="DarkLog"):
    """벽 그림(제 좌표: 그림 면 = -y, 벽 = y 0, 아래 가운데 원점): 굵은 틀 · 하늘 · 눈 덮인 산 둘 · 아래 전나무 띠 · 작은 집 불빛"""
    t = 0.3
    bx(q, frame, -w / 2, w / 2, -0.25, 0.0, 0, h)
    bx(q, "Canvas", -w / 2 + t, w / 2 - t, -0.3, -0.25, t, h - t)
    sw, sh = (w - 2 * t) / 3.4, (h - 2 * t) / 2.2                       # 산·집을 액자 안 크기에 맞춤(작은 액자에서 삐져나오지 않게)
    for cx, mw, mh, mat in ((-0.5, 2.6, 1.6, "Stone"), (0.75, 1.8, 1.15, "RockC")):
        cx, mw, mh = cx * sw, min(mw * sw, w - 2 * t), mh * sh
        b = t + 0.45 * sh
        prism(q, mat, [(cx - mw / 2, b), (cx + mw / 2, b), (cx, b + mh)], "x", -0.36, -0.3)
        k = 0.32
        prism(q, "SnowCap", [(cx - mw / 2 * k, b + mh * (1 - k)), (cx + mw / 2 * k, b + mh * (1 - k)), (cx, b + mh)], "x", -0.42, -0.36)
    bx(q, "Needle", -w / 2 + t, w / 2 - t, -0.4, -0.3, t, t + 0.55 * sh)
    bx(q, "Timber", 0.5 * sw, 1.0 * sw, -0.46, -0.4, t + 0.3 * sh, t + 0.75 * sh)
    bx(q, "Glow", 0.65 * sw, 0.85 * sw, -0.5, -0.46, t + 0.42 * sh, t + 0.6 * sh)


_PLANK = (7.6, 6.4, 9.2, 6.8, 8.4, 7.0, 9.6, 6.2)        # 널 길이 손 순서(6~10, 줄마다 시작을 바꿔 맞댄 이음이 엇갈림)
_PLANK_MAT = ("Timber", "FloorWood", "Timber", "FloorWood", "Wood")   # 다섯 장에 Wood 한 장 이하


def plank_floor(g, x0, x1, y0, y1, z, w=1.6, along="x", t=0.08, seam="DarkLog"):
    """마루 널(바닥 위 t): 폭 w 줄, 줄마다 길이 6~10 널을 틈 없이 맞대고(이음은 줄마다 엇갈림), 재질은 Timber 바탕 + 한 톤 밝은 FloorWood
    + 가끔 Wood. 줄눈은 틈 대신 위에 납작한 띠(seam, 폭 0.06 · 두께 0.012)로 그린다.
    (비평 1차 2026-11-24 [심각]: 틈 0.05 + 줄마다 Wood/Timber 가 1인칭에서 계단·얼룩말 줄무늬 → 틈 0 · 한 톤 차 · 엇갈린 이음 · 폭 1.6)"""
    a0, a1, b0, b1 = (x0, x1, y0, y1) if along == "x" else (y0, y1, x0, x1)
    n = max(1, int(round((b1 - b0) / w)))
    ww = (b1 - b0) / n
    zt = z + t

    def B(mat, ua, ub, ca, cb, za, zb):
        if along == "x":
            bx(g, mat, ua, ub, ca, cb, za, zb)
        else:
            bx(g, mat, ca, cb, ua, ub, za, zb)
    for i in range(n):
        c0, c1 = b0 + i * ww, b0 + (i + 1) * ww
        u, k, j = a0, (i * 3) % len(_PLANK), 0
        first = 1.5 + (i * 2.3) % 5.0                          # 줄마다 첫 널을 다르게 잘라 이음을 엇갈림
        while u < a1 - 1e-6:
            ln = first if j == 0 else _PLANK[k % len(_PLANK)]
            if j:
                k += 1
            e = min(a1, u + ln)
            if a1 - e < 1.2:                                   # 끝에 아주 짧은 토막을 남기지 않음
                e = a1
            B(_PLANK_MAT[(i * 2 + j) % len(_PLANK_MAT)], u, e, c0, c1, z, zt)
            if e < a1 - 1e-6:                                  # 맞댄 이음 줄눈(널 위 납작한 띠)
                B(seam, e - 0.03, e + 0.03, c0 + 0.035, c1 - 0.035, zt, zt + 0.012)
            u, j = e, j + 1
        if i:                                                  # 줄 사이 줄눈
            B(seam, a0, a1, c0 - 0.03, c0 + 0.03, zt, zt + 0.012)
    return zt


# ================================================================== 소품(제 좌표: 원점 = 바닥 가운데, 앞 = -y). put(g, x, y, z, rz, 함수, ...) 로 놓는다
def barrel(q, r=0.95, h=2.5, wood="Wood", hoop="Iron", lid="DarkLog", seg=10, bung=True):
    """선 통: 배 부른 몸(아래·위 뿔대) · 널 이음 줄(짙은 띠) · 쇠테 넷 · 위 뚜껑 판 + 마개"""
    rb = r * 0.84
    q[wood].cyl(0, 0, 0, rb, r, h / 2, seg=seg)
    q[wood].cyl(0, 0, h / 2, r, rb, h / 2, seg=seg)
    ap = math.cos(math.pi / seg)
    tilt = math.atan2(r - rb, h / 2)
    Ls = math.hypot(r - rb, h / 2)
    for k in range(0, seg, 2):                                   # 널 이음(면 가운데, 하나 걸러)
        a = (k + 0.5) * 2 * math.pi / seg
        for lo, sgn in ((0.0, 1), (h / 2, -1)):
            rr = (rb + r) / 2 * ap + 0.025
            q["Timber"].obox(rr * math.cos(a), rr * math.sin(a), lo + h / 4, 0.06, 0.1, Ls - 0.05, rz=a, ry=sgn * tilt)
    for f0, f1 in ((0.08, 0.17), (0.3, 0.37), (0.63, 0.7), (0.83, 0.92)):
        z0, z1 = h * f0, h * f1
        rz0 = rb + (r - rb) * (min(z0, h - z0) / (h / 2))
        rz1 = rb + (r - rb) * (min(z1, h - z1) / (h / 2))
        q[hoop].cyl(0, 0, z0, rz0 + 0.06, rz1 + 0.06, z1 - z0, seg=seg)
    q[lid].cyl(0, 0, h, rb - 0.12, rb - 0.12, 0.07, seg=seg)
    if bung:
        q["Brass"].cyl(rb * 0.45, 0, h + 0.07, 0.13, 0.13, 0.1, seg=6)


def barrel_lying(q, r=1.05, length=2.6, tap=True, wood="Wood"):
    """누운 통(긴 축 = y, 앞 뚜껑 = -y) + 앞 뚜껑 놋쇠 꼭지. 바닥에서 r 만큼 올린 가운데(받침은 부르는 쪽)"""
    L.transformed(q, Matrix.Translation((0, length / 2, r)) @ Matrix.Rotation(math.pi / 2, 4, "X"),
                  lambda qq: barrel(qq, r=r, h=length, wood=wood, bung=False))
    if tap:
        rb = r * 0.84
        q["Brass"].hcyl(0, -length / 2 - 0.2, r - rb * 0.45, 0.12, 0.4, axis="y", seg=8)
        q["Brass"].cyl(0, -length / 2 - 0.36, r - rb * 0.45 - 0.35, 0.07, 0.09, 0.35, seg=6)
        q["Wood"].obox(0, -length / 2 - 0.3, r - rb * 0.45 + 0.28, 0.12, 0.12, 0.45)


def cradle(q, length, w, h=0.55):
    """누운 통 받침: 길이 방향(y) 굵은 각재 둘(안쪽 윗모서리에 통이 얹힘) + 바닥 가로 굄목 둘(통 밑보다 낮게)"""
    for s in (-1, 1):
        bx(q, "DarkLog", s * w / 2 - 0.25, s * w / 2 + 0.25, -length / 2, length / 2, 0, h)
    for y in (-length / 2 + 0.35, length / 2 - 0.35):
        bx(q, "Timber", -w / 2 - 0.35, w / 2 + 0.35, y - 0.25, y + 0.25, 0, 0.24)


def cradle_lift(r, w, h=0.55):
    """cradle(w, h) 위에 얹힌 반지름 r 누운 통의 밑 높이(통 가운데 = 밑 + r)"""
    e = w / 2 - 0.25
    return h + math.sqrt(max(0.0, r * r - e * e)) - r


def crate(q, w=2.2, d=2.0, h=1.9, body="Wood", frame="Timber", brace=True, lid_band=True):
    """나무 상자: 들인 판 몸 · 모서리 각재 넷 · 위·아래 둘레 테 · 앞·옆 X 아닌 빗장 한 줄 · 위 쇠 귀 넷"""
    t = 0.22
    bx(q, body, -w / 2 + 0.08, w / 2 - 0.08, -d / 2 + 0.08, d / 2 - 0.08, 0.02, h - 0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(q, frame, *sorted((sx * w / 2, sx * (w / 2 - t))), *sorted((sy * d / 2, sy * (d / 2 - t))), 0, h)
    for z0 in (0.0, h - t):
        for s in (-1, 1):
            bx(q, frame, -w / 2 + t, w / 2 - t, *sorted((s * d / 2, s * (d / 2 - t))), z0, z0 + t)
            bx(q, frame, *sorted((s * w / 2, s * (w / 2 - t))), -d / 2 + t, d / 2 - t, z0, z0 + t)
    if brace:
        a = math.atan2(h - 2 * t, w - 2 * t)
        Ln = math.hypot(h - 2 * t, w - 2 * t)
        q[frame].obox(0, -d / 2 + 0.09, h / 2, Ln, 0.14, 0.2, ry=-a)
        a2 = math.atan2(h - 2 * t, d - 2 * t)
        q[frame].obox(w / 2 - 0.09, 0, h / 2, 0.14, math.hypot(h - 2 * t, d - 2 * t), 0.2, rx=a2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(q, "Iron", *sorted((sx * (w / 2 + 0.03), sx * (w / 2 - 0.45))), *sorted((sy * (d / 2 + 0.03), sy * (d / 2 - 0.45))), h - 0.12, h + 0.03)


def sack(q, s=1.0, mat="Canvas", tie="Leather", lean=0.0):
    """자루: 불룩한 아래(뿔대) · 좁아지는 위 · 묶은 목 + 끈"""
    SVC.frustum(q, mat, 0, 0, 0, 1.45 * s, 1.05 * s, 1.7 * s, 1.25 * s, 0.55 * s)
    SVC.frustum(q, mat, 0, 0, 0.55 * s, 1.7 * s, 1.25 * s, 0.95 * s, 0.75 * s, 0.85 * s)
    q[mat].cyl(lean, 0, 1.4 * s, 0.32 * s, 0.42 * s, 0.32 * s, seg=8)
    q[tie].cyl(lean * 0.5, 0, 1.36 * s, 0.4 * s, 0.38 * s, 0.12 * s, seg=8)


def bottle(q, x, y, z0, liquid, r=0.27, h=1.05, kind=0, label="Canvas", cork="Wood", glass="Glass"):
    """병: 물약 색 몸(색이 바로 읽히게) · 유리 어깨 · 목 · 코르크 · 앞 라벨. kind 0 긴 병 / 1 둥근 납작 병 / 2 네모 병"""
    seg = 8
    if kind == 1:
        rr, hb = r * 1.3, h * 0.42
        q[liquid].cyl(x, y, z0, rr * 0.92, rr, hb, seg=seg)
        q[glass].cyl(x, y, z0 + hb, rr, r * 0.35, h * 0.2, seg=seg)
        nz = z0 + hb + h * 0.2
    elif kind == 2:
        rr, hb = r, h * 0.6
        bx(q, liquid, x - r, x + r, y - r, y + r, z0, z0 + hb)
        q[glass].cyl(x, y, z0 + hb, r * 1.15, r * 0.35, h * 0.14, seg=4)
        nz = z0 + hb + h * 0.14
    else:
        rr, hb = r, h * 0.55
        q[liquid].cyl(x, y, z0, r, r, hb, seg=seg)
        q[glass].cyl(x, y, z0 + hb, r, r * 0.38, h * 0.17, seg=seg)
        nz = z0 + hb + h * 0.17
    q[glass].cyl(x, y, nz, r * 0.34, r * 0.34, h * 0.16, seg=6)
    q[cork].cyl(x, y, nz + h * 0.14, r * 0.3, r * 0.38, h * 0.12, seg=6)
    if label:
        bx(q, label, x - rr * 0.6, x + rr * 0.6, y - rr - 0.04, y - rr * 0.55, z0 + hb * 0.25, z0 + hb * 0.78)


def jar(q, x, y, z0, r=0.42, h=1.0, body="Paint", lid="Brass", band="SignTeal"):
    """약 단지(흰 사기): 몸 · 어깨 · 뚜껑 + 꼭지 · 가운데 색 띠(라벨 자리)"""
    q[body].cyl(x, y, z0, r * 0.9, r, h * 0.7, seg=10)
    q[body].cyl(x, y, z0 + h * 0.7, r, r * 0.75, h * 0.12, seg=10)
    q[lid].cyl(x, y, z0 + h * 0.82, r * 0.82, r * 0.7, h * 0.1, seg=10)
    q[lid].cyl(x, y, z0 + h * 0.92, r * 0.2, r * 0.28, h * 0.12, seg=6)
    q[band].cyl(x, y, z0 + h * 0.28, r * 0.97, r * 0.99, h * 0.22, seg=10)


def mug(q, x, y, z0, body="Wood", band="Iron", beer=True):
    """나무 맥주잔(굵게): 몸 · 쇠테 둘 · 손잡이 · 거품"""
    q[body].cyl(x, y, z0, 0.3, 0.27, 0.68, seg=8)
    for zz in (0.12, 0.5):
        q[band].cyl(x, y, z0 + zz, 0.31, 0.3, 0.07, seg=8)
    bx(q, body, x + 0.27, x + 0.42, y - 0.06, y + 0.06, z0 + 0.15, z0 + 0.55)
    bx(q, body, x + 0.25, x + 0.42, y - 0.06, y + 0.06, z0 + 0.5, z0 + 0.58)
    if beer:
        q["Canvas"].cyl(x, y, z0 + 0.68, 0.26, 0.22, 0.08, seg=8)


def plate(q, x, y, z0, r=0.5, mat="Paint", food=None):
    q[mat].cyl(x, y, z0, r * 0.7, r, 0.08, seg=10)
    if food:
        q[food].cyl(x, y, z0 + 0.08, r * 0.45, r * 0.3, 0.16, seg=8)


def candle(q, x, y, z0, h=0.55, holder="Brass", wax="Paint", light=False):
    """촛대: 놋쇠 받침 접시 · 손잡이 · 초 · 불꽃(Glow)"""
    q[holder].cyl(x, y, z0, 0.32, 0.28, 0.08, seg=8)
    q[holder].cyl(x, y, z0 + 0.08, 0.12, 0.16, 0.18, seg=6)
    q[wax].cyl(x, y, z0 + 0.26, 0.12, 0.11, h, seg=6)
    q["Glow"].obox(x, y, z0 + 0.26 + h + 0.12, 0.1, 0.1, 0.22)
    if light:
        q["LampPt"].box(x, y, z0 + 0.26 + h + 0.5, 0.3, 0.3, 0.3)


def book(q, x, y, z0, w=0.9, d=1.2, h=0.3, cover="Banner", pages="Canvas", open_=False):
    """책(굵게): 닫힌 책 = 표지 + 종이 들임 / 펼친 책 = 두 쪽 살짝 들어 올림 + 가운데 접힘"""
    if open_:
        for s in (-1, 1):
            q[cover].obox(x + s * w / 2, y, z0 + 0.05, w, d, 0.08, ry=-s * 0.08)
            q[pages].obox(x + s * (w / 2 - 0.05), y, z0 + 0.13, w - 0.15, d - 0.12, 0.1, ry=-s * 0.08)
        return
    bx(q, cover, x - w / 2, x + w / 2, y - d / 2, y + d / 2, z0, z0 + h)
    bx(q, pages, x - w / 2 + 0.08, x + w / 2 + 0.03, y - d / 2 + 0.08, y + d / 2 - 0.08, z0 + 0.06, z0 + h - 0.06)


def rug(q, w, d, main="Banner", border="SignGold", inner=None, z=0.0):
    """깔개(길이 = y): 바깥 테 · 안 테(두 겹) · 바탕 · 가운데 마름모 셋(줄) · 양 끝 술 줄 — 두께 계단(겹친 면 없이)"""
    inner = inner or border
    bx(q, border, -w / 2, w / 2, -d / 2, d / 2, z, z + 0.05)
    bx(q, main, -w / 2 + 0.22, w / 2 - 0.22, -d / 2 + 0.22, d / 2 - 0.22, z + 0.05, z + 0.07)
    bx(q, inner, -w / 2 + 0.42, w / 2 - 0.42, -d / 2 + 0.42, d / 2 - 0.42, z + 0.07, z + 0.085)
    bx(q, main, -w / 2 + 0.56, w / 2 - 0.56, -d / 2 + 0.56, d / 2 - 0.56, z + 0.085, z + 0.1)
    m = min(w, d) * 0.22
    long_y = d >= w
    for k in (-1, 0, 1):
        dx, dy = (0.0, k * m * 1.45) if long_y else (k * m * 1.45, 0.0)
        q[border if k == 0 else inner].obox(dx, dy, z + 0.11, m, m, 0.025, rz=math.pi / 4)
    for s_ in (-1, 1):                                      # 술(짧은 쪽 끝)
        n = max(3, int((w if long_y else d) / 0.45))
        for i in range(n):
            t = -0.5 + (i + 0.5) / n
            if long_y:
                bx(q, "Canvas", t * w - 0.08, t * w + 0.08, *sorted((s_ * d / 2, s_ * (d / 2 + 0.28))), z, z + 0.04)
            else:
                bx(q, "Canvas", *sorted((s_ * w / 2, s_ * (w / 2 + 0.28))), t * d - 0.08, t * d + 0.08, z, z + 0.04)


def chair(q, seat_h=1.75, mat="Wood", frame="DarkLog", cushion=None, arms=False):
    """의자(앞 = -y): 굵은 다리 넷 · 아래 가로대(H) · 따낸 좌판 · 등받이(기둥 둘 · 위 가로대 · 세로살 셋) · 방석"""
    w, d = 1.8, 1.7
    p = 0.3
    for sx in (-1, 1):
        x = sx * (w / 2 - p / 2)
        bx(q, frame, x - p / 2, x + p / 2, -d / 2, -d / 2 + p, 0, seat_h)
        bx(q, frame, x - p / 2, x + p / 2, d / 2 - p, d / 2, 0, seat_h + 2.55)
        bx(q, frame, x - 0.12, x + 0.12, -d / 2 + p, d / 2 - p, 0.45, 0.7)
        bx(q, "Wood" if frame != "Wood" else "Timber", x - p / 2 - 0.04, x + p / 2 + 0.04, d / 2 - p - 0.04, d / 2 + 0.04, seat_h + 2.55, seat_h + 2.7)
    bx(q, frame, -w / 2 + p, w / 2 - p, -0.12, 0.12, 0.5, 0.72)
    bx(q, mat, -w / 2, w / 2, -d / 2, d / 2, seat_h, seat_h + 0.22)
    bx(q, mat, -w / 2 + 0.12, w / 2 - 0.12, -d / 2 + 0.12, d / 2 - 0.3, seat_h + 0.22, seat_h + 0.3)
    yb = d / 2 - p / 2
    bx(q, frame, -w / 2 + p, w / 2 - p, yb - 0.13, yb + 0.13, seat_h + 1.9, seat_h + 2.45)
    bx(q, frame, -w / 2 + p, w / 2 - p, yb - 0.1, yb + 0.1, seat_h + 0.55, seat_h + 0.8)
    for k in (-1, 0, 1):
        bx(q, mat, k * 0.38 - 0.11, k * 0.38 + 0.11, yb - 0.07, yb + 0.07, seat_h + 0.8, seat_h + 1.9)
    if cushion:
        bx(q, cushion, -w / 2 + 0.18, w / 2 - 0.18, -d / 2 + 0.15, d / 2 - 0.35, seat_h + 0.3, seat_h + 0.52)
    if arms:
        for sx in (-1, 1):
            x = sx * (w / 2 - p / 2)
            bx(q, frame, x - 0.17, x + 0.17, -d / 2 - 0.05, d / 2 - p, seat_h + 1.1, seat_h + 1.35)
            bx(q, frame, x - 0.12, x + 0.12, -d / 2 + 0.05, -d / 2 + 0.29, seat_h, seat_h + 1.1)


def armchair(q, body="Leather", frame="DarkLog", accent="Brass", back=4.4):
    """날개 안락의자(벽난로 옆): 짙은 틀 위 가죽 덩이 — 좌판 방석 · 등(back 높이, 바닥에서) · 양옆 날개 · 팔걸이 두루마리 · 놋쇠 못 줄 · 짧은 다리"""
    w, d = 2.6, 2.4
    hb = back
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.25), sy * (d / 2 - 0.25)
            bx(q, frame, x - 0.2, x + 0.2, y - 0.2, y + 0.2, 0, 0.55)
    bx(q, frame, -w / 2, w / 2, -d / 2, d / 2, 0.55, 1.0)
    bx(q, body, -w / 2 + 0.45, w / 2 - 0.45, -d / 2 + 0.05, d / 2 - 0.5, 1.0, 1.6)                 # 방석
    bx(q, body, -w / 2 + 0.05, w / 2 - 0.05, d / 2 - 0.55, d / 2, 1.0, hb)                           # 등
    q[body].obox(0, d / 2 - 0.62, hb - 0.5, w - 0.6, 0.25, 0.7, rx=-0.18)                          # 등 위 불룩
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.22)
        bx(q, body, x - 0.22, x + 0.22, -d / 2 + 0.1, d / 2 - 0.4, 1.0, 2.25)                        # 팔걸이 몸
        q[body].hcyl(x, -d / 2 + 0.1 + (d - 0.5) / 2, 2.3, 0.3, d - 0.5, axis="y", seg=8)             # 두루마리
        bx(q, body, x - 0.2, x + 0.2, d / 2 - 0.9, d / 2 - 0.4, 2.25, max(2.4, hb - 0.4))              # 날개
        for k in range(4):                                                                         # 놋쇠 못 줄
            q[accent].box(x + sx * 0.23, -d / 2 + 0.4 + k * 0.5, 1.15, 0.06, 0.14, 0.14)
    bx(q, accent, -w / 2 + 0.1, w / 2 - 0.1, -d / 2 - 0.03, -d / 2 + 0.02, 0.72, 0.84)


def table(q, w, d, h=2.8, top="Wood", frame="DarkLog", stretch=True):
    """탁자(굵은 다리 · 다리 위·아래 마디 · 상판 밑 테 · 아래 H 가로대 · 두꺼운 상판 + 앞 모서리 띠)"""
    t = 0.32
    bx(q, top, -w / 2, w / 2, -d / 2, d / 2, h - t, h)
    bx(q, frame, -w / 2 + 0.06, w / 2 - 0.06, -d / 2 + 0.06, d / 2 - 0.06, h - t - 0.12, h - t)
    ap = 0.5
    for s in (-1, 1):
        bx(q, frame, -w / 2 + 0.35, w / 2 - 0.35, *sorted((s * (d / 2 - 0.35), s * (d / 2 - 0.55))), h - t - ap, h - t - 0.12)
        bx(q, frame, *sorted((s * (w / 2 - 0.35), s * (w / 2 - 0.55))), -d / 2 + 0.35, d / 2 - 0.35, h - t - ap, h - t - 0.12)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.5), sy * (d / 2 - 0.5)
            bx(q, frame, x - 0.21, x + 0.21, y - 0.21, y + 0.21, 0.28, h - t - 0.12)
            bx(q, frame, x - 0.28, x + 0.28, y - 0.28, y + 0.28, 0.0, 0.28)
            bx(q, frame, x - 0.27, x + 0.27, y - 0.27, y + 0.27, h - t - ap - 0.25, h - t - ap)
    if stretch:
        long_x = w >= d
        if long_x:
            bx(q, frame, -w / 2 + 0.5, w / 2 - 0.5, -0.13, 0.13, 0.55, 0.85)
            for sx in (-1, 1):
                bx(q, frame, sx * (w / 2 - 0.5) - 0.13, sx * (w / 2 - 0.5) + 0.13, -d / 2 + 0.5, d / 2 - 0.5, 0.55, 0.85)
        else:
            bx(q, frame, -0.13, 0.13, -d / 2 + 0.5, d / 2 - 0.5, 0.55, 0.85)
            for sy in (-1, 1):
                bx(q, frame, -w / 2 + 0.5, w / 2 - 0.5, sy * (d / 2 - 0.5) - 0.13, sy * (d / 2 - 0.5) + 0.13, 0.55, 0.85)
    return h


def round_table(q, r=1.8, h=2.8, top="Wood", frame="DarkLog"):
    """둥근 탁자: 두꺼운 원판 + 밑 테 · 굵은 기둥(마디 둘) · 십자 발 넷(놋쇠 발끝)"""
    q[top].cyl(0, 0, h - 0.3, r, r, 0.3, seg=16)
    q[frame].cyl(0, 0, h - 0.5, r * 0.82, r * 0.82, 0.2, seg=16)
    q[frame].cyl(0, 0, 0.35, 0.32, 0.32, h - 0.85, seg=8)
    for zz in (0.9, h - 1.1):
        q[frame].cyl(0, 0, zz, 0.45, 0.45, 0.3, seg=8)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        q[frame].obox(math.cos(a) * 0.75, math.sin(a) * 0.75, 0.2, 1.5, 0.36, 0.4, rz=a)
        q["Brass"].box(math.cos(a) * 1.45, math.sin(a) * 1.45, 0.06, 0.3, 0.3, 0.12)


def bench(q, length, h=1.75, mat="Wood", frame="DarkLog"):
    """긴 걸상(길이 = x): 두꺼운 좌판 · 판 다리 둘(아래 발) · 가운데 가로대"""
    bx(q, mat, -length / 2, length / 2, -0.65, 0.65, h - 0.28, h)
    for s in (-1, 1):
        x = s * (length / 2 - 0.6)
        bx(q, frame, x - 0.2, x + 0.2, -0.45, 0.45, 0.3, h - 0.28)
        bx(q, frame, x - 0.28, x + 0.28, -0.6, 0.6, 0, 0.3)
    bx(q, frame, -length / 2 + 0.8, length / 2 - 0.8, -0.13, 0.13, 0.75, 1.0)


def stool(q, h=1.75, mat="Wood", frame="DarkLog"):
    """걸상: 네모 좌판(두꺼움) · 다리 넷 · 아래 고리 테"""
    bx(q, mat, -0.7, 0.7, -0.7, 0.7, h - 0.25, h)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(q, frame, sx * 0.5 - 0.13, sx * 0.5 + 0.13, sy * 0.5 - 0.13, sy * 0.5 + 0.13, 0, h - 0.25)
    for s in (-1, 1):
        bx(q, frame, -0.37, 0.37, s * 0.5 - 0.09, s * 0.5 + 0.09, 0.55, 0.75)
        bx(q, frame, s * 0.5 - 0.09, s * 0.5 + 0.09, -0.37, 0.37, 0.8, 1.0)


def bed(q, w=3.8, ln=6.6, blanket="Banner", sheet="Canvas", frame="DarkLog", panel="Wood", head_h=4.2, foot_h=2.9):
    """침대(머리 = +y 벽 쪽): 기둥 넷(갓·꼭지) · 옆 막대 · 머리판(세 칸 판넬 + 가운데 놋쇠 원) · 발판 · 매트(윗단 들임) ·
    베개(불룩 둘) · 접어 내린 홑청 · 담요(옆으로 흘러내림, 각진 주름 셋)"""
    p = 0.5
    y0, y1 = -ln / 2, ln / 2
    for sy, hh in ((1, head_h), (-1, foot_h)):
        for sx in (-1, 1):
            cx, cy = sx * (w / 2 - p / 2), sy * (ln / 2 - p / 2)
            bx(q, frame, cx - p / 2, cx + p / 2, cy - p / 2, cy + p / 2, 0, hh)
            bx(q, panel, cx - 0.33, cx + 0.33, cy - 0.33, cy + 0.33, hh, hh + 0.2)
            bx(q, frame, cx - 0.2, cx + 0.2, cy - 0.2, cy + 0.2, hh + 0.2, hh + 0.42)
    for sx in (-1, 1):
        cx = sx * (w / 2 - p / 2)
        bx(q, frame, cx - 0.19, cx + 0.19, y0 + p, y1 - p, 0.7, 1.25)
    for sy, top in ((1, head_h - 0.45), (-1, foot_h - 0.4)):
        cy = sy * (ln / 2 - p / 2)
        bx(q, frame, -w / 2 + p, w / 2 - p, cy - 0.2, cy + 0.2, 0.7, 1.25)
        bx(q, frame, -w / 2 + p, w / 2 - p, cy - 0.24, cy + 0.24, top, top + 0.4)
        bx(q, panel, -w / 2 + p, w / 2 - p, cy - 0.1, cy + 0.1, 1.25, top)
        if sy > 0:
            for sx in (-1, 1):
                bx(q, frame, sx * 0.52 - 0.13, sx * 0.52 + 0.13, cy - 0.16, cy + 0.16, 1.25, top)
            q["Brass"].hcyl(0, cy - 0.14, (1.25 + top) / 2 + 0.2, 0.32, 0.08, axis="y", seg=10)
    # 매트 · 홑청
    m0, m1 = -w / 2 + 0.3, w / 2 - 0.3
    bx(q, sheet, m0, m1, y0 + 0.35, y1 - 0.35, 1.25, 1.95)
    bx(q, sheet, m0 + 0.1, m1 - 0.1, y0 + 0.45, y1 - 0.45, 1.95, 2.03)
    # 베개(불룩 — 넓은 판 + 가운데 두툼)
    py = y1 - p - 0.75
    q[sheet].obox(0, py, 2.32, w - 1.1, 1.15, 0.42, rx=-0.22)
    q[sheet].obox(0, py + 0.02, 2.36, w - 1.5, 0.85, 0.56, rx=-0.22)
    # 담요(+ 접어 내린 홑청 띠): 위 판 · 옆·발 늘어뜨림 · 주름 셋
    b0, b1 = y0 + 0.3, y1 - 2.1
    bx(q, blanket, m0 - 0.12, m1 + 0.12, b0, b1, 2.03, 2.2)
    for sx in (-1, 1):
        bx(q, blanket, *sorted((sx * (w / 2 - 0.3 + 0.12), sx * (w / 2 - 0.3 - 0.06))), b0, b1, 1.3, 2.2)
    bx(q, blanket, m0 - 0.12, m1 + 0.12, b0 - 0.18, b0, 1.4, 2.2)
    bx(q, sheet, m0 - 0.05, m1 + 0.05, b1 - 0.55, b1 + 0.05, 2.2, 2.32)
    bx(q, blanket, m0 - 0.08, m1 + 0.08, b1 - 1.05, b1 - 0.55, 2.2, 2.34)
    for k, rx in enumerate((0.35, -0.3, 0.28)):
        yy = b0 + 0.9 + k * (b1 - b0 - 2.2) / 2
        q[blanket].obox(0, yy, 2.24, w - 1.0, 0.55, 0.16, rx=rx)
    return (-w / 2, w / 2, y0, y1)


def wall_shelf(q, w, depth=1.0, mat="Wood", bracket="DarkLog", n_br=2, t=0.2):
    """벽 선반(뒤 = +y 벽면 y 0, 앞 = -y, 판 윗면 z 0): 두꺼운 판 · 까치발(세로 + 비스듬) n 개"""
    bx(q, mat, -w / 2, w / 2, -depth, 0, -t, 0)
    xs = [(-w / 2 + 0.5) + (w - 1.0) * k / max(1, n_br - 1) for k in range(n_br)] if n_br > 1 else [0.0]
    for x in xs:
        bx(q, bracket, x - 0.13, x + 0.13, -0.22, 0.0, -t - 1.1, -t)
        Ln = math.hypot(depth - 0.3, 0.9)
        q[bracket].obox(x, -0.22 - (depth - 0.3) / 2, -t - 0.55, 0.22, Ln, 0.2, rx=-math.atan2(0.9, depth - 0.3))


def sconce(q, light=True):
    """벽 등(벽 = +y): 쇠 받침판 · 굽은 팔 · 놋쇠 갓 등(유리 + 불빛). 원점 = 벽 면 등 높이"""
    bx(q, "Iron", -0.3, 0.3, -0.12, 0.0, -0.6, 0.6)
    bx(q, "Iron", -0.08, 0.08, -1.0, -0.12, -0.1, 0.06)
    bx(q, "Iron", -0.08, 0.08, -1.0, -0.84, 0.06, 0.45)
    S.pyramid(q, "Brass", 0, -0.92, 1.05, 0.9, 0.9, 0.4)
    q["Brass"].box(0, -0.92, 1.05, 0.85, 0.85, 0.08)
    q["Glass"].box(0, -0.92, 0.75, 0.6, 0.6, 0.55)
    q["Glow"].box(0, -0.92, 0.7, 0.18, 0.18, 0.32)
    q["Iron"].box(0, -0.92, 0.42, 0.72, 0.72, 0.12)
    if light:
        q["LampPt"].box(0, -1.4, 0.75, 0.3, 0.3, 0.3)


def kettle(q, x, y, z0, mat="Iron", s=1.0):
    """무쇠 주전자(굵게): 몸 · 뚜껑 · 손잡이 고리 · 부리"""
    q[mat].cyl(x, y, z0, 0.42 * s, 0.5 * s, 0.45 * s, seg=10)
    q[mat].cyl(x, y, z0 + 0.45 * s, 0.5 * s, 0.25 * s, 0.25 * s, seg=10)
    q["Brass"].cyl(x, y, z0 + 0.7 * s, 0.1 * s, 0.08 * s, 0.12 * s, seg=6)
    q[mat].obox(x + 0.55 * s, y, z0 + 0.45 * s, 0.5 * s, 0.14 * s, 0.14 * s, ry=-0.7)
    for sx in (-1, 1):                    # 손잡이 고리: 뚜껑 가장자리 → 위 가로대(2026-11-28 playcheck: 밖으로 벌어져 가로대에 안 닿았다)
        q[mat].obox(x + sx * 0.31 * s, y, z0 + 0.875 * s, 0.12, 0.12, 0.6 * s, ry=-sx * 0.38)
    q[mat].box(x, y, z0 + 1.15 * s, 0.4 * s + 0.12, 0.12, 0.12)


def washstand(q, frame="DarkLog", body="Wood"):
    """세면대(뒤 = +y 벽): 문짝 하나 찬장(틀·들인 판·놋쇠 손잡이) · 대리석 판 · 놋쇠 대야 · 물 주전자 · 옆 수건 걸이 + 수건 · 벽 거울(틀)"""
    w, d, h = 2.2, 1.2, 2.8
    bx(q, body, -w / 2 + 0.1, w / 2 - 0.1, -d / 2 + 0.12, d / 2, 0.25, h - 0.15)
    for sx in (-1, 1):
        bx(q, frame, sx * (w / 2 - 0.15) - 0.15, sx * (w / 2 - 0.15) + 0.15, -d / 2, d / 2, 0, h - 0.15)
    bx(q, frame, -w / 2 + 0.3, w / 2 - 0.3, -d / 2, -d / 2 + 0.2, 0.0, 0.3)
    bx(q, frame, -w / 2 + 0.3, w / 2 - 0.3, -d / 2 + 0.02, -d / 2 + 0.16, 0.45, h - 0.4)
    bx(q, body, -w / 2 + 0.55, w / 2 - 0.55, -d / 2 - 0.02, -d / 2 + 0.06, 0.7, h - 0.65)
    q["Brass"].box(w / 2 - 0.6, -d / 2 - 0.06, h * 0.55, 0.14, 0.12, 0.3)
    bx(q, "Marble", -w / 2 - 0.1, w / 2 + 0.1, -d / 2 - 0.1, d / 2, h - 0.15, h + 0.05)
    q["Brass"].cyl(-0.2, -0.05, h + 0.05, 0.42, 0.62, 0.32, seg=12)
    q["Glass"].cyl(-0.2, -0.05, h + 0.12, 0.45, 0.5, 0.2, seg=12)
    q["Paint"].cyl(0.75, 0.15, h + 0.05, 0.22, 0.28, 0.65, seg=8)
    q["Paint"].cyl(0.75, 0.15, h + 0.7, 0.28, 0.18, 0.25, seg=8)
    q["Paint"].obox(0.75, -0.18, h + 0.85, 0.12, 0.3, 0.12, rx=0.6)
    bx(q, frame, w / 2 + 0.1, w / 2 + 0.25, -0.4, 0.4, h - 0.6, h - 0.45)
    q["Canvas"].obox(w / 2 + 0.24, 0.0, h - 1.2, 0.12, 0.7, 1.3, ry=0.05)
    bx(q, frame, -0.95, 0.95, d / 2 - 0.15, d / 2, h + 0.05, h + 3.6)          # 거울 틀(대리석 판 위에 선다 — 2026-11-28: 벽에서 0.1 떠 있었다)
    bx(q, "Glass", -0.75, 0.75, d / 2 - 0.2, d / 2 - 0.1, h + 1.4, h + 3.4)


def wardrobe(q, body="Wood", frame="DarkLog"):
    """옷장(앞 = -y, 뒤 벽): 받침 · 몸 · 기둥 셋 · 문짝 둘(들인 판넬 위·아래) · 놋쇠 손잡이 · 머리 장식(층진 처마)"""
    w, d, h = 3.0, 1.6, 7.2
    bx(q, frame, -w / 2, w / 2, -d / 2, d / 2, 0, 0.45)
    bx(q, body, -w / 2 + 0.1, w / 2 - 0.1, -d / 2 + 0.1, d / 2, 0.45, h - 0.6)
    for x in (-w / 2 + 0.2, 0.0, w / 2 - 0.2):
        bx(q, frame, x - 0.2, x + 0.2, -d / 2, d / 2 - 0.1, 0.45, h - 0.6)
    for sx in (-1, 1):
        xa, xb = sorted((sx * 0.2, sx * (w / 2 - 0.4)))
        for za, zb in ((0.9, 3.3), (3.7, h - 1.1)):
            bx(q, frame, xa, xb, -d / 2 - 0.02, -d / 2 + 0.1, za - 0.25, za)
            bx(q, "Timber", xa + 0.2, xb - 0.2, -d / 2 - 0.06, -d / 2 + 0.06, za, zb)
        q["Brass"].box(sx * 0.42, -d / 2 - 0.1, 3.5, 0.14, 0.14, 0.55)
    bx(q, frame, -w / 2 - 0.15, w / 2 + 0.15, -d / 2 - 0.15, d / 2, h - 0.6, h - 0.3)
    bx(q, body, -w / 2 - 0.05, w / 2 + 0.05, -d / 2 - 0.05, d / 2, h - 0.3, h)


def nightstand(q, body="Wood", frame="DarkLog"):
    """머리맡 탁자: 다리 넷 · 서랍(놋쇠 꼭지) · 아래 열린 칸 · 두꺼운 위 판"""
    w, d, h = 1.4, 1.2, 2.2
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(q, frame, sx * (w / 2 - 0.12) - 0.12, sx * (w / 2 - 0.12) + 0.12, sy * (d / 2 - 0.12) - 0.12, sy * (d / 2 - 0.12) + 0.12, 0, h - 0.2)
    bx(q, body, -w / 2 + 0.1, w / 2 - 0.1, -d / 2 + 0.1, d / 2 - 0.1, 0.5, 0.65)
    bx(q, body, -w / 2 + 0.1, w / 2 - 0.1, -d / 2 + 0.05, d / 2 - 0.1, h - 0.85, h - 0.2)
    bx(q, frame, -w / 2 + 0.3, w / 2 - 0.3, -d / 2 - 0.02, -d / 2 + 0.1, h - 0.75, h - 0.3)
    q["Brass"].box(0, -d / 2 - 0.06, h - 0.52, 0.16, 0.1, 0.16)
    bx(q, body, -w / 2 - 0.08, w / 2 + 0.08, -d / 2 - 0.08, d / 2 + 0.08, h - 0.2, h)


def bookcase(q, w=2.2, d=1.1, h=7.0, frame="DarkLog", shelf="Wood", seed=0):
    """책장(앞 = -y): 옆판 · 뒤판 · 칸 넷 · 머리 · 칸마다 책 줄(굵은 책 — 높이·색 손으로 정한 순서) + 기댄 책 하나"""
    bx(q, "Timber", -w / 2 + 0.2, w / 2 - 0.2, d / 2 - 0.15, d / 2, 0.3, h - 0.3)
    for sx in (-1, 1):
        bx(q, frame, *sorted((sx * w / 2, sx * (w / 2 - 0.22))), -d / 2, d / 2, 0, h)
    bx(q, frame, -w / 2, w / 2, -d / 2, d / 2, 0, 0.3)
    bx(q, frame, -w / 2 - 0.1, w / 2 + 0.1, -d / 2 - 0.1, d / 2, h - 0.3, h)
    cols = ("Banner", "SignBlue", "Felt", "Leather", "SignGold", "Canvas", "SignRed")
    hs = (1.25, 1.05, 1.35, 1.15, 0.95, 1.3)
    ws = (0.34, 0.28, 0.4, 0.3, 0.36)
    k = seed
    for i, z in enumerate((0.3, 1.95, 3.6, 5.25)):
        if i > 0:
            bx(q, shelf, -w / 2 + 0.22, w / 2 - 0.22, -d / 2 + 0.05, d / 2 - 0.15, z - 0.16, z)
        x = -w / 2 + 0.3
        while x < w / 2 - 0.75:
            bw, bh = ws[k % len(ws)], hs[k % len(hs)]
            bx(q, cols[k % len(cols)], x, x + bw, -d / 2 + 0.2, d / 2 - 0.2, z, z + bh)
            x += bw + 0.03
            k += 1
        q[cols[(k + 2) % len(cols)]].obox(w / 2 - 0.5, 0.0, z + 0.6, 0.3, d - 0.4, 1.15, ry=0.38)


def trunk(q, w=2.0, d=1.2, h=1.4, body="Leather", band="Iron", wood="Wood"):
    """여행 궤짝(앞 = -y): 나무 몸 + 가죽 덮개 · 둥근 뚜껑(반 원통) · 쇠 띠 둘(몸 + 뚜껑) · 놋쇠 자물쇠 · 옆 손잡이"""
    bx(q, wood, -w / 2, w / 2, -d / 2, d / 2, 0, h)
    bx(q, body, -w / 2 + 0.06, w / 2 - 0.06, -d / 2 - 0.04, d / 2 + 0.04, 0.12, h - 0.1)
    q[wood].hcyl(0, 0, h, d / 2, w, axis="x", seg=12)
    q[body].hcyl(0, 0, h, d / 2 + 0.04, w - 0.12, axis="x", seg=12)
    for x in (-w / 2 + 0.4, w / 2 - 0.4):
        bx(q, band, x - 0.1, x + 0.1, -d / 2 - 0.08, d / 2 + 0.08, 0, h)
        q[band].hcyl(x, 0, h, d / 2 + 0.08, 0.2, axis="x", seg=12)
    bx(q, "Brass", -0.22, 0.22, -d / 2 - 0.12, -d / 2 - 0.02, h - 0.45, h + 0.05)
    for sx in (-1, 1):
        bx(q, band, *sorted((sx * (w / 2 + 0.02), sx * (w / 2 + 0.1))), -0.3, 0.3, h - 0.5, h - 0.38)


def panel_counter(g, x0, x1, y0, y1, z0, frame="DarkLog", panel="Wood", body="Timber", top="Wood", trim="Brass", n=None, rail=False):
    """판넬 카운터(세계 좌표, 앞 = -y 면 y0): 몸 · 기둥 줄 + 들인 판넬 · 아래 걸레받이 · 위 띠 · 두꺼운 상판(앞 0.15 내밈) + 앞 모서리 쇠/놋쇠 띠
    · (rail) 발걸이. 높이 COUNTER_H, 충돌 상자. 상판 윗면 높이를 돌려준다"""
    zt = z0 + K.COUNTER_H
    bx(g, body, x0 + 0.15, x1 - 0.15, y0 + 0.3, y1 - 0.05, z0, zt - 0.35)
    n = n or max(2, int(round((x1 - x0) / 1.7)))
    for i in range(n + 1):
        x = x0 + 0.15 + (x1 - x0 - 0.3) * i / n
        bx(g, frame, x - 0.18, x + 0.18, y0 + 0.12, y0 + 0.32, z0 + 0.6, zt - 0.85)
        if i < n:
            xa, xb = x + 0.18, x0 + 0.15 + (x1 - x0 - 0.3) * (i + 1) / n - 0.18
            bx(g, panel, xa + 0.15, xb - 0.15, y0 + 0.2, y0 + 0.3, z0 + 0.9, zt - 1.15)
    bx(g, frame, x0 + 0.15, x1 - 0.15, y0 + 0.08, y0 + 0.31, z0, z0 + 0.6)
    bx(g, frame, x0 + 0.15, x1 - 0.15, y0 + 0.1, y0 + 0.31, zt - 0.85, zt - 0.35)
    bx(g, top, x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.1, zt - 0.35, zt)
    bx(g, trim, x0 - 0.17, x1 + 0.17, y0 - 0.19, y0 - 0.11, zt - 0.3, zt - 0.05)
    if rail:
        for x in (x0 + 0.6, (x0 + x1) / 2, x1 - 0.6):
            bx(g, trim, x - 0.08, x + 0.08, y0 - 0.45, y0 + 0.1, z0 + 0.4, z0 + 0.55)
        g[trim].hcyl((x0 + x1) / 2, y0 - 0.45, z0 + 0.47, 0.12, x1 - x0 - 0.8, axis="x", seg=8)
    K.cbox(x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.1, z0, zt)
    return zt


def heart(q, x, y, z, s=1.0, mat="Core", depth=0.5):
    """굵은 심장(면 = -y, 가운데 (x, y, z)): 위 둥근 혹 둘(눕힌 원통) + 아래 45° 돌린 덩이"""
    for sx in (-1, 1):
        q[mat].hcyl(x + sx * 0.3 * s, y, z + 0.22 * s, 0.4 * s, depth * s, axis="y", seg=12)
    q[mat].obox(x, y, z - 0.12 * s, 0.78 * s, depth * s, 0.78 * s, ry=math.pi / 4)


def green_cross(q, x, y, z, s=1.0, depth=0.25, plate=False, face=-1, centered=False, mat="PaintGreen"):
    """녹십자(2026-11-28 사용자: "병원은 하트가 아니라 녹십자 모양으로"): 가운데 (x, z), 면 = face 쪽(±y). 두툼한 블록 십자(팔 폭 0.44 s · 길이 1.3 s).
    plate = 뒤에 흰 판(놋쇠 테) 을 깔고 그 앞에 십자. centered = y 를 가운데로 양면(우리 속·고리 속처럼 떠 있는 기관용)"""
    f = face
    w, ln = 0.44 * s, 1.3 * s
    y0 = y
    if plate:
        h = 0.82 * s
        bx(q, "Paint", x - h, x + h, *sorted((y, y + f * 0.12)), z - h, z + h)
        for a, b, c, d in ((-h - 0.1, h + 0.1, -h - 0.1, -h + 0.06), (-h - 0.1, h + 0.1, h - 0.06, h + 0.1),
                           (-h - 0.1, -h + 0.06, -h + 0.06, h - 0.06), (h - 0.06, h + 0.1, -h + 0.06, h - 0.06)):
            bx(q, "Brass", x + a, x + b, *sorted((y, y + f * 0.18)), z + c, z + d)
        y0 = y + f * 0.12
    ya, yb = sorted((y0 - depth / 2, y0 + depth / 2)) if centered else sorted((y0, y0 + f * depth))
    bx(q, mat, x - w / 2, x + w / 2, ya, yb, z - ln / 2, z + ln / 2)
    bx(q, mat, x - ln / 2, x - w / 2, ya, yb, z - w / 2, z + w / 2)
    bx(q, mat, x + w / 2, x + ln / 2, ya, yb, z - w / 2, z + w / 2)


def full_ring(q, mat, x, y, z, r0, r1, t, n=16):
    """선 고리(x-z 평면, 두께 t 는 y): 위 반원 + 180° 돌린 아래 반원"""
    I.half_ring(q, mat, x, y, z, r0, r1, t, n=n)
    L.transformed(q, Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.pi, 4, "Y") @ Matrix.Translation((-x, -y, -z)),
                  lambda qq: I.half_ring(qq, mat, x, y, z, r0, r1, t, n=n))


def heart_engine(q):
    """녹십자 톱니 기관(2026-11-28 하트 → 녹십자. 앞 = -y, 원점 바닥 가운데): 돌 받침 · 쇠 기둥 넷 + 위 덮개 · 놋쇠 고리 둘 사이 쇠살 우리 · 우리 속 흰 원판 + 녹십자 ·
    양옆 큰 놋쇠 톱니 · 앞 압력계 · 아래 구리 통 · 위로 나가는 구리 관 자리(부르는 쪽이 관을 잇는다)"""
    bx(q, "DarkStone", -1.6, 1.6, -1.3, 1.3, 0, 0.6)
    bx(q, "Iron", -1.7, 1.7, -1.4, 1.4, 0.6, 0.8)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(q, "Iron", sx * 1.35 - 0.18, sx * 1.35 + 0.18, sy * 1.05 - 0.18, sy * 1.05 + 0.18, 0.8, 6.2)
            for z in (1.2, 2.6, 4.0, 5.4):                                      # 놋쇠 리벳(기둥 바깥 두 면)
                q["Brass"].box(sx * 1.55, sy * 1.05, z, 0.06, 0.14, 0.14)
                q["Brass"].box(sx * 1.35, sy * 1.25, z + 0.3, 0.14, 0.06, 0.14)
    bx(q, "Iron", -1.6, 1.6, -1.3, 1.3, 6.2, 6.6)
    bx(q, "Brass", -1.65, 1.65, -1.35, 1.35, 6.6, 6.75)
    q["Copper"].cyl(0, 0, 0.8, 0.95, 0.95, 1.3, seg=12)
    q["Brass"].cyl(0, 0, 2.1, 1.05, 1.05, 0.25, seg=12)
    q["Brass"].cyl(0, 0, 5.4, 1.05, 1.05, 0.25, seg=12)
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        q["Iron"].box(0.92 * math.cos(a), 0.92 * math.sin(a), 3.75, 0.14, 0.14, 3.1)
    q["Brass"].cyl(0, 0, 2.35, 0.12, 0.12, 0.7, seg=6)
    q["Paint"].hcyl(0, 0, 3.75, 0.78, 0.36, axis="y", seg=16)                # 우리 속 흰 원판 + 두툼한 녹십자(양면) — 2026-11-28 하트 → 녹십자
    green_cross(q, 0, 0, 3.75, s=1.15, depth=0.62, centered=True)
    q["LampPt"].box(0, -1.6, 3.8, 0.3, 0.3, 0.3)
    for sx in (-1, 1):
        S.gear(q, "Brass", sx * 1.62, 0, 3.75, 1.0, 14, 0.25, axis="x")
        q["Iron"].hcyl(sx * 1.5, 0, 3.75, 0.25, 0.3, axis="x", seg=8)
    q["Brass"].hcyl(0, -1.2, 1.45, 0.13, 0.62, axis="y", seg=8)             # 압력계 목(구리 통 → 계기 — 2026-11-28: 계기가 떠 있었다)
    q["Iron"].hcyl(0, -1.5, 1.45, 0.5, 0.15, axis="y", seg=14)
    q["Dial"].hcyl(0, -1.58, 1.45, 0.4, 0.06, axis="y", seg=14)
    q["Iron"].obox(0.1, -1.63, 1.55, 0.06, 0.03, 0.34, ry=-0.7)


def halo(q, x, y, z, r=2.6):
    """되살아나는 고리(선 고리, 면 = ±y): 놋쇠 테 + 바깥 톱니 16 · 안쪽 붉은 빛 테 · 살 넷 → 가운데 놋쇠 톱니 + 흰 원판 + 녹십자(2026-11-28 하트 → 녹십자)"""
    full_ring(q, "Brass", x, y, z, r - 0.5, r, 0.45, n=16)
    full_ring(q, "Core", x, y, z, r - 0.68, r - 0.5, 0.2, n=16)
    for k in range(16):
        a = 2 * math.pi * k / 16
        q["Brass"].obox(x + (r + 0.12) * math.cos(a), y, z + (r + 0.12) * math.sin(a), 0.36, 0.38, 0.32, ry=-a)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        rr = (r - 0.68 + 0.75) / 2
        q["Iron"].obox(x + rr * math.cos(a), y, z + rr * math.sin(a), r - 0.68 - 0.75, 0.16, 0.16, ry=-a)
    S.gear(q, "Brass", x, y, z, 0.85, 12, 0.3, axis="y")
    q["Paint"].hcyl(x, y, z, 0.62, 0.42, axis="y", seg=14)                  # 톱니 가운데 흰 원판 + 녹십자 양면(2026-11-28 하트 → 녹십자)
    green_cross(q, x, y, z, s=0.85, depth=0.66, centered=True)


def folding_screen(q, panels=3, w=1.6, h=5.2, cloth="Canvas", frame="DarkLog"):
    """접이 칸막이(제 좌표: 바닥 가운데, 판이 x 를 따라 지그재그): 판마다 틀(기둥 둘·위아래 가로대) + 천 · 발"""
    a0 = 0.45
    span = panels * w * math.cos(a0)
    px, py = -span / 2, 0.0
    for i in range(panels):
        a = a0 if i % 2 == 0 else -a0
        nx, ny = px + w * math.cos(a), py + w * math.sin(a)
        cx, cy = (px + nx) / 2, (py + ny) / 2
        q[frame].obox(cx, cy, 0.5, w - 0.2, 0.16, 0.15, rz=a)
        q[frame].obox(cx, cy, h + 0.1, w - 0.2, 0.18, 0.2, rz=a)
        q[cloth].obox(cx, cy, (0.6 + h) / 2, w - 0.2, 0.08, h - 0.6, rz=a)
        if i == 0:
            q[frame].cyl(px, py, 0, 0.13, 0.13, h + 0.35, seg=6)
        q[frame].cyl(nx, ny, 0, 0.13, 0.13, h + 0.35, seg=6)
        q["Brass"].cyl(nx, ny, h + 0.35, 0.16, 0.08, 0.2, seg=6)
        px, py = nx, ny


def drip_stand(q, flask="SignRed"):
    """약병 걸이대(굵게): 무쇠 발 셋 · 놋쇠 기둥 · 위 가로 팔 + 매단 큰 병 · 내려오는 관(굵게)"""
    for k in range(3):
        a = k * 2 * math.pi / 3
        q["Iron"].obox(0.45 * math.cos(a), 0.45 * math.sin(a), 0.1, 1.0, 0.22, 0.2, rz=a)
    q["Brass"].cyl(0, 0, 0.2, 0.12, 0.1, 5.6, seg=8)
    q["Brass"].box(0.4, 0, 5.75, 1.1, 0.14, 0.14)
    q["Iron"].cyl(0.8, 0, 5.15, 0.04, 0.04, 0.6, seg=4)
    q[flask].cyl(0.8, 0, 4.3, 0.3, 0.3, 0.55, seg=8)
    q["Glass"].cyl(0.8, 0, 4.85, 0.3, 0.12, 0.3, seg=8)
    q["Glass"].cyl(0.8, 0, 3.9, 0.08, 0.08, 0.4, seg=6)


def cart(q, w=2.4, d=1.4, h=2.6, frame="Brass", shelf="Marble"):
    """약품 수레: 놋쇠 기둥 넷 · 대리석 판 둘 · 작은 바퀴 넷 · 손잡이"""
    for sx in (-1, 1):
        for sy in (-1, 1):
            q[frame].cyl(sx * (w / 2 - 0.12), sy * (d / 2 - 0.12), 0.35, 0.09, 0.09, h - 0.35, seg=6)
            q["Iron"].hcyl(sx * (w / 2 - 0.12), sy * (d / 2 - 0.12), 0.2, 0.2, 0.14, axis="x", seg=8)
    for z in (0.8, h - 0.1):
        bx(q, shelf, -w / 2, w / 2, -d / 2, d / 2, z, z + 0.12)
    q[frame].hcyl(w / 2 + 0.25, 0, h + 0.3, 0.07, d - 0.2, axis="y", seg=6)
    for sy in (-1, 1):
        bx(q, frame, w / 2 - 0.05, w / 2 + 0.3, sy * (d / 2 - 0.15) - 0.05, sy * (d / 2 - 0.15) + 0.05, h + 0.02, h + 0.36)


def mortar(q, x, y, z0, s=1.0):
    """막자사발(굵게): 돌 사발(아래 좁은 뿔대 + 테) · 속 가루 · 비스듬히 꽂힌 나무 막자"""
    q["StoneTrim"].cyl(x, y, z0, 0.35 * s, 0.55 * s, 0.45 * s, seg=10)
    q["StoneTrim"].cyl(x, y, z0 + 0.45 * s, 0.6 * s, 0.6 * s, 0.1 * s, seg=10)
    q["Felt"].cyl(x, y, z0 + 0.52 * s, 0.45 * s, 0.45 * s, 0.05 * s, seg=10)
    q["Wood"].obox(x + 0.15 * s, y, z0 + 0.85 * s, 0.18 * s, 0.18 * s, 1.0 * s, ry=0.45)


def scale(q, x, y, z0):
    """천칭(놋쇠, 굵게): 받침 · 기둥 · 가로대 · 매단 접시 둘(쇠줄 셋 대신 굵은 막대 둘)"""
    q["Wood"].box(x, y, z0 + 0.1, 1.6, 0.8, 0.2)
    q["Brass"].cyl(x, y, z0 + 0.2, 0.1, 0.08, 1.6, seg=8)
    q["Brass"].box(x, y, z0 + 1.82, 1.9, 0.12, 0.12)
    q["Brass"].obox(x, y, z0 + 1.95, 0.3, 0.12, 0.3, ry=math.pi / 4)
    for sx in (-1, 1):
        for sy in (-1, 1):
            q["Iron"].obox(x + sx * 0.92 + sx * 0.0, y + sy * 0.18, z0 + 1.35, 0.05, 0.05, 0.9, rx=sy * 0.35)
        q["Brass"].cyl(x + sx * 0.92, y, z0 + 0.85, 0.42, 0.5, 0.12, seg=10)


def herbs(q, x, y, z_top, mat="Felt", drop=1.6, stem="Twig"):
    """매단 말린 약초 다발(z_top = 묶은 매듭 높이): 줄기 일곱(0.12 각, 아래로 조금씩 벌어짐) · 가죽 끈 매듭 · 아래 1/3 잎 덩이 다섯(엇갈림)"""
    q["Leather"].cyl(x, y, z_top - 0.22, 0.17, 0.17, 0.22, seg=6)
    for k in range(7):
        a = k * 2 * math.pi / 7 + 0.3
        sp = 0.08 + 0.04 * (k % 3)
        q[stem].obox(x + math.cos(a) * sp, y + math.sin(a) * sp, z_top - 0.22 - drop * 0.45, 0.12, 0.12, drop * 0.9,
                     rx=math.sin(a) * 0.12, ry=-math.cos(a) * 0.12)
    for k, (dx, dy, dz, sz) in enumerate(((0.12, 0.05, 0.62, 0.42), (-0.14, 0.1, 0.7, 0.38), (0.02, -0.15, 0.78, 0.45),
                                           (0.18, -0.12, 0.88, 0.32), (-0.1, -0.05, 0.94, 0.36))):
        q[mat].obox(x + dx, y + dy, z_top - 0.22 - drop * dz, sz, sz * 0.8, sz * 1.1, rz=k * 1.1, rx=0.2 * (k % 2))


def drawer_chest(q, w=4.4, d=1.2, h=3.0, cols=3, rows=2, body="Timber", front="Wood", top="Wood", label="Paint"):
    """서랍장(앞 = -y): 몸 · 서랍(틀 안 들인 앞판 + 이름표 판 + 놋쇠 손잡이) · 두꺼운 위 판 · 받침"""
    bx(q, "DarkLog", -w / 2, w / 2, -d / 2, d / 2, 0, 0.3)
    bx(q, body, -w / 2 + 0.05, w / 2 - 0.05, -d / 2 + 0.05, d / 2, 0.3, h - 0.2)
    cw, ch = (w - 0.3) / cols, (h - 0.7) / rows
    for i in range(cols):
        for r in range(rows):
            x0 = -w / 2 + 0.15 + i * cw
            z0 = 0.4 + r * ch
            bx(q, front, x0 + 0.07, x0 + cw - 0.07, -d / 2 - 0.02, -d / 2 + 0.1, z0 + 0.07, z0 + ch - 0.07)
            bx(q, label, x0 + cw / 2 - 0.35, x0 + cw / 2 + 0.35, -d / 2 - 0.06, -d / 2 - 0.02, z0 + ch * 0.62, z0 + ch * 0.62 + 0.3)
            q["Brass"].box(x0 + cw / 2, -d / 2 - 0.08, z0 + ch * 0.35, 0.5, 0.12, 0.14)
    bx(q, top, -w / 2 - 0.1, w / 2 + 0.1, -d / 2 - 0.1, d / 2, h - 0.2, h)


def _rod(q, mat, p0, p1, w):
    """두 점 사이 네모 막대(굵기 w)"""
    dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    ln = math.sqrt(dx * dx + dy * dy + dz * dz)
    q[mat].obox((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2, w, w, ln,
                ry=math.acos(max(-1.0, min(1.0, dz / ln))), rz=math.atan2(dy, dx))


def cauldron(q, liquid="GlowTeal"):
    """끓는 솥(2026-11-28 다시 — 사용자 4차: '배 불룩 솥·두꺼운 테·다리 셋·끓는 액체 면(거품 덩이·김)·장작불·국자, 납작 뚜껑 위 청록 점 금지').
    바닥 가운데 원점. 돌 화덕 고리(돌 여덟) + 재 바닥(장작불·불 자리는 부르는 쪽, z 0.48) · 굽은 쇠 다리 셋(발 + 무릎) ·
    배 불룩 무쇠 솥(다섯 마디 — 가장 넓은 배 r 1.55) · 두꺼운 테(고리 판 0.32) · 끓는 물약 면(테 0.16 밑) + 부푼 거품 덩이 일곱(면에 박힘) + 터진 거품 고리 ·
    김 기둥 둘(유리 덩이 셋씩 위로 갈수록 크게 — 면에서 이어짐) · 귀 둘 + 들 손잡이(아치) · 테에 걸쳐 물약에 담근 국자"""
    for k in range(8):                                                   # 돌 화덕 고리
        a = k * math.pi / 4 + 0.2
        q["StoneTrim" if k % 2 else "Stone"].obox(1.75 * math.cos(a), 1.75 * math.sin(a), 0.24, 0.95, 0.75, 0.48 - 0.06 * (k % 2), rz=a + math.pi / 2)
    q["Soot"].cyl(0, 0, 0.0, 1.45, 1.45, 0.48, seg=14)
    for k in range(3):                                                   # 굽은 다리: 재 위 발 → 무릎 → 솥 배 밑
        a = k * 2 * math.pi / 3 + 0.5
        c, s = math.cos(a), math.sin(a)
        q["Iron"].obox(1.25 * c, 1.25 * s, 0.6, 0.5, 0.4, 0.24, rz=a)
        _rod(q, "Iron", (1.25 * c, 1.25 * s, 0.6), (1.2 * c, 1.2 * s, 1.35), 0.3)
        _rod(q, "Iron", (1.2 * c, 1.2 * s, 1.35), (0.95 * c, 0.95 * s, 1.8), 0.3)
    for z0, r0, r1, h in ((1.15, 0.7, 1.15, 0.35), (1.5, 1.15, 1.5, 0.45), (1.95, 1.5, 1.55, 0.3), (2.25, 1.55, 1.4, 0.4), (2.65, 1.4, 1.25, 0.25)):
        q["Iron"].cyl(0, 0, z0, r0, r1, h, seg=18)
    K.S.ring(q, "Iron", 0, 0, 2.85, 1.05, 1.5, 0.32, n=18)              # 두꺼운 테(2.85..3.17)
    K.S.ring(q, "Brass", 0, 0, 3.17, 1.12, 1.42, 0.06, n=18)
    q[liquid].cyl(0, 0, 2.75, 1.12, 1.12, 0.26, seg=18)                  # 물약 면(3.01 — 테 윗면 0.16 밑)
    for x, y, r in ((0.35, 0.2, 0.42), (-0.45, -0.3, 0.36), (0.1, -0.6, 0.3), (-0.25, 0.55, 0.34), (0.68, -0.25, 0.26), (-0.7, 0.25, 0.28), (0.05, 0.0, 0.3)):
        q[liquid].cyl(x, y, 2.9, r, r * 0.35, r * 1.1, seg=8)              # 부푼 거품(밑은 면 속)
    for x, y in ((0.55, 0.65), (-0.55, -0.75)):                           # 터진 거품 고리
        K.S.ring(q, "Verdigris", x, y, 3.01, 0.12, 0.24, 0.05, n=8)
    for bxx, byy, kk in ((0.3, 0.15, 0), (-0.4, -0.3, 1)):                # 김 기둥(유리 덩이 셋 — 겹쳐 이어짐)
        z = 3.2
        for j, r in enumerate((0.32, 0.45, 0.58)):
            q["Glass"].obox(bxx + 0.12 * j * (1 if kk else -1), byy + 0.1 * j, z + r * 0.6, r * 1.6, r * 1.5, r * 1.3, rz=0.4 * j + kk)
            z += r * 1.05
    for sx in (-1, 1):                                                   # 귀 + 들 손잡이(아치 셋)
        q["Iron"].box(sx * 1.55, 0, 2.95, 0.36, 0.42, 0.42)
        _rod(q, "Iron", (sx * 1.6, 0, 3.1), (sx * 1.05, 0, 4.05), 0.2)
    q["Iron"].box(0, 0, 4.05, 2.3, 0.2, 0.2)
    _rod(q, "Wood", (0.55, -0.45, 3.0), (1.85, -1.1, 4.25), 0.2)           # 국자 자루(테에 걸침) + 쇠 바가지(물약 속)
    q["Iron"].cyl(0.5, -0.42, 2.8, 0.26, 0.34, 0.3, seg=8)
    q["Brass"].box(1.85, -1.1, 4.3, 0.24, 0.24, 0.16)


def ladder(q, h, w=1.4):
    """사다리(제 좌표: 발 = 원점, 위로 h, 뒤 +y 로 기댐 없이 곧게 — 부르는 쪽이 기울인다): 옆대 둘 · 디딤 막대 · 위 놋쇠 갈고리"""
    for sx in (-1, 1):
        bx(q, "Wood", sx * w / 2 - 0.12, sx * w / 2 + 0.12, -0.12, 0.12, 0, h)
        bx(q, "Brass", sx * w / 2 - 0.1, sx * w / 2 + 0.1, -0.05, 0.4, h - 0.1, h + 0.1)
    z = 0.9
    while z < h - 0.4:
        bx(q, "Timber", -w / 2, w / 2, -0.09, 0.09, z, z + 0.16)
        z += 1.0


def crystal(q, x, y, z, r=0.5, h=2.0, mat="GlowTeal", tilt=0.0, rz=0.0):
    """수정(육각 쌍뿔 — 아래 뿔 · 기둥 · 위 뿔). tilt = 기울기(라디안), rz = 기우는 쪽"""
    def build(qq):
        qq[mat].cyl(0, 0, 0, 0.05, r, h * 0.25, seg=6)
        qq[mat].cyl(0, 0, h * 0.25, r, r, h * 0.45, seg=6)
        qq[mat].cyl(0, 0, h * 0.7, r, 0.05, h * 0.3, seg=6)
    L.transformed(q, Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(tilt, 4, "Y"), build)


def crystal_altar(q):
    """청록 수정 받침(강화대 머리, 원점 바닥 가운데): 팔각 돌 단 둘 · 놋쇠 띠 두른 팔각 돌 기둥 · 기둥머리 · 놋쇠 받침 + 발톱 넷 ·
    큰 청록 수정 + 둘레 작은 수정 셋 · 바닥 청록 룬 고리(빛)"""
    q["StoneTrim"].cyl(0, 0, 0, 2.05, 2.05, 0.45, seg=8)
    q["Stone"].cyl(0, 0, 0.45, 1.55, 1.45, 0.45, seg=8)
    q["Stone"].cyl(0, 0, 0.9, 0.8, 0.72, 2.2, seg=8)
    for z in (1.3, 2.6):
        q["Brass"].cyl(0, 0, z, 0.84, 0.82, 0.18, seg=8)
    q["StoneTrim"].cyl(0, 0, 3.1, 0.75, 1.2, 0.45, seg=8)
    q["Brass"].cyl(0, 0, 3.55, 1.0, 0.85, 0.25, seg=10)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        q["Brass"].obox(0.72 * math.cos(a), 0.72 * math.sin(a), 4.2, 0.22, 0.3, 1.25, rz=a, ry=-0.35)
        q["Brass"].box(0.55 * math.cos(a), 0.55 * math.sin(a), 4.85, 0.24, 0.24, 0.24)
    crystal(q, 0, 0, 3.7, r=0.62, h=2.9)
    for k, (a, t, hh) in enumerate(((0.5, 0.5, 1.1), (2.6, 0.45, 0.9), (4.4, 0.55, 1.0))):
        crystal(q, 0.55 * math.cos(a), 0.55 * math.sin(a), 3.75, r=0.25, h=hh, tilt=t, rz=a)
    S.ring(q, "GlowTeal", 0, 0, 0.0, 2.55, 2.8, 0.06, n=24)
    for k in range(8):
        a = k * math.pi / 4
        q["GlowTeal"].obox(3.0 * math.cos(a), 3.0 * math.sin(a), 0.03, 0.5, 0.16, 0.06, rz=a)


def rune_anvil(q):
    """강화 모루(앞 = -y): 통나무 그루터기(지름 2.4) · 쇠 몸(허리 잘록) · 앞으로 뺀 2단 뿔(굵게 → 가늘게) · 꼬리 네모 구멍 · 놋쇠 귀 ·
    윗면 청록 룬 고리 · 놓인 칼 · 망치(그루터기에 기댐)"""
    q["Wood"].cyl(0, 0, 0, 1.2, 1.15, 1.1, seg=12)
    q["Timber"].cyl(0, 0, 1.1, 1.05, 1.05, 0.05, seg=12)
    for k in range(3):
        q["Iron"].cyl(0, 0, 0.2 + k * 0.35, 1.22, 1.22, 0.08, seg=12) if k == 1 else None
    z0 = 1.15
    SVC.frustum(q, "Iron", 0, 0, z0, 1.4, 1.1, 0.8, 0.7, 0.7)
    bx(q, "Iron", -1.0, 0.9, -0.42, 0.42, z0 + 0.7, z0 + 1.25)
    q["Iron"].obox(-1.45, 0, z0 + 1.0, 0.7, 0.62, 0.42, ry=0.12)               # 뿔 굵은 마디
    q["Iron"].obox(-1.98, 0, z0 + 1.07, 0.55, 0.4, 0.26, ry=0.2)               # 뿔 가는 마디
    bx(q, "Soot", 0.55, 0.75, -0.1, 0.1, z0 + 1.2, z0 + 1.27)                   # 꼬리 네모 구멍
    for sx in (-1, 1):
        q["Brass"].box(sx * 0.62, -0.42, z0 + 0.95, 0.2, 0.06, 0.2)
    S.ring(q, "GlowTeal", -0.15, 0, z0 + 1.25, 0.25, 0.36, 0.03, n=14)
    import lib_int1 as P                                                     # 놓인 칼(날·등줄·코등이·손잡이·폼멜 — 2026-11-28 무기 품질)
    L.transformed(q, Matrix.Translation((-1.0, 0.0, z0 + 1.35)) @ Matrix.Rotation(math.pi / 2, 4, "Y"), lambda qq: P.sword(qq, L=1.8, w=0.4))
    q["Iron"].box(0.85, -2.0, 0.16, 0.6, 0.32, 0.32)                          # 망치: 쇠 머리는 바닥, 자루는 그루터기에 기댐(2026-11-28: 머리가 떠 있었다)
    q["Wood"].obox(0.85, -1.585, 0.8, 0.18, 0.18, 1.26, rx=-0.63)


def grindstone(q):
    """발판 숫돌(연마, 앞 = -y): 나무 틀(다리 넷·가로대) · 쇠 굴대 · 큰 둥근 숫돌(놋쇠 축 테) · 아래 물 받이 · 발판 + 크랭크 막대 · 옆 앉는 판"""
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(q, "DarkLog", sx * 0.9 - 0.15, sx * 0.9 + 0.15, sy * 0.8 - 0.15, sy * 0.8 + 0.15, 0, 2.3)
        bx(q, "DarkLog", sx * 0.9 - 0.13, sx * 0.9 + 0.13, -0.8, 0.8, 2.3, 2.6)
        bx(q, "DarkLog", sx * 0.9 - 0.12, sx * 0.9 + 0.12, -0.8, 0.8, 0.4, 0.6)
    q["Iron"].hcyl(0, 0, 2.45, 0.12, 2.3, axis="x", seg=8)
    q["StoneTrim"].hcyl(0, 0, 2.45, 1.35, 0.55, axis="x", seg=16)
    for sx in (-1, 1):
        q["Brass"].hcyl(sx * 0.32, 0, 2.45, 0.35, 0.1, axis="x", seg=10)
    bx(q, "Wood", -0.55, 0.55, -0.7, 0.7, 0.6, 1.0)
    bx(q, "Glass", -0.45, 0.45, -0.6, 0.6, 0.98, 1.02)
    q["Wood"].obox(0, -1.3, 0.25, 0.5, 1.8, 0.12, rx=0.25)
    q["Iron"].obox(1.15, -0.7, 1.4, 0.1, 0.1, 2.0, rx=-0.45)
    q["Iron"].box(1.15, 0, 2.45, 0.12, 0.6, 0.12)


def spear(q, x, y, z0, h=6.4, head="Steel", shaft="Wood", halberd=False):
    """창(굵게 — 자루 0.24): 쇠 물미 · 자루 · 놋쇠 테 · 잎 모양 날(가운데 두툼) / halberd = 도끼날 + 갈고리"""
    q["Iron"].cyl(x, y, z0, 0.13, 0.13, 0.35, seg=6)
    q[shaft].cyl(x, y, z0 + 0.35, 0.12, 0.12, h - 1.45, seg=6)
    q["Brass"].cyl(x, y, z0 + h - 1.15, 0.16, 0.16, 0.18, seg=6)
    import lib_int1 as P                     # 창날 두툼하게(2026-11-28 무기 품질): 쇠 투겁 · 잎 날(두께 0.16 쐐기) · 가운데 등줄 · 각진 끝
    zb = z0 + h - 1.0
    q["Iron"].box(x, y, zb + 0.2, 0.3, 0.3, 0.4)
    L.transformed(q, Matrix.Translation((x, y, 0.0)), lambda qq: (
        P.prism_x(qq, head, [(-0.36, zb + 0.4), (0.0, zb + 0.3), (0.36, zb + 0.4), (0.22, zb + 0.95), (0.0, zb + 1.35), (-0.22, zb + 0.95)], -0.08, 0.08),
        bx(qq, head, -0.12, 0.12, -0.1, 0.1, zb + 0.4, zb + 1.1)) and None)
    if halberd:                              # 도끼날(두께 0.16 · 위아래로 벌어짐) + 뒤 갈고리
        L.transformed(q, Matrix.Translation((x, y, 0.0)) @ Matrix.Rotation(math.pi / 2, 4, "Z"), lambda qq: (
            P.prism_x(qq, head, [(-0.15, zb + 0.1), (-0.15, zb + 0.7), (-0.55, zb + 0.9), (-0.62, zb + 0.4), (-0.55, zb - 0.1)], -0.08, 0.08),
            P.prism_x(qq, head, [(0.15, zb + 0.55), (0.15, zb + 0.25), (0.5, zb + 0.75)], -0.08, 0.08)) and None)


def spear_rack(q, n=4, gap=0.75, h=6.4, halberd_every=2, plan=None, shield=False):
    """벽 창 걸이(벽 = +y, 앞 = -y): 아래 홈 받침 · 위 걸이 막대(벽에 박은 까치발 둘) · 걸린 것(손 표 plan = [(종류, 높이 ±)] — 'h' 미늘창 · 's' 창 · None 빈 칸)
    · shield = 위 가운데 둥근 방패(나무 + 쇠 테 + 놋쇠 배꼽)"""
    plan = plan or [("h" if k % halberd_every == 1 else "s", 0.0) for k in range(n)]
    n = len(plan)
    w = (n - 1) * gap + 0.9
    bx(q, "DarkLog", -w / 2, w / 2, -0.8, 0.0, 0, 0.5)
    bx(q, "Timber", -w / 2 + 0.1, w / 2 - 0.1, -0.7, -0.1, 0.5, 0.6)
    bx(q, "DarkLog", -w / 2, w / 2, -0.55, 0.0, h - 2.0, h - 1.7)
    for sx in (-1, 1):
        bx(q, "DarkLog", sx * (w / 2 - 0.15) - 0.15, sx * (w / 2 - 0.15) + 0.15, -0.3, 0.0, h - 2.8, h - 1.7)
        q["Iron"].box(sx * (w / 2 - 0.15), -0.56, h - 1.85, 0.2, 0.06, 0.2)
    for k, it in enumerate(plan):
        if it is None or it[0] is None:
            continue
        kind, dh = it
        spear(q, -w / 2 + 0.45 + k * gap, -0.38, 0.45 + max(0.0, dh), h=h - 0.45 + min(0.0, dh), halberd=kind == "h")
    if shield:
        zc = h + 0.4
        q["Wood"].hcyl(0, -0.15, zc, 1.0, 0.2, axis="y", seg=14)
        q["Iron"].hcyl(0, -0.12, zc, 1.08, 0.12, axis="y", seg=14)
        q["Brass"].hcyl(0, -0.3, zc, 0.3, 0.14, axis="y", seg=10)


def pallet(q, w=2.6, d=2.0):
    """팔레트(널 다섯 + 받침 각재 셋) — 높이 0.45"""
    for x in (-w / 2 + 0.2, 0.0, w / 2 - 0.2):
        bx(q, "DarkLog", x - 0.2, x + 0.2, -d / 2, d / 2, 0, 0.27)
    for k in range(5):
        y = -d / 2 + 0.2 + k * (d - 0.4) / 4
        bx(q, "Wood", -w / 2, w / 2, y - 0.17, y + 0.17, 0.27, 0.45)


def lift_cage(q, w=2.6, d=2.6, h=3.8):
    """승강 우리(앞 = -y): 쇠 바닥판 · 귀 기둥 넷 · 위 틀 + 매다는 놋쇠 멍에 · 옆·뒤 가로살 셋 · 앞 놋쇠 접이문(반쯤 열림)"""
    bx(q, "IronLight", -w / 2, w / 2, -d / 2, d / 2, 0, 0.22)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(q, "Iron", sx * w / 2 - (0.24 if sx > 0 else 0), sx * w / 2 + (0.0 if sx > 0 else 0.24),
               sy * d / 2 - (0.24 if sy > 0 else 0), sy * d / 2 + (0.0 if sy > 0 else 0.24), 0.22, h)
    for sy in (-1, 1):
        bx(q, "Iron", -w / 2, w / 2, *sorted((sy * d / 2, sy * (d / 2 - 0.24))), h, h + 0.25)
    for sx in (-1, 1):
        bx(q, "Iron", *sorted((sx * w / 2, sx * (w / 2 - 0.24))), -d / 2, d / 2, h, h + 0.25)
    bx(q, "Brass", -0.25, 0.25, -d / 2, d / 2, h + 0.25, h + 0.55)
    q["Brass"].cyl(0, 0, h + 0.55, 0.22, 0.22, 0.3, seg=8)
    for z in (1.1, 2.0, 2.9):
        bx(q, "Iron", -w / 2, w / 2, d / 2 - 0.2, d / 2 - 0.06, z, z + 0.14)
        for sx in (-1, 1):
            bx(q, "Iron", *sorted((sx * w / 2, sx * (w / 2 - 0.14))), -d / 2, d / 2, z, z + 0.14)
    for k in range(4):
        x = -w / 2 + 0.35 + k * 0.32
        bx(q, "Brass", x - 0.05, x + 0.05, -d / 2 - 0.08, -d / 2 + 0.02, 0.3, h - 0.4)
    bx(q, "Brass", -w / 2 + 0.25, -w / 2 + 1.4, -d / 2 - 0.1, -d / 2 + 0.04, h - 0.5, h - 0.36)
    bx(q, "Brass", -w / 2 + 0.25, -w / 2 + 1.4, -d / 2 - 0.1, -d / 2 + 0.04, 0.3, 0.44)


def cable_drum(q, length=3.0, r=0.95):
    """밧줄 감개(굴대 = x): 돌 받침 · 돌 볼 둘 · 쇠 북(감긴 밧줄 띠 셋) · 놋쇠 테 둘 · 굴대 · 오른쪽 큰 톱니 + 멈춤쇠 · 왼쪽 손 크랭크"""
    bx(q, "Stone", -length / 2 - 0.7, length / 2 + 0.7, -0.9, 0.9, 0, 0.6)
    bx(q, "StoneTrim", -length / 2 - 0.8, length / 2 + 0.8, -1.0, 1.0, 0.6, 0.75)
    zc = 0.75 + r + 0.35
    for sx in (-1, 1):
        bx(q, "Stone", sx * (length / 2 + 0.2) - 0.25, sx * (length / 2 + 0.2) + 0.25, -0.65, 0.65, 0.75, zc + 0.45)
    q["Iron"].hcyl(0, 0, zc, r * 0.8, length, axis="x", seg=14)
    for k in range(3):
        q["Canvas"].hcyl(-length / 2 + 0.55 + k * (length - 1.1) / 2, 0, zc, r * 0.92, (length - 0.6) / 3 - 0.06, axis="x", seg=14)
    for sx in (-1, 1):
        q["Brass"].hcyl(sx * (length / 2 - 0.05), 0, zc, r * 1.12, 0.14, axis="x", seg=14)
    q["Iron"].hcyl(0, 0, zc, 0.16, length + 1.4, axis="x", seg=8)
    S.gear(q, "Brass", length / 2 + 0.55, 0, zc, 0.8, 14, 0.2, axis="x")
    q["Iron"].obox(length / 2 + 0.55, -0.6, zc + 0.75, 0.12, 0.12, 0.8, rx=0.6)
    q["Iron"].box(-length / 2 - 0.62, 0, zc - 0.35, 0.12, 0.12, 0.8)
    q["Wood"].hcyl(-length / 2 - 0.85, 0, zc - 0.7, 0.12, 0.5, axis="x", seg=6)


def log_pile(q, w=2.6, d=1.6, rows=3, bark="Timber", end="Wood"):
    """장작 더미(쇠 받침 안): 통나무 동그라미 끝이 앞(-y)으로 보이게 층마다 엇갈려 쌓음"""
    r = 0.32
    bx(q, "Iron", -w / 2 - 0.1, -w / 2 + 0.1, -d / 2, d / 2, 0, rows * 2 * r + 0.4)
    bx(q, "Iron", w / 2 - 0.1, w / 2 + 0.1, -d / 2, d / 2, 0, rows * 2 * r + 0.4)
    bx(q, "Iron", -w / 2, w / 2, -d / 2, d / 2, 0, 0.1)
    for k in range(rows):
        n = int((w - 0.3) / (2 * r)) - (k % 2)
        x0 = -(n - 1) * r
        for i in range(n):
            x = x0 + i * 2 * r
            z = 0.1 + r + k * 2 * r * 0.92
            q[bark].hcyl(x, 0, z, r, d - 0.1, axis="y", seg=7)
            q[end].hcyl(x, -d / 2 + 0.03, z, r * 0.78, 0.08, axis="y", seg=7)

# ------------------------------------------------------------------ 1인칭 내부 시점(블렌더 좌표: 카메라, 바라볼 점) — 전/후 같은 자리
E1 = 2.0 + 4.5            # 1층 눈높이(바닥 FZ 2 + 4.5)
E2 = 14.4 + 4.5           # 여관 2층 눈높이
VIEWS = {
    "Sn3_Inn": [
        ("door", (0.0, -12.0, E1), (0.0, 8.0, 5.0)),
        ("hearth", (3.5, -4.0, E1), (16.0, -4.0, 5.0)),
        ("counter", (-11.0, -8.5, E1), (-11.0, 6.0, 5.0)),
        ("corner_a", (15.0, 8.0, E1), (-8.0, -8.0, 4.5)),
        ("corner_b", (-15.5, -9.5, E1), (6.0, 4.0, 5.0)),
        ("2f_left", (-11.0, 7.0, E2), (-12.0, -9.0, 16.5)),
        ("2f_right", (2.0, 0.0, E2), (13.0, -9.0, 16.5)),
        ("close", (9.5, -4.0, 5.8), (15.5, -4.0, 4.8)),
    ],
    "Sn3_Hospital": [
        ("door", (-7.65, -12.5, E1), (-1.0, 8.0, 5.0)),
        ("focal", (-4.0, -8.5, E1), (2.5, 6.0, 6.5)),
        ("counter", (-12.0, -8.0, E1), (-12.0, 8.0, 5.0)),
        ("corner_a", (6.0, -9.5, E1), (-12.0, 6.0, 5.0)),
        ("corner_b", (-17.5, -10.0, E1), (5.0, 6.0, 5.0)),
        ("close", (0.0, -2.0, 6.0), (1.5, 9.0, 6.5)),
    ],
    "Sn3_Potion": [
        ("door", (0.0, -11.5, E1), (0.0, 9.0, 5.0)),
        ("counter", (0.0, -3.0, E1), (0.0, 10.0, 6.0)),
        ("right", (-3.0, -6.0, E1), (8.0, 1.0, 5.0)),
        ("left", (3.0, -6.0, E1), (-8.0, 0.0, 5.0)),
        ("corner", (-9.5, -9.0, E1), (7.0, 8.0, 5.0)),
        ("close", (3.5, -1.0, 6.0), (8.0, 1.0, 5.0)),
    ],
    "Sn3_Enhance": [
        ("door", (0.0, -11.5, E1), (0.0, 8.0, 5.0)),
        ("counter", (6.0, -6.0, E1), (6.0, 8.0, 5.0)),
        ("focal", (0.0, -5.0, E1), (-7.5, -2.0, 5.0)),
        ("corner_a", (10.5, -9.5, E1), (-8.0, 6.0, 5.0)),
        ("corner_b", (-10.5, -9.5, E1), (6.0, 8.0, 5.0)),
        ("close", (-3.5, -2.5, 6.0), (-7.5, -4.0, 5.2)),
    ],
    "Sn3_Gate": [
        ("approach", (0.0, -10.0, 4.5), (0.0, 3.0, 6.0)),
        ("left", (2.0, -0.5, 4.5), (-6.5, 0.0, 5.5)),
        ("right", (-2.0, -0.5, 4.5), (6.5, 0.0, 5.0)),
        ("through", (0.0, -3.5, 4.5), (0.0, 20.0, 4.0)),
        ("back", (0.0, 9.0, 4.5), (0.0, -3.0, 6.0)),
        ("close", (2.5, -1.0, 4.5), (-6.0, 0.5, 4.0)),
    ],
    # Sn3_Mast 는 2026-11-19 총괄 지시로 2팀 범위에서 빠짐(3팀이 다시 만듦) — 시점 표에서도 뺐다
}



def ski_pair(q, h=6.4):
    """엇걸린 스키 한 벌 + 폴 둘(제 좌표: 벽 = +x 면 x 0, 앞 = -x, 가운데 원점). 스키 = 판 + 휜 코 두 마디 + 가죽 바인딩 덩이, 폴 = 자루 + 놋쇠 손잡이 + 아래 바구니 고리"""
    for sg in (1, -1):
        rx = sg * 0.5
        c, s_ = math.cos(rx), math.sin(rx)
        q["Wood"].obox(-0.12, 0, 0, 0.14, 0.55, h, rx=rx)
        for k, (d0, ln, bend) in enumerate(((h / 2 + 0.25, 0.55, 0.55), (h / 2 + 0.62, 0.45, 1.1))):
            yy, zz = -s_ * d0, c * d0
            q["Wood"].obox(-0.12 - 0.1 * (k + 1), yy, zz, 0.14, 0.5, ln, rx=rx, ry=-bend * 0.5)
        q["Leather"].obox(-0.3, s_ * 0.5, -c * 0.5, 0.3, 0.68, 0.55, rx=rx)
        q["Iron"].obox(-0.3, s_ * 0.5, -c * 0.5, 0.34, 0.72, 0.12, rx=rx)
    for sg in (1, -1):                                         # 폴(스키 뒤로 비스듬)
        rx = sg * 0.22
        c, s_ = math.cos(rx), math.sin(rx)
        q["Timber"].obox(-0.04, sg * 0.9, -0.3, 0.14, 0.14, h - 0.6, rx=rx)
        q["Brass"].obox(-0.04, sg * 0.9 - s_ * (h / 2 - 0.5), -0.3 + c * (h / 2 - 0.5), 0.2, 0.2, 0.5, rx=rx)
        bz, by = -0.3 - c * (h / 2 - 0.9), sg * 0.9 + s_ * (h / 2 - 0.9)
        q["Leather"].obox(-0.12, by, bz, 0.08, 0.6, 0.6, rx=rx)


def key_board(q, w=3.0, h=2.0):
    """방 열쇠판(제 좌표: 벽 = y 0, 앞 = -y, 아래 가운데 원점): 짙은 틀 · 판 · 위 방 그림 판(지붕 셋) · 놋쇠 갈고리 아홉 + 매단 열쇠(고리·대·이)"""
    bx(q, "DarkLog", -w / 2, w / 2, -0.25, 0.0, 0, h)
    bx(q, "Wood", -w / 2 + 0.2, w / 2 - 0.2, -0.3, -0.25, 0.2, h - 0.2)
    for k, x in enumerate((-0.8, 0.0, 0.8)):                   # 방 그림(작은 박공 집 셋)
        prism(q, "Timber", [(x - 0.35, h - 0.62), (x + 0.35, h - 0.62), (x, h - 0.32)], "x", -0.36, -0.3)
        bx(q, "Banner" if k == 1 else "Timber", x - 0.25, x + 0.25, -0.34, -0.3, h - 0.95, h - 0.62)
    for r in range(3):
        for c in range(3):
            x, z = -w / 2 + 0.6 + c * (w - 1.2) / 2, h - 1.1 - r * 0.45
            if r == 0 and c == 1:
                continue
            q["Brass"].box(x, -0.36, z, 0.1, 0.12, 0.1)
            q["Brass"].hcyl(x, -0.37, z - 0.14, 0.1, 0.05, axis="y", seg=8)
            q["Brass"].box(x, -0.37, z - 0.36, 0.06, 0.05, 0.28)
            q["Brass"].box(x + 0.06, -0.37, z - 0.46, 0.08, 0.05, 0.06)
    for x in (-0.25, 0.25):                                    # 가운데 한 칸 = 빈 갈고리 둘(손님이 가져감)
        q["Brass"].box(x, -0.36, h - 1.1, 0.1, 0.12, 0.1)


def picture_lamp(q, w=2.0):
    """그림 등(제 좌표: 벽 = y 0, 원점 = 그림 위 끝 가운데): 놋쇠 받침 · 앞으로 뺀 팔 · 긴 갓 · 빛"""
    bx(q, "Brass", -0.25, 0.25, -0.12, 0.0, 0.05, 0.4)
    bx(q, "Brass", -0.06, 0.06, -0.7, -0.12, 0.25, 0.37)
    q["Brass"].obox(0, -0.78, 0.2, w, 0.42, 0.22, rx=0.4)
    bx(q, "Glow", -w / 2 + 0.15, w / 2 - 0.15, -0.82, -0.68, 0.06, 0.1)
    q["LampPt"].box(0, -1.2, -0.5, 0.3, 0.3, 0.3)


def chain(q, x, y, z0, z1, mat="Brass", t=0.35):
    """굵은 사슬(마디 블록 번갈아 돌림): z0 → z1 세로"""
    k, z = 0, z0
    while z < z1 - 0.1:
        zz = min(z + 0.55, z1)
        if k % 2:
            bx(q, mat, x - 0.08, x + 0.08, y - t / 2, y + t / 2, z, zz)
        else:
            bx(q, mat, x - t / 2, x + t / 2, y - 0.08, y + 0.08, z, zz)
        z, k = zz - 0.08, k + 1


def board_counter(g, x0, x1, y0, y1, z0, body="Paint", top="Marble", trim="Brass"):
    """병원 접수대(세계 좌표, 앞 = -y): 흰 칠 세로 널 앞면(널 하나 걸러 0.08 내밀어 그늘 줄) · 걸레받이 · 위 띠 · 대리석 상판 · 앞 가운데 하트 판. 충돌"""
    zt = z0 + K.COUNTER_H
    bx(g, body, x0 + 0.15, x1 - 0.15, y0 + 0.3, y1 - 0.05, z0, zt - 0.3)
    n = max(4, int(round((x1 - x0 - 0.3) / 0.7)))
    wv = (x1 - x0 - 0.3) / n
    for i in range(n):
        xa = x0 + 0.15 + i * wv
        bx(g, body, xa + 0.02, xa + wv - 0.02, y0 + (0.12 if i % 2 else 0.2), y0 + 0.3, z0 + 0.35, zt - 0.55)
    bx(g, "DarkLog", x0 + 0.1, x1 - 0.1, y0 + 0.05, y0 + 0.31, z0, z0 + 0.35)
    bx(g, body, x0 + 0.1, x1 - 0.1, y0 + 0.02, y0 + 0.31, zt - 0.55, zt - 0.3)
    bx(g, top, x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.1, zt - 0.3, zt)
    bx(g, trim, x0 - 0.17, x1 + 0.17, y0 - 0.19, y0 - 0.11, zt - 0.26, zt - 0.06)
    xc = (x0 + x1) / 2
    g[trim].hcyl(xc, y0 - 0.02, zt - 1.6, 0.62, 0.1, axis="y", seg=16)
    g[body].hcyl(xc, y0 - 0.06, zt - 1.6, 0.52, 0.06, axis="y", seg=16)
    green_cross(g, xc, y0 - 0.09, zt - 1.6, s=0.62, depth=0.12, face=-1)    # 앞 녹십자 판(2026-11-28 하트 → 녹십자)
    K.cbox(x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.1, z0, zt)
    return zt


def drawer_counter(g, x0, x1, y0, y1, z0, frame="PaintGreen", front="Wood", top="Wood", trim="Brass"):
    """약방 카운터(앞 = -y): 앞면 = 이름표 서랍 격자(세 줄 · 놋쇠 손잡이 · 흰 이름표) · 녹색 칠 틀 · 걸레받이 · 상판. 충돌. 상판 윗면을 돌려준다"""
    zt = z0 + K.COUNTER_H
    bx(g, frame, x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.05, z0, zt - 0.3)
    bx(g, "DarkLog", x0 + 0.05, x1 - 0.05, y0 + 0.02, y0 + 0.2, z0, z0 + 0.35)
    cols = max(3, int(round((x1 - x0) / 1.25)))
    cw = (x1 - x0 - 0.3) / cols
    rows, rh = 3, (zt - 0.3 - z0 - 0.5) / 3
    for i in range(cols):
        for r in range(rows):
            xa, za = x0 + 0.15 + i * cw, z0 + 0.42 + r * rh
            bx(g, front, xa + 0.07, xa + cw - 0.07, y0 + 0.02, y0 + 0.12, za + 0.06, za + rh - 0.06)
            bx(g, "Paint", xa + cw / 2 - 0.28, xa + cw / 2 + 0.28, y0 - 0.01, y0 + 0.02, za + rh * 0.58, za + rh * 0.58 + 0.22)
            g[trim].box(xa + cw / 2, y0 - 0.04, za + rh * 0.3, 0.42, 0.12, 0.12)
    bx(g, top, x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.1, zt - 0.3, zt)
    bx(g, trim, x0 - 0.17, x1 + 0.17, y0 - 0.19, y0 - 0.11, zt - 0.26, zt - 0.06)
    K.cbox(x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.1, z0, zt)
    return zt


def glass_case_low(q, w=3.2, d=1.3, h=1.1, frame="Brass", base="Wood"):
    """상판 위 낮은 유리 진열함(제 좌표, 바닥 가운데): 나무 밑판 · 놋쇠 귀 기둥 넷 · 유리 네 면 + 위 · 안 작은 병 다섯(물약 색)"""
    bx(q, base, -w / 2, w / 2, -d / 2, d / 2, 0, 0.18)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(q, frame, sx * w / 2 - (0.1 if sx > 0 else 0), sx * w / 2 + (0 if sx > 0 else 0.1),
               sy * d / 2 - (0.1 if sy > 0 else 0), sy * d / 2 + (0 if sy > 0 else 0.1), 0.18, h)
    bx(q, frame, -w / 2, w / 2, -d / 2, d / 2, h, h + 0.08)
    bx(q, "Glass", -w / 2 + 0.1, w / 2 - 0.1, -d / 2 + 0.02, -d / 2 + 0.06, 0.18, h)
    for k, liq in enumerate(("SignRed", "GlowTeal", "SignPurple", "SignGold", "Verdigris")):
        bottle(q, -w / 2 + 0.45 + k * (w - 0.9) / 4, 0.1, 0.18, liq, r=0.17, h=0.7 - 0.1 * (k % 2), kind=k % 2, label=None)


def stone_counter(g, x0, x1, y0, y1, z0):
    """강화소 카운터(앞 = -y): 짙은 돌 받침(켜 줄) · 앞면 쇠판 넷 + 리벳 줄(위·아래) · 놋쇠 귀 · 짙은 돌 상판 · 오른 끝 바이스. 충돌"""
    zt = z0 + K.COUNTER_H
    bx(g, "DarkStone", x0, x1, y0 + 0.2, y1 - 0.05, z0, zt - 0.35)
    for z in (z0 + 1.0, z0 + 2.0):
        bx(g, "Stone", x0 - 0.04, x1 + 0.04, y0 + 0.16, y1 - 0.1, z - 0.06, z + 0.06)
    n = 4
    pw = (x1 - x0 - 0.4) / n
    for i in range(n):
        xa = x0 + 0.2 + i * pw
        bx(g, "Iron", xa + 0.05, xa + pw - 0.05, y0 + 0.06, y0 + 0.2, z0 + 0.4, zt - 0.6)
        for zz in (z0 + 0.6, zt - 0.8):
            for k in range(5):
                g["Brass"].box(xa + 0.3 + k * (pw - 0.6) / 4, y0 + 0.04, zz, 0.12, 0.06, 0.12)
    for xx in (x0 + 0.05, x1 - 0.05):
        bx(g, "Brass", xx - 0.15, xx + 0.15, y0 + 0.02, y0 + 0.22, z0 + 0.3, zt - 0.35)
    bx(g, "DarkStone", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.1, zt - 0.35, zt)
    bx(g, "Iron", x0 - 0.17, x1 + 0.17, y0 - 0.19, y0 - 0.11, zt - 0.3, zt - 0.08)
    vy = (y0 + y1) / 2                                        # 바이스(오른 끝 옆 — 손잡이가 카운터 앞 빈 바닥으로 나오지 않게)
    bx(g, "Iron", x1 - 0.5, x1 + 0.4, vy - 0.35, vy + 0.35, zt, zt + 0.25)
    for xx in (x1 - 0.45, x1 + 0.0):
        bx(g, "Iron", xx, xx + 0.22, vy - 0.3, vy + 0.3, zt + 0.25, zt + 0.75)
    g["Iron"].hcyl(x1 + 0.6, vy, zt + 0.45, 0.07, 0.7, axis="x", seg=6)
    g["Brass"].hcyl(x1 + 0.95, vy, zt + 0.45, 0.13, 0.14, axis="x", seg=6)
    K.cbox(x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.1, z0, zt)
    return zt


def tool_board(q, w=4.0, h=3.0):
    """연장 걸이판(제 좌표: 벽 = y 0, 앞 = -y, 아래 가운데 원점): 짙은 틀 + 판 · 망치 셋(자루 + 쇠 머리) · 집게 둘(두 팔 + 고리) · 줄(쇠 판 + 손잡이) · 나무 못"""
    bx(q, "DarkLog", -w / 2, w / 2, -0.2, 0.0, 0, h)
    bx(q, "Timber", -w / 2 + 0.2, w / 2 - 0.2, -0.26, -0.2, 0.2, h - 0.2)
    for k, x in enumerate((-1.4, -0.9, -0.4)):                 # 망치 셋(머리 위)
        hh = 1.4 - 0.2 * k
        q["Wood"].box(x, -0.38, h / 2 - 0.1, 0.16, 0.12, hh)
        q["Iron"].box(x, -0.42, h / 2 - 0.1 + hh / 2 + 0.12, 0.62 - 0.08 * k, 0.24, 0.24)
        q["DarkLog"].box(x, -0.32, h / 2 + hh / 2 - 0.1, 0.12, 0.12, 0.12)
    for x in (0.45, 1.0):                                      # 집게 둘
        for sg in (-1, 1):
            q["Iron"].obox(x + sg * 0.1, -0.38, h / 2 - 0.2, 0.1, 0.1, 1.6, ry=sg * 0.08)
        q["Iron"].hcyl(x, -0.38, h / 2 + 0.65, 0.12, 0.12, axis="y", seg=8)
    q["Steel"].box(1.55, -0.36, h / 2 - 0.3, 0.2, 0.08, 1.1)       # 줄
    q["Wood"].box(1.55, -0.38, h / 2 + 0.45, 0.24, 0.14, 0.5)


def lamp_post(q, h=7.0):
    """증기 가로등(제 좌표: 바닥 가운데): 돌 받침 · 쇠 기둥(놋쇠 띠) · 위 팔 · 놋쇠 지붕 유리 등 · 빛"""
    bx(q, "Stone", -0.7, 0.7, -0.7, 0.7, 0, 0.6)
    bx(q, "StoneTrim", -0.75, 0.75, -0.75, 0.75, 0.6, 0.75)
    q["Iron"].cyl(0, 0, 0.75, 0.26, 0.2, h - 1.9, seg=8)
    for z in (1.4, h - 2.6):
        q["Brass"].cyl(0, 0, z, 0.3, 0.3, 0.2, seg=8)
    q["Iron"].cyl(0, 0, h - 1.15, 0.35, 0.25, 0.3, seg=8)
    S.pyramid(q, "Brass", 0, 0, h - 0.15, 1.3, 1.3, 0.55)
    q["Brass"].box(0, 0, h - 0.2, 1.2, 1.2, 0.1)
    q["Glass"].box(0, 0, h - 0.7, 0.85, 0.85, 0.9)
    q["Glow"].box(0, 0, h - 0.75, 0.3, 0.3, 0.45)
    q["Iron"].box(0, 0, h - 1.2, 1.0, 1.0, 0.15)
    q["LampPt"].box(0, 0, h - 0.7, 0.3, 0.3, 0.3)


def deck_chair(q, blanket="Felt"):
    """볕쬐기 의자(앞 = -y, 등 = +y 쪽으로 눕힘): 다리 넷 · 옆 틀 · 좌판 살 · 등판 살 다섯 · 팔걸이 · 발치 접은 담요"""
    for sx in (-1, 1):
        for yy, hh in ((-1.0, 1.0), (0.9, 1.0)):
            bx(q, "DarkLog", sx * 0.9 - 0.13, sx * 0.9 + 0.13, yy - 0.13, yy + 0.13, 0, hh)
        bx(q, "DarkLog", sx * 0.9 - 0.12, sx * 0.9 + 0.12, -1.2, 1.0, 1.0, 1.25)
        q["DarkLog"].obox(sx * 0.9, 1.4, 2.1, 0.22, 0.22, 2.2, rx=-0.45)
        bx(q, "Wood", sx * 1.02 - 0.12, sx * 1.02 + 0.12, -1.0, 0.8, 1.9, 2.05)
        bx(q, "DarkLog", sx * 1.02 - 0.08, sx * 1.02 + 0.08, -0.9, -0.75, 1.25, 1.9)
    for k in range(5):
        y = -1.1 + k * 0.45
        bx(q, "Wood", -0.8, 0.8, y - 0.17, y + 0.17, 1.12, 1.25)
    for k in range(5):
        x = -0.68 + k * 0.34
        q["Wood"].obox(x, 1.45, 2.15, 0.26, 0.1, 2.0, rx=-0.45)
    bx(q, blanket, -0.7, 0.7, -1.05, -0.35, 1.25, 1.55)
    bx(q, blanket, -0.66, 0.66, -1.0, -0.4, 1.55, 1.75)


def ore_display(q, w=4.0, d=2.0, h=2.0):
    """낮은 원석 진열대(제 좌표): 짙은 나무 다리·테 · 벨벳 윗판 · 놋쇠 테두리 · 청록·보라·파랑 원석 덩이(손 자리)"""
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(q, "DarkLog", sx * (w / 2 - 0.2) - 0.18, sx * (w / 2 - 0.2) + 0.18, sy * (d / 2 - 0.2) - 0.18, sy * (d / 2 - 0.2) + 0.18, 0, h - 0.3)
    bx(q, "DarkLog", -w / 2, w / 2, -d / 2, d / 2, h - 0.5, h - 0.25)
    bx(q, "Banner", -w / 2 + 0.1, w / 2 - 0.1, -d / 2 + 0.1, d / 2 - 0.1, h - 0.25, h - 0.15)
    for sx in (-1, 1):
        bx(q, "Brass", -w / 2, w / 2, *sorted((sx * d / 2, sx * (d / 2 - 0.12))), h - 0.25, h - 0.05)
        bx(q, "Brass", *sorted((sx * w / 2, sx * (w / 2 - 0.12))), -d / 2 + 0.12, d / 2 - 0.12, h - 0.25, h - 0.05)
    for k, (x, y, r, hh, mat, t, rz) in enumerate(((-1.3, -0.3, 0.3, 1.0, "GlowTeal", 0.3, 0.0), (-0.5, 0.35, 0.22, 0.7, "SignPurple", 0.5, 1.4),
                                                     (0.3, -0.2, 0.34, 1.2, "GlowTeal", 0.15, 2.5), (1.1, 0.3, 0.2, 0.65, "SignBlue", 0.45, 4.0),
                                                     (1.45, -0.35, 0.16, 0.5, "SignPurple", 0.6, 5.2))):
        crystal(q, x, y, h - 0.15, r=r, h=hh, mat=mat, tilt=t, rz=rz)


def stair2(g, x_bot, x_top, y0, y1, z0, z1, open_y, guard_from=2, guard_h=3.0, runner="Banner", runner_w=4.0):
    """곧은 나무 계단(세계 좌표, x_bot 아랫단 앞 → x_top 윗단 끝, 폭 y0..y1, 열린 옆 = open_y). lib_a.stair_x 와 같은 충돌·치수 + 다듬음(비평 5):
    챌판 Timber(한 톤 짙게) · 디딤판 Wood 0.15 내밈(그늘선) · 가운데 깔개(runner_w) + 챌판마다 놋쇠 누름대 · 계단 밑 막힌 몸.
    열린 옆: guard_from 단부터 물매 따라 곧은 측판 한 장(Timber 0.4, 디딤 밑 1.0 ~ 디딤 위 guard_h) + 위 손잡이 턱 + 아래·위 기둥(놋쇠 갓)"""
    n = max(1, int(math.ceil((z1 - z0) / K.STEP_RISE - 1e-6)))
    rs = (z1 - z0) / n
    d = (x_top - x_bot) / n
    sg = 1 if d > 0 else -1
    ym = (y0 + y1) / 2
    for k in range(n):
        top = z0 + rs * (k + 1)
        xa, xb = sorted((x_bot + d * k, x_top))
        bx(g, "Timber", xa, xb, y0, y1, z0 if k == 0 else top - rs, top - 0.18)
        xs0, xs1 = sorted((x_bot + d * k, x_bot + d * (k + 1)))
        nose0, nose1 = (xs0, xs1 + 0.15) if sg < 0 else (xs0 - 0.15, xs1)       # 앞(아래 쪽)으로 0.15 내민 디딤판
        bx(g, "Wood", nose0, nose1, y0 + 0.02, y1, top - 0.18, top)
        bx(g, runner, xs0 + 0.02, xs1 - 0.02, ym - runner_w / 2, ym + runner_w / 2, top, top + 0.04)
        fx = x_bot + d * k                                                       # 챌판 앞 = 이 단의 아래 끝
        bx(g, runner, *sorted((fx, fx - sg * 0.05)), ym - runner_w / 2, ym + runner_w / 2, top - rs + 0.02, top)
        bx(g, "Brass", *sorted((fx - sg * 0.06, fx - sg * 0.16)), ym - runner_w / 2 - 0.1, ym + runner_w / 2 + 0.1, top - 0.06, top + 0.06)
        K.cbox(xs0, xs1, y0, y1, z0, top)
        if k >= guard_from:
            ya, yb = sorted((open_y, open_y + (-0.5 if open_y <= y0 else 0.5)))
            K.cbox(xs0, xs1, ya, yb, top - rs, top + guard_h)
    # 곧은 측판(물매 따라 평행사변형 한 장) + 손잡이 턱 + 기둥 둘
    xg0 = x_bot + d * guard_from
    zg0 = z0 + rs * (guard_from + 1)
    yp0, yp1 = sorted((open_y, open_y + (-0.4 if open_y <= y0 else 0.4)))
    slope = rs / d                                                               # 디딤판 앞 끝을 잇는 선

    def zline(x):
        return zg0 + (x - xg0) * slope
    # 위 끝은 윗층 마루(z1)에서 자른다 — 윗층 계단 구멍 난간과 겹쳐 솟지 않게
    xc = xg0 + (z1 - guard_h - zg0) / slope
    xc = min(max(xc, min(xg0, x_top)), max(xg0, x_top))
    poly = [(xg0, zline(xg0) - 1.4), (x_top, zline(x_top) - 1.4), (x_top, z1), (xc, z1), (xg0, zline(xg0) + guard_h)]
    poly = [p for i, p in enumerate(poly) if i == 0 or abs(p[0] - poly[i - 1][0]) + abs(p[1] - poly[i - 1][1]) > 1e-4]
    cx_ = sum(p[0] for p in poly) / len(poly)
    cz_ = sum(p[1] for p in poly) / len(poly)
    poly.sort(key=lambda p: math.atan2(p[1] - cz_, p[0] - cx_))                 # 반시계 볼록 다각형
    prism(g, "Timber", poly, "x", yp0, yp1)
    ang = math.atan2(guard_h + zline(xc) - zline(xg0) - guard_h, xc - xg0) if abs(xc - xg0) > 1e-3 else 0.0
    Ln = math.hypot(xc - xg0, zline(xc) - zline(xg0))
    ycap = (yp0 + yp1) / 2
    if Ln > 0.5:
        g["DarkLog"].obox((xg0 + xc) / 2, ycap, (zline(xg0) + zline(xc)) / 2 + guard_h + 0.12, Ln, 0.7, 0.24, ry=-ang)
    zp = zline(xg0)                                                               # 아래 기둥(바닥부터, 놋쇠 갓)
    bx(g, "DarkLog", xg0 - 0.35, xg0 + 0.35, ycap - 0.35, ycap + 0.35, z0, zp + guard_h + 0.5)
    bx(g, "Brass", xg0 - 0.42, xg0 + 0.42, ycap - 0.42, ycap + 0.42, zp + guard_h + 0.5, zp + guard_h + 0.75)
    return n


def board_wall(g, ax, c, face, u0, u1, z0, ztop_fn, w=1.0, mat="Timber"):
    """세로 판 벽(면 자리 c, 바깥 = face): u0..u1 를 폭 w 판으로, 판마다 위 끝 = ztop_fn(판 가운데) (계단 밑 경사 벽 — 위 계단은 측판이 덮는다)"""
    n = max(1, int(round((u1 - u0) / w)))
    ww = (u1 - u0) / n
    for i in range(n):
        a, b = u0 + i * ww, u0 + (i + 1) * ww
        zt = ztop_fn((a + b) / 2)
        if zt - z0 < 0.2:
            continue
        th = 0.14 + (0.08 if i % 2 else 0.0)
        n0, n1 = sorted((c, c + face * th))
        if ax == "x":
            bx(g, mat, a + 0.02, b - 0.02, n0, n1, z0, zt)
        else:
            bx(g, mat, n0, n1, a + 0.02, b - 0.02, z0, zt)

def _render(tag, names):
    import importlib
    import bpy
    from mathutils import Vector
    import lib as K
    out = os.path.join(HERE, "render")
    os.makedirs(out, exist_ok=True)
    mods = {}
    for p in sorted(os.listdir(HERE)):
        if p.startswith("b_") and p.endswith(".py"):
            m = importlib.import_module(p[:-3])
            if m.NAME in VIEWS and (not names or m.NAME in names):
                mods[m.NAME] = m
    for name, m in mods.items():
        K.L.clear_scene()
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        sh = scene.display.shading
        sh.light, sh.color_type = "STUDIO", "MATERIAL"
        sh.show_cavity = True
        sh.show_shadows = False
        sh.background_type = "VIEWPORT"
        sh.background_color = (0.62, 0.72, 0.82)
        scene.render.resolution_x, scene.render.resolution_y = 1200, 800
        bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.02))
        bpy.context.active_object.data.materials.append(K.L.material("SnowCap", K.PAL))
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        objs, tris, (zm, zl) = K.build_model(m, zfix=False)
        print("  %s %d tri" % (name, sum(tris.values())))
        for ob in objs:
            ob.hide_render = ob.name.endswith(("WinGlass", "_Vent", "_LampPt"))
        for tail, loc, look in VIEWS[name]:
            cam.location = Vector(loc)
            cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
            cam.data.type = "PERSP"
            cam.data.lens = 17
            cam.data.clip_start = 0.1
            cam.data.clip_end = 2000.0
            scene.render.filepath = os.path.join(out, "%s_int_%s_%s.png" % (name, tail, tag))
            bpy.ops.render.render(write_still=True)


def _sheet():
    """시점마다 [전 | 후] 한 줄, 건물마다 띠 — 작게(가로 2 × 360)"""
    from PIL import Image, ImageDraw
    out = os.path.join(HERE, "render")
    rows = []
    for name, views in VIEWS.items():
        for tail, _, _ in views:
            pair = [os.path.join(out, "%s_int_%s_%s.png" % (name, tail, t)) for t in ("before", "after")]
            if all(os.path.exists(p) for p in pair):
                rows.append(("%s %s" % (name[4:], tail), pair))
    W, H = 360, 240
    cols = 2                       # 한 칸 = 전|후 둘
    n = len(rows)
    per = 3                        # 한 줄에 시점 셋
    nr = (n + per - 1) // per
    sheet = Image.new("RGB", (per * (cols * W + 12), nr * (H + 22)), (24, 26, 30))
    d = ImageDraw.Draw(sheet)
    for i, (label, pair) in enumerate(rows):
        r, c = divmod(i, per)
        x0, y0 = c * (cols * W + 12), r * (H + 22)
        for k, p in enumerate(pair):
            im = Image.open(p).convert("RGB").resize((W, H))
            sheet.paste(im, (x0 + k * W, y0 + 20))
        d.text((x0 + 4, y0 + 4), "%s   before | after" % label, fill=(235, 235, 235))
    sheet.save(os.path.join(out, "int2_sheet.png"))
    print("sheet", n, "views")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args and args[0] == "sheet":
        _sheet()
    else:
        _render(args[0] if args else "after", args[1:])
