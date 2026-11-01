# -*- coding: utf-8 -*-
"""
build_callisto_hammer.py — 칼리스토 2·3페이즈 북두칠성 망치(2026-11-01 블렌더판).
사용자: "망치 크기 더 키우고, 망치 쥐고 있는 모션도 손봐야 할 듯 — 지금은 의수마냥 손에 꽂아 놓은 느낌".

무기 공간(로블록스 — WeaponDefinitions 와 같다): 원점 = 오른손(위쪽 쥔 자리), +Y = 자루 → 머리, -Z = 앞 때리는 면, X = 옆.
두 손으로 쥔다: 오른손 y 0 · 왼손 y -0.85(아래 가죽 감은 데). 자루 끝(알카이드) y -1.3, 머리 가운데 y 2.6(길이 2.5 · 폭 1.0 · 높이 1.2).
  북두칠성: 자루 = 손잡이 별 셋(알카이드 자루 끝 · 미자르 + 작은 알코르 · 알리오스), 머리 = 국자 별 넷(양옆 — 메그레즈·페크다·메라크·두베, 빛줄로 이음).
  짙은 푸른 강철 몸 · 금 테·고리·띠·면판 · 가죽 손잡이 둘 · 별은 Glow(스튜디오에서 Neon).
메시 이름 CallistoHammer_Main_<묶음>(BluedSteel · Gold · Leather · Glow · Lines) + 원점 표지 WeaponsOrigin_Marker(1×1×1)
→ models/CallistoHammer.glb → Ctrl+M → tools/WeaponMeshes.luau(→ ReplicatedStorage.WeaponMeshes.CallistoHammer.Main). 색·재질은 WeaponDefinitions Skins.
돌리기: blender -b -P models/build_callisto_hammer.py [-- render]
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_callisto_outfit as O  # noqa: E402

RENDER = "render" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
HOST = "CallistoHammer_Main"
HEAD_Y = 2.6
HW, HH, HL = 0.5, 0.6, 1.25        # 머리 반폭(X) · 반높이(Y) · 반길이(Z)


def R(x, y, z):
    """로블록스 무기 공간 → 블렌더(내보낼 때 (-x, z, y) 로 되돌아온다)."""
    return Vector((-x, z, y))


def shaft_lathe(name, mat, profile, seg=16, sub=1):
    """자루 축(로블록스 Y = 블렌더 z) 둘레로 돌린 몸 — profile = [(반지름, y)]."""
    rows, c0, c1 = O.lathe(profile, seg, Matrix())
    O.finish(O.mesh_obj(name, rows, True, c0, c1), HOST, mat, sub)


def ring_at(name, mat, y, r, h, seg=18):
    shaft_lathe(name, mat, [(r - 0.02, y - h / 2), (r, y - h / 2 + 0.015), (r, y + h / 2 - 0.015), (r - 0.02, y + h / 2)], seg, 1)


def gem(name, center, r, normal=(0, 0, 1), seg=12):
    """별 보석: 반구 + 금 네 갈래 받침(normal = 블렌더 방향)."""
    M = Matrix.Translation(center) @ O.orient(normal)
    rows, c0, c1 = O.lathe([(0.0, -r * 0.3)] + [(r * math.cos(a), r * math.sin(a) * 0.9) for a in (0.0, 0.5, 0.9, 1.25)] + [(0.0, r * 0.95)], seg, M)
    O.finish(O.mesh_obj(name, rows, True, c0, c1), HOST, "Glow", 1)
    pts, top = [], []
    for k in range(8):
        rr = r * (1.9 if k % 2 == 0 else 0.95)
        a = k * math.pi / 4
        pts.append(M @ Vector((rr * math.cos(a), rr * math.sin(a), -0.01)))
        top.append(M @ Vector((rr * 0.85 * math.cos(a), rr * 0.85 * math.sin(a), 0.035)))
    O.finish(O.mesh_obj(name + "Set", [pts, top], True, M @ Vector((0, 0, -0.02)), M @ Vector((0, 0, 0.04))), HOST, "Gold", 0)


def head_ring(z, hw, hh, n=6, seg=28):
    """머리 단면(로블록스 X·Y, 둥근 사각 — 초타원 n) — 블렌더 y = 로블록스 z 에서."""
    out = []
    for k in range(seg):
        a = 2 * math.pi * k / seg
        cx, sy = math.cos(a), math.sin(a)
        px = math.copysign(abs(cx) ** (2 / n), cx) * hw
        py = math.copysign(abs(sy) ** (2 / n), sy) * hh
        out.append(R(-px, HEAD_Y + py, z))   # 블렌더 +y 진행에서 반시계
    return out


def build():
    # 자루(짙은 푸른 강철) — 끝에서 머리 속까지, 살짝 가늘어진다
    shaft_lathe("Shaft", "BluedSteel", [(0.0, -1.18), (0.1, -1.18), (0.112, -0.6), (0.108, 0.6), (0.1, 1.6), (0.096, HEAD_Y - 0.2), (0.0, HEAD_Y - 0.2)], 16, 1)
    # 가죽 손잡이 둘(두 손) — 감은 결이 도드라지게 물결
    for name, y0, y1 in (("GripLow", -1.08, -0.56), ("GripHigh", -0.3, 0.32)):
        prof = [(0.12, y0)]
        n = int((y1 - y0) / 0.045)
        for i in range(n + 1):
            y = y0 + (y1 - y0) * i / n
            prof.append((0.138 + 0.01 * (1 if i % 2 == 0 else -1), y))
        prof.append((0.12, y1))
        shaft_lathe(name, "Leather", prof, 16, 1)
    # 자루 끝(금 잔 + 알카이드)
    shaft_lathe("Pommel", "Gold", [(0.0, -1.38), (0.1, -1.37), (0.17, -1.3), (0.19, -1.22), (0.15, -1.16), (0.13, -1.12), (0.0, -1.12)], 18, 1)
    gem("Alkaid", R(0, -1.4, 0), 0.13, normal=(0, 0, -1))
    # 금 고리들(손잡이 경계 · 미자르 · 알리오스 · 머리 소켓)
    for i, (y, r, h) in enumerate(((-0.52, 0.14, 0.06), (-0.34, 0.15, 0.05), (0.36, 0.15, 0.05), (0.72, 0.16, 0.14), (1.62, 0.16, 0.14))):
        ring_at("Ring%d" % i, "Gold", y, r, h)
    shaft_lathe("Socket", "Gold", [(0.12, 1.86), (0.16, 1.9), (0.22, 1.98), (0.3, HEAD_Y - HH + 0.02), (0.12, HEAD_Y - HH + 0.02)], 18, 1)
    # 손잡이 별: 미자르(+ 작은 알코르) · 알리오스 — 고리 앞에 박힘
    gem("Mizar", R(0, 0.72, -0.165), 0.085, normal=(0, -1, 0))
    gem("Alcor", R(0.13, 0.86, -0.14), 0.04, normal=(-0.6, -1, 0))
    gem("Alioth", R(0, 1.62, -0.165), 0.09, normal=(0, -1, 0))
    # 머리 쇠띠(랑겟) 넷 — 머리에서 자루 아래로
    for sx, sz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        rows = []
        for y in O.lin(1.78, HEAD_Y - HH + 0.05, 6):
            off = 0.112 + 0.02 * (y - 1.78)
            w = 0.035
            if sx:
                rows.append([R(sx * off, y, -w * sx), R(sx * off, y, w * sx)])
            else:
                rows.append([R(w * sz, y, sz * off), R(-w * sz, y, sz * off)])
        O.finish(O.mesh_obj("Langet", rows), HOST, "Gold", 1, solid=0.018, offset=0.0)
    # 머리(짙은 강철): 가운데 굵고 → 목 → 양 끝 면으로 퍼짐
    secs = [(-HL, 0.5, 0.6), (-HL + 0.05, 0.56, 0.66), (-1.05, 0.5, 0.6), (-0.85, 0.44, 0.54), (-0.45, 0.47, 0.58), (0.0, 0.5, 0.6),
            (0.45, 0.47, 0.58), (0.85, 0.44, 0.54), (1.05, 0.5, 0.6), (HL - 0.05, 0.56, 0.66), (HL, 0.5, 0.6)]
    rows = [head_ring(z, w, h) for z, w, h in secs]
    O.finish(O.mesh_obj("Head", rows, True, R(0, HEAD_Y, -HL), R(0, HEAD_Y, HL)), HOST, "BluedSteel", 1)
    # 금 띠(면 가까이 · 가운데 두 줄)
    for z in (-1.02, 1.02, -0.25, 0.25):
        w, h = (0.51, 0.61) if abs(z) > 0.5 else (0.495, 0.595)
        rows = [head_ring(z - 0.05, w + 0.01, h + 0.01), head_ring(z - 0.03, w + 0.035, h + 0.035), head_ring(z + 0.03, w + 0.035, h + 0.035), head_ring(z + 0.05, w + 0.01, h + 0.01)]
        O.finish(O.mesh_obj("Band", rows, True), HOST, "Gold", 1)
    # 때리는 면판(양쪽, 금 — 가운데 짙은 별 문양 돋을새김)
    for sz in (-1, 1):
        z0 = sz * (HL + 0.005)
        rows = []
        for k, (dz, w, h) in enumerate(((0.0, 0.53, 0.63), (0.025, 0.5, 0.6), (0.045, 0.4, 0.48))):
            ring = head_ring(z0 + sz * dz, w, h)
            rows.append(ring if sz > 0 else ring[::-1])
        O.finish(O.mesh_obj("Face", rows, True, None, R(0, HEAD_Y, z0 + sz * 0.06)), HOST, "Gold", 1)
        pts, top = [], []
        for k in range(8):
            rr = 0.36 if k % 2 == 0 else 0.13
            a = k * math.pi / 4 + math.pi / 8
            pts.append(R(rr * math.cos(a), HEAD_Y + rr * math.sin(a), z0 + sz * 0.055))
            top.append(R(rr * 0.6 * math.cos(a), HEAD_Y + rr * 0.6 * math.sin(a), z0 + sz * 0.09))
        if sz < 0:
            pts, top = pts[::-1], top[::-1]
        O.finish(O.mesh_obj("FaceStar", [pts, top], True, R(0, HEAD_Y, z0 + sz * 0.04), R(0, HEAD_Y, z0 + sz * 0.1)), HOST, "BluedSteel", 0)
    # 국자 별 넷(양 옆면) + 이은 빛줄
    bowl = [("Megrez", 2.24, 0.68), ("Phecda", 2.2, -0.8), ("Merak", 2.98, -0.95), ("Dubhe", 3.0, 0.74)]
    for sx in (1, -1):
        side = sx * (HW + 0.005)
        for name, y, z in bowl:
            gem(name, R(side, y, z), 0.085, normal=(-sx, 0, 0))
        for k in range(4):
            (_, y0, z0), (_, y1, z1) = bowl[k], bowl[(k + 1) % 4]
            pts = [R(side + sx * 0.012, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t) for t in O.lin(0.16, 0.84, 6)]
            O.add_tube("Line", HOST, "Lines", pts, 0.022, 6, 0)


def render(objs):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 900, 700
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.36, 0.44, 1)
    for nm, loc, e in (("Key", (-4, -6, 6), 600), ("Rim", (5, 5, 4), 400)):
        ld = bpy.data.lights.new(nm, "AREA")
        ld.energy, ld.size = e, 4
        lo = bpy.data.objects.new(nm, ld)
        lo.location = loc
        lo.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        O.scol().objects.link(lo)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    O.scol().objects.link(cam)
    scene.camera = cam
    mid = Vector((0, 0, 1.3))
    for tag, d in (("side", (1.0, -0.15, 0.12)), ("q34", (0.75, -0.7, 0.35))):
        d = Vector(d).normalized()
        cam.location = mid + d * 9
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(HERE, "weapons", "render", "CallistoHammer_%s.png" % tag)
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    O.make_textures()
    O.make_materials()
    m = bpy.data.materials.new("Lines")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.3, 0.55, 1.0, 1)
    O.MATERIALS["Lines"] = m
    O.MATS["Lines"] = (None, 1.0)
    build()
    objs = []
    for (host, mat), parts in sorted(O.PIECES.items()):
        ob = O.dress(O.join(parts, "%s_%s" % (host, mat)), mat, 35)
        print("  %-30s %6d tri" % (ob.name, O.tris(ob)))
        objs.append(ob)
    if RENDER:
        render(objs)
    O.export_glb(objs + [O.marker("WeaponsOrigin_Marker")], os.path.join(HERE, "CallistoHammer.glb"))


main()
