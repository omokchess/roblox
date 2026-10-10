# -*- coding: utf-8 -*-
"""render_inside_preview.py — build_steam_inside.py 건물 미리보기(작업대 렌더). blender -b -P models/render_inside_preview.py [-- 이름...]
out: models/snowtown_render/in_<이름>_*.png"""
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import build_steam_town as T  # noqa: E402
import build_steam_inside as I  # noqa: E402
import build_steam_school as SCH  # noqa: E402
import build_steam_under as UND  # noqa: E402

only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
# 이름: (바깥 카메라, 바라볼 점), [(파일 꼬리, 카메라, 바라볼 점, 렌즈)] — 안 시점은 사람 눈높이
VIEWS = {
    "Frostig_Werk": [("ext", (30, -34, 22), (0, 0, 10), 30), ("in1", (-6, -7.2, 7.2), (3, 5, 5.5), 18), ("in2", (8, 4, 7.2), (-6, -4, 5.0), 18)],
    "Zapfen_Werk": [("ext", (70, -85, 45), (0, 0, 15), 30), ("in1", (0, -18, 8.5), (0, 10, 12), 16), ("in2", (-27, 0, 19.5), (10, -6, 10), 16),
                    ("in3", (20, 4, 8.5), (32, 14, 7), 18)],
    "Figuren_HQ": [("ext", (45, -70, 40), (0, 0, 15), 30), ("in1", (0, -16.5, 8.0), (0, 8, 9), 16), ("in2", (-18, 12, 8.0), (6, -8, 10), 16),
                   ("in3", (0, -13, 7.0), (0, -14, 40), 18)],
    "Sel_Werk_Ruin": [("ext", (34, -38, 26), (0, 0, 8), 30), ("in1", (-7.8, -9, 7.0), (4, 4, 4), 18), ("in2", (10, -6, 7.0), (-6, 6, 3), 18)],
    "Shop_Blue": [("ext", (20, -26, 14), (0, 0, 7), 30), ("in1", (-5, -4.6, 6.6), (3, 4, 4.5), 18)],
    "Shop_Teal": [("in1", (-5, -4.6, 6.6), (3, 4, 4.5), 18), ("in2", (5, 0, 6.6), (-5, -3, 3), 18)],
    "Shop_Red": [("in1", (-5, -4.6, 6.6), (2, 3, 4.0), 18), ("in2", (5, 2, 6.6), (-5, -3, 3), 18)],
    "Ticket_Booth": [("ext", (14, -10, 9), (0, 0, 5), 30), ("in1", (2.8, 1.2, 6.0), (-1, -1.5, 4.5), 16)],
    "Inn_House": [("ext", (26, -30, 18), (0, 0, 12), 30), ("in1", (0, -6.4, 6.6), (-2, 4, 4.5), 16), ("in2", (8, -4, 6.6), (-8, 3, 4.0), 16)],
    "Casino_Hall": [("ext", (60, -70, 35), (10, 0, 15), 30), ("in1", (0, -17, 8.5), (0, 8, 11), 16), ("in2", (20, -14, 8.5), (-8, 6, 9), 16),
                    ("in3", (39, -6, 8.0), (39, 14, 6), 18)],
    "Steam_Factory": [("ext", (50, -70, 40), (0, 0, 15), 30), ("in1", (0, -31, 8.5), (0, 10, 12), 16), ("in2", (16, 20, 9.0), (-6, -10, 8), 16)],
    "Schule": [("ext", (60, -75, 40), (8, 0, 14), 30), ("ext2", (75, 20, 30), (30, 8, 8), 30), ("in1", (0, -19, 7.5), (0, 12, 10), 16),
               ("in2", (-8.5, -15, 7.5), (-22, 10, 4), 16), ("in3", (8.5, -12, 7.5), (22, 10, 5), 16), ("in4", (-8.5, 14, 19.5), (-22, -10, 17), 16),
               ("in5", (8.5, 15, 19.5), (22, -8, 17), 16), ("in6", (28, 0, 7.5), (46, 14, 5), 16), ("in7", (0, 15, 19.5), (0, -16, 12), 16)],
    "Casino_Gate": [("ext", (26, -30, 18), (0, 0, 6), 30), ("in1", (0, -6, 3.0), (2, 4, -6), 16)],
    "Casino_Under": [("sp1", (-5.5, -2.0, -16.0), (5, 3, -26), 16), ("fo1", (0, 10.5, -22.5), (0, 22, -24), 16),
                     ("ha1", (0, 27.0, -21.5), (2, 50, -24), 16), ("ha2", (20, 30, -21.5), (-12, 58, -24), 16),
                     ("au1", (28.0, 43.0, -22.0), (50, 43, -24), 16), ("au2", (50, 52, -18), (33, 38, -26), 16)],
    "Observatory": [("ext", (45, -60, 25), (0, 0, 12), 30), ("in1", (0, -14, 7.0), (12, 14, 8), 16)],
}
L.clear_scene()
made = {}
for name, prefix, fn in I.JOBS + SCH.JOBS + UND.JOBS:
    if only and name not in only:
        continue
    g = L.new_groups(prefix, T.PAL)
    fn(g)
    obs = []
    for k in T.PAL:
        ob = g[k].finish()
        if len(ob.data.polygons) == 0:
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert tris <= 10000, (ob.name, tris)
        obs.append(ob)
    made[name] = obs
    print("  %-16s %d objs %d tri, coll %d, props %d" % (name, len(obs), sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in obs),
                                                        len(I.COLL.get(name, [])), len(I.PROPS.get(name, []))))
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
sh = scene.display.shading
sh.light, sh.color_type = "STUDIO", "MATERIAL"
sh.show_cavity = True
sh.background_type = "VIEWPORT"
sh.background_color = (0.55, 0.68, 0.8)
scene.render.resolution_x, scene.render.resolution_y = 900, 600
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
out = os.path.join(HERE, "snowtown_render")
for name, obs in made.items():
    for n2, lst in made.items():
        for ob in lst:
            ob.hide_render = n2 != name or ob.name.endswith("WinGlass")    # 창유리는 숨겨 구멍이 보이게
    for tail, loc, look, lens in VIEWS[name]:
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        cam.data.clip_start = 0.1
        scene.render.filepath = os.path.join(out, "in_%s_%s.png" % (name, tail))
        bpy.ops.render.render(write_still=True)
print("done")
