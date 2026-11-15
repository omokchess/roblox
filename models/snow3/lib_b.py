# -*- coding: utf-8 -*-
"""
snow3/lib_b.py — 2026-11-14. 아트 부서원 2 전용 부품(B 양식 건물: 강화소·은행·병원·시계탑). lib.py 는 공용이라 고치지 않고 여기에 더한다.

■ 부품(한 줄씩)
    member(g, mat, p0, p1, w, h)                두 3D 점 사이 각재(서까래·추녀·가새 — 아무 방향)
    plane_slab(g, mat, pts, zfun, off, th)      평면 위 볼록 다각형 판(지붕 개판·덮개·눈). zfun(x, y) = 서까래 밑선, off·th 는 수직 두께
    hip_roof(g, A, B, z_plate, pitch, eave, cut, cover) 모임지붕(은행) / 사각뿔(시계탑, A = B) / 잘린 모임지붕(cut = 안쪽 평평한 단까지 들임)
                                                 처마도리(네 벽 위) → 마룻대 → 추녀(모서리 대각) → 서까래·짧은 서까래 → 개판 → 덮개 → 눈 + 추녀마루 눈
    shed_roof(g, ax, u0, u1, p_hi, p_lo, z_hi, z_lo, eave)  외쪽 지붕(회랑·차양·탑 단 사이 띠지붕). 받침(벽 띠장·기둥 보)은 부르는 쪽이 짓는다
    railing(g, ax, c, u0, u1, z0)               기둥 사이 난간(아랫대·손잡이·살) — 난간 위엔 아무것도 세우지 않는다
    barred_window(g, ax, c, u, z0, face)        lib.window + 바깥 쇠살(은행)
    grille(g, x0, x1, y, z0, z1, gaps)          카운터 위 쇠살 칸막이(창구 구멍 gaps = [(x0, x1)])
    vault_door(g, x, y, z0, r, face)            닫힌 금고문(원판·바퀴·빗장·경첩·돌 문틀). 돌려주는 값 = INFO 용 (가운데, 지름)
    clock_face(g, ax, c, u, zc, r, face)        시계판(뒷판·놋쇠 테·흰 판·눈금·고정 바늘·축)
"""
import math

import lib as K
from lib import bx, cbox, SNOW_T


# ------------------------------------------------------------------ 기본
def member(g, mat, p0, p1, w, h):
    """p0 → p1 각재(단면 폭 w · 높이 h)"""
    dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    hz = math.hypot(dx, dy)
    Ln = math.sqrt(hz * hz + dz * dz)
    if Ln < 1e-3:
        return
    g[mat].obox((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2, Ln, w, h,
                rz=math.atan2(dy, dx), ry=-math.atan2(dz, hz))


def plane_slab(g, mat, pts, zfun, off, th):
    """평면 다각형(plan 점 pts, 볼록, 반시계) 판: 밑면 z = zfun + off, 윗면 = 밑면 + th (수직 값)"""
    q = []
    for p in pts:
        if not q or math.hypot(p[0] - q[-1][0], p[1] - q[-1][1]) > 1e-4:
            q.append(p)
    if math.hypot(q[0][0] - q[-1][0], q[0][1] - q[-1][1]) < 1e-4:
        q.pop()
    n = len(q)
    if n < 3:
        return
    v = [(x, y, zfun(x, y) + off) for x, y in q] + [(x, y, zfun(x, y) + off + th) for x, y in q]
    f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    g[mat].add_mesh(v, f)


# ------------------------------------------------------------------ 모임지붕 / 사각뿔
def hip_roof(g, A, B, z_plate, pitch, eave=K.EAVE_SIDE, cut=None, cx=0.0, cy=0.0, plate=True, snow=True, cover="RoofMetal"):
    """
    벽 바깥면 반폭 A(x)·B(y, A ≥ B), 벽 윗면 z_plate. 모든 면 물매 pitch. cut = 바깥면에서 안쪽으로 이 거리에서 평평하게 자름(None = 끝까지).
    돌려주는 값 = (마루 높이(서까래 밑), 함수 zb(인셋)) — 인셋 = 벽 바깥면에서 안쪽으로 잰 거리
    """
    p = math.radians(pitch)
    t = math.tan(p)
    cp = math.cos(p)
    zs = z_plate + 0.9
    d = B if cut is None else min(cut, B)
    e = eave
    rh = 0.9

    def zb(i):
        return zs + i * t
    # 처마도리(네 벽 위)
    if plate:
        for s in (-1, 1):
            bx(g, "DarkLog", cx - A, cx + A, *sorted((cy + s * B, cy + s * (B - 1.1))), z_plate, zs)
            bx(g, "DarkLog", *sorted((cx + s * A, cx + s * (A - 1.1))), cy - B + 1.1, cy + B - 1.1, z_plate, zs)
    # 마룻대(잘리지 않고 A > B 일 때)
    if cut is None and A - B > 0.5:
        bx(g, "DarkLog", cx - (A - B), cx + (A - B), cy - 0.55, cy + 0.55, zb(B) - 1.1, zb(B) - 0.1)
    elif cut is not None:   # 잘린 단 테두리 보(평평한 단을 받침)
        for s in (-1, 1):
            bx(g, "DarkLog", cx - A + d - 0.6, cx + A - d + 0.6, *sorted((cy + s * (B - d), cy + s * (B - d - 1.0))), zb(d) - 1.0, zb(d))
            bx(g, "DarkLog", *sorted((cx + s * (A - d), cx + s * (A - d - 1.0))), cy - B + d, cy + B - d, zb(d) - 1.0, zb(d))
    # 추녀(대각) — 모서리 처마 끝 → 마룻대 끝 / 잘린 단 모서리
    for sx in (-1, 1):
        for sy in (-1, 1):
            a = (cx + sx * (A + e), cy + sy * (B + e), zb(-e) + rh / 2)
            b = (cx + sx * (A - d), cy + sy * (B - d), zb(d) + rh / 2)
            member(g, "DarkLog", a, b, 0.7, rh * 1.1)
    # 서까래(긴 면 ±y: x 를 따라 / 박공 쪽 ±x: y 를 따라). 추녀에 닿는 짧은 서까래 포함
    gap = K.RAFTER_GAP

    def rafters(len_along, other, flip):
        n = max(2, int(round(2 * len_along / gap)))
        for k in range(n + 1):
            u = -len_along + 2 * len_along * k / n
            top = min(d, (other - abs(u)) if not flip else (other - abs(u)))
            if top < 0.3 - e:
                continue
            top = min(d, top)
            yield u, top
    for s in (-1, 1):
        for u, top in rafters(A + e - 0.3, A, False):        # ±y 면: u = x
            a = (cx + u, cy + s * (B + e), zb(-e) + rh / 2)
            b = (cx + u, cy + s * (B - top), zb(top) + rh / 2)
            member(g, "Timber", a, b, 0.55, rh)
        for u, top in rafters(B + e - 0.3, B, True):         # ±x 면: u = y
            a = (cx + s * (A + e), cy + u, zb(-e) + rh / 2)
            b = (cx + s * (A - top), cy + u, zb(top) + rh / 2)
            member(g, "Timber", a, b, 0.55, rh)
    # 면 판(개판 · 덮개 · 눈) — 네 면 사다리꼴/세모
    def zfun(x, y):
        i = min(A - abs(x - cx), B - abs(y - cy))
        return zb(i) + rh / cp
    faces = []
    for s in (-1, 1):
        faces.append([(cx - A - e, cy + s * (B + e)), (cx + A + e, cy + s * (B + e)), (cx + A - d, cy + s * (B - d)), (cx - A + d, cy + s * (B - d))])
        faces.append([(cx + s * (A + e), cy - B - e), (cx + s * (A + e), cy + B + e), (cx + s * (A - d), cy + B - d), (cx + s * (A - d), cy - B + d)])
    layers = (("Timber", 0.0, 0.35), (cover, 0.35, 0.4)) + ((("SnowCap", 0.75, SNOW_T),) if snow else ())
    for f in faces:
        for mat, off, th in layers:
            plane_slab(g, mat, f, zfun, off / cp, th / cp)
    # 처마 끝 막이판 + 눈 턱
    zt_e = zb(-e) + rh / cp
    for s in (-1, 1):
        bx(g, "Timber", cx - A - e - 0.15, cx + A + e + 0.15, *sorted((cy + s * (B + e), cy + s * (B + e + 0.3))), zt_e - 1.0, zt_e + 0.3)
        bx(g, "Timber", *sorted((cx + s * (A + e), cx + s * (A + e + 0.3))), cy - B - e - 0.15, cy + B + e + 0.15, zt_e - 1.0, zt_e + 0.3)
        if snow:
            bx(g, "SnowCap", cx - A - e - 0.3, cx + A + e + 0.3, *sorted((cy + s * (B + e - 0.1), cy + s * (B + e + 0.5))), zt_e + 0.3, zt_e + 0.75 + SNOW_T * 0.8)
            bx(g, "SnowCap", *sorted((cx + s * (A + e - 0.1), cx + s * (A + e + 0.5))), cy - B - e - 0.3, cy + B + e + 0.3, zt_e + 0.3, zt_e + 0.75 + SNOW_T * 0.8)
    # 추녀마루 눈(면 판 이음 덮개) · 용마루 눈
    zt = lambda i: zb(i) + (rh + 0.75 + SNOW_T) / cp       # noqa: E731
    if snow:
        for sx in (-1, 1):
            for sy in (-1, 1):
                member(g, "SnowCap", (cx + sx * (A + e), cy + sy * (B + e), zt(-e)), (cx + sx * (A - d), cy + sy * (B - d), zt(d)), 0.9, 0.5)
        if cut is None and A - B > 0.5:
            bx(g, "SnowCap", cx - (A - B) - 0.4, cx + (A - B) + 0.4, cy - 0.8, cy + 0.8, zt(B) - 0.3, zt(B) + 0.35)
    return zb(d), zb


# ------------------------------------------------------------------ 외쪽 지붕
def shed_roof(g, ax, u0, u1, p_hi, p_lo, z_hi, z_lo, eave=1.5, side_eave=0.8, snow=True):
    """
    외쪽 지붕: ax 축을 따라 u0..u1, 다른 축 p 가 p_hi(높은 쪽, 벽) → p_lo(낮은 쪽) 로 내려가며 서까래 밑선 z_hi → z_lo.
    낮은 쪽은 eave 만큼 더 내민다. 서까래(받침 위)·개판·덮개·눈·처마 눈 턱·막이판. 서까래 밑선 함수를 돌려준다
    """
    sgn = 1.0 if p_lo > p_hi else -1.0
    run = abs(p_lo - p_hi)
    slope = (z_hi - z_lo) / run
    pe = p_lo + sgn * eave
    rh = 0.7
    cp = math.cos(math.atan(slope))

    def zb_p(p):
        return z_hi - (p - p_hi) * sgn * slope

    def P(u, p, z):
        return (u, p, z) if ax == "x" else (p, u, z)
    n = max(2, int(round((u1 - u0 + 2 * side_eave) / K.RAFTER_GAP)))
    for k in range(n + 1):
        u = u0 - side_eave + 0.3 + (u1 - u0 + 2 * side_eave - 0.6) * k / n
        member(g, "Timber", P(u, p_hi, zb_p(p_hi) + rh / 2), P(u, pe, zb_p(pe) + rh / 2), 0.5, rh)

    def zf(x, y):
        p = y if ax == "x" else x
        return zb_p(p) + rh / cp
    ua, ub = u0 - side_eave, u1 + side_eave
    pts = [P(ua, p_hi, 0)[:2], P(ub, p_hi, 0)[:2], P(ub, pe, 0)[:2], P(ua, pe, 0)[:2]]
    if (pts[1][0] - pts[0][0]) * (pts[2][1] - pts[1][1]) - (pts[1][1] - pts[0][1]) * (pts[2][0] - pts[1][0]) < 0:
        pts.reverse()
    layers = (("Timber", 0.0, 0.3), ("RoofMetal", 0.3, 0.35)) + ((("SnowCap", 0.65, SNOW_T * 0.8),) if snow else ())
    for mat, off, th in layers:
        plane_slab(g, mat, pts, zf, off / cp, th / cp)
    ze = zb_p(pe) + rh / cp
    pa, pb = sorted((pe, pe + sgn * 0.3))
    if ax == "x":
        bx(g, "Timber", ua, ub, pa, pb, ze - 0.9, ze + 0.3)
    else:
        bx(g, "Timber", pa, pb, ua, ub, ze - 0.9, ze + 0.3)
    if snow:
        pa, pb = sorted((pe - sgn * 0.1, pe + sgn * 0.45))
        if ax == "x":
            bx(g, "SnowCap", ua - 0.1, ub + 0.1, pa, pb, ze + 0.3, ze + 0.65 + SNOW_T * 0.6)
        else:
            bx(g, "SnowCap", pa, pb, ua - 0.1, ub + 0.1, ze + 0.3, ze + 0.65 + SNOW_T * 0.6)
    return zb_p


# ------------------------------------------------------------------ 난간
def railing(g, ax, c, u0, u1, z0, h=3.4, coll=True):
    """기둥 사이 난간: 아랫대(0.4 띄움) · 손잡이(윗대) · 세로 살(0.9 간격, 굵기 0.22). 양 끝은 기둥 면에 닿게 u0·u1 을 준다"""
    def B(mat, a, b, za, zb_, t):
        if ax == "x":
            bx(g, mat, a, b, c - t / 2, c + t / 2, za, zb_)
        else:
            bx(g, mat, c - t / 2, c + t / 2, a, b, za, zb_)
    B("DarkLog", u0, u1, z0 + 0.4, z0 + 0.75, 0.45)
    B("DarkLog", u0, u1, z0 + h - 0.35, z0 + h, 0.55)
    n = max(1, int((u1 - u0) / 0.9))
    for k in range(1, n):
        u = u0 + (u1 - u0) * k / n
        B("Timber", u - 0.11, u + 0.11, z0 + 0.75, z0 + h - 0.35, 0.22)
    if coll:
        if ax == "x":
            cbox(u0, u1, c - 0.3, c + 0.3, z0, z0 + h)
        else:
            cbox(c - 0.3, c + 0.3, u0, u1, z0, z0 + h)


# ------------------------------------------------------------------ 은행 부품
def barred_window(g, ax, c, u, z0, face, w=K.WIN_W, h=K.WIN_H, t=K.LOG):
    """쇠살 창: 흰 틀 창(덧창 없음) + 바깥 쇠살 4줄 + 가로 띠 둘(벽에 박음)"""
    K.window(g, ax, c, u, z0, w=w, h=h, face=face, shutters=False)
    off = c + face * (t / 2 + 0.15)
    for k in range(4):
        uu = u - w / 2 + w * (k + 0.5) / 4
        if ax == "x":
            bx(g, "Iron", uu - 0.08, uu + 0.08, off - 0.08, off + 0.08, z0 + 0.05, z0 + h + 0.25)
        else:
            bx(g, "Iron", off - 0.08, off + 0.08, uu - 0.08, uu + 0.08, z0 + 0.05, z0 + h + 0.25)
    for zz in (z0 + h * 0.3, z0 + h * 0.75):
        if ax == "x":
            bx(g, "Iron", u - w / 2 - 0.2, u + w / 2 + 0.2, off - 0.1, off + 0.1, zz - 0.1, zz + 0.1)
        else:
            bx(g, "Iron", off - 0.1, off + 0.1, u - w / 2 - 0.2, u + w / 2 + 0.2, zz - 0.1, zz + 0.1)


def grille(g, x0, x1, y, z0, z1, gaps=()):
    """카운터 상판(z0) 위 쇠살 칸막이: 양 끝 짙은 나무 기둥(상판 위) · 윗 테(놋쇠) · 세로 쇠살 0.6 간격 · 창구 구멍(위 놋쇠 아치 띠, 아래 비움)"""
    for xx in (x0, x1):
        bx(g, "DarkLog", xx - 0.3, xx + 0.3, y - 0.3, y + 0.3, z0, z1 + 0.3)
    bx(g, "Brass", x0, x1, y - 0.18, y + 0.18, z1 - 0.2, z1 + 0.15)
    bx(g, "DarkLog", x0, x1, y - 0.25, y + 0.25, z1 + 0.15, z1 + 0.5)
    zg = z0 + 2.4          # 창구 구멍 윗선
    for a, b in gaps:
        bx(g, "Brass", a, b, y - 0.15, y + 0.15, zg, zg + 0.25)
        bx(g, "Wood", a, b, y - 0.6, y + 0.6, z0, z0 + 0.12)           # 창구 받침 판(돈 놓는 곳)
    n = int((x1 - x0) / 0.6)
    for k in range(1, n):
        xx = x0 + (x1 - x0) * k / n
        za = zg + 0.25 if any(a - 0.05 < xx < b + 0.05 for a, b in gaps) else z0
        bx(g, "Iron", xx - 0.06, xx + 0.06, y - 0.06, y + 0.06, za, z1 - 0.2)
    cbox(x0 - 0.3, x1 + 0.3, y - 0.3, y + 0.3, z0, z1 + 0.5)


def vault_door(g, x, y, z0, r=3.2, face=-1):
    """
    닫힌 금고문(뒷벽 안쪽 면 y 에 붙음, face = 방 쪽 부호): 돌 문틀(네모 두꺼운 테) → 쇠 원판(두 겹) → 둘레 빗장 8 · 바퀴 손잡이(살 넷) ·
    가운데 놋쇠 다이얼 · 왼 경첩 통 둘. 돌려주는 값 = (가운데 x, y, z, 지름) — 퀘스트로 열 때 Studio 가 쓴다
    """
    zc = z0 + r + 0.4
    f = face

    def Y(d):
        return y + f * d
    # 돌 문틀(벽 면 위에 덧쌓은 테)
    for a, b, za, zb_ in ((x - r - 1.4, x - r - 0.2, z0, zc + r + 1.4), (x + r + 0.2, x + r + 1.4, z0, zc + r + 1.4),
                          (x - r - 1.4, x + r + 1.4, zc + r + 0.2, zc + r + 1.4)):
        bx(g, "StoneTrim", a, b, *sorted((Y(0), Y(0.9))), za, zb_)
    bx(g, "DarkStone", x - r - 0.2, x + r + 0.2, *sorted((Y(0), Y(0.25))), z0, zc + r + 0.2)      # 문 뒤 어둠(막힌 벽)
    g["Iron"].hcyl(x, Y(0.55), zc, r, 0.6, axis="y", seg=28)
    g["IronLight"].hcyl(x, Y(0.95), zc, r * 0.82, 0.3, axis="y", seg=28)
    g["Brass"].hcyl(x, Y(0.88), zc, r + 0.12, 0.14, axis="y", seg=28)
    for k in range(8):                     # 빗장 머리(둘레 쇠 덩이)
        a = 2 * math.pi * (k + 0.5) / 8
        g["Steel"].obox(x + (r - 0.35) * math.cos(a), Y(1.0), zc + (r - 0.35) * math.sin(a), 0.7, 0.3, 0.35, ry=-a)
    # 바퀴 손잡이: 축 · 테 · 살 넷
    g["Brass"].hcyl(x, Y(1.4), zc, 0.35, 0.8, axis="y", seg=10)
    g["Iron"].hcyl(x, Y(1.75), zc, 1.6, 0.2, axis="y", seg=20)
    g["Iron"].hcyl(x, Y(1.8), zc, 1.25, 0.25, axis="y", seg=20)       # 안쪽 테(링처럼 보이게 겹친 두 원판 대신 바퀴살 위)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        g["Brass"].obox(x + 0.75 * math.cos(a), Y(1.9), zc + 0.75 * math.sin(a), 1.5, 0.18, 0.2, ry=-a)
    g["Brass"].hcyl(x, Y(2.0), zc, 0.45, 0.2, axis="y", seg=12)
    # 경첩 통(왼쪽)
    for dz in (-r * 0.55, r * 0.55):
        g["Iron"].cyl(x - r - 0.05, Y(0.9), zc + dz - 0.7, 0.35, 0.35, 1.4, seg=10)
    # 다이얼(오른 위)
    g["Brass"].hcyl(x + r * 0.5, Y(1.15), zc + r * 0.45, 0.4, 0.15, axis="y", seg=14)
    cbox(x - r - 1.4, x + r + 1.4, *sorted((Y(0), Y(2.1))), z0, zc + r + 1.4)
    return (x, Y(0.9), zc, 2 * r)


# ------------------------------------------------------------------ 시계판
def clock_face(g, ax, c, u, zc, r, face):
    """
    벽 바깥면(ax 벽 축, c = 바깥면 자리, u = 가운데, zc 높이)에 시계판: 네모 뒷판(DarkLog) · 놋쇠 테 · 흰 판(Dial) ·
    눈금 12(3·6·9·12 는 길게) · 고정 바늘(시 10:10) · 놋쇠 축. 돌려주는 값 = (x, y, z) 판 가운데(바늘 달 자리)
    """
    f = face
    axis = "y" if ax == "x" else "x"

    def P(du, dn, dz):
        """du = 벽 따라, dn = 바깥으로, dz = 위"""
        if ax == "x":
            return u + du, c + f * dn, zc + dz
        return c + f * dn, u + du, zc + dz

    hs = -f if ax == "x" else f            # 보는 사람 오른쪽 = +du 가 되게(시계 방향)

    def ob(mat, a, rr, dn, su, sn, sz):
        """판 위 각 a(12시 = 0, 시계 방향) · 반지름 rr 자리에 바깥을 향해 놓인 막대(길이 sz 가 반지름 방향)"""
        a = hs * a
        x, y, z = P(rr * math.sin(a), dn, rr * math.cos(a))
        if ax == "x":
            g[mat].obox(x, y, z, su, sn, sz, ry=a)
        else:
            g[mat].obox(x, y, z, sn, su, sz, rx=-a)
    s = r + 0.9
    if ax == "x":
        bx(g, "DarkLog", u - s, u + s, *sorted((c, c + f * 0.4)), zc - s, zc + s)
    else:
        bx(g, "DarkLog", *sorted((c, c + f * 0.4)), u - s, u + s, zc - s, zc + s)
    g["Brass"].hcyl(*P(0, 0.55, 0), r + 0.35, 0.4, axis=axis, seg=32)
    g["Dial"].hcyl(*P(0, 0.8, 0), r - 0.1, 0.2, axis=axis, seg=32)
    for k in range(12):
        a = 2 * math.pi * k / 12
        L_ = 1.0 if k % 3 == 0 else 0.55
        ob("Iron", a, r - 0.4 - L_ / 2, 0.95, 0.22, 0.1, L_)
    # 고정 바늘: 시침(10시) · 분침(2시)
    for a, Ln, w in ((-math.pi / 3, r * 0.5, 0.35), (math.pi / 3, r * 0.78, 0.22)):
        ob("Iron", a, Ln / 2, 1.1, w, 0.12, Ln)
    g["Brass"].hcyl(*P(0, 1.15, 0), 0.4, 0.3, axis=axis, seg=12)
    return P(0, 1.15, 0)
