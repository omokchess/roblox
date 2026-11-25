# -*- coding: utf-8 -*-
"""
int1_render.py — 2026-11-18 아트 1팀. 1팀 건물(은행·잡화·대장간·시계탑·티켓) 안 1인칭(눈높이 바닥 + 4.5) 렌더, 전/후 비교, 사진판.

돌리기(프로젝트 루트에서):
  BL="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
  "$BL" -b -P models/snow3/int1_render.py -- Sn3_Bank [Sn3_General ...]            → '후'(지금 파일)
  STAGE=before ORIG=<옛 lib·b_*.py 가 든 폴더> "$BL" -b -P models/snow3/int1_render.py -- Sn3_Bank   → '전'
  python models/snow3/int1_render.py sheet          (시스템 파이썬 — PIL 있음. 블렌더 안 파이썬엔 PIL 이 없다)
  "$BL" -b -P models/snow3/int1_render.py -- check [Sn3_Bank ...]   → 건물 INFO["loops"] 통로 폭(8 이상) 검사, render/int1_check.txt
out: models/snow3/render/<이름>_int_<시점>_<before|after>.png · render/int1_sheet.png(건물마다 전 줄 / 후 줄)
작업대 렌더(preview.py 와 같은 Workbench · STUDIO 빛 · 그림자) — 창유리·김·빛 표지는 숨김. 렌즈 17mm = 로블록스 세로 FOV 70 의 3:2 화면.
시점은 아래 VIEWS 손 표(블렌더 좌표, 앞 = -y). 카메라 높이 = 바닥 + 4.5(티켓 손님 자리는 땅 + 4.5).
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")

# (꼬리, 카메라 (x, y, z), 바라볼 점 (x, y, z), 렌즈) — z 는 절대 높이
E = 2.0 + 4.5
VIEWS = {
    "Sn3_Bank": [
        ("door", (0, -11.6, E), (0, 14, 5.5), 17),
        ("counter", (0, -6.5, E), (0, 14, 5.0), 17),
        ("corner_fl", (-14.6, -11.4, E), (4, 8, 4.5), 17),
        ("corner_br", (14.4, 11.6, E), (-6, -2, 4.0), 17),
        ("focus_vault", (-6.0, 6.0, E), (1.5, 14.5, 5.5), 20),
        ("vault_in", (0, 16.2, E), (0, 25, 4.5), 17),
        ("vault_back", (-3.6, 22.3, E), (4.0, 14.0, 4.5), 17),
        ("corridor", (11.6, 14.0, E), (11.6, 25, 4.0), 17),
    ],
    "Sn3_General": [
        ("door", (0, -9.6, E), (0, 10, 5.0), 17),
        ("counter", (5.0, -1.5, E), (5.0, 11, 5.0), 17),
        ("corner_bl", (-10.2, 7.8, E), (6, -6, 4.5), 17),
        ("corner_fr", (10.6, -3.8, E), (-6, 8, 4.5), 17),
        ("focus_shelf", (1.0, 1.5, E), (1.0, 10.4, 5.8), 22),
    ],
    "Sn3_Smithy": [
        ("door", (0, -10.6, E), (-4, 8, 5.0), 17),
        ("counter", (8.0, -2.0, E), (8.0, 11.4, 5.0), 17),
        ("corner_fl", (-13.6, -10.6, E), (-5, 8, 5.0), 17),
        ("corner_fr", (13.6, -3.6, E), (-10, 8, 4.5), 17),
        ("focus_forge", (-3.0, -1.5, E), (-11.0, 4.5, 4.5), 20),
    ],
    "Sn3_Clock": [
        ("door", (0, -8.4, E), (0, 8, 6.0), 17),
        ("counter", (0, -1.5, E), (0, 8.6, 6.0), 17),
        ("corner_fl", (-7.6, -7.8, E), (4, 6, 5.5), 17),
        ("corner_br", (7.2, 4.4, E), (-5, -6, 5.0), 17),
        ("focus_gears", (-2.5, 0.0, E), (-1.0, 8.6, 7.5), 20),
    ],
    "Sn3_Ticket": [
        ("door", (0, -12.5, 4.5), (0, 2, 5.5), 17),
        ("counter", (0, -4.6, 4.5), (0, 3.2, 5.0), 17),
        ("corner_l", (-3.0, 1.3, 1.0 + 4.5), (3.2, 3.0, 4.8), 17),
        ("corner_r", (3.2, 0.4, 1.0 + 4.5), (-3.0, 3.4, 5.0), 17),
        ("focus_board", (-1.0, -5.6, 4.5), (-3.45, -1.1, 5.4), 20),
    ],
}


def sheet():
    from PIL import Image, ImageDraw
    tw, th = 320, 214
    rows = []
    for name, vs in VIEWS.items():
        for stage in ("before", "after"):
            rows.append((name, stage, [os.path.join(OUT, "%s_int_%s_%s.png" % (name, v[0], stage)) for v in vs]))
    cols = max(len(r[2]) for r in rows)
    lab = 150
    im = Image.new("RGB", (lab + cols * tw, len(rows) * th), (24, 26, 30))
    d = ImageDraw.Draw(im)
    for j, (name, stage, ps) in enumerate(rows):
        d.text((8, j * th + th // 2 - 14), name.replace("Sn3_", ""), fill=(235, 235, 235))
        d.text((8, j * th + th // 2 + 4), "before" if stage == "before" else "AFTER", fill=(160, 160, 160) if stage == "before" else (255, 200, 90))
        for i, p in enumerate(ps):
            if os.path.exists(p):
                im.paste(Image.open(p).convert("RGB").resize((tw - 4, th - 4)), (lab + i * tw + 2, j * th + 2))
                if j % 2 == 0:
                    d.text((lab + i * tw + 6, j * th + 4), os.path.basename(p).split("_int_")[1].rsplit("_", 1)[0], fill=(255, 255, 255))
    out = os.path.join(OUT, "int1_sheet.png")
    im.save(out)
    print("sheet →", out)


def prop_gears(K, name):
    """K.I.PROPS 의 Gear_24/16/10 을 build_steam.spoked_gear 로 지어 그 자리에 놓는다(렌더 전용)"""
    import math
    from mathutils import Matrix
    teeth = {"Gear_24": 24, "Gear_16": 16, "Gear_10": 10}
    out = []
    for kit, x, y, z, yaw, sc, rot, speed, col in K.I.PROPS.get(name, []):
        if kit not in teeth:
            continue
        r = teeth[kit] * K.S.TOOTH_PITCH / (2 * math.pi)
        g = K.G("RenderGear")
        K.L.transformed(g, Matrix.Translation((x, y, z - r)) @ Matrix.Rotation(math.radians(yaw), 4, "Z"),
                        lambda q, n=teeth[kit]: K.S.spoked_gear(q, n))
        for grp in g.values():
            if grp.bm.verts:
                out.append(grp.finish())
            else:
                grp.bm.free()
    return out


def render(names):
    import bpy
    from mathutils import Vector
    stage = os.environ.get("STAGE", "after")
    if stage == "before":
        sys.path.insert(0, os.path.dirname(HERE))          # models (hanok_lib 등)
        sys.path.insert(0, os.environ["ORIG"])             # 옛 lib.py · b_*.py 가 먼저
    else:
        sys.path.insert(0, HERE)
    import lib as K
    K.L.clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.show_cavity = True
    sh.show_shadows = True
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.62, 0.72, 0.82)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 800
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.02))
    bpy.context.active_object.data.materials.append(K.L.material("SnowCap", K.PAL))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    files = {"Sn3_Bank": "b_bank", "Sn3_General": "b_general", "Sn3_Smithy": "b_smithy", "Sn3_Clock": "b_clock", "Sn3_Ticket": "b_ticket"}
    for name in names:
        m = importlib.import_module(files[name])
        objs, tris, _ = K.build_model(m, zfix=False)
        objs += prop_gears(K, name)          # 도는 톱니(PROP — Studio 옛 키트 Gear_*)도 렌더에 보이게(내보내기엔 안 들어감)
        for ob in objs:
            ob.hide_render = ob.name.endswith(("WinGlass", "_Vent", "_LampPt"))
        print("  %s %s %d tri" % (name, stage, sum(tris.values())))
        for tail, loc, look, lens in VIEWS[name]:
            cam.location = Vector(loc)
            cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
            cam.data.type = "PERSP"
            cam.data.lens = lens
            cam.data.clip_start = 0.1
            cam.data.clip_end = 2000.0
            scene.render.filepath = os.path.join(OUT, "%s_int_%s_%s.png" % (name, tail, stage))
            bpy.ops.render.render(write_still=True)
        for ob in objs:
            bpy.data.objects.remove(ob, do_unlink=True)
    print("done →", OUT)


def check(names):
    """INFO["loops"] = [(이름, (출발 x, y), (도착 x, y))] 마다 audit.walk_width 로 '가장 넓게 지나는 길의 가장 좁은 폭'(바닥 + 2.5 충돌 상자)을 잰다.
    1팀 기준: 금고실·회랑·안쪽 길 8 이상(총괄 지시서 2026-11-18). 문 → 카운터 주 통로 10 은 audit.py 가 맡는다"""
    sys.path.insert(0, HERE)
    src = open(os.path.join(HERE, "audit.py"), encoding="utf-8").read()
    src = src[:src.rstrip().rfind("main()")]
    A = {"__name__": "audit_lib", "__file__": os.path.join(HERE, "audit.py")}
    exec(compile(src, "audit.py", "exec"), A)
    K = A["K"]
    files = {"Sn3_Bank": "b_bank", "Sn3_General": "b_general", "Sn3_Smithy": "b_smithy", "Sn3_Clock": "b_clock", "Sn3_Ticket": "b_ticket"}
    lines, bad = ["int1_render.py check — 안쪽 통로 폭(길·회랑 10 / 문 8, 0.5 격자 오차 0.5)"], 0
    for name in names:
        m = importlib.import_module(files[name])
        if not getattr(m, "INFO", {}).get("loops"):
            continue
        K.L.clear_scene()
        g = K.G(m.PREFIX)
        K.I.job(m.NAME, m.build)(g)
        for label, a, b in m.INFO["loops"]:
            info = dict(m.INFO, walk=(a, b), free=(b[0] - 2.5, b[0] + 2.5, b[1] - 0.5, b[1] + 4.5))
            x0, x1, y0, y1 = info["inside"]
            info["inside"] = (x0, x1, min(y0, a[1] - 1.0), y1)
            w, at, _ = A["walk_width"](m.NAME, info)
            # 비평 1차(2026-11-24): 길·회랑 10 / 문 8 — 가장 좁은 자리가 INFO["doors_xy"] 문(가운데 x, y, 반폭) 안이면 문 기준
            door = any(abs(at[0] - dx) <= hw + 0.5 and abs(at[1] - dy) <= hw + 0.5 for dx, dy, hw in m.INFO.get("doors_xy", ()))
            need = 8.0 if door else 10.0
            ok = w >= need - 0.5 - 1e-6             # 0.5 격자: 칸 가운데가 길 가운데서 최대 0.25 어긋나 폭이 최대 0.5 작게 재진다
            bad += not ok
            lines.append("%s %-28s 폭 %.1f (가장 좁은 자리 x %.1f y %.1f — %s 기준 %.0f) → %s" % (name, label, w, at[0], at[1], "문" if door else "길", need, "통과" if ok else "걸림"))
        for grp in g.values():
            grp.bm.free()
    lines.append("걸림 %d" % bad)
    out = os.path.join(OUT, "int1_check.txt")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if True:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if argv[:1] == ["sheet"]:
        sheet()
    elif argv[:1] == ["check"]:
        check(argv[1:] or list(VIEWS))
    else:
        render(argv or list(VIEWS))
