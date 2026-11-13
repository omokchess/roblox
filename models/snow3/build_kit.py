# -*- coding: utf-8 -*-
"""
build_kit.py — 2026-11-13. 설원 마을 3판 건물 키트를 짓는다.

models/snow3/b_*.py 를 모두 찾아(ONLY=Sn3_Smithy,Sn3_Bank 로 몇 개만) 짓고 내놓는다:
  models/SnowTown3Kit.fbx        재질 덩이 메시(이름 = 앞머리_재질) + 원점 표지 SnowTown3Origin_Marker.
                                 블렌더 (x, y, z) → 로블록스 (-x, z, y), 앞 = -y(build_steam_town.py 와 같은 내보내기)
  tools/Snow_Inside3_data.luau   충돌·소품·등·NPC·불 표(tools/Snow_Inside_data.luau 와 같은 형식 — build_steam_inside.emit_luau)
  tools/snow3_kit.json           모델마다 앞머리·발자국(base/all, 로블록스 로컬 x0 x1 z0 z1)·문·높이·재질·삼각형
ONLY 로 일부만 지으면 FBX 이름은 SnowTown3Kit_<이름>.fbx, data·json 은 쓰지 않는다(다른 건물 자료가 빠지니까).
돌리기: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P models/snow3/build_kit.py
"""
import glob
import importlib
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib as K  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))


def modules():
    out = []
    for p in sorted(glob.glob(os.path.join(HERE, "b_*.py"))):
        out.append(importlib.import_module(os.path.splitext(os.path.basename(p))[0]))
    return out


def rbx_box(pts):
    """블렌더 점들 → 로블록스 로컬 발자국 (x0, x1, z0, z1)"""
    xs = [-p[0] for p in pts]
    zs = [p[1] for p in pts]
    return [round(min(xs), 2), round(max(xs), 2), round(min(zs), 2), round(max(zs), 2)]


def footprint(objs):
    allp, basep, top = [], [], 0.0
    for ob in objs:
        for v in ob.data.vertices:
            p = ob.matrix_world @ v.co
            allp.append(p)
            if p.z < 1.0:
                basep.append(p)
            top = max(top, p.z)
    return rbx_box(basep), rbx_box(allp), round(top, 2)


def main():
    only = os.environ.get("ONLY")
    mods = [m for m in modules() if not only or m.NAME in only.split(",")]
    assert mods, "지을 건물이 없다(ONLY=%s)" % only
    K.L.clear_scene()
    objs, kit = [], {}
    for m in mods:
        mine, tris, (zm, zl) = K.build_model(m)
        objs += mine
        base, allb, top = footprint(mine)
        doors = [{"x": round(-p[0], 2), "z": round(p[1], 2), "width": w, "height": h,
                  "facing": ("-Z" if f < 0 else "+Z") if ax == "x" else ("+X" if f < 0 else "-X")}
                 for p, w, h, f, ax in K.DOOR_INFO.get(m.NAME, [])]
        kit[m.NAME] = {"prefix": m.PREFIX, "variant": getattr(m, "VARIANT", None),
                       "base": dict(zip(("x0", "x1", "z0", "z1"), base)), "all": dict(zip(("x0", "x1", "z0", "z1"), allb)),
                       "size_base": [round(base[1] - base[0], 2), round(base[3] - base[2], 2)],
                       "size_all": [round(allb[1] - allb[0], 2), round(allb[3] - allb[2], 2)],
                       "height": top, "doors": doors, "materials": sorted(tris), "tris": tris, "tris_total": sum(tris.values())}
        print("  %-12s %s  %6d tri  base %.1f×%.1f  all %.1f×%.1f  높이 %.1f  반짝임 민 면 %d 남음 %d" % (
            m.NAME, kit[m.NAME]["variant"], sum(tris.values()), *kit[m.NAME]["size_base"], *kit[m.NAME]["size_all"], top, zm, zl))
    mk = K.L.Group("SnowTown3Origin_Marker", K.L.material("Stone", K.PAL))
    mk.box(0, 0, 0, 0.8, 0.8, 0.8)
    marker = mk.finish()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs + [marker]:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = marker
    fbx = os.path.join(ROOT, "models", "SnowTown3Kit.fbx" if not only else "SnowTown3Kit_%s.fbx" % only.replace(",", "_"))
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             axis_forward="-Z", axis_up="Y", object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
                             bake_space_transform=False)
    print("objects %d  FBX: %s" % (len(objs) + 1, fbx))
    if not only:
        K.I.emit_luau(os.path.join(ROOT, "tools", "Snow_Inside3_data.luau"))
        with open(os.path.join(ROOT, "tools", "snow3_kit.json"), "w", encoding="utf-8", newline="\n") as fh:
            json.dump({"_": "models/snow3/build_kit.py 가 만든 표(손으로 고치지 말 것). 로블록스 로컬 = (-x, z, y), 원점 = 발자국 가운데 땅",
                       "new_materials": {"DarkLog": K.PAL["DarkLog"]}, "models": kit}, fh, ensure_ascii=False, indent=1)
        print("data: tools/Snow_Inside3_data.luau · tools/snow3_kit.json")


main()
