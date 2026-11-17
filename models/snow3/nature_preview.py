# -*- coding: utf-8 -*-
"""
nature_preview.py — 2026-11-17. 설원 3판 자연 키트(n_*.py) 점검표 + 시트 렌더. 아트 부서.
돌리기: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P models/snow3/nature_preview.py [-- check] [-- Sn3_Spruce_L ...]
  check = 표만(렌더 없음). 이름을 주면 그 조각만.
점검표(render/nature_report.txt): 조각마다 땅 위 실측 크기(로블록스 X 폭 × Z 깊이 × Y 높이)·목표 ±10%·삼각형(한도)·충돌 상자 수·재질·
  반짝임(zfight_scan: 고친 면 / 남은 쌍 — 둘 다 0 이어야)·1인칭 짙은 잎 비율(눈높이 4.5, 거리 20·40, 잎 면 = 바늘잎 + 나무 위 눈 중 바늘잎 몫)
시트(render/): nature_fp_trees.png · nature_fp_ground.png(1인칭 눈높이 4.5, 세로 시야 70°, 16:9) · nature_34.png(3/4 위) ·
  nature_compare.png(지금 맵 나무 = 숲 키트 Pine_A 잎 눈색 vs Sn3_Spruce_L·M) · nature_tones.png(바늘잎 두 톤 세 쌍: 짙게/중간/조금 밝게) ·
  nature_idmask.png(1인칭 나무 쪽 가름: 빨강 바늘잎 · 파랑 나무 위 눈 · 초록 줄기 등) → nature_sheet.png(여섯 장 한 판)
"""
import glob
import importlib
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib as K  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "render")
os.makedirs(OUT, exist_ok=True)
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CHECK = "check" in ARGS
NAMES = [a for a in ARGS if a.startswith("Sn3_")]

# 목표 크기(지시서 2절: 폭 X × 깊이 Z × 높이 Y, None = 정하지 않음)와 삼각형 한도
TARGET = {
    "Sn3_Spruce_L": ((18, 18, 46), 1200), "Sn3_Spruce_M": ((13, 13, 30), 900), "Sn3_Spruce_S": ((8, 8, 16), 900),
    "Sn3_Spruce_Bent": ((12, 12, 26), 900), "Sn3_Birch": ((12, None, 26), 900), "Sn3_DeadPine": ((6, 6, 20), 900),
    "Sn3_Stump": ((2.6, 2.6, 1.6), 600), "Sn3_Log": ((16, 2, 2), 600), "Sn3_Bush": ((6, 5, 3), 600),
    "Sn3_Boulder_S": ((5, 4, 3.5), 600), "Sn3_Boulder_M": ((10, 8, 6), 600), "Sn3_Boulder_L": ((18, 14, 10), 600),
    "Sn3_Drift_A": ((14, 8, 1.0), 600), "Sn3_Drift_B": ((22, 10, 2.2), 600), "Sn3_SnowFence": ((12, None, 3.5), 600),
    "Sn3_Woodpile": ((6, 3, 4), 600),
}
# 시트 자리(손 배치, 블렌더 x, y, 돌림 도). 나무 줄은 y 35~41(1인칭 카메라가 +y 를 본다), 땅 조각은 y < 0(카메라가 -y 를 본다)
LAYOUT = {
    "Sn3_Spruce_L": (-30, 40, 0), "Sn3_Spruce_M": (-12, 36, 0), "Sn3_Spruce_Bent": (2, 41, 0), "Sn3_Spruce_S": (13, 34, 0),
    "Sn3_Birch": (25, 39, 0), "Sn3_DeadPine": (37, 36, 0),
    "Sn3_Woodpile": (-24, -12, 20), "Sn3_Stump": (-14, -9, 0), "Sn3_Bush": (-7, -12, 0), "Sn3_Boulder_S": (1, -10, 0),
    "Sn3_Log": (12, -12, 15), "Sn3_Boulder_M": (-15, -26, 0), "Sn3_Boulder_L": (5, -32, 0), "Sn3_SnowFence": (24, -22, -10),
    "Sn3_Drift_B": (-34, -32, 0), "Sn3_Drift_A": (24, -38, 0),
}
TREES = ("Sn3_Spruce_L", "Sn3_Spruce_M", "Sn3_Spruce_S", "Sn3_Spruce_Bent", "Sn3_Birch", "Sn3_DeadPine")
SPRUCES = TREES[:4]          # 잎 비율은 바늘잎 나무만
NEEDLE = ("_Needle", "_NeedleLit")
SKY = (0.21, 0.35, 0.52)
TONES = [("짙게", "#1E2D28", "#2C3E34"), ("중간", "#283A32", "#384E40"), ("조금 밝게", "#32463A", "#46604C")]


def mods():
    out = []
    for p in sorted(glob.glob(os.path.join(HERE, "n_*.py"))):
        m = importlib.import_module(os.path.splitext(os.path.basename(p))[0])
        if not NAMES or m.NAME in NAMES:
            out.append(m)
    return out


def measure(objs):
    """땅 위(z > 0.02) 크기: 땅 위 꼭짓점 + 땅을 뚫고 나오는 모서리의 0.02 높이 점(비탈이 땅에 묻힌 눈더미)"""
    pts, up = [], []
    for ob in objs:
        w = [ob.matrix_world @ v.co for v in ob.data.vertices]
        pts += w
        up += [p for p in w if p.z > 0.02]
        for e in ob.data.edges:
            a, b = w[e.vertices[0]], w[e.vertices[1]]
            if (a.z - 0.02) * (b.z - 0.02) < 0:
                up.append(a.lerp(b, (0.02 - a.z) / (b.z - a.z)))
    return (max(p.x for p in up) - min(p.x for p in up), max(p.y for p in up) - min(p.y for p in up), max(p.z for p in pts))


def ok10(v, t):
    return t is None or abs(v - t) <= 0.1 * t + 1e-6


def old_pine():
    """지금 맵 나무: models/forest/build_kit_forest.py 의 Pine_A 표(로블록스 좌표 상자)를 잎만 Snow_Town3.luau 의 눈색(LeafA 232,240,248 / LeafB 196,212,228)으로"""
    src = open(os.path.join(K.MODELS, "forest", "build_kit_forest.py"), encoding="utf-8").read()
    ns = {}
    exec(compile(src[src.index("SHAPES = {"):src.index("def build(")], "forest_shapes", "exec"), ns)
    pal = {"OldWood": "#4A3728", "OldLeafA": "#E8F0F8", "OldLeafB": "#C4D4E4"}
    gs = {k: K.L.Group("Old_" + k, K.L.material(k, pal)) for k in pal}
    for grp, c, s, r in ns["SHAPES"]["Pine_A"]:
        gs["Old" + grp].obox(c[0], c[2], c[1], s[0], s[2], s[1], rz=math.radians(r[1]))
    return [g.finish() for g in gs.values()]


def scene_setup():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.exposure = 0.75                # 작업대 빛은 흰 눈을 회색으로 낮춘다 — 노출로 올리고 하늘색은 그만큼 낮춘다
    sh = sc.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.studio_light = "outdoor.sl"                 # 맑은 낮 바깥 빛(기본 작업대 빛은 1인칭에서 눈 바닥을 회색으로 만든다)
    sh.use_world_space_lighting = True
    sh.show_cavity = True
    sh.show_shadows = True
    sh.shadow_intensity = 0.45
    sh.background_type = "VIEWPORT"
    sh.background_color = SKY                       # 맑은 낮 하늘(노출 뒤 0.36, 0.58, 0.88)
    sc.display.light_direction = (-0.35, -0.55, 0.76)
    sc.render.resolution_x, sc.render.resolution_y = 1280, 720
    bpy.ops.mesh.primitive_plane_add(size=1600, location=(150, 0, -0.03))
    gr = bpy.context.active_object
    gr.name = "Ground"
    gr.data.materials.append(K.L.material("SnowCap", K.PAL))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.sensor_fit = "VERTICAL"
    cam.data.clip_start, cam.data.clip_end = 0.1, 3000
    return sc, cam, gr


def shoot(sc, cam, path, loc, look, fov=70.0, res=(1280, 720)):
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.angle_y = math.radians(fov)
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def pixels(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)


def save_png(a, path):
    h, w = a.shape[:2]
    img = bpy.data.images.new("sheet", w, h, alpha=False)
    img.pixels.foreach_set(np.ascontiguousarray(a, np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def id_mode(sc, on, groups=None):
    """on: 평면 빛·물체 색으로 가름(빨강 바늘잎, 파랑 나무 위 눈, 초록 그 밖 나무 몸, 검정 땅·하늘)"""
    sh = sc.display.shading
    if on:
        sh.light, sh.color_type = "FLAT", "OBJECT"
        sc.view_settings.exposure = 0.0
        sh.show_cavity = sh.show_shadows = False
        sh.background_color = (0, 0, 0)
        for ob in bpy.data.objects:
            if ob.type != "MESH":
                continue
            n = ob.name
            if n.endswith(NEEDLE):
                ob.color = (1, 0, 0, 1)
            elif n.endswith("_SnowCap") and any(n.startswith(K_) for K_ in groups):
                ob.color = (0, 0, 1, 1)
            elif n.endswith(("_OldLeafA", "_OldLeafB")):
                ob.color = (0, 0, 1, 1)
            elif n == "Ground":
                ob.color = (0, 0, 0, 1)
            else:
                ob.color = (0, 1, 0, 1)
    else:
        sh.light, sh.color_type = "STUDIO", "MATERIAL"
        sc.view_settings.exposure = 0.75
        sh.show_cavity = sh.show_shadows = True
        sh.background_color = SKY


def leaf_share(a):
    r, g_, b = a[..., 0], a[..., 1], a[..., 2]
    nd = int(((r > 0.5) & (g_ < 0.35) & (b < 0.35)).sum())
    sn = int(((b > 0.5) & (r < 0.35) & (g_ < 0.35)).sum())
    return nd, sn


def main():
    K.L.clear_scene()
    sc, cam, gr = scene_setup()
    rows, built = [], {}
    for m in mods():
        objs, tris, (zm, zl) = K.build_model(m, zfix=True)
        X, Z, H = measure(objs)
        (tx, tz, th), lim = TARGET[m.NAME]
        ncoll = len(K.I.COLL[m.NAME])
        tt = sum(tris.values())
        flag = "" if (ok10(X, tx) and ok10(Z, tz) and ok10(H, th) and tt <= lim and zm == 0 and zl == 0) else "  <<"
        rows.append("%-16s 크기 %5.1f × %5.1f × %5.1f (목표 %s × %s × %s)  삼각형 %4d/%d  충돌 %d  반짝임 고친 면 %d 남음 %d  재질 %s%s" % (
            m.NAME, X, Z, H, tx, tz, th, tt, lim, ncoll, zm, zl, ",".join(sorted(tris)), flag))
        built[m.NAME] = (m, objs)
        x, y, yaw = LAYOUT[m.NAME]
        for ob in objs:
            ob.location = (x, y, 0)
            ob.rotation_euler.z = math.radians(yaw)
        print(rows[-1])
    if CHECK:
        print("\n".join(rows))
        return
    bpy.context.view_layer.update()
    for ob in bpy.data.objects:                 # 표지·김은 렌더에서 숨김
        if ob.name.endswith(("_Vent", "_LampPt", "WinGlass")):
            ob.hide_render = True
    paths = {}
    # (a) 1인칭 — 나무 쪽 · 땅 조각 쪽
    paths["fp_trees"] = shoot(sc, cam, os.path.join(OUT, "nature_fp_trees.png"), (3, 4, 4.5), (3, 40, 12.5))
    paths["fp_ground"] = shoot(sc, cam, os.path.join(OUT, "nature_fp_ground.png"), (-2, 12, 4.5), (-2, -22, 1.5))
    # (b) 3/4 위
    paths["34"] = shoot(sc, cam, os.path.join(OUT, "nature_34.png"), (-56, -78, 46), (3, 2, 3), fov=48)
    # (c) 지금 나무와 비교: 옛 Pine_A(눈색 잎) · Sn3_Spruce_L · Sn3_Spruce_M 을 x 200 줄에
    comp = []
    old = old_pine()
    for ob in old:
        ob.location = (188, 30, -0.3)
    comp.append(("Pine_A(지금)", old))
    for nm, x in (("Sn3_Spruce_L", 207), ("Sn3_Spruce_M", 224)):
        if nm in built:
            cp = []
            for ob in built[nm][1]:
                c = ob.copy()
                sc.collection.objects.link(c)
                c.location = (x, 31, 0)
                c.rotation_euler.z = 0
                cp.append(c)
            comp.append((nm, cp))
    paths["compare"] = shoot(sc, cam, os.path.join(OUT, "nature_compare.png"), (205, -9, 4.5), (205, 31, 15))
    # 바늘잎 두 톤 세 쌍(짙게 / 중간 = 지시서 예 / 조금 밝게) — Sn3_Spruce_M 복사본 셋
    if "Sn3_Spruce_M" in built:
        for i, (lab, dk, lt) in enumerate(TONES):
            pal = {"Needle_t%d" % i: dk, "NeedleLit_t%d" % i: lt}
            for ob in built["Sn3_Spruce_M"][1]:
                c = ob.copy()
                c.data = ob.data.copy()
                sc.collection.objects.link(c)
                c.location = (388 + 15 * i, 25, 0)
                c.rotation_euler.z = math.radians(40 * i)
                for tag, key in (("_Needle", "Needle_t%d" % i), ("_NeedleLit", "NeedleLit_t%d" % i)):
                    if ob.name.endswith(tag):
                        c.data.materials[0] = K.L.material(key, pal)
                        c.name = ob.name + "_t%d" % i
        paths["tones"] = shoot(sc, cam, os.path.join(OUT, "nature_tones.png"), (403, -6, 4.5), (403, 25, 11))
    # 짙은 잎 비율: 나무마다 따로(다른 것 숨김), 눈높이 4.5, 거리 20·40, 나무 높이 45% 를 본다
    tree_pref = tuple(built[n][0].PREFIX + "_" for n in TREES if n in built)
    id_mode(sc, True, tree_pref)
    paths["idmask"] = shoot(sc, cam, os.path.join(OUT, "nature_idmask.png"), (3, 4, 4.5), (3, 40, 12.5))
    share = []
    allm = [o for o in bpy.data.objects if o.type == "MESH" and o.name != "Ground"]
    vis0 = {o.name: o.hide_render for o in allm}
    tmp = os.path.join(OUT, "_id_tmp.png")
    for lab, objs in [(n, built[n][1]) for n in SPRUCES if n in built] + comp[:1]:
        for o in allm:
            o.hide_render = o not in objs
        px = objs[0].location
        H = max((o.matrix_world @ Vector(c)).z for o in objs for c in o.bound_box)
        cells = []
        for d in (20, 40):
            nd, sn = leaf_share(pixels(shoot(sc, cam, tmp, (px.x, px.y - d, 4.5), (px.x, px.y, H * 0.45), res=(640, 360))))
            cells.append("거리 %d: 바늘잎 %d%% · 눈 %d%%" % (d, round(100 * nd / max(1, nd + sn)), round(100 * sn / max(1, nd + sn))))
        share.append("%-16s %s" % (lab, "   ".join(cells)))
    for o in allm:
        o.hide_render = vis0[o.name]
    os.remove(tmp)
    id_mode(sc, False)
    # 시트: 2 × 3
    order = ["fp_trees", "fp_ground", "34", "compare", "tones", "idmask"]
    tiles = [pixels(paths[k]) if k in paths else np.zeros((720, 1280, 4), np.float32) for k in order]
    gap = 8
    W, Hh = 1280 * 2 + gap, 720 * 3 + gap * 2
    sheet = np.ones((Hh, W, 4), np.float32) * np.array([0.1, 0.1, 0.12, 1.0], np.float32)
    for i, t in enumerate(tiles):
        r, c = divmod(i, 2)
        y0 = Hh - (r + 1) * 720 - r * gap          # 블렌더 픽셀은 아래 줄부터
        x0 = c * (1280 + gap)
        sheet[y0:y0 + 720, x0:x0 + 1280] = t[:720, :1280]
    save_png(sheet, os.path.join(OUT, "nature_sheet.png"))
    rep = ["# nature_preview.py %s" % ("(일부: %s)" % ",".join(NAMES) if NAMES else "")] + rows + ["", "# 1인칭 잎 면 가름(나무마다 따로, 눈높이 4.5)"] + share
    rep += ["", "# 시트 칸: 1 나무 1인칭 · 2 땅 조각 1인칭 / 3 3/4 위 · 4 지금 나무 비교(왼쪽 Pine_A 눈색, Spruce_L, Spruce_M) / "
            "5 바늘잎 톤 세 쌍(왼쪽부터 %s) · 6 1인칭 가름(빨강 바늘잎·파랑 나무 눈·초록 줄기 등)" % " / ".join("%s %s·%s" % t for t in TONES)]
    with open(os.path.join(OUT, "nature_report.txt"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(rep) + "\n")
    print("\n".join(rep))


main()
