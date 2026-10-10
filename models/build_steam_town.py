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

PAL = dict(S.PALETTE)
PAL.update({"SignBlue": "#3A5FA8", "SignGold": "#C9A23A", "SignTeal": "#3E9C93", "SignRed": "#A83A3A", "SignPurple": "#6B4AA0",
            "Dial": "#F2E8C8"})


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


def casino(g):
    W, D = 40.0, 30.0
    g["Stone"].box(0, 0, 1.0, W + 2, D + 2, 2.0)
    g["Brick"].box(0, 0, 2 + 9, W, D, 18)
    g["StoneTrim"].box(0, 0, 20.4, W + 1.4, D + 1.4, 0.8)
    fy = -D / 2
    # 기둥 여섯 + 위 띠
    for k in range(6):
        x = -W / 2 + 4 + k * (W - 8) / 5
        g["StoneTrim"].cyl(x, fy - 2.2, 2.0, 1.1, 1.0, 16.0, seg=12)
    g["StoneTrim"].box(0, fy - 2.2, 18.6, W - 2, 3.4, 1.0)
    g["Stone"].box(0, fy - 2.2, 2.4, W - 2, 4.4, 0.8)
    # 큰 아치 불빛창(문 위)
    g["Brass"].hcyl(0, fy - 0.2, 13.0, 5.4, 0.4, axis="y", seg=24)
    g["Glow"].hcyl(0, fy - 0.35, 13.0, 4.8, 0.3, axis="y", seg=24)
    S.door(g, 0, fy, 2.0, 6.0, 8.0, canopy=False)
    for x in (-13, -7, 7, 13):
        S.window(g, x, fy, 5.0, 3.0, 5.0)
        S.window(g, x, fy, 13.0, 3.0, 4.0)
    # 간판: 놋쇠 틀 + 붉은 판 + 톱니
    g["Brass"].box(0, fy - 0.6, 23.5, 18.0, 0.5, 4.6)
    g["SignRed"].box(0, fy - 0.9, 23.5, 16.6, 0.3, 3.4)
    S.gear(g, "Brass", -10.4, fy - 0.9, 23.5, 2.2, 12, 0.4)
    S.gear(g, "Brass", 10.4, fy - 0.9, 23.5, 2.2, 12, 0.4)
    # 원통 지붕(앞뒤로 누움) + 눈
    R = D / 2 + 0.8
    S.arc_shell(g, "RoofMetal", -W / 2 - 0.6, W / 2 + 0.6, 0, 20.8, R - 0.6, R, n=22)
    S.arc_shell(g, "SnowCap", -W / 2 - 0.3, W / 2 + 0.3, 0, 20.8, R, R + 0.6, a0=math.radians(40), a1=math.radians(140), n=12)
    for s in (-1, 1):
        S.half_disc(g, "BrickDark", s * W / 2, 0, 20.8, R - 0.6, 0.6)
    # 옆 경매동(+x)
    ox = W / 2 + 10
    g["Stone"].box(ox, 4, 1.0, 19, 23, 2.0)
    g["BrickDark"].box(ox, 4, 2 + 7, 18, 22, 14)
    S.roof_gable(g, ox, 4, 16.0, 18.6, 22.6, 7.0, along="y")
    S.door(g, ox, 4 - 11, 2.0, 4.6, 7.4)
    g["Brass"].box(ox, 4 - 11.6, 12.5, 12.0, 0.4, 3.0)
    g["SignGold"].box(ox, 4 - 11.85, 12.5, 11.0, 0.25, 2.2)
    for yy in (-2.0, 6.0, 12.0):
        S.window(g, ox + 9, yy, 5.0, 2.6, 4.0, face="+x")
    S.banded_cyl(g, "Copper", -W / 2 + 4, D / 2 - 4, 21.0, 1.4, 14.0, every=4.0)
    S.vent(g, -W / 2 + 4, D / 2 - 4, 36.0)
    for x in (-8.0, 8.0):
        g["LampPt"].box(x, fy - 4.6, 14.0, 0.6, 0.6, 0.6)


def factory(g):
    W, D = 36.0, 52.0
    g["Stone"].box(0, 0, 1.0, W + 2, D + 2, 2.0)
    g["Brick"].box(0, 0, 2 + 10, W, D, 20)
    g["StoneTrim"].box(0, 0, 22.4, W + 1.2, D + 1.2, 0.8)
    S.roof_gable(g, 0, 0, 22.8, W + 1.0, D + 1.0, 10.0, along="y")
    # 벽기둥
    for k in range(7):
        y = -D / 2 + 4 + k * (D - 8) / 6
        for s in (-1, 1):
            g["BrickDark"].box(s * (W / 2 + 0.4), y, 12, 0.8, 1.8, 20)
            S.window(g, s * W / 2, y + 3.2, 8.0, 2.6, 7.0, face="+x" if s > 0 else "-x")
    fy = -D / 2
    GW, GH = 12.0, 14.0
    g["Timber"].box(0, fy - 0.15, 2 + GH / 2, GW, 0.4, GH)
    for k in range(4):
        g["Iron"].box(0, fy - 0.4, 2 + GH * (k + 0.5) / 4, GW, 0.2, 0.45)
    g["StoneTrim"].box(0, fy - 0.3, 2 + GH + 0.6, GW + 2.4, 0.8, 1.2)
    g["Iron"].box(0, fy - 0.4, 20.0, 16.0, 0.5, 2.0)
    g["Brass"].box(0, fy - 0.7, 20.0, 14.6, 0.2, 1.2)
    # 굴뚝 넷(뒤쪽, 높이 다르게)
    for x, y, h in ((-10, 10, 62.0), (10, 10, 56.0), (-10, 22, 50.0), (10, 22, 66.0)):
        g["Brick"].box(x, y, 2 + h / 2, 5.0, 5.0, h)
        for z in (24.0, 40.0, h - 1.0):
            g["StoneTrim"].box(x, y, 2 + z, 5.6, 5.6, 0.8)
        g["Iron"].box(x, y, 2 + h + 0.5, 5.8, 5.8, 1.0)
        S.vent(g, x, y, 2 + h + 1.4)
    # 옆 보일러 통 둘 + 관
    for y in (-12.0, 4.0):
        S.banded_cyl(g, "Copper", -W / 2 - 5, y, 2.0, 3.2, 16.0, every=4.0)
        S.pipe(g, [(-W / 2 - 5, y, 18.8), (-W / 2 - 5, y, 21.0), (-W / 2, y, 21.0)], 0.7)
        S.vent(g, -W / 2 - 5, y, 19.4)
    S.gear(g, "Brass", W / 4, fy - 0.6, 14.0, 3.0, 16, 0.5)


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


def inn(g):
    W, D = 24.0, 16.0
    g["Stone"].box(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    g["Brick"].box(0, 0, 1.5 + 13.5, W, D, 27.0)
    for z in (10.0, 19.0, 28.0):
        g["StoneTrim"].box(0, 0, z, W + 0.8, D + 0.8, 0.6)
    S.roof_gable(g, 0, 0, 28.3, W + 0.8, D + 0.8, 9.0, along="x")
    fy = -D / 2
    S.door(g, 0, fy, 1.5, 4.4, 7.6)
    for z in (3.0, 12.0, 21.0):
        for x in (-8.0, -3.5, 3.5, 8.0):
            if z == 3.0 and abs(x) < 4:
                continue
            S.window(g, x, fy, z, 2.4, 4.2)
    # 이층 발코니
    g["Timber"].box(0, fy - 1.6, 10.4, 14.0, 3.2, 0.5)
    for x in range(-7, 8, 2):
        g["Iron"].box(x, fy - 3.0, 12.0, 0.25, 0.25, 3.0)
    g["Iron"].box(0, fy - 3.0, 13.5, 14.2, 0.3, 0.3)
    # 간판
    g["Brass"].box(0, fy - 0.5, 18.0, 10.0, 0.4, 2.6)
    g["SignPurple"].box(0, fy - 0.75, 18.0, 9.2, 0.25, 1.9)
    for x in (-8.0, 8.0):
        S.banded_cyl(g, "Iron", x, 3.0, 28.0, 0.9, 10.0, band="Brass", every=3.0)
        S.vent(g, x, 3.0, 39.0)
    g["LampPt"].box(0, fy - 2.0, 9.0, 0.6, 0.6, 0.6)


def ticket_booth(g):
    W, D = 9.0, 7.0
    g["Stone"].box(0, 0, 0.5, W + 1.0, D + 1.0, 1.0)
    g["Timber"].box(0, 0, 1 + 4.5, W, D, 9.0)
    g["IronLight"].box(0, 0, 10.4, W + 1.6, D + 1.6, 0.6)
    S.pyramid(g, "RoofMetal", 0, 0, 10.7, W + 1.6, D + 1.6, 3.4)
    S.pyramid(g, "SnowCap", 0, 0, 10.7, W + 1.6, D + 1.6, 3.4, frac=0.6, lift=0.2)
    fy = -D / 2
    S.window(g, 0, fy, 4.6, 5.4, 3.2, cross=False)
    g["StoneTrim"].box(0, fy - 0.8, 4.4, 6.4, 1.6, 0.4)
    g["Brass"].box(0, fy - 0.4, 9.0, 7.0, 0.4, 1.6)
    g["SignRed"].box(0, fy - 0.6, 9.0, 6.4, 0.25, 1.1)
    S.door(g, W / 2, 1.0, 1.0, 2.6, 6.2, face="+x", canopy=False)
    g["LampPt"].box(0, fy - 1.6, 8.0, 0.5, 0.5, 0.5)


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
    ("Casino_Hall", "Casino", casino),
    ("Steam_Factory", "Fact", factory),
    ("Shop_Blue", "ShopB", shop("SignBlue")),
    ("Shop_Gold", "ShopG", shop("SignGold")),
    ("Shop_Teal", "ShopT", shop("SignTeal")),
    ("Shop_Red", "ShopR", shop("SignRed")),
    ("Inn_House", "Inn", inn),
    ("Ticket_Booth", "Ticket", ticket_booth),
    ("Under_Gate", "UGate", under_gate),
] + O.JOBS

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
