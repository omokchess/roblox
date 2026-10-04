# -*- coding: utf-8 -*-
"""
build_bones.py — 2026-10-04 (2판). 사막 거대 용 뼈 5종(블렌더) → models/desert/DesertBones.fbx (+ 미리보기 PNG).

1판(둥근 관·타원체)은 사용자: "용 뼈가 좀 동글동글한데, 실제 용 사진같은거 보고 참고해서 날카롭게 만들어줘."
참고(빙 이미지 검색 "dragon skull skeleton bones fossil": Eltanin 용 두개골(ArtStation), 왕좌의 게임 해변 용 두개골,
Lorenzo Napoli 용 두개골)에서 가져온 것:
  - 두개골은 낮고 긴 쐐기(윗면 평평, 주둥이 끝 갈고리) — 통 덩어리가 아니라 뼈 기둥 틀 사이로 큰 구멍(눈구멍·앞눈구멍·관자구멍)
  - 뒤통수에서 뒤로 뻗는 뿔 왕관(큰 뿔 둘 + 작은 뿔 여럿), 눈썹·광대 줄의 잔가시, 길고 뾰족한 송곳니 줄
  - 갈비는 얇은 칼날처럼 휘어 끝이 뾰족, 등뼈는 칼날 같은 높은 가시(뒤로 기움)
그래서 2판은 단면을 4~6각(모난 관)으로, 매끈 음영 대신 면 음영(각진 면), 끝은 모두 뾰족하게.
이름·크기는 1판과 같다(tools/Desert_Bones.luau 의 놓기 표 그대로): Bone_Skull · Bone_Ribcage · Bone_Tail · Bone_Tusk · Bone_Femur.
단위 1 = 1 스터드. 앞(머리) = 블렌더 -y → 로블록스 -Z. 원점 표지 Bones_Marker.
돌리기: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P models/desert/build_bones.py
"""
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "DesertBones.fbx")
RENDER = os.path.join(HERE, "render")

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


def strut(pts, r0, r1, res=0, smooth=4, flat=1.0):
    """모난 관: res 0 → 4각(마름모) 단면. flat < 1 이면 단면을 납작하게(칼날)."""
    cu = bpy.data.curves.new("s", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = res
    cu.resolution_u = smooth
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS" if len(pts) > 2 else "POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        t = i / max(1, len(pts) - 1)
        sp.points[i].co = (p[0], p[1], p[2], 1)
        sp.points[i].radius = r0 + (r1 - r0) * t
    if len(pts) > 2:
        sp.order_u = min(3, len(pts))
        sp.use_endpoint_u = True
    o = to_mesh(link(bpy.data.objects.new("s", cu)))
    if flat != 1.0:
        o.scale = (flat, 1, 1)
        bpy.ops.object.transform_apply(scale=True)
    return o


def spike(base, tip, r, sides=4):
    """뾰족한 가시(밑 반지름 r, base → tip)"""
    b, t = Vector(base), Vector(tip)
    d = t - b
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=r, radius2=0.0, depth=d.length, location=(b + t) / 2)
    o = bpy.context.active_object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(rotation=True)
    return o


def lump(loc, scale, seg=6, rings=4):
    """모난 덩어리(각진 타원체)"""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return o


def join(name, objs, offset_x):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    o.location.x += offset_x
    bpy.ops.object.transform_apply(location=True)
    # 칼날(납작하게 누른 관)·곡선 관의 면이 뒤집혀 스튜디오에서 까맣게 보였다 → 법선을 바깥으로 맞춘다
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    o.data.materials.clear()
    o.data.materials.append(mat)
    for poly in o.data.polygons:
        poly.use_smooth = False  # 각진 면
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("%s 삼각형 %d" % (name, tris))
    assert tris <= 15000, name
    return o


pieces = []

# ── 두개골: 길이 ~50, 낮은 쐐기 틀. 앞 = -y, 바닥 z ≈ 0 ──
P = []
for sx in (-1, 1):
    # 윗 옆 기둥(눈썹줄 → 주둥이)
    P.append(strut([(sx * 10, 14, 13), (sx * 9, 2, 13.5), (sx * 6, -14, 10), (sx * 2.5, -30, 6), (sx * 0.6, -36, 4)], 2.56, 0.80))
    # 아래 옆 기둥(위턱 이빨줄)
    P.append(strut([(sx * 11, 14, 4), (sx * 9.5, 0, 3.5), (sx * 6, -16, 3), (sx * 2.6, -32, 2.6), (sx * 0.8, -36, 2.4)], 2.24, 0.80))
    # 세로 기둥: 뒤눈확 막대(y 6) · 앞눈확(y -6) · 앞눈구멍 앞(y -20) — 그 사이가 큰 구멍
    P.append(strut([(sx * 9.5, 6, 13.5), (sx * 10.5, 5, 8), (sx * 10, 4, 3.8)], 1.92, 1.60))
    P.append(strut([(sx * 8.5, -6, 12.5), (sx * 8.8, -7, 7.5), (sx * 8.2, -8, 3.4)], 1.60, 1.44))
    P.append(strut([(sx * 4.8, -20, 8.6), (sx * 5.0, -21, 5.5), (sx * 4.6, -22, 2.9)], 1.28, 1.12))
    # 관자 구멍 테두리(뒤통수 옆)
    P.append(strut([(sx * 10, 14, 13), (sx * 12, 16, 9), (sx * 11, 14, 4)], 2.08, 1.76))
    # 눈썹·광대 잔가시(뒤로)
    for k in range(4):
        y = 10 - k * 6
        P.append(spike((sx * (9.6 - k * 0.6), y, 13.6 - k * 0.3), (sx * (12 - k * 0.4), y + 4.5, 16 - k * 0.8), 0.9))
        P.append(spike((sx * (10.5 - k * 0.9), y - 1, 4.5), (sx * (14 - k * 1.0), y + 3, 3.5), 0.7))
    # 뿔 왕관: 큰 뿔(뒤·위로 휘어 끝 뾰족) + 작은 뿔 셋
    P.append(strut([(sx * 9, 14, 14), (sx * 14, 26, 21), (sx * 17, 40, 22), (sx * 16, 50, 17)], 3.4, 0.05, res=1, smooth=6))
    P.append(strut([(sx * 11.5, 16, 10), (sx * 18, 26, 12), (sx * 23, 34, 9)], 2.0, 0.05, res=0, smooth=5))
    P.append(strut([(sx * 11, 15, 6), (sx * 17, 24, 3), (sx * 21, 30, -1)], 1.6, 0.05, res=0, smooth=5))
    P.append(strut([(sx * 6, 16, 15), (sx * 8, 28, 19), (sx * 8, 36, 17)], 1.5, 0.05, res=0, smooth=5))
    # 위턱 송곳니(아래로, 길고 뾰족 — 앞으로 갈수록 짧게)
    for k in range(8):
        t = k / 7
        y = 8 - t * 40
        x = sx * (10 - t * 8.6)
        length = 5.2 - t * 1.6 + (1.4 if k in (2, 5) else 0)
        P.append(spike((x, y, 3.2), (x * 0.96, y - 0.6, 3.2 - length), 0.8, 5))
# 정수리 등줄(가운데 능선) + 정수리 가시 줄
P.append(strut([(0, 15, 15.5), (0, 0, 14.5), (0, -16, 11), (0, -34, 5.2)], 1.76, 0.80))
for k in range(4):
    P.append(spike((0, 12 - k * 5, 15.3 - k * 0.3), (0, 17 - k * 5, 20 - k * 1.2), 1.0))
# 뒤통수 덩어리(뇌함 — 모난 덩어리) · 주둥이 끝 갈고리
P.append(lump((0, 12, 9.5), (9.5, 6.5, 7), 6, 4))  # 2판: 틀이 가늘어 뇌함을 키움
P.append(spike((0, -34.5, 4.5), (0, -38, 0.4), 1.6, 4))
# 아래턱(조금 벌어짐): 아래 기둥 · 윗기둥 · 뒤 돌기 · 아래 송곳니(위로)
for sx in (-1, 1):
    P.append(strut([(sx * 10, 13, 1.6), (sx * 8.5, 0, 0.4), (sx * 5, -16, -0.4), (sx * 1.4, -33, -0.6)], 2.40, 0.96))
    P.append(strut([(sx * 9.5, 11, 3.0), (sx * 8, -2, 2.2), (sx * 4.6, -18, 1.4), (sx * 1.2, -32, 0.8)], 1.44, 0.80))
    P.append(spike((sx * 10, 13, 1.6), (sx * 11.5, 19, 0.2), 1.2))
    for k in range(7):
        t = k / 6
        y = 4 - t * 34
        x = sx * (9 - t * 7.4)
        P.append(spike((x, y, 1.8), (x * 0.95, y + 0.6, 1.8 + 4.2 - t * 1.2), 0.7, 5))
P.append(strut([(-1.3, -33, -0.6), (0, -34.5, -0.8), (1.3, -33, -0.6)], 1.92, 1.92))
skull = join("Bone_Skull", P, 0)
pieces.append(skull)

# ── 갈비뼈 우리: 칼날 등뼈 가시 + 칼날 갈비(끝 뾰족) ──
P = []
for i in range(12):
    y = i * 5.6
    z = 23 - i * 0.35
    P.append(lump((0, y, z), (2.6, 2.0, 2.4), 6, 3))  # 몸통뼈(모남)
    # 신경 가시: 납작한 칼날(뒤로 기움, 앞쪽 몇 마디가 가장 높다)
    h = 9 - abs(i - 4) * 0.7
    P.append(strut([(0, y - 0.6, z + 1.5), (0, y + 1.6, z + 1.5 + h * 0.6), (0, y + 3.4, z + 1.5 + h)], 1.6, 0.05, res=0, smooth=3, flat=0.35))
    for sx in (-1, 1):
        P.append(spike((sx * 1.8, y, z), (sx * 5.5, y + 1.2, z + 1.0), 0.8))  # 가로 돌기
for k in range(7):
    y = 6 + k * 7.5
    span = 1.0 - k * 0.07
    for sx in (-1, 1):
        P.append(strut([(sx * 2.2, y, 22.5), (sx * 12 * span, y + 1.2, 25 * span), (sx * 20 * span, y + 2.8, 15),
                        (sx * 19 * span, y + 4.2, 3), (sx * 13 * span, y + 5.2, -5)], 1.5, 0.05, res=0, smooth=5, flat=0.55))
ribcage = join("Bone_Ribcage", P, 120)
pieces.append(ribcage)

# ── 꼬리뼈: S 자, 마디마다 칼날 가시, 끝은 가시 셋 ──
P = []
n = 16
for i in range(n):
    t = i / (n - 1)
    x = math.sin(t * math.pi * 1.4) * 9
    y = t * 62
    r = 3.0 - 2.2 * t
    z = r * 0.4
    P.append(lump((x, y, z), (r, r * 0.8, r * 0.9), 6, 3))
    P.append(spike((x, y, z + r * 0.6), (x, y + 2.0 * (1 - t) + 1.0, z + r + 3.6 * (1 - t) + 1.2), 0.9 * (1 - t) + 0.35))
    if i % 2 == 0:
        for sx in (-1, 1):
            P.append(spike((x, y, z), (x + sx * (r + 2.2), y + 0.8, z), 0.6 * (1 - t) + 0.25))
tip = (math.sin(math.pi * 1.4) * 9, 62, 0.4)
for dx in (-2.5, 0, 2.5):
    P.append(spike(tip, (tip[0] + dx, 67, 2.0 + abs(dx) * 0.2), 0.7))
tail = join("Bone_Tail", P, 240)
pieces.append(tail)

# ── 엄니: 모난 휜 송곳니, 등 능선 가시 + 끝 뾰족 ──
P = [strut([(0, 0, -6), (0, 3, 8), (0, 12, 20), (0, 25, 27), (0, 36, 24), (0, 43, 17)], 5.0, 0.04, res=1, smooth=6)]
for k in range(5):
    t = k / 4
    P.append(spike((0, 4 + t * 26, 8 + t * 16), (0, 2 + t * 26, 12 + t * 17), 1.0 - t * 0.4))
tusk = join("Bone_Tusk", P, 330)
pieces.append(tusk)

# ── 넓적다리뼈: 모난 몸통 + 모난 관절머리·무릎 돌기 + 돌기 가시 ──
P = [strut([(0, -12, 2.6), (0, 0, 2.4), (0, 12, 2.8)], 2.2, 2.0, res=1, smooth=2)]
P.append(lump((1.4, -13, 3.8), (3.8, 3.4, 3.6), 6, 4))
P.append(lump((-1.5, -12.5, 2.8), (2.6, 2.8, 2.6), 6, 3))
P.append(lump((-1.8, 13, 3.0), (2.6, 3.0, 3.0), 6, 3))
P.append(lump((1.8, 13, 3.0), (2.6, 3.0, 3.0), 6, 3))
P.append(spike((2, -8, 4), (5, -10, 6.5), 1.0))
femur = join("Bone_Femur", P, 400)
pieces.append(femur)

bpy.ops.mesh.primitive_cube_add(size=0.8, location=(0, 0, 0))
marker = bpy.context.active_object
marker.name = "Bones_Marker"

bpy.ops.object.select_all(action="DESELECT")
for o in pieces + [marker]:
    o.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=OUT, use_selection=True, global_scale=1.0, apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y", object_types={"MESH"}, mesh_smooth_type="FACE",
)
print("FBX", OUT)

# 미리보기: 조각마다 3/4 앞 위
os.makedirs(RENDER, exist_ok=True)
cam = link(bpy.data.objects.new("cam", bpy.data.cameras.new("cam")))
cam.data.lens = 35
scene.camera = cam
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.render.resolution_x, scene.render.resolution_y = 900, 700
for o in pieces:
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    c = (lo + hi) / 2
    size = (hi - lo).length
    cam.location = c + Vector((size * 0.75, -size * 0.85, size * 0.5))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(RENDER, o.name + ".png")
    bpy.ops.render.render(write_still=True)
