# -*- coding: utf-8 -*-
"""
build_kit_sanctuary.py — 탑의 성역 모델을 FBX 하나(SanctuaryKit.fbx)로 묶는다. (2026-09-27)

build_kit_hanok.py 와 같은 방식. 모든 모델이 원점에 겹쳐 앉고 파트 이름 앞머리로 Studio 에서 다시 가른다
(tools/Sanctuary_Kit.luau). 원점 표지는 SancOrigin_Marker. 탑은 높이 여섯 토막(Tw1..Tw6)으로 들어간다.
탑 계단 윗면 점들은 tools/Sanctuary_steps.luau 로 적는다(충돌 비탈용).

돌리는 법: blender --background --python build_kit_sanctuary.py [-- 이름...]
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L
import build_sanctuary as S

L.clear_scene()
only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
jobs = [j for j in S.JOBS if j[0] != "Tower_Preview" and (not only or j[0] in only)]
objs = []
prefixes = [j[1] for j in S.JOBS] + ["Tw%d" % (k + 1) for k in range(S.N_SEC)]
assert len(set(prefixes)) == len(prefixes), "앞머리가 겹친다"
print("=== SanctuaryKit ===")


def take(name, g):
    total = 0
    for k in S.SPAL:
        ob = g[k].finish()
        if len(ob.data.polygons) == 0:
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert tris <= 10000, "%s 가 삼각형 10000 을 넘는다 (%d)" % (ob.name, tris)
        total += tris
        objs.append(ob)
    print("  %-16s %6d tri" % (name, total))


for name, prefix, fn, _, _ in jobs:
    g = S.G(prefix)
    fn(g)
    take(name, g)

if not only or "Tower" in only:
    for k, g in enumerate(S.tower_section_groups()):
        take("Tower_S%d" % (k + 1), g)
    lines = ["-- build_kit_sanctuary.py 가 적은 탑 계단 윗면 점. 탑 발치 원점, 로블록스 축. 손으로 고치지 말 것",
             "return {"]
    for i, x, y, z, w in S.STEPS_OUT:
        lines.append("\t{ %d, %.3f, %.3f, %.3f, %.3f }," % (i, x, y, z, w))
    lines.append("}")
    with open(os.path.join(HERE, "..", "tools", "Sanctuary_steps.luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("  계단 %d 칸" % len(S.STEPS_OUT))

m = L.Group("SancOrigin_Marker", L.material("Marble", S.SPAL))
m.box(0, 0, 0, 0.8, 0.8, 0.8)
objs.append(m.finish())

bpy.ops.object.select_all(action="DESELECT")
for ob in objs:
    ob.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
fbx = os.path.join(HERE, "SanctuaryKit.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y",
    object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
    bake_space_transform=False,
)
print("objects %d  FBX: %s" % (len(objs), fbx))
