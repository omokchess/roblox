# -*- coding: utf-8 -*-
"""
preview.py — 2026-11-13. 설원 3판 건물 미리보기(작업대 렌더, render_inside_preview.py 방식). 창유리는 숨겨 속이 보이게.
돌리기: blender -b -P models/snow3/preview.py -- Sn3_Smithy [다른 이름...]      (SMITHY_VARIANT=B 로 B 안)
out: models/snow3/render/<이름>_<안>_<시점>.png
시점(건물 파일의 INFO 에서 자리를 읽는다 — 앞 = -y):
  ext34 겉 3/4 · front 정면 · back 뒤 3/4 · fp_door10 문 앞 10 스터드 1인칭(땅 + 4.5) · fp_sill 문턱 · fp_mid 안 가운데 · fp_counter 카운터 앞 · plan 지붕 자른 위 평면
1인칭 렌즈 17mm(가로 약 93° = 로블록스 세로 FOV 70° 의 3:2 화면)
"""
import importlib
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib as K  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.join(HERE, "render")
os.makedirs(OUT, exist_ok=True)


def views(m):
    inf = m.INFO
    fz, eye = inf["floor"], inf["floor"] + K.EYE
    (dx, dy), (cx, cy) = inf["walk"]
    door = K.DOOR_INFO[m.NAME][0][0]
    x0, x1, y0, y1 = inf["counter"]
    ccx = (x0 + x1) / 2
    return [
        ("ext34", (-54, -60, 32), (0, 0, 12), 30, None),
        ("ext34r", (54, -60, 32), (0, 0, 12), 30, None),
        ("front", (0, -80, 14), (0, 0, 14), 32, None),
        ("back", (46, 62, 30), (0, 0, 12), 30, None),
        ("fp_door10", (door[0], door[1] - 10, K.EYE), (door[0], door[1] + 20, fz + 3.0), 17, None),
        ("fp_sill", (door[0], door[1] - 0.5, eye), (door[0] - 2, door[1] + 20, fz + 3.0), 17, None),
        ("fp_mid", (0, 0, eye), (*inf.get("forge_look", (-6, 12)), fz + 3.0), 17, None),
        ("fp_counter", (ccx, y0 - 6.0, eye), (ccx, y1 + 6, fz + 3.0), 17, None),
        ("plan", (0, 0, 120), (0, 0.01, 0), None, (120 - (fz + inf["ceiling"] - 0.3), 44)),
    ]


def main():
    names = args or None
    mods = []
    for p in sorted(os.listdir(HERE)):
        if p.startswith("b_") and p.endswith(".py"):
            m = importlib.import_module(p[:-3])
            if not names or m.NAME in names:
                mods.append(m)
    K.L.clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.show_cavity = True
    sh.show_shadows = True
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.62, 0.72, 0.82)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 800
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.02))
    ground = bpy.context.active_object
    ground.data.materials.append(K.L.material("SnowCap", K.PAL))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    built = {}
    for m in mods:
        objs, tris, _ = K.build_model(m, zfix=False)
        built[m.NAME] = (m, objs)
        print("  %s %s %d tri" % (m.NAME, getattr(m, "VARIANT", ""), sum(tris.values())))
    for name, (m, objs) in built.items():
        for n2, (_, o2) in built.items():
            for ob in o2:
                ob.hide_render = n2 != name or ob.name.endswith(("WinGlass", "_Vent", "_LampPt"))
        tag = "%s_%s" % (name, getattr(m, "VARIANT", "-"))
        for tail, loc, look, lens, ortho in views(m):
            cam.location = Vector(loc)
            cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
            if ortho:
                cam.data.type = "ORTHO"
                cam.data.ortho_scale = ortho[1]
                cam.data.clip_start = ortho[0]
            else:
                cam.data.type = "PERSP"
                cam.data.lens = lens
                cam.data.clip_start = 0.1
            cam.data.clip_end = 2000.0
            ground.hide_render = bool(ortho)
            scene.render.filepath = os.path.join(OUT, "%s_%s.png" % (tag, tail))
            bpy.ops.render.render(write_still=True)
    print("done →", OUT)


main()
