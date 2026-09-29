# -*- coding: utf-8 -*-
"""
build_kit_roman.py — 칼로도르 폴리스 모델 36종을 FBX 하나(RomanKit.fbx)로 묶는다. (2026-09-28)

build_kit_snow.py 와 같은 방식. 모든 모델이 원점에 겹쳐 앉고, 파트 이름 앞머리로
Studio 에서 다시 가른다(tools/Roman_Kit.luau). 원점 표지는 RomanOrigin_Marker.

돌리는 법: blender --background --python build_kit_roman.py
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import build_roman as B  # noqa: E402
import roman_lib as R  # noqa: E402
import ruin_lib as RU  # noqa: E402

# 폐허(2026-09-29): 여러 번 쓰는 일반 건물은 무너진 모양이 다른 두 번째 판을 더 만든다(앞머리 + "2", 이름 + "_2")
VARIANTS = ["Domus", "Insula_A", "Insula_B", "Taberna_Row", "Barracks", "Wall_Seg"]

L.clear_scene()
objs = []
prefixes = [p for _, p, _, _ in B.JOBS]
assert len(set(prefixes)) == len(prefixes), "앞머리가 겹친다"
print("=== RomanKit ===")
jobs = []
for name, prefix, fn, _ in B.JOBS:
    jobs.append((name, prefix, fn, 1))
    if name in VARIANTS:
        jobs.append((name + "_2", prefix + "2", fn, 2))
for name, prefix, fn, seed in jobs:
    g = R.G(prefix)
    fn(g)
    base = name[:-2] if name.endswith("_2") else name
    mode, opts = RU.SPEC.get(base, ("none", {}))
    pressed, removed, rubble = RU.apply(g, mode, seed=seed * 17 + len(base), **opts)
    total = 0
    for k in R.PALETTE:
        ob = g[k].finish()
        if len(ob.data.polygons) == 0:
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert tris <= 10000, "%s 가 삼각형 10000 을 넘는다 (%d)" % (ob.name, tris)
        total += tris
        objs.append(ob)
    print("  %-16s %-5s %6d tri  폐허 %s 눌림 %d 없앰 %d 받침 잃은 꼭짓점 %d" % (name, prefix, total, mode, pressed, removed, rubble))

m = L.Group("RomanOrigin_Marker", L.material("Basalt", R.PALETTE))
m.box(0, 0, 0, 0.8, 0.8, 0.8)
objs.append(m.finish())

bpy.ops.object.select_all(action="DESELECT")
for ob in objs:
    ob.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
fbx = os.path.join(HERE, "RomanKit.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y",
    object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
    bake_space_transform=False,
)
print("objects %d  FBX: %s" % (len(objs), fbx))
