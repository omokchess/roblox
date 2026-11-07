# -*- coding: utf-8 -*-
"""
build_callisto_prosthetic.py — 칼리스토 오른팔 의수 3판(2026-11-07). 사용자: "의수 팔은 로블록스 R6 아바타 팔을 주 기준으로 만들어줘".
(총괄 해석: R6 팔 상자 — 가로 1 × 세로 2 × 깊이 1 스터드의 곧은 직육면체 — 가 의수의 기본 형태. 말레니아식 금 의수의 재질·세공을 그 상자 위에 입힌다.
 멀리서 보면 R6 팔 그대로, 가까이서 보면 정교한 금 의수.)

레퍼런스(웹: 반다이남코 PureArts 1:1 "Arm of Malenia" 복제품 · 위키 Malenia · S.H.Figuarts 설명 + 게임 속 모습) 핵심:
  1. 매끈한 광택 금 판 · 판 가장자리 가는 테 · 판 위 가는 덩굴 세공. 2. 어깨는 둥근 돔이 아니라 작게 뒤로 휘는 날개판. 3. 관절 마디로 나뉜 손이 칼 자루를 쥔다 —
  칼이 손에서 이어진다. (칼리스토 별 모티프로 바꿈.)
형태: 외곽은 R6 팔 상자와 ±0.05 안 — 상자를 위→아래로 마디 나눈다.
  어깨 마디(맨 위 0.3, 윗면에 작은 날개판 셋이 윤곽 안에서 살짝 뒤로) · 위팔 판 · 팔꿈치 이음(가는 어두운 홈 + 작은 별 보석) · 아래팔 판 ·
  손목 고리 · 손(상자 바닥 0.4 — 앞면에 짧은 손가락 마디 판 넷 + 옆면 엄지 판, 바닥 중앙 놋쇠 고리 구멍으로 칼 슴베·날이 이어진다).
  각 마디: 모따기만 한 상자 판(초타원 단면) + 양끝 놋쇠 테 + 얕은 테두리 선 + 별 문양, 마디 사이엔 가는 검은 이음매.
묶음(재질, 메시 그룹): Gold 광택 금 · Brass 테·세공 · BluedSteel 이음매 · Glow 별빛(스튜디오에서 Neon) · DetailB 짙은 세공(B안 전용 — 아래).
변형(V_Prosthetic): 한 GLB 에 둘 다 들어 있다. 1(깔끔한 판) = DetailB 를 안 붙임. 2(세공 많은 판, 말레니아 느낌) = DetailB 도 붙임.
  → 가져오기 한 번에 둘 다 들어오고, Combat/Callisto.luau 가 Variant.Index("Prosthetic", 2) 로 DetailB 만 넣고 뺀다.

공간(블렌더): 원점 = 오른팔 가운데, 팔 축 = +z(위, 로블록스 +Y), 바깥(로블록스 +X) = 블렌더 -x, 앞(로블록스 -Z) = -y. 팔 끝 z = -1. 상자 반폭 0.5.
메시 이름 CallistoProsthetic_<묶음> + 원점 표지 WeaponsOrigin_Marker(1×1×1, 팔 가운데)
→ models/CallistoProsthetic.glb → 스튜디오 가져오기 → tools/Callisto_Prosthetic.luau(→ ReplicatedStorage.CallistoAssets.Prosthetic).
돌리기: blender -b -P models/build_callisto_prosthetic.py [-- render]
  렌더 art/callisto/prosthetic_{front,side,q34,blade,r6compare}.png (+ _B 붙은 것 = B안)
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_callisto_outfit as O  # noqa: E402

RENDER = "render" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
HOST = "CallistoProsthetic"
PI = math.pi
ROOT = os.path.abspath(os.path.join(HERE, ".."))
H = 0.5   # R6 팔 반폭


def sring(hx, hy, z, n=9, seg=48, cx=0.0, cy=0.0):
    """모따기 상자 단면(초타원, n 클수록 각진다) — 반시계."""
    pts = []
    for k in range(seg):
        a = 2 * PI * k / seg
        c, s = math.cos(a), math.sin(a)
        pts.append(Vector((cx + hx * math.copysign(abs(c) ** (2 / n), c), cy + hy * math.copysign(abs(s) ** (2 / n), s), z)))
    return pts


def slab(name, mat, z0, z1, hx, hy, n=9, cx=0.0, cy=0.0, seg=48):
    """z0..z1 의 상자 마디(양 끝 막음)."""
    rows = [sring(hx, hy, z0, n, seg, cx, cy), sring(hx, hy, z1, n, seg, cx, cy)]
    O.finish(O.mesh_obj(name, rows, True, Vector((cx, cy, z0)), Vector((cx, cy, z1))), HOST, mat, 0)


def rim(name, z, hx, hy, h=0.014, grow=0.006, mat="Brass"):
    """마디 끝 놋쇠 테 — 상자 윤곽보다 살짝 튀어나온 얇은 띠."""
    rows = [sring(hx + grow, hy + grow, z - h / 2), sring(hx + grow, hy + grow, z + h / 2)]
    O.finish(O.mesh_obj(name, rows, True, Vector((0, 0, z - h / 2)), Vector((0, 0, z + h / 2))), HOST, mat, 0)


# 면: (바깥 법선, 면 위 가로 방향) — 0 바깥(-x) · 1 앞(-y) · 2 몸쪽(+x) · 3 뒤(+y)
FACES = [((-1, 0), (0, 1)), ((0, -1), (1, 0)), ((1, 0), (0, -1)), ((0, 1), (-1, 0))]


def fp(face, u, z, hx, hy, off=0.004):
    (nx, ny), (tx, ty) = FACES[face]
    h = hx if face in (0, 2) else hy
    return Vector((nx * (h + off) + tx * u, ny * (h + off) + ty * u, z))


def half_t(face, hx, hy):
    return hy if face in (0, 2) else hx


def border(name, mat, face, z0, z1, hx, hy, inset=0.085, off=0.004, r=0.0055):
    """면에 얕게 두른 직사각 테두리 선(놋쇠)."""
    w = half_t(face, hx, hy) - inset
    za, zb = z0 + inset * 0.7, z1 - inset * 0.7
    if zb - za < 0.06:
        return
    pts = []
    for (u0, z_0), (u1, z_1) in (((-w, za), (w, za)), ((w, za), (w, zb)), ((w, zb), (-w, zb)), ((-w, zb), (-w, za))):
        for f in O.lin(0.0, 1.0, 5)[:-1]:
            pts.append(fp(face, u0 + (u1 - u0) * f, z_0 + (z_1 - z_0) * f, hx, hy, off))
    pts.append(pts[0])
    O.add_tube(name, HOST, mat, pts, r, 4, 0, round_start=False)


def vine(name, mat, face, z0, z1, hx, hy, amp, phase=0.0, waves=1.5, off=0.004, r=0.0042):
    """면 위를 물결 치며 흐르는 가는 덩굴선(세공)."""
    pts = []
    for i in range(18):
        t = i / 17
        u = amp * math.sin(t * PI * 2 * waves + phase) * (0.35 + 0.65 * math.sin(PI * t))
        pts.append(fp(face, u, z0 + (z1 - z0) * (0.06 + 0.88 * t), hx, hy, off))
    O.add_tube(name, HOST, mat, pts, r, 4, 0, round_start=False)


def star_on(name, mat, face, u, z, hx, hy, size, off=0.003):
    """면에 붙은 네 갈래 별 문양(돋을새김)."""
    c = fp(face, u, z, hx, hy, off)
    (nx, ny), _ = FACES[face]
    M = Matrix.Translation(c) @ O.orient((nx, ny, 0))
    pts, top = [], []
    for k in range(8):
        rr = size * (1.0 if k % 2 == 0 else 0.3)
        ang = k * PI / 4
        pts.append(M @ Vector((rr * math.cos(ang), rr * math.sin(ang), 0.0)))
        top.append(M @ Vector((rr * 0.55 * math.cos(ang), rr * 0.55 * math.sin(ang), 0.012)))
    O.finish(O.mesh_obj(name, [pts, top], True, M @ Vector((0, 0, -0.003)), M @ Vector((0, 0, 0.016))), HOST, mat, 0)


def gem(name, c, r, normal):
    M = Matrix.Translation(c) @ O.orient(normal)
    O.add_lathe(name, HOST, "Glow", [(0.0, -r * 0.2)] + [(r * math.cos(a), r * math.sin(a) * 0.8) for a in (0.0, 0.5, 0.95, 1.3)] + [(0.0, r * 0.9)], 10, M, 0)
    O.add_lathe(name + "Set", HOST, "Brass", [(r * 1.6, -0.01), (r * 1.65, 0.006), (r * 1.15, 0.016), (r * 0.9, 0.008)], 10, M, 0)


def wing(name, k):
    """어깨 윗면 날개판: 앞쪽에서 뒤(+y)로 휘며 좁아지는 얇은 잎 — 상자 윤곽 안, 윗면에서 0.05 안으로만 솟는다."""
    rows = []
    n = 10
    for i in range(n):
        s = i / (n - 1)
        y = -0.34 + 0.76 * s
        xc = -0.2 + 0.2 * k - 0.1 * s * (k - 1) + 0.06 * math.sin(s * PI)
        w = max(0.012, (0.15 - 0.02 * k) * math.sin(PI * min(max(s, 0), 1) ** 0.7) ** 0.6)
        z = 1.008 + 0.014 * k + 0.018 * s
        rows.append([Vector((xc + w * (j / 4 * 2 - 1), y, z + 0.016 * (1 - (j / 4 * 2 - 1) ** 2))) for j in range(5)])
    O.finish(O.mesh_obj(name, rows), HOST, "Gold", 0, solid=0.012, offset=-1.0)
    left = [Vector((r[0].x, r[0].y, r[0].z + 0.004)) for r in rows]
    right = [Vector((r[4].x, r[4].y, r[4].z + 0.004)) for r in reversed(rows)]
    O.add_tube(name + "Rim", HOST, "Brass", left + right, 0.0055, 4, 0, round_start=False)


# 마디(위→아래): (이름, z0, z1, 반폭) — 마디 사이 0.015 틈에 검은 심이 비친다
PLATES = [("Shoulder", 0.70, 1.0, 0.5), ("Upper", 0.23, 0.685, 0.495), ("Fore", -0.55, 0.155, 0.495)]


def build():
    # 검은 심(마디 틈으로 가늘게만 비친다)
    slab("Core", "BluedSteel", -0.99, 0.96, 0.478, 0.478, 9)
    # ── 판 마디 ──
    for name, z0, z1, h in PLATES:
        slab(name, "Gold", z0, z1, h, h)
        rim(name + "RimTop", z1 - 0.007, h, h)
        rim(name + "RimBot", z0 + 0.007, h, h)
        for face in range(4):
            if face in (0, 1):
                border(name + "Border", "Brass", face, z0, z1, h, h)
        star_on(name + "Star", "Brass", 0, 0.0, (z0 + z1) / 2, h, h, 0.045)
        # B안 전용 짙은 세공: 모든 면의 덩굴선 + 안쪽 겹 테두리 + 모서리 작은 별
        for face in range(4):
            vine(name + "VineA", "DetailB", face, z0, z1, h, h, 0.13, 0.0)
            vine(name + "VineB", "DetailB", face, z0, z1, h, h, 0.13, PI)
            border(name + "BorderIn", "DetailB", face, z0, z1, h, h, inset=0.15, r=0.004)
            if face not in (0,):
                star_on(name + "StarB", "DetailB", face, 0.0, (z0 + z1) / 2, h, h, 0.04)
        star_on(name + "StarB0", "DetailB", 0, 0.0, z0 + 0.09, h, h, 0.028)
        star_on(name + "StarB1", "DetailB", 0, 0.0, z1 - 0.09, h, h, 0.028)
    # 어깨 날개판 셋
    for k in range(3):
        wing("Wing%d" % k, k)
    # ── 팔꿈치 이음: 좁은 금 고리 + 가는 어두운 홈 + 작은 별 보석 하나 ──
    slab("ElbowRing", "Gold", 0.175, 0.212, 0.468, 0.468, 9)
    rim("ElbowRimT", 0.21, 0.468, 0.468, 0.01, 0.004)
    rim("ElbowRimB", 0.177, 0.468, 0.468, 0.01, 0.004)
    gem("ElbowGem", Vector((-0.468, 0, 0.1935)), 0.04, (-1, 0, 0))
    # ── 손목 고리 ──
    slab("WristRing", "Gold", -0.595, -0.565, 0.47, 0.47, 9)
    rim("WristRimT", -0.567, 0.47, 0.47, 0.01, 0.004)
    rim("WristRimB", -0.593, 0.47, 0.47, 0.01, 0.004)
    # ── 손: 상자 바닥 0.4(−1.0 ~ −0.6) — 앞면 손가락 마디 판 넷 + 옆면 엄지 + 바닥 중앙 칼 구멍 고리 ──
    HZ0, HZ1, HW = -1.0, -0.61, 0.49
    slab("Hand", "Gold", HZ0, HZ1, HW, HW, 8)
    rim("HandRimT", HZ1 - 0.007, HW, HW)
    rim("HandRimB", HZ0 + 0.007, HW, HW)
    # 손가락: 앞(-y)면에 길쭉한 마디 판 셋씩(짧은 손가락 표현) — 사이 홈은 검은 금속
    cuts = [HZ1 - 0.035, -0.74, -0.85, HZ0 + 0.03]
    for fi, cxp in enumerate((-0.3, -0.1, 0.1, 0.3)):
        for ph in range(3):
            a, b = cuts[ph] - (0.0 if ph == 0 else 0.007), cuts[ph + 1] + 0.007
            slab("Finger%d_%d" % (fi, ph), "Gold", b, a, 0.088, 0.011, 7, cx=cxp, cy=-HW - 0.004, seg=24)
        for g in (1, 2):
            slab("Groove%d_%d" % (fi, g), "BluedSteel", cuts[g] - 0.008, cuts[g] + 0.008, 0.086, 0.0125, 7, cx=cxp, cy=-HW - 0.004, seg=24)
        if fi in (1, 2):
            star_on("HandStar%d" % fi, "DetailB", 1, cxp, HZ1 + 0.0, HW, HW, 0.02, off=0.016)
    # 엄지: 몸쪽(+x)면의 마디 판 둘
    for ph, (a, b) in enumerate(((HZ1 - 0.03, -0.77), (-0.78, HZ0 + 0.14))):
        slab("Thumb%d" % ph, "Gold", b, a, 0.011, 0.1, 7, cx=HW + 0.004, cy=-0.12, seg=24)
    slab("ThumbGroove", "BluedSteel", -0.784, -0.766, 0.0125, 0.098, 7, cx=HW + 0.004, cy=-0.12, seg=24)
    for face in (0, 2, 3):
        border("HandBorder", "Brass", face, HZ0, HZ1, HW, HW, inset=0.09)
    # 바닥 중앙: 칼 슴베가 나오는 놋쇠 고리(타원)
    ring = []
    for k in range(24):
        a = 2 * PI * k / 24
        ring.append(Vector((0.105 * math.cos(a), 0.205 * math.sin(a), HZ0 - 0.012)))
    ring.append(ring[0])
    O.add_tube("BladeSocket", HOST, "Brass", ring, 0.02, 6, 0, round_start=False)
    for sx in (-1, 1):   # 슬롯 양쪽 별빛 점
        gem("SocketGem", Vector((sx * 0.3, 0, HZ0 - 0.004)), 0.022, (0, 0, -1))


def plain(name, color, rough, metal=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def smooth_materials():
    O.MATERIALS["Gold"] = plain("Gold", (0.95, 0.70, 0.26), 0.16)
    O.MATERIALS["Brass"] = plain("Brass", (0.66, 0.46, 0.17), 0.28)
    O.MATERIALS["DetailB"] = plain("DetailB", (0.66, 0.46, 0.17), 0.28)
    O.MATERIALS["BluedSteel"] = plain("BluedSteel", (0.05, 0.055, 0.075), 0.32)
    O.MATERIALS["Steel"] = plain("Steel", (0.85, 0.87, 0.9), 0.18)
    for k in ("Gold", "Brass", "DetailB", "BluedSteel", "Steel"):
        O.MATS[k] = (None, 6.0)


def blade_for_render():
    saved = dict(O.PIECES)
    O.PIECES.clear()
    parts = O.build_blade()
    M = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, -1), (0, 0, 0, 1)))
    out = []
    for key, mat in (("Blade", "Steel"), ("Fuller", "BluedSteel"), ("Collar", "Gold"), ("Edge", "Glow")):
        objs = parts[key] if isinstance(parts[key], list) else [parts[key]]
        for ob in objs:
            ob.data.transform(M)
        out.append(O.dress(O.join(objs, "RB_" + key), mat, 30))
    O.PIECES.update(saved)
    return out


def r6_figure():
    """R6 몸통·머리·왼팔·다리 상자(비교 렌더 전용): 의수 팔 가운데가 원점, 몸통은 몸쪽(+x)에 놓인다."""
    skin = plain("Skin", (0.96, 0.82, 0.74), 0.6, 0.0)
    cloth = plain("Cloth", (0.18, 0.12, 0.09), 0.8, 0.0)
    pants = plain("Pants", (0.05, 0.05, 0.06), 0.8, 0.0)
    out = []
    for (cx, cy, cz), size, m in (((1.5, 0, 0), (2, 1, 2), cloth), ((1.5, 0, 1.5), (1.25, 1.25, 1.0), skin), ((3.0, 0, 0), (1, 1, 2), cloth),
                                  ((1.0, 0, -2), (1, 1, 2), pants), ((2.0, 0, -2), (1, 1, 2), pants)):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy, cz))
        ob = bpy.context.active_object
        ob.scale = size
        ob.data.materials.append(m)
        out.append(ob)
    return out


def render(tagB=False, show=("Core",)):
    scene = bpy.context.scene
    for ob in list(bpy.data.objects):
        if ob.name.split(".")[0] in ("Key", "Fill", "Rim", "Top", "Cam"):
            bpy.data.objects.remove(ob, do_unlink=True)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 760, 1000
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.23, 0.30, 1)

    def softbox(nm, loc, e, size, color):
        ld = bpy.data.lights.new(nm, "AREA")
        ld.energy, ld.size, ld.color = e, size, color
        lo = bpy.data.objects.new(nm, ld)
        lo.location = loc
        lo.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        O.scol().objects.link(lo)
    softbox("Key", (-4.5, -5.5, 4.5), 900, 3.5, (1.0, 0.93, 0.82))
    softbox("Fill", (6, -3, 0.5), 260, 5.0, (0.7, 0.8, 1.0))
    softbox("Rim", (2, 6, 4), 650, 2.5, (1.0, 0.97, 0.92))
    softbox("Top", (0, -1, 7), 500, 5.0, (1.0, 1.0, 1.0))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 85
    O.scol().objects.link(cam)
    scene.camera = cam
    out = os.path.join(ROOT, "art", "callisto")
    os.makedirs(out, exist_ok=True)
    sfx = "_B" if tagB else ""

    def shot(tag, d, dist, aim, lens=85, size=(760, 1000)):
        scene.render.resolution_x, scene.render.resolution_y = size
        cam.data.lens = lens
        d = Vector(d).normalized()
        cam.location = aim + d * dist
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out, "prosthetic_%s%s.png" % (tag, sfx))
        bpy.ops.render.render(write_still=True)
    mid = Vector((0, 0, 0.0))
    shot("front", (0.0, -1.0, 0.06), 9.0, mid)
    shot("side", (-1.0, 0.0, 0.06), 9.0, mid)
    shot("q34", (-0.75, -0.7, 0.28), 9.0, mid)
    blade = blade_for_render()
    shot("blade", (-0.7, -0.75, 0.2), 14.5, Vector((0, 0, -1.0)), 85, (760, 1100))
    fig = r6_figure()
    shot("r6compare", (-0.35, -1.0, 0.12), 17.0, Vector((1.5, 0, -0.4)), 60, (1000, 900))
    for ob in blade + fig:
        bpy.data.objects.remove(ob, do_unlink=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    O.make_textures()
    O.make_materials()
    smooth_materials()
    build()
    objs, total, totalA = [], 0, 0
    for (host, mat), parts in sorted(O.PIECES.items()):
        ob = O.dress(O.join(parts, "%s_%s" % (host, mat)), mat, 40)
        n = O.tris(ob)
        assert n <= 20000, (ob.name, n)
        total += n
        if mat != "DetailB":
            totalA += n
        print("  %-30s %6d tri" % (ob.name, n))
        objs.append(ob)
    print("CallistoProsthetic: 전체 %d tri (A안 %d · B안 %d) · %d 메시" % (total, totalA, total, len(objs)))
    assert total <= 20000, total
    mk = O.marker("WeaponsOrigin_Marker")
    O.export_glb(objs + [mk], os.path.join(HERE, "CallistoProsthetic.glb"))
    bpy.data.objects.remove(mk, do_unlink=True)
    if RENDER:
        render(False)
        render_variants(objs)


def render_variants(objs):
    """A안(DetailB 숨김)·B안(전부) 렌더 이름 구분: 위 render 는 전부 보인 상태 = B안, 이름 정리."""
    out = os.path.join(ROOT, "art", "callisto")
    for tag in ("front", "side", "q34", "blade", "r6compare"):
        src = os.path.join(out, "prosthetic_%s.png" % tag)
        dst = os.path.join(out, "prosthetic_%s_B.png" % tag)
        if os.path.exists(src):
            os.replace(src, dst)
    for ob in objs:
        if ob.name.endswith("DetailB"):
            ob.hide_render = True
    render(False)


main()
