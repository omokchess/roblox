"""늪 식생: 낙우송(사이프러스), 맹그로브, 고사목, 덤불, 갈대, 부들, 연잎, 쓰러진 통나무, 활엽수.

나뭇잎은 노이즈 덩어리(blob)로 표현한 스타일라이즈드 룩 (Roblox 에 잘 어울림).
"""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import shapes as S


def _branch(a, start, direction, length, r0, key, depth, leaf_key=None, moss=True, leaf_size=3.0, leaves=True):
    """재귀 가지. 끝에 잎 덩어리."""
    d = Vector(direction).normalized()
    pts = [Vector(start)]
    n = 4
    for i in range(1, n + 1):
        t = i / n
        wob = Vector((a.rng.uniform(-0.3, 0.3), a.rng.uniform(-0.3, 0.3), a.rng.uniform(-0.1, 0.25))) * length * 0.15
        pts.append(Vector(start) + d * length * t + wob * t)
    radii = [r0 * (1 - 0.7 * i / n) for i in range(n + 1)]
    a.tube(pts, radii, key, sides=6 if depth > 0 else 5, noise_amp=0.08, part_step=2, caps=True)
    end = pts[-1]
    if depth > 0:
        for k in range(2):
            nd = d + Vector((a.rng.uniform(-0.8, 0.8), a.rng.uniform(-0.8, 0.8), a.rng.uniform(-0.1, 0.5)))
            _branch(a, pts[-2].lerp(end, 0.6), nd, length * a.rng.uniform(0.5, 0.7), radii[-1] * 1.2, key, depth - 1, leaf_key, moss, leaf_size, leaves)
    elif leaves and leaf_key:
        s = leaf_size * a.rng.uniform(0.8, 1.2)
        a.blob(end + Vector((0, 0, s * 0.2)), s, leaf_key, seg=10, rings=6, amp=0.35, freq=1.2, scale=(1.3, 1.3, 0.6))
        # 잎 덩어리 클러스터 (2~3개 겹침 → 풍성한 수관)
        with a.no_parts():
            for k in range(2):
                ang = a.rng.uniform(0, 2 * math.pi)
                off = Vector((math.cos(ang) * s * 0.9, math.sin(ang) * s * 0.9, a.rng.uniform(-0.25, 0.1) * s))
                a.blob(end + off, s * a.rng.uniform(0.6, 0.8), "leaf_dk" if k == 0 else leaf_key, seg=8, rings=5, amp=0.35, scale=(1.3, 1.3, 0.6))
            if moss:
                for k in range(2):
                    ang = a.rng.uniform(0, 2 * math.pi)
                    S.hanging_moss(a, end + Vector((math.cos(ang) * s * 0.7, math.sin(ang) * s * 0.7, -s * 0.2)), length=s * 1.4, strands=5, spread=s * 0.4)
    if moss and depth <= 1 and a.rng.random() < 0.6:
        with a.no_parts():
            S.hanging_moss(a, pts[2], length=length * 0.35 + 1.5, strands=4, spread=0.6)


def cypress(name, height=46.0, seed=None):
    a = Asset(name, "Vegetation", seed=seed, description="낙우송 (넓은 판뿌리, 무릎뿌리, 스패니시 모스)")
    # 줄기: 밑동이 넓게 퍼지는 판뿌리
    n = 12
    pts, radii = [], []
    lean = Vector((a.rng.uniform(-0.04, 0.04), a.rng.uniform(-0.04, 0.04), 1))
    for i in range(n + 1):
        t = i / n
        z = -3.0 + t * height * 0.72
        pts.append(Vector((lean.x * z * 1.5, lean.y * z * 1.5, z)))
        base = 4.4 * math.exp(-t * 9) + 1.75 * (1 - 0.55 * t)
        radii.append(base)
    a.tube(pts, radii, "bark_cypress", sides=14, noise_amp=0.22, noise_freq=0.5, part_step=3, part_joints=True)
    a.collider((0, 0, height * 0.3), (3.6, 3.6, height * 0.66), tag="Trunk")
    # 판뿌리 날개
    for k in range(6):
        ang = k * 2 * math.pi / 6 + a.rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(ang), math.sin(ang), 0))
        rp = [d * 1.0 + Vector((0, 0, 4.5)), d * 3.2 + Vector((0, 0, 1.2)), d * 5.2 + Vector((0, 0, -0.5)), d * 6.5 + Vector((0, 0, -2.5))]
        a.tube(rp, [0.9, 0.8, 0.6, 0.4], "bark_cypress", sides=7, noise_amp=0.2, part_step=1)
    # 무릎뿌리 (knees)
    for k in range(7):
        ang = a.rng.uniform(0, 2 * math.pi)
        r = a.rng.uniform(6, 11)
        h = a.rng.uniform(1.0, 3.0)
        base = Vector((math.cos(ang) * r, math.sin(ang) * r, -1.5))
        a.tube([base, base + Vector((0.1, 0, h * 0.6 + 1.5)), base + Vector((0, 0.1, h + 1.5))], [0.6, 0.4, 0.12], "bark_cypress", sides=6, noise_amp=0.15, part_step=1)
    # 가지 (위쪽 절반) + 수관
    top = pts[-1]
    for k in range(10):
        t = 0.42 + 0.58 * k / 9
        p = pts[0].lerp(top, t)
        ang = k * 2.4 + a.rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(ang), math.sin(ang), a.rng.uniform(0.05, 0.35)))
        _branch(a, p, d, height * a.rng.uniform(0.18, 0.28) * (1.2 - 0.5 * t), 0.7 * (1.1 - 0.5 * t), "bark_cypress", 1, "leaf", leaf_size=height * 0.08)
    a.blob(top + Vector((0, 0, 2.0)), height * 0.11, "leaf", seg=12, rings=7, amp=0.3, scale=(1.4, 1.4, 0.7))
    a.blob(top + Vector((2.5, -1.5, -1.0)), height * 0.08, "leaf_dk", seg=10, rings=6, amp=0.3, scale=(1.4, 1.4, 0.65))
    return a


def cypress_a():
    return cypress("CypressA", 48.0, seed=11)


def cypress_b():
    return cypress("CypressB", 38.0, seed=23)


def cypress_c():
    return cypress("CypressC", 58.0, seed=37)


def mangrove():
    a = Asset("Mangrove", "Vegetation", description="맹그로브 (아치형 지주뿌리)")
    trunk_base = Vector((0, 0, 5.0))
    pts = [trunk_base + Vector((0.2 * math.sin(i), 0.2 * math.cos(i), i * 3.0)) for i in range(7)]
    a.tube(pts, [1.3, 1.2, 1.05, 0.9, 0.8, 0.7, 0.6], "bark", sides=10, noise_amp=0.15, part_step=2, part_joints=True)
    a.collider((0, 0, 12.0), (2.4, 2.4, 20), tag="Trunk")
    # 지주뿌리: 줄기에서 아치를 그리며 물속으로
    for k in range(11):
        ang = k * 2 * math.pi / 11 + a.rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(ang), math.sin(ang), 0))
        r_end = a.rng.uniform(6, 10)
        z0 = a.rng.uniform(4.5, 9.0)
        root = []
        for i in range(9):
            t = i / 8
            p = trunk_base + Vector((0, 0, z0 - 5.0)) + d * (0.8 + r_end * t) + Vector((0, 0, -t * (z0 + 3.0) + 3.2 * math.sin(t * math.pi)))
            root.append(p)
        a.tube(root, [0.55 - 0.3 * i / 8 for i in range(9)], "bark", sides=6, noise_amp=0.15, part_step=2)
    top = pts[-1]
    for k in range(6):
        ang = k * 2 * math.pi / 6 + 0.3
        d = Vector((math.cos(ang), math.sin(ang), 0.45))
        _branch(a, top - Vector((0, 0, 3 - k * 0.4)), d, 9.0, 0.6, "bark", 1, "leaf", moss=False, leaf_size=3.6)
    a.blob(top + Vector((0, 0, 2.5)), 6.0, "leaf", seg=12, rings=7, amp=0.3, scale=(1.5, 1.5, 0.6))
    return a


def dead_tree():
    a = Asset("DeadTree", "Vegetation", description="고사목 (앙상한 뒤틀린 가지)")
    pts = []
    for i in range(10):
        t = i / 9
        pts.append(Vector((math.sin(t * 3) * 1.2, math.cos(t * 2.5) * 0.8 - 0.8, -2.0 + t * 30)))
    a.tube(pts, [2.2 - 1.8 * i / 9 for i in range(10)], "bark_dead", sides=10, noise_amp=0.25, noise_freq=0.8, part_step=2, part_joints=True)
    a.collider((0, 0, 11), (3.2, 3.2, 26), tag="Trunk")
    for k in range(6):
        t = 0.35 + 0.1 * k
        p = pts[int(t * 9)]
        ang = k * 2.2
        _branch(a, p, (math.cos(ang), math.sin(ang), 0.6), 9.0 - k * 0.8, 0.6, "bark_dead", 1, None, moss=True, leaves=False)
    # 부러진 꼭대기
    a.box(pts[-1] + Vector((0, 0, 0.3)), (0.9, 0.9, 1.6), "bark_dead", rot=(25, 10, 0), bevel=0.1)
    for k in range(4):
        ang = k * 1.6
        base = Vector((math.cos(ang) * 2.0, math.sin(ang) * 2.0, 0))
        a.tube([base + Vector((0, 0, 3)), base * 2.2 + Vector((0, 0, 0.5)), base * 3.2 + Vector((0, 0, -2))], [0.8, 0.5, 0.3], "bark_dead", sides=6, noise_amp=0.2, part_step=1)
    return a


def swamp_bush():
    a = Asset("SwampBush", "Vegetation", description="늪 덤불")
    for k in range(7):
        ang = a.rng.uniform(0, 2 * math.pi)
        r = a.rng.uniform(0, 3.0)
        s = a.rng.uniform(1.6, 2.8)
        a.blob((math.cos(ang) * r, math.sin(ang) * r, s * 0.5), s, "leaf" if k % 3 else "leaf_dk", seg=9, rings=6, amp=0.35, scale=(1.2, 1.2, 0.8))
    for k in range(4):
        ang = a.rng.uniform(0, 2 * math.pi)
        a.sphere((math.cos(ang) * 2.5, math.sin(ang) * 2.5, 2.6), 0.25, "flower_white", seg=6, rings=4)
    return a


def reeds():
    a = Asset("Reeds", "Vegetation", description="갈대 + 부들 군락")
    with a.no_parts():
        for k in range(60):
            ang = a.rng.uniform(0, 2 * math.pi)
            r = a.rng.uniform(0, 4.0) ** 0.9
            base = Vector((math.cos(ang) * r, math.sin(ang) * r, -0.8))
            h = a.rng.uniform(4, 8)
            lean = Vector((a.rng.uniform(-0.2, 0.2), a.rng.uniform(-0.2, 0.2), 1)).normalized()
            tipd = lean * h + Vector((a.rng.uniform(-0.6, 0.6), a.rng.uniform(-0.6, 0.6), 0))
            mid = base + lean * h * 0.5
            # 납작한 잎: 얇은 박스 두 마디
            a.box_between(base, mid, 0.05, "reed", width=0.28)
            a.box_between(mid, base + tipd, 0.04, "reed", width=0.16)
            if k % 5 == 0:
                top = base + tipd
                a.cyl(top - Vector((0, 0, 1.4)), top - Vector((0, 0, 0.2)), 0.22, "cattail", sides=6)
                a.cyl(top - Vector((0, 0, 0.2)), top + Vector((0, 0, 0.6)), 0.04, "reed", sides=3)
    for k in range(5):
        ang = k * 2 * math.pi / 5
        a._prim_box_only((math.cos(ang) * 2.0, math.sin(ang) * 2.0, 2.2), (0.3, 1.6, 6.0), "reed", rot=(a.rng.uniform(-8, 8), 0, math.degrees(ang)))
    return a


def lily_pads():
    a = Asset("LilyPads", "Vegetation", description="연잎 + 연꽃 무리 (수면)")
    from swamplib import geom
    for k in range(14):
        ang = a.rng.uniform(0, 2 * math.pi)
        r = a.rng.uniform(0, 7.0)
        c = Vector((math.cos(ang) * r, math.sin(ang) * r, 0.08))
        rr = a.rng.uniform(0.9, 2.0)
        notch = a.rng.uniform(0, 2 * math.pi)
        # 노치 있는 원판 (삼각 팬)
        verts = [Vector((0, 0, 0.06))]
        seg = 14
        for i in range(seg + 1):
            t = notch + 0.35 + (2 * math.pi - 0.7) * i / seg
            verts.append(Vector((math.cos(t) * rr, math.sin(t) * rr, 0.02 * math.sin(i))))
        faces = [(0, i, i + 1) for i in range(1, seg + 1)]
        uvs = [tuple((verts[j].x, verts[j].y) for j in f) for f in faces]
        geo = geom.solidify(verts, faces, uvs, [True] * len(faces), 0.08)
        with a.at(loc=c, rot=(0, 0, 0)):
            a.mesh(geo, "lily", part_boxes=None)
            a._prim_cyl_only((0, 0, -0.04), (0, 0, 0.04), rr * 0.95, "lily")
        if k % 4 == 0:
            with a.at(loc=c + Vector((0.2, 0.2, 0.1))), a.no_parts():
                for p in range(6):
                    t = p * 2 * math.pi / 6
                    a.box((math.cos(t) * 0.3, math.sin(t) * 0.3, 0.35), (0.6, 0.25, 0.08), "flower_pink", rot=(0, -40, math.degrees(t)), bevel=0.0)
                a.sphere((0, 0, 0.35), 0.18, "brass", seg=6, rings=4)
    return a


def fallen_log():
    a = Asset("FallenLog", "Vegetation", description="이끼 낀 쓰러진 통나무 + 버섯")
    pts = [Vector((-10 + i * 2.5, 0.3 * math.sin(i), 1.2 + 0.1 * math.sin(i * 1.3))) for i in range(9)]
    a.tube(pts, [1.5, 1.6, 1.55, 1.5, 1.45, 1.4, 1.35, 1.3, 1.25], "bark_dead", sides=12, noise_amp=0.15, part_step=2)
    with a.no_parts():
        for k in range(8):
            p = pts[a.rng.randrange(9)]
            a.blob(p + Vector((0, 0, 1.2)), a.rng.uniform(0.6, 1.1), "moss", seg=8, rings=5, amp=0.3, scale=(1.6, 1.2, 0.35))
    from assets.witch_hut import glow_mushrooms
    glow_mushrooms(a, (4, 1.4, 0.5), n=5, big=0.7, light=True)
    # 부러진 가지 끝
    a.tube([pts[3] + Vector((0, 0.5, 1.0)), pts[3] + Vector((0.5, 2.0, 3.2)), pts[3] + Vector((1.0, 3.2, 4.0))], [0.5, 0.35, 0.15], "bark_dead", sides=6, part_step=1)
    a.collider((0, 0, 1.2), (20, 3.0, 3.0), rot=(0, 0, 0), tag="Prop")
    return a


def broadleaf_tree():
    a = Asset("BroadleafTree", "Vegetation", description="활엽수 (항구섬)")
    pts = [Vector((0.3 * math.sin(i * 0.7), 0.2 * math.cos(i), -1 + i * 3.2)) for i in range(7)]
    a.tube(pts, [1.8, 1.4, 1.2, 1.05, 0.9, 0.8, 0.7], "bark", sides=10, noise_amp=0.12, part_step=2, part_joints=True)
    a.collider((0, 0, 9), (2.6, 2.6, 20), tag="Trunk")
    top = pts[-1]
    for k in range(5):
        ang = k * 2 * math.pi / 5 + 0.2
        _branch(a, pts[4], (math.cos(ang), math.sin(ang), 0.7), 7.0, 0.6, "bark", 0, "leaf", moss=False, leaf_size=5.0)
    a.blob(top + Vector((0, 0, 3)), 7.5, "leaf", seg=14, rings=8, amp=0.28, scale=(1.3, 1.3, 0.9))
    a.blob(top + Vector((3, 2, 0)), 5.0, "leaf_dk", seg=12, rings=7, amp=0.28, scale=(1.2, 1.2, 0.85))
    a.blob(top + Vector((-3, -2, 1)), 5.0, "leaf", seg=12, rings=7, amp=0.28, scale=(1.2, 1.2, 0.85))
    return a


ASSETS = [cypress_a, cypress_b, cypress_c, mangrove, dead_tree, swamp_bush, reeds, lily_pads, fallen_log, broadleaf_tree]
