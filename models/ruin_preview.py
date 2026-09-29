# -*- coding: utf-8 -*-
"""ruin_preview.py — 폐허 틀 몇 개를 나란히 세워 찍는다.  blender -b -P ruin_preview.py -- <출력.png> <모델...>"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import build_roman as B  # noqa: E402
import roman_lib as R  # noqa: E402
import ruin_lib as RU  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out, names = args[0], args[1:]
L.clear_scene()
jobs = {j[0]: j for j in B.JOBS}
x = 0.0
for name in names:
    seed = 2 if name.endswith("_2") else 1
    base = name[:-2] if name.endswith("_2") else name
    _, prefix, fn, _ = jobs[base]
    g = R.G(prefix + ("2" if seed == 2 else ""))
    fn(g)
    mode, opts = RU.SPEC.get(base, ("none", {}))
    print(name, RU.apply(g, mode, seed=seed * 17 + len(base), **opts))
    objs = []
    for k in R.PALETTE:
        ob = g[k].finish()
        if len(ob.data.polygons) == 0 or k in ("Vent", "LampPt"):
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        objs.append(ob)
    xs = [ob.matrix_world @ v.co for ob in objs for v in ob.data.vertices]
    w = max(v.x for v in xs) - min(v.x for v in xs)
    for ob in objs:
        ob.location.x += x + w / 2
    x += w + 8
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_shadows = True
sc.display.shading.show_cavity = True
sc.world = bpy.data.worlds.new("W")
sc.world.color = (0.42, 0.45, 0.5)
sc.render.resolution_x, sc.render.resolution_y = 1600, 700
bpy.ops.mesh.primitive_plane_add(size=1, location=(x / 2, 0, 0))
pl = bpy.context.active_object
pl.scale = (x + 60, 200, 1)
pl.data.materials.append(L.material("Basalt", R.PALETTE))
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
cam.data.lens = 35
cam.location = Vector((x / 2, -max(130, x * 0.95), max(80, x * 0.55)))
cam.rotation_euler = (Vector((x / 2, 0, 8)) - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.collection.objects.link(cam)
sc.camera = cam
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("찍음", out)
