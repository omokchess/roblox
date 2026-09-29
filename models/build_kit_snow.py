# -*- coding: utf-8 -*-
"""
build_kit_snow.py — 설원 스팀펑크 14종을 FBX 하나(SnowKit.fbx)로 묶는다. (2026-09-26)

build_kit2.py 와 같은 방식이다. 모든 모델이 원점에 겹쳐 앉고, 파트 이름 앞머리로
Studio 에서 다시 가른다(tools/Snow_Kit.luau). 원점 표지는 SnowOrigin_Marker.

돌리는 법: blender --background --python build_kit_snow.py
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L
import build_steam as S
import build_props as P

L.clear_scene()
objs = []
JOBS = S.JOBS + P.JOBS
prefixes = [p for _, p, _, _ in JOBS]
assert len(set(prefixes)) == len(prefixes), "앞머리가 겹친다"
print("=== SnowKit ===")
for name, prefix, fn, _ in JOBS:
    g = S.G(prefix)
    fn(g)
    total = 0
    for k in S.PALETTE:
        ob = g[k].finish()
        if len(ob.data.polygons) == 0:
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert tris <= 10000, "%s 가 삼각형 10000 을 넘는다 (%d)" % (ob.name, tris)
        total += tris
        objs.append(ob)
    print("  %-16s %-7s %6d tri" % (name, prefix, total))

m = L.Group("SnowOrigin_Marker", L.material("Stone", S.PALETTE))
m.box(0, 0, 0, 0.8, 0.8, 0.8)
objs.append(m.finish())

bpy.ops.object.select_all(action="DESELECT")
for ob in objs:
    ob.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
fbx = os.path.join(HERE, "SnowKit.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y",
    object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
    bake_space_transform=False,
)
print("objects %d  FBX: %s" % (len(objs), fbx))
