"""레벨 전체를 Blender 씬으로 조립하고 렌더 (개관도 + 뷰티샷). 조립한 씬은 .blend 로 저장 가능.

    python blender/level/render_level.py [--samples 48] [--save-blend] [--shots overview,village,ferry,shrine,harbor]
"""

import argparse
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

from swamplib import render  # noqa: E402
from swamplib.materials import terrain_material, water_material  # noqa: E402
import build_all  # noqa: E402

ROOT = HERE.parents[1]
OUT = ROOT / "assets" / "previews"

MAT_RGB = {0: (196, 178, 136), 1: (72, 60, 46), 2: (104, 86, 62), 3: (80, 108, 56), 4: (98, 136, 68), 5: (108, 104, 98), 6: (82, 86, 84), 7: (140, 130, 112), 8: (176, 172, 158)}


def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def terrain_mesh(isl):
    d = np.load(ROOT / "assets" / f"terrain_{isl['name']}.npz")
    h, m = d["h"], d["m"]
    ny, nx = h.shape
    x0, y0 = isl["x0"], isl["y0"]
    verts = []
    for j in range(ny):
        for i in range(nx):
            verts.append((x0 + (i + 0.5) * 4, y0 + (j + 0.5) * 4, float(h[j, i])))
    faces = []
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    me = bpy.data.meshes.new("T_" + isl["name"])
    me.from_pydata(verts, [], faces)
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    data = []
    for f in faces:
        for vi in f:
            j, i = divmod(vi, nx)
            r, g, b = MAT_RGB[int(m[j, i])]
            data.extend((srgb(r), srgb(g), srgb(b), 1.0))
    col.data.foreach_set("color", data)
    me.polygons.foreach_set("use_smooth", [True] * len(faces))
    me.materials.append(terrain_material("M_Terrain", (0, 0, 0)))
    ob = bpy.data.objects.new("Terrain_" + isl["name"], me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def build_asset_collections(names):
    lib = bpy.data.collections.new("AssetLibrary")
    bpy.context.scene.collection.children.link(lib)
    cols = {}
    for modname, fn in build_all.collect_builders(None):
        a = fn()
        if a.name not in names:
            continue
        c = bpy.data.collections.new("A_" + a.name)
        lib.children.link(c)
        a.finalize(c)
        cols[a.name] = c
    lib.hide_render = True
    lay = bpy.context.view_layer.layer_collection.children["AssetLibrary"]
    lay.exclude = True
    return cols


def instance(col, loc, yaw, scale=1.0, name="inst"):
    e = bpy.data.objects.new(name, None)
    e.instance_type = "COLLECTION"
    e.instance_collection = col
    e.location = loc
    e.rotation_euler = (0, 0, math.radians(yaw))
    e.scale = (scale, scale, scale)
    bpy.context.scene.collection.objects.link(e)
    return e


def route_pose(route, s):
    pts = [Vector((p[0], p[1], 0)) for p in route]
    seg = [(pts[(i + 1) % len(pts)] - pts[i]).length for i in range(len(pts))]
    total = sum(seg)
    s = s % total
    acc = 0.0
    for i, L in enumerate(seg):
        if acc + L >= s:
            f = (s - acc) / L
            p = pts[i].lerp(pts[(i + 1) % len(pts)], f)
            d = pts[(i + 1) % len(pts)] - pts[i]
            return p, math.degrees(math.atan2(d.y, d.x)) - 90
        acc += L
    return pts[0], 0


def camera(loc, target, lens=35, ortho=None):
    scn = bpy.context.scene
    cd = bpy.data.cameras.new("Cam")
    cd.lens = lens
    cd.clip_end = 20000
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    cam = bpy.data.objects.new("Cam", cd)
    scn.collection.objects.link(cam)
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scn.camera = cam
    return cam


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--save-blend", action="store_true")
    ap.add_argument("--shots", default="overview,village,ferry,shrine,harbor,witch")
    ap.add_argument("--res", default="1600x900")
    args = ap.parse_args(argv)
    res = tuple(int(v) for v in args.res.split("x"))
    cache = json.loads((ROOT / "assets" / "level_cache.json").read_text())
    render.reset_scene()
    names = {it["a"] for it in cache["items"]} | {"Ferry"}
    cols = build_asset_collections(names)
    for isl in cache["islands"]:
        terrain_mesh(isl)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
    w = bpy.context.active_object
    w.scale = (4200, 2600, 1)
    w.name = "Sea"
    w.data.materials.append(water_material("M_Sea", (30, 62, 70), 0.0))
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, -36.2))
    fl = bpy.context.active_object
    fl.scale = (4200, 2600, 1)
    fl.data.materials.append(terrain_material("M_Terrain", (0, 0, 0)))
    for k, it in enumerate(cache["items"]):
        instance(cols[it["a"]], it["p"], it["r"], it.get("s", 1.0), f"I{k}_{it['a']}")
    # 정박 중인 배 1척 + 항해 중 1척 (연출)
    route = cache["route"]
    p0, yaw0 = route_pose(route, 0.0)
    instance(cols["Ferry"], (p0.x, p0.y, 0), yaw0, 1.0, "FerryDocked")
    p1, yaw1 = route_pose(route, 1500.0)
    instance(cols["Ferry"], (p1.x, p1.y, 0), yaw1, 1.0, "FerrySailing")
    render.setup_world(sun_elev=24, sun_azim=235, sun_strength=3.0)
    shots = {
        "overview": dict(loc=(-150, 0, 3000), target=(-150, 0, 0), ortho=3100, lens=50),
        "village": dict(loc=(250, -250, 150), target=(470, 20, 4), lens=30),
        "ferry": dict(loc=(p1.x - 160, p1.y - 120, 45), target=(p1.x, p1.y, 12), lens=35),
        "shrine": dict(loc=(820, -330, 90), target=(900, -200, 5), lens=32),
        "harbor": dict(loc=(-480, -200, 120), target=(-640, 10, 5), lens=30),
        "witch": dict(loc=(820, 60, 40), target=(880, 150, 8), lens=32),
    }
    for name in args.shots.split(","):
        sh = shots[name]
        camera(sh["loc"], sh["target"], sh.get("lens", 35), sh.get("ortho"))
        r = (2400, 1350) if name == "overview" else res
        render.render(OUT / f"Level_{name}.jpg", samples=args.samples, res=r)
        print("[level] rendered", name)
    if args.save_blend:
        (ROOT / "assets" / "blend").mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "assets" / "blend" / "SwampArchipelago_Level.blend"), compress=True)
        print("[level] saved blend")


if __name__ == "__main__":
    main()
