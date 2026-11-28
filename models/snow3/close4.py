# -*- coding: utf-8 -*-
"""
close4.py — 2026-11-28 아트. 설원 3판 10채 '가까이 보기' 렌더(사용자 4차: 가까이에서 봤을 때 정성이 느껴지냐).
건물마다 눈높이(바닥 + 4.5)에서 1~3 스터드 앞 가까이 3장 + 문 시점 1장. 작업대 렌더(int1_render 와 같은 빛), 창유리·김·빛 표지 숨김.
돌리기(프로젝트 루트):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P models/snow3/close4.py -- Sn3_Smithy [Sn3_Bank ...]
  python models/snow3/close4.py sheet         → models/snow3/render/close4_sheet.png (시스템 파이썬 — PIL)
시점 표 VIEWS: (꼬리, 카메라 (x, y, z), 바라볼 점, 렌즈) — 블렌더 좌표, z 절대 높이
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")
E = 2.0 + 4.5          # 바닥 FZ 2 + 눈 4.5
FILES = {"Sn3_Bank": "b_bank", "Sn3_General": "b_general", "Sn3_Smithy": "b_smithy", "Sn3_Clock": "b_clock", "Sn3_Ticket": "b_ticket",
         "Sn3_Inn": "b_inn", "Sn3_Potion": "b_potion", "Sn3_Hospital": "b_hospital", "Sn3_Enhance": "b_enhance", "Sn3_Gate": "b_gate"}
VIEWS = {
    "Sn3_Bank": [
        ("door", (0, -11.6, E), (0, 14, 5.5), 17),
        ("teller", (-3.0, 1.6, E), (-3.0, 5.3, 6.2), 22),
        ("rateboard", (-12.6, -0.4, E), (-15.8, -0.4, 6.8), 22),
        ("staff", (-6.0, 2.2, E), (-9.0, 11.0, 4.8), 20),
    ],
    "Sn3_General": [
        ("door", (0, -9.6, E), (0, 10, 5.0), 17),
        ("counter", (5.0, 3.0, E), (5.0, 7.2, 6.0), 22),
        ("shelf", (-6.0, 6.6, E), (-6.0, 10.4, 5.4), 22),
        ("stove", (-4.0, -0.6, E), (-5.6, -4.0, 4.2), 22),
    ],
    "Sn3_Clock": [
        ("door", (0, -8.4, E), (0, 8, 6.5), 17),
        ("machine", (3.4, 1.6, E), (7.0, 6.2, 5.6), 20),
        ("map", (0.0, 2.6, E + 0.5), (0.0, 6.0, 4.6), 22),
        ("dial", (-2.0, 3.0, E), (0.0, 8.6, 9.0), 20),
    ],
    "Sn3_Inn": [
        ("door", (0, -10.0, 2.08 + 4.5), (0, 8, 5.5), 17),
        ("bar", (-11.0, -2.6, 2.08 + 4.5), (-11.0, 1.2, 5.8), 22),
        ("hearth", (10.4, -4.0, 2.08 + 4.5), (14.6, -4.0, 4.2), 20),
        ("room2", (-11.5, -4.2, 14.4 + 4.5), (-13.4, -9.2, 16.2), 20),
    ],
    "Sn3_Potion": [
        ("door", (0, -9.6, E), (0, 10, 5.0), 17),
        ("cauldron", (-6.0, 2.6, E), (-8.4, 5.2, 4.6), 20),
        ("counter", (0.0, 3.4, E), (0.0, 7.0, 6.0), 22),
        ("still", (5.0, -1.6, E), (8.0, 0.1, 5.0), 20),
    ],
    "Sn3_Hospital": [
        ("door", (-7.65, -10.0, E), (-7.65, 8, 5.5), 17),
        ("reception", (-12.0, 0.6, E), (-12.0, 5.0, 6.2), 22),
        ("engine", (0.0, -4.6, E), (0.0, -9.0, 5.8), 20),
        ("halo", (2.5, -3.6, E), (2.5, 0.0, 9.6), 20),
    ],
    "Sn3_Enhance": [
        ("door", (0, -9.6, E), (0, 10, 5.0), 17),
        ("engraver", (-3.4, 4.0, E), (-5.6, 5.8, 4.6), 22),
        ("counter", (6.6, 0.6, E), (7.2, 4.3, 5.6), 22),
        ("anvil", (-5.2, -2.4, E), (-7.6, 0.0, 4.2), 22),
    ],
    "Sn3_Gate": [
        ("door", (0, -12.0, 4.5), (0, 0, 7.0), 17),
        ("rack", (3.4, -1.2, 4.5), (6.3, 0.4, 5.2), 20),
        ("shield", (3.8, 1.0, 6.0), (6.3, 2.1, 8.4), 22),
        ("sign", (0, 5.6, 4.5), (0, 3.3, 11.0), 20),
    ],
    "Sn3_Ticket": [
        ("door", (0, -12.5, 4.5), (0, 2, 5.5), 17),
        ("machine", (1.2, -2.3, 4.6), (1.7, 0.1, 4.1), 24),
        ("board", (-1.0, -5.6, 4.5), (-3.45, -1.1, 5.4), 20),
        ("wicket", (0.0, -4.6, 4.5), (0, 3.2, 5.0), 17),
    ],
    "Sn3_Smithy": [
        ("door", (0, -10.6, E), (-4, 8, 5.0), 17),
        ("rack", (-6.2, 8.6, E), (-9.0, 11.2, 5.6), 20),
        ("counter", (10.0, 2.2, E), (10.4, 5.2, 5.4), 22),
        ("wall", (0.6, 8.2, E), (0.3, 11.4, 7.0), 20),
    ],
}


def sheet():
    from PIL import Image, ImageDraw
    tw, th = 330, 220
    names = [n for n in FILES if n in VIEWS]
    cols = max(len(VIEWS[n]) for n in names)
    lab = 110
    im = Image.new("RGB", (lab + cols * tw, len(names) * th), (24, 26, 30))
    d = ImageDraw.Draw(im)
    for j, name in enumerate(names):
        d.text((8, j * th + th // 2 - 6), name.replace("Sn3_", ""), fill=(235, 235, 235))
        for i, v in enumerate(VIEWS[name]):
            p = os.path.join(OUT, "%s_close4_%s.png" % (name, v[0]))
            if os.path.exists(p):
                im.paste(Image.open(p).convert("RGB").resize((tw - 4, th - 4)), (lab + i * tw + 2, j * th + 2))
                d.text((lab + i * tw + 6, j * th + 4), v[0], fill=(255, 220, 120))
    out = os.path.join(OUT, "close4_sheet.png")
    im.save(out)
    print("sheet →", out)


def render(names):
    import bpy
    from mathutils import Vector
    sys.path.insert(0, HERE)
    import lib as K
    src = open(os.path.join(HERE, "int1_render.py"), encoding="utf-8").read()
    R = {"__name__": "int1_lib", "__file__": os.path.join(HERE, "int1_render.py")}
    exec(compile(src[:src.index("def render(")], "int1_render.py", "exec"), R)     # prop_gears 만(도는 톱니 PROP 를 렌더에 보이게)
    K.L.clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.show_cavity = True
    sh.show_shadows = True
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.62, 0.72, 0.82)
    scene.render.resolution_x, scene.render.resolution_y = 900, 600
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.02))
    bpy.context.active_object.data.materials.append(K.L.material("SnowCap", K.PAL))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name in names:
        m = importlib.import_module(FILES[name])
        objs, tris, _ = K.build_model(m, zfix=False)
        objs += R["prop_gears"](K, name)
        for ob in objs:
            ob.hide_render = ob.name.endswith(("WinGlass", "_Vent", "_LampPt"))
        for tail, loc, look, lens in VIEWS[name]:
            cam.location = Vector(loc)
            cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
            cam.data.lens = lens
            cam.data.clip_start = 0.1
            cam.data.clip_end = 2000.0
            scene.render.filepath = os.path.join(OUT, "%s_close4_%s.png" % (name, tail))
            bpy.ops.render.render(write_still=True)
        for ob in objs:
            bpy.data.objects.remove(ob, do_unlink=True)
    print("done →", OUT)


if True:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if argv[:1] == ["sheet"]:
        sheet()
    else:
        render(argv or [n for n in FILES if n in VIEWS])
