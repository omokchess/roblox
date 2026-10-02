# -*- coding: utf-8 -*-
"""
preview_motion.py — 전투 모션을 블렌더로 찍어 본다(R6 상자 몸 + 무기). (2026-09-28)

Studio 화면을 못 볼 때도 자세를 확인하려고 만들었다. 게임과 같은 계산을 한다:
  - 관절: R6 표준 C0/C1, Transform = C0회전⁻¹ · R · C0회전 (CombatRig), R = fromOrientation(x,y,z) = Ry·Rx·Rz
  - Root: Torso 관절에 CFrame(자리) · fromOrientation(회전) 을 앞에 곱함
  - 무기: 팔 끝 (0,-1,0) 에서 X -90° 로 붙이고, W/O 변환을 곱함
  - 보간·곡선: MotionMath 와 같은 규칙(키 이어받기, 들어오는 곡선)
한 모션을 시각 n 개로 나눠 왼쪽→오른쪽으로 늘어놓아 한 장에 찍는다.

돌리는 법:
  lune run tools/combat/export_motions.luau
  blender -b -P tools/combat/preview_motion.py -- <묶음> <모션|all> [장수] [무기 Id]
  → tools/combat/out/<묶음>_<모션>.png
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
PI = math.pi

# ── 로블록스 CFrame(회전 3x3 + 자리) ─────────────────────────


def mat(rows):
    return Matrix(rows)


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return mat(((1, 0, 0), (0, c, -s), (0, s, c)))


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return mat(((c, 0, s), (0, 1, 0), (-s, 0, c)))


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return mat(((c, -s, 0), (s, c, 0), (0, 0, 1)))


class CF:
    def __init__(self, R=None, p=None):
        self.R = R if R is not None else Matrix.Identity(3)
        self.p = p if p is not None else Vector((0, 0, 0))

    def __mul__(self, o):
        return CF(self.R @ o.R, self.R @ o.p + self.p)

    def inv(self):
        Rt = self.R.transposed()
        return CF(Rt, -(Rt @ self.p))

    def rot(self):
        return CF(self.R.copy(), Vector((0, 0, 0)))


def cfp(x, y, z):
    return CF(None, Vector((x, y, z)))


def orient(x, y, z):  # fromOrientation(도) = Ry·Rx·Rz
    return CF(ry(math.radians(y)) @ rx(math.radians(x)) @ rz(math.radians(z)))


def angles(x, y, z):  # CFrame.Angles(도) = Rx·Ry·Rz
    return CF(rx(math.radians(x)) @ ry(math.radians(y)) @ rz(math.radians(z)))


def cfm(p, rows):
    return CF(mat(rows), Vector(p))


# R6 표준 관절(로블록스 값 그대로)
RJ = ((-1, 0, 0), (0, 0, 1), (0, 1, 0))
RS = ((0, 0, 1), (0, 1, 0), (-1, 0, 0))
LS = ((0, 0, -1), (0, 1, 0), (1, 0, 0))
JOINTS = {
    "Torso": ("HRP", cfm((0, 0, 0), RJ), cfm((0, 0, 0), RJ)),
    "Head": ("Torso", cfm((0, 1, 0), RJ), cfm((0, -0.5, 0), RJ)),
    "RArm": ("Torso", cfm((1, 0.5, 0), RS), cfm((-0.5, 0.5, 0), RS)),
    "LArm": ("Torso", cfm((-1, 0.5, 0), LS), cfm((0.5, 0.5, 0), LS)),
    "RLeg": ("Torso", cfm((1, -1, 0), RS), cfm((0.5, 1, 0), RS)),
    "LLeg": ("Torso", cfm((-1, -1, 0), LS), cfm((-0.5, 1, 0), LS)),
}
SIZES = {"Torso": (2, 2, 1), "Head": (1.25, 1.2, 1.2), "RArm": (1, 2, 1), "LArm": (1, 2, 1), "RLeg": (1, 2, 1), "LLeg": (1, 2, 1)}
COLORS = {"Torso": (52, 92, 170), "Head": (245, 205, 150), "RArm": (245, 205, 150), "LArm": (230, 190, 140), "RLeg": (40, 44, 60), "LLeg": (56, 60, 78)}
ORDER = ["Torso", "Head", "RArm", "LArm", "RLeg", "LLeg"]

# ── MotionMath 와 같은 곡선·보간 ─────────────────────────


def _bounce(x):
    n1, d1 = 7.5625, 2.75
    if x < 1 / d1:
        return n1 * x * x
    if x < 2 / d1:
        x -= 1.5 / d1
        return n1 * x * x + 0.75
    if x < 2.5 / d1:
        x -= 2.25 / d1
        return n1 * x * x + 0.9375
    x -= 2.625 / d1
    return n1 * x * x + 0.984375


def _elastic(x):
    if x <= 0 or x >= 1:
        return x
    return 2 ** (-10 * x) * math.sin((x * 10 - 0.75) * (2 * PI) / 3) + 1


EASE = {
    "linear": lambda x: x,
    "sineIn": lambda x: 1 - math.cos(x * PI / 2), "sineOut": lambda x: math.sin(x * PI / 2),
    "sineInOut": lambda x: -(math.cos(PI * x) - 1) / 2,
    "quadIn": lambda x: x * x, "quadOut": lambda x: 1 - (1 - x) ** 2,
    "quadInOut": lambda x: 2 * x * x if x < 0.5 else 1 - (-2 * x + 2) ** 2 / 2,
    "cubicIn": lambda x: x ** 3, "cubicOut": lambda x: 1 - (1 - x) ** 3,
    "cubicInOut": lambda x: 4 * x ** 3 if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2,
    "quartOut": lambda x: 1 - (1 - x) ** 4, "quartIn": lambda x: x ** 4,
    "expoOut": lambda x: 1 if x >= 1 else 1 - 2 ** (-10 * x), "expoIn": lambda x: 0 if x <= 0 else 2 ** (10 * x - 10),
    "backOut": lambda x: 1 + 2.70158 * (x - 1) ** 3 + 1.70158 * (x - 1) ** 2,
    "backIn": lambda x: 2.70158 * x ** 3 - 1.70158 * x * x,
    "backInOut": lambda x: ((2 * x) ** 2 * (3.5949095 * 2 * x - 2.5949095)) / 2 if x < 0.5 else ((2 * x - 2) ** 2 * (3.5949095 * (x * 2 - 2) + 2.5949095) + 2) / 2,
    "elasticOut": _elastic, "bounceOut": _bounce, "step": lambda x: 1 if x >= 1 else 0,
}
J3 = ["Torso", "Head", "RArm", "LArm", "RElbow", "LElbow", "RLeg", "LLeg", "RKnee", "LKnee"]
J6 = ["Root", "W", "O"]


def compile_motion(m):
    keys = sorted(m.get("Keys", []), key=lambda k: k.get("t", 0))
    prev = {n: [0, 0, 0] for n in J3}
    prev.update({n: [0] * 6 for n in J6})
    out = []
    for k in keys:
        pose = {}
        for n in J3 + J6:
            v = k.get(n)
            size = 3 if n in J3 else 6
            pose[n] = [(v[i] if i < len(v) else 0) for i in range(size)] if v else prev[n]
        prev = pose
        out.append((k.get("t", 0), k.get("e"), pose))
    if not out:
        out = [(0, None, prev)]
    loop = m.get("Loop", False)
    if loop and m.get("Smooth") and len(out) > 1:
        loop = "smooth"
    return out, m.get("Duration", out[-1][0]), loop


def _qax(i, deg):
    h = math.radians(deg) / 2
    q = [0.0, 0.0, 0.0, math.cos(h)]
    q[i] = math.sin(h)
    return q


def _qmul(a, b):
    return [a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
            a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
            a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3],
            a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2]]


def slerp_weapon(a, b, alpha):
    """MotionMath.slerpWeapon 과 같다(무기 회전은 최단 호, 한 값이라도 180° 넘게 바뀌면 오일러 그대로)"""
    if alpha <= 0:
        return a
    if alpha >= 1:
        return b
    if any(abs(b[i] - a[i]) > 180 for i in (3, 4, 5)):
        return [a[j] + (b[j] - a[j]) * alpha for j in range(6)]
    qa = _qmul(_qmul(_qax(0, a[3]), _qax(1, a[4])), _qax(2, a[5]))
    qb = _qmul(_qmul(_qax(0, b[3]), _qax(1, b[4])), _qax(2, b[5]))
    dot = sum(x * y for x, y in zip(qa, qb))
    if dot < 0:
        dot, qb = -dot, [-v for v in qb]
    if dot > 0.9995:
        wa, wb = 1 - alpha, alpha
    else:
        th = math.acos(max(-1, min(1, dot)))
        sn = math.sin(th)
        wa, wb = math.sin((1 - alpha) * th) / sn, math.sin(alpha * th) / sn
    q = [x * wa + y * wb for x, y in zip(qa, qb)]
    n = math.sqrt(sum(v * v for v in q))
    x, y, z, w = [v / n for v in q]
    ref = [a[i + 3] + (b[i + 3] - a[i + 3]) * alpha for i in range(3)]
    r02 = 2 * (x * z + y * w)
    if abs(r02) > 0.99999:
        sm = math.degrees(math.atan2(2 * (x * y + z * w), 1 - 2 * (x * x + z * z)))
        c = ref[2]
        e = [sm - c, 90, c] if r02 > 0 else [c - sm, -90, c]
    else:
        e = [math.degrees(math.atan2(-2 * (y * z - x * w), 1 - 2 * (x * x + y * y))),
             math.degrees(math.asin(r02)),
             math.degrees(math.atan2(-2 * (x * y - z * w), 1 - 2 * (y * y + z * z)))]
    r = [a[j] + (b[j] - a[j]) * alpha for j in range(3)]
    for i in range(3):
        r.append(e[i] + 360 * round((ref[i] - e[i]) / 360))
    return r


def pick(s, name):
    """모션 이름: Idle · Skills.<Id> · Fidgets.<번호(1부터)>"""
    if name.startswith("Skills."):
        return s["Skills"][name[7:]]
    if name.startswith("Fidgets."):
        # 버릇은 적힌 관절만 덮는다 — 미리보기에선 기본 자세(Stance) 위에 얹어 보인다
        f = s["Fidgets"][int(name[8:]) - 1]
        base = s.get("Stance") or {}
        return dict(f, Keys=[dict(base, **k) for k in f["Keys"]])
    return s[name]


def smooth_sample(keys, dur, t):
    """MotionMath.smoothSample 과 같다(주기 캣멀-롬, 키에서 멈추지 않는 되풀이)"""
    n = len(keys)

    def at(i):
        k = keys[(i - 1) % n]
        return k[2], k[0] + ((i - 1) // n) * dur

    i = n
    for j in range(1, n + 1):
        if t < keys[j - 1][0]:
            i = j - 1
            break
    p0, t0 = at(i - 1)
    p1, t1 = at(i)
    p2, t2 = at(i + 1)
    p3, t3 = at(i + 2)
    span = max(1e-4, t2 - t1)
    s = (t - t1) / span
    h00, h10, h01, h11 = 2 * s ** 3 - 3 * s * s + 1, s ** 3 - 2 * s * s + s, -2 * s ** 3 + 3 * s * s, s ** 3 - s * s
    k1, k2 = span / max(1e-4, t2 - t0), span / max(1e-4, t3 - t1)
    return {n_: [h00 * a + h10 * (b - q0) * k1 + h01 * b + h11 * (q3 - a) * k2
                 for a, b, q0, q3 in zip(p1[n_], p2[n_], p0[n_], p3[n_])] for n_ in p1}


def sample(comp, t):
    keys, dur, loop = comp
    if loop and dur > 0:
        t = t % dur
    if loop == "smooth":
        return smooth_sample(keys, dur, t)
    if t <= keys[0][0]:
        return keys[0][2]
    for i in range(1, len(keys)):
        tb, eb, pb = keys[i]
        if t <= tb:
            ta, _, pa = keys[i - 1]
            a = EASE.get(eb or "sineInOut", EASE["sineInOut"])((t - ta) / max(1e-4, tb - ta))
            out = {n: [pa[n][j] + (pb[n][j] - pa[n][j]) * a for j in range(len(pa[n]))] for n in pa}
            for n in ("W", "O"):
                out[n] = slerp_weapon(pa[n], pb[n], a)
            return out
    return keys[-1][2]


# ── 자세 → 부품 월드 CFrame ─────────────────────────


def solve(pose):
    """CombatRig.Apply(R6) 와 같다: Root = 몸 전체, Torso = 허리(몸통 아래 가운데)에서 굽힘,
    다리 = 골반(Root) 기준이라 몸통 굽힘을 되돌려 준다."""
    world = {"HRP": CF()}
    rt = orient(*pose.get("Torso", [0, 0, 0]))
    r = pose.get("Root", [0] * 6)
    rootcf = cfp(r[0], r[1], r[2]) * orient(r[3], r[4], r[5])
    for name in ORDER:
        parent, C0, C1 = JOINTS[name]
        v = pose.get(name, [0, 0, 0])
        if name == "Torso":
            R = rootcf * cfp(0, -1, 0) * rt * cfp(0, 1, 0)
        elif name in ("RLeg", "LLeg"):
            R = rt.inv() * orient(*v)
        else:
            R = orient(*v)
        conj = C0.rot()
        T = conj.inv() * R * conj
        world[name] = world[parent] * C0 * T * C1.inv()
    return world


def weapon_cf(world, hand, w):
    arm = world["RArm" if hand == "Right" else "LArm"]
    grip = cfp(0, -1, 0) * angles(-90, 0, 0)
    # 무기 회전은 CFrame.Angles 순서(숙임 X · 날 비틀기 Y · 기울기 Z) — CombatRig 와 같다
    # 회전 먼저, 그다음 무기 자기 축으로 밀기(y- = 길이 방향으로 손 쪽으로 당김)
    return arm * grip * angles(w[3], w[4], w[5]) * cfp(w[0], w[1], w[2])


# ── 블렌더 ─────────────────────────
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def to_blender(cf, size):
    R = P @ cf.R @ P.transposed()
    p = P @ cf.p
    S = Matrix.Diagonal((size[0], size[2], size[1]))  # 로블록스 크기(x,y,z) → 블렌더 축(x, -z→y, y→z)
    # 로블록스 상자 축을 블렌더로: 로컬 x→x, y→z, z→-y
    L = P @ Matrix.Diagonal(size) @ P.transposed()
    M = (R @ L).to_4x4()
    M.translation = p
    return M


_mats = {}


def material(col, glow=False, alpha=1.0):
    key = (tuple(col), glow, alpha)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new("M%d" % len(_mats))
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = tuple((c / 255) ** 2.2 for c in col) + (1,)
    b.inputs["Base Color"].default_value = lin
    b.inputs["Roughness"].default_value = 0.8
    if glow:
        b.inputs["Emission Color"].default_value = lin
        b.inputs["Emission Strength"].default_value = 2.5
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    _mats[key] = m
    return m


_unit = None
_shapes = {}


def _shape_mesh(shape):
    """로블록스 쐐기·원통을 블렌더 단위 메시로(로블록스 부품 축 → 블렌더: x→x, y→z, z→-y)"""
    if shape in _shapes:
        return _shapes[shape]
    if shape == "Wedge":
        # 쐐기: 뒤(+z)는 꽉 찬 높이, 앞(-z) 아래 모서리로 비탈이 내려간다
        rv = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5), (-0.5, 0.5, 0.5), (0.5, 0.5, 0.5)]
        verts = [(x, -z, y) for x, y, z in rv]
        faces = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)]
        me = bpy.data.meshes.new("wedge")
        me.from_pydata(verts, [], faces)
        me.update()
    else:
        # 원통: 축 = 로블록스 x(블렌더 x)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1, vertices=20)
        o = bpy.context.active_object
        me = o.data
        me.transform(Matrix.Rotation(PI / 2, 4, "Y"))
        bpy.data.objects.remove(o)
    _shapes[shape] = me
    return me


def cube(name, M, col, glow=False, alpha=1.0, ball=False, shape="Block"):
    global _unit
    if ball:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=12, ring_count=8)
        o = bpy.context.active_object
    else:
        if shape in ("Wedge", "Cylinder"):
            data = _shape_mesh(shape)
        else:
            if _unit is None:
                bpy.ops.mesh.primitive_cube_add(size=1)
                _unit = bpy.context.active_object.data
                bpy.data.objects.remove(bpy.context.active_object)
            data = _unit
        o = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(o)
    o.matrix_world = M
    o.data.materials.clear() if ball else None
    if ball:
        o.data.materials.append(material(col, glow, alpha))
    else:
        o.active_material = None
        if not o.material_slots:
            o.data.materials.append(material((128, 128, 128)))
        o.material_slots[0].link = "OBJECT"
        o.material_slots[0].material = material(col, glow, alpha)
    return o


def build(pose, offset, weapon, yaw=90):
    world = solve(pose)
    # yaw 90 = 게임 카메라처럼 오른쪽 옆모습(얼굴이 화면 오른쪽)
    base = cfp(*offset) * orient(0, yaw, 0)
    for name in ORDER:
        cf = base * world[name]
        cube(name, to_blender(cf, SIZES[name]), COLORS[name])
    # 얼굴·가슴 표시(앞 = -Z)
    cube("Face", to_blender(base * world["Head"] * cfp(0, 0.1, -0.62), (0.7, 0.25, 0.08)), (40, 30, 30))
    cube("Chest", to_blender(base * world["Torso"] * cfp(0, 0.3, -0.52), (1.2, 0.4, 0.06)), (220, 200, 120))
    if weapon:
        for slot, piece in (("W", weapon.get("Main")), ("O", weapon.get("Off"))):
            if not piece or piece.get("Hand") == "Float":
                continue
            wcf = base * weapon_cf(world, piece["Hand"], pose.get(slot, [0] * 6))
            for part in piece["Parts"]:
                at = part["At"]
                pc = wcf * cfp(at[0], at[1], at[2]) * orient(at[3], at[4], at[5])
                cube(part["Name"], to_blender(pc, part["Size"]), part["Color"], part["Material"] == "Neon",
                     1 - part.get("Transparency", 0) * 0.8, part["Shape"] == "Ball", part["Shape"])
        main = weapon.get("Main")
        if main and main.get("Hand") == "Float":
            orbit = weapon.get("Orbit", {"Count": 3, "Radius": 2.6, "Height": 1.6})
            for i in range(orbit["Count"]):
                a = 2 * PI * i / orbit["Count"]
                oc = base * world["Torso"].rot() * cfp(math.cos(a) * orbit["Radius"], orbit["Height"] - 1, math.sin(a) * orbit["Radius"])
                oc = CF(None, (base * cfp(0, 0, 0)).p + (world["Torso"].p + Vector((math.cos(a) * orbit["Radius"], orbit["Height"] - 1, math.sin(a) * orbit["Radius"]))))
                for part in main["Parts"]:
                    at = part["At"]
                    pc = oc * cfp(at[0], at[1], at[2]) * orient(at[3], at[4], at[5])
                    cube(part["Name"], to_blender(pc, part["Size"]), part["Color"], part["Material"] == "Neon",
                         1 - part.get("Transparency", 0) * 0.8, part["Shape"] == "Ball", part["Shape"])


def render(path, n, span, cam_side=1.0, zoom=None):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = eng
            break
        except Exception:
            pass
    sc.render.resolution_x, sc.render.resolution_y = (int(240 * n), 420) if zoom is None else (720, 720)
    sc.world = bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.78, 0.82, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3
    sun.rotation_euler = (math.radians(55), 0, math.radians(-30))
    sc.collection.objects.link(sun)
    # 바닥(로블록스 y = -3 = 발바닥)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(-span / 2, 0, -3.02))
    g = bpy.context.active_object
    g.scale = (span + 20, 30, 1)
    g.data.materials.append(material((150, 150, 140)))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("C"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = span + 6 if zoom is None else zoom
    # 앞(로블록스 -Z = 블렌더 +Y)에서 조금 오른쪽·위
    cam.location = Vector((-span / 2 - 10 * cam_side, 40, 19))
    d = Vector((-span / 2, 0, 0.5)) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def lineup(spec, out_name, yaw=90):
    """여러 직업의 한 순간을 나란히: spec = "직업/모션/무기/시각,직업/모션/무기/시각,..." """
    motions = json.load(open(os.path.join(OUT, "motions.json"), encoding="utf-8"))
    weapons = json.load(open(os.path.join(OUT, "weapons.json"), encoding="utf-8"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    global _unit, _mats, _shapes
    _unit, _mats, _shapes = None, {}, {}
    items = [x.split("/") for x in spec.split(",")]
    step = 7.0
    for i, (cls, name, wid, t) in enumerate(items):
        s = motions[cls]
        m = pick(s, name)
        build(sample(compile_motion(m), float(t)), (-i * step, 0, 0), weapons.get(wid), yaw)
    render(os.path.join(OUT, out_name + ".png"), len(items), (len(items) - 1) * step)
    print("찍음", out_name)


def views(set_name, motion_name, t, weapon_id, out_name):
    """한 자세를 네 방향에서: 게임 옆모습(90) · 앞 3/4(45) · 앞(0) · 뒤 3/4(135). 자세 검사용."""
    motions = json.load(open(os.path.join(OUT, "motions.json"), encoding="utf-8"))
    weapons = json.load(open(os.path.join(OUT, "weapons.json"), encoding="utf-8"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    global _unit, _mats, _shapes
    _unit, _mats, _shapes = None, {}, {}
    s = motions[set_name]
    m = pick(s, motion_name)
    pose = sample(compile_motion(m), float(t))
    step = 7.0
    for i, yaw in enumerate((90, 45, 0, 135)):
        build(pose, (-i * step, 0, 0), weapons.get(weapon_id), yaw)
    render(os.path.join(OUT, out_name + ".png"), 4, 3 * step)
    print("찍음", out_name)


def close(set_name, motion_name, t, weapon_id, yaw, out_name):
    """한 자세를 가까이(윗몸·무기 확대) 한 방향에서"""
    motions = json.load(open(os.path.join(OUT, "motions.json"), encoding="utf-8"))
    weapons = json.load(open(os.path.join(OUT, "weapons.json"), encoding="utf-8"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    global _unit, _mats, _shapes
    _unit, _mats, _shapes = None, {}, {}
    s = motions[set_name]
    m = pick(s, motion_name)
    build(sample(compile_motion(m), float(t)), (0, 0, 0), weapons.get(weapon_id), float(yaw))
    render(os.path.join(OUT, out_name + ".png"), 1, 0, zoom=7.5)
    print("찍음", out_name)


def gallery(out_name, yaw):
    """무기 전부를 세워 한 줄로(쥔 점 = 바닥 위 3, +Y 위). 모양 확인용"""
    weapons = json.load(open(os.path.join(OUT, "weapons.json"), encoding="utf-8"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    global _unit, _mats, _shapes
    _unit, _mats, _shapes = None, {}, {}
    ids = ["Rapier", "Greatsword", "Violin", "PilgrimNails", "MasonHammer", "PickStaff", "Flask", "Greataxe", "Orbs"]
    x = 0.0
    for wid in ids:
        w = weapons.get(wid)
        if not w:
            continue
        for slot in ("Main", "Off"):
            piece = w.get(slot)
            if not piece:
                continue
            base = cfp(-x, -1.6, 0) * orient(0, float(yaw), 0)
            for part in piece["Parts"]:
                at = part["At"]
                pc = base * cfp(at[0], at[1], at[2]) * orient(at[3], at[4], at[5])
                cube(part["Name"], to_blender(pc, part["Size"]), part["Color"], part["Material"] == "Neon",
                     1 - part.get("Transparency", 0) * 0.8, part["Shape"] == "Ball", part["Shape"])
            x += 2.4
    render(os.path.join(OUT, out_name + ".png"), 6, x - 2.4)
    print("찍음", out_name)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["Test", "Axes"]
    if args[0] == "gallery":
        gallery(args[1], args[2])
        return
    if args[0] == "close":
        close(*args[1:7])
        return
    if args[0] == "views":
        views(args[1], args[2], args[3], args[4], args[5])
        return
    if args[0] == "lineup":
        lineup(args[1], args[2], float(args[3]) if len(args) > 3 else 90)
        return
    set_name, motion_name = args[0], args[1]
    n_arg = args[2] if len(args) > 2 else "8"
    weapon_id = args[3] if len(args) > 3 and args[3] != "-" else None
    yaw = float(args[4]) if len(args) > 4 else 90
    motions = json.load(open(os.path.join(OUT, "motions.json"), encoding="utf-8"))
    weapons = json.load(open(os.path.join(OUT, "weapons.json"), encoding="utf-8"))
    s = motions[set_name]
    names = []
    if motion_name == "all":
        for k, v in s.items():
            if k == "Skills":
                names += ["Skills." + x for x in v]
            elif isinstance(v, dict) and "Keys" in v:
                names.append(k)
    else:
        names = [motion_name]
    for name in names:
        m = pick(s, name)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        global _unit, _mats, _shapes
        _unit, _mats, _shapes = None, {}, {}
        comp = compile_motion(m)
        dur = comp[1]
        weapon = weapons.get(weapon_id) if weapon_id else None
        step = 7.0
        # "k" = 키 시각마다 한 장, 숫자 = 고르게 n 장
        if n_arg == "k":
            times = [k[0] for k in comp[0]]
            if comp[2] and dur > times[-1]:
                times.append(dur)
        else:
            n = int(n_arg)
            times = [dur * i / max(1, n - 1) for i in range(n)]
        n = len(times)
        for i, t in enumerate(times):
            # 앞에서 보면 로블록스 +X 가 화면 왼쪽이라, 시간 순서가 왼→오가 되게 -X 로 늘어놓는다
            build(sample(comp, t), (-i * step, 0, 0), weapon, yaw)
        render(os.path.join(OUT, "%s_%s.png" % (set_name, name.replace(".", "_"))), n, (n - 1) * step)
        print("찍음", set_name, name)


main()
