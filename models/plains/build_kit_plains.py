# -*- coding: utf-8 -*-
"""
build_kit_plains.py — 평원(절화) 블렌더 키트: 경계벽 잔해. (2026-10-03)

2026-10-03 사용자: "돌산 같은 것도 기본적으로는 커다란 육면체", "대륙이 사각형 = 곡선 없음"(+ 참고 사진) →
땅·절벽·돌산·바위는 로블록스 Part 상자로 짓고(tools/PlainsNorth_Build.luau), 블렌더는 상자로 안 되는 것만 여기:
  WallRuin_A     경계벽 잔해(세계관: 오염을 막으려 세웠다가 버려진 벽) 40×7, 높이 최대 26, 돌을 켜켜이 쌓고 위가 무너짐
  WallRuin_B     무너진 돌무더기 26×18
  WallRuin_Tower 부서진 둥근 망루 지름 16, 높이 최대 24, 문 구멍
원점 = 바닥 가운데. 메시 이름 "<틀>_<묶음>"(Stone·StoneDark·Rock) — 색·재질은 tools/Plains_Kit.luau.
원점 표지 PlainsKitOrigin_Marker(1×1×1).

돌리는 법: blender -b -P models/plains/build_kit_plains.py [-- render]
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "weapons"))
import wlib as L  # noqa: E402

RENDER = "render" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])


def rgb(r, g, b):
    return (r / 255) ** 2.2, (g / 255) ** 2.2, (b / 255) ** 2.2


GRASS, ROCK, STONE, STONED = rgb(117, 151, 83), rgb(120, 116, 106), rgb(157, 153, 139), rgb(126, 122, 110)


class Piece:
    def __init__(self, name):
        self.name = name
        self.groups = {}

    def g(self, group, color):
        if group not in self.groups:
            self.groups[group] = L.Group("%s_%s" % (self.name, group), color, None)
        return self.groups[group]

    def finish(self):
        return [g.finish() for g in self.groups.values()]


def _rotate(v, yaw, pitch, roll):
    """fromOrientation 순서(Y·X·Z) 돌림(도)"""
    from mathutils import Matrix
    R = Matrix.Rotation(math.radians(yaw), 3, "Y") @ Matrix.Rotation(math.radians(pitch), 3, "X") @ Matrix.Rotation(math.radians(roll), 3, "Z")
    return R @ v


def hexa(piece, center, size, rot=(0, 0, 0), taper=0.9, jit=0.06, seed=0, top="Grass", top_slope=None):
    """각진 육면체 하나(꼭짓점 8개를 조금씩 흔들고 위를 좁힌다). 윗면은 top 묶음(풀), 옆·밑은 바위.
    top_slope = (앞 높이 비율, 뒤 높이 비율) 이면 윗면이 앞(-Z)에서 뒤(+Z)로 기운 쐐기(오르막)."""
    rnd = random.Random(seed)
    sx, sy, sz = size
    m = min(sx, sy, sz) * jit
    corners = []
    for yi, y in enumerate((-sy / 2, sy / 2)):
        k = 1 if yi == 0 else taper
        for xs, zs in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            yy = y
            if yi == 1 and top_slope:
                f, r = top_slope
                yy = -sy / 2 + sy * (f if zs < 0 else r)
            v = Vector((xs * sx / 2 * k + rnd.uniform(-m, m), yy + (rnd.uniform(-m, m) if yi else 0), zs * sz / 2 * k + rnd.uniform(-m, m)))
            corners.append(Vector(center) + _rotate(v, *rot))
    c = [tuple(v) for v in corners]
    rock = piece.g("Rock", ROCK)
    rock.add(c, [(0, 3, 2, 1), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])
    tg = piece.g(top, GRASS) if top == "Grass" else piece.g(top, ROCK)
    tg.add(c, [(4, 5, 6, 7)])


def stone(p, rnd, center, size, rot=(0, 0, 0)):
    grp = p.g("StoneDark", STONED) if rnd.random() < 0.35 else p.g("Stone", STONE)
    L.bbox(grp, center, size, 0.18, rot, seg=1)


def wall_ruin(name, seed, length=40.0, thick=7.0, hmax=26.0):
    """돌을 켜켜이 쌓은 벽. 켜마다 줄눈이 엇갈리고, 윗선이 무너져 들쭉날쭉(가운데가 크게 무너짐)"""
    rnd = random.Random(seed)
    p = Piece(name)
    course = 2.6
    ncourse = int(hmax / course)
    # 무너진 윗선: 끝이 높고 가운데가 낮은 들쭉날쭉한 높이
    def top_at(x):
        u = (x + length / 2) / length
        return hmax * (0.35 + 0.65 * abs(u - 0.42) ** 0.8 * 1.6) * (0.85 + 0.15 * math.sin(x * 1.7 + seed))
    for k in range(ncourse):
        y = k * course + course / 2
        x = -length / 2 + (rnd.uniform(0.8, 2.4) if k % 2 else 0)
        while x < length / 2 - 0.5:
            w = rnd.uniform(2.6, 4.4)
            w = min(w, length / 2 - x)
            cx = x + w / 2
            if y < top_at(cx) and not (k > 2 and rnd.random() < 0.05):
                for side in (-1, 1):
                    stone(p, rnd, (cx, y, side * thick / 4), (w - 0.18, course - 0.16, thick / 2 - 0.12))
            x += w
    # 벽 위에서 떨어진 돌 몇
    for _ in range(9):
        x = rnd.uniform(-length / 2, length / 2)
        stone(p, rnd, (x, 0.9, rnd.choice((-1, 1)) * rnd.uniform(thick * 0.7, thick * 1.6)), (rnd.uniform(2, 3.6), 1.8, rnd.uniform(1.6, 2.4)),
              (rnd.uniform(-12, 12), rnd.uniform(0, 90), rnd.uniform(-12, 12)))
    return p


def rubble(name, seed):
    rnd = random.Random(seed)
    p = Piece(name)
    for _ in range(26):
        r = rnd.uniform(0, 1) ** 0.6
        a = rnd.uniform(0, math.tau)
        x, z = math.cos(a) * r * 13, math.sin(a) * r * 9
        h = (1 - r) * 5
        stone(p, rnd, (x, h + 0.8, z), (rnd.uniform(2.2, 4.2), rnd.uniform(1.6, 2.6), rnd.uniform(1.8, 3.2)),
              (rnd.uniform(-25, 25), rnd.uniform(0, 180), rnd.uniform(-25, 25)))
    hexa(p, (0, 1.5, 0), (14, 3.5, 10), (20, 0, 0), taper=0.8, jit=0.12, seed=seed + 99, top="Rock")
    return p


def tower(name, seed, R=8.0, hmax=24.0):
    rnd = random.Random(seed)
    p = Piece(name)
    course, n = 2.6, 18
    for k in range(int(hmax / course)):
        y = k * course + course / 2
        off = 0.5 if k % 2 else 0
        for i in range(n):
            a = math.tau * (i + off) / n
            # 무너진 윗선 + 문 구멍(아군 쪽 -Z, 아래 세 켜)
            broken = hmax * (0.55 + 0.45 * (0.5 + 0.5 * math.cos(a - 0.9))) * (0.9 + 0.1 * rnd.random())
            door = abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) < 0.3 and k < 4
            if y > broken or door:
                continue
            w = math.tau * R / n - 0.2
            stone(p, rnd, (math.cos(a) * R, y, math.sin(a) * R), (1.6, course - 0.16, w), (0, -math.degrees(a), 0))
    for _ in range(8):
        a = rnd.uniform(0, math.tau)
        r = R + rnd.uniform(1.5, 5)
        stone(p, rnd, (math.cos(a) * r, 0.9, math.sin(a) * r), (rnd.uniform(2, 3.4), 1.8, rnd.uniform(1.6, 2.4)), (rnd.uniform(-15, 15), rnd.uniform(0, 180), 0))
    return p


KIT = [
    lambda: wall_ruin("WallRuin_A", 61),
    lambda: rubble("WallRuin_B", 62),
    lambda: tower("WallRuin_Tower", 63),
]


def render_sheet(pieces, out):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.show_cavity = True
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.55, 0.68, 0.8)
    scene.render.resolution_x = scene.render.resolution_y = 600
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    paths = []
    for name, objs in pieces:
        for ob in bpy.data.objects:
            if ob.type == "MESH":
                ob.hide_render = ob not in objs
        pts = [ob.matrix_world @ Vector(c) for ob in objs for c in ob.bound_box]
        lo = Vector((min(q.x for q in pts), min(q.y for q in pts), min(q.z for q in pts)))
        hi = Vector((max(q.x for q in pts), max(q.y for q in pts), max(q.z for q in pts)))
        mid, size = (lo + hi) / 2, (hi - lo).length
        cam.data.ortho_scale = size * 0.85
        d = Vector((0.55, -0.7, 0.45)).normalized()
        cam.location = mid + d * size * 2
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(out, name + ".png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    allobjs, pieces = [], []
    for make in KIT:
        p = make()
        objs = p.finish()
        for ob in objs:
            assert L.tri_count(ob) <= 20000, ob.name
        print("  %-15s %d 조각, %d tri" % (p.name, len(objs), sum(L.tri_count(o) for o in objs)))
        pieces.append((p.name, objs))
        allobjs += objs
    mk = L.Group("PlainsKitOrigin_Marker", (1, 0, 1), None)
    L.bbox(mk, (0, 0, 0), (1, 1, 1))
    marker = mk.finish()
    marker.hide_render = True
    if RENDER:
        out = os.path.join(HERE, "render")
        os.makedirs(out, exist_ok=True)
        print("RENDERS", render_sheet(pieces, out))
    bpy.ops.object.select_all(action="DESELECT")
    for ob in allobjs + [marker]:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = marker
    fbx = os.path.join(HERE, "PlainsKit.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             axis_forward="-Z", axis_up="Y", object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
                             bake_space_transform=False)
    print("objects %d  FBX: %s" % (len(allobjs) + 1, fbx))


main()
