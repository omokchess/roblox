# -*- coding: utf-8 -*-
"""
swamp_rooms.py — 늪지대 집 실내(받침벽 + 인테리어) 자료를 만들고 미리 찍는다. (2026-09-28)

요청: "늪지대의 인테리어 디테일 + 집에 난 빵꾸(통나무 간 간격이 너무 넓거나, 통나무가 얇아 집에 구멍이 아주 많음)"

원인: 참고 에셋 라이브러리(C:\\wth\\roblox\\blender\\swamplib)의
  - log_wall  : 통나무를 10각 기둥, 굵기 0.9~1.08배 무작위, 한쪽 끝 0.88배로 가늘게 만들면서
                간격은 평균 지름으로 벌려 → 통나무 사이 0.1~0.3 틈
  - plank_wall: 세로 판자 사이 0.05 띄우고 ±0.6° 기울여 → 쐐기 틈
  - plank_floor: 판자 사이 0.07, 오두막·마녀 집은 판자 4~5% 를 빼 둠
고치는 법: 집을 지은 **같은 라이브러리**로 에셋을 다시 짓되 벽 함수를 가로채 벽 자리·창문 구멍을 기록하고,
  벽 속에 틈 없는 받침판(통나무는 흙 메움, 판자는 짙은 판재)을 창·문 자리를 비워 세운다. 방 바닥 밑에도 받침판.
인테리어: 같은 라이브러리 소품 함수(통·상자·병·초·등불 …)로 손배치한다(swamp_interior_design.py).

결과: tools/swamp/interiors.json → tools/swamp/interiors.luau (Studio 스크립트 Swamp_Interiors.luau 가 읽음)
      tools/swamp/room_<에셋>_plan.png(위에서 본 단면·모눈), room_<에셋>_view.png(실내 시점)
돌리는 법: blender --background --python tools/swamp_rooms.py -- [build] [plan 에셋...] [view 에셋...]
  (build = 자료만, plan/view = 그림. 아무것도 안 주면 build + 전부 그림)
좌표: 에셋 좌표(블렌더, z 위) = 참고 파이썬 코드의 좌표. 로블록스 = (x, z, -y).
"""
import inspect
import json
import math
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REF = Path(r"C:\wth\roblox\blender")
sys.path.insert(0, str(REF))
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "models"))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from swamplib import shapes as S  # noqa: E402
from swamplib.asset import Asset, to_rbx_pos  # noqa: E402

# ── 벽 가로채기 ─────────────────────────────────────────────
WALLS = []


def _recorder(kind, orig):
    sig = inspect.signature(orig)

    def wrapped(a, *args, **kwargs):
        b = sig.bind(a, *args, **kwargs)
        b.apply_defaults()
        v = dict(b.arguments)
        v.pop("a")
        v["kind"] = kind
        v["M"] = a.M.copy()
        WALLS.append(v)
        return orig(a, *args, **kwargs)

    return wrapped


FLOORS = []


def _floor_recorder(orig):
    sig = inspect.signature(orig)

    def wrapped(a, *args, **kwargs):
        b = sig.bind(a, *args, **kwargs)
        b.apply_defaults()
        v = dict(b.arguments)
        v.pop("a")
        v["M"] = a.M.copy()
        FLOORS.append(v)
        return orig(a, *args, **kwargs)

    return wrapped


S.plank_wall = _recorder("plank", S.plank_wall)
S.log_wall = _recorder("log", S.log_wall)
S.plank_floor = _floor_recorder(S.plank_floor)

from assets.longhouse import longhouse  # noqa: E402
from assets.stilt_house import stilt_house_a, stilt_hut_c  # noqa: E402
from assets.witch_hut import witch_hut  # noqa: E402
import swamp_ref_assets as SRA  # noqa: E402

BUILDERS = {
    "Longhouse": longhouse,
    "StiltHouseA": stilt_house_a,
    "StiltHouseB2": SRA.stilt_house_b2,
    "StiltHutC": stilt_hut_c,
    "WitchHut": witch_hut,
}


# ── 받침판 ─────────────────────────────────────────────────
def _rects(L, z0, top, openings, margin=0.06):
    """벽 면 [0,L]x[z0,top(u)] 에서 창·문 구멍을 뺀 사각형들(u0,u1,v0,v1). 박공(top 이 u 에 따라 변함)은 띠로 자른다."""
    cuts = {0.0, L}
    for (ou0, ou1, _, _) in openings:
        for c in (ou0 - margin, ou1 + margin):
            if 0 < c < L:
                cuts.add(c)
    cuts = sorted(cuts)
    out = []
    for u0, u1 in zip(cuts[:-1], cuts[1:]):
        if u1 - u0 < 0.05:
            continue
        # 박공이면 0.8 폭 띠로 나눈다
        strips = [(u0, u1)]
        if top is not None and not isinstance(top, (int, float)):
            n = max(1, int(math.ceil((u1 - u0) / 0.8)))
            strips = [(u0 + (u1 - u0) * k / n, u0 + (u1 - u0) * (k + 1) / n) for k in range(n)]
        for s0, s1 in strips:
            um = (s0 + s1) / 2
            zt = top if isinstance(top, (int, float)) else min(top(s0), top(s1)) - 0.05
            spans = [(z0, zt)]
            for (ou0, ou1, ov0, ov1) in openings:
                if um > ou0 - margin and um < ou1 + margin:
                    spans = S._subtract(spans, (ov0 - margin, ov1 + margin))
            for v0, v1 in spans:
                if v1 - v0 > 0.1:
                    out.append((s0, s1, v0, v1))
    return out


def add_backing(ia, walls):
    """벽 속 받침판. 통나무 벽은 흙 메움(mud), 판자벽은 짙은 판재."""
    n = 0
    for w in walls:
        p0, p1 = Vector(w["p0"]), Vector(w["p1"])
        d = p1 - p0
        L = d.length
        yaw = math.degrees(math.atan2(d.y, d.x))
        lean = w.get("lean", 0.0) or 0.0
        if w["kind"] == "log":
            thick, key, top = 2 * w["r"] * 0.55, "mud", w["z1"]
        else:
            # 박공(삼각벽)은 옆벽과 같은 선에서 아래 0.2~0.6 이 겹친다 → 두께를 달리해 면이 겹쳐 반짝이지 않게
            gable = bool(w.get("top_profile"))
            thick, key = w["thick"] * (0.45 if gable else 0.55), "wood_dark"
            top = w["top_profile"] if gable else w["z1"]
        # 모서리에서 직각인 두 받침판 윗면이 같은 높이로 겹치지 않게 x 방향 벽은 0.03 낮춘다
        if isinstance(top, (int, float)) and abs(d.x) > abs(d.y):
            top -= 0.03
        with ia.at(matrix=w["M"]):
            with ia.at(loc=(p0.x, p0.y, 0), rot=(lean, 0, yaw)):
                for (u0, u1, v0, v1) in _rects(L, w["z0"], top, w.get("openings") or ()):
                    ia.box(((u0 + u1) / 2, 0, (v0 + v1) / 2), (u1 - u0, thick, v1 - v0), key, bevel=0.0)
                    n += 1
    return n


def add_floor_backing(ia, rooms):
    """방 바닥 밑 받침판(판자 틈·빠진 판자로 물이 보이지 않게). rooms: [(M, x0, x1, y0, y1, z)]"""
    for (M, x0, x1, y0, y1, z) in rooms:
        with ia.at(matrix=M):
            # 판자 밑면(z-0.37..-0.31)보다 아래(윗면 z-0.40) — 가까이 붙이면 판자 밑면과 겹쳐 반짝인다
            ia.box(((x0 + x1) / 2, (y0 + y1) / 2, z - 0.45), (x1 - x0, y1 - y0, 0.1), "wood_dark", bevel=0.0)


# ── 짓기 ──────────────────────────────────────────────────
def build_all():
    import swamp_interior_design as D

    pal = json.load(open(r"C:\wth\roblox\assets\palette.json", encoding="utf-8"))
    out = {}
    for name, builder in BUILDERS.items():
        WALLS.clear()
        FLOORS.clear()
        a = builder()
        walls = [w for w in WALLS]
        ia = Asset(name + "_Interior", "Prop")
        nb = add_backing(ia, walls)
        rooms = D.ROOMS[name](ia)  # 방 바닥 사각형들(받침판용) — 설계 모듈이 안다
        add_floor_backing(ia, rooms)
        nb_parts = len(ia.prims)
        D.DESIGN[name](ia)
        parts = ia.parts_json()
        for p in parts:
            if p["k"] not in pal:
                raise SystemExit("팔레트에 없는 재질: %s (%s)" % (p["k"], name))
        lights = [{"pos": [round(v, 3) for v in to_rbx_pos(L["pos"])], "color": list(L["color"]), "range": L["range"], "brightness": L["brightness"]} for L in ia.lights]
        out[name] = {"parts": parts, "lights": lights, "backing": nb_parts}
        print("%-14s 벽 %2d → 받침판 %3d개(바닥 포함 %d), 인테리어 %3d개, 불빛 %d" % (name, len(walls), nb, nb_parts, len(parts) - nb_parts, len(lights)))
    json.dump(out, open(HERE / "swamp" / "interiors.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    write_luau(out, pal)
    return out


def write_luau(out, pal):
    """Studio 용 자료: 팔레트 + 에셋별 부품 {모양, 재질키, x,y,z, r00..r22, sx,sy,sz} + 불빛."""
    L = ["return {", "PALETTE = {"]
    keys = sorted({p["k"] for v in out.values() for p in v["parts"]})
    for k in keys:
        c = pal[k]
        L.append('["%s"] = { "%s", %d, %d, %d, %s, %s, %s },' % (k, c["material"], c["color"][0], c["color"][1], c["color"][2],
                                                               c.get("transparency", 0), c.get("reflectance", 0), "true" if c.get("castShadow", True) else "false"))
    L.append("},")
    L.append("ASSETS = {")
    for name, v in out.items():
        L.append('["%s"] = { parts = {' % name)
        for p in v["parts"]:
            L.append('{ "%s", "%s", %s, %s, %s, %s },' % (p["s"], p["k"], ", ".join("%g" % x for x in p["p"]), ", ".join("%g" % x for x in p["r"]),
                                                    ", ".join("%g" % x for x in p["z"]), "true" if p["sh"] else "false"))
        L.append("}, lights = {")
        for l in v["lights"]:
            L.append("{ %g, %g, %g, %d, %d, %d, %g, %g }," % (*l["pos"], *l["color"], l["range"], l["brightness"]))
        L.append("} },")
    L.append("},")
    L.append("}")
    (HERE / "swamp" / "interiors.luau").write_text("\n".join(L), encoding="utf-8", newline="\n")


# ── 미리보기 ──────────────────────────────────────────────
def _mat(name, rgb, emit=0.0, alpha=1.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = tuple((v / 255) ** 2.2 for v in rgb) + (1,)
    b.inputs["Base Color"].default_value = lin
    b.inputs["Roughness"].default_value = 0.85
    if emit:
        b.inputs["Emission Color"].default_value = lin
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
    return m


def parts_to_objects(parts, pal, tag):
    """부품 목록(로블록스 좌표) → 블렌더 물체(에셋 좌표). 원기둥은 로컬 X 축."""
    import bmesh
    objs = []
    for i, p in enumerate(parts):
        x, y, z = p["p"]
        r = p["r"]
        sx, sy, sz = p["z"]
        # 로블록스 회전 → 블렌더: R_b = C^T R_r C, C = ((1,0,0),(0,0,1),(0,-1,0))
        Rr = Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])))
        C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
        Rb = C.transposed() @ Rr @ C
        bm = bmesh.new()
        if p["s"] == "C":
            bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.5, radius2=0.5, depth=1.0)
            bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"))
            # 로블록스 크기 (x, y, z) → 블렌더 로컬 (x, -z, y)
            scale = (sx, sz, sy)
        elif p["s"] == "S":
            bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.5)
            scale = (sx, sz, sy)
        else:
            bmesh.ops.create_cube(bm, size=1.0)
            scale = (sx, sz, sy)
        me = bpy.data.meshes.new("m")
        bm.to_mesh(me)
        bm.free()
        c = pal[p["k"]]
        me.materials.append(_mat("P_" + p["k"], c["color"], 3.0 if c["material"] == "Neon" else 0.0))
        ob = bpy.data.objects.new("%s_%d" % (tag, i), me)
        M = Rb.to_4x4() @ Matrix.Diagonal(Vector((*scale, 1)))
        M.translation = Vector((x, -z, y))
        ob.matrix_world = M
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
    return objs


def _text(s, loc, size=0.9, rot_z=0.0, col=(20, 20, 20)):
    cu = bpy.data.curves.new("T", "FONT")
    cu.body = s
    cu.size = size
    cu.align_x = "CENTER"
    ob = bpy.data.objects.new("T_" + s, cu)
    ob.location = loc
    ob.rotation_euler = (0, 0, rot_z)
    cu.materials.append(_mat("Txt%d%d%d" % col, col))
    bpy.context.scene.collection.objects.link(ob)


def _grid(x0, x1, y0, y1, z):
    """1 스터드 가는 선, 5 스터드 굵은 선, 가장자리에 숫자."""
    import bmesh
    for kind, step, w, col in (("fine", 1, 0.03, (150, 150, 150)), ("bold", 5, 0.08, (60, 60, 200))):
        bm = bmesh.new()
        xs = range(int(math.floor(x0)), int(math.ceil(x1)) + 1)
        ys = range(int(math.floor(y0)), int(math.ceil(y1)) + 1)
        for gx in xs:
            if gx % step == 0:
                bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((gx, (y0 + y1) / 2, z)) @ Matrix.Diagonal((w, y1 - y0, 0.01, 1)))
        for gy in ys:
            if gy % step == 0:
                bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(((x0 + x1) / 2, gy, z)) @ Matrix.Diagonal((x1 - x0, w, 0.01, 1)))
        me = bpy.data.meshes.new("grid_" + kind)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(_mat("Grid_" + kind, col, 1.5))
        ob = bpy.data.objects.new("grid_" + kind, me)
        bpy.context.scene.collection.objects.link(ob)
    for gx in range(int(math.ceil(x0 / 5) * 5), int(x1) + 1, 5):
        _text(str(gx), (gx, y0 - 1.2, z), col=(200, 30, 30))
        _text(str(gx), (gx, y1 + 0.4, z), col=(200, 30, 30))
    for gy in range(int(math.ceil(y0 / 5) * 5), int(y1) + 1, 5):
        _text(str(gy), (x0 - 1.4, gy - 0.3, z), col=(30, 120, 30))
        _text(str(gy), (x1 + 1.4, gy - 0.3, z), col=(30, 120, 30))


# 찍을 장면: 이름 → (에셋, 평면 범위 x0,x1,y0,y1, 평면 자르는 높이, 바닥 z, 실내 카메라, 바라볼 곳)
VIEW = {
    "Longhouse": ("Longhouse", (-18, 18, -5, 17), 18.5, 7.0, (-13.5, -1.5, 13.0), (10, 12, 9)),
    "Longhouse:hearth": ("Longhouse", (-18, 18, -5, 17), 18.5, 7.0, (13.5, 0.0, 13.0), (-10, 12, 9)),
    "StiltHouseA": ("StiltHouseA", (-10, 10, -6, 11), 17.5, 7.0, (6.5, -3.5, 13.5), (-5, 7, 8.5)),
    "StiltHouseB2": ("StiltHouseB2", (-11, 11, 2, 20), 16.4, 7.0, (5.8, 5.0, 13.0), (-5, 15, 8.5)),
    "StiltHouseB2:up": ("StiltHouseB2", (-11, 11, 1, 20), 27.5, 18.2, (7.5, 3.5, 24.0), (-5, 14, 19.5)),
    "StiltHutC": ("StiltHutC", (-8, 8, -6, 8), 14.6, 6.0, (4.8, -3.8, 11.5), (-4, 5, 7)),
    "WitchHut": ("WitchHut", (-9, 9, -6, 10), 16.0, 6.5, (2.4, -1.8, 11.6), (-3.5, 6.5, 8)),
}


def render_asset(shot, mode, parts, pal):
    sys.path.insert(0, str(HERE))
    import swamp2_preview as SP

    name, (x0, x1, y0, y1), cut, fz, cam_p, tgt = VIEW[shot]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SP.setup_render((1400, 1000) if mode == "plan" else (1600, 1000))
    SP.kit_collections([name])
    for c in bpy.data.collections:
        if c.name.startswith("K_") and c.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(c)
    parts_to_objects(parts, pal, "N")
    sc = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("C"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    if mode == "plan":
        _grid(x0, x1, y0, y1, fz + 0.05)
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = max(x1 - x0 + 5, (y1 - y0 + 5) * 1.4)
        cam.location = ((x0 + x1) / 2, (y0 + y1) / 2, 200)
        cam.rotation_euler = (0, 0, 0)
        cam.data.clip_start = 200 - cut
        cam.data.clip_end = 400
        # 해를 위에서
        for o in bpy.data.objects:
            if o.type == "LIGHT":
                o.rotation_euler = (math.radians(15), 0, math.radians(20))
    else:
        cam.data.lens = 16
        cam.location = cam_p
        d = Vector(tgt) - Vector(cam_p)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        # 실내는 어두우니 등불 대신 약한 채움빛
        fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "POINT"))
        fill.data.energy = 900
        fill.location = ((x0 + x1) / 2, (y0 + y1) / 2 + 3, fz + 7)
        sc.collection.objects.link(fill)
    sc.render.filepath = str(HERE / "swamp" / ("room_%s_%s.png" % (shot.replace(":", "_"), mode)))
    bpy.ops.render.render(write_still=True)
    print("찍음", shot, mode)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    pal = json.load(open(r"C:\wth\roblox\assets\palette.json", encoding="utf-8"))
    if not args or "build" in args:
        out = build_all()
    else:
        out = json.load(open(HERE / "swamp" / "interiors.json", encoding="utf-8"))
    modes = {"plan": [], "view": []}
    cur = None
    for a in args:
        if a in modes:
            cur = a
        elif cur and a in VIEW:
            modes[cur].append(a)
        elif cur and a == "all":
            modes[cur] += list(VIEW)
    if not args:
        modes = {"plan": list(VIEW), "view": list(VIEW)}
    for mode, shots in modes.items():
        for shot in shots:
            render_asset(shot, mode, out[VIEW[shot][0]]["parts"], pal)


main()
