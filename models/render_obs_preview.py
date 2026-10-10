# -*- coding: utf-8 -*-
"""render_obs_preview.py — build_steam_obs.py 모델 미리보기(작업대 렌더). blender -b -P models/render_obs_preview.py
out: models/snowtown_render/obs_*.png"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import build_steam_town as T  # noqa: E402
import build_steam_obs as O  # noqa: E402

L.clear_scene()
made = {}
for name, prefix, fn in O.JOBS:
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
    print("  %-18s %d objs %d tri" % (name, len(obs), sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in obs)))

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
sh = scene.display.shading
sh.light, sh.color_type = "STUDIO", "MATERIAL"
sh.show_cavity = True
sh.background_type = "VIEWPORT"
sh.background_color = (0.55, 0.68, 0.8)
scene.render.resolution_x, scene.render.resolution_y = 900, 680
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
out = os.path.join(HERE, "snowtown_render")
os.makedirs(out, exist_ok=True)

PLAY = ["Play_Swing", "Play_Slide", "Play_Seesaw", "Play_RoundBase", "Play_Round", "Play_Dome", "Park_Bench", "Snowman", "Sled",
        "Play_Spring", "Play_MonkeyBars", "Play_Tunnel", "Play_TireSwing", "Play_Balance", "Park_Bin"]
OBS = ["Observatory", "Observatory_Dome", "Observatory_Scope", "Orrery_A", "Orrery_B", "Orrery_C", "Orrery_D"]


def show(names, hide_mats=()):
    for n, lst in made.items():
        for ob in lst:
            ob.hide_render = (n not in names) or any(ob.name.endswith("_" + m) for m in hide_mats)


def shot(fname, loc, look, lens=None, ortho=None):
    cam.location = Vector(loc)
    d = Vector(look) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = "PERSP"
        cam.data.lens = lens or 35
    scene.render.filepath = os.path.join(out, fname)
    bpy.ops.render.render(write_still=True)


show(OBS)
shot("obs_ext.png", (60, -75, 45), (0, 0, 22), lens=40)
shot("obs_back.png", (-55, 70, 60), (0, 0, 26), lens=40)
shot("obs_top.png", (10, 45, 85), (0, 2, 26), lens=40)
# 안: 벽(벽돌·띠돌·벽기둥) 숨기고 안을 본다
show(OBS, hide_mats=("Brick", "BrickDark", "StoneTrim", "SnowCap", "Verdigris", "Copper", "Iron") if False else ("Brick", "BrickDark"))
shot("obs_cut.png", (38, -42, 30), (0, 2, 14), lens=32)
show(OBS)
shot("obs_door_eye.png", (0, -30, 7.5), (0, 0, 12), lens=24)
shot("obs_in_eye.png", (8, -14, 7.5), (-4, 8, 14), lens=22)
shot("obs_gallery_eye.png", (-14, -10, 19.5), (2, 4, 20), lens=24)
show(["Observatory_Scope", "Observatory"], hide_mats=("Brick", "BrickDark", "Timber", "Wood", "Stone", "StoneTrim", "SnowCap"))
shot("obs_scope.png", (16, -14, 24), (0, 3, 19), lens=30)
shot("obs_scope_side.png", (26, 4, 20), (0, 3, 20), lens=32)
show(["Observatory_Dome"])
shot("obs_dome.png", (40, 50, 60), (0, 0, 30), lens=35)
show(["Observatory", "Orrery_A", "Orrery_B", "Orrery_C", "Orrery_D"], hide_mats=("Brick", "BrickDark"))
shot("obs_orrery.png", (-2, -6, 11), (-10, 5, 7), lens=35)
# 놀이터: 줄지어 놓고 찍는다
xs = 0.0
for n in PLAY:
    if n == "Play_Round":
        continue
    for ob in made[n]:
        ob.location.x += xs
    if n == "Play_RoundBase":
        for ob in made["Play_Round"]:
            ob.location.x += xs
    xs += 16.0
show(PLAY)
shot("obs_play.png", (40, -40, 16), (40, 0, 3), lens=30)
shot("obs_play2.png", (95, -40, 16), (95, 0, 3), lens=30)
shot("obs_play3.png", (165, -40, 16), (165, 0, 3), lens=30)
shot("obs_play4.png", (128, -7, 5), (128, 0, 2.6), lens=35)
show(OBS)
shot("obs_chair.png", (-4, -16, 7), (-11.3, -9.4, 3.5), lens=35)
print("done")
