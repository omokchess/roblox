# -*- coding: utf-8 -*-
"""
build_steam_obs.py — 2026-10-09. 슈네라이히 천문대 2판(들어가는 건물) + 놀이터·연못 소품. build_steam_town.py 가 JOBS 로 묶는다.

사용자: "천문대 위쪽 뚜껑이 열린 상태로, 초 고퀄리티 대형 망원경이 하늘을 비추고 있게. 조금씩 돌아가게 하면서 항성을 따라다니고,
천문대는 문에서 텔포가 아니라 건물 자체에 들어갈 수 있게" / "초록 구역 놀이터, 주황 구역 빈 공간 채울 것(건물 말고)".

천문대 = 19세기 대형 굴절 망원경 천문대(여키스·릭 천문대 꼴)를 스팀펑크로:
  Observatory        벽돌 원통(속이 빈 벽, 앞 -y 에 열린 쌍여닫이 문), 받침돌·계단, 기둥띠·창(안팎), 바닥(놋쇠 나침 무늬),
                     무쇠 기둥 받침(피어) + 고정 극축 통 + 시계 구동 상자, 태양계 모형 탁자(해), 책장, 별지도, 책상
  Observatory_Dome   녹청 반구 돔. 틈(폭 8)이 +y(북) 쪽 지평에서 천정 너머 15도까지 열려 있고 구리 덧문 둘이 양옆에 걷혀 있다. 돈다(수직축)
  Observatory_Scope  극축을 따라 도는 몸: 적경 톱니바퀴, 적위 축통·눈금판, 균형추 둘, 놋쇠 굴절 경통(차양·대물렌즈·접안부·파인더)
  Orrery_A..D        태양계 모형 팔 넷(각각 다른 빠르기로 수직축 둘레를 돈다)
적도의: 극축 = 위도 40도로 +y(북)를 향해 든다. 별은 적위 60도(극에서 30도) — 고도 10..70도, 방위 북 ±41도 안에서 돈다.
극축 하나로 별을 따라가므로 Observatory_Scope 만 극축(점 H 를 지나는 P) 둘레로 돌리면 된다. 돔은 경통 방위로 돈다.
로블록스 쪽 값(Snow_City2.luau OBS_SCRIPT 와 같아야 함): 블렌더 (x, y, z) → 로블록스 로컬 (-x, z, y).

놀이터: Play_Swing(그네), Play_Slide(미끄럼틀), Play_Seesaw(시소), Play_RoundBase + Play_Round(톱니 회전 놀이기구 — 판이 돈다),
        Play_Dome(오르기 돔), Park_Bench(무쇠 벤치), Snowman(눈사람), Sled(썰매)
원점 = 바닥 가운데, 앞 = -y.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import build_steam as S  # noqa: E402

R = math.radians

# ================================================================== 천문대 치수
RO, RI = 22.5, 20.5        # 원통 벽 바깥·안 반지름
Z_PL = 1.7                 # 받침돌 윗면
Z_FL = 2.0                 # 안 바닥 윗면
Z_TOP = 24.0               # 벽 윗면
DOOR_A, DOOR_HALF, DOOR_TOP = -90.0, 9.0, 11.7
DOME_CZ, DOME_RO, DOME_RI, SLIT = 24.6, 22.6, 21.9, 5.5   # SLIT = 틈 반폭(경통이 극축에서 비켜 있어 넉넉히)
SLIT_BACK_Y = 0.26 * DOME_RO     # 틈이 천정 너머 뒤쪽으로 내려오는 끝(고도 75도). 틈·별·극축은 문 쪽(-y, 광장 쪽)
PHI = R(40.0)                     # 위도 = 극축 고도
P = Vector((0.0, -math.cos(PHI), math.sin(PHI)))
A_PIV = Vector((0.0, 0.0, 18.3))  # 극축 통 가운데
H = A_PIV + 3.0 * P               # 적위축이 극축과 만나는 점(도는 중심)
D0 = Vector((-1.0, 0.0, 0.0))     # 적위축(별이 남중할 때 동서로 눕는다)
S0 = Vector((0.0, -math.cos(R(70.0)), math.sin(R(70.0))))  # 남중한 별 쪽(고도 70, 앞 -y)
OFF = 3.6                         # 극축에서 경통 가운데까지
ORRERY = (-10.0, 5.0)             # 태양계 모형 탁자 가운데(블렌더 x, y)


def basis(x, y, z, o):
    """세 축(열)과 원점으로 4x4 행렬"""
    m = Matrix((tuple(x), tuple(y), tuple(z))).transposed().to_4x4()
    m.translation = Vector(o)
    return m


def polar_m(a_deg, r, z=0.0):
    """원통 벽 둘레 자리 틀: 원점 = 벽 위 점, 로컬 -y = 바깥(법선), x = 둘레 방향"""
    a = R(a_deg)
    return Matrix.Translation((r * math.cos(a), r * math.sin(a), z)) @ Matrix.Rotation(a + math.pi / 2, 4, "Z")


def arc_wall(g, mat, z0, z1, r0, r1, a0, a1, n=24):
    """닫힌 부채꼴 고리 덩이(벽·띠). a0 → a1 (도, a0 < a1)"""
    v = []
    for z in (z0, z1):
        for r in (r0, r1):
            for k in range(n + 1):
                a = R(a0 + (a1 - a0) * k / n)
                v.append((r * math.cos(a), r * math.sin(a), z))
    m = n + 1
    B0i, B0o, B1i, B1o = 0, m, 2 * m, 3 * m
    f = []
    for k in range(n):
        f.append((B0i + k, B0o + k, B0o + k + 1, B0i + k + 1))
        f.append((B1i + k, B1i + k + 1, B1o + k + 1, B1o + k))
        f.append((B0o + k, B1o + k, B1o + k + 1, B0o + k + 1))
        f.append((B0i + k, B0i + k + 1, B1i + k + 1, B1i + k))
    for k in (0, n):
        f.append((B0i + k, B1i + k, B1o + k, B0o + k))
    g[mat].add_mesh(v, f)


def sphere(g, mat, c, r, sub=2):
    bmesh.ops.create_icosphere(g[mat].bm, subdivisions=sub, radius=r, matrix=Matrix.Translation(c))


def cone(g, mat, base, tip, r, seg=10):
    base, tip = Vector(base), Vector(tip)
    d = tip - base
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.create_cone(g[mat].bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=0.0,
                          depth=d.length, matrix=Matrix.Translation((base + tip) / 2) @ rot)


def sweep(g, mat, pts, r, seg=8, cap=True):
    """꺾은선을 따라 둥근 관(평행 이동 틀). 사슬·난간·갈비살·미끄럼 테두리"""
    P_ = [Vector(p) for p in pts]
    n = len(P_)
    if n < 2:
        return
    T = []
    for i in range(n):
        a = P_[min(i + 1, n - 1)] - P_[max(i - 1, 0)]
        T.append(a.normalized())
    up = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
    N = (up - T[0] * up.dot(T[0])).normalized()
    v = []
    for i in range(n):
        if i > 0:
            N = (N - T[i] * N.dot(T[i])).normalized()
        B = T[i].cross(N)
        for k in range(seg):
            ph = 2 * math.pi * k / seg
            v.append(tuple(P_[i] + (N * math.cos(ph) + B * math.sin(ph)) * r))
    f = []
    for i in range(n - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            f.append((i * seg + k, i * seg + k2, (i + 1) * seg + k2, (i + 1) * seg + k))
    if cap:
        f.append(tuple(range(seg))[::-1])
        f.append(tuple(range((n - 1) * seg, n * seg)))
    g[mat].add_mesh(v, f)


def ribbon(g, mat, pts, side, w, t):
    """꺾은선을 따라 폭 w(옆 = side 벡터), 두께 t 의 띠 덩이. 미끄럼틀 바닥·옆벽"""
    side = Vector(side).normalized()
    P_ = [Vector(p) for p in pts]
    n = len(P_)
    v = []
    for i in range(n):
        a = P_[min(i + 1, n - 1)] - P_[max(i - 1, 0)]
        nrm = a.normalized().cross(side).normalized()
        if nrm.z < 0:
            nrm = -nrm
        for sx in (-1, 1):
            for sz in (-1, 1):
                v.append(tuple(P_[i] + side * (w / 2 * sx) + nrm * (t / 2 * sz)))
    f = []
    for i in range(n - 1):
        a, b = 4 * i, 4 * (i + 1)
        f += [(a + 1, a + 3, b + 3, b + 1), (a + 0, b + 0, b + 2, a + 2), (a + 0, a + 1, b + 1, b + 0), (a + 2, b + 2, b + 3, a + 3)]
    f.append((0, 2, 3, 1))
    e = 4 * (n - 1)
    f.append((e, e + 1, e + 3, e + 2))
    g[mat].add_mesh(v, f)


def sector(g, mat, r0, r1, a0, a1, z0, z1, n=8, c=(0.0, 0.0)):
    """가로 누운 부채꼴 판(가운데 c)"""
    v = []
    for z in (z0, z1):
        for r in (r0, r1):
            for k in range(n + 1):
                a = R(a0 + (a1 - a0) * k / n)
                v.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a), z))
    m = n + 1
    B0i, B0o, B1i, B1o = 0, m, 2 * m, 3 * m
    f = []
    for k in range(n):
        f.append((B0i + k, B0o + k, B0o + k + 1, B0i + k + 1))
        f.append((B1i + k, B1i + k + 1, B1o + k + 1, B1o + k))
        f.append((B0o + k, B1o + k, B1o + k + 1, B0o + k + 1))
        f.append((B0i + k, B0i + k + 1, B1i + k + 1, B1i + k))
    for k in (0, n):
        f.append((B0i + k, B1i + k, B1o + k, B0o + k))
    g[mat].add_mesh(v, f)


def _obj(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def _box_obj(name, x0, x1, y0, y1, z0, z1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
                          @ Matrix.Diagonal((x1 - x0, y1 - y0, z1 - z0, 1.0)))
    return _obj(bm, name)


def _hemi_shell_obj(name, ro, ri, cz, na=72, nl=18):
    """두께 있는 반구 껍질(닫힌 덩이)"""
    bm = bmesh.new()
    rings = {}
    for tag, rr in (("o", ro), ("i", ri)):
        rows = []
        for k in range(nl):
            el = R(90.0 * k / nl)
            rows.append([bm.verts.new((rr * math.cos(el) * math.cos(2 * math.pi * j / na),
                                       rr * math.cos(el) * math.sin(2 * math.pi * j / na), cz + rr * math.sin(el)))
                         for j in range(na)])
        pole = bm.verts.new((0, 0, cz + rr))
        rings[tag] = (rows, pole)
    for tag in ("o", "i"):
        rows, pole = rings[tag]
        for k in range(nl - 1):
            for j in range(na):
                q = (rows[k][j], rows[k][(j + 1) % na], rows[k + 1][(j + 1) % na], rows[k + 1][j])
                bm.faces.new(q if tag == "o" else q[::-1])
        for j in range(na):
            t = (rows[nl - 1][j], rows[nl - 1][(j + 1) % na], pole)
            bm.faces.new(t if tag == "o" else t[::-1])
    ro_, ri_ = rings["o"][0][0], rings["i"][0][0]
    for j in range(na):
        bm.faces.new((ro_[(j + 1) % na], ro_[j], ri_[j], ri_[(j + 1) % na]))
    return _obj(bm, name)


def boolean_into(g, mat, target, cutters, op):
    """target 에 cutters 를 불리언으로 적용해 g[mat] 에 합치고 임시 오브젝트는 지운다"""
    for c in cutters:
        mod = target.modifiers.new(name="b_" + c.name, type="BOOLEAN")
        mod.operation = op
        mod.object = c
        mod.solver = "EXACT"
        c.hide_render = True
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(target.evaluated_get(dg))
    g[mat].bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    for ob in [target] + list(cutters):
        m = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.meshes.remove(m)


def in_slit_zone(p, pad):
    """돔 겉의 점이 틈(+덧문 자리 pad)에 드는가"""
    return abs(p.x) < pad and p.y < SLIT_BACK_Y + 0.5


# ------------------------------------------------------------------ 둥근 벽 창(안팎)
def rwin(g, a_deg, z0, w, h, inner=True):
    L.transformed(g, polar_m(a_deg, RO), lambda t: S.window(t, 0, 0, z0, w, h, face="-y", cross=True))
    # 창 위 돌 처마(밖)
    L.transformed(g, polar_m(a_deg, RO), lambda t: t["StoneTrim"].box(0, -0.5, z0 + h + 0.9, w + 1.2, 1.0, 0.5))
    if inner:
        L.transformed(g, polar_m(a_deg, RI), lambda t: S.window(t, 0, 0, z0, w, h, face="+y", cross=True, sill=False))


def observatory(g):
    # ── 받침돌 두 켜 + 문 앞 계단(둘) + 옆 볼
    g["Stone"].cyl(0, 0, 0, 26.0, 26.0, 1.2, seg=56)
    g["StoneTrim"].cyl(0, 0, 1.2, 25.4, 25.2, Z_PL - 1.2, seg=56)
    g["Stone"].box(0, -26.2, 0.565, 12.0, 2.4, 1.13)
    g["Stone"].box(0, -28.0, 0.285, 12.0, 1.4, 0.57)
    for s in (-1, 1):
        g["StoneTrim"].box(s * 6.4, -26.9, 0.8, 0.8, 3.6, 1.6)
    # ── 원통 벽(문 자리 비움) + 문 위 상인방 벽
    arc_wall(g, "Brick", Z_PL, Z_TOP, RI, RO, DOOR_A + DOOR_HALF, DOOR_A - DOOR_HALF + 360, n=64)
    arc_wall(g, "Brick", DOOR_TOP, Z_TOP, RI, RO, DOOR_A - DOOR_HALF, DOOR_A + DOOR_HALF, n=4)
    # 띠돌: 밑 띠(문 비움)·가운데 띠·처마 띠, 안쪽 회랑 받침 띠
    arc_wall(g, "StoneTrim", Z_PL, 2.6, RO, RO + 0.4, DOOR_A + DOOR_HALF + 1.5, DOOR_A - DOOR_HALF - 1.5 + 360, n=64)
    arc_wall(g, "StoneTrim", 15.0, 15.6, RO, RO + 0.45, DOOR_A + 12, DOOR_A - 12 + 360, n=64)
    arc_wall(g, "StoneTrim", 23.3, Z_TOP + 0.3, RO - 0.2, RO + 1.1, -180, 180, n=72)
    arc_wall(g, "SnowCap", Z_TOP + 0.3, Z_TOP + 0.65, 23.0, 23.7, -180, 180, n=72)
    arc_wall(g, "StoneTrim", 13.0, 13.4, RI - 0.35, RI, DOOR_A + DOOR_HALF + 1, DOOR_A - DOOR_HALF - 1 + 360, n=64)
    # 벽기둥(문 둘레 빼고 30 도마다)
    for a in range(0, 360, 30):
        if abs(((a - DOOR_A + 180) % 360) - 180) < 22:
            continue
        L.transformed(g, polar_m(a, RO), lambda t: (t["BrickDark"].box(0, -0.45, 2.6 + 10.35, 1.8, 0.9, 20.7),
                                                     t["StoneTrim"].box(0, -0.55, 22.9, 2.3, 1.1, 0.8),
                                                     t["StoneTrim"].box(0, -0.55, 2.9, 2.3, 1.1, 0.6)))
    # 창: 아래(밖만 — 안쪽은 계단·책장 자리) / 회랑 높이(안팎)
    for a in (150, -150, 30, -30):
        rwin(g, a, 5.0, 2.6, 5.0, inner=False)
    for a in (0, 45, 90, 135, 180, 225, -45):
        rwin(g, a, 16.4, 2.6, 5.4, inner=True)
    # ── 문: 돌 문틀 + 반달 불빛창(문 위) + 활짝 연 쌍여닫이
    fr = polar_m(DOOR_A, RO)

    def doorway(t):
        for s in (-1, 1):
            t["StoneTrim"].box(s * 3.85, -0.35, Z_PL + (DOOR_TOP - Z_PL) / 2, 1.1, 0.9, DOOR_TOP - Z_PL)
        t["StoneTrim"].box(0, -0.4, DOOR_TOP + 0.35, 8.8, 1.0, 0.7)
        t["StoneTrim"].box(0, -0.6, DOOR_TOP + 3.75, 1.0, 1.0, 1.2)   # 쐐기돌
        L.transformed(t, Matrix.Translation((0, -0.35, DOOR_TOP + 0.7)) @ Matrix.Rotation(math.pi / 2, 4, "Z"),
                      lambda q: S.half_disc(q, "Glow", 0, 0, 0, 2.9, 0.2))
        L.transformed(t, Matrix.Translation((0, -0.55, DOOR_TOP + 0.7)) @ Matrix.Rotation(math.pi / 2, 4, "Z"),
                      lambda q: S.half_disc(q, "Brass", 0, 0, 0, 3.4, 0.15))
        for k in range(5):
            a = math.pi * (k + 1) / 6
            t["Iron"].obox(1.5 * math.cos(a), -0.7, DOOR_TOP + 0.7 + 1.5 * math.sin(a), 0.16, 0.12, 2.9, ry=-(math.pi / 2 - a))
        # 문짝: 경첩(x ±3.25)에서 바깥으로 105 도 활짝 연다(닫힌 방향 = 가운데 쪽 -s·x)
        for s in (-1, 1):
            beta = R(105.0)
            dx, dy = -s * math.cos(beta), -math.sin(beta)
            hx, hy = s * 3.25, -0.6
            cx, cy = hx + dx * 1.6, hy + dy * 1.6
            rz = math.atan2(dy, dx)
            t["Timber"].obox(cx, cy, Z_PL + 4.8, 3.2, 0.3, 9.5, rz=rz)
            for zz in (2.6, 5.6, 8.8):
                t["Iron"].obox(cx - math.sin(rz) * 0.2, cy + math.cos(rz) * 0.2, Z_PL + zz, 3.25, 0.1, 0.35, rz=rz)
            t["Brass"].obox(cx + dx * 1.1 - math.sin(rz) * 0.25, cy + dy * 1.1 + math.cos(rz) * 0.25, Z_PL + 4.8, 0.3, 0.15, 0.6, rz=rz)
    L.transformed(g, fr, doorway)
    g["LampPt"].box(0, -RO - 2.0, 10.2, 0.6, 0.6, 0.6)
    # ── 안: 바닥(나무) + 놋쇠 고리·나침 무늬
    g["Timber"].cyl(0, 0, 1.5, RI - 0.1, RI - 0.1, Z_FL - 1.5, seg=64)
    S.ring(g, "Brass", 0, 0, Z_FL - 0.1, 8.6, 9.0, 0.13, n=64)
    S.ring(g, "Brass", 0, 0, Z_FL - 0.1, 3.0, 3.25, 0.13, n=32)
    for k in range(8):
        a = math.pi * k / 4
        ln = 5.4 if k % 2 == 0 else 3.6
        g["Brass"].obox(math.cos(a) * (3.2 + ln / 2), math.sin(a) * (3.2 + ln / 2), Z_FL - 0.035, ln, 0.35 if k % 2 == 0 else 0.22, 0.13, rz=a)
    # ── 망원경 받침(피어): 돌 굽 + 무쇠 기둥(가늘어짐) + 놋쇠 띠 + 머리
    g["Stone"].box(0, 0, Z_FL + 0.5, 5.6, 5.6, 1.0)
    g["Iron"].cyl(0, 0, Z_FL + 1.0, 2.0, 1.55, 15.0 - Z_FL - 1.0, seg=28)
    for z, r in ((Z_FL + 1.3, 2.12), (8.5, 1.9), (14.6, 1.7)):
        g["Brass"].cyl(0, 0, z, r, r, 0.45, seg=28)
    for k in range(12):   # 세로 홈(골)
        a = 2 * math.pi * k / 12
        g["IronLight"].obox(1.82 * math.cos(a), 1.82 * math.sin(a), 9.0, 0.22, 0.22, 10.5, rz=a)
    g["Iron"].cyl(0, 0, 15.0, 1.6, 2.6, 1.0, seg=28)
    g["Brass"].cyl(0, 0, 16.0, 2.75, 2.75, 0.3, seg=28)
    g["Iron"].box(0, -0.3, 16.9, 3.6, 4.4, 1.2)                    # 쐐기(극축 받침)
    for s in (-1, 1):
        g["IronLight"].obox(s * 1.6, -0.5, 17.6, 0.35, 4.6, 2.2, rx=PHI * 0.5)
    # 고정 극축 통 + 놋쇠 테
    S.tube(g, "Iron", A_PIV - 3.5 * P, A_PIV + 2.1 * P, 1.35, seg=28)
    S.collar(g, "Brass", A_PIV + 2.0 * P, P, 1.55, 0.3, seg=28)
    S.collar(g, "Brass", A_PIV - 3.3 * P, P, 1.55, 0.35, seg=28)
    S.collar(g, "Copper", A_PIV - 0.6 * P, P, 1.45, 0.5, seg=28)
    # 적경 눈금 고리(고정)
    L.transformed(g, basis(D0, P.cross(D0), P, A_PIV + 2.25 * P),
                  lambda t: [t["Iron"].obox(2.15 * math.cos(2 * math.pi * k / 36), 2.15 * math.sin(2 * math.pi * k / 36), 0.0,
                                            0.45 if k % 3 == 0 else 0.25, 0.07, 0.12, rz=2 * math.pi * k / 36) for k in range(36)])
    # 시계 구동 상자(피어 옆, 놋쇠) + 조속기 + 추
    g["Brass"].box(-2.7, 0.0, 11.0, 1.6, 2.6, 3.0)                 # (피어 -x 옆)
    g["Iron"].box(-2.7, 0.0, 12.6, 1.8, 2.8, 0.25)
    g["Glass"].box(-3.52, 0.0, 11.2, 0.05, 2.0, 2.2)
    S.gear(g, "Copper", -3.6, -0.4, 11.4, 0.6, 12, 0.12, axis="x")
    S.gear(g, "Brass", -3.62, 0.5, 10.6, 0.4, 9, 0.12, axis="x")
    g["Iron"].cyl(-2.7, 0.0, 12.75, 0.12, 0.12, 1.4, seg=8)
    for s in (-1, 1):
        g["Iron"].obox(-2.7 + s * 0.35, 0.0, 13.6, 0.08, 0.08, 0.9, ry=s * 0.6)
        sphere(g, "Brass", (-2.7 + s * 0.65, 0.0, 13.25), 0.22, sub=1)
    g["Iron"].cyl(-3.0, 0.9, 4.0, 0.05, 0.05, 6.9, seg=6)
    g["Iron"].cyl(-3.0, 0.9, 3.2, 0.45, 0.45, 0.9, seg=12)       # 추
    S.tube(g, "IronLight", (-2.7, 0.0, 12.5), A_PIV + 1.6 * P + Vector((-2.2, 0.0, 0.0)), 0.13, seg=8)
    # ── 태양계 모형 탁자(해는 고정, 팔은 Orrery_A..D)
    ox, oy = ORRERY
    g["Wood"].cyl(ox, oy, 5.4, 3.6, 3.6, 0.4, seg=32)
    g["Brass"].cyl(ox, oy, 5.35, 3.7, 3.7, 0.1, seg=32)
    g["Wood"].cyl(ox, oy, Z_FL, 0.5, 0.35, 3.4, seg=12)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        g["Iron"].obox(ox + math.cos(a) * 1.3, oy + math.sin(a) * 1.3, Z_FL + 0.35, 2.4, 0.3, 0.35, rz=a)
    g["Brass"].cyl(ox, oy, 5.8, 1.2, 0.9, 0.6, seg=24)
    S.gear(g, "Copper", ox, oy, 6.25, 1.0, 16, 0.15, axis="z")
    g["Brass"].cyl(ox, oy, 6.4, 0.16, 0.16, 3.2, seg=10)
    sphere(g, "Glow", (ox, oy, 9.9), 0.85, sub=2)
    g["LampPt"].box(ox, oy, 9.9, 0.3, 0.3, 0.3)
    # ── 책장(왼쪽 뒤 벽, 140..205 도): 등판·칸·칸막이 + 책
    a0, a1 = 140.0, 205.0
    arc_wall(g, "Wood", Z_FL, 11.0, RI - 0.45, RI - 0.05, a0, a1, n=16)
    for z in (Z_FL, 4.3, 6.6, 8.9, 10.8):
        arc_wall(g, "Wood", z, z + 0.25, RI - 1.5, RI - 0.45, a0, a1, n=16)
    for k in range(0, 14):
        aa = a0 + (a1 - a0) * k / 13
        L.transformed(g, polar_m(aa, RI - 0.95), lambda t: t["Wood"].box(0, 0, (Z_FL + 11.0) / 2, 0.3, 1.1, 11.0 - Z_FL))
    cols = ["Banner", "Leather", "SignBlue", "SignTeal", "SignGold", "Canvas", "Wood", "SignPurple", "Copper"]
    n = 0
    for zb in (Z_FL + 0.25, 4.55, 6.85, 9.15):
        aa = a0 + 1.2
        while aa < a1 - 1.0:
            hgt = 1.35 + 0.45 * ((n * 7) % 5) / 4
            wid = 0.32 + 0.12 * ((n * 3) % 3)
            tilt = 0.18 if n % 11 == 5 else 0.0
            col = cols[(n * 5) % len(cols)]
            L.transformed(g, polar_m(aa, RI - 1.0), lambda t, c=col, w=wid, h=hgt, b=zb, tl=tilt:
                          t[c].obox(0, 0, b + h / 2, w, 0.85, h, ry=tl))
            aa += math.degrees((wid + 0.06) / (RI - 1.0)) * (1.6 if tilt else 1.0)
            n += 1
    # ── 별지도(오른쪽 앞 벽 210 도 → 안쪽 벽면) + 책상과 의자(왼쪽 앞)
    def starmap(t):
        L.transformed(t, Matrix.Rotation(math.pi / 2, 4, "X"), lambda q: (
            q["Canvas"].cyl(0, 7.5, -0.12, 3.0, 3.0, 0.12, seg=40),
            S.ring(q, "Brass", 0, 7.5, -0.18, 3.0, 3.35, 0.2, n=40)))
        for k in range(26):
            a = k * 2.399
            rr = 2.6 * math.sqrt((k + 0.5) / 26)
            t["Glow"].box(rr * math.cos(a), 0.12, 7.5 + rr * math.sin(a), 0.14, 0.06, 0.14)
        for k in range(4):
            t["Iron"].obox(0, 0.1, 7.5, 5.8, 0.03, 0.05, ry=k * math.pi / 4)
    L.transformed(g, polar_m(232.0, RI - 0.05), starmap)
    dx, dy = -13.2, -6.8
    g["Wood"].obox(dx, dy, 5.0, 5.2, 2.6, 0.3, rz=R(35))
    for sx in (-1, 1):
        for sy in (-1, 1):
            c, s_ = math.cos(R(35)), math.sin(R(35))
            g["Wood"].box(dx + c * sx * 2.3 - s_ * sy * 1.1, dy + s_ * sx * 2.3 + c * sy * 1.1, Z_FL + 1.4, 0.3, 0.3, 2.8)
    g["Canvas"].obox(dx + 0.4, dy - 0.2, 5.17, 2.4, 1.6, 0.04, rz=R(28))
    g["Brass"].obox(dx - 1.4, dy + 0.4, 5.4, 0.9, 0.1, 0.9, rz=R(35), rx=0.3)
    g["Glass"].cyl(dx - 1.9, dy - 0.6, 5.15, 0.22, 0.22, 0.35, seg=10)
    g["Wood"].obox(dx + 1.9, dy - 2.6, 3.1, 1.6, 1.6, 0.25, rz=R(35))
    g["Wood"].obox(dx + 2.4, dy - 3.25, 4.4, 1.6, 0.2, 2.4, rz=R(35))
    # ── 안 불빛(벽 등 넷: 놋쇠 받침 + 불빛 등)
    for a in (60.0, 120.0, 200.0, 330.0):
        L.transformed(g, polar_m(a, RI), lambda t: (t["Brass"].box(0, 0.6, 10.5, 0.3, 1.2, 0.3),
                                                  t["Glow"].box(0, 1.2, 10.0, 0.6, 0.6, 0.9),
                                                  t["Iron"].box(0, 1.2, 10.6, 0.8, 0.8, 0.2),
                                                  t["LampPt"].box(0, 1.6, 10.0, 0.3, 0.3, 0.3)))
    for a in (90.0, 180.0, 0.0):
        L.transformed(g, polar_m(a, RI), lambda t: t["LampPt"].box(0, 2.5, 19.5, 0.3, 0.3, 0.3))


# ------------------------------------------------------------------ 돔(돈다)
def observatory_dome(g):
    cz = DOME_CZ
    shell = _hemi_shell_obj("dome_shell", DOME_RO, DOME_RI, cz)
    cut = _box_obj("dome_cut", -SLIT, SLIT, -DOME_RO - 2, SLIT_BACK_Y, cz - 1, cz + DOME_RO + 2)
    boolean_into(g, "Verdigris", shell, [cut], "DIFFERENCE")
    # 걷힌 덧문 둘(구리, 틈 양옆 위에 겹쳐 앉음)
    for s in (-1, 1):
        sh = _hemi_shell_obj("shutter", DOME_RO + 0.75, DOME_RO + 0.15, cz, na=96, nl=24)
        x0, x1 = sorted((s * (SLIT + 0.25), s * (2 * SLIT + 0.75)))
        keep = _box_obj("shutter_keep", x0, x1, -DOME_RO - 2, SLIT_BACK_Y, cz + 0.6, cz + DOME_RO + 2)
        boolean_into(g, "Copper", sh, [keep], "INTERSECT")
    # 틈 가장자리 놋쇠 테(양옆), 아래 문턱
    for s in (-1, 1):
        x = s * (SLIT + 0.05)
        rr = math.sqrt((DOME_RO + 0.05) ** 2 - x * x)
        pts = []
        g0 = 0.0
        g1 = math.pi / 2 + math.asin(SLIT_BACK_Y / rr)   # 천정 너머 뒤쪽 끝(y = SLIT_BACK_Y)
        for k in range(41):
            gm = g0 + (g1 - g0) * k / 40
            pts.append((x, -rr * math.cos(gm), cz + rr * math.sin(gm)))
        sweep(g, "Brass", pts, 0.28, seg=8)
    g["Brass"].box(0, -(DOME_RO - 0.2), cz + 0.3, 2 * SLIT + 0.6, 0.9, 0.6)
    # 갈비살(밖, 구리) + 위도 고리 + 돔 밑 테·치마
    for az in [22.5 * k for k in range(16)]:
        pts = []
        for k in range(0, 31):
            el = R(90.0 * k / 30)
            p = Vector(((DOME_RO + 0.12) * math.cos(el) * math.cos(R(az)), (DOME_RO + 0.12) * math.cos(el) * math.sin(R(az)),
                        cz + (DOME_RO + 0.12) * math.sin(el)))
            if in_slit_zone(p, 2 * SLIT + 1.3):
                break
            pts.append(p)
        if len(pts) > 2:
            sweep(g, "Copper", pts, 0.2, seg=6)
    for el_d in (28.0, 54.0):
        el = R(el_d)
        rr = (DOME_RO + 0.12) * math.cos(el)
        run = []
        for k in range(0, 91):
            a = 2 * math.pi * k / 90
            p = Vector((rr * math.cos(a), rr * math.sin(a), cz + (DOME_RO + 0.12) * math.sin(el)))
            if in_slit_zone(p, 2 * SLIT + 1.3):
                if len(run) > 2:
                    sweep(g, "Copper", run, 0.16, seg=6)
                run = []
            else:
                run.append(p)
        if len(run) > 2:
            sweep(g, "Copper", run, 0.16, seg=6)
    S.ring(g, "Copper", 0, 0, cz - 0.05, DOME_RO - 0.15, DOME_RO + 0.4, 0.55, n=72)
    S.ring(g, "Iron", 0, 0, Z_TOP + 0.3, DOME_RI - 0.1, DOME_RO + 0.2, cz - Z_TOP - 0.3, n=72)
    # 안쪽 갈비살(무쇠) — 안에서 올려다볼 때
    for az in range(0, 360, 20):
        pts = []
        for k in range(0, 31):
            el = R(90.0 * k / 30)
            p = Vector(((DOME_RI - 0.15) * math.cos(el) * math.cos(R(az)), (DOME_RI - 0.15) * math.cos(el) * math.sin(R(az)),
                        cz + (DOME_RI - 0.15) * math.sin(el)))
            if in_slit_zone(p, SLIT + 0.5):
                break
            pts.append(p)
        if len(pts) > 2:
            sweep(g, "Iron", pts, 0.18, seg=6)
    # 돔 바퀴(밑 테 안쪽, 8)
    for k in range(8):
        a = 2 * math.pi * k / 8
        g["Brass"].hcyl(21.5 * math.cos(a), 21.5 * math.sin(a), Z_TOP + 0.6, 0.35, 0.5, axis="x", seg=12, rz=a + math.pi / 2)


# ------------------------------------------------------------------ 망원경(극축 둘레로 돈다)
def observatory_scope(g):
    ym = P.cross(D0)
    mount = basis(D0, ym, P, H)

    def ra_dec(t):
        # 적경 톱니바퀴(놋쇠, 48 이) + 살 + 극축 끝 굴대
        S.gear(t, "Brass", 0, 0, -0.55, 2.9, 48, 0.5, axis="z")
        for k in range(6):
            a = 2 * math.pi * k / 6
            t["Iron"].obox(1.3 * math.cos(a), 1.3 * math.sin(a), -0.25, 2.0, 0.28, 0.12, rz=a)
        t["IronLight"].cyl(0, 0, -1.0, 0.85, 0.85, 1.0, seg=20)
        # 적위축 통 + 놋쇠 테 + 이음 덩이
        t["Iron"].box(0, 0, -0.35, 2.4, 2.4, 1.3)
        t["Iron"].hcyl(0, 0, 0.2, 1.15, 3.2, axis="x", seg=24)
        for x in (-1.65, 1.65):
            t["Brass"].hcyl(x, 0, 0.2, 1.35, 0.3, axis="x", seg=24)
        # 적위 눈금판
        t["Brass"].hcyl(1.95, 0, 0.2, 1.9, 0.15, axis="x", seg=36)
        for k in range(24):
            a = 2 * math.pi * k / 24
            t["Iron"].obox(2.05, 1.65 * math.cos(a), 0.2 + 1.65 * math.sin(a), 0.05, 0.08, 0.35 if k % 3 == 0 else 0.2, rx=a)
        t["IronLight"].hcyl(2.6, 0, 0.2, 0.55, 1.2, axis="x", seg=16)
        # 균형추 막대 + 추 둘 + 멈춤 고리
        t["IronLight"].hcyl(-5.3, 0, 0.2, 0.32, 7.4, axis="x", seg=12)
        for x in (-6.3, -8.0):
            t["Iron"].hcyl(x, 0, 0.2, 1.75, 1.45, axis="x", seg=28)
            for dx in (-0.75, 0.75):
                t["Brass"].hcyl(x + dx, 0, 0.2, 1.8, 0.12, axis="x", seg=28)
        t["Brass"].hcyl(-9.15, 0, 0.2, 0.55, 0.4, axis="x", seg=12)
        t["Brass"].hcyl(-9.4, 0, 0.2, 0.25, 0.3, axis="x", seg=10)

    L.transformed(g, mount, ra_dec)
    # 극축 굴대(통 끝에서 머리까지)
    S.tube(g, "IronLight", H - 1.1 * P, H - 0.4 * P, 0.8, seg=20)
    # 경통 틀: z = 광축(별 쪽), x = 적위축
    zt = S0
    yt = zt.cross(D0)
    tube_m = basis(D0, yt, zt, H + OFF * D0 + 0.2 * P)

    def ota(t):
        # 받침판(적위축 끝) + 경통 고리 둘(무쇠) + 죔쇠
        t["Iron"].box(-1.75, 0, 0.6, 0.3, 1.4, 5.6)
        for z in (-1.4, 2.6):
            S.ring(t, "Iron", 0, 0, z - 0.3, 1.47, 1.85, 0.6, n=28)
            t["Brass"].box(0, 1.95, z, 0.5, 0.3, 0.5)
            t["Brass"].box(0, -1.95, z, 0.5, 0.3, 0.5)
        # 경통 몸: 뒤(가늘게) → 가운데 → 앞(굵게). 놋쇠
        t["Brass"].cyl(0, 0, -8.0, 1.15, 1.25, 4.0, seg=32)
        t["Brass"].cyl(0, 0, -4.0, 1.45, 1.45, 10.0, seg=32)
        t["Brass"].cyl(0, 0, 6.0, 1.5, 1.6, 4.9, seg=32)
        t["Soot"].cyl(0, 0, 10.9, 1.5, 1.5, 0.1, seg=32)
        S.ring(t, "Brass", 0, 0, 11.0, 1.5, 1.78, 0.8, n=32)      # 렌즈 칸
        t["Glass"].cyl(0, 0, 11.3, 1.5, 1.5, 0.15, seg=32)
        S.ring(t, "Copper", 0, 0, 11.8, 1.6, 1.88, 3.7, n=32)     # 차양
        S.ring(t, "Brass", 0, 0, 15.4, 1.6, 2.0, 0.3, n=32)
        for z, r in ((-7.7, 1.33), (-4.15, 1.62), (-0.2, 1.55), (1.6, 1.55), (4.6, 1.6), (8.3, 1.66), (10.8, 1.7)):
            S.ring(t, "Iron", 0, 0, z, r - 0.15, r, 0.3, n=32)
        # 리벳 줄(고리마다 놋쇠 점)
        for z, r in ((-4.0, 1.62), (4.75, 1.6), (8.45, 1.66)):
            for k in range(16):
                a = 2 * math.pi * k / 16
                t["Copper"].box(r * math.cos(a), r * math.sin(a), z, 0.14, 0.14, 0.14)
        # 이름판
        t["Brass"].box(0, 1.47, 2.0 + 1.0, 1.4, 0.08, 2.6)
        t["SignGold"].box(0, 1.52, 3.0, 1.1, 0.06, 2.2)
        # 뒤 끝: 뚜껑 + 초점 장치(놋쇠 빼는 관·손잡이) + 접안경 + 눈받이
        t["Iron"].cyl(0, 0, -8.4, 1.25, 1.25, 0.4, seg=32)
        t["Brass"].cyl(0, 0, -10.2, 0.5, 0.5, 1.8, seg=20)
        t["Brass"].box(0, 0, -9.0, 1.3, 1.0, 0.8)
        t["Brass"].hcyl(0, 0, -9.0, 0.16, 2.6, axis="x", seg=10)
        for s in (-1, 1):
            t["Brass"].hcyl(s * 1.35, 0, -9.0, 0.38, 0.22, axis="x", seg=14)
        t["Iron"].cyl(0, 0, -11.0, 0.38, 0.38, 0.8, seg=16)
        t["Leather"].cyl(0, 0, -11.35, 0.44, 0.44, 0.35, seg=16)
        # 파인더(작은 경통) + 받침 둘
        t["Brass"].cyl(0, 2.15, -5.0, 0.4, 0.42, 10.0, seg=16)
        t["Copper"].cyl(0, 2.15, 5.0, 0.5, 0.5, 0.7, seg=16)
        t["Glass"].cyl(0, 2.15, 5.55, 0.42, 0.42, 0.1, seg=16)
        t["Iron"].cyl(0, 2.15, -5.6, 0.25, 0.25, 0.6, seg=10)
        for z in (-3.0, 3.0):
            t["Iron"].box(0, 1.75, z, 0.3, 0.75, 0.4)
            S.ring(t, "Iron", 0, 2.15, z - 0.15, 0.42, 0.56, 0.3, n=16)
        # 손잡이(뒤쪽 양옆, 놋쇠 고리)
        for s in (-1, 1):
            sweep(t, "Brass", [(s * 1.3, 0, -6.6), (s * 2.0, 0, -6.3), (s * 2.0, 0, -5.1), (s * 1.3, 0, -4.8)], 0.12, seg=8)
        # 김 관(구리): 구동부에서 경통 옆을 따라 — 스팀펑크
        sweep(t, "Copper", [(-1.3, -0.9, -6.0), (-1.75, -1.0, -3.0), (-1.75, -1.0, 4.0), (-1.4, -0.95, 6.5)], 0.14, seg=8)
        t["Brass"].hcyl(-1.85, -1.0, 0.5, 0.35, 0.2, axis="x", seg=14)

    L.transformed(g, tube_m, ota)
    # 적위축 이음 막대(통 → 받침판)
    S.tube(g, "IronLight", H + 1.6 * D0 + 0.2 * P, H + (OFF - 1.6) * D0 + 0.2 * P, 0.5, seg=16)


# ------------------------------------------------------------------ 태양계 모형 팔(넷, 따로 돈다)
ORR_ARMS = [  # (앞머리, 높이, 반지름, 행성 반지름, 재질, 고리?)
    ("OrrA", 7.0, 1.4, 0.22, "Copper", False),
    ("OrrB", 7.6, 2.0, 0.3, "Verdigris", False),
    ("OrrC", 8.25, 2.65, 0.26, "StoneTrim", False),
    ("OrrD", 8.9, 3.25, 0.4, "Brass", True),
]


def orrery_arm(k):
    _, z, r, pr, mat, ringed = ORR_ARMS[k]
    ox, oy = ORRERY
    a = R(40.0 + 97.0 * k)

    def fn(g):
        g["Brass"].cyl(ox, oy, z - 0.12, 0.3, 0.3, 0.24, seg=12)
        g["Brass"].obox(ox + math.cos(a) * r / 2, oy + math.sin(a) * r / 2, z, r, 0.1, 0.1, rz=a)
        px, py = ox + math.cos(a) * r, oy + math.sin(a) * r
        g["Brass"].cyl(px, py, z - 0.55, 0.05, 0.05, 0.6, seg=6)
        sphere(g, mat, (px, py, z - 0.55 - pr), pr, sub=2)
        if ringed:
            S.ring(g, "Brass", px, py, z - 0.55 - pr - 0.03, pr * 1.35, pr * 1.9, 0.06, n=24)
        if k == 1:   # 달
            g["Brass"].obox(px + 0.35, py, z - 0.55 - pr, 0.6, 0.05, 0.05)
            sphere(g, "StoneTrim", (px + 0.68, py, z - 0.55 - pr), 0.09, sub=1)
    return fn


# ================================================================== 놀이터
def play_swing(g):
    for s in (-1, 1):
        x = 7.0 * s
        for yy in (-2.7, 2.7):
            S.tube(g, "Iron", (x, yy, 0.0), (x, 0.0, 9.0), 0.22, seg=10)
            g["Iron"].box(x, yy, 0.1, 0.9, 0.9, 0.2)
        S.tube(g, "IronLight", (x, -1.45, 4.2), (x, 1.45, 4.2), 0.13, seg=8)
        S.gear(g, "Brass", x + s * 0.35, 0.0, 8.1, 0.8, 10, 0.18, axis="x")
    S.tube(g, "Iron", (-7.7, 0, 9.0), (7.7, 0, 9.0), 0.3, seg=14)
    for x in (-7.7, 7.7):
        sphere(g, "Brass", (x, 0, 9.0), 0.42, sub=1)
    for sx in (-2.8, 2.8):
        for cx in (sx - 0.9, sx + 0.9):
            g["Brass"].box(cx, 0, 8.65, 0.25, 0.5, 0.35)
            z = 8.45
            k = 0
            while z > 2.55:
                g["Iron"].obox(cx, 0, z - 0.17, 0.09, 0.2 if k % 2 == 0 else 0.07, 0.36, rz=0.0)
                z -= 0.32
                k += 1
        g["Timber"].box(sx, 0, 2.35, 2.4, 0.95, 0.16)
        g["Iron"].box(sx, 0, 2.22, 2.1, 0.2, 0.1)
        for cx in (sx - 1.2, sx + 1.2):
            g["Brass"].box(cx, 0, 2.38, 0.12, 1.0, 0.24)
    # 바닥 닳은 자리(그네 밑)
    for sx in (-2.8, 2.8):
        g["Soot"].cyl(sx, 0, 0.0, 1.4, 1.4, 0.06, seg=16)


def play_slide(g):
    zp = 6.0
    for sx in (-2.0, 2.0):
        for sy in (-2.0, 2.0):
            g["Iron"].cyl(sx, sy, 0, 0.2, 0.2, 10.6, seg=10)
    g["Timber"].box(0, 0, zp, 4.6, 4.6, 0.3)
    g["Iron"].box(0, 0, zp - 0.3, 4.4, 4.4, 0.3)
    S.pyramid(g, "RoofMetal", 0, 0, 10.6, 5.4, 5.4, 2.4)
    S.pyramid(g, "SnowCap", 0, 0, 10.6, 5.4, 5.4, 2.4, frac=0.6, lift=0.25)
    sphere(g, "Brass", (0, 0, 13.3), 0.3, sub=1)
    for sx in (-2.0, 2.0):   # 옆 난간
        for zz in (zp + 1.3, zp + 2.6):
            S.tube(g, "Iron", (sx, -2.0, zz), (sx, 2.0, zz), 0.08, seg=8)
        for yy in (-1.0, 0.0, 1.0):
            S.tube(g, "IronLight", (sx, yy, zp + 0.15), (sx, yy, zp + 2.6), 0.05, seg=6)
    for sx in (-2.0, 2.0):   # 뒤 난간(가운데 사다리 자리 비움)
        S.tube(g, "Iron", (sx, 2.0, zp + 2.6), (sx * 0.45, 2.0, zp + 2.6), 0.08, seg=8)
    # 사다리(뒤 +y)
    for sx in (-0.75, 0.75):
        S.tube(g, "Iron", (sx, 4.4, 0.0), (sx, 2.05, zp + 2.0), 0.12, seg=8)
    k = 1
    while k * 0.85 < zp:
        z = k * 0.85
        y = 4.4 - (4.4 - 2.05) * z / (zp + 2.0)
        S.tube(g, "Brass", (-0.75, y, z), (0.75, y, z), 0.08, seg=8)
        k += 1
    # 미끄럼판(구리 홈통): 꼭대기 평평 → 내려와 → 끝 평평
    pts = []
    for i in range(25):
        t = i / 24
        pts.append((0.0, -2.3 - 11.8 * t, 0.65 + (zp + 0.15 - 0.65) * (math.cos(math.pi * t) + 1) / 2))
    ribbon(g, "Copper", pts, (1, 0, 0), 2.1, 0.16)
    for sx in (-1, 1):
        side = [(sx * 1.1, y, z + 0.38) for _, y, z in pts]
        ribbon(g, "Copper", side, (0, 0, 1), 0.8, 0.12) if False else None
        wall = []
        for (_, y, z) in pts:
            wall.append((sx * 1.1, y, z + 0.35))
        # 옆벽: 세운 띠(옆 = z) — 꺾은선마다 세로 판
        for (a, b) in zip(wall, wall[1:]):
            mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
            ln = math.hypot(b[1] - a[1], b[2] - a[2])
            rx = math.atan2(b[2] - a[2], b[1] - a[1])
            g["Copper"].obox(mid[0], mid[1], mid[2], 0.12, ln + 0.05, 0.75, rx=rx)
        sweep(g, "Brass", [(sx * 1.1, y, z + 0.75) for _, y, z in pts], 0.09, seg=8)
    # 홈통 다리
    for t in (0.35, 0.65):
        y = -2.3 - 11.8 * t
        z = 0.65 + (zp + 0.15 - 0.65) * (math.cos(math.pi * t) + 1) / 2
        for sx in (-0.8, 0.8):
            g["Iron"].cyl(sx, y, 0, 0.12, 0.12, z - 0.1, seg=8)
    S.gear(g, "Brass", 0, -2.32, zp + 1.4, 0.75, 10, 0.15, axis="y")


def play_seesaw(g):
    for s in (-1, 1):
        g["Iron"].obox(s * 0.7, -0.6, 0.85, 0.25, 0.25, 1.9, rx=0.35)
        g["Iron"].obox(s * 0.7, 0.6, 0.85, 0.25, 0.25, 1.9, rx=-0.35)
    g["Iron"].box(0, 0, 0.1, 2.0, 2.2, 0.2)
    g["Iron"].hcyl(0, 0, 1.7, 0.2, 1.8, axis="x", seg=10)
    for s in (-1, 1):
        S.gear(g, "Brass", s * 0.95, 0, 1.7, 0.55, 10, 0.12, axis="x")
    tilt = 0.13
    M = Matrix.Translation((0, 0, 1.9)) @ Matrix.Rotation(tilt, 4, "X")

    def plank(t):
        t["Timber"].box(0, 0, 0, 1.0, 12.0, 0.22)
        t["Iron"].box(0, 0, -0.16, 0.5, 2.0, 0.12)
        for sy in (-1, 1):
            t["Leather"].box(0, sy * 5.2, 0.2, 0.95, 1.3, 0.2)
            for sx in (-0.4, 0.4):
                t["Iron"].cyl(sx, sy * 4.2, 0.1, 0.06, 0.06, 1.0, seg=6)
            S.tube(t, "Brass", (-0.45, sy * 4.2, 1.05), (0.45, sy * 4.2, 1.05), 0.08, seg=8)
    L.transformed(g, M, plank)


def play_round_base(g):
    g["Stone"].cyl(0, 0, 0, 1.6, 1.4, 0.45, seg=20)
    g["Iron"].cyl(0, 0, 0.45, 0.6, 0.6, 0.2, seg=16)


def play_round(g):
    g["IronLight"].cyl(0, 0, 0.55, 4.5, 4.5, 0.3, seg=40)
    S.gear(g, "Brass", 0, 0, 0.6, 4.78, 40, 0.2, axis="z")
    cols = ["SignRed", "SignGold", "SignBlue"]
    for k in range(6):
        sector(g, cols[k % 3], 1.0, 4.3, 60 * k + 4, 60 * k + 56, 0.85, 0.9, n=8)
    g["Iron"].cyl(0, 0, 0.85, 0.35, 0.3, 2.8, seg=14)
    sphere(g, "Brass", (0, 0, 3.75), 0.5, sub=2)
    for k in range(6):
        a = 2 * math.pi * k / 6
        c, s = math.cos(a), math.sin(a)
        sweep(g, "Iron", [(0.35 * c, 0.35 * s, 3.4), (2.4 * c, 2.4 * s, 3.15), (3.9 * c, 3.9 * s, 2.7), (4.15 * c, 4.15 * s, 2.0),
                          (4.15 * c, 4.15 * s, 0.9)], 0.1, seg=8)


def play_dome(g):
    rr = 4.6
    for k in range(12):
        az = 2 * math.pi * k / 12
        sweep(g, "Iron", [(rr * math.cos(el) * math.cos(az), rr * math.cos(el) * math.sin(az), rr * math.sin(el))
                          for el in [math.pi / 2 * i / 12 for i in range(13)]], 0.1, seg=6, cap=False)
    for el_d in (0.0, 22.5, 45.0, 67.5):
        el = R(el_d)
        sweep(g, "Iron" if el_d else "Brass", [(rr * math.cos(el) * math.cos(a), rr * math.cos(el) * math.sin(a), rr * math.sin(el) + (0.05 if el_d == 0 else 0))
                                               for a in [2 * math.pi * i / 48 for i in range(49)]], 0.12 if el_d == 0 else 0.1, seg=6)
        if el_d:
            for k in range(12):
                az = 2 * math.pi * k / 12
                sphere(g, "Brass", (rr * math.cos(el) * math.cos(az), rr * math.cos(el) * math.sin(az), rr * math.sin(el)), 0.17, sub=1)
    sphere(g, "Brass", (0, 0, rr), 0.25, sub=1)


def park_bench(g):
    for s in (-1, 1):
        x = 2.8 * s
        g["Iron"].obox(x, -0.55, 0.85, 0.18, 0.18, 1.8, rx=-0.15)
        g["Iron"].obox(x, 0.45, 0.9, 0.18, 0.18, 1.85, rx=0.18)
        g["Iron"].box(x, -0.05, 1.65, 0.16, 1.4, 0.16)
        sweep(g, "Iron", [(x, 0.5, 1.6), (x, 0.62, 2.4), (x, 0.75, 3.3)], 0.09, seg=6)
        sweep(g, "Iron", [(x, -0.75, 2.3), (x, -0.4, 2.45), (x, 0.3, 2.4), (x, 0.55, 2.2)], 0.08, seg=6)
    for k in range(4):
        g["Timber"].box(0, -0.6 + 0.33 * k, 1.78, 6.0, 0.27, 0.12)
    for k in range(3):
        g["Timber"].obox(0, 0.62 + 0.04 * k, 2.25 + 0.36 * k, 6.0, 0.1, 0.27, rx=-0.2)
    g["SnowCap"].box(-1.2, -0.35, 1.88, 2.4, 0.7, 0.08)
    g["SnowCap"].box(1.7, -0.25, 1.88, 1.2, 0.5, 0.06)


def snowman(g):
    sphere(g, "SnowCap", (0, 0, 1.3), 1.6, sub=3)
    sphere(g, "SnowCap", (0, 0, 3.55), 1.15, sub=3)
    sphere(g, "SnowCap", (0, 0, 5.15), 0.8, sub=3)
    for s in (-1, 1):
        sphere(g, "Soot", (s * 0.28, -0.7, 5.35), 0.09, sub=1)
    for z in (3.2, 3.65, 4.1):
        sphere(g, "Soot", (0, -1.12 + (z - 3.55) ** 2 * 0.25, z), 0.1, sub=1)
    cone(g, "Copper", (0, -0.72, 5.15), (0, -1.5, 5.1), 0.13, seg=10)
    g["Iron"].cyl(0, 0, 5.78, 0.8, 0.8, 0.1, seg=20)
    g["Iron"].cyl(0, 0, 5.88, 0.5, 0.52, 1.0, seg=20)
    g["Banner"].cyl(0, 0, 5.92, 0.53, 0.53, 0.18, seg=20)
    S.ring(g, "Banner", 0, 0, 4.25, 0.62, 0.92, 0.3, n=20)
    g["Banner"].obox(0.45, -0.75, 3.85, 0.4, 0.12, 0.9, ry=0.2)
    for s in (-1, 1):
        sweep(g, "Timber", [(s * 1.0, 0, 3.8), (s * 1.9, 0.1, 4.4), (s * 2.5, 0.1, 5.1)], 0.07, seg=5)
        sweep(g, "Timber", [(s * 1.9, 0.1, 4.4), (s * 2.3, 0.1, 4.4)], 0.05, seg=5)


def sled(g):
    for s in (-1, 1):
        sweep(g, "Brass", [(s * 0.7, 2.0, 0.1), (s * 0.7, -1.6, 0.1), (s * 0.7, -2.1, 0.35), (s * 0.7, -2.2, 0.75), (s * 0.7, -1.9, 0.9)], 0.07, seg=6)
        for y in (-1.2, 0.0, 1.2):
            g["Iron"].box(s * 0.7, y, 0.4, 0.1, 0.1, 0.6)
    for k in range(5):
        g["Timber"].box(0, -1.4 + 0.7 * k, 0.75, 1.7, 0.55, 0.1)
    g["Iron"].box(0, -1.6, 0.85, 1.6, 0.1, 0.1)
    sweep(g, "Banner", [(0, -1.9, 0.9), (0.4, -2.6, 0.5), (0.9, -3.2, 0.05)], 0.04, seg=5)


JOBS = [
    ("Observatory", "Obs", observatory),
    ("Observatory_Dome", "ObsDome", observatory_dome),
    ("Observatory_Scope", "ObsScope", observatory_scope),
    ("Orrery_A", "OrrA", orrery_arm(0)),
    ("Orrery_B", "OrrB", orrery_arm(1)),
    ("Orrery_C", "OrrC", orrery_arm(2)),
    ("Orrery_D", "OrrD", orrery_arm(3)),
    ("Play_Swing", "PSwing", play_swing),
    ("Play_Slide", "PSlide", play_slide),
    ("Play_Seesaw", "PSaw", play_seesaw),
    ("Play_RoundBase", "PRoundB", play_round_base),
    ("Play_Round", "PRound", play_round),
    ("Play_Dome", "PDome", play_dome),
    ("Park_Bench", "PBench", park_bench),
    ("Snowman", "PSnow", snowman),
    ("Sled", "PSled", sled),
]

if __name__ == "__main__":
    # 로블록스 쪽 상수(Snow_City2.luau OBS_SCRIPT 에 옮겨 적는 값)
    def rb(v):
        return "Vector3.new(%.4f, %.4f, %.4f)" % (-v.x, v.z, v.y)
    print("H", rb(H), "P", rb(P), "S0", rb(S0), "ORRERY", rb(Vector((ORRERY[0], ORRERY[1], 0))))
