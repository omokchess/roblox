# -*- coding: utf-8 -*-
"""
build_kit2.py — 2026-09-26 새 건물 11종을 FBX 하나로 묶는다.

Studio 3D 가져오기를 열한 번 하지 않으려는 것이다. 모든 모델이 원점에 겹쳐 앉고,
파트 이름 앞머리(GateP_, Corr_ ...)로 로블록스에서 다시 모델별로 가른다.
원점 표지 KitOrigin_Marker(0.4 상자)를 원점에 둔다. 가져오면 Studio 가 모델을 아무 데나
놓으므로, 표지 위치를 빼서 원점을 되찾는다.

돌리는 법: blender --background --python build_kit2.py [-- 틀이름 ...]
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L
import build_house as BH
import build_palace2 as BP
import build_town2 as BT

SCALE = 0.5

# (모델 이름, 앞머리, 짓는 함수)
KIT = [(name, prefix, fn) for name, prefix, fn, _, _ in BP.JOBS]
KIT += [(name, prefix, fn) for name, prefix, fn, _ in BT.JOBS]
KIT.append(("Building_HouseLM", "HouseLM", lambda g: BH.house_l(g, -1)))

# "-- 이름 ..." 을 주면 그 틀만 묶는다(바꾼 틀만 Studio 에서 갈아 끼울 때). Jeolhwa_Kit2.luau 는 든 것만 바꾼다
only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if only:
    KIT = [k for k in KIT if k[0] in only]
    assert len(KIT) == len(only), "모르는 틀 이름이 있다 %s" % only

prefixes = [p for _, p, _ in KIT]
assert len(set(prefixes)) == len(prefixes), "앞머리가 겹친다"

L.clear_scene()
objs = []
print("=== JeolhwaKit2 ===")
for name, prefix, fn in KIT:
    g = L.new_groups(prefix)
    fn(g)
    tris_total = 0
    for k in L.PALETTE:
        ob = g[k].finish()
        if len(ob.data.polygons) == 0:
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert tris <= 10000, "%s 가 삼각형 10000 을 넘는다 (%d)" % (ob.name, tris)
        tris_total += tris
        objs.append(ob)
    print("  %-18s %-8s %6d tri" % (name, prefix, tris_total))

# 원점 표지
g = {"Marker": L.Group("KitOrigin_Marker", L.material("Stylobate"))}
g["Marker"].box(0, 0, 0, 0.8, 0.8, 0.8)
objs.append(g["Marker"].finish())

bpy.ops.object.select_all(action="DESELECT")
for ob in objs:
    ob.select_set(True)
    ob.scale = (SCALE, SCALE, SCALE)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

fbx = os.path.join(HERE, "JeolhwaKit2.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y",
    object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
    bake_space_transform=False,
)
print("objects %d  FBX: %s" % (len(objs), fbx))
