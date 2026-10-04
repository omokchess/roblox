# -*- coding: utf-8 -*-
"""
build_bones.py — 2026-10-04. 사막에 놓을 거대 생물 뼈 5종(블렌더) → models/desert/DesertBones.fbx (+ 미리보기 PNG).

사용자(2026-10-04): "엄청 커다란 생물 뼈도 몇개 놔줘. 블렌더로 작업해서 놔줘."
  Bone_Skull    뿔 달린 짐승 두개골(길이 ~40) — 눈구멍·콧구멍 뚫림, 아래턱, 굽은 뿔 둘, 이빨
  Bone_Ribcage  등뼈 12마디 + 갈비 7쌍(길이 ~66, 높이 ~26) — 갈비 끝은 모래에 묻히게 땅(0) 아래로
  Bone_Tail     S자로 굽은 꼬리뼈 16마디(점점 가늘어짐, 반쯤 묻힘)
  Bone_Tusk     모래에서 휘어 솟은 엄니 하나(높이 ~28)
  Bone_Femur    넓적다리뼈(길이 ~28)
단위 1 = 1 스터드. 앞(머리 쪽) = 블렌더 -y → 로블록스 -Z. 원점 표지 Bones_Marker(0.8 상자)를 (0,0,0)에.
조각은 x 로 띄워 놓는다(가져온 뒤 tools/Desert_Bones.luau 가 이름으로 갈라 밑면 가운데를 피벗으로 틀을 만든다).
돌리기: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P models/desert/build_bones.py
"""
import math
import os

import bpy
import bmesh

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "DesertBones.fbx")
PREVIEW = os.path.join(HERE, "render", "bones_preview.png")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

mat = bpy.data.materials.new("Bone")
mat.diffuse_color = (0.88, 0.84, 0.74, 1)


def link(obj):
    scene.collection.objects.link(obj)
    return obj


def to_mesh(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.view_layer.objects.active


def tube(name, pts, r0, r1, sides=2):
    """점들을 지나는 매끈한 관(끝으로 갈수록 r0 → r1)"""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = sides
    cu.resolution_u = 5
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        t = i / max(1, len(pts) - 1)
        sp.points[i].co = (p[0], p[1], p[2], 1)
        sp.points[i].radius = r0 + (r1 - r0) * t
    sp.order_u = min(3, len(pts))
    sp.use_endpoint_u = True
    return to_mesh(link(bpy.data.objects.new(name, cu)))


def ellipsoid(name, loc, scale, seg=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return o


def cylinder(name, loc, r, depth, rot=(0, 0, 0), verts=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    return o


def cone(name, loc, r, depth, rot=(0, 0, 0), verts=8):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=0.1, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    return o


def carve(target, cutter):
    m = target.modifiers.new("cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.object = cutter
    m.solver = "EXACT"
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier="cut")
    bpy.data.objects.remove(cutter, do_unlink=True)


def join(name, objs, offset_x, max_tris):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    # 삼각형 수 맞추기(로블록스 메시 한도 안쪽)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if tris > max_tris:
        d = o.modifiers.new("dec", "DECIMATE")
        d.ratio = max_tris / tris
        bpy.ops.object.modifier_apply(modifier="dec")
    o.location.x += offset_x
    bpy.ops.object.transform_apply(location=True)
    o.data.materials.clear()
    o.data.materials.append(mat)
    for poly in o.data.polygons:
        poly.use_smooth = True
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("%s 삼각형 %d" % (name, tris))
    assert tris <= max_tris * 1.05, name
    return o


pieces = []

# ── 두개골(앞 = -y). 바닥 z 0 근처 ──
parts = []
cran = ellipsoid("cran", (0, 6, 11), (10, 13, 8.5))
parts.append(cran)
snout = ellipsoid("snout", (0, -12, 8), (6.2, 13, 5.5))
parts.append(snout)
brow = ellipsoid("brow", (0, -1, 15), (11, 5, 3.2))
parts.append(brow)
for sx in (-1, 1):
    # 뿔: 정수리 옆에서 바깥·뒤로 휘었다가 앞으로 굽는다
    parts.append(tube("horn", [(sx * 8, 6, 16), (sx * 17, 9, 24), (sx * 25, 18, 25), (sx * 27, 28, 19), (sx * 22, 34, 12)], 3.6, 0.5, 3))
    # 광대뼈
    parts.append(tube("cheek", [(sx * 9, 4, 8), (sx * 9.5, -4, 6), (sx * 6.5, -14, 5)], 1.8, 1.1))
    # 아래턱(U 자 한쪽)
    parts.append(tube("jaw", [(sx * 8, 10, 2.5), (sx * 7.5, 0, 1.5), (sx * 5, -14, 1.2), (sx * 1.2, -24, 1.6)], 1.9, 1.3))
    # 이빨(위·아래)
    for k in range(6):
        y = -6 - k * 3.2
        x = sx * (5.2 - k * 0.55)
        parts.append(cone("tooth", (x, y, 3.6), 0.9, 2.6, rot=(math.pi, 0, 0)))
        parts.append(cone("tooth", (x * 0.92, y - 1.2, 2.4), 0.7, 2.2))
# 구멍은 합치기 전에 닫힌 덩어리마다 뚫는다(겹친 메시를 합친 뒤 불리언하면 덩어리가 통째로 사라졌다)
for sx in (-1, 1):
    for target in (cran, brow):
        carve(target, ellipsoid("eye", (sx * 8.2, -1.5, 12.5), (3.6, 3.2, 3.0), 14, 8))
carve(snout, ellipsoid("nose", (0, -23.5, 9.5), (2.2, 2.5, 2.6), 12, 8))
carve(snout, ellipsoid("nose2", (0, -18, 12.5), (1.6, 3.5, 1.4), 12, 8))
skull = join("Bone_Skull", parts, 0, 9000)
pieces.append(skull)

# ── 갈비뼈 우리(등뼈 + 갈비 7쌍, 머리 쪽 = -y) ──
parts = []
for i in range(12):
    y = i * 5.6
    z = 23 - i * 0.35
    r = 2.6 - i * 0.06
    parts.append(cylinder("vert", (0, y, z), r, 3.8, rot=(math.pi / 2, 0, 0)))
    parts.append(cone("spike", (0, y + 0.6, z + r + 2.2), 1.1, 5.0, rot=(-0.25, 0, 0), verts=6))
    for sx in (-1, 1):
        parts.append(cylinder("wing", (sx * 2.8, y, z - 0.4), 0.9, 3.4, rot=(0, math.pi / 2, 0), verts=6))
for k in range(7):
    y = 6 + k * 7.5
    span = 1.0 - k * 0.07
    for sx in (-1, 1):
        parts.append(tube("rib", [(sx * 2.5, y, 22.5), (sx * 12 * span, y + 1, 25 * span), (sx * 20 * span, y + 2.5, 15),
                                  (sx * 19 * span, y + 4, 3), (sx * 14 * span, y + 5, -5)], 1.6, 0.7, 2))
ribcage = join("Bone_Ribcage", parts, 120, 12000)
pieces.append(ribcage)

# ── 꼬리뼈(S 자, 반쯤 묻힘) ──
parts = []
n = 16
for i in range(n):
    t = i / (n - 1)
    x = math.sin(t * math.pi * 1.4) * 9
    y = t * 62
    r = 3.2 - 2.3 * t
    z = r * 0.35
    ang = math.atan2(math.cos(t * math.pi * 1.4) * 9 * math.pi * 1.4 / 62, 1)
    parts.append(cylinder("tv", (x, y, z), r, r * 1.5, rot=(math.pi / 2, 0, -ang), verts=10))
    parts.append(cone("ts", (x, y, z + r + 1.2 * (1 - t) + 0.6), 0.9 * (1 - t) + 0.3, 3.2 * (1 - t) + 1.2, verts=6))
tail = join("Bone_Tail", parts, 240, 6000)
pieces.append(tail)

# ── 엄니(모래에서 휘어 솟음) ──
parts = [tube("tusk", [(0, 0, -6), (0, 3, 8), (0, 12, 20), (0, 25, 27), (0, 36, 24), (0, 42, 18)], 5.0, 0.6, 3)]
tusk = join("Bone_Tusk", parts, 330, 4000)
pieces.append(tusk)

# ── 넓적다리뼈 ──
parts = [cylinder("shaft", (0, 0, 2.6), 2.2, 24, rot=(math.pi / 2, 0, 0), verts=14)]
parts.append(ellipsoid("headA", (1.5, -12.5, 3.6), (3.6, 3.4, 3.6), 16, 10))
parts.append(ellipsoid("headB", (-1.2, -12, 2.8), (2.8, 3.0, 2.8), 14, 8))
parts.append(ellipsoid("knee", (0, 12.6, 3.0), (4.6, 3.2, 3.2), 16, 10))
femur = join("Bone_Femur", parts, 400, 4000)
pieces.append(femur)

# 원점 표지
bpy.ops.mesh.primitive_cube_add(size=0.8, location=(0, 0, 0))
marker = bpy.context.active_object
marker.name = "Bones_Marker"

# FBX
bpy.ops.object.select_all(action="DESELECT")
for o in pieces + [marker]:
    o.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=OUT, use_selection=True, global_scale=1.0, apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y", object_types={"MESH"}, mesh_smooth_type="FACE",
)
print("FBX", OUT)

# 미리보기(워크벤치, 3/4 위에서)
os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
link(cam)
cam.location = (200, -170, 120)
direction = __import__("mathutils").Vector((210, 30, 5)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
cam_data.lens = 30
scene.camera = cam
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.render.resolution_x, scene.render.resolution_y = 1400, 700
scene.render.filepath = PREVIEW
bpy.ops.render.render(write_still=True)
print("PREVIEW", PREVIEW)

# 조각마다 가까이(3/4 앞 위)
from mathutils import Vector  # noqa: E402
scene.render.resolution_x, scene.render.resolution_y = 900, 700
for o in pieces:
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    c = (lo + hi) / 2
    size = (hi - lo).length
    cam.location = c + Vector((size * 0.75, -size * 0.85, size * 0.55))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(HERE, "render", o.name + ".png")
    bpy.ops.render.render(write_still=True)
