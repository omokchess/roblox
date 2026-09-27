"""늪의 사당 (MireShrine) — 보스 '늪의 군주' 아레나.

원형 석판 광장, 부서진 기둥 8개, 입구 아치, 중앙 제단(발광 룬 구슬), 화로 4개.
"""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import shapes as S

TOP = 3.0       # 광장 윗면
R = 34.0        # 광장 반지름


def _pillar(a, x, y, h, r=1.6, broken=False, rune=True):
    base = Vector((x, y, TOP))
    a.box(base + Vector((0, 0, 0.6)), (r * 2.8, r * 2.8, 1.2), "stone_ruin", rot=(0, 0, a.rng.uniform(-5, 5)), bevel=0.2)
    a.box(base + Vector((0, 0, 1.5)), (r * 2.4, r * 2.4, 0.6), "stone_ruin", bevel=0.15)
    # 드럼(원통 마디)들을 쌓아 올림 (약간씩 어긋나게)
    z = TOP + 1.8
    drums = max(1, int(h / 3.2))
    for i in range(drums):
        dh = h / drums
        off = Vector((a.rng.uniform(-0.12, 0.12), a.rng.uniform(-0.12, 0.12), 0))
        key = "stone_ruin" if a.rng.random() > 0.3 else "stone_moss"
        a.cyl(Vector((x, y, z)) + off, Vector((x, y, z + dh - 0.08)) + off, r, key, sides=16, bevel=0.12)
        with a.no_parts():
            # 세로 홈 (플루팅) 표현: 얇은 어두운 띠
            for k in range(8):
                ang = k * 2 * math.pi / 8 + 0.2
                p = Vector((x + math.cos(ang) * (r + 0.02), y + math.sin(ang) * (r + 0.02), z + dh / 2)) + off
                a.box(p, (0.18, 0.18, dh - 0.4), "stone_dk", rot=(0, 0, math.degrees(ang)), bevel=0.0)
        z += dh
    if broken:
        # 부러진 윗면: 비스듬한 파편
        a.box((x + 0.3, y, z + 0.4), (r * 1.7, r * 1.5, 1.2), "stone_ruin", rot=(a.rng.uniform(-18, 18), a.rng.uniform(-18, 18), a.rng.uniform(0, 90)), bevel=0.2)
        # 바닥에 떨어진 드럼
        ang = a.rng.uniform(0, 2 * math.pi)
        fx, fy = x + math.cos(ang) * 5, y + math.sin(ang) * 5
        a.cyl((fx - math.sin(ang) * 1.5, fy + math.cos(ang) * 1.5, TOP + r * 0.95), (fx + math.sin(ang) * 1.5, fy - math.cos(ang) * 1.5, TOP + r * 0.95), r, "stone_moss", sides=16, bevel=0.12)
        a.collider((fx, fy, TOP + r), (3.0, r * 2, r * 2), rot=(0, 0, math.degrees(ang)), tag="Prop")
    else:
        a.box((x, y, z + 0.5), (r * 2.8, r * 2.8, 1.0), "stone_ruin", bevel=0.2)
        a.box((x, y, z + 1.3), (r * 3.2, r * 3.2, 0.6), "stone_ruin", bevel=0.15)
        z += 1.6
    if rune:
        ang = math.atan2(-y, -x)
        p = Vector((x + math.cos(ang) * (r + 0.05), y + math.sin(ang) * (r + 0.05), TOP + 4.5))
        for k in range(3):
            a.box(p + Vector((0, 0, k * 1.1)), (0.12, 0.7 - 0.15 * k, 0.18), "stone_rune", rot=(0, 0, math.degrees(ang)), bevel=0.0)
        a.box(p + Vector((0, 0, 1.1)), (0.12, 0.18, 2.4), "stone_rune", rot=(0, 0, math.degrees(ang)), bevel=0.0)
    # 덩굴 (메시)
    with a.no_parts():
        for k in range(2):
            ang0 = a.rng.uniform(0, 2 * math.pi)
            pts = []
            for i in range(14):
                t = i / 13
                ang = ang0 + t * 3.0
                pts.append(Vector((x + math.cos(ang) * (r + 0.15), y + math.sin(ang) * (r + 0.15), TOP + 1.8 + t * (z - TOP - 2.0))))
            a.tube(pts, 0.14, "leaf_dk", sides=4, part=False)
    a.collider((x, y, (TOP + z) / 2), (r * 2.4, r * 2.4, z - TOP), tag="Pillar")
    return z


def _brazier(a, x, y):
    p = Vector((x, y, TOP))
    for k in range(3):
        ang = k * 2 * math.pi / 3
        a.box_between(p + Vector((math.cos(ang) * 1.2, math.sin(ang) * 1.2, 0)), p + Vector((math.cos(ang) * 0.6, math.sin(ang) * 0.6, 3.2)), 0.25, "iron", width=0.25)
    prof = [(3.0, 0.4), (3.3, 1.2), (3.9, 1.5), (4.1, 1.55)]
    a.tube([p + Vector((0, 0, z)) for z, _ in prof], [r for _, r in prof], "iron", sides=12, part_step=3)
    a.blob(p + Vector((0, 0, 4.3)), 0.9, "glow_mushroom", seg=8, rings=5, amp=0.35, scale=(1.2, 1.2, 1.3))
    a.light(p + Vector((0, 0, 5.2)), color=(110, 255, 190), range_=28, brightness=2.0)
    a.marker("Flame", tuple(p + Vector((0, 0, 4.4))), color="green")
    a.collider(p + Vector((0, 0, 2.0)), (2.4, 2.4, 4.0), tag="Prop")


def mire_shrine():
    a = Asset("MireShrine", "Landmark", description="늪의 사당 — 보스 아레나 (원형 석판 광장, 기둥, 제단)")
    # 기초: 계단식 원형 기단 (물속까지)
    for i, (rr, z0, z1) in enumerate(((R + 5.0, -4.0, TOP - 2.2), (R + 2.2, TOP - 2.2, TOP - 1.0))):
        n = int(2 * math.pi * rr / 4.2)
        for k in range(n):
            ang = 2 * math.pi * (k + 0.5 * (i % 2)) / n
            c = Vector((math.cos(ang) * (rr - 1.6), math.sin(ang) * (rr - 1.6), (z0 + z1) / 2))
            a.box(c, (3.4, 2 * math.pi * rr / n - 0.12, z1 - z0), "stone_moss" if a.rng.random() < 0.35 else "stone_ruin",
                  rot=(a.rng.uniform(-1, 1), a.rng.uniform(-1, 1), math.degrees(ang)), bevel=0.18, part=False)
        a._prim_cyl_only((0, 0, z0), (0, 0, z1), rr, "stone_ruin")
    # 코어 (안쪽 채움)
    a.cyl((0, 0, -4.0), (0, 0, TOP - 1.0), R - 1.0, "stone_dk", sides=32, part=False)
    # 광장 석판: 동심원 링
    rings = [(0.0, 7.5), (7.5, 14.0), (14.0, 21.0), (21.0, 28.0), (28.0, R)]
    for ri, (r0, r1) in enumerate(rings):
        if r0 == 0:
            continue
        n = int(2 * math.pi * (r0 + r1) / 2 / 4.5)
        for k in range(n):
            if a.rng.random() < 0.04:
                continue
            a0 = 2 * math.pi * (k + (ri % 2) * 0.5) / n
            a1 = 2 * math.pi * (k + 1 + (ri % 2) * 0.5) / n
            am = (a0 + a1) / 2
            rm = (r0 + r1) / 2
            w = rm * (a1 - a0) - 0.14
            key = "stone_moss" if a.rng.random() < 0.3 else ("stone_ruin" if a.rng.random() < 0.7 else "stone")
            a.box((math.cos(am) * rm, math.sin(am) * rm, TOP - 0.5 + a.rng.uniform(-0.06, 0.06)), (r1 - r0 - 0.14, w, 1.0), key,
                  rot=(a.rng.uniform(-0.8, 0.8), a.rng.uniform(-0.8, 0.8), math.degrees(am)), bevel=0.12)
    # 중앙 제단 (계단식)
    z0 = TOP
    for i, (rr, h) in enumerate(((7.5, 0.9), (5.2, 0.9), (3.4, 1.4))):
        a.cyl((0, 0, z0 - 0.2), (0, 0, z0 + h), rr, "stone" if i == 1 else "stone_ruin", sides=24, bevel=0.15)
        a.collider((0, 0, z0 + h / 2), (h, rr * 2, rr * 2), rot=(0, 90, 0), shape="Cylinder", tag="Floor")
        z0 += h
    top_z = z0
    # 룬 구슬 + 받침 발톱
    a.sphere((0, 0, top_z + 3.2), 1.6, "stone_rune", seg=16, rings=10)
    for k in range(4):
        ang = k * math.pi / 2 + 0.4
        pts = [Vector((math.cos(ang) * 2.4, math.sin(ang) * 2.4, top_z)), Vector((math.cos(ang) * 2.6, math.sin(ang) * 2.6, top_z + 2.0)),
               Vector((math.cos(ang) * 1.9, math.sin(ang) * 1.9, top_z + 3.8)), Vector((math.cos(ang) * 1.0, math.sin(ang) * 1.0, top_z + 4.6))]
        a.tube(pts, [0.45, 0.4, 0.3, 0.1], "stone_dk", sides=7, part_step=1)
    a.light((0, 0, top_z + 3.2), color=(90, 255, 170), range_=40, brightness=2.5, shadows=True)
    a.marker("Orb", (0, 0, top_z + 3.2))
    # 룬 링 (바닥 발광 문양)
    for k in range(24):
        ang = k * 2 * math.pi / 24
        if k % 3 == 0:
            continue
        a.box((math.cos(ang) * 10.8, math.sin(ang) * 10.8, TOP + 0.03), (0.35, 1.6, 0.08), "stone_rune", rot=(0, 0, math.degrees(ang)), bevel=0.0)
    # 기둥 8개
    for k in range(8):
        ang = k * 2 * math.pi / 8 + math.pi / 8
        if abs(math.degrees(ang) - 270) < 30:
            continue
        x, y = math.cos(ang) * 29.5, math.sin(ang) * 29.5
        broken = k in (1, 3, 6)
        _pillar(a, x, y, a.rng.uniform(9, 12) if not broken else a.rng.uniform(4, 7), broken=broken)
    # 입구 아치 (-Y)
    for sx in (-1, 1):
        _pillar(a, sx * 6.0, -R + 2.5, 13.0, r=1.5, rune=False)
    arch_c = Vector((0, -R + 2.5, TOP + 16.6))
    n = 9
    for i in range(n):
        t0 = math.pi * i / n
        t1 = math.pi * (i + 1) / n
        tm = (t0 + t1) / 2
        p = arch_c + Vector((math.cos(tm) * 6.0, 0, math.sin(tm) * 3.2))
        a.box(p, (2.3, 3.0, 1.5), "stone_ruin" if i != n // 2 else "stone_moss", rot=(0, -math.degrees(tm) + 90, 0), bevel=0.15)
    a.box(arch_c + Vector((0, -1.6, 3.6)), (1.2, 0.2, 1.8), "stone_rune", bevel=0.0)
    # 입구 계단 (광장 밖으로)
    for i in range(4):
        y = -R - 1.0 - i * 2.2
        z = TOP - 0.6 - i * 1.0
        a.box((0, y, z - 0.5), (14.0 - i * 0.6, 2.4, 1.0 + i * 0.1), "stone_ruin" if i % 2 else "stone_moss", bevel=0.18)
    a.collider_between((0, -R + 0.5, TOP + 0.02), (0, -R - 9.5, TOP - 4.0), 13.0, 1.2, tag="Stairs")
    # 화로 4개
    for k in range(4):
        ang = k * math.pi / 2 + math.pi / 4
        _brazier(a, math.cos(ang) * 18.5, math.sin(ang) * 18.5)
    # 광장 콜라이더 (원기둥)
    a.collider((0, 0, TOP - 3.5), (7.0, 2 * R, 2 * R), rot=(0, 90, 0), shape="Cylinder", tag="Floor")
    a.collider((0, 0, -2.0), (4.0, 2 * (R + 5.0), 2 * (R + 5.0)), rot=(0, 90, 0), shape="Cylinder", tag="Floor")
    # 이끼 덩어리 & 버섯
    from assets.witch_hut import glow_mushrooms
    with a.no_parts():
        for k in range(22):
            ang = a.rng.uniform(0, 2 * math.pi)
            rr = a.rng.uniform(8, R - 1)
            a.blob((math.cos(ang) * rr, math.sin(ang) * rr, TOP + 0.05), a.rng.uniform(0.6, 1.6), "moss", seg=8, rings=5, amp=0.3, scale=(1.5, 1.3, 0.28))
    for c in ((20, 16), (-22, 12), (-14, -24), (25, -10)):
        glow_mushrooms(a, (c[0], c[1], TOP), n=5, big=0.9, light=False)
    a.marker("BossSpawn", (0, 12, TOP + 0.2), rot=(0, 0, 180))
    a.marker("ArenaCenter", (0, 0, TOP), radius=R)
    a.marker("PlayerEntry", (0, -R - 6, TOP - 2.0))
    return a


def ruin_pillar():
    global TOP
    a = Asset("RuinPillar", "Landmark", description="부서진 고대 기둥 (늪 곳곳의 유적)")
    old = TOP
    TOP = 0.0
    try:
        _pillar(a, 0, 0, 7.5, r=1.5, broken=True)
    finally:
        TOP = old
    return a


def ruin_arch():
    global TOP
    a = Asset("RuinArch", "Landmark", description="무너져가는 고대 아치")
    old = TOP
    TOP = 0.0
    try:
        for sx in (-1, 1):
            _pillar(a, sx * 6.0, 0, 12.0, r=1.4, rune=(sx > 0))
        c = Vector((0, 0, 15.0))
        for i in range(7):
            t = math.pi * (i + 0.5) / 9
            p = c + Vector((math.cos(t) * 6.0, 0, math.sin(t) * 3.0))
            a.box(p, (2.2, 2.8, 1.4), "stone_ruin" if i % 3 else "stone_moss", rot=(0, -math.degrees(t) + 90, 0), bevel=0.15)
        a.box((-5.5, 2.5, 0.6), (2.4, 2.0, 1.2), "stone_moss", rot=(10, 20, 35), bevel=0.2)
    finally:
        TOP = old
    return a


ASSETS = [mire_shrine, ruin_pillar, ruin_arch]
