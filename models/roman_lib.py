# -*- coding: utf-8 -*-
"""
roman_lib.py — 칼로도르 폴리스(화산섬 로마풍 제국 도시) 건축 부품. (2026-09-28)

hanok_lib 의 Group(재질 하나 = 오브젝트 하나)에 로마 건축 부재를 얹는다.
단위는 스터드(캐릭터 키 5). 원점은 바닥 가운데, 앞은 -y, 위는 +z.

사람 치수(이 표를 벗어나지 않는다)
  문 높이 9, 폭 5~7 · 한 층 13 · 벽 두께 1.6(집) / 3(신전 벽) / 5(성벽)
  기둥: 집 반지름 0.9 · 주랑 1.3 · 신전 2.1 · 궁 2.4
"""
import math

import bmesh
from mathutils import Matrix, Vector

import hanok_lib as L

PALETTE = {
    # 2026-09-29 폐허: 그을리고 바랜 칙칙한 빛으로 모두 낮췄다(원래 값은 backup/2026-09-29_motions_original 아님 — 이 파일 기록 참고)
    "Marble": "#A7A194",       # 흰 대리석(따뜻한 빛)
    "MarbleWall": "#9C9588",   # 벽·기단용 대리석(기둥과 메시를 나눠 삼각형 한도를 지킨다)
    "MarbleDark": "#7C766B",   # 비바람에 바랜 대리석
    "Travertine": "#9A907B",   # 트래버틴(원형 투기장·수도교)
    "Plaster": "#9E9381",      # 흰 회벽
    "PlasterOchre": "#896E57", # 황토 회벽
    "PlasterRed": "#684036",   # 폼페이 붉은 회벽
    "Brick": "#6C493B",        # 로마 벽돌
    "Tile": "#684436",         # 기와(ClayRoofTiles)
    "Basalt": "#2F2B2D",       # 현무암(길·기단·성벽 밑)
    "BasaltLight": "#4A4543",  # 바랜 현무암
    "Porphyry": "#4C2A2B",     # 붉은 반암 — 황제의 돌
    "Bronze": "#5C4A30",       # 청동
    "Verdigris": "#3F6258",    # 녹슨 청동
    "Gold": "#7A6440",         # 금박
    "Wood": "#3E3128",
    "Iron": "#333235",
    "Lava": "#FF5A1E",         # 용암(네온)
    "Rune": "#FFB347",         # 봉인 문자(네온)
    "Fabric": "#5A2A26",       # 붉은 천(깃발·차양)
    "HotWater": "#4A7C76",     # 온천물
    "Glow": "#FFB05A",         # 창·문 불빛
    "Garden": "#5A5A3A",       # 안뜰 풀밭
    "Sand": "#8A7E66",         # 투기장 모래
    "Terracotta": "#7A5040",   # 항아리
    "Vent": "#FFFFFF",         # 김·불 나오는 자리(투명)
    "LampPt": "#FFFFFF",       # 점광원 자리(투명)
}

TAU = math.pi * 2


def G(prefix):
    return L.new_groups(prefix, PALETTE)


# ---------------------------------------------------------------- 도형

def sphere(g, cx, cy, cz, r, seg=12, rings=8, sz=None):
    """구(또는 sz 로 찌그린 타원체)."""
    sz = r if sz is None else sz
    bmesh.ops.create_uvsphere(
        g.bm, u_segments=seg, v_segments=rings, radius=1.0,
        matrix=Matrix.Translation((cx, cy, cz)) @ Matrix.Diagonal((r, r, sz, 1.0)),
    )


def seg_cyl(g, a, b, r0, r1=None, seg=10):
    """점 a 에서 b 로 가는 원통(끝 반지름 r0→r1). 팔다리·사슬 고리에 쓴다."""
    r1 = r0 if r1 is None else r1
    a, b = Vector(a), Vector(b)
    d = b - a
    h = d.length
    if h < 1e-4:
        return
    q = d.normalized().to_track_quat("Z", "Y")
    m = Matrix.Translation(a) @ q.to_matrix().to_4x4() @ Matrix.Translation((0, 0, h / 2))
    bmesh.ops.create_cone(g.bm, cap_ends=True, cap_tris=False, segments=seg,
                          radius1=r0, radius2=r1, depth=h, matrix=m)


def seg_box(g, a, b, w, t, up=(0, 0, 1)):
    """점 a→b 를 잇는 각진 막대(폭 w, 두께 t)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    h = d.length
    if h < 1e-4:
        return
    z = d.normalized()
    u = Vector(up)
    x = u.cross(z)
    if x.length < 1e-4:
        x = Vector((1, 0, 0)).cross(z)
    x.normalize()
    y = z.cross(x)
    rot = Matrix((x, y, z)).transposed().to_4x4()
    m = Matrix.Translation((a + b) / 2) @ rot @ Matrix.Diagonal((w, t, h, 1.0))
    bmesh.ops.create_cube(g.bm, size=1.0, matrix=m)


def prism(g, pts2d, z0, z1, axis="y", at=0.0):
    """단면 다각형(pts2d)을 밀어 만든 기둥꼴. axis='y' 면 단면이 x-z 평면에 있고 y 로 [at-z0.. ] 가 아니라
    y 범위 [z0, z1] 로 민다. axis='z' 면 단면이 x-y 이고 z 범위 [z0, z1]."""
    n = len(pts2d)
    verts = []
    for dep in (z0, z1):
        for (u, v) in pts2d:
            if axis == "y":
                verts.append((u, dep, v))
            elif axis == "x":
                verts.append((dep, u, v))
            else:
                verts.append((u, v, dep))
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    g.add_mesh(verts, faces)


def ring_band(g, cx, cy, z, r0, r1, t, seg=24, a0=0.0, a1=TAU):
    """납작한 고리(바닥 문자 고리·기둥 띠)."""
    full = abs(a1 - a0 - TAU) < 1e-6
    n = seg
    verts, faces = [], []
    steps = n if full else n
    for i in range(steps + (0 if full else 1)):
        a = a0 + (a1 - a0) * i / n
        c, s = math.cos(a), math.sin(a)
        for r in (r0, r1):
            for zz in (z, z + t):
                verts.append((cx + r * c, cy + r * s, zz))
    count = len(verts) // 4
    for i in range(count if full else count - 1):
        j = (i + 1) % count
        a = [i * 4 + k for k in range(4)]
        b = [j * 4 + k for k in range(4)]
        # 0: r0 아래, 1: r0 위, 2: r1 아래, 3: r1 위
        faces += [[a[1], a[3], b[3], b[1]], [a[0], b[0], b[2], a[2]],
                  [a[2], b[2], b[3], a[3]], [a[0], a[1], b[1], b[0]]]
    g.add_mesh(verts, faces)


# ---------------------------------------------------------------- 건축 부재

def column(g, x, y, z0, h, r, order="tuscan", shaft="Marble", cap=None, base=True, flutes=False):
    """기둥 하나. 주초·배흘림 기둥몸·주두. 돌려주는 값은 주두 윗면 높이."""
    cap = cap or shaft
    z = z0
    if base:
        g[shaft].box(x, y, z + 0.18 * r, 2.5 * r, 2.5 * r, 0.36 * r)   # 주춧돌(plinth)
        g[shaft].cyl(x, y, z + 0.36 * r, 1.22 * r, 1.12 * r, 0.3 * r, seg=16)  # 토루스 대신 둥근 턱
        z += 0.66 * r
    top = z0 + h
    ch = {"tuscan": 0.9, "doric": 0.9, "ionic": 1.1, "corinthian": 1.9}[order] * r
    g[shaft].cyl(x, y, z, r, 0.86 * r, top - ch - z, seg=12)
    if flutes:
        for k in range(6):
            a = TAU * (k + 0.5) / 6
            g[shaft].obox(x + 0.93 * r * math.cos(a), y + 0.93 * r * math.sin(a), (z + top - ch) / 2,
                          0.16 * r, 0.16 * r, top - ch - z - 0.4, rz=a)
    zc = top - ch
    if order in ("tuscan", "doric"):
        g[cap].cyl(x, y, zc, 0.9 * r, 1.18 * r, 0.5 * ch, seg=16)       # 에키누스
        g[cap].box(x, y, zc + 0.75 * ch, 2.5 * r, 2.5 * r, 0.5 * ch)   # 아바쿠스
    elif order == "ionic":
        g[cap].cyl(x, y, zc, 0.9 * r, 1.05 * r, 0.4 * ch, seg=16)
        g[cap].box(x, y, zc + 0.55 * ch, 2.2 * r, 1.4 * r, 0.3 * ch)
        for s in (-1, 1):   # 소용돌이
            g[cap].hcyl(x + s * 1.05 * r, y, zc + 0.45 * ch, 0.42 * r, 1.5 * r, axis="y", seg=10)
        g[cap].box(x, y, zc + 0.85 * ch, 2.4 * r, 2.4 * r, 0.3 * ch)
    else:  # corinthian: 종 모양 + 아칸서스 잎 두 단 + 아바쿠스
        g[cap].cyl(x, y, zc, 0.88 * r, 1.25 * r, 0.8 * ch, seg=16)
        for tier, (hh, rr) in enumerate(((0.35, 1.02), (0.62, 1.12))):
            for k in range(8):
                a = TAU * (k + 0.5 * tier) / 8
                g[cap].obox(x + rr * r * math.cos(a), y + rr * r * math.sin(a), zc + hh * ch,
                            0.42 * r, 0.22 * r, 0.42 * ch, rz=a + math.pi / 2, rx=0.25)
        g[cap].box(x, y, zc + 0.9 * ch, 2.6 * r, 2.6 * r, 0.2 * ch)
    return top


def colonnade(g, xs, ys, z0, h, r, order="tuscan", shaft="Marble", cap=None, flutes=False):
    for x in xs:
        for y in ys:
            column(g, x, y, z0, h, r, order, shaft, cap, flutes=flutes)


def entablature(g, x0, x1, y0, y1, z, h, mat="Marble", frieze=None, cornice=True):
    """들보(아키트레이브)·프리즈·코니스 세 켜. 돌려주는 값은 윗면 높이."""
    frieze = frieze or mat
    cx, cy, w, d = (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0
    a = 0.42 * h
    g[mat].box(cx, cy, z + a / 2, w, d, a)
    g[mat].box(cx, cy, z + a * 0.9, w + 0.3, d + 0.3, a * 0.2)
    f = 0.36 * h
    g[frieze].box(cx, cy, z + a + f / 2, w - 0.1, d - 0.1, f)
    if cornice:
        c = h - a - f
        g[mat].box(cx, cy, z + a + f + c * 0.35, w + 0.9, d + 0.9, c * 0.7)
        g[mat].box(cx, cy, z + a + f + c * 0.85, w + 1.5, d + 1.5, c * 0.3)
    return z + h


def pediment(g, cx, y0, y1, z, W, H, mat="Marble", tympanum=None, inset=0.6):
    """앞(y0)뒤(y1)로 두께를 가진 삼각 박공. 테두리 코니스를 따로 두른다."""
    tympanum = tympanum or mat
    half = W / 2
    prism(g[tympanum], [(cx - half + inset, z), (cx + half - inset, z), (cx, z + H - inset * 0.6)], y0 + 0.5, y1)
    ang = math.atan2(H, half)
    L_ = math.hypot(half, H) + 0.8
    for s in (-1, 1):
        g[mat].obox(cx + s * half / 2, (y0 + y1) / 2 - 0.2, z + H / 2 + 0.15, L_, y1 - y0 + 0.8, 0.7,
                    ry=s * ang)
    g[mat].box(cx, (y0 + y1) / 2 - 0.2, z + 0.25, W + 0.8, y1 - y0 + 0.8, 0.5)


def gable_roof(g, cx, cy, z0, W, D, H, along="y", over=1.2, thick=0.8, mat="Tile", end_mat=None):
    """박공지붕. along 방향이 용마루. 끝 박공은 end_mat(없으면 막지 않음)."""
    if along == "y":
        half = W / 2
        ang = math.atan2(H, half)
        L_ = math.hypot(half, H) + over
        for s in (-1, 1):
            g[mat].obox(cx + s * half / 2, cy, z0 + H / 2 + thick / 2, L_, D + 2 * over, thick, ry=s * ang)
        g[mat].box(cx, cy, z0 + H + thick * 0.6, 0.9, D + 2 * over, 0.7)
        if end_mat:
            for yy in (cy - D / 2, cy + D / 2):
                prism(g[end_mat], [(cx - half, z0), (cx + half, z0), (cx, z0 + H)], yy - 0.4, yy + 0.4)
    else:
        half = D / 2
        ang = math.atan2(H, half)
        L_ = math.hypot(half, H) + over
        for s in (-1, 1):
            g[mat].obox(cx, cy + s * half / 2, z0 + H / 2 + thick / 2, W + 2 * over, L_, thick, rx=-s * ang)
        g[mat].box(cx, cy, z0 + H + thick * 0.6, W + 2 * over, 0.9, 0.7)
        if end_mat:
            for xx in (cx - W / 2, cx + W / 2):
                prism(g[end_mat], [(cy - half, z0), (cy + half, z0), (cy, z0 + H)], xx - 0.4, xx + 0.4, axis="x")


def hip_roof(g, cx, cy, z0, W, D, H, mat="Tile", over=1.0):
    """모임지붕(인술라). 네 경사면을 삼각·사다리꼴 면으로 붙인다."""
    x0, x1, y0, y1 = cx - W / 2 - over, cx + W / 2 + over, cy - D / 2 - over, cy + D / 2 + over
    r = min(W, D) / 2 + over
    if W >= D:
        a, b = (cx - (W - D) / 2, cy, z0 + H), (cx + (W - D) / 2, cy, z0 + H)
    else:
        a, b = (cx, cy - (D - W) / 2, z0 + H), (cx, cy + (D - W) / 2, z0 + H)
    t = 0.7
    base = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)]
    top = [a, b]
    verts = base + top + [(v[0], v[1], v[2] + t) for v in base] + [(v[0], v[1], v[2] + t) for v in top]
    if W >= D:
        faces = [[0, 1, 5, 4], [1, 2, 5], [2, 3, 4, 5], [3, 0, 4]]
    else:
        faces = [[0, 1, 4], [1, 2, 5, 4], [2, 3, 5], [3, 0, 4, 5]]
    rim = [[0, 1, 7, 6], [1, 2, 8, 7], [2, 3, 9, 8], [3, 0, 6, 9]]
    g[mat].add_mesh(verts, [f[::-1] for f in faces] + [[i + 6 for i in f] for f in faces] + rim)


def arch(g, cx, cy, z_spring, span, depth, t=None, mat="Travertine", key=None, n=11, axis="x"):
    """반원 아치의 홍예돌. span 은 안쪽 폭, t 는 홍예 두께. axis 'x' 면 아치가 x 로 벌어지고 y 로 두께."""
    t = t or max(1.0, span * 0.14)
    r0 = span / 2
    for i in range(n):
        a0 = math.pi * i / n
        a1 = math.pi * (i + 1) / n
        am = (a0 + a1) / 2
        rm = r0 + t / 2
        w = 2 * (r0 + t) * math.sin((a1 - a0) / 2) + 0.05
        u, v = rm * math.cos(am), rm * math.sin(am)
        m = key if (key and i == n // 2) else mat
        if axis == "x":
            g[m].obox(cx + u, cy, z_spring + v, w, depth, t, ry=-(am - math.pi / 2))
        else:
            g[m].obox(cx, cy + u, z_spring + v, depth, w, t, rx=(am - math.pi / 2))


def arch_wall(g, cx, cy, z0, W, H, depth, span, spring, mat="Travertine", axis="x", arch_mat=None, key=None):
    """폭 W·높이 H 벽에 가운데 아치 구멍 하나(너비 span, 홍예 시작 높이 spring)."""
    arch_mat = arch_mat or mat
    side = (W - span) / 2
    # 스팬드럴 채움은 홍예돌 띠 한가운데(r + t/2)에서 시작한다 — 홍예 안쪽 면과 겹쳐 깜빡이지 않게
    r = span / 2 + max(1.0, span * 0.14) / 2
    if axis == "x":
        for s in (-1, 1):
            g[mat].box(cx + s * (span / 2 + side / 2), cy, z0 + H / 2, side, depth, H)
        top_z = z0 + spring + r
        if H > spring:
            # 아치 위 채움: 스팬드럴을 층층 상자로
            steps = 6
            for s in (-1, 1):
                for k in range(steps):
                    a0 = math.pi / 2 * k / steps
                    a1 = math.pi / 2 * (k + 1) / steps
                    xa = r * math.cos(a1)
                    xb = r * math.cos(a0)
                    zb = z0 + spring + r * math.sin(a1)
                    g[mat].box(cx + s * (xa + xb) / 2, cy, (zb + z0 + H) / 2, xb - xa + 0.05, depth, z0 + H - zb)
            if top_z < z0 + H:
                g[mat].box(cx, cy, (top_z + z0 + H) / 2, 2 * r * math.cos(math.pi / 2 * (steps - 1) / steps) + 0.1,
                           depth, z0 + H - top_z)
        arch(g, cx, cy - 0.01, z0 + spring, span, depth + 0.3, mat=arch_mat, key=key)
    else:
        for s in (-1, 1):
            g[mat].box(cx, cy + s * (span / 2 + side / 2), z0 + H / 2, depth, side, H)
        steps = 6
        for s in (-1, 1):
            for k in range(steps):
                a0 = math.pi / 2 * k / steps
                a1 = math.pi / 2 * (k + 1) / steps
                ya = r * math.cos(a1)
                yb = r * math.cos(a0)
                zb = z0 + spring + r * math.sin(a1)
                g[mat].box(cx, cy + s * (ya + yb) / 2, (zb + z0 + H) / 2, depth, yb - ya + 0.05, z0 + H - zb)
        arch(g, cx - 0.01, cy, z0 + spring, span, depth + 0.3, mat=arch_mat, key=key, axis="y")


def dome(g, cx, cy, z0, r, mat="Plaster", rings=9, seg=24, oculus=0.0, drum=0.0, drum_mat=None):
    """반구 돔(층층 원뿔대). drum 이 있으면 그 높이의 원통 위에 얹는다. 돌려주는 값은 꼭대기 높이."""
    if drum > 0:
        g[drum_mat or mat].cyl(cx, cy, z0, r + 0.4, r + 0.4, drum, seg=seg)
        z0 += drum
    for i in range(rings):
        a0 = math.pi / 2 * i / rings
        a1 = math.pi / 2 * (i + 1) / rings
        r0, r1 = r * math.cos(a0), r * math.cos(a1)
        if oculus and r1 < oculus:
            r1 = oculus
        z_a, z_b = z0 + r * math.sin(a0), z0 + r * math.sin(a1)
        g[mat].cyl(cx, cy, z_a, r0, max(r1, 0.05), z_b - z_a, seg=seg)
        if oculus and r1 <= oculus:
            break
    return z0 + r


def stairs(g, cx, y_front, z_top, width, steps, tread=1.3, mat="Marble", face=-1, z_bottom=0.0):
    """y_front 에서 face 쪽(-1 이면 -y)으로 내려가는 계단. z_bottom 에서 z_top 까지."""
    rise = (z_top - z_bottom) / steps
    for i in range(steps):
        d = (steps - i) * tread
        h = rise * (i + 1)
        g[mat].box(cx, y_front + face * d / 2, z_bottom + h / 2, width, d, h)


def wall_with_openings(g, x0, x1, y, z0, H, t, openings, mat="Plaster", axis="x", glow=None, frame=None):
    """x0..x1 (axis='x') 를 따라 선 벽. openings = [(가운데, 폭, 밑높이, 윗높이)]. 구멍 속에 불빛 판."""
    cuts = sorted(openings)
    pos = x0
    for (c, w, lo, hi) in cuts:
        a, b = c - w / 2, c + w / 2
        if a > pos:
            _wall_piece(g, mat, pos, a, y, z0, z0 + H, t, axis)
        if lo > 0:
            _wall_piece(g, mat, a, b, y, z0, z0 + lo, t, axis)
        if hi < H:
            _wall_piece(g, mat, a, b, y, z0 + hi, z0 + H, t, axis)
        if glow:
            _wall_piece(g, glow, a, b, y, z0 + lo, z0 + hi, t * 0.3, axis)
        if frame:
            _wall_piece(g, frame, a - 0.35, b + 0.35, y - 0.0, z0 + hi, z0 + hi + 0.45, t + 0.4, axis)
            if lo > 0:
                _wall_piece(g, frame, a - 0.35, b + 0.35, y, z0 + lo - 0.35, z0 + lo, t + 0.5, axis)
        pos = b
    if pos < x1:
        _wall_piece(g, mat, pos, x1, y, z0, z0 + H, t, axis)


def _wall_piece(g, mat, a, b, y, z_lo, z_hi, t, axis):
    if b - a <= 0 or z_hi - z_lo <= 0:
        return
    if axis == "x":
        g[mat].box((a + b) / 2, y, (z_lo + z_hi) / 2, b - a, t, z_hi - z_lo)
    else:
        g[mat].box(y, (a + b) / 2, (z_lo + z_hi) / 2, t, b - a, z_hi - z_lo)


def podium(g, cx, cy, W, D, h, mat="Marble", mould="MarbleDark"):
    """신전 기단(포디움). 아래 몰딩과 위 몰딩."""
    g[mat].box(cx, cy, h / 2, W, D, h)
    g[mould].box(cx, cy, 0.4, W + 1.0, D + 1.0, 0.8)
    g[mould].box(cx, cy, h - 0.3, W + 0.7, D + 0.7, 0.6)
    return h


# ---------------------------------------------------------------- 사람 꼴(석상·거인)

def figure(g, mat, s=1.0, pose="stand", robe=None, x=0.0, y=0.0, z=0.0, face=-1, arm_raise=0.0, stride=0.0,
           head_mat=None, crack=None, seg=6, cloak=None):
    """
    사람 꼴 석상. 키 = 8*s (발바닥 z → 정수리). pose: stand(콘트라포스토) | step(한 발 앞).
    face=-1 이면 -y 를 본다(앞 = f 방향). arm_raise(0~1) 는 오른팔을 드는 정도.
    몸은 덩어리(갈비 우리·배·골반·엉덩이·어깨·팔뚝·허벅지·장딴지)를 타원체로 붙여 근육 윤곽을 낸다.
    robe: 토가(발목까지 퍼지는 치마 + 주름 + 어깨에서 비스듬히 두른 자락). cloak: 왼어깨에 걸쳐 등 뒤로 늘어진 망토.
    돌려주는 값 {"lh","rh","head","chest"}.
    """
    hm = head_mat or mat
    f = face
    out = {}

    def Q(px, fwd, pz):
        # fwd 는 "앞으로" 양. 앞 = f 방향(-1 이면 -y)
        return (x + px * s, y + fwd * s * f, z + pz * s)

    def E(c, rx, ry, rz, m=None):
        _ell(g[m or mat], c, rx * s, ry * s, rz * s, seg)

    # ---- 다리 (오른쪽 = +x). contrapposto: 오른다리에 무게, 왼다리 살짝 굽혀 앞으로
    for side in (-1, 1):
        fwd = (stride if pose == "step" else 0.18) * (1 if side < 0 else -0.3)
        hip = Q(side * 0.5, 0.0, 4.1)
        knee = Q(side * 0.55, fwd * 0.55 + 0.08, 2.15)
        ankle = Q(side * 0.52, fwd, 0.45)
        seg_cyl(g[mat], hip, knee, 0.56 * s, 0.34 * s, seg=seg)
        E(Q(side * 0.54, 0.1 + fwd * 0.25, 3.25), 0.44, 0.5, 0.95)                  # 넓적다리 앞근육
        E(knee, 0.4, 0.4, 0.4)
        seg_cyl(g[mat], knee, ankle, 0.4 * s, 0.24 * s, seg=seg)
        E(Q(side * 0.53, fwd * 0.75 - 0.12, 1.55), 0.36, 0.42, 0.62)               # 장딴지
        E(Q(side * 0.52, fwd + 0.28, 0.18), 0.3, 0.62, 0.2)                          # 발
    # ---- 몸통
    E(Q(0, -0.08, 4.25), 0.86, 0.6, 0.58)                                            # 골반
    E(Q(0, -0.36, 4.0), 0.8, 0.48, 0.52)                                             # 엉덩이
    E(Q(0, 0.02, 4.95), 0.64, 0.5, 0.72)                                             # 배(허리는 좁게)
    E(Q(0, 0.05, 5.98), 1.14, 0.7, 0.88)                                             # 갈비 우리(넓은 가슴)
    for side in (-1, 1):
        E(Q(side * 0.52, 0.36, 6.12), 0.5, 0.32, 0.38)                              # 가슴근
        E(Q(side * 1.22, 0.0, 6.55), 0.5, 0.46, 0.48)                               # 어깨(삼각근)
        E(Q(side * 0.55, -0.1, 6.75), 0.55, 0.4, 0.3)                               # 승모근
    seg_cyl(g[mat], Q(0, 0.0, 6.65), Q(0, 0.06, 7.05), 0.36 * s, 0.32 * s, seg=seg)  # 목
    out["chest"] = Q(0, 0.05, 5.95)
    # ---- 머리
    head = Q(0, 0.1, 7.45)
    E(head, 0.36, 0.4, 0.46, hm)
    E(Q(0, 0.3, 7.22), 0.24, 0.2, 0.18, hm)                                          # 턱
    g[hm].box(*Q(0, 0.46, 7.43), 0.1 * s, 0.14 * s, 0.22 * s)                       # 코
    g[hm].box(*Q(0, 0.4, 7.58), 0.5 * s, 0.1 * s, 0.07 * s)                          # 눈두덩
    E(Q(0, -0.06, 7.62), 0.39, 0.42, 0.34, hm)                                       # 머리칼(곱슬 덩어리)
    out["head"] = head
    # ---- 팔(오른팔을 든다)
    for side in (-1, 1):
        rz = arm_raise if side > 0 else 0.0
        sh = Q(side * 1.3, 0.0, 6.45)
        el = Q(side * (1.32 + 0.25 * rz), 0.12 + 0.35 * rz, 5.25 + 1.9 * rz)
        ha = Q(side * (1.38 + 0.15 * rz), 0.3 + 0.55 * rz, 4.2 + 3.9 * rz)
        seg_cyl(g[mat], sh, el, 0.3 * s, 0.24 * s, seg=seg)
        E(((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, (sh[2] + el[2]) / 2), 0.3, 0.3, 0.42)   # 위팔
        seg_cyl(g[mat], el, ha, 0.24 * s, 0.17 * s, seg=seg)
        E(((el[0] * 0.6 + ha[0] * 0.4), (el[1] * 0.6 + ha[1] * 0.4), (el[2] * 0.6 + ha[2] * 0.4)), 0.25, 0.25, 0.4)
        E(ha, 0.2, 0.22, 0.26)                                                        # 손
        out["rh" if side > 0 else "lh"] = ha
    # ---- 옷
    if robe:
        g[robe].cyl(*Q(0, 0.02, 0.25), 1.05 * s, 0.95 * s, 4.25 * s, seg=seg + 4)    # 토가 치마
        for k in range(10):                                                           # 주름
            a = TAU * (k + 0.5) / 10
            g[robe].obox(x + 1.0 * s * math.cos(a), y + 1.0 * s * math.sin(a), z + 2.35 * s, 0.14 * s, 0.14 * s, 4.1 * s,
                         rz=a)
        seg_box(g[robe], Q(-1.05, 0.3, 6.75), Q(0.75, 0.52, 4.15), 0.85 * s, 0.28 * s)   # 가슴을 가로지른 자락
        seg_box(g[robe], Q(-1.05, -0.3, 6.75), Q(0.8, -0.5, 4.2), 0.85 * s, 0.28 * s)
        g[robe].box(*Q(-1.2, 0.0, 5.2), 0.5 * s, 0.9 * s, 3.0 * s)                  # 왼팔에 걸친 자락
    if not robe:
        g[mat].box(*Q(0, 0.02, 4.3), 1.85 * s, 1.3 * s, 0.75 * s)                  # 허리 두른 천(페리조마)
        g[mat].box(*Q(0, 0.62, 3.75), 0.8 * s, 0.14 * s, 0.9 * s)
    if cloak:
        seg_box(g[cloak], Q(-1.1, -0.1, 6.7), Q(-0.6, -0.75, 1.2), 1.4 * s, 0.22 * s)
        seg_box(g[cloak], Q(-0.2, -0.55, 6.6), Q(0.3, -0.95, 1.8), 1.3 * s, 0.2 * s)
        E(Q(-1.15, 0.0, 6.7), 0.5, 0.5, 0.35, cloak)                                  # 어깨 매듭
    if crack:
        for (a, b) in (((-0.6, 0.66, 6.2), (0.5, 0.6, 5.6)), ((0.2, 0.55, 5.3), (0.6, 0.5, 4.7))):
            seg_box(g[crack], Q(*a), Q(*b), 0.1 * s, 0.08 * s)
    return out


def _ell(g, c, rx, ry, rz, sg):
    bmesh.ops.create_uvsphere(g.bm, u_segments=sg + 2, v_segments=max(6, sg - 2), radius=1.0,
                              matrix=Matrix.Translation(c) @ Matrix.Diagonal((rx, ry, rz, 1.0)))
