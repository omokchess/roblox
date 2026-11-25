# -*- coding: utf-8 -*-
"""
figuren_render.py — 2026-11-23 아트 1팀. 기물군 본부(Figuren_HQ, 2판 키트) 전/후 렌더 · 사진판 · 충돌 표 따로 뽑기.
사용자(2026-11-23): "기물군 본부쪽도 세부 디테일 수정" · "한쪽에만 세밀하게 구현돼있고, 다른 한쪽은 민둥민둥한 건 전체적으로 세밀하게".

돌리기(프로젝트 루트):
  BL="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
  "$BL" -b -P models/figuren_render.py                                   → '후'(지금 build_steam_figuren.py)
  STAGE=before ORIG=<옛 build_steam_figuren.py 가 든 폴더> "$BL" -b -P models/figuren_render.py   → '전'(git HEAD 에서 꺼낸 파일)
  python models/figuren_render.py sheet                                  → models/render/figuren_sheet.png (시스템 파이썬, PIL)
  "$BL" -b -P models/figuren_render.py -- emit                           → tools/Snow_Inside_Figuren_data.luau (본부 충돌·소품 표만 — 총괄이 Snow_Inside_data 에 합침)
out: models/render/figuren_<시점>_<before|after>.png. 작업대 렌더(STUDIO 빛, 그림자는 안 시점만), 창유리·김·빛 표지 숨김.
겉: 네 면(정면 원근) + 3/4 둘. 안: 1인칭 눈높이 바닥 + 4.5(아래층 ZF 2.2 → 6.7, 위층 Z1 16 → 20.5).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")
LO, UP = 2.2 + 4.5, 16.0 + 4.5
VIEWS = [   # (꼬리, 카메라, 바라볼 점, 렌즈)
    ("ext_front", (0, -175, 26), (0, 0, 24), 35), ("ext_back", (0, 182, 26), (0, 0, 24), 35),
    ("ext_left", (-185, 2, 26), (0, 2, 24), 35), ("ext_right", (185, 2, 26), (0, 2, 24), 35),
    ("ext_34fl", (-120, -135, 70), (0, 0, 18), 35), ("ext_34br", (120, 140, 70), (0, 0, 18), 35),
    ("in_gate", (0, -31.5, LO), (0, 10, 7.0), 17), ("in_hall", (0, -12.5, LO), (0, 28, 9.0), 17),
    ("in_hall_corner", (-21, -13, LO), (8, 26, 8.0), 17), ("in_war", (-9.5, -19.0, UP), (2.5, -27.5, 18.0), 17),
    ("in_training", (-27.5, 0.5, LO), (-31, -22, 5.0), 17), ("in_lounge", (27.5, -2, LO), (33.5, -18, 5.5), 17),
    ("in_library", (-27.5, 1.0, UP), (-33, -20, 19.5), 17), ("in_master", (27.5, 1.0, UP), (31.5, -14, 19.5), 17),
]


def sheet():
    from PIL import Image, ImageDraw
    tw, th = 300, 200
    ext = [v[0] for v in VIEWS if v[0].startswith("ext")]
    inn = [v[0] for v in VIEWS if v[0].startswith("in")]
    rows = [(ext, "before"), (ext, "after"), (inn, "before"), (inn, "after")]
    cols = max(len(ext), len(inn))
    lab = 90
    im = Image.new("RGB", (lab + cols * tw, len(rows) * th), (24, 26, 30))
    d = ImageDraw.Draw(im)
    for j, (tags, stage) in enumerate(rows):
        d.text((8, j * th + th // 2 - 6), stage.upper() if stage == "after" else stage, fill=(255, 200, 90) if stage == "after" else (170, 170, 170))
        for i, t in enumerate(tags):
            p = os.path.join(OUT, "figuren_%s_%s.png" % (t, stage))
            if os.path.exists(p):
                im.paste(Image.open(p).convert("RGB").resize((tw - 4, th - 4)), (lab + i * tw + 2, j * th + 2))
                d.text((lab + i * tw + 6, j * th + 4), t, fill=(255, 255, 255))
    out = os.path.join(OUT, "figuren_sheet.png")
    im.save(out)
    print("sheet →", out)


def build():
    import bpy  # noqa: F401
    sys.path.insert(0, HERE)
    if os.environ.get("STAGE") == "before":
        # build_steam_town 이 models 를 경로 맨 앞에 넣으니, 옛 파일을 먼저 모듈 자리에 박아 둔다(경로 순서로는 안 됨 — 2026-11-24 전 줄이 후와 같게 찍힌 사고)
        import importlib.util
        spec = importlib.util.spec_from_file_location("build_steam_figuren", os.path.join(os.environ["ORIG"], "build_steam_figuren.py"))
        old = importlib.util.module_from_spec(spec)
        sys.modules["build_steam_figuren"] = old
        spec.loader.exec_module(old)
    import build_steam_town as T
    import build_steam_figuren as FIG
    T.L.clear_scene()
    g = T.G("FiguIn")
    FIG.JOBS[0][2](g)
    objs, tris = [], 0
    for k in T.PAL:
        ob = g[k].finish()
        if not ob.data.polygons:
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        tris += sum(len(p.vertices) - 2 for p in ob.data.polygons)
        objs.append(ob)
    return T, FIG, objs, tris


def render():
    import bpy
    from mathutils import Vector
    stage = os.environ.get("STAGE", "after")
    T, FIG, objs, tris = build()
    print("Figuren_HQ %s %d tri" % (stage, tris))
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.show_cavity = True
    sh.show_shadows = True
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.62, 0.72, 0.82)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 800
    for ob in objs:
        ob.hide_render = ob.name.endswith(("_WinGlass", "_Vent", "_LampPt", "_Pane", "_Cut"))
    bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, -0.02))
    bpy.context.active_object.data.materials.append(T.L.material("SnowCap", T.PAL))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(OUT, exist_ok=True)
    for tail, loc, look, lens in VIEWS:
        # 겉 시점은 그림자를 끈다: 작업대 그림자(그림자 부피)가 얇은 띠돌·눈 띠에서 땅 위 긴 줄 자국을 만든다(형상 아님 — 2026-11-24 확인)
        sh.show_shadows = not tail.startswith("ext")
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        cam.data.clip_start, cam.data.clip_end = 0.1, 3000.0
        scene.render.filepath = os.path.join(OUT, "figuren_%s_%s.png" % (tail, stage))
        bpy.ops.render.render(write_still=True)
    print("done →", OUT)


def emit():
    T, FIG, objs, tris = build()
    out = os.path.join(HERE, "..", "tools", "Snow_Inside_Figuren_data.luau")
    T.I.emit_luau(out)
    print("emit →", out, "(Figuren_HQ 만 — Snow_Inside_data.luau 의 Figuren_HQ 칸과 바꿔 낄 것)")


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
if argv[:1] == ["sheet"]:
    sheet()
elif argv[:1] == ["emit"]:
    emit()
else:
    render()
