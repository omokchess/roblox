# -*- coding: utf-8 -*-
"""
build_callisto_prosthetic.py — 칼리스토 오른팔 의수 2판(2026-11-07, QA 반려 뒤 다시). 엘든 링 말레니아의 금빛 의수.

레퍼런스(웹: 반다이남코 PureArts 1:1 "Arm of Malenia" 복제품 · 위키 Malenia · S.H.Figuarts 설명, 그리고 게임 속 모습) 핵심 특징 —
  1. 사람 팔 실루엣: 굵은 덩어리 갑옷이 아니라 날씬하고 길쭉한, 근육 흐름을 따르는 금 의수(어깨 작고 · 위팔 볼륨 · 팔꿈치 잘록 · 아래팔 손목으로 가늘어짐).
  2. 매끈한 광택 금 판들이 비늘처럼 겹쳐 덮고, 판 가장자리에 가는 테, 판 위에 가는 덩굴 모양 세공선.
  3. 손목이 꺾이는 관절 의수 손: 가늘고 긴 마디 손가락이 칼(카타나) 자루를 감아 쥔다 — 칼이 손에서 이어진다.
  4. 어깨는 둥근 돔이 아니라 작게 뒤로 휘어진 날개형 판.
  (※ 위 설명은 웹 검색 결과 요약 + 게임 아트 기억 — 세부 무늬는 칼리스토 별 모티프로 바꿨다.)
반영: 타원 단면 몸통 곡선(위팔 이두 볼륨 → 팔꿈치 잘록 → 손목) 위에 잎 모양 금판을 두 겹 비늘로 겹치고(끝이 손목 쪽으로 뾰족),
  각 판에 놋쇠 테 + 물결 덩굴선, 판 사이엔 검은 금속 속살만 살짝, 어깨는 뒤로 휘는 날개판 셋, 팔꿈치는 판이 겹쳐 덮고 별 보석 하나,
  손은 가는 손가락 넷 + 엄지로 칼 슴베를 감는다. 전체 반폭 ≤ 0.46(R6 팔 반폭 0.5).
묶음(재질): Gold 광택 금(결 없는 매끈한 재질) · Brass 테·덩굴·별 문양 · BluedSteel 이음부 · Glow 별빛(스튜디오에서 Neon).

공간(블렌더): 원점 = 오른팔 가운데, 팔 축 = +z(위, 로블록스 +Y), 바깥(로블록스 +X) = 블렌더 -x, 앞(로블록스 -Z) = -y. 팔 끝 z = -1.
메시 이름 CallistoProsthetic_<묶음> + 원점 표지 WeaponsOrigin_Marker(1×1×1, 팔 가운데)
→ models/CallistoProsthetic.glb → 스튜디오 가져오기 → tools/Callisto_Prosthetic.luau(→ ReplicatedStorage.CallistoAssets.Prosthetic).
돌리기: blender -b -P models/build_callisto_prosthetic.py [-- render]   (렌더 = art/callisto/prosthetic_{front,side,q34,blade}.png)
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
OUT, FRONT, BACK, IN = PI, -PI / 2, PI / 2, 0.0     # 바깥 · 앞 · 뒤 · 몸 쪽(블렌더 각)
ROOT = os.path.abspath(os.path.join(HERE, ".."))

# 몸통 곡선 (z, 반폭 x, 반깊이 y): 어깨 → 이두 볼륨 → 팔꿈치 잘록 → 아래팔 근육 → 손목
PROFILE = [(0.95, 0.18, 0.20), (0.86, 0.24, 0.26), (0.7, 0.30, 0.33), (0.45, 0.33, 0.37), (0.22, 0.29, 0.32),
           (0.05, 0.22, 0.245), (-0.1, 0.235, 0.265), (-0.27, 0.215, 0.24), (-0.42, 0.16, 0.17), (-0.5, 0.15, 0.16)]


def prof(z):
    t = PROFILE
    if z >= t[0][0]:
        return t[0][1], t[0][2]
    for (z1, x1, y1), (z0, x0, y0) in zip(t, t[1:]):
        if z >= z0:
            f = (z - z0) / (z1 - z0)
            f = f * f * (3 - 2 * f)
            return x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
    return t[-1][1], t[-1][2]


def body(z, a, extra=0.0):
    """z 높이 · 각 a 방향의 몸통 겉(타원) + extra 만큼 띄운 점."""
    ax, ay = prof(z)
    r = ax * ay / math.sqrt((ay * math.cos(a)) ** 2 + (ax * math.sin(a)) ** 2)
    return Vector(((r + extra) * math.cos(a), (r + extra) * math.sin(a), z))


def ell(a, z, ax, ay):
    """손의 납작한 타원(칼 슴베 단면 — x 얇게, y(앞뒤) 넓게) 위의 점."""
    return Vector((ax * math.cos(a), ay * math.sin(a), z))


def sph(name, mat, c, r, seg=8):
    prof_ = [(0.0, -r)] + [(r * math.sin(t), -r * math.cos(t)) for t in O.lin(0.4, PI - 0.4, 5)] + [(0.0, r)]
    O.add_lathe(name, HOST, mat, prof_, seg, Matrix.Translation(c), 0)


def gem(name, c, r, normal):
    """별빛 보석: Glow 돔 + 황동 받침."""
    M = Matrix.Translation(c) @ O.orient(normal)
    O.add_lathe(name, HOST, "Glow", [(0.0, -r * 0.2)] + [(r * math.cos(a), r * math.sin(a) * 0.9) for a in (0.0, 0.5, 0.95, 1.3)] + [(0.0, r)], 10, M, 0)
    O.add_lathe(name + "Set", HOST, "Brass", [(r * 1.6, -0.01), (r * 1.65, 0.008), (r * 1.15, 0.022), (r * 0.9, 0.01)], 10, M, 0)


def star_inlay(name, a, z, lift, size):
    """판 위 네 갈래 별 문양(놋쇠 돋을새김) — 접면에 눕는다."""
    c = body(z, a, lift)
    n = Vector((math.cos(a), math.sin(a), 0))
    M = Matrix.Translation(c) @ O.orient(n)
    pts, top = [], []
    for k in range(8):
        rr = size * (1.0 if k % 2 == 0 else 0.3)
        ang = k * PI / 4
        pts.append(M @ Vector((rr * math.cos(ang), rr * math.sin(ang), 0.0)))
        top.append(M @ Vector((rr * 0.55 * math.cos(ang), rr * 0.55 * math.sin(ang), 0.012)))
    O.finish(O.mesh_obj(name, [pts, top], True, M @ Vector((0, 0, -0.004)), M @ Vector((0, 0, 0.016))), HOST, "Brass", 0)


def leaf_shape(t):
    """잎 판 폭(0 위끝 · 1 아래끝): 위는 완만히 넓어지고 아래는 뾰족."""
    t = min(max(t, 0.0), 1.0)
    return math.sin(PI * t ** 0.72) ** 0.62


def leaf(name, c, ztop, zbot, wmax, lift, rim=True, vine=False, rows=9, cols=9, flare=0.02, mat="Gold", sweep=0.0, thick=0.02):
    """몸통 곡선을 따르는 잎 모양 금판. c = 중심각 · wmax = 가장 넓은 곳의 반각 · sweep = 아래로 갈수록 도는 각(휘어진 날개)."""
    zs = O.lin(zbot, ztop, rows)
    grid = []

    def pt(z, u, extra=0.0):
        t = (ztop - z) / (ztop - zbot)
        w = max(wmax * leaf_shape(t), 0.012)
        a = c + sweep * t + (u * 2 - 1) * w
        arch = 0.024 * (1 - (2 * u - 1) ** 2)
        return body(z, a, lift + arch + flare * t ** 3 + extra)
    for z in zs:
        grid.append([pt(z, k / (cols - 1)) for k in range(cols)])
    O.finish(O.mesh_obj(name, grid), HOST, mat, 0, solid=thick, offset=-1.0)
    if rim:   # 가는 놋쇠 테: 한쪽 가장자리 → 뾰족한 끝 → 반대쪽
        left = [pt(z, 0.0, 0.004) for z in O.lin(ztop, zbot, 7)]
        right = [pt(z, 1.0, 0.004) for z in O.lin(zbot, ztop, 7)]
        O.add_tube(name + "Rim", HOST, "Brass", left + right, 0.0065, 4, 0, round_start=False)
    if vine:  # 판 가운데를 따라 흐르는 물결 덩굴선
        pts = []
        for i in range(12):
            t = i / 11
            z = ztop + (zbot - ztop) * (0.08 + 0.84 * t)
            tt = (ztop - z) / (ztop - zbot)
            a = c + sweep * tt + 0.09 * math.sin(t * PI * 3.0) * leaf_shape(tt)
            pts.append(body(z, a, lift + 0.024 + flare * tt ** 3 + 0.004))
        O.add_tube(name + "Vine", HOST, "Brass", pts, 0.0045, 4, 0, round_start=False)


def build():
    # ── 검은 속살(판 사이로 살짝만 비친다): 같은 몸통 곡선보다 얇게 ──
    zs = O.lin(-0.5, 0.9, 26)
    rows = [[body(z, 2 * PI * k / 20, -0.035) for k in range(20)] for z in zs]
    O.finish(O.mesh_obj("Core", rows, True, Vector((0, 0, -0.5)), Vector((0, 0, 0.91))), HOST, "BluedSteel", 0)
    # 손목 이음(검은 고리)
    O.add_lathe("WristDark", HOST, "BluedSteel", [(0.14, -0.5), (0.185, -0.505), (0.185, -0.53), (0.14, -0.535)], 14, Matrix(), 0)

    # ── 어깨: 작은 날개판 셋(바깥 위에서 뒤로 휘어 내려간다) ──
    for i, (c, zt, zb, wm, lf) in enumerate(((OUT + 0.15, 0.95, 0.56, 0.62, 0.012), (OUT + 0.62, 0.93, 0.6, 0.5, 0.032), (OUT + 1.08, 0.9, 0.64, 0.4, 0.052))):
        leaf("Wing%d" % i, c, zt, zb, wm, lf, rim=True, vine=(i == 0), sweep=0.7, flare=0.03, rows=9, cols=9)
    # ── 위팔: 안쪽 겹 여섯(길게) + 바깥 겹 여섯(짧게, 사이에 비늘처럼 겹침) ──
    for i in range(6):
        c = i * PI / 3
        leaf("UpperA%d" % i, c, 0.92, -0.04, 0.52, 0.012, rim=True, vine=True, flare=0.025, rows=11, cols=9)
    for i in range(6):
        c = i * PI / 3 + PI / 6
        leaf("UpperB%d" % i, c, 0.6, 0.1, 0.36, 0.034, rim=(i % 2 == 0), vine=False, flare=0.02, rows=9, cols=7)
    # ── 팔꿈치: 뒤 덮개(판이 겹쳐 덮는다) + 작은 별 보석 하나 ──
    leaf("ElbowCop", BACK, 0.26, -0.2, 0.62, 0.075, rim=True, vine=False, flare=0.03, rows=9, cols=9)
    leaf("ElbowCopLow", BACK, 0.12, -0.22, 0.46, 0.105, rim=False, flare=0.02, rows=7, cols=7)
    gem("ElbowGem", body(0.06, OUT, 0.045), 0.04, (-1, 0, 0))
    # ── 아래팔: 손목으로 모이는 길쭉한 판 여섯 + 바깥 겹 여섯 ──
    for i in range(6):
        c = i * PI / 3 + PI / 6
        leaf("ForeA%d" % i, c, 0.12, -0.47, 0.55, 0.012, rim=True, vine=True, flare=0.02, rows=11, cols=9)
    for i in range(6):
        c = i * PI / 3
        leaf("ForeB%d" % i, c, -0.08, -0.4, 0.4, 0.04, rim=(i % 2 == 1), flare=0.016, rows=9, cols=7)
    star_inlay("StarUpper", OUT, 0.42, 0.06, 0.05)
    star_inlay("StarFore", OUT + PI / 6, -0.22, 0.05, 0.036)
    star_inlay("StarBack", FRONT, 0.4, 0.06, 0.045)

    # ── 손목 소맷부리: 가는 금 나팔 + 황동 테 ──
    cuff = [(0.17, -0.41), (0.2, -0.44), (0.215, -0.485), (0.2, -0.525)]
    rows, _, _ = O.lathe(cuff, 22, Matrix())
    O.finish(O.mesh_obj("Cuff", rows, True), HOST, "Gold", 0, solid=0.014, offset=-1.0)
    O.add_lathe("CuffTrim", HOST, "Brass", [(0.2, -0.522), (0.212, -0.528), (0.212, -0.538), (0.19, -0.54)], 22, Matrix(), 0)

    # ── 손: 칼 슴베(납작 타원)를 가는 손가락으로 감아 쥔 손 ──
    ZF = [-0.585 - 0.071 * i for i in range(4)]
    rows = [[ell(2 * PI * k / 16, zz, 0.034, 0.146) for k in range(16)] for zz in O.lin(-0.5, -0.93, 5)]
    O.finish(O.mesh_obj("Hilt", rows, True, Vector((0, 0, -0.5)), Vector((0, 0, -0.93))), HOST, "BluedSteel", 0)
    # 손등판(앞): 손목에서 손가락 뿌리로 뾰족하게 퍼지는 금판
    rows = []
    for zz in O.lin(-0.545, -0.86, 8):
        t = (-0.545 - zz) / 0.315
        ang = 0.95 * (0.35 + 0.65 * math.sin(PI * min(t * 0.9, 1.0) ** 0.8)) if t < 1 else 0.2
        rows.append([ell(FRONT - ang + 2 * ang * k / 8, zz, 0.095 + 0.05 + 0.02 * (1 - abs(k / 4 - 1)), 0.205 + 0.05 + 0.02 * (1 - abs(k / 4 - 1))) for k in range(9)])
    O.finish(O.mesh_obj("Dorsal", rows), HOST, "Gold", 0, solid=0.018, offset=-1.0)
    gem("DorsalGem", ell(FRONT, -0.575, 0.15, 0.27), 0.022, (0, -1, 0))
    # 가는 손가락 넷: 마디 셋(금 관) + 이음 구 — 손등판 한쪽 끝에서 슴베 뒤를 돌아 반대쪽 끝까지
    a_start = FRONT + 0.95
    for fi, zz in enumerate(ZF):
        ax, ay = 0.098 + 0.004 * fi, 0.21 - 0.003 * fi
        bounds = [a_start + (PI * 2 - 1.9 + 0.1) * k / 3 for k in range(4)]
        for k in range(3):
            pts = [ell(bounds[k] + (bounds[k + 1] - bounds[k]) * f, zz - 0.003 * (k + f), ax, ay) for f in O.lin(0.0, 1.0, 6)]
            base = 0.029 - 0.002 * k
            O.add_tube("Phalanx", HOST, "Gold", pts, lambda t, base=base: base * (1.0 - 0.18 * t), 8, 0, round_start=False)
            sph("FingerJoint", "BluedSteel", ell(bounds[k], zz - 0.003 * k, ax, ay), 0.0275, 6)
        sph("FingerTip", "Brass", ell(bounds[3], zz - 0.009, ax, ay), 0.024, 6)
    # 엄지: 손등판 안쪽에서 손가락 위로 가로질러 슴베를 누른다
    tz = -0.535
    for k in range(2):
        a0 = FRONT - 0.95 - 1.1 * k
        a1 = FRONT - 0.95 - 1.1 * (k + 1)
        pts = [ell(a0 + (a1 - a0) * f, tz - 0.008 * (k + f), 0.125, 0.235) for f in O.lin(0.0, 1.0, 6)]
        O.add_tube("Thumb", HOST, "Gold", pts, lambda t, k=k: (0.034 - 0.005 * k) * (1.0 - 0.15 * t), 8, 0, round_start=False)
        sph("ThumbJoint", "BluedSteel", ell(a0, tz - 0.008 * k, 0.125, 0.235), 0.033, 6)
    sph("ThumbTip", "Brass", ell(FRONT - 0.95 - 2.2, tz - 0.018, 0.125, 0.235), 0.026, 6)


def plain(name, color, rough, metal=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def smooth_materials():
    """결 텍스처 없는 매끈한 광택 재질로 갈아 끼운다(반려 사유: 긁힌 노이즈 결)."""
    O.MATERIALS["Gold"] = plain("Gold", (0.95, 0.70, 0.26), 0.16)
    O.MATERIALS["Brass"] = plain("Brass", (0.66, 0.46, 0.17), 0.28)
    O.MATERIALS["BluedSteel"] = plain("BluedSteel", (0.05, 0.055, 0.075), 0.32)
    O.MATERIALS["Steel"] = plain("Steel", (0.85, 0.87, 0.9), 0.18)
    for k in ("Gold", "Brass", "BluedSteel", "Steel"):
        O.MATS[k] = (None, 6.0)   # UV 한 칸 = 6 스터드 → 텍스처 없는 재질이라 의미 없음


def blade_for_render():
    """무기 공간 칼(CallistoArms Main)을 팔 공간에 맞춰 놓는다(렌더 전용 — 내보내지 않는다)."""
    saved = dict(O.PIECES)
    O.PIECES.clear()
    parts = O.build_blade()
    M = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, -1), (0, 0, 0, 1)))
    out = []
    for key, mat in (("Blade", "Steel"), ("Fuller", "BluedSteel"), ("Collar", "Gold"), ("Edge", "Glow")):
        objs = parts[key] if isinstance(parts[key], list) else [parts[key]]
        for ob in objs:
            ob.data.transform(M)
        ob = O.dress(O.join(objs, "RB_" + key), mat, 30)
        out.append(ob)
    O.PIECES.update(saved)
    return out


def render():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 760, 1000
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes["Background"].inputs[0].default_value = (0.20, 0.23, 0.30, 1)
    nt.nodes["Background"].inputs[1].default_value = 1.0

    def softbox(nm, loc, e, size, color=(1, 1, 1)):
        ld = bpy.data.lights.new(nm, "AREA")
        ld.energy, ld.size, ld.color = e, size, color
        lo = bpy.data.objects.new(nm, ld)
        lo.location = loc
        lo.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        O.scol().objects.link(lo)
    # 3점 조명: 따뜻한 키(앞 왼쪽 위) · 푸른 채움(오른쪽 낮게) · 뒤 림(뒤 위)
    softbox("Key", (-4.5, -5.5, 4.5), 900, 3.5, (1.0, 0.93, 0.82))
    softbox("Fill", (6, -3, 0.5), 260, 5.0, (0.7, 0.8, 1.0))
    softbox("Rim", (2, 6, 4), 650, 2.5, (1.0, 0.97, 0.92))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 85
    O.scol().objects.link(cam)
    scene.camera = cam
    out = os.path.join(ROOT, "art", "callisto")
    os.makedirs(out, exist_ok=True)
    mid = Vector((0, 0, 0.18))
    for tag, d, dist, aim in (("front", (0.0, -1.0, 0.06), 8.2, mid), ("side", (-1.0, 0.0, 0.06), 8.2, mid),
                              ("q34", (-0.75, -0.7, 0.28), 8.2, mid)):
        d = Vector(d).normalized()
        cam.location = aim + d * dist
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out, "prosthetic_%s.png" % tag)
        bpy.ops.render.render(write_still=True)
    # 칼 날 포함(아래로 이어지는 전체) — 위에서 비스듬히
    blade = blade_for_render()
    scene.render.resolution_x, scene.render.resolution_y = 760, 1100
    d = Vector((-0.7, -0.75, 0.2)).normalized()
    aim = Vector((0, 0, -0.9))
    cam.location = aim + d * 13.5
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(out, "prosthetic_blade.png")
    bpy.ops.render.render(write_still=True)
    for ob in blade:
        bpy.data.objects.remove(ob, do_unlink=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    O.make_textures()
    O.make_materials()
    smooth_materials()
    build()
    objs, total = [], 0
    for (host, mat), parts in sorted(O.PIECES.items()):
        ob = O.dress(O.join(parts, "%s_%s" % (host, mat)), mat, 40)
        n = O.tris(ob)
        assert n <= 20000, (ob.name, n)
        total += n
        print("  %-30s %6d tri" % (ob.name, n))
        objs.append(ob)
    print("CallistoProsthetic: %d tri · %d 메시" % (total, len(objs)))
    assert total <= 20000, total
    mk = O.marker("WeaponsOrigin_Marker")
    O.export_glb(objs + [mk], os.path.join(HERE, "CallistoProsthetic.glb"))
    bpy.data.objects.remove(mk, do_unlink=True)   # 렌더에 표지 상자가 비치지 않게
    if RENDER:
        render()


main()
