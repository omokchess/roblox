# -*- coding: utf-8 -*-
"""
build_callisto_space.py — 2026-11-01. 칼리스토 2·3페이즈 전투 배경 우주(블렌더). 사용자: "2·3페이즈로 넘어가면 배경이 우주 —
다른 플레이어도 전투 칸 위에 서면 보임, 우주는 블렌더로, 전투 구역 위에 있지 않으면 안 보임(스카이 스피어·스카이박스 금지)" ·
"3페이즈엔 우리은하가 전투 필드 아래에 생겨나야".

원점 = 전투 필드 가운데(블렌더 z 위 = 로블록스 Y). 닫힌 구(스카이 스피어)가 아니라 흩어진 물체들:
  Space_*   별 2400(흰·푸른·금빛 팔면체, 반지름 140~360 껍질에 흩음) + 별무리 6(플레이아데스처럼 촘촘한 작은 별) ·
            성운 6(울퉁불퉁한 덩어리 — 로블록스에선 반투명 네온) · 행성 셋(띠 무늬 가스 행성 + 고리 · 푸른 얼음 행성 · 붉은 작은 행성 + 달)
  Galaxy_*  우리은하(3페이즈 — 필드 아래 z -28): 금빛 팽대부 + 로그 나선 팔 넷(안쪽 금빛 → 바깥 푸른 별) + 옅은 원반
돌리기: blender -b -P models/build_callisto_space.py  →  models/CallistoSpace.fbx  →  Ctrl+M  →  tools/Callisto_Space.luau
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402

PAL = {
    "StarWhite": "#F2F6FF", "StarBlue": "#9CC4FF", "StarGold": "#FFD98A",
    "NebulaViolet": "#7A4CE0", "NebulaBlue": "#3C6CE0", "NebulaPink": "#D65CB0",
    "PlanetBand": "#C9A27A", "PlanetBand2": "#8E6A4E", "PlanetIce": "#7FB6E6", "PlanetRed": "#B5523C", "Moon": "#B8B6B0",
    "Ring": "#E6D3A8", "GalaxyCore": "#FFE2A8", "GalaxyBlue": "#A8C8FF", "GalaxyGold": "#FFCF8A", "GalaxyHaze": "#8C6CF0",
}
RNG = random.Random(20261101)


def octa(g, mat, x, y, z, r, flat=1.0):
    """팔면체 별 하나(삼각형 8)."""
    v = [(x + r, y, z), (x - r, y, z), (x, y + r, z), (x, y - r, z), (x, y, z + r * flat), (x, y, z - r * flat)]
    f = [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)]
    g[mat].add_mesh(v, f)


def blob(g, mat, c, size, subdiv=2, noise=0.22):
    """울퉁불퉁한 덩어리(성운)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    for v in bm.verts:
        k = 1 + (RNG.random() - 0.5) * 2 * noise
        v.co = Vector((v.co.x * size[0] * k, v.co.y * size[1] * k, v.co.z * size[2] * k)) + Vector(c)
    bm.verts.index_update()
    g[mat].add_mesh([tuple(v.co) for v in bm.verts], [[v.index for v in f.verts] for f in bm.faces])
    bm.free()


def sphere(g, mat, c, r, seg=32, rings=16, squash=1.0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    for v in bm.verts:
        v.co = Vector((v.co.x, v.co.y, v.co.z * squash)) + Vector(c)
    bm.verts.index_update()
    g[mat].add_mesh([tuple(v.co) for v in bm.verts], [[v.index for v in f.verts] for f in bm.faces])
    bm.free()


def annulus(g, mat, c, r0, r1, tilt, seg=64):
    m = Matrix.Translation(Vector(c)) @ Matrix.Rotation(tilt[0], 4, "X") @ Matrix.Rotation(tilt[1], 4, "Y")
    verts, faces = [], []
    for i in range(seg):
        a = i / seg * math.tau
        for r in (r0, r1):
            verts.append(tuple(m @ Vector((math.cos(a) * r, math.sin(a) * r, 0))))
    for i in range(seg):
        j = (i + 1) % seg
        faces.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    g[mat].add_mesh(verts, faces)


def space(g):
    # 별 2400 — 반지름 140~360 껍질에 고르게(방향 = 구면 고른 분포)
    for _ in range(2400):
        u, v = RNG.random() * 2 - 1, RNG.random() * math.tau
        s = math.sqrt(1 - u * u)
        r = 140 + RNG.random() ** 0.7 * 220
        d = (s * math.cos(v), s * math.sin(v), u)
        k = RNG.random()
        mat = "StarWhite" if k < 0.55 else ("StarBlue" if k < 0.85 else "StarGold")
        octa(g, mat, d[0] * r, d[1] * r, d[2] * r, 0.25 + RNG.random() ** 3 * 1.1)
    # 별무리 6(플레이아데스처럼 촘촘)
    for dirv in ((0.7, 0.4, 0.55), (-0.5, 0.7, 0.4), (-0.8, -0.3, 0.45), (0.2, -0.85, 0.3), (0.9, -0.2, 0.1), (-0.1, 0.3, 0.92)):
        d = Vector(dirv).normalized() * (210 + RNG.random() * 60)
        for _ in range(45):
            o = Vector((RNG.gauss(0, 7), RNG.gauss(0, 7), RNG.gauss(0, 5)))
            octa(g, "StarBlue" if RNG.random() < 0.6 else "StarWhite", *(d + o), 0.35 + RNG.random() * 0.5)
    # 성운 6
    for (dirv, size, mat) in (((0.6, 0.75, 0.2), (46, 26, 18), "NebulaViolet"), ((-0.7, 0.5, 0.35), (38, 30, 20), "NebulaBlue"),
                              ((-0.3, -0.8, 0.4), (52, 22, 16), "NebulaPink"), ((0.85, -0.4, 0.3), (34, 24, 22), "NebulaBlue"),
                              ((0.05, 0.95, 0.5), (40, 28, 14), "NebulaPink"), ((-0.9, -0.1, 0.05), (44, 20, 26), "NebulaViolet")):
        c = Vector(dirv).normalized() * 250
        blob(g, mat, c, size)
        blob(g, mat, c + Vector((size[0] * 0.5, -size[1] * 0.3, size[2] * 0.4)), (size[0] * 0.55, size[1] * 0.6, size[2] * 0.7))
    # 행성 셋
    gas = Vector((0.6, 0.7, 0.32)).normalized() * 285
    sphere(g, "PlanetBand", gas, 26)
    for k in range(5):                                       # 띠 무늬(조금 큰 납작 띠)
        sphere(g, "PlanetBand2", gas + Vector((0, 0, -16 + k * 8)), 26.3 * math.cos(math.asin(min(0.95, abs(-16 + k * 8) / 26))), 32, 2, 0.06)
    annulus(g, "Ring", gas, 34, 52, (math.radians(72), math.radians(18)))
    sphere(g, "PlanetIce", Vector((-0.8, 0.32, 0.25)).normalized() * 245, 12)
    red = Vector((0.25, -0.9, 0.38)).normalized() * 205
    sphere(g, "PlanetRed", red, 7, 24, 12)
    sphere(g, "Moon", red + Vector((14, 6, 4)), 2, 16, 8)


def galaxy(g):
    """우리은하: 필드 아래(z -28) 금빛 팽대부 + 로그 나선 팔 넷 + 옅은 원반."""
    cz = -28.0
    sphere(g, "GalaxyCore", (0, 0, cz), 16, 32, 16, 0.38)
    for arm in range(4):
        base = arm * math.pi / 2
        for _ in range(420):
            t = RNG.random() ** 0.8 * 3.2 * math.pi
            r = 14 * math.exp(0.21 * t)
            if r > 135:
                continue
            a = base + t + RNG.gauss(0, 0.16)
            sc = 2 + r * 0.06
            x, y = math.cos(a) * r + RNG.gauss(0, sc), math.sin(a) * r + RNG.gauss(0, sc)
            z = cz + RNG.gauss(0, 1.2 + (1 - r / 135) * 2)
            mat = "GalaxyGold" if r < 45 + RNG.random() * 20 else "GalaxyBlue"
            octa(g, mat, x, y, z, 0.35 + RNG.random() * 0.6, 0.4)
    annulus(g, "GalaxyHaze", (0, 0, cz - 0.5), 8, 138, (0, 0), 96)


if __name__ == "__main__":
    L.clear_scene()
    groups = {"Space": L.new_groups("Space", PAL), "Galaxy": L.new_groups("Galaxy", PAL)}
    space(groups["Space"])
    galaxy(groups["Galaxy"])
    objs, total = [], 0
    for pre, g in groups.items():
        for k in PAL:
            ob = g[k].finish()
            if len(ob.data.polygons) == 0:
                bpy.data.objects.remove(ob, do_unlink=True)
                continue
            tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
            assert tris <= 20000, (ob.name, tris)
            total += tris
            objs.append(ob)
            print("  %-22s %6d tri" % (ob.name, tris))
    print("CallistoSpace %d tri · 오브젝트 %d" % (total, len(objs)))
    m = L.Group("SpaceOrigin_Marker", L.material("StarWhite", PAL))
    m.box(0, 0, 0, 0.4, 0.4, 0.4)
    marker = m.finish()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs + [marker]:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = marker
    fbx = os.path.join(HERE, "CallistoSpace.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             axis_forward="-Z", axis_up="Y", object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
                             bake_space_transform=False)
    print("FBX:", fbx)
