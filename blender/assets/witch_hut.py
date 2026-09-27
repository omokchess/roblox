"""늪 마녀의 오두막 (Witch Hut).

비틀린 뿌리 기둥 위의 기울어진 오두막, 뾰족하게 꺾인 지붕, 가마솥, 해골 부적, 발광 버섯.
"""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import shapes as S


def _root_stilt(a, top, spread=3.0, z_bottom=-6.0):
    """나무 뿌리처럼 휘어진 기둥."""
    top = Vector(top)
    ang = a.rng.uniform(0, 2 * math.pi)
    foot = top + Vector((math.cos(ang) * spread, math.sin(ang) * spread, 0))
    foot.z = z_bottom
    pts = []
    for i in range(8):
        t = i / 7
        p = foot.lerp(top, t)
        bulge = math.sin(t * math.pi) * a.rng.uniform(0.6, 1.4)
        p += Vector((math.cos(ang + 1.3) * bulge, math.sin(ang + 1.3) * bulge, 0))
        pts.append(p)
    radii = [0.95 - 0.35 * (i / 7) for i in range(8)]
    a.tube(pts, radii, "bark", sides=9, noise_amp=0.18, noise_freq=0.9, part_step=2, part_joints=True)
    # 곁뿌리
    for k in range(2):
        b0 = pts[2]
        ang2 = ang + a.rng.uniform(-1.5, 1.5)
        b1 = b0 + Vector((math.cos(ang2) * 3, math.sin(ang2) * 3, -2.5))
        b2 = b1 + Vector((math.cos(ang2) * 1.5, math.sin(ang2) * 1.5, -3.0))
        a.tube([b0, (b0 + b1) / 2 + Vector((0, 0, 0.6)), b1, b2], [0.5, 0.42, 0.3, 0.2], "bark", sides=7, noise_amp=0.15, part_step=1)
    a.collider(((top.x + foot.x) / 2, (top.y + foot.y) / 2, (top.z + z_bottom) / 2), (1.6, 1.6, top.z - z_bottom), tag="Stilt")


def _skull(a, pos, s=0.5, yaw=0.0):
    with a.at(loc=pos, rot=(0, 0, yaw), scale=s):
        a.sphere((0, 0, 0.2), 1.0, "bone", seg=10, rings=7, scale=(0.85, 1.0, 0.9))
        a.box((0, -0.55, -0.55), (1.1, 0.7, 0.6), "bone", bevel=0.2)
        with a.no_parts():
            for sx in (-1, 1):
                a.sphere((sx * 0.35, -0.8, 0.15), 0.26, "wood_wet", seg=6, rings=4)
            a.sphere((0, -0.95, -0.25), 0.12, "wood_wet", seg=5, rings=3)


def _charm(a, top, length=2.5):
    """매달린 부적: 끈 + 뼈 + 깃털."""
    top = Vector(top)
    with a.no_parts():
        a.cyl(top, top - Vector((0, 0, length)), 0.04, "rope_dk", sides=4)
        b = top - Vector((0, 0, length))
        a.box(b - Vector((0, 0, 0.3)), (0.12, 0.12, 0.7), "bone", rot=(0, 0, 45), bevel=0.02)
        a.box(b - Vector((0, 0, 0.3)), (0.7, 0.12, 0.12), "bone", bevel=0.02)
        for k in range(3):
            a.box(b - Vector((0.2 * (k - 1), 0, 0.9)), (0.12, 0.05, 0.8), ("cloth_red", "cloth_purple", "wood_dark")[k], rot=(0, 10 * (k - 1), 0), bevel=0.0)


def glow_mushrooms(a, center, n=6, spread=1.8, big=1.0, key_cap="glow_mushroom", light=True):
    c = Vector(center)
    for i in range(n):
        ang = a.rng.uniform(0, 2 * math.pi)
        r = a.rng.uniform(0, spread)
        p = c + Vector((math.cos(ang) * r, math.sin(ang) * r, 0))
        h = a.rng.uniform(0.6, 1.8) * big
        cr = a.rng.uniform(0.35, 0.8) * big
        tilt = (a.rng.uniform(-12, 12), a.rng.uniform(-12, 12), 0)
        with a.at(loc=p, rot=tilt):
            a.cyl((0, 0, 0), (0, 0, h), 0.12 * big + 0.05, "mushroom_stem", r1=0.09 * big + 0.04, sides=6)
            a.sphere((0, 0, h), cr, key_cap, seg=10, rings=6, scale=(1, 1, 0.45))
    if light:
        a.light(c + Vector((0, 0, 1.2 * big)), color=(110, 255, 205), range_=12 * big, brightness=1.0)


def cauldron(a, pos, r=2.0, brew="cauldron_brew", fire=True):
    p = Vector(pos)
    with a.at(loc=p):
        # 다리
        for k in range(3):
            ang = k * 2 * math.pi / 3
            a.box_between((math.cos(ang) * r * 0.7, math.sin(ang) * r * 0.7, r * 0.9), (math.cos(ang) * r * 0.95, math.sin(ang) * r * 0.95, 0), 0.3, "iron", width=0.3)
        prof = [(r * 0.35, r * 0.2), (r * 0.6, r * 0.8), (r * 1.0, r * 1.0), (r * 1.45, r * 0.92), (r * 1.62, r * 0.8), (r * 1.72, r * 0.86)]
        with a.no_parts():
            a.tube([Vector((0, 0, z)) for z, _ in prof], [rr for _, rr in prof], "iron", sides=16, caps=True, part=False)
            ring = [Vector((math.cos(t) * r * 0.88, math.sin(t) * r * 0.88, r * 1.72)) for t in [i * 2 * math.pi / 16 for i in range(17)]]
            a.tube(ring, 0.16, "iron", sides=5, caps=False, part=False)
            # 손잡이
            for sx in (-1, 1):
                arc = [Vector((sx * r * (0.95 + 0.2 * math.sin(t * math.pi)), 0, r * 1.3 + 0.5 * math.cos(t * math.pi))) for t in [i / 6 for i in range(7)]]
                a.tube(arc, 0.1, "iron", sides=5, part=False)
        a._prim_cyl_only((0, 0, r * 0.3), (0, 0, r * 1.7), r * 0.95, "iron")
        a.cyl((0, 0, r * 1.45), (0, 0, r * 1.55), r * 0.8, brew, sides=16)
        with a.no_parts():
            for k in range(5):
                ang = a.rng.uniform(0, 2 * math.pi)
                rr = a.rng.uniform(0, r * 0.6)
                a.sphere((math.cos(ang) * rr, math.sin(ang) * rr, r * 1.58), a.rng.uniform(0.15, 0.35), brew, seg=6, rings=4, scale=(1, 1, 0.6))
        if fire:
            for k in range(5):
                ang = k * 2 * math.pi / 5
                a.cyl((math.cos(ang) * 1.6, math.sin(ang) * 1.6, 0.2), (math.cos(ang) * 0.3, math.sin(ang) * 0.3, 0.45), 0.25, "wood_dark", sides=6)
            a.sphere((0, 0, 0.5), 0.7, "glow_fire", seg=8, rings=5, scale=(1.2, 1.2, 0.8))
    a.light(p + Vector((0, 0, r * 2.2)), color=(140, 255, 110), range_=20, brightness=1.6)
    if fire:
        a.light(p + Vector((0, 0, 0.8)), color=(255, 120, 50), range_=14, brightness=1.4)
    a.marker("Cauldron", (p.x, p.y, p.z + r * 1.6))
    a.collider((p.x, p.y, p.z + r * 0.9), (r * 2, r * 2, r * 1.8), shape="Block", tag="Prop")


def witch_hut():
    a = Asset("WitchHut", "Building", description="늪 마녀의 오두막 (뒤틀린 뿌리 기둥, 가마솥)")
    Z = 6.5
    # 뿌리 기둥
    for (x, y) in ((-7, -6), (7, -6), (-7, 7), (7, 7), (0, 8), (-8, 0.5), (8, 0.5)):
        _root_stilt(a, (x, y, Z - 0.8), spread=a.rng.uniform(2.0, 3.5))
    a.box((0, 0.5, Z - 1.3), (17, 15, 1.0), "wood_dark", bevel=0.1)
    S.plank_floor(a, -9, 9, -12, 9, Z, along="x", keys=("wood_moss", "wood_b", "wood_dark"), missing=0.05)
    # 기울어진 집
    with a.at(loc=(0, 1.2, 0), rot=(1.5, -2.5, 3)):
        x0, x1, y0, y1 = -6.5, 6.5, -5, 7
        zt = Z + 10
        keys = ("wood_moss", "wood_dark", "wood_b", "wood_wet")
        for (cx, cy) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            S.post(a, cx, cy, Z, zt + 0.5, 0.85, "bark")
        S.plank_wall(a, (x0, y0), (x1, y0), Z, zt, openings=[(4.0, 8.4, Z, Z + 7.6)], keys=keys, jag=0.5, lean=-2)
        with a.at(loc=(x0, y0, 0)):
            S.door(a, 4.0, 4.4, 7.6, Z, keys=("cloth_purple", "wood_dark"), open_angle=70)
        S.plank_wall(a, (x1, y0), (x1, y1), Z, zt, openings=[(4.0, 7.5, Z + 4.0, Z + 7.5)], keys=keys, jag=0.5, lean=2)
        S.plank_wall(a, (x1, y1), (x0, y1), Z, zt, keys=keys, jag=0.5)
        S.plank_wall(a, (x0, y1), (x0, y0), Z, zt, openings=[(5.0, 8.0, Z + 4.5, Z + 7.5)], keys=keys, jag=0.5, lean=-3)
        # 둥근 창 발광
        a.cyl((x1 + 0.2, 1.75, Z + 5.75), (x1 + 0.5, 1.75, Z + 5.75), 1.7, "wood_dark", sides=14)
        a.cyl((x1 + 0.1, 1.75, Z + 5.75), (x1 + 0.55, 1.75, Z + 5.75), 1.35, "glow_potion", sides=14)
        a.light((x1 + 1.5, 1.75, Z + 5.75), color=(180, 110, 255), range_=16, brightness=1.4)
        # 천 조각 패치
        for (px, py, pz) in ((x0 + 2.5, y0 - 0.3, Z + 8.0), (x1 + 0.3, y1 - 2.0, Z + 2.5), (x0 - 0.3, y0 + 2.5, Z + 3.0)):
            a.box((px, py, pz), (1.8, 0.1, 1.6) if abs(py - y0 + 0.3) < 0.01 else (0.1, 1.8, 1.6), "cloth_purple", rot=(0, a.rng.uniform(-10, 10), 0), bevel=0.0)
        span = y1 - y0
        pitch = 56
        for xw in (x0, x1):
            prof = (lambda u, s=span: zt + (s / 2 - abs(u - s / 2)) * math.tan(math.radians(pitch)) - 0.3)
            S.plank_wall(a, (xw, y0), (xw, y1), zt - 0.4, zt, top_profile=prof, battens=False, collider=False, jag=0.0, keys=keys)
        zr = S.gable_roof(a, 0, (y0 + y1) / 2, zt, x1 - x0, span, pitch=pitch, overhang=1.6, gable_over=1.2,
                          keys=("shingle_c", "wood_moss", "shingle_a"), moss=0.2)
        # 꺾인 첨탑
        base = Vector((x1 - 1.0, (y0 + y1) / 2, zr + 0.2))
        pts = [base + Vector((0.4 * i * i * 0.2, 0, i * 1.1)) for i in range(7)]
        a.tube(pts, [0.9, 0.8, 0.65, 0.5, 0.35, 0.2, 0.05], "shingle_c", sides=8, part_step=2)
        # 굴뚝 (구부러진 철관)
        cp = [Vector((x0 + 2.0, y1 - 2.0, zr - 3.0)), Vector((x0 + 2.0, y1 - 2.0, zr + 1.0)), Vector((x0 + 2.5, y1 - 2.2, zr + 2.6)), Vector((x0 + 3.6, y1 - 2.4, zr + 3.4)), Vector((x0 + 4.2, y1 - 2.4, zr + 4.6))]
        a.tube(cp, 0.55, "iron", sides=10, part_step=1, part_joints=True)
        a.cyl(cp[-1], cp[-1] + Vector((0.2, 0, 0.5)), 0.8, "iron", sides=10)
        a.marker("Smoke", tuple(cp[-1] + Vector((0.2, 0, 0.8))), color="green")
        # 실내
        a.box((x0 + 1.5, 2.0, Z + 3.5), (1.2, 6.0, 0.25), "wood_dark", bevel=0.03)
        for k in range(5):
            S.bottle(a, (x0 + 1.5, -0.4 + k * 1.2, Z + 3.65), h=0.9, key=("glow_potion", "glass_green", "glow_mushroom", "glass", "glow_potion")[k])
        a.box((1.0, 4.5, Z + 2.2), (5.0, 3.0, 0.3), "wood_dark", bevel=0.05)
        _skull(a, (0.5, 4.5, Z + 2.65), s=0.45)
        S.candle(a, (2.2, 4.8, Z + 2.35), light=True)
        S.candle(a, (2.8, 4.0, Z + 2.35), h=0.4)
        S.lantern(a, (0, 1, zt - 1.2), hang=0.5, glow="glow_potion", color=(180, 110, 255), rng_range=16)
    # 베란다: 가마솥
    cauldron(a, (-3.5, -8.5, Z), r=1.7)
    # 부적 / 해골
    for (x, y) in ((-8.5, -11.5), (8.5, -11.5), (8.5, 8.5), (-8.5, 8.5)):
        S.post(a, x, y, Z - 0.5, Z + 6.5, 0.55, "bark")
        _skull(a, (x, y, Z + 7.0), s=0.55, yaw=a.rng.uniform(-30, 30))
    for x in (-6, -2, 2, 6):
        _charm(a, (x, -6.6, Z + 9.2), length=a.rng.uniform(1.8, 3.0))
    a.box_between((-8.5, -11.5, Z + 5.5), (8.5, -11.5, Z + 5.5), 0.14, "rope_dk", width=0.14)
    for x in (-5.5, -1.0, 3.5, 6.5):
        _charm(a, (x, -11.5, Z + 5.4), length=1.2)
    # 약병 선반 (밖)
    a.box((6.5, -10.0, Z + 2.6), (3.6, 1.2, 0.25), "wood_dark", bevel=0.03)
    for k in range(4):
        S.bottle(a, (5.2 + k * 0.9, -10.0, Z + 2.75), h=0.8, key=("glass_green", "glow_potion", "glass", "glow_mushroom")[k])
    for sx in (-1, 1):
        a.box((6.5 + sx * 1.6, -10.0, Z + 1.3), (0.25, 1.0, 2.6), "wood_dark", bevel=0.03)
    # 계단 (앞, 물가로)
    S.stairs(a, (0, -21.0, 0.2), (0, -12.2, Z), width=4.0, key_tread=("wood_moss", "wood_dark"), rails=False)
    a.marker("Entrance", (0, -21.5, 0.4), rot=(0, 0, 180))
    # 버섯 군락 & 이끼
    for c in ((-9.5, -4, 0.2), (9.0, 6.0, 0.2), (-4, 10.5, 0.2), (5, -13.5, 0.3)):
        glow_mushrooms(a, c, n=7, big=1.2)
    glow_mushrooms(a, (-7.5, -11, Z), n=4, big=0.6, light=False)
    for k in range(4):
        S.hanging_moss(a, (a.rng.uniform(-9, 9), a.rng.uniform(-12, 8), Z - 1.3), length=3.5, strands=4)
    return a


ASSETS = [witch_hut]
