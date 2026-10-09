# -*- coding: utf-8 -*-
"""
build_kit_forest.py — 숲 나무 키트(2026-10-09, 숲+평원 리메이크).

숲이 약 4600×4600 이 되어 나무가 수천 그루 필요하다. 평원 나무(Part 35개짜리)를 그대로 쓰면 수십만 파트가 되므로,
같은 양식(각진 줄기·가지 + 잎 상자 덩어리)을 블렌더에서 **나무 하나 = 메시 셋**(Wood·LeafA 밝은 잎·LeafB 어두운 잎)으로 만든다.
모양은 손으로 적은 상자 표(줄기·가지·잎 상자 자리·크기·기울기). 원점 = 줄기 밑 가운데, +Y 위(로블록스 스터드).
  Oak_A  넓은 활엽수 34      Oak_B  둥근 활엽수 28      Giant_A 숲 거목 58(판자 뿌리)
  Pine_A 각진 침엽수 42      Pine_B 작은 침엽수 30      Birch_A 가는 나무 32
  Bush_A 덤불 6              Bush_B 낮은 덤불 4          Log_A  쓰러진 통나무
메시 이름 "<틀>_<묶음>". 색·재질·충돌은 tools/Forest_Kit.luau. 원점 표지 ForestKitOrigin_Marker(1×1×1).
돌리는 법: blender -b -P models/forest/build_kit_forest.py [-- render]   → models/forest/ForestKit.fbx (+ render/*.png)
"""
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "weapons"))
import wlib as L  # noqa: E402

RENDER = "render" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])


def rgb(r, g, b):
    return (r / 255) ** 2.2, (g / 255) ** 2.2, (b / 255) ** 2.2


# 평원 나무에서 읽은 색(Wood 74,55,40 · 잎 52~60 / 84~94 / 46~50)
WOOD, LEAFA, LEAFB = rgb(74, 55, 40), rgb(60, 94, 50), rgb(36, 62, 38)


class Tree:
    def __init__(self, name):
        self.name = name
        self.g = {"Wood": L.Group(name + "_Wood", WOOD, None), "LeafA": L.Group(name + "_LeafA", LEAFA, None),
                  "LeafB": L.Group(name + "_LeafB", LEAFB, None)}

    def box(self, group, center, size, rot=(0, 0, 0)):
        L.bbox(self.g[group], center, size, 0.0, rot)

    def finish(self):
        return [g.finish() for g in self.g.values() if len(g.bm.verts) > 0]


# 손 표: (묶음, 가운데, 크기, 회전(도: x 앞뒤 기울기, y 돌림, z 옆 기울기))
SHAPES = {
    "Oak_A": [
        ("Wood", (0, 2, 0), (6.5, 4, 6.5), (0, 20, 0)),  # 뿌리 밑동
        ("Wood", (0, 8, 0), (4.6, 12, 4.6), (0, 8, 3)),
        ("Wood", (0.6, 17, 0.2), (3.6, 8, 3.6), (0, 30, -4)),
        ("Wood", (4.2, 17, -1.5), (1.6, 9, 1.6), (12, 0, -38)),  # 가지 동
        ("Wood", (-4.0, 18, 2.0), (1.5, 8, 1.5), (-10, 0, 40)),  # 가지 서
        ("Wood", (0.5, 19, -4.0), (1.3, 7, 1.3), (-35, 0, 6)),
        ("LeafB", (0, 21, 0), (19, 8, 17), (0, 10, 0)),
        ("LeafA", (5.5, 25, -3), (13, 8, 12), (0, 35, 0)),
        ("LeafB", (-6.5, 23.5, 4), (12, 7, 11), (0, -15, 0)),
        ("LeafA", (1, 29.5, 1), (11, 6, 10), (0, 25, 0)),
        ("LeafB", (-2.5, 18, -6.5), (10, 5, 8), (0, 5, 0)),
        ("LeafA", (7, 19.5, 5), (8, 5, 8), (0, 40, 0)),
    ],
    "Oak_B": [
        ("Wood", (0, 1.8, 0), (5.8, 3.6, 5.8), (0, 45, 0)),
        ("Wood", (0, 7, 0), (4, 10, 4), (4, 0, -3)),
        ("Wood", (-3, 13, 1), (1.4, 7, 1.4), (0, 0, 35)),
        ("Wood", (3, 13.5, -1), (1.4, 7, 1.4), (0, 0, -32)),
        ("LeafA", (0, 17, 0), (16, 9, 16), (0, 0, 0)),
        ("LeafB", (-4.5, 20, 3), (11, 7, 10), (0, 20, 0)),
        ("LeafB", (4, 21.5, -2.5), (10, 7, 10), (0, -20, 0)),
        ("LeafA", (0.5, 25, 0.5), (9, 6, 9), (0, 45, 0)),
        ("LeafB", (2, 14, 5.5), (8, 4, 7), (0, 10, 0)),
    ],
    "Giant_A": [
        # 판자 뿌리 넷 + 굵은 줄기 + 높은 잎 세 켜
        ("Wood", (0, 3, 0), (9, 6, 9), (0, 0, 0)),
        ("Wood", (6, 2.2, 0), (6, 4.4, 1.6), (0, 0, -18)),
        ("Wood", (-6, 2.2, 0.5), (6, 4.4, 1.6), (0, 0, 18)),
        ("Wood", (0.5, 2.2, 6), (1.6, 4.4, 6), (18, 0, 0)),
        ("Wood", (-0.5, 2.2, -6), (1.6, 4.4, 6), (-18, 0, 0)),
        ("Wood", (0, 18, 0), (7, 26, 7), (0, 15, 2)),
        ("Wood", (0.6, 36, 0.4), (5.5, 14, 5.5), (0, 40, -3)),
        ("Wood", (6, 38, -2), (2.2, 12, 2.2), (10, 0, -42)),
        ("Wood", (-6, 40, 3), (2, 11, 2), (-12, 0, 44)),
        ("Wood", (1, 41, 6), (1.8, 10, 1.8), (40, 0, 4)),
        ("LeafB", (0, 44, 0), (28, 9, 26), (0, 12, 0)),
        ("LeafA", (8, 47, -5), (17, 8, 16), (0, 30, 0)),
        ("LeafB", (-9, 46.5, 6), (16, 8, 15), (0, -20, 0)),
        ("LeafA", (1, 51.5, 2), (18, 7, 17), (0, 40, 0)),
        ("LeafA", (-2, 56, -1), (11, 5, 10), (0, 5, 0)),
        ("LeafB", (4, 40.5, 10), (12, 5, 10), (0, 15, 0)),
        ("LeafB", (-6, 40, -9), (12, 5, 11), (0, -30, 0)),
    ],
    "Pine_A": [
        ("Wood", (0, 1.5, 0), (4.4, 3, 4.4), (0, 45, 0)),
        ("Wood", (0, 19, 0), (3, 36, 3), (0, 0, 0)),
        ("LeafB", (0, 10, 0), (17, 5, 17), (0, 0, 0)),
        ("LeafA", (0, 15, 0), (14.5, 5, 14.5), (0, 45, 0)),
        ("LeafB", (0, 20, 0), (12, 5, 12), (0, 0, 0)),
        ("LeafA", (0, 25, 0), (9.5, 5, 9.5), (0, 45, 0)),
        ("LeafB", (0, 30, 0), (7, 5, 7), (0, 0, 0)),
        ("LeafA", (0, 35, 0), (4.5, 5, 4.5), (0, 45, 0)),
        ("LeafB", (0, 39.5, 0), (2.4, 4, 2.4), (0, 0, 0)),
    ],
    "Pine_B": [
        ("Wood", (0, 1.2, 0), (3.6, 2.4, 3.6), (0, 30, 0)),
        ("Wood", (0, 14, 0), (2.4, 26, 2.4), (0, 0, 2)),
        ("LeafB", (0, 8, 0), (13, 4, 13), (0, 15, 0)),
        ("LeafA", (0, 12, 0), (11, 4, 11), (0, 60, 0)),
        ("LeafB", (0, 16, 0), (8.5, 4, 8.5), (0, 15, 0)),
        ("LeafA", (0, 20, 0), (6, 4, 6), (0, 60, 0)),
        ("LeafB", (0, 24, 0), (3.6, 4, 3.6), (0, 15, 0)),
        ("LeafA", (0, 27.5, 0), (1.8, 3, 1.8), (0, 60, 0)),
    ],
    "Birch_A": [
        ("Wood", (0, 1, 0), (3, 2, 3), (0, 20, 0)),
        ("Wood", (0, 11, 0), (2, 20, 2), (0, 0, 4)),
        ("Wood", (0.8, 23, 0), (1.6, 6, 1.6), (0, 0, -8)),
        ("Wood", (2.5, 19, -1), (0.9, 6, 0.9), (10, 0, -40)),
        ("LeafA", (0.5, 24, 0), (9, 7, 8), (0, 15, 0)),
        ("LeafB", (-2, 21, 2), (7, 5, 6), (0, -10, 0)),
        ("LeafA", (2.5, 28, -1), (6, 5, 6), (0, 40, 0)),
        ("LeafB", (3, 20, -3), (6, 4, 5), (0, 20, 0)),
        ("LeafA", (0, 31, 0.5), (4, 3, 4), (0, 0, 0)),
    ],
    "Bush_A": [
        ("LeafB", (0, 2, 0), (8, 4, 7), (0, 10, 0)),
        ("LeafA", (2, 4, -1), (6, 4, 5), (0, 35, 0)),
        ("LeafB", (-2.5, 3.5, 2), (5, 4, 5), (0, -20, 0)),
        ("LeafA", (0, 5.5, 0.5), (4, 2.5, 4), (0, 10, 0)),
    ],
    "Bush_B": [
        ("LeafA", (0, 1.5, 0), (7, 3, 5), (0, 0, 0)),
        ("LeafB", (2.5, 2.5, 1), (5, 3, 4), (0, 30, 0)),
        ("LeafB", (-2.5, 2, -1), (4, 3, 4), (0, -25, 0)),
    ],
    "Log_A": [
        ("Wood", (0, 1.8, 0), (3.6, 3.6, 18), (0, 0, 0)),
        ("Wood", (0, 1.9, -9.6), (4.4, 4.4, 1.4), (0, 0, 0)),  # 밑동 끝
        ("Wood", (1.5, 3.4, 4), (1, 1, 4), (0, 25, 0)),  # 남은 가지
        ("LeafB", (-1.2, 3.8, -3), (3, 1, 4), (0, 10, 0)),  # 이끼
        ("LeafA", (0.6, 3.8, 6), (2.5, 0.8, 3), (0, -15, 0)),
    ],
}


def build(name):
    t = Tree(name)
    for group, c, s, r in SHAPES[name]:
        t.box(group, c, s, r)
    return t


def render_sheet(pieces, out):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.show_cavity = True
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.55, 0.68, 0.8)
    scene.render.resolution_x = scene.render.resolution_y = 500
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
        cam.data.ortho_scale = size * 0.95
        d = Vector((0.6, -0.8, 0.3)).normalized()
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
    for name in SHAPES:
        objs = build(name).finish()
        for ob in objs:
            assert L.tri_count(ob) <= 20000, ob.name
        print("  %-8s %d 조각, %d tri" % (name, len(objs), sum(L.tri_count(o) for o in objs)))
        pieces.append((name, objs))
        allobjs += objs
    mk = L.Group("ForestKitOrigin_Marker", (1, 0, 1), None)
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
    fbx = os.path.join(HERE, "ForestKit.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             axis_forward="-Z", axis_up="Y", object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
                             bake_space_transform=False)
    print("objects %d  FBX: %s" % (len(allobjs) + 1, fbx))


main()
