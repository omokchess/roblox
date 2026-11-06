# -*- coding: utf-8 -*-
"""
build_callisto_skysphere.py — 2026-11-02. 칼리스토 2·3페이즈 배경 우주 사진을 입힐 하늘 구(스카이스피어).
사용자: "2페 돌입 때 우주가 카메라 따라가는거 수정해야 함. 스카이스피어 쓰면 될듯."

안쪽이 앞면인 구(반지름 1, 극 = 블렌더 z = 로블록스 Y) 하나 + 1×1×1 표지 CallistoSkySphere_Marker.
  · 면 순서를 뒤집어 법선이 구 가운데를 향한다 — 가운데(카메라)에서 올려다보면 앞면이다(로블록스 컬링은 감는 방향 기준)
  · 그림은 이음매 없는 1024² 타일(models/callisto_tex/SpaceLayer.png → CallistoAssets 속성 SpaceLayerImage)을 UV 0~1 밖으로 내보내지 않고
    '조각' 18장(경도 6 × 위도 3, 한 조각 60°×60°)이 저마다 그림 한 장을 통째로 쓰게 짠다. UV 를 0~1 밖으로 반복시키면 로블록스 텍스처 처리가
    어떻게 나올지 몰라서다. 타일이 이음매 없이 이어지니 조각 경계는 안 보인다(UV 는 반 텍셀 안쪽으로 물려 끝 텍셀끼리 맞닿게)
  · 적도에서 텍셀이 정사각(경도 60° = 위도 60° = 그림 한 장). 카메라가 보는 곳(수평선 둘레)이 적도 가까이라 극 쪽 찌그러짐은 안 보인다
돌리기: blender -b -P models/build_callisto_skysphere.py [-- render]   →  models/CallistoSkySphere.glb  →  Ctrl+M  →  tools/Callisto_SkySphere.luau
render: 구 안쪽에서 본 모습을 models/out/skysphere_inside.png 로 그려 확인(뒷면으로 보이면 빨강)
"""
import json
import math
import os
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = "render" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
NAME = "CallistoSkySphere"
TILES_U, TILES_V = 6, 3          # 경도 6 × 위도 3 조각
SEG_U, SEG_V = 20, 12            # 한 조각을 나눈 칸(경도 3° · 위도 5°)
TEXELS = 1024                    # 타일 그림 한 변
PAD = 0.5 / TEXELS               # UV 를 반 텍셀 안쪽으로


def build_mesh():
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for pv in range(TILES_V):
        for pu in range(TILES_U):
            grid = {}
            for j in range(SEG_V + 1):
                lat = math.pi * ((pv + j / SEG_V) / TILES_V - 0.5)
                for i in range(SEG_U + 1):
                    lon = math.tau * (pu + i / SEG_U) / TILES_U
                    c = math.cos(lat)
                    grid[i, j] = (bm.verts.new((c * math.cos(lon), c * math.sin(lon), math.sin(lat))), i, j)
            for j in range(SEG_V):
                for i in range(SEG_U):
                    # 안쪽이 앞면: (i,j) → 위(j+1) → 위+동쪽 → 동쪽 (바깥에서 보면 시계 방향)
                    quad = [grid[i, j], grid[i, j + 1], grid[i + 1, j + 1], grid[i + 1, j]]
                    verts = []
                    for v, vi, vj in quad:                      # 극에서 겹친 꼭짓점은 하나로(삼각형)
                        if not verts or (v.co - verts[-1][0].co).length > 1e-6:
                            verts.append((v, vi, vj))
                    if len(verts) > 2 and (verts[0][0].co - verts[-1][0].co).length < 1e-6:
                        verts.pop()
                    face = bm.faces.new([v for v, _, _ in verts])
                    for loop, (_, vi, vj) in zip(face.loops, verts):
                        # 안에서 보면 경도가 늘수록 왼쪽 — 그림이 거울로 뒤집히지 않게 u 를 거꾸로
                        loop[uv].uv = (PAD + (1 - 2 * PAD) * (1 - vi / SEG_U), PAD + (1 - 2 * PAD) * (vj / SEG_V))
    me = bpy.data.meshes.new(NAME)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    return me


def checks(me):
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    assert tris <= 20000, tris
    inward = sum(1 for p in me.polygons if p.normal.dot(p.center) < 0)
    assert inward == len(me.polygons), "법선이 바깥을 향한 면 %d" % (len(me.polygons) - inward)
    us = [l.uv[0] for l in me.uv_layers[0].data]
    vs = [l.uv[1] for l in me.uv_layers[0].data]
    assert 0 <= min(us) and max(us) <= 1 and 0 <= min(vs) and max(vs) <= 1, "UV 가 0~1 밖"
    ext = [max(abs(v.co[a]) for v in me.vertices) for a in range(3)]
    assert all(abs(e - 1) < 1e-4 for e in ext), ext
    print("%s: 삼각형 %d · 꼭짓점 %d · 법선 모두 안쪽 · UV %.4f~%.4f · 반지름 1" % (NAME, tris, len(me.vertices), min(us), max(us)))


def make_objects():
    mat = bpy.data.materials.new("SkySphere")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1, 1, 1, 1)
    sky = bpy.data.objects.new(NAME, build_mesh())
    marker_me = bpy.data.meshes.new(NAME + "_Marker")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.to_mesh(marker_me)
    bm.free()
    marker = bpy.data.objects.new(NAME + "_Marker", marker_me)
    for ob in (sky, marker):
        bpy.context.scene.collection.objects.link(ob)
        ob.data.materials.append(mat)
    checks(sky.data)
    return sky, marker


def export(objs):
    # 블렌더 → glTF(+Y 위) 는 (x, z, -y) — 메시를 z 둘레로 반 바퀴 미리 돌려 두면 로블록스에서 (-x, z, y) 가 된다
    rot = Matrix.Rotation(math.pi, 4, "Z")
    for o in objs:
        o.data.transform(rot)
        o.select_set(True)
    path = os.path.join(HERE, NAME + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                              export_materials="EXPORT", export_texcoords=True, export_normals=True)
    for o in objs:
        o.data.transform(rot.inverted())
    # 내보낸 GLB 점검: UV · 법선이 실제로 들어갔는지
    with open(path, "rb") as f:
        f.read(12)
        n, _ = struct.unpack("<II", f.read(8))
        meta = json.loads(f.read(n))
    for mesh in meta["meshes"]:
        attrs = mesh["primitives"][0]["attributes"]
        print("GLB 메시 %-24s %s" % (mesh.get("name"), sorted(attrs)))
        assert "NORMAL" in attrs and ("TEXCOORD_0" in attrs or mesh.get("name") != NAME), "UV/법선이 GLB 에 없다"
    print("GLB:", path)


def render_inside(sky, marker):
    """구 안쪽(카메라 자리 ≈ 반지름의 15%)에서 수평선 둘레를 본 모습. 뒷면으로 보이는 곳은 빨강."""
    scene = bpy.context.scene
    marker.hide_render = True                # 표지 상자는 카메라를 둘러싸므로 뺀다
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.device = "CPU"
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.view_settings.view_transform = "Standard"
    img = bpy.data.images.load(os.path.join(HERE, "callisto_tex", "SpaceLayer.png"))
    mat = bpy.data.materials.new("InsideView")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.extension = "EXTEND"                 # 로블록스와 같게 — 반복시키지 않는다
    emit = nt.nodes.new("ShaderNodeEmission")
    red = nt.nodes.new("ShaderNodeEmission")
    red.inputs["Color"].default_value = (1, 0, 0, 1)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mix = nt.nodes.new("ShaderNodeMixShader")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(tex.outputs["Color"], emit.inputs["Color"])
    nt.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
    nt.links.new(emit.outputs["Emission"], mix.inputs[1])
    nt.links.new(red.outputs["Emission"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    sky.data.materials.clear()
    sky.data.materials.append(mat)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.location = Vector((0.15, -0.06, 0.06))
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(70)
    cam.rotation_euler = (math.radians(80), 0, math.radians(20))      # 수평에서 10° 내려다봄
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.0, 0.25, 0.0, 1)   # 구가 안 덮인 곳은 초록
    out_dir = os.path.join(HERE, "out")
    os.makedirs(out_dir, exist_ok=True)
    scene.render.filepath = os.path.join(out_dir, "skysphere_inside.png")
    bpy.ops.render.render(write_still=True)
    print("렌더:", scene.render.filepath)


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sky_obj, marker_obj = make_objects()
    bpy.ops.object.select_all(action="DESELECT")
    export([sky_obj, marker_obj])
    if RENDER:
        render_inside(sky_obj, marker_obj)
