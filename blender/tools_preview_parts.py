"""검증용: Part 버전 JSON(Roblox 좌표)을 Blender 로 역변환해 렌더.

Roblox 로 가는 좌표/회전/크기 변환이 올바른지 눈으로 확인하는 용도.
    python blender/tools_preview_parts.py StiltHouseA [--colliders]
"""

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from swamplib import config, render  # noqa: E402
from swamplib.asset import C, C_INV  # noqa: E402
from swamplib.materials import make_preview_material  # noqa: E402


def rbx_to_blender(pos, rot9):
    R_r = Matrix(((rot9[0], rot9[1], rot9[2]), (rot9[3], rot9[4], rot9[5]), (rot9[6], rot9[7], rot9[8])))
    R_b = C_INV @ R_r @ C
    p_b = Vector((pos[0], -pos[2], pos[1]))
    M = Matrix.Translation(p_b) @ R_b.to_4x4()
    return M


def add_part(shape, M, size_r, mat, name):
    sx, sy, sz = size_r
    if shape == "B" or shape == "W":
        bpy.ops.mesh.primitive_cube_add(size=1)
        ob = bpy.context.active_object
        ob.matrix_world = M @ Matrix.Diagonal(Vector((sx, sz, sy, 1)))
    elif shape == "C":
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.5, depth=1)
        ob = bpy.context.active_object
        # 기본 원기둥은 Z 축 -> X 축으로 눕힌 뒤 스케일
        ob.matrix_world = M @ Matrix.Rotation(1.5707963, 4, "Y") @ Matrix.Diagonal(Vector((sy, sz, sx, 1)))
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.5)
        ob = bpy.context.active_object
        ob.matrix_world = M @ Matrix.Diagonal(Vector((sx, sx, sx, 1)))
    ob.name = name
    if mat:
        ob.data.materials.append(mat)
    return ob


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    show_col = "--colliders" in sys.argv
    name = args[0]
    render.reset_scene()
    data = json.loads((config.PARTS_DIR / f"{name}.json").read_text())
    man = json.loads(config.MANIFEST_PATH.read_text())[name]
    for i, p in enumerate(data["parts"]):
        M = rbx_to_blender(p["p"], p["r"])
        add_part(p["s"], M, p["z"], make_preview_material(p["k"]), f"p{i}")
    if show_col:
        red = bpy.data.materials.new("col")
        red.use_nodes = True
        red.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1, 0.1, 0.1, 1)
        red.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.35
        for i, c in enumerate(man["colliders"]):
            M = rbx_to_blender(c["pos"], c["rot"])
            add_part("B" if c["shape"] == "Block" else "C", M, c["size"], red, f"c{i}")
    render.setup_world()
    render.ground("water")
    b = man["bounds"]
    bmin = (b["min"][0], -b["max"][2], b["min"][1])
    bmax = (b["max"][0], -b["min"][2], b["max"][1])
    render.frame_camera(bmin, bmax, azim=35, elev=18, pad=1.05)
    suffix = "_colliders" if show_col else "_parts"
    render.render(config.PREVIEW_DIR / f"{name}{suffix}.jpg", samples=24, res=(960, 540))
    print("parts:", len(data["parts"]))


if __name__ == "__main__":
    main()
