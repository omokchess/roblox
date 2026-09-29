# -*- coding: utf-8 -*-
"""
swamp_preview.py — 늪지대 배치 미리보기(블렌더 렌더). (2026-09-28)

Studio 화면이 안 그려질 때 눈으로 확인하려고 만든 대리 장면이다.
swamp_plan.py 의 지형 높이·재질로 땅을 만들고, 안개늪 에셋 FBX 를 place.txt 자리에 인스턴스로 앉혀
몇 곳을 찍는다. 좌표: 로블록스 (X, Y, Z) → 블렌더 (X, -Z, Y), 로블록스 y 축 회전 θ → 블렌더 z 축 +θ.
(참고 프로젝트 FBX 는 가져오면 그쪽 블렌더 좌표 그대로라 로블록스 로컬과 이 관계가 맞는다)

돌리는 법: blender --background --python tools/swamp_preview.py -- [장면이름 ...]
결과: tools/swamp/preview_<장면>.png
"""
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import swamp_plan as P  # noqa: E402

FBX = r"C:\wth\roblox\assets\fbx"
PAL = json.load(open(r"C:\wth\roblox\assets\palette.json", encoding="utf-8"))

SHOTS = {
    # 이름: (카메라 로블록스 자리, 바라보는 곳, 렌즈 mm)
    "overview": ((2350, 900, 2350), (2350, 0, 1080), 26),
    "village": ((1990, 120, 1200), (1862, 5, 930), 30),
    "village_s": ((2150, 70, 1330), (2010, 5, 1300), 30),
    "witch": ((2470, 45, 930), (2425, 8, 805), 35),
    "shrine": ((2760, 70, 1380), (2920, 5, 1200), 30),
    "hill": ((2300, 60, 1180), (2400, 8, 1060), 30),
    "homestead": ((2640, 40, 760), (2705, 5, 650), 32),
    "west": ((1560, 90, 1500), (1640, 5, 1150), 30),
}


def rb(x, y, z):
    return (x, -z, y)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgb, kind="", alpha=1.0, emit=0.0, rough=0.85):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    col = (rgb[0] / 255) ** 2.2, (rgb[1] / 255) ** 2.2, (rgb[2] / 255) ** 2.2, 1
    b.inputs["Base Color"].default_value = col
    b.inputs["Roughness"].default_value = rough
    if kind in ("Metal", "CorrodedMetal"):
        b.inputs["Metallic"].default_value = 0.6
    if emit > 0:
        b.inputs["Emission Color"].default_value = col
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    return m


def terrain(h, mat, out):
    import numpy as np
    NZ, NX = h.shape
    verts, faces, cols = [], [], []
    idx = -np.ones((NZ, NX), int)
    MC = {P.M[k]: v for k, v in P.MCOL.items()}
    for j in range(NZ):
        for i in range(NX):
            if out[j, i]:
                continue
            idx[j, i] = len(verts)
            x = P.X0 + P.R * i + 2
            z = P.Z0 + P.R * j + 2
            verts.append(rb(x, float(h[j, i]), z))
            cols.append(MC[int(mat[j, i])])
    for j in range(NZ - 1):
        for i in range(NX - 1):
            a, b, c, d = idx[j, i], idx[j, i + 1], idx[j + 1, i + 1], idx[j + 1, i]
            if min(a, b, c, d) >= 0:
                faces.append((a, d, c, b))
    me = bpy.data.meshes.new("Terrain")
    me.from_pydata(verts, [], faces)
    me.update()
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for k, c in enumerate(cols):
        ca.data[k].color = ((c[0] / 255) ** 2.2, (c[1] / 255) ** 2.2, (c[2] / 255) ** 2.2, 1)
    ob = bpy.data.objects.new("Terrain", me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.new("TerrainMat")
    m.use_nodes = True
    nt = m.node_tree
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    # 물: 섬 안 칸에만(수면 y = 0)
    wv, wf, wid = [], [], -np.ones((NZ + 1, NX + 1), int)
    for j in range(NZ):
        for i in range(NX):
            if out[j, i]:
                continue
            q = []
            for dj, di in ((0, 0), (1, 0), (1, 1), (0, 1)):
                if wid[j + dj, i + di] < 0:
                    wid[j + dj, i + di] = len(wv)
                    wv.append(rb(P.X0 + P.R * (i + di), 0.0, P.Z0 + P.R * (j + dj)))
                q.append(wid[j + dj, i + di])
            wf.append(tuple(q))
    wm = bpy.data.meshes.new("Water")
    wm.from_pydata(wv, [], wf)
    wm.update()
    w = bpy.data.objects.new("Water", wm)
    bpy.context.scene.collection.objects.link(w)
    w.data.materials.append(material("Water", (46, 62, 40), alpha=0.82, rough=0.08))


def asset_collections(names):
    cols = {}
    for a in sorted(names):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=os.path.join(FBX, a + ".fbx"))
        new = [o for o in bpy.data.objects if o not in before]
        c = bpy.data.collections.new("A_" + a)
        for o in new:
            for uc in list(o.users_collection):
                uc.objects.unlink(o)
            c.objects.link(o)
            if o.type == "MESH":
                key = o.name.split("__", 1)[1].split(".")[0] if "__" in o.name else ""
                if key not in PAL:
                    key = key.rsplit("_", 1)[0]  # 같은 재질 메시가 둘이면 _1, _2 가 붙는다
                s = PAL.get(key)
                if not s:
                    print("팔레트 없음", o.name)
                if s:
                    o.data.materials.clear()
                    o.data.materials.append(material("P_" + key, s["color"], s["material"], 1 - s["transparency"],
                                                     3.0 if s["material"] == "Neon" else 0.0))
        cols[a] = c
    return cols


def main():
    import numpy as np
    want = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(SHOTS)
    reset()
    X, Z, h, mat, out = P.build_terrain()
    terrain(h, mat, out)
    rows = [l.split("\t") for l in open(os.path.join(HERE, "swamp", "place.txt"), encoding="utf-8").read().split("\n") if l]
    cols = asset_collections({r[0] for r in rows})
    for r in rows:
        a, x, z, ys, yaw, s = r[0], float(r[1]), float(r[2]), r[3], float(r[4]), float(r[5])
        if ys.startswith("g"):
            y = float(P.sample(h, x, z)) + (float(ys[1:]) if len(ys) > 1 else 0)
        else:
            y = float(ys)
        e = bpy.data.objects.new(a, None)
        e.instance_type = "COLLECTION"
        e.instance_collection = cols[a]
        e.location = rb(x, y, z)
        e.rotation_euler = (0, 0, math.radians(yaw))
        e.scale = (s, s, s)
        bpy.context.scene.collection.objects.link(e)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = eng
            break
        except Exception:
            pass
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    sc.world = bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.6, 0.52, 1)
    sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    sc.collection.objects.link(sun)
    for name in want:
        cam_p, tgt, lens = SHOTS[name]
        cam = bpy.data.objects.new("Cam_" + name, bpy.data.cameras.new("C"))
        cam.data.lens = lens
        cam.data.clip_end = 6000
        cam.location = rb(*cam_p)
        d = [rb(*tgt)[k] - cam.location[k] for k in range(3)]
        from mathutils import Vector
        cam.rotation_euler = Vector(d).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(cam)
        sc.camera = cam
        sc.render.filepath = os.path.join(HERE, "swamp", "preview_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("찍음", name)


main()
