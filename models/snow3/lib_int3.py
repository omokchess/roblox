# -*- coding: utf-8 -*-
"""
snow3/lib_int3.py — 2026-11-24 아트 3팀. 비행선(b_airship · b_airprop · b_airdoor)과 계류탑(b_mast · b_mastlift)이 같이 쓰는 치수·부품,
그리고 탑에 비행선을 매어 놓은 장면 렌더·사진판. lib.py · lib_a.py · lib_b.py · lib_int2.py 는 다른 팀 것이라 읽기만 한다.

사용자(2026-11-23): "비행정 지금 너무 저퀄이니까 비행정 퀄리티좀 높이고, 플레이어가 진짜 들어가서 탈 수 있도록 하자. 그만큼 비행정 그 탑 높이도 높게 하고."
(2026-11-18) "지금 테마에 맞는 수준에서 퀄리티의 극상이니까, 극사실주의로 만들면 안 돼." — 굵직한 블록감 + 놋쇠/구리 2단 디테일, 가는 실선 금지.

■ 맞춘 치수(블렌더: x 오른쪽 · y 뒤 · z 위, 앞 = -y. 로블록스 로컬 = (-x, z, y))
    탑 원점 = 탑 발자국 가운데 땅. 승강장 바닥 HP = 49. 비행선 원점 = 곤돌라 바닥 가운데.
    매인 자리: 비행선 원점 = 탑 (0, SHIP_Y, HP), 돌림 없음(둘 다 앞 = -y, 비행선 코가 탑을 본다)
    기낭 축 높이 ZC(곤돌라 바닥 위), 코 끝 Y_TIP(비행선 y), 길이 LH, 반지름 RH, 16 각
    계류 원뿔(탑 팔 끝 컵) = 탑 (0, CUP_Y, HP + ZC) — 비행선 코 막대 끝이 들어간다

■ 부품(한 줄씩)
    r_at(d) · hull_pt(d, k, dr)            기낭 반지름(코 끝에서 d) · 16 각 꼭짓점 k 의 점
    loft(g, mat, rings, tip0, tip1)        같은 꼭짓점 수 고리들을 잇는 닫힌 덩이(끝은 뚜껑 또는 뾰족 끝)
    slab(g, mat, pts, vec)                 평면 볼록 다각형을 vec 만큼 밀어낸 닫힌 판
    ring_walls(g, mat, poly, t, z0, z1, holes, coll)   바깥 다각형(반시계)을 두께 t 로 세운 벽(모서리 맞춤 · 구멍 = 문·창)
    rod(g, mat, p0, p1, s)                 두 점 사이 굵은 각재(밧줄·버팀대 — 가는 실선 금지, s ≥ 0.4)
    rail_slope(g, p0, p1, h)               두 기둥 사이 비스듬한 난간(계단) — 기둥은 부르는 쪽
    door_mark(ax, c, u, w, h, z0, face)    문 자리만 등록(문짝 없이 — 미닫이 문짝은 따로 도는 틀)
■ 렌더: blender -b -P models/snow3/lib_int3.py -- [시점 이름 ...]   → models/snow3/render/Sn3_Airship_*.png · Sn3_Mast_*.png
   사진판: python models/snow3/lib_int3.py -- sheet   (PIL 있는 시스템 파이썬) → models/snow3/render/airship_sheet.png
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

try:
    from mathutils import Matrix, Vector
    import lib as K
    from lib import bx, cbox
    import lib_a as A
    import lib_b as LB
    L, I, S = K.L, K.I, K.S
except ImportError:                    # pragma: no cover  (사진판은 PIL 만)
    K = None

# ================================================================== 맞춘 치수
HP = 49.0                 # 탑 승강장 바닥(= 곤돌라 바닥) 높이
SHIP_Y = 41.0             # 매였을 때 비행선 원점의 탑 y
LH, RH = 130.0, 16.0      # 기낭 길이 · 반지름(지름 32)
TN, PN = 0.33, 2.6        # 가장 굵은 자리(코에서 33%) · 코 둥글기(초타원 지수)
Y_TIP = -31.6             # 기낭 코 끝(비행선 y)
ZC = 31.2                 # 기낭 축(곤돌라 바닥 위)
NS = 16                   # 기낭 단면 각 수(아래·위·옆이 평평한 면)
PROBE = 2.4               # 코 계류 막대 길이(코 끝 앞)
CUP_Y = SHIP_Y + Y_TIP - PROBE + 0.6     # 탑 팔 끝 컵 입 자리(막대 끝이 0.6 들어감) = 7.6
CUP_Z = HP + ZC


def r_at(d):
    """기낭 반지름 — 코 끝에서 d(0..LH). 앞은 초타원(뭉툭한 R100 코), 뒤는 길게 가늘어짐"""
    if d <= 0.0 or d >= LH:
        return 0.0
    dn = TN * LH
    if d <= dn:
        x = d / dn
        return RH * (1.0 - (1.0 - x) ** PN) ** (1.0 / PN)
    u = (d - dn) / (LH - dn)
    return RH * max(0.0, 1.0 - u * u) ** 0.85


def ang(k):
    return math.pi / NS + k * 2 * math.pi / NS


def hull_pt(d, k, dr=0.0, zc=ZC):
    r = r_at(d) + dr
    a = ang(k)
    return (r * math.cos(a), Y_TIP + d, zc + r * math.sin(a))


def hull_low_z(d, x):
    """기낭 단면(16 각)에서 가로 위치 x 의 아랫면 높이(비행선 좌표)"""
    r = r_at(d)
    pts = [(r * math.cos(ang(k)), r * math.sin(ang(k))) for k in range(NS)]
    best = None
    for i in range(NS):
        (x0, z0), (x1, z1) = pts[i], pts[(i + 1) % NS]
        if min(x0, x1) - 1e-6 <= x <= max(x0, x1) + 1e-6 and abs(x1 - x0) > 1e-6:
            z = z0 + (z1 - z0) * (x - x0) / (x1 - x0)
            best = z if best is None else min(best, z)
    return ZC + (best if best is not None else 0.0)


# ================================================================== 덩이 만들기
def loft(g, mat, rings, tip0=None, tip1=None):
    """rings = [[(x, y, z) ...] ...](꼭짓점 수 같음). tip0 · tip1 = 앞·뒤 뾰족 끝(없으면 평평한 뚜껑). 닫힌 덩이"""
    n = len(rings[0])
    v = [p for r in rings for p in r]
    f = []
    for i in range(len(rings) - 1):
        for k in range(n):
            a, b = i * n + k, i * n + (k + 1) % n
            f.append((a, b, b + n, a + n))
    last = (len(rings) - 1) * n
    if tip0 is None:
        f.append(tuple(range(n))[::-1])
    else:
        v.append(tip0)
        t = len(v) - 1
        f += [(t, (k + 1) % n, k) for k in range(n)]
    if tip1 is None:
        f.append(tuple(range(last, last + n)))
    else:
        v.append(tip1)
        t = len(v) - 1
        f += [(t, last + k, last + (k + 1) % n) for k in range(n)]
    g[mat].add_mesh(v, f)


def slab(g, mat, pts, vec):
    """평면 볼록 다각형 pts(3D) 를 vec 만큼 밀어낸 닫힌 판"""
    n = len(pts)
    v = [tuple(p) for p in pts] + [(p[0] + vec[0], p[1] + vec[1], p[2] + vec[2]) for p in pts]
    f = [tuple(range(n))[::-1], tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    g[mat].add_mesh(v, f)


def prism_z(g, mat, poly, z0, z1):
    """평면 다각형(x, y)을 z0..z1 로 세운 덩이"""
    slab(g, mat, [(x, y, z0) for x, y in poly], (0.0, 0.0, z1 - z0))


def rod(g, mat, p0, p1, s=0.45):
    """두 점 사이 굵은 각재(쇠 막대 · 밧줄 · 버팀대). 단면 s × s"""
    A.lattice_leg(g, p0, p1, s=s, mat=mat)


def member(g, mat, p0, p1, w, h):
    LB.member(g, mat, p0, p1, w, h)


# ------------------------------------------------------------------ 다각형
def _nrm(x, y):
    n = math.hypot(x, y)
    return (x / n, y / n)


def poly_inset(poly, d):
    """반시계 볼록 다각형을 안으로 d 들인 다각형(모서리 맞춤)"""
    n = len(poly)
    out = []
    for i in range(n):
        p0, p1, p2 = poly[i - 1], poly[i], poly[(i + 1) % n]
        n1 = _nrm(-(p1[1] - p0[1]), p1[0] - p0[0])
        n2 = _nrm(-(p2[1] - p1[1]), p2[0] - p1[0])
        b = _nrm(n1[0] + n2[0], n1[1] + n2[1])
        k = d / (b[0] * n1[0] + b[1] * n1[1])
        out.append((p1[0] + b[0] * k, p1[1] + b[1] * k))
    return out


def ring_walls(g, mat, poly, t, z0, z1, holes=None, coll=True):
    """
    바깥 다각형 poly(반시계)를 두께 t 로 세운 벽. 모서리는 안쪽 다각형과 맞춰 잘라 틈·겹침이 없다.
    holes = {변 번호 i: [(u0, u1, za, zb)]} — u 는 바깥 꼭짓점 i 에서 변을 따라 잰 거리(문·창 구멍).
    돌려주는 값 = 안쪽 다각형
    """
    holes = holes or {}
    inn = poly_inset(poly, t)
    n = len(poly)
    for i in range(n):
        o0, o1 = poly[i], poly[(i + 1) % n]
        i0, i1 = inn[i], inn[(i + 1) % n]
        Lo = math.hypot(o1[0] - o0[0], o1[1] - o0[1])
        e = ((o1[0] - o0[0]) / Lo, (o1[1] - o0[1]) / Lo)
        nn = (-e[1], e[0])

        def P_out(u):
            return (o0[0] + e[0] * u, o0[1] + e[1] * u)

        def P_in(u):
            if u <= 1e-6:
                return i0
            if u >= Lo - 1e-6:
                return i1
            return (o0[0] + e[0] * u + nn[0] * t, o0[1] + e[1] * u + nn[1] * t)

        def piece(ua, ub, za, zb):
            if ub - ua < 1e-3 or zb - za < 1e-3:
                return
            q = [P_out(ua), P_out(ub), P_in(ub), P_in(ua)]
            prism_z(g, mat, q, za, zb)
            if coll:
                cu = (ua + ub) / 2
                c = (o0[0] + e[0] * cu + nn[0] * t / 2, o0[1] + e[1] * cu + nn[1] * t / 2)
                I.C(c[0], c[1], (za + zb) / 2, ub - ua, t, zb - za, math.atan2(e[1], e[0]))
        hs = sorted(holes.get(i, []))
        u = 0.0
        for h0, h1, hz0, hz1 in hs:
            piece(u, h0, z0, z1)
            piece(h0, h1, z0, hz0)
            piece(h0, h1, hz1, z1)
            u = h1
        piece(u, Lo, z0, z1)
    return inn


def edge_frame(poly, i):
    """변 i 의 (시작점, 방향, 안쪽 법선, 길이) — 벽에 붙이는 장식 자리 계산용"""
    o0, o1 = poly[i], poly[(i + 1) % len(poly)]
    Lo = math.hypot(o1[0] - o0[0], o1[1] - o0[1])
    e = ((o1[0] - o0[0]) / Lo, (o1[1] - o0[1]) / Lo)
    return o0, e, (-e[1], e[0]), Lo


def on_wall(g, mat, poly, i, u0, u1, z0, z1, d0, d1):
    """변 i 에 붙인 상자: 변을 따라 u0..u1, 높이 z0..z1, 바깥면에서 안쪽으로 d0..d1(음수 = 바깥으로 내밈)"""
    o0, e, nn, Lo = edge_frame(poly, i)
    cu, cd = (u0 + u1) / 2, (d0 + d1) / 2
    g[mat].obox(o0[0] + e[0] * cu + nn[0] * cd, o0[1] + e[1] * cu + nn[1] * cd, (z0 + z1) / 2,
                u1 - u0, d1 - d0, z1 - z0, rz=math.atan2(e[1], e[0]))


# ------------------------------------------------------------------ 난간 · 문
def rail_slope(g, p0, p1, h=3.4, mat="Rail", bal=1.4, coll=True):
    """
    두 기둥 사이 비스듬한 계단 난간: p0 · p1 = 두 기둥 안쪽 면의 디딤 높이 점(x, y, z).
    손잡이(윗대) · 가운데대 · 세로 살(디딤 선 위에 선다 — 난간 위엔 아무것도 없다)
    """
    member(g, mat, (p0[0], p0[1], p0[2] + h - 0.2), (p1[0], p1[1], p1[2] + h - 0.2), 0.45, 0.4)
    member(g, mat, (p0[0], p0[1], p0[2] + h * 0.5), (p1[0], p1[1], p1[2] + h * 0.5), 0.3, 0.3)
    Ln = math.dist(p0[:2], p1[:2])
    n = max(1, int(Ln / bal))
    for k in range(1, n):
        f = k / n
        x, y, z = (p0[0] + (p1[0] - p0[0]) * f, p0[1] + (p1[1] - p0[1]) * f, p0[2] + (p1[2] - p0[2]) * f)
        g[mat].box(x, y, z + (h - 0.4) / 2, 0.22, 0.22, h - 0.4)
    if coll:
        cx, cy = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        zlo, zhi = min(p0[2], p1[2]), max(p0[2], p1[2]) + h
        I.C(cx, cy, (zlo + zhi) / 2, Ln, 0.5, zhi - zlo, math.atan2(p1[1] - p0[1], p1[0] - p0[0]))


class _Sink:
    def box(self, *a, **k):
        pass
    obox = cyl = hcyl = add_mesh = box


class _SinkG(dict):
    def __missing__(self, k):
        return _Sink()


def door_mark(ax, c, u, w, h, z0, face):
    """문 자리만 등록(lib.door_open 을 버리는 덩이에 불러 DOORWAY · 문 정보 · holes.py 문 높이가 같이 적힌다). 문틀·문짝은 부르는 쪽"""
    K.door_open(_SinkG(), ax, c, u, w, h, z0, face=face)


# ------------------------------------------------------------------ 작은 소품(제 좌표: 원점 = 바닥 가운데, 앞 = -y)
def gauge(g, x, y, z, face_y=-1, r=0.55):
    """둥근 압력계(벽에 붙임, 얼굴 = face_y 쪽): 쇠 테 · 흰 판 · 바늘"""
    g["Brass"].hcyl(x, y + face_y * 0.08, z, r + 0.12, 0.16, axis="y", seg=14)
    g["Dial"].hcyl(x, y + face_y * 0.18, z, r, 0.06, axis="y", seg=14)
    g["Iron"].obox(x + 0.12, y + face_y * 0.23, z + 0.12, 0.08, 0.04, r * 0.85, ry=-0.8)


def lamp_hang(g, x, y, ztop, zl):
    """매단 등(lib 옛 등 + LampPt)"""
    K.lantern(g, x, y, ztop, zl)


# ================================================================== 렌더 장면
VIEWS = {}       # 렌더 시점(아래 main 에서 채움) — 이름 → (카메라, 바라볼 점, 렌즈, 그림자, 무엇)


def _scene_setup(sky=(0.66, 0.74, 0.84)):
    import bpy
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.show_cavity = True
    sh.background_type = "VIEWPORT"
    sh.background_color = sky
    scene.render.resolution_x, scene.render.resolution_y = 1200, 800
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


def _ground(name, x0, x1, y0, y1, z, mat="SnowCap"):
    import bpy
    me = bpy.data.meshes.new(name)
    me.from_pydata([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(K.L.material(mat, K.PAL))
    bpy.context.scene.collection.objects.link(ob)
    return ob


def _build(modname, M=None, copies=()):
    """b_*.py 하나를 지어 M 으로 옮긴다. copies = 같은 틀을 더 놓을 변환들(프로펠러)"""
    import importlib
    m = importlib.import_module(modname)
    objs, tris, _ = K.build_model(m, zfix=False)
    out = list(objs)
    for C_ in copies:
        for ob in objs:
            o2 = ob.copy()
            import bpy
            bpy.context.scene.collection.objects.link(o2)
            o2.matrix_world = C_
            out.append(o2)
    if M is not None:
        for ob in objs:
            ob.matrix_world = M
    print("  %s %d tri" % (m.NAME, sum(tris.values())))
    return out, sum(tris.values())


def _old_airship(M):
    """옛 SnowKit.Airship(models/build_steam.py airship()) — 크기 비교용"""
    g = K.G("OldAirship")
    S.airship(g)
    objs = []
    for k in K.PAL:
        ob = g[k].finish()
        if len(ob.data.polygons) == 0:
            import bpy
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        ob.matrix_world = M
        objs.append(ob)
    return objs


def _mannequin(x, y, z, rz=0.0):
    """R6 크기 사람(폭 4 · 키 5) — 렌더 크기 눈금용"""
    g = K.G("Dummy")
    q = {k: g[k] for k in g}
    c, s = math.cos(rz), math.sin(rz)

    def B(mat, lx, ly, lz, sx, sy, sz):
        q[mat].obox(x + c * lx - s * ly, y + s * lx + c * ly, z + lz, sx, sy, sz, rz=rz)
    B("SignBlue", 0, 0, 2.0 + 1.0, 2.0, 1.0, 2.0)
    for sx in (-1, 1):
        B("Paint", sx * 1.5, 0, 3.0, 1.0, 1.0, 2.0)
        B("Leather", sx * 0.5, 0, 1.0, 1.0, 1.0, 2.0)
    B("Paint", 0, 0, 4.5, 1.2, 1.2, 1.0)
    objs = []
    for k in K.PAL:
        ob = g[k].finish()
        if len(ob.data.polygons) == 0:
            import bpy
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        objs.append(ob)
    return objs


def compose(what):
    """what: 'moored'(탑 + 매인 비행선 + 프로펠러 + 문 + 승강기 칸) · 'ship'(비행선만, 원점 0) · 'compare'(새 · 옛 비행선 나란히)"""
    import importlib
    import bpy
    T = Matrix.Translation
    ship = importlib.import_module("b_airship")
    hidden = []
    if what == "moored":
        _build("b_mast")
        Ms = T((0.0, SHIP_Y, HP))
        _build("b_airship", Ms)
        hubs = [Ms @ T(h[:3]) @ Matrix.Rotation(h[3], 4, "Y") for h in ship.PROP_HUBS]
        _build("b_airprop", hubs[0], copies=hubs[1:])
        dr = importlib.import_module("b_airdoor")
        _build("b_airdoor", Ms @ T(dr.OPEN))
        ms = importlib.import_module("b_mast")
        _build("b_mastlift", T(ms.LIFT_TOP if os.environ.get("LIFT_TOP") else ms.LIFT_BOTTOM))
        for x, y, z, rz in ((-2.0, -16.0, 0.0, 0.0), (13.0, 26.0, HP, math.pi / 2), (-5.0, -6.8, 1.0, 0.6)):   # 셋째(1층 안)는 승강기 · 계단 시점을 가리지 않게 지레 옆(2026-11-27 — 비평 6번 '흰 안내판'이 이 잣대 사람이었다)
            _mannequin(x, y, z, rz)
        _ground("terrace", -27, 27, -97.5, 35, -0.02)
        _ground("plaza", -200, 200, -400, -97.5, -5.62)
        _ground("sea", -600, 600, 35, 900, -80.0, "RockC")
    elif what == "ship":
        _build("b_airship")
        hubs = [T(h[:3]) @ Matrix.Rotation(h[3], 4, "Y") for h in ship.PROP_HUBS]
        _build("b_airprop", hubs[0], copies=hubs[1:])
        dr = importlib.import_module("b_airdoor")
        _build("b_airdoor", T(dr.OPEN))
        _mannequin(12.0, -12.0, 0.0, math.pi / 2)
    elif what == "compare":
        _build("b_airship", T((-45.0, 0.0, 0.0)))
        hubs = [T((-45.0, 0.0, 0.0)) @ T(h[:3]) @ Matrix.Rotation(h[3], 4, "Y") for h in ship.PROP_HUBS]
        _build("b_airprop", hubs[0], copies=hubs[1:])
        _old_airship(T((30.0, 0.0, 0.0)))
        _mannequin(-6.0, -40.0, 0.0)
        _mannequin(40.0, -40.0, 0.0)
        _ground("ground", -300, 300, -300, 300, -6.0)
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.name.endswith(("WinGlass", "_Vent", "_LampPt")):
            ob.hide_render = True
            hidden.append(ob)
    return hidden


def shots():
    """시점 표: (파일 이름, 장면, 카메라, 바라볼 점, 렌즈 또는 ('ortho', 크기), 그림자, 창유리 보임)"""
    E = 4.5
    sy = SHIP_Y
    return [
        # 비행선 겉(비행선 원점 기준)
        ("Sn3_Airship_ext34", "ship", (-120, -110, 70), (0, 30, 22), 30, True),
        ("Sn3_Airship_ext34r", "ship", (125, -95, 40), (0, 30, 24), 30, True),
        ("Sn3_Airship_side", "ship", (230, 33, 22), (0, 33, 22), ("ortho", 150), True),
        ("Sn3_Airship_top", "ship", (0.01, 33, 300), (0, 33, 0), ("ortho", 150), True),
        ("Sn3_Airship_front", "ship", (0, -170, 25), (0, 0, 24), 40, True),
        ("Sn3_Airship_gondola", "ship", (34, -42, 14), (0, -4, 8), 24, True),
        ("Sn3_Airship_tail", "ship", (62.0, 50.0, 52.0), (0.0, 82.0, 31.0), 30, True),
        ("Sn3_Airship_compare", "compare", (-8, -230, 30), (-8, 20, 22), ("ortho", 200), True),
        # 탑에 매인 모습
        ("Sn3_Mast_moored34", "moored", (-150, -135, 60), (0, 50, 55), 28, True),
        ("Sn3_Mast_moored_side", "moored", (240, 45, 52), (0, 45, 52), ("ortho", 190), True),
        ("Sn3_Mast_plaza_eye", "moored", (0.0, -150.0, -5.6 + E), (0.0, 30.0, 52.0), 24, True),
        ("Sn3_Mast_plaza_eye_se", "moored", (38.0, -112.0, -5.6 + E), (0.0, 40.0, 55.0), 24, True),
        ("Sn3_Mast_terrace_eye", "moored", (-14.0, -60.0, E), (0.0, 20.0, 55.0), 17, True),
        ("Sn3_Mast_top34", "moored", (48, -40, 72), (6, 16, 52), 24, True),
        # 2026-11-27 2판 확인용: 계류 머리 가까이 · 벌어진 다리 밑 · 꼬리날개
        ("Sn3_Mast_head", "moored", (-34.0, -30.0, 90.0), (0.0, 3.0, 74.0), 30, True),
        ("Sn3_Mast_base", "moored", (-44.0, -58.0, 9.0), (0.0, 0.0, 16.0), 24, True),
        # 탑 1인칭(눈높이 4.5)
        ("Sn3_Mast_fp_door", "moored", (0.0, -22.0, E), (0.0, 0.0, 5.0), 17, False),
        ("Sn3_Mast_fp_lift", "moored", (-2.0, -8.0, 1.0 + E), (0.0, -2.0, 3.5), 17, False),
        ("Sn3_Mast_fp_stair", "moored", (6.6, -2.0, 17.0 + E), (6.6, 6.0, 22.5), 17, False),
        ("Sn3_Mast_fp_stair_up", "moored", (-2.5, -7.5, 1.0 + E), (6.5, 2.5, 9.0), 17, False),      # 2026-11-27: 1층에서 첫 계단(동쪽)을 봄(옛 시점은 쉼참 밑판만 보였다)
        ("Sn3_Mast_fp_platform", "moored", (-8.0, -9.0, HP + E), (12.0, 20.0, HP + 6.0), 17, False),
        ("Sn3_Mast_fp_gangway", "moored", (13.6, 15.0, HP + E), (11.0, 30.0, HP + 4.0), 17, False),
        # 곤돌라 안 1인칭(비행선 원점 = 탑 (0, SHIP_Y, HP))
        ("Sn3_Airship_fp_door", "moored", (13.2, sy - 12.8, HP + E), (0.0, sy - 10.0, HP + 4.0), 17, False),
        ("Sn3_Airship_fp_cockpit", "moored", (2.5, sy - 9.0, HP + E), (0.0, sy - 24.0, HP + 4.5), 17, False),
        ("Sn3_Airship_fp_cabin", "moored", (0.5, sy - 8.0, HP + E), (-1.0, sy + 14.0, HP + 3.5), 17, False),
        ("Sn3_Airship_fp_cabin_back", "moored", (-1.0, sy + 12.0, HP + E), (2.0, sy - 10.0, HP + 3.5), 17, False),
        ("Sn3_Airship_fp_cargo", "moored", (0.0, sy + 11.0, HP + E), (0.0, sy + 24.0, HP + 3.0), 17, False),
        ("Sn3_Airship_fp_window", "moored", (6.0, sy + 1.0, HP + E), (14.0, sy + 6.0, HP + 1.0), 17, False),
    ]


def render(names=None):
    import bpy
    out = os.path.join(HERE, "render")
    os.makedirs(out, exist_ok=True)
    by = {}
    solo = bool(os.environ.get("SHIPONLY"))           # 탑 없이 비행선만 놓고 곤돌라 안을 찍어 볼 때(시점을 비행선 원점으로 옮김)
    for s in shots():
        if not names or s[0] in names:
            if solo and s[0].startswith("Sn3_Airship_fp"):
                sh = lambda p: (p[0], p[1] - SHIP_Y, p[2] - HP)       # noqa: E731
                s = (s[0], "ship", sh(s[2]), sh(s[3]), s[4], s[5])
            by.setdefault(s[1], []).append(s)
    for what, lst in by.items():
        K.L.clear_scene()
        scene, cam = _scene_setup()
        compose(what)
        for name, _, loc, look, lens, shadow in lst:
            scene.display.shading.show_shadows = shadow
            cam.location = Vector(loc)
            cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
            if isinstance(lens, tuple):
                cam.data.type = "ORTHO"
                cam.data.ortho_scale = lens[1]
            else:
                cam.data.type = "PERSP"
                cam.data.lens = lens
            cam.data.clip_start = 0.1
            cam.data.clip_end = 3000.0
            scene.render.filepath = os.path.join(out, name + ".png")
            bpy.ops.render.render(write_still=True)
            print("  ->", name)


def sheet():
    """사진판: 시점마다 한 칸(가로 3) + 이름"""
    from PIL import Image, ImageDraw
    out = os.path.join(HERE, "render")
    names = [s[0] for s in _SHOT_NAMES]
    ims = [(n, os.path.join(out, n + ".png")) for n in names if os.path.exists(os.path.join(out, n + ".png"))]
    W, H, per = 480, 320, 3
    nr = (len(ims) + per - 1) // per
    sh = Image.new("RGB", (per * (W + 8), nr * (H + 24)), (24, 26, 30))
    d = ImageDraw.Draw(sh)
    for i, (n, p) in enumerate(ims):
        r, c = divmod(i, per)
        x0, y0 = c * (W + 8), r * (H + 24)
        sh.paste(Image.open(p).convert("RGB").resize((W, H)), (x0, y0 + 22))
        d.text((x0 + 4, y0 + 5), n, fill=(235, 235, 235))
    sh.save(os.path.join(out, "airship_sheet.png"))
    print("sheet", len(ims))


_SHOT_NAMES = [("Sn3_Airship_ext34",), ("Sn3_Airship_ext34r",), ("Sn3_Airship_side",), ("Sn3_Airship_top",), ("Sn3_Airship_front",),
               ("Sn3_Airship_gondola",), ("Sn3_Airship_tail",), ("Sn3_Airship_compare",), ("Sn3_Mast_moored34",), ("Sn3_Mast_moored_side",), ("Sn3_Mast_plaza_eye",),
               ("Sn3_Mast_terrace_eye",), ("Sn3_Mast_top34",), ("Sn3_Mast_head",), ("Sn3_Mast_base",), ("Sn3_Mast_fp_door",), ("Sn3_Mast_fp_lift",), ("Sn3_Mast_fp_stair",),
               ("Sn3_Mast_fp_stair_up",), ("Sn3_Mast_fp_platform",), ("Sn3_Mast_fp_gangway",), ("Sn3_Airship_fp_door",),
               ("Sn3_Airship_fp_cockpit",), ("Sn3_Airship_fp_cabin",), ("Sn3_Airship_fp_cabin_back",), ("Sn3_Airship_fp_cargo",),
               ("Sn3_Airship_fp_window",)]


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args[:1] == ["sheet"]:
        sheet()
    elif K is not None:
        render(set(args) or None)
