# -*- coding: utf-8 -*-
"""
roman_preview.py — Studio 에서 내보낸 칼로도르 폴리스(tools/Roman_Export.luau → recv/rexp_*.txt)를
블렌더에서 다시 세워 여러 각도로 찍는다. Studio 뷰포트가 멈췄을 때 눈으로 확인하는 길이다. (2026-09-29)

  G/P 줄 = Studio 파트 그대로(상자·원기둥·공), K 줄 = 틀 피벗 → models/build_roman.py 로 틀을 다시 빚어 놓는다.
  좌표: 로블록스 (X, Y, Z) ↔ 블렌더 (-X, Z, Y). 행렬은 P·A·P (P 는 자기 역행렬).

돌리는 법:
  blender --background --python tools/roman_preview.py -- <rexp 폴더> <출력 폴더> [찍을 이름 ...]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "models"))
import hanok_lib as L  # noqa: E402
import build_roman as B  # noqa: E402
import roman_lib as R  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[0], args[1]
WANT = args[2:]

P = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

SHOTS = {  # 이름: (카메라 로블록스 좌표, 바라볼 곳, 렌즈)
    "overview": ((-600, 720, -1900), (-1300, 60, -2950), 30),
    "overview_n": ((-1900, 650, -3900), (-1250, 60, -2900), 30),
    "giant_front": ((-1320, 118, -3010), (-1320, 100, -2870), 30),
    "giant_side": ((-1170, 135, -2790), (-1320, 95, -2870), 28),
    "palace": ((-1245, 190, -3215), (-1330, 88, -3430), 30),
    "forum": ((-755, 175, -3070), (-872, 80, -3245), 30),
    "legion": ((-1590, 210, -3040), (-1745, 80, -3185), 30),
    "market": ((-750, 160, -2510), (-880, 80, -2615), 32),
    "south": ((-1240, 210, -2215), (-1320, 80, -2380), 30),
    "ruins": ((-1480, 150, -2470), (-1680, 80, -2600), 30),
    "east": ((-610, 170, -2960), (-765, 80, -2940), 30),
    "aqueduct": ((-930, 150, -3620), (-1000, 80, -3450), 32),
    "spring": ((-960, 110, -3650), (-1000, 85, -3570), 30),
    "ash": ((-1150, 95, -3720), (-1200, 45, -3645), 28),
    "ash_top": ((-1230, 120, -3580), (-1190, 50, -3650), 30),
    "fumarole": ((-1420, 95, -3030), (-1440, 50, -2990), 30),
    "lava_close": ((-1180, 90, -3120), (-1320, 50, -3050), 30),
}


def rb(x, y, z):
    return Vector((-x, z, y))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


_mats = {}


def mat_for(rgb, matname, alpha):
    key = (rgb, matname, round(alpha, 2))
    m = _mats.get(key)
    if m is None:
        m = bpy.data.materials.new("M_%d_%d_%d_%s" % (rgb + (matname,)))
        c = [v / 255.0 for v in rgb]
        m.diffuse_color = (c[0], c[1], c[2], 1 - alpha)
        _mats[key] = m
    return m


def unit_mesh(kind):
    me = bpy.data.meshes.new("unit_" + kind)
    bm = bmesh.new()
    if kind == "Block":
        bmesh.ops.create_cube(bm, size=1.0)
    elif kind == "Cylinder":  # 축이 로컬 x, 지름 1, 길이 1
        bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.5, radius2=0.5, depth=1.0)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    else:
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.5)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(None)
    return me


def cf_matrix(nums):
    x, y, z = nums[0:3]
    r = nums[3:12]
    return Matrix(((r[0], r[1], r[2], x), (r[3], r[4], r[5], y), (r[6], r[7], r[8], z), (0, 0, 0, 1)))


def build_kits(names):
    cols = {}
    jobs = {j[0]: j for j in B.JOBS}
    for name in sorted(names):
        _, prefix, fn, _ = jobs[name]
        g = R.G(prefix)
        fn(g)
        col = bpy.data.collections.new("KIT_" + name)
        for k in R.PALETTE:
            ob = g[k].finish()
            if len(ob.data.polygons) == 0 or k in ("Vent", "LampPt"):
                bpy.data.objects.remove(ob, do_unlink=True)
                continue
            for c in list(ob.users_collection):
                c.objects.unlink(ob)
            col.objects.link(ob)
        cols[name] = col
    return cols


def main():
    reset()
    lines = []
    for fn in sorted(os.listdir(SRC)):
        if fn.startswith("rexp_") and fn[5:-4].isdigit():
            lines += [l for l in open(os.path.join(SRC, fn), encoding="utf-8").read().split("\n") if l]
    meshes = {k: unit_mesh(k) for k in ("Block", "Cylinder", "Ball")}
    kits = [l.split("\t") for l in lines if l.startswith("K\t")]
    cols = build_kits({k[1] for k in kits})
    sc = bpy.context.scene
    n = 0
    for l in lines:
        t = l.split("\t")
        if t[0] in ("G", "P"):
            nums = [float(v) for v in t[3].split()]
            sx, sy, sz = [float(v) for v in t[4].split()]
            shape = t[2] if t[2] in meshes else "Block"
            if shape == "Cylinder":
                d = min(sy, sz)
                sy = sz = d
            A = cf_matrix(nums) @ Matrix.Diagonal((sx, sy, sz, 1))
            ob = bpy.data.objects.new("%s_%d" % (t[0], n), meshes[shape])
            ob.matrix_world = P @ A @ P
            ob.material_slots[0].link = "OBJECT"
            ob.material_slots[0].material = mat_for(tuple(int(v) for v in t[5].split()), t[6], float(t[7]))
            sc.collection.objects.link(ob)
        elif t[0] == "K":
            e = bpy.data.objects.new(t[1], None)
            e.instance_type = "COLLECTION"
            e.instance_collection = cols[t[1]]
            e.matrix_world = P @ cf_matrix([float(v) for v in t[2].split()]) @ P
            sc.collection.objects.link(e)
        n += 1
    print("objects", n, "kits", len(kits))

    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_shadows = True
    sc.display.shading.show_cavity = True
    sc.world = bpy.data.worlds.new("W")
    sc.world.color = (0.42, 0.55, 0.66)
    sc.render.resolution_x, sc.render.resolution_y = 1400, 860
    sc.render.image_settings.file_format = "PNG"
    for name in (WANT or list(SHOTS)):
        cam_p, tgt, lens = SHOTS[name]
        cam = bpy.data.objects.new("Cam_" + name, bpy.data.cameras.new("C"))
        cam.data.lens = lens
        cam.data.clip_end = 8000
        cam.location = rb(*cam_p)
        cam.rotation_euler = (rb(*tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(cam)
        sc.camera = cam
        sc.render.filepath = os.path.join(OUT, "roman_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("찍음", name)


main()
