# -*- coding: utf-8 -*-
"""
swamp2_preview.py — 늪지대 2판 미리보기(블렌더). (2026-09-28)
- flora : swamp/flora.txt 의 틀을 한 줄로 세워 찍는다 → swamp/flora_lineup.png
- scene [장면...] : 흙 판·물 판·길·풀나무·안개늪 건물을 place2/ground2 대로 앉혀 찍는다 → swamp/preview2_<장면>.png
좌표: 로블록스 (x, y, z) → 블렌더 (x, -z, y)
돌리는 법: blender --background --python tools/swamp2_preview.py -- flora | scene overview village ...
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
REFASSETS = os.path.join("C:" + os.sep, "wth", "roblox", "assets")


def rb(x, y, z):
    return Vector((x, -z, y))


def lin(c):
    return tuple((v / 255) ** 2.2 for v in c) + (1,)


def srgb(c):
    return tuple(v / 255 for v in c) + (1,)


MAT_ROUGH = {"Neon": 0.5, "SmoothPlastic": 0.4, "Glass": 0.05}


def box_verts(cf, size):
    """cf = (x,y,z, r00..r22) 로블록스. 8 꼭짓점(블렌더 좌표)."""
    x, y, z = cf[0:3]
    R = Matrix(((cf[3], cf[4], cf[5]), (cf[6], cf[7], cf[8]), (cf[9], cf[10], cf[11])))
    out = []
    for sx in (-0.5, 0.5):
        for sy in (-0.5, 0.5):
            for sz in (-0.5, 0.5):
                lv = Vector((sx * size[0], sy * size[1], sz * size[2]))
                w = R @ lv + Vector((x, y, z))
                out.append(rb(w.x, w.y, w.z))
    return out


FACES = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]


def mesh_from_boxes(name, boxes):
    """boxes: [(cf12, size3, color, material)] → 한 메시(꼭짓점 색)."""
    bm = bmesh.new()
    col_layer = bm.loops.layers.color.new("Col")
    emit_faces = []
    for (cf, size, col, mat) in boxes:
        vs = [bm.verts.new(v) for v in box_verts(cf, size)]
        for f in FACES:
            try:
                face = bm.faces.new([vs[i] for i in f])
            except ValueError:
                continue
            c = srgb(col)
            if mat == "Neon":
                c = tuple(min(1.0, v * 2.2) for v in c[:3]) + (1,)
            for loop in face.loops:
                loop[col_layer] = c
            face.smooth = False
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    m = bpy.data.materials.get("VCol")
    if not m:
        m = bpy.data.materials.new("VCol")
        m.use_nodes = True
        nt = m.node_tree
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        nt.links.new(vc.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
        nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    return ob


def read_flora():
    T = {}
    for line in open(os.path.join(HERE, "swamp", "flora.txt"), encoding="utf-8").read().split("\n"):
        if not line:
            continue
        f = line.split("\t")
        cf = [float(v) for v in f[4].split()]
        size = [float(v) for v in f[5].split()]
        col = tuple(int(v) for v in f[3].split(","))
        T.setdefault(f[0], []).append((cf, size, col, f[2]))
    return T


def read_dump():
    """treedump.txt(평원·숲 나무 부품 목록) → 틀. rot 는 ToOrientation(rx, ry, rz) = Y·X·Z."""
    T = {}
    cur = None
    for line in open(os.path.join(HERE, "swamp", "treedump.txt"), encoding="utf-8").read().split("\n"):
        if line.startswith("== "):
            cur = "REF_" + line.split()[1]
            continue
        f = line.split()
        if not cur or len(f) < 14 or "pos" not in f:
            continue
        i = f.index("pos")
        x, y, z = float(f[i + 1]), float(f[i + 2]), float(f[i + 3])
        sx, sy, sz = float(f[i + 5]), float(f[i + 6]), float(f[i + 7])
        rx, ry, rz = (math.radians(float(v)) for v in f[i + 9:i + 12])
        R = Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(rz, 3, "Z")
        col = tuple(int(v) for v in f[2].split(","))
        cf = [x, y, z, R[0][0], R[0][1], R[0][2], R[1][0], R[1][1], R[1][2], R[2][0], R[2][1], R[2][2]]
        T.setdefault(cur, []).append((cf, (sx, sy, sz), col, f[1]))
    return T


def setup_render(res=(1600, 900)):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = eng
            break
        except Exception:
            pass
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.world = bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.7, 1)
    sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.4
    sun.rotation_euler = (math.radians(48), 0, math.radians(30))
    sc.collection.objects.link(sun)


def shoot(name, cam_p, tgt, lens, path):
    sc = bpy.context.scene
    cam = bpy.data.objects.new("Cam_" + name, bpy.data.cameras.new("C"))
    cam.data.lens = lens
    cam.data.clip_end = 8000
    cam.location = rb(*cam_p)
    d = rb(*tgt) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("찍음", name)


def flora_lineup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    T = read_dump()
    T.update(read_flora())
    x = 0.0
    for name, boxes in T.items():
        ob = mesh_from_boxes(name, boxes)
        ob.location = rb(x, 0, 0)
        bpy.context.scene.collection.objects.link(ob)
        w = 70 if name.startswith("REF_For") else (30 if name.startswith(("Cyp", "Man", "Dead", "Brd", "REF")) else 12)
        x += w
    bpy.ops.mesh.primitive_plane_add(size=1, location=rb(x / 2, 0, 0))
    g = bpy.context.active_object
    g.scale = (x + 60, 80, 1)
    m = bpy.data.materials.new("G")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin((84, 82, 59))
    g.data.materials.append(m)
    setup_render((2000, 700))
    shoot("flora", (x * 0.36, 70, 230), (x * 0.36, 16, 0), 24, os.path.join(HERE, "swamp", "flora_lineup.png"))
    shoot("flora_a", (190, 34, 95), (190, 18, 0), 28, os.path.join(HERE, "swamp", "flora_a.png"))
    shoot("flora_b", (330, 30, 80), (330, 12, 0), 28, os.path.join(HERE, "swamp", "flora_b.png"))
    shoot("flora_c", (440, 26, 70), (440, 8, 0), 28, os.path.join(HERE, "swamp", "flora_c.png"))
    shoot("flora_d", (640, 14, 38), (640, 2, 0), 30, os.path.join(HERE, "swamp", "flora_d.png"))


SHOTS = {
    "overview": ((2350, 1000, 2400), (2350, 0, 1080), 24),
    "village": ((1990, 110, 860), (1880, 5, 990), 30),
    "tavern": ((2080, 70, 1230), (1960, 5, 1150), 32),
    "south": ((2110, 80, 1360), (2005, 5, 1260), 30),
    "witch": ((2470, 45, 930), (2425, 8, 810), 35),
    "shrine": ((2760, 70, 1390), (2920, 5, 1210), 30),
    "hill": ((2300, 60, 1180), (2400, 8, 1060), 30),
    "homestead": ((2640, 45, 780), (2705, 8, 650), 32),
    "west": ((1560, 90, 1500), (1640, 5, 1150), 30),
}


def palette_mats():
    import json
    pal = json.load(open(os.path.join(REFASSETS, "palette.json"), encoding="utf-8"))
    mats = {}
    for k, v in pal.items():
        m = bpy.data.materials.new("P_" + k)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = lin(v["color"])
        b.inputs["Roughness"].default_value = 0.85
        if v["material"] == "Neon":
            b.inputs["Emission Color"].default_value = lin(v["color"])
            b.inputs["Emission Strength"].default_value = 3.0
        mats[k] = m
    return pal, mats


def kit_collections(names):
    pal, mats = palette_mats()
    cols = {}
    for a in sorted(names):
        src = os.path.join(HERE, "..", "models", "swamp_ref", "fbx") if a in ("StiltHouseB2", "BoardwalkOpen") else os.path.join(REFASSETS, "fbx")
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=os.path.join(src, a + ".fbx"))
        c = bpy.data.collections.new("K_" + a)
        for o in [o for o in bpy.data.objects if o not in before]:
            for uc in list(o.users_collection):
                uc.objects.unlink(o)
            c.objects.link(o)
            if o.type == "MESH" and "__" in o.name:
                key = o.name.split("__", 1)[1].split(".")[0]
                if key not in pal:
                    key = key.rsplit("_", 1)[0]
                if key in mats:
                    o.data.materials.clear()
                    o.data.materials.append(mats[key])
        cols[a] = c
    return cols


def read_rows(name):
    txt = open(os.path.join(HERE, "swamp", name), encoding="utf-8").read()
    return [line.split(chr(9)) for line in txt.split(chr(10)) if line]


def scene(shots):
    sys.path.insert(0, HERE)
    import swamp2_plan as SP
    bpy.ops.wm.read_factory_settings(use_empty=True)
    slabs = SP.load_slabs()
    H = SP.top_grid(slabs, [tuple(f) for f in SP.FILLS])
    sc = bpy.context.scene
    # 흙 판·바위
    boxes = []
    for s in slabs:
        c, sn = math.cos(math.radians(s.yaw)), math.sin(math.radians(s.yaw))
        boxes.append(([s.x, s.y, s.z, c, 0, sn, 0, 1, 0, -sn, 0, c], (s.sx, s.sy, s.sz), s.col, "Mud"))
    sc.collection.objects.link(mesh_from_boxes("Slabs", boxes))
    # 땅·길(불투명), 물(반투명)
    solid, water = [], []
    for f in read_rows("ground2.txt"):
        x, y, z = (float(v) for v in f[4].split())
        yaw = float(f[5])
        sx, sy, sz = (float(v) for v in f[6].split())
        c, sn = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        cf = [x, y, z, c, 0, sn, 0, 1, 0, -sn, 0, c]
        col = tuple(int(v) for v in f[3].split(","))
        (water if f[0] == "물" else solid).append((cf, (sx, sy, sz), col, f[2]))
    sc.collection.objects.link(mesh_from_boxes("Ground2", solid))
    wo = mesh_from_boxes("Water2", water)
    wm = bpy.data.materials.new("WaterMat")
    wm.use_nodes = True
    b = wm.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin((54, 74, 58))
    b.inputs["Roughness"].default_value = 0.1
    b.inputs["Alpha"].default_value = 0.8
    try:
        wm.surface_render_method = "BLENDED"
    except Exception:
        pass
    wo.data.materials.clear()
    wo.data.materials.append(wm)
    sc.collection.objects.link(wo)
    # 풀나무 틀
    fcols = {}
    for name, bx in read_flora().items():
        c = bpy.data.collections.new("F_" + name)
        c.objects.link(mesh_from_boxes("T_" + name, bx))
        fcols[name] = c
    rows = read_rows("place2.txt")
    kcols = kit_collections({r[1] for r in rows if r[0] == "K"})
    for r in rows:
        src, a, x, z, ys, yaw, s = r[0], r[1], float(r[2]), float(r[3]), r[4], float(r[5]), float(r[6])
        try:
            y = float(ys)
        except ValueError:
            off = float(ys[1:]) if len(ys) > 1 else 0.0
            base = {"w": SP.WATER, "d": SP.DECK}.get(ys[0])
            y = (base if base is not None else float(SP.T(H, x, z))) + off
        e = bpy.data.objects.new(a, None)
        e.instance_type = "COLLECTION"
        e.instance_collection = (kcols if src == "K" else fcols)[a]
        e.location = rb(x, y, z)
        e.rotation_euler = (0, 0, math.radians(yaw))
        e.scale = (s, s, s)
        sc.collection.objects.link(e)
    setup_render()
    for name in shots:
        cam_p, tgt, lens = SHOTS[name]
        shoot(name, cam_p, tgt, lens, os.path.join(HERE, "swamp", "preview2_%s.png" % name))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["flora"]
    if args[0] == "flora":
        flora_lineup()
    elif args[0] == "scene":
        scene(args[1:] or list(SHOTS))