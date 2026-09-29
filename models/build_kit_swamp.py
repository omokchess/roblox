# -*- coding: utf-8 -*-
"""
build_kit_swamp.py — 안개늪 군도(C:/wth/roblox) 에셋 FBX 를 우리 늪지대용 합본 SwampKit.fbx 로 묶는다. (2026-09-28)

참고 프로젝트의 FBX 는 "에셋__재질" 이름 메시로 들어오고, 축 약속이 우리(블렌더 +x → 로블록스 -X)와 Y 축 180도 다르다.
그래서 불러온 뒤 월드 Z 로 180도 돌려(=그쪽 로블록스 로컬 좌표와 같아지게) 우리 설정으로 내보낸다.
그러면 참고 manifest.json 의 충돌체·불빛·표지 로컬 좌표를 그대로 쓸 수 있다.
원점 표지 SwampOrigin_Marker. Studio 에서 tools/Swamp_Kit.luau 가 가른다.
돌리는 법: blender --background --python build_kit_swamp.py
"""
import math
import os
import sys

import bpy
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = r"C:\wth\roblox\assets\fbx"
ASSETS = [
    "StiltHouseA", "StiltHouseB", "StiltHutC", "Longhouse", "WitchHut", "Watchtower", "FerryDock",
    "BoardwalkStraight", "BoardwalkStraightB", "BoardwalkJunction", "BoardwalkRamp", "RopeBridge", "DeckPlatform",
    "MireShrine", "RuinPillar", "RuinArch", "MarketStallA", "MarketStallB", "NoticeBoard", "Signpost", "LampPost",
    "Campfire", "Bench", "CargoPile", "FishRack", "TorchPost", "Fence", "Well", "GlowMushrooms",
    "CypressA", "CypressB", "CypressC", "Mangrove", "DeadTree", "SwampBush", "Reeds", "LilyPads", "FallenLog",
    "BroadleafTree", "Rowboat", "Shipwreck",
]

# "-- kit2": 고친판(models/swamp_ref_assets.py 가 만든 StiltHouseB2·BoardwalkOpen)만 묶어 SwampKit2.fbx 로
KIT2 = "--" in sys.argv and "kit2" in sys.argv[sys.argv.index("--") + 1:]
if KIT2:
    SRC = os.path.join(HERE, "swamp_ref", "fbx")
    ASSETS = ["StiltHouseB2", "BoardwalkOpen"]

bpy.ops.wm.read_factory_settings(use_empty=True)
objs = []
turn = Matrix.Rotation(math.pi, 4, "Z")
for name in ASSETS:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(SRC, name + ".fbx"))
    new = [o for o in bpy.data.objects if o not in before]
    n = 0
    for o in new:
        if o.type != "MESH":
            continue
        o.matrix_world = turn @ o.matrix_world
        assert o.name.startswith(name + "__"), o.name
        o.name = o.name.split(".")[0]
        objs.append(o)
        n += 1
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in new if o.type == "MESH")
    big = max(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in new if o.type == "MESH")
    print("  %-18s 메시 %2d  삼각형 %6d  (가장 큰 메시 %d)" % (name, n, tris, big))

bpy.ops.mesh.primitive_cube_add(size=0.8, location=(0, 0, 0))
m = bpy.context.active_object
m.name = "SwampOrigin_Marker"
objs.append(m)
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
fbx = os.path.join(HERE, "SwampKit2.fbx" if KIT2 else "SwampKit.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y",
    object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
    bake_space_transform=False,
)
print("objects %d  FBX: %s" % (len(objs), fbx))
