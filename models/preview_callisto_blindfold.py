# -*- coding: utf-8 -*-
"""
preview_callisto_blindfold.py — 칼리스토 별 눈가리개 2판 미리보기(2026-11-07). Combat/Callisto.luau 의 BF_* 상수·별 뿌리는 규칙(scatterStars)을
그대로 옮겨(난수만 파이썬 것 — 실제 자리와 똑같지는 않고 분포가 같다) 머리(타원체) + 반투명 성운 띠 두 겹 + 별 + 별자리 선을 렌더한다.
→ art/callisto/blindfold_{A,B,C}_{front,q34}.png (A·B·C = V_Blindfold 1·2·3), blindfold_preview.png = A 앞면.
돌리기: blender -b -P models/preview_callisto_blindfold.py
로블록스 (x, y, z) → 블렌더 (x, -z, y) — 앞(-Z)이 블렌더 +y.
"""
import math
import os
import random
import re

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
src = open(os.path.join(ROOT, "src", "client", "Combat", "Callisto.luau"), encoding="utf-8").read()
BF_R = float(re.search(r"local BF_R = ([\d.]+)", src).group(1))
BF_Y = float(re.search(r"local BF_Y = (-?[\d.]+)", src).group(1))
SIZES = [float(v) for v in re.search(r"local BF_SIZE = \{ ([\d., ]+) \}", src).group(1).split(",")]
LOOKS = [{"Haze": float(h), "HazeH": float(hh), "Density": float(d), "Big": float(b)}
         for h, hh, d, b in re.findall(r"Haze = ([\d.]+), HazeH = ([\d.]+), Density = ([\d.]+), Big = ([\d.]+)", src)]
COLORS = [(0.84, 0.91, 1.0), (0.59, 0.78, 1.0), (1.0, 0.89, 0.67), (0.81, 0.72, 1.0)]
NEB_A, NEB_B = (0.59, 0.75, 1.0), (0.71, 0.55, 1.0)


def scatter(look):
    rng = random.Random(11)
    out = []
    for row in range(17):
        y0 = -0.27 + row * 0.03
        dy = y0 - BF_Y
        vert = math.exp(-((dy / 0.15) ** 2))
        for col in range(78):
            ang = (col * 360 / 78 + 180) % 360 - 180
            front = 0.18 + 0.82 * max(0, math.cos(math.radians(ang))) ** 1.3
            eye = 1 + 1.3 * math.exp(-(((abs(ang) - 19) / 20) ** 2) - (dy / 0.07) ** 2)
            if rng.random() < min(0.9, 0.26 * look["Density"] * front * vert * eye):
                k = rng.random()
                g = 1 if k < 0.58 else 2 if k < 0.86 else 3 if k < 0.96 else 4
                if g < 4 and rng.random() < 0.06 * (look["Big"] - 1):
                    g += 1
                out.append((ang + rng.uniform(-2, 2), y0 + rng.uniform(-0.012, 0.012), g))
    return out


def pos(a, y, r=BF_R):
    t = math.radians(a)
    return Vector((math.sin(t) * r, math.cos(t) * r, y))     # 앞 = +y


def emissive(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Emission Color"].default_value = (*color, 1)
    b.inputs["Emission Strength"].default_value = strength
    return m


def haze_material(name, color, peak, h):
    """띠 가운데가 투명도 peak, 위아래로 풀려 완전 투명(세로 그라디언트) — SurfaceGui 그라디언트와 같은 꼴."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    mix = nt.nodes.new("ShaderNodeMixShader")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    em.inputs["Strength"].default_value = 3.0
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    # 가장자리까지 거리 e = 1 - |z - BF_Y| / (h/2) → 불투명도 = (1 - peak) * clamp(e)^1.2
    sub = nt.nodes.new("ShaderNodeMath"); sub.operation = "SUBTRACT"; sub.inputs[1].default_value = BF_Y
    ab = nt.nodes.new("ShaderNodeMath"); ab.operation = "ABSOLUTE"
    dv = nt.nodes.new("ShaderNodeMath"); dv.operation = "DIVIDE"; dv.inputs[1].default_value = h / 2
    one = nt.nodes.new("ShaderNodeMath"); one.operation = "SUBTRACT"; one.inputs[0].default_value = 1.0; one.use_clamp = True
    pw = nt.nodes.new("ShaderNodeMath"); pw.operation = "POWER"; pw.inputs[1].default_value = 1.2
    mu = nt.nodes.new("ShaderNodeMath"); mu.operation = "MULTIPLY"; mu.inputs[1].default_value = 1.0 - peak
    L = nt.links.new
    L(tc.outputs["Object"], sep.inputs[0])
    L(sep.outputs["Z"], sub.inputs[0]); L(sub.outputs[0], ab.inputs[0]); L(ab.outputs[0], dv.inputs[0])
    L(dv.outputs[0], one.inputs[1]); L(one.outputs[0], pw.inputs[0]); L(pw.outputs[0], mu.inputs[0])
    L(mu.outputs[0], mix.inputs[0]); L(tr.outputs[0], mix.inputs[1]); L(em.outputs[0], mix.inputs[2])
    L(mix.outputs[0], out.inputs[0])
    return m


def plain(name, color, rough=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def render_look(idx, tag):
    look = LOOKS[idx]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    col = sc.collection
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1.0, location=(0, 0, 0))
    head = bpy.context.active_object
    head.scale = (0.62, 0.62, 0.64)
    head.data.materials.append(plain("Skin", (0.96, 0.82, 0.74), 0.5))
    bpy.ops.object.shade_smooth()
    # 성운 띠 두 겹
    for layer in (1, 2):
        r = BF_R - (0.014 if layer == 1 else 0.03)
        h = look["HazeH"] * (1 if layer == 1 else 0.72)
        peak = min(0.97, look["Haze"] + (0 if layer == 1 else 0.12))
        bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=r, depth=h, location=(0, 0, BF_Y))
        ob = bpy.context.active_object
        ob.data.materials.append(haze_material("Haze%d" % layer, NEB_A if layer == 1 else NEB_B, peak, h))
    stars = scatter(look)
    mats = [emissive("S%d" % i, c, 3.5) for i, c in enumerate(COLORS)]
    for i, (a, y, g) in enumerate(stars, 1):
        r = SIZES[g - 1] / 2
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=r, location=pos(a, y))
        bpy.context.active_object.data.materials.append(mats[(i * 7) % 4])
        if g >= 3:
            L = r * 2 * (2.6 if g == 4 else 1.9)
            for horizontal in (False, True):
                bpy.ops.mesh.primitive_cube_add(size=1, location=pos(a, y, BF_R * 1.012))
                o = bpy.context.active_object
                o.scale = (L, 0.004, 0.004) if horizontal else (0.004, 0.004, L)
                o.rotation_euler = (0, 0, -math.radians(a))
                o.data.materials.append(mats[(i * 7) % 4])
    # 큰 별끼리 별자리 선(열여섯 줄까지)
    line = emissive("Line", COLORS[1], 4)
    linked, n = set(), 0
    for i, (ai, yi, gi) in enumerate(stars):
        if gi < 3 or n >= 16:
            continue
        best, bd = None, 0.34
        for j, (aj, yj, gj) in enumerate(stars):
            d = (pos(ai, yi) - pos(aj, yj)).length
            if j != i and gj >= 2 and d < bd and (j, i) not in linked:
                best, bd = j, d
        if best is not None:
            linked.add((i, best))
            n += 1
            p0, p1 = pos(ai, yi), pos(stars[best][0], stars[best][1])
            bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.004, depth=(p1 - p0).length, location=(p0 + p1) / 2)
            o = bpy.context.active_object
            o.rotation_euler = (p1 - p0).to_track_quat("Z", "Y").to_euler()
            o.data.materials.append(line)
    print("%s안: 별 %d · 선 %d" % (tag, len(stars), n))
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 640, 640
    sc.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.015, 0.02, 0.045, 1)
    for nm, loc, e in (("Key", (-3, 4, 3), 120), ("Rim", (3, -3, 2), 90)):
        ld = bpy.data.lights.new(nm, "AREA")
        ld.energy, ld.size = e, 3
        lo = bpy.data.objects.new(nm, ld)
        col.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    col.objects.link(cam)
    cam.data.lens = 85
    sc.camera = cam
    out = os.path.join(ROOT, "art", "callisto")
    os.makedirs(out, exist_ok=True)
    for view, d in (("front", (0, 1, 0.05)), ("q34", (0.75, 0.7, 0.15))):
        d = Vector(d).normalized()
        cam.location = d * 4.2
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out, "blindfold_%s_%s.png" % (tag, view))
        bpy.ops.render.render(write_still=True)


for i, tag in enumerate("ABC"):
    render_look(i, tag)
import shutil
shutil.copy(os.path.join(ROOT, "art", "callisto", "blindfold_A_front.png"), os.path.join(ROOT, "art", "callisto", "blindfold_preview.png"))
