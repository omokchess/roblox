# -*- coding: utf-8 -*-
"""
build_kit_ruins.py — 탑의 성역 재작업 모델을 FBX 하나(RuinsKit.fbx)로 묶는다. (2026-09-27)

모든 모델이 원점에 겹쳐 앉고 파트 이름 앞머리로 Studio 에서 가른다(tools/Ruins_Kit.luau). 원점 표지 RuinsOrigin_Marker.
탑은 높이 여섯 토막(RTw1..RTw6). 함께 적는 것:
  tools/Ruins_steps.luau  탑 계단 윗면 점(충돌 비탈)
  tools/Ruins_lifts.luau  모델마다 원점 밑으로 들어가 올려 둔 값(놓을 때 그만큼 묻는다)
돌리는 법: blender --background --python build_kit_ruins.py [-- 이름...]
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L
import build_ruins as R

L.clear_scene()
only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
jobs = [j for j in R.JOBS if j[0] != "Tower_Preview" and (not only or j[0] in only)]
objs = []
prefixes = [j[1] for j in R.JOBS] + ["RTw%d" % (k + 1) for k in range(R.N_SEC)]
assert len(set(prefixes)) == len(prefixes), "앞머리가 겹친다"
lifts = {}
print("=== RuinsKit ===")


import zfight_scan as Z  # noqa: E402  (2026-10-24 반짝임: 겹친 면 중 작은 쪽을 0.02 앞으로)
Z.LOOK = Z.looks("Ruins_Kit.luau")


def take(name, g, zf=None):
    zm, zl = zf or Z.fix(g, name)
    total = 0
    for k in R.RPAL:
        ob = g[k].finish()
        if len(ob.data.polygons) == 0:
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert tris <= 10000, "%s 가 삼각형 10000 을 넘는다 (%d)" % (ob.name, tris)
        total += tris
        objs.append(ob)
    print("  %-16s %6d tri  반짝임 민 면 %d 남음 %d" % (name, total, zm, zl))


for name, prefix, fn, _, _ in jobs:
    g = R.G(prefix)
    fn(g)
    lifts[name] = R.norm_floor(g)
    take(name, g)

if not only or "Tower" in only:
    gs = R.tower_section_groups()
    # 토막끼리 맞닿은 면도 재려고 나머지 토막 면을 extra 로 준다. 다 고친 뒤에 마무리(finish 가 bmesh 를 푼다)
    zfs = [Z.fix(g, "Tower_S%d" % (k + 1), [f for j, o in enumerate(gs) if j != k for f in Z.collect(o, "RTw%d" % (j + 1), movable=False)])
           for k, g in enumerate(gs)]
    for k, g in enumerate(gs):
        take("Tower_S%d" % (k + 1), g, zfs[k])
    with open(os.path.join(HERE, "..", "tools", "Ruins_steps.luau"), "w", encoding="utf-8") as f:
        f.write("-- build_kit_ruins.py 가 적은 탑 계단 윗면 점 {번호, x, y, z, 폭}. 탑 발치 원점, 로블록스 축\nreturn {\n")
        for i, x, y, z, w in R.STEPS_OUT:
            f.write("\t{ %d, %.3f, %.3f, %.3f, %.3f },\n" % (i, x, y, z, w))
        f.write("}\n")
    print("  계단 %d 칸" % len(R.STEPS_OUT))
with open(os.path.join(HERE, "..", "tools", "Ruins_lifts.luau"), "w", encoding="utf-8") as f:
    f.write("-- build_kit_ruins.py 가 적은 모델별 올림 값(원점 밑으로 들어간 만큼 올려 내보냈다). 놓을 때 이만큼 묻는다\nreturn {\n")
    for k, v in sorted(lifts.items()):
        f.write("\t%s = %.3f,\n" % (k, v))
    f.write("}\n")

m = L.Group("RuinsOrigin_Marker", L.material("Stone", R.RPAL))
m.box(0, 0, 0, 0.8, 0.8, 0.8)
objs.append(m.finish())
bpy.ops.object.select_all(action="DESELECT")
for ob in objs:
    ob.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
fbx = os.path.join(HERE, "RuinsKit.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y",
    object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
    bake_space_transform=False,
)
print("objects %d  FBX: %s" % (len(objs), fbx))
