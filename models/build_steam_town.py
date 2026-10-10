# -*- coding: utf-8 -*-
"""
build_steam_town.py — 2026-10-09. 설원 마을(슈네라이히) 새 건물. build_steam.py(옛 스팀펑크 키트)와 같은 부품·재질로.

사용자 마을 확대 그림(설원 지도.jpg)의 건물 중 옛 키트에 없는 것:
  Clock_Tower   광장 시계탑. 벽돌 몸 + 네 면 시계 + 구리 뾰족지붕
  Observatory   천문대(조율자 전직) → 2판은 build_steam_obs.py(들어가는 건물·도는 돔·망원경) + 놀이터 소품
  Casino_Hall   카지노+경매장. 기둥 앞면, 큰 아치 불빛창, 원통 지붕 + 옆 경매동(맞배)
  Steam_Factory 공장. 긴 벽돌동, 굴뚝 넷, 보일러 통·관
  Shop_Blue/Gold/Teal/Red  상점(잡화·장비·물약·강화소): 진열창·차양·걸린 간판(색으로 가름)
  Inn_House     여관. 삼층, 발코니, 보라 간판
  Ticket_Booth  티켓 판매점. 작은 매표소
  Under_Gate    지하 입구. 돌 아치 문 + 쇠창살
원점 = 바닥 가운데, 앞 = -y(블렌더). 한 FBX(SnowTownKit.fbx)로 묶고 원점 표지 SnowTownOrigin_Marker. Studio: tools/Snow_TownKit.luau
돌리기: blender -b -P models/build_steam_town.py [-- render]
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import build_steam as S  # noqa: E402
import build_steam_obs as O  # noqa: E402  (천문대 2판·놀이터 — 2026-10-09)
import build_steam_inside as I  # noqa: E402  (들어가는 건물 — 2026-10-10)

PAL = dict(S.PALETTE)
PAL.update({"SignBlue": "#3A5FA8", "SignGold": "#C9A23A", "SignTeal": "#3E9C93", "SignRed": "#A83A3A", "SignPurple": "#6B4AA0",
            "Dial": "#F2E8C8", "Marble": "#E1E1E4", "DarkStone": "#28282C",
            "Felt": "#2E6B45", "GlowTeal": "#4FE0C8"})


def G(prefix):
    return L.new_groups(prefix, PAL)


def clock_tower(g):
    g["Stone"].box(0, 0, 2.0, 17, 17, 4.0)
    g["Brick"].box(0, 0, 4 + 20, 12, 12, 40)
    for z in (14.0, 28.0, 44.0):
        g["StoneTrim"].box(0, 0, z, 13.2, 13.2, 0.8)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["BrickDark"].box(sx * 5.8, sy * 5.8, 24, 1.8, 1.8, 40)
    S.door(g, 0, -6, 4, 3.6, 7.0)
    for z in (18.0, 32.0):
        for face, (cx, cy) in (("-y", (0, -6)), ("+y", (0, 6)), ("-x", (-6, 0)), ("+x", (6, 0))):
            S.window(g, cx, cy, z, 2.0, 4.0, face=face, cross=False)
    # 시계 단
    g["BrickDark"].box(0, 0, 50.5, 13.4, 13.4, 13.0)
    g["StoneTrim"].box(0, 0, 57.2, 14.4, 14.4, 0.8)
    for axis, sgn in (("y", -1), ("y", 1), ("x", -1), ("x", 1)):
        if axis == "y":
            g["Brass"].hcyl(0, sgn * 6.85, 50.5, 4.8, 0.6, axis="y", seg=24)
            g["Dial"].hcyl(0, sgn * 7.1, 50.5, 4.1, 0.4, axis="y", seg=24)
            g["Iron"].obox(0.9, sgn * 7.4, 51.5, 0.35, 0.2, 3.4, ry=0.5)
            g["Iron"].obox(-1.1, sgn * 7.4, 50.0, 0.3, 0.2, 2.4, ry=-1.1)
        else:
            g["Brass"].hcyl(sgn * 6.85, 0, 50.5, 4.8, 0.6, axis="x", seg=24)
            g["Dial"].hcyl(sgn * 7.1, 0, 50.5, 4.1, 0.4, axis="x", seg=24)
            g["Iron"].obox(sgn * 7.4, 0.9, 51.5, 0.2, 0.35, 3.4, rx=0.5)
            g["Iron"].obox(sgn * 7.4, -1.1, 50.0, 0.2, 0.3, 2.4, rx=-1.1)
    S.pyramid(g, "RoofMetal", 0, 0, 57.6, 15.0, 15.0, 13.0)
    S.pyramid(g, "SnowCap", 0, 0, 57.6, 15.0, 15.0, 13.0, frac=0.55, lift=0.35)
    g["Brass"].cyl(0, 0, 70.4, 0.5, 0.15, 7.0, seg=10)
    S.gear(g, "Brass", 0, -6.2, 24.0, 2.6, 14, 0.4)
    S.gear(g, "Copper", 3.6, -6.25, 26.6, 1.4, 10, 0.4)
    g["LampPt"].box(0, -9.0, 50.5, 0.6, 0.6, 0.6)


def shop(sign):
    def fn(g):
        W, D = 16.0, 12.0
        g["Stone"].box(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
        g["Brick"].box(0, 0, 1.5 + 4.5, W, D, 9.0)
        g["StoneTrim"].box(0, 0, 10.9, W + 0.8, D + 0.8, 0.8)
        g["BrickDark"].box(0, 0, 11.3 + 3.75, W + 0.4, D + 0.4, 7.5)
        S.roof_gable(g, 0, 0, 18.8, W + 0.6, D + 0.6, 7.0, along="x")
        fy = -D / 2
        # 진열창(넓게) + 문
        S.window(g, 2.8, fy, 2.6, 8.0, 5.0, cross=True)
        S.door(g, -5.0, fy, 1.5, 3.2, 6.6, canopy=False)
        # 차양(간판 색)
        g[sign].obox(0, fy - 1.6, 8.6, W - 1.0, 3.4, 0.3, rx=-0.32)
        for x in range(-6, 7, 3):
            g["StoneTrim"].obox(x, fy - 2.9, 7.9, 0.3, 0.6, 0.6, rx=-0.32)
        # 걸린 간판(쇠 팔 + 판)
        g["Iron"].box(W / 2 - 1.5, fy - 2.2, 14.2, 0.3, 4.4, 0.3)
        g["Brass"].box(W / 2 - 1.5, fy - 3.8, 12.6, 0.4, 3.2, 2.8)
        g[sign].box(W / 2 - 1.5, fy - 3.8, 12.6, 0.5, 2.6, 2.2)
        for x in (-4.0, 4.0):
            S.window(g, x, fy, 13.0, 2.4, 3.4)
        S.banded_cyl(g, "Copper", -W / 2 - 1.4, 2.0, 1.5, 1.1, 24.0, every=5.0)
        S.vent(g, -W / 2 - 1.4, 2.0, 26.0)
        g["LampPt"].box(0, fy - 2.4, 10.4, 0.5, 0.5, 0.5)
    return fn


def under_gate(g):
    W, D, H = 14.0, 10.0, 11.0
    g["Stone"].box(0, 0, H / 2, W, D, H)
    g["StoneTrim"].box(0, 0, H + 0.4, W + 1.0, D + 1.0, 0.8)
    S.pyramid(g, "SnowCap", 0, 0, H + 0.8, W + 1.0, D + 1.0, 1.4)
    fy = -D / 2
    # 아치 입구(어두운 안) + 쇠창살
    g["Soot"].box(0, fy - 0.1, 3.6, 6.0, 0.3, 7.2)
    g["Soot"].hcyl(0, fy - 0.1, 7.2, 3.0, 0.3, axis="y", seg=16)
    for x in (-2.2, -1.1, 0.0, 1.1, 2.2):
        g["Iron"].box(x, fy - 0.4, 4.6, 0.25, 0.25, 9.2)
    g["Iron"].box(0, fy - 0.4, 3.0, 6.2, 0.25, 0.3)
    g["Iron"].box(0, fy - 0.4, 6.4, 6.2, 0.25, 0.3)
    g["StoneTrim"].hcyl(0, fy - 0.35, 7.2, 3.8, 0.5, axis="y", seg=16)
    S.gear(g, "Brass", 0, fy - 0.6, 10.2, 1.3, 10, 0.3)
    for s in (-1, 1):
        g["Iron"].cyl(s * 5.2, fy - 1.5, 0, 0.3, 0.3, 7.0, seg=8)
        g["Glow"].box(s * 5.2, fy - 1.5, 7.6, 0.9, 0.9, 1.2)
    g["LampPt"].box(0, fy - 2.0, 9.0, 0.5, 0.5, 0.5)


JOBS = [
    ("Clock_Tower", "Clock", clock_tower),
    ("Shop_Gold", "ShopG", shop("SignGold")),
    ("Under_Gate", "UGate", under_gate),
] + O.JOBS + I.JOBS

if __name__ == "__main__":
    RENDER = "render" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    L.clear_scene()
    objs, pieces = [], []
    for name, prefix, fn in JOBS:
        g = G(prefix)
        fn(g)
        mine, total = [], 0
        for k in PAL:
            ob = g[k].finish()
            if len(ob.data.polygons) == 0:
                bpy.data.objects.remove(ob, do_unlink=True)
                continue
            tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
            assert tris <= 10000, (ob.name, tris)
            total += tris
            mine.append(ob)
        objs += mine
        pieces.append((name, mine))
        print("  %-14s %-7s %6d tri" % (name, prefix, total))
    m = L.Group("SnowTownOrigin_Marker", L.material("Stone", PAL))
    m.box(0, 0, 0, 0.8, 0.8, 0.8)
    marker = m.finish()
    if RENDER:
        sys.path.insert(0, os.path.join(HERE, "forest"))
        import importlib.util
        spec = importlib.util.spec_from_file_location("bkf", os.path.join(HERE, "forest", "build_kit_forest.py"))
        out = os.path.join(HERE, "snowtown_render")
        os.makedirs(out, exist_ok=True)
        # 간단한 미리보기(작업대 렌더)
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        sh = scene.display.shading
        sh.light, sh.color_type = "STUDIO", "MATERIAL"
        sh.show_cavity = True
        sh.background_type = "VIEWPORT"
        sh.background_color = (0.55, 0.68, 0.8)
        scene.render.resolution_x = scene.render.resolution_y = 520
        from mathutils import Vector
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        cam.data.type = "ORTHO"
        marker.hide_render = True
        for name, mine in pieces:
            for ob in bpy.data.objects:
                if ob.type == "MESH":
                    ob.hide_render = ob not in mine
            pts = [ob.matrix_world @ Vector(c) for ob in mine for c in ob.bound_box]
            lo = Vector((min(q.x for q in pts), min(q.y for q in pts), min(q.z for q in pts)))
            hi = Vector((max(q.x for q in pts), max(q.y for q in pts), max(q.z for q in pts)))
            mid, size = (lo + hi) / 2, (hi - lo).length
            cam.data.ortho_scale = size * 0.9
            d = Vector((0.55, -0.75, 0.38)).normalized()
            cam.location = mid + d * size * 2
            cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(out, name + ".png")
            bpy.ops.render.render(write_still=True)
        for ob in bpy.data.objects:
            if ob.type == "MESH":
                ob.hide_render = False
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs + [marker]:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = marker
    fbx = os.path.join(HERE, "SnowTownKit.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             axis_forward="-Z", axis_up="Y", object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
                             bake_space_transform=False)
    print("objects %d  FBX: %s" % (len(objs) + 1, fbx))
    I.emit_luau(os.path.join(HERE, "..", "tools", "Snow_Inside_data.luau"))
