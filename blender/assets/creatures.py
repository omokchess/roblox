"""적 크리처 (관절 분할 리그).

각 신체 부위는 별도 그룹(= Roblox 에서 별도 뼈 파트)으로 모델링되고,
관절 마커 J_<이름> (part0/part1 속성) 로 Motor6D 를 만든다.
관절 이름은 R15 와 동일 → 플레이어와 같은 절차적 포즈 라이브러리를 공유.

좌표: 크리처는 +Y (Roblox LookVector) 를 바라본다. 발바닥 = Z 0.
"""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import shapes as S

SEGMENTS = [
    "LowerTorso", "UpperTorso", "Head",
    "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm",
    "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg",
]
JOINTS = [
    # name, part0, part1
    ("Waist", "LowerTorso", "UpperTorso"),
    ("Neck", "UpperTorso", "Head"),
    ("LeftShoulder", "UpperTorso", "LeftUpperArm"),
    ("LeftElbow", "LeftUpperArm", "LeftLowerArm"),
    ("RightShoulder", "UpperTorso", "RightUpperArm"),
    ("RightElbow", "RightUpperArm", "RightLowerArm"),
    ("LeftHip", "LowerTorso", "LeftUpperLeg"),
    ("LeftKnee", "LeftUpperLeg", "LeftLowerLeg"),
    ("RightHip", "LowerTorso", "RightUpperLeg"),
    ("RightKnee", "RightUpperLeg", "RightLowerLeg"),
]


class Rig:
    def __init__(self, a, joints, root, hrp_size):
        self.a = a
        self.j = {k: Vector(v) for k, v in joints.items()}
        self.root = Vector(root)
        for name, p0, p1 in JOINTS:
            a.marker(f"J_{name}", tuple(self.j[name]), part0=p0, part1=p1)
        a.marker("J_Root", tuple(self.root), part0="HumanoidRootPart", part1="LowerTorso")
        hip_height = self.root.z - hrp_size[2] / 2
        a.attributes.update({"Rig": True, "HipHeight": round(hip_height, 3),
                             "HrpSize": [hrp_size[0], hrp_size[2], hrp_size[1]],   # Roblox (x, y, z)
                             "RootPos": [self.root.x, self.root.z, -self.root.y]})

    def seg(self, name):
        return self.a.in_group(name)

    def limb(self, seg, p0, p1, r0, r1, key, sides=8, noise=0.08):
        with self.seg(seg):
            p0, p1 = Vector(p0), Vector(p1)
            mid = p0.lerp(p1, 0.5)
            self.a.tube([p0, mid + (p1 - p0).orthogonal().normalized() * 0.05, p1], [r0, (r0 + r1) / 2 * 1.05, r1], key, sides=sides, noise_amp=noise, part_step=2)
            self.a.sphere(p0, r0 * 1.02, key, seg=sides, rings=5)


def _claws(a, c, direction, n=3, length=0.7, r=0.14, spread=0.35, key="claw"):
    c = Vector(c)
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    for k in range(n):
        off = side * spread * (k - (n - 1) / 2)
        base = c + off
        tip = base + d * length + Vector((0, 0, -length * 0.3))
        a.cyl(base, tip, r, key, r1=0.02, sides=5)


def bog_crawler():
    a = Asset("E_BogCrawler", "Creature", description="늪 크롤러 — 작고 빠른 개구리 고블린 (독 물기)")
    J = {
        "Waist": (0, 0.1, 3.2), "Neck": (0, 1.1, 4.6),
        "LeftShoulder": (-1.15, 0.6, 4.3), "RightShoulder": (1.15, 0.6, 4.3),
        "LeftElbow": (-1.6, 1.1, 3.1), "RightElbow": (1.6, 1.1, 3.1),
        "LeftHip": (-0.65, 0, 2.5), "RightHip": (0.65, 0, 2.5),
        "LeftKnee": (-1.1, 0.7, 1.35), "RightKnee": (1.1, 0.7, 1.35),
    }
    R = Rig(a, J, root=(0, 0, 2.7), hrp_size=(2.4, 1.6, 3.0))
    with R.seg("LowerTorso"):
        a.blob((0, 0, 2.8), 0.95, "skin_bog", seg=10, rings=7, amp=0.1, scale=(1.15, 0.95, 0.85))
        a.box((0, 0.2, 2.35), (2.0, 1.6, 0.5), "leather", bevel=0.15)
        a.box((0, 0.95, 2.0), (0.9, 0.12, 1.0), "cloth_red", rot=(8, 0, 0), bevel=0.0)
    with R.seg("UpperTorso"):
        a.blob((0, 0.45, 3.9), 1.25, "skin_bog", seg=12, rings=8, amp=0.1, scale=(1.15, 1.0, 1.0), rot=(25, 0, 0))
        a.blob((0, 1.2, 3.7), 0.8, "skin_bog_lt", seg=10, rings=6, amp=0.05, scale=(1.1, 0.5, 1.0))
        for k in range(4):
            a.blob((a.rng.uniform(-0.8, 0.8), a.rng.uniform(-0.6, 0.2), 4.6 + a.rng.uniform(-0.3, 0.2)), 0.25, "skin_bog_lt", seg=6, rings=4, amp=0.2)
        # 뼈 목걸이
        with a.no_parts():
            for k in range(5):
                ang = math.pi * (0.2 + 0.6 * k / 4)
                a.box((math.cos(ang) * 0.9, 0.9 + math.sin(ang) * 0.4, 4.35 - math.sin(ang) * 0.2), (0.14, 0.14, 0.45), "bone", rot=(0, 0, math.degrees(ang)), bevel=0.03)
    with R.seg("Head"):
        a.blob((0, 1.6, 4.95), 1.15, "skin_bog", seg=12, rings=8, amp=0.08, scale=(1.3, 1.1, 0.78))
        a.blob((0, 2.0, 4.55), 0.9, "skin_bog_lt", seg=10, rings=6, amp=0.05, scale=(1.35, 0.9, 0.45))
        a.box((0, 2.52, 4.75), (2.1, 0.2, 0.12), "mouth", rot=(0, 0, 0), bevel=0.04)
        for sx in (-1, 1):
            a.sphere((sx * 0.72, 1.85, 5.55), 0.42, "skin_bog", seg=10, rings=6)
            a.sphere((sx * 0.78, 2.12, 5.62), 0.24, "eye_glow", seg=8, rings=5)
            a.sphere((sx * 0.82, 2.3, 5.64), 0.1, "mouth", seg=6, rings=4)
        # 개구리 해골 가면 (이마)
        a.blob((0, 1.45, 5.55), 0.7, "bone", seg=8, rings=6, amp=0.1, scale=(1.3, 1.0, 0.45))
        for sx in (-1, 1):
            a.cyl((sx * 0.5, 1.2, 5.8), (sx * 0.9, 0.7, 6.6), 0.14, "bone", r1=0.03, sides=5)
    for side, sx in (("Left", -1), ("Right", 1)):
        sh, el = Vector(J[f"{side}Shoulder"]), Vector(J[f"{side}Elbow"])
        hand = Vector((sx * 1.75, 1.7, 1.9))
        R.limb(f"{side}UpperArm", sh, el, 0.38, 0.3, "skin_bog")
        R.limb(f"{side}LowerArm", el, hand, 0.3, 0.26, "skin_bog")
        with R.seg(f"{side}LowerArm"):
            a.blob(hand, 0.42, "skin_bog", seg=8, rings=5, amp=0.1, scale=(1.0, 1.2, 0.7))
            _claws(a, hand + Vector((0, 0.3, -0.1)), (0, 1, -0.4), n=3, length=0.65)
        hip, kn = Vector(J[f"{side}Hip"]), Vector(J[f"{side}Knee"])
        foot = Vector((sx * 1.0, 0.2, 0.25))
        R.limb(f"{side}UpperLeg", hip, kn, 0.5, 0.36, "skin_bog")
        R.limb(f"{side}LowerLeg", kn, foot, 0.34, 0.26, "skin_bog")
        with R.seg(f"{side}LowerLeg"):
            a.blob(foot + Vector((0, 0.45, -0.1)), 0.55, "skin_bog", seg=8, rings=5, amp=0.1, scale=(1.1, 1.6, 0.35))
            _claws(a, foot + Vector((0, 1.1, -0.1)), (0, 1, 0), n=3, length=0.35, r=0.1)
    a.marker("Mouth", (0, 2.6, 4.75))
    a.marker("HealthBar", (0, 0, 7.4))
    return a


def mud_brute():
    a = Asset("E_MudBrute", "Creature", description="진흙 거인 — 느리지만 강력한 탱커 (곤봉)")
    J = {
        "Waist": (0, 0.2, 6.4), "Neck": (0, 1.9, 9.8),
        "LeftShoulder": (-3.2, 0.7, 9.2), "RightShoulder": (3.2, 0.7, 9.2),
        "LeftElbow": (-4.0, 1.3, 6.4), "RightElbow": (4.0, 1.3, 6.4),
        "LeftHip": (-1.5, 0, 4.9), "RightHip": (1.5, 0, 4.9),
        "LeftKnee": (-1.8, 0.5, 2.6), "RightKnee": (1.8, 0.5, 2.6),
    }
    R = Rig(a, J, root=(0, 0, 5.2), hrp_size=(5.6, 3.6, 6.0))
    with R.seg("LowerTorso"):
        a.blob((0, 0, 5.6), 2.1, "skin_mud", seg=12, rings=8, amp=0.15, scale=(1.2, 0.95, 0.8))
        a.box((0, 1.5, 4.8), (2.4, 0.3, 2.6), "leather", rot=(5, 0, 0), bevel=0.1)
    with R.seg("UpperTorso"):
        a.blob((0, 0.6, 8.3), 3.0, "skin_mud", seg=14, rings=9, amp=0.14, scale=(1.3, 1.0, 1.0), rot=(18, 0, 0))
        for k in range(8):
            ang = a.rng.uniform(0, 2 * math.pi)
            z = a.rng.uniform(7.0, 10.0)
            a.blob((math.cos(ang) * 3.0, 0.6 + math.sin(ang) * 2.2, z), a.rng.uniform(0.45, 0.8), "stone_dk", seg=7, rings=5, amp=0.25)
        for sx in (-1, 1):
            a.blob((sx * 2.8, 0.0, 10.4), 1.5, "moss", seg=10, rings=6, amp=0.3, scale=(1.3, 1.2, 0.6))
            S.hanging_moss(a, (sx * 3.2, 0.3, 9.8), length=2.8, strands=4, spread=0.8)
    with R.seg("Head"):
        a.blob((0, 2.3, 10.3), 1.1, "skin_mud", seg=10, rings=7, amp=0.12, scale=(1.1, 1.0, 0.9))
        for sx in (-1, 1):
            a.sphere((sx * 0.45, 3.2, 10.5), 0.2, "eye_red", seg=6, rings=4)
        a.box((0, 3.25, 9.9), (0.9, 0.2, 0.18), "mouth", bevel=0.05)
    for side, sx in (("Left", -1), ("Right", 1)):
        sh, el = Vector(J[f"{side}Shoulder"]), Vector(J[f"{side}Elbow"])
        hand = Vector((sx * 4.3, 1.9, 3.8))
        R.limb(f"{side}UpperArm", sh, el, 1.25, 1.0, "skin_mud", sides=10, noise=0.15)
        R.limb(f"{side}LowerArm", el, hand, 1.05, 0.95, "skin_mud", sides=10, noise=0.15)
        with R.seg(f"{side}LowerArm"):
            a.blob(hand, 1.2, "skin_mud", seg=10, rings=6, amp=0.2, scale=(1.0, 1.1, 0.9))
            a.blob(el + Vector((sx * 0.4, 0.2, -0.4)), 0.7, "stone_dk", seg=7, rings=5, amp=0.25)
        hip, kn = Vector(J[f"{side}Hip"]), Vector(J[f"{side}Knee"])
        foot = Vector((sx * 1.9, 0.3, 0.6))
        R.limb(f"{side}UpperLeg", hip, kn, 1.25, 1.0, "skin_mud", sides=10, noise=0.12)
        R.limb(f"{side}LowerLeg", kn, foot, 1.0, 0.9, "skin_mud", sides=10, noise=0.12)
        with R.seg(f"{side}LowerLeg"):
            a.blob(foot + Vector((0, 0.5, -0.2)), 1.1, "skin_mud", seg=9, rings=5, amp=0.15, scale=(1.0, 1.4, 0.5))
    a.marker("WeaponGrip", (4.3, 1.9, 3.8), rot=(90, 0, 0))
    a.marker("HealthBar", (0, 0, 13.6))
    return a


def bog_witch():
    a = Asset("E_BogWitch", "Creature", description="늪 마녀 — 거리를 두고 독 구체를 쏘는 원거리형")
    J = {
        "Waist": (0, 0.1, 4.2), "Neck": (0, 0.9, 6.0),
        "LeftShoulder": (-1.0, 0.4, 5.6), "RightShoulder": (1.0, 0.4, 5.6),
        "LeftElbow": (-1.45, 0.9, 4.4), "RightElbow": (1.45, 0.9, 4.4),
        "LeftHip": (-0.55, 0, 3.1), "RightHip": (0.55, 0, 3.1),
        "LeftKnee": (-0.6, 0.2, 1.6), "RightKnee": (0.6, 0.2, 1.6),
    }
    R = Rig(a, J, root=(0, 0, 3.4), hrp_size=(2.2, 1.6, 3.4))
    with R.seg("LowerTorso"):
        # 로브 치마 (원뿔 + 너덜한 밑단)
        prof = [(4.3, 0.9), (3.4, 1.2), (2.0, 1.55), (0.5, 1.9)]
        a.tube([Vector((0, 0, z)) for z, _ in prof], [r for _, r in prof], "robe", sides=14, noise_amp=0.12, part_step=1)
        with a.no_parts():
            for k in range(10):
                ang = k * 2 * math.pi / 10
                a.box((math.cos(ang) * 1.82, math.sin(ang) * 1.82, 0.55), (0.9, 0.1, 0.8), "robe_dk", rot=(-18, 0, math.degrees(ang) + 90), bevel=0.0)
        a.cyl((0, 0, 4.1), (0, 0, 4.4), 1.0, "rope", sides=10)
    with R.seg("UpperTorso"):
        a.blob((0, 0.3, 5.1), 1.05, "robe", seg=10, rings=7, amp=0.1, scale=(1.1, 0.9, 1.1), rot=(20, 0, 0))
        a.blob((0, 0.2, 5.8), 1.2, "robe_dk", seg=10, rings=6, amp=0.2, scale=(1.3, 1.1, 0.45))
        with a.no_parts():
            for k in range(3):
                S.bottle(a, (-0.5 + k * 0.5, 1.15, 4.6), h=0.45, r=0.13, key=("glow_potion", "glass_green", "glow_mushroom")[k])
    with R.seg("Head"):
        a.blob((0, 1.1, 6.5), 0.75, "skin_witch", seg=10, rings=7, amp=0.1, scale=(0.9, 1.0, 1.1))
        a.cyl((0, 1.7, 6.5), (0, 2.6, 6.2), 0.2, "skin_witch", r1=0.06, sides=6)
        a.sphere((0.2, 2.2, 6.35), 0.08, "skin_bog", seg=5, rings=3)
        for sx in (-1, 1):
            a.sphere((sx * 0.3, 1.75, 6.75), 0.12, "glow_potion", seg=6, rings=4)
        with a.no_parts():
            for k in range(8):
                ang = math.pi * (0.9 + 1.2 * k / 7)
                p0 = Vector((math.cos(ang) * 0.7, 1.0 + math.sin(ang) * 0.6, 6.8))
                a.tube([p0, p0 + Vector((0, -0.2, -1.2)), p0 + Vector((0, -0.3, -2.4))], [0.12, 0.09, 0.03], "hair", sides=4, part=False)
        # 모자
        a.cyl((0, 1.0, 7.05), (0, 1.0, 7.2), 1.9, "robe_dk", sides=16)
        hat = [Vector((0, 1.0, 7.1)), Vector((0, 0.9, 8.3)), Vector((0, 0.5, 9.4)), Vector((0, -0.3, 10.1)), Vector((0, -0.9, 10.2))]
        a.tube(hat, [1.0, 0.75, 0.48, 0.25, 0.06], "robe_dk", sides=10, part_step=1)
        a.cyl((0, 1.0, 7.25), (0, 1.0, 7.6), 1.02, "cloth_green", sides=12)
    for side, sx in (("Left", -1), ("Right", 1)):
        sh, el = Vector(J[f"{side}Shoulder"]), Vector(J[f"{side}Elbow"])
        hand = Vector((sx * 1.35, 1.5, 3.55))
        R.limb(f"{side}UpperArm", sh, el, 0.38, 0.32, "robe")
        R.limb(f"{side}LowerArm", el, hand, 0.34, 0.2, "robe")
        with R.seg(f"{side}LowerArm"):
            a.blob(hand, 0.25, "skin_witch", seg=7, rings=5, amp=0.15)
            _claws(a, hand + Vector((0, 0.2, 0)), (0, 1, -0.3), n=4, length=0.45, r=0.06, spread=0.14, key="skin_witch")
        hip, kn = Vector(J[f"{side}Hip"]), Vector(J[f"{side}Knee"])
        foot = Vector((sx * 0.6, 0.2, 0.2))
        R.limb(f"{side}UpperLeg", hip, kn, 0.3, 0.25, "robe_dk")
        R.limb(f"{side}LowerLeg", kn, foot, 0.24, 0.2, "skin_witch")
        with R.seg(f"{side}LowerLeg"):
            a.blob(foot + Vector((0, 0.35, 0)), 0.3, "leather", seg=7, rings=4, amp=0.1, scale=(0.9, 1.6, 0.6))
    a.marker("WeaponGrip", (1.35, 1.5, 3.55), rot=(0, 0, 0))
    a.marker("CastPoint", (1.35, 2.2, 5.2))
    a.marker("HealthBar", (0, 0, 11.2))
    return a


def mire_lord():
    a = Asset("E_MireLord", "Creature", description="늪의 군주 — 보스 (사슴뿔 해골, 이끼 망토, 발광 핵)")
    J = {
        "Waist": (0, 0.3, 9.6), "Neck": (0, 2.2, 14.4),
        "LeftShoulder": (-4.6, 1.0, 13.4), "RightShoulder": (4.6, 1.0, 13.4),
        "LeftElbow": (-6.2, 2.0, 9.6), "RightElbow": (6.2, 2.0, 9.6),
        "LeftHip": (-2.0, 0, 7.6), "RightHip": (2.0, 0, 7.6),
        "LeftKnee": (-2.6, 1.2, 4.2), "RightKnee": (2.6, 1.2, 4.2),
    }
    R = Rig(a, J, root=(0, 0, 8.0), hrp_size=(8.0, 5.0, 9.0))
    with R.seg("LowerTorso"):
        a.blob((0, 0, 8.6), 3.0, "skin_lord", seg=12, rings=8, amp=0.15, scale=(1.2, 0.9, 0.8))
        # 이끼 망토 자락
        with a.no_parts():
            for k in range(14):
                ang = math.pi * (0.1 + 0.8 * k / 13) + math.pi
                p0 = Vector((math.cos(ang) * 3.2, math.sin(ang) * 2.4 - 0.5, 9.5))
                a.tube([p0, p0 + Vector((0, -0.4, -3.5)), p0 + Vector((a.rng.uniform(-0.3, 0.3), -0.8, -7.8))], [0.6, 0.5, 0.2], "moss_hang", sides=5, part=False)
        a._prim_box_only((0, -2.2, 5.5), (6.0, 1.0, 7.5), "moss_hang")
    with R.seg("UpperTorso"):
        a.blob((0, 0.8, 12.2), 4.2, "skin_lord", seg=14, rings=9, amp=0.15, scale=(1.25, 0.95, 0.95), rot=(15, 0, 0))
        # 가슴 핵 + 뿌리 갈비뼈
        a.sphere((0, 4.3, 12.0), 1.1, "stone_rune", seg=12, rings=8)
        for k in range(5):
            z = 10.6 + k * 0.75
            for sx in (-1, 1):
                a.tube([Vector((sx * 0.9, 4.2, z)), Vector((sx * 2.6, 3.6, z + 0.2)), Vector((sx * 3.8, 2.0, z - 0.1))], [0.32, 0.26, 0.15], "bark", sides=6, part_step=2)
        for sx in (-1, 1):
            a.blob((sx * 4.0, 0.0, 15.0), 2.2, "moss", seg=10, rings=6, amp=0.3, scale=(1.3, 1.3, 0.7))
            S.hanging_moss(a, (sx * 4.4, 0.5, 14.0), length=4.5, strands=6, spread=1.2)
        a.light((0, 5.0, 12.0), color=(90, 255, 170), range_=24, brightness=2.0)
    with R.seg("Head"):
        a.blob((0, 3.0, 15.8), 1.8, "bone", seg=12, rings=8, amp=0.08, scale=(1.0, 1.35, 0.95))
        a.box((0, 4.6, 15.0), (1.9, 1.4, 1.0), "bone", bevel=0.3)
        for sx in (-1, 1):
            a.sphere((sx * 0.7, 4.3, 16.1), 0.42, "mouth", seg=8, rings=5)
            a.sphere((sx * 0.7, 4.55, 16.1), 0.24, "glow_mushroom", seg=8, rings=5)
            # 사슴뿔
            base = Vector((sx * 1.0, 2.6, 17.2))
            p1 = base + Vector((sx * 1.6, -0.4, 2.2))
            p2 = p1 + Vector((sx * 2.2, -0.8, 2.4))
            p3 = p2 + Vector((sx * 1.6, -0.4, 2.8))
            a.tube([base, p1, p2, p3], [0.45, 0.36, 0.26, 0.08], "bark_dead", sides=7, part_step=1)
            for (q, d) in ((p1, (sx * 0.6, 0.6, 1.8)), (p2, (sx * 0.4, 0.8, 2.0)), (p2, (sx * 1.8, -0.2, 0.9))):
                a.tube([q, q + Vector(d) * 0.6, q + Vector(d)], [0.26, 0.18, 0.05], "bark_dead", sides=6, part_step=2)
            S.hanging_moss(a, p1, length=2.0, strands=3, spread=0.4)
        a.light((0, 5.0, 16.1), color=(110, 255, 205), range_=12, brightness=1.4)
    for side, sx in (("Left", -1), ("Right", 1)):
        sh, el = Vector(J[f"{side}Shoulder"]), Vector(J[f"{side}Elbow"])
        hand = Vector((sx * 6.6, 3.2, 5.8))
        R.limb(f"{side}UpperArm", sh, el, 1.5, 1.2, "skin_lord", sides=10, noise=0.15)
        R.limb(f"{side}LowerArm", el, hand, 1.25, 1.0, "bark", sides=10, noise=0.2)
        with R.seg(f"{side}LowerArm"):
            a.blob(hand, 1.4, "bark", seg=9, rings=6, amp=0.2)
            _claws(a, hand + Vector((0, 0.9, -0.4)), (0, 1, -0.6), n=4, length=2.0, r=0.3, spread=0.7, key="bark_dead")
            for k in range(3):
                a.tube([el + Vector((sx * 0.8, 0, -k * 0.8)), el + Vector((sx * 1.8, 0.4, -1.5 - k)), el + Vector((sx * 2.0, 1.0, -3.0 - k))], [0.3, 0.2, 0.06], "bark", sides=5, part_step=2)
        hip, kn = Vector(J[f"{side}Hip"]), Vector(J[f"{side}Knee"])
        foot = Vector((sx * 2.8, 0.6, 0.8))
        R.limb(f"{side}UpperLeg", hip, kn, 1.6, 1.25, "skin_lord", sides=10, noise=0.12)
        R.limb(f"{side}LowerLeg", kn, foot, 1.25, 1.05, "bark", sides=10, noise=0.2)
        with R.seg(f"{side}LowerLeg"):
            for k in range(4):
                ang = math.pi * (0.1 + 0.8 * k / 3)
                d = Vector((math.cos(ang) * 1.6, math.sin(ang) * 2.0, -0.6))
                a.tube([foot, foot + d * 0.6, foot + d], [0.55, 0.4, 0.15], "bark", sides=6, part_step=2)
    a.marker("SlamPoint", (0, 5.0, 0.2))
    a.marker("CastPoint", (0, 5.2, 12.0))
    a.marker("HealthBar", (0, 0, 24.0))
    return a


ASSETS = [bog_crawler, mud_brute, bog_witch, mire_lord]
for _f in ASSETS:
    _f.preview = {"env": "mud", "azim": 150, "elev": 10, "pad": 1.25}
