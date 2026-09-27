"""등대 (Lighthouse) — 바다 항로 중간 바위섬의 랜드마크.

석조 기단 + 흰/적색 띠 탑 + 전망 갤러리 + 유리 등실(회전 빔 마커) + 관리인 오두막.
"""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import shapes as S

H = 52.0         # 탑 몸통 높이 (기단 위)
BASE_Z = 4.0     # 기단 윗면


def _stone_ring(a, z0, z1, r0, r1, key_a="stone", key_b="stone_dk"):
    rows = max(1, int((z1 - z0) / 1.3))
    for i in range(rows):
        za = z0 + (z1 - z0) * i / rows
        zb = z0 + (z1 - z0) * (i + 1) / rows
        rr = r0 + (r1 - r0) * (i + 0.5) / rows
        n = max(8, int(2 * math.pi * rr / 3.0))
        for k in range(n):
            ang = 2 * math.pi * (k + 0.5 * (i % 2)) / n
            a.box((math.cos(ang) * rr, math.sin(ang) * rr, (za + zb) / 2), (1.3, 2 * math.pi * rr / n - 0.1, zb - za - 0.08),
                  key_a if a.rng.random() > 0.3 else key_b, rot=(0, 0, math.degrees(ang)), bevel=0.1, part=False)
    a._prim_cyl_only((0, 0, z0), (0, 0, z1), (r0 + r1) / 2 + 0.5, key_a)


def lighthouse():
    a = Asset("Lighthouse", "Landmark", description="바다 등대 (회전 빔, 전망 갤러리, 관리인 오두막)")
    # 기단 (팔각 석축)
    _stone_ring(a, -4.0, BASE_Z, 13.0, 12.0)
    a.cyl((0, 0, -4.0), (0, 0, BASE_Z - 0.2), 11.8, "stone_dk", sides=24, part=False)
    a.cyl((0, 0, BASE_Z - 0.4), (0, 0, BASE_Z), 12.4, "stone", sides=24, bevel=0.15)
    a.collider((0, 0, 0), (BASE_Z + 4, 26, 26), rot=(0, 90, 0), shape="Cylinder", tag="Floor")
    # 탑 몸통: 테이퍼 + 흰/빨강 띠
    r_bot, r_top = 8.0, 5.6
    bands = 6
    for i in range(bands):
        z0 = BASE_Z + H * i / bands
        z1 = BASE_Z + H * (i + 1) / bands
        ra = r_bot + (r_top - r_bot) * i / bands
        rb = r_bot + (r_top - r_bot) * (i + 1) / bands
        a.cyl((0, 0, z0), (0, 0, z1), ra, "paint_red" if i % 2 else "paint_white", r1=rb, sides=28)
        a.cyl((0, 0, z1 - 0.15), (0, 0, z1 + 0.15), rb + 0.12, "stone_dk", sides=28)
    a.collider((0, 0, BASE_Z + H / 2), (H, 2 * r_bot, 2 * r_bot), rot=(0, 90, 0), shape="Cylinder", tag="Wall")
    # 창문 (나선형 배치)
    for k in range(6):
        z = BASE_Z + 8 + k * 7.0
        ang = k * 1.9
        r = r_bot + (r_top - r_bot) * (z - BASE_Z) / H
        c = Vector((math.cos(ang) * (r + 0.05), math.sin(ang) * (r + 0.05), z))
        a.box(c, (0.5, 1.6, 2.6), "wood_dark", rot=(0, 0, math.degrees(ang)), bevel=0.05)
        a.box(c + Vector((math.cos(ang) * 0.1, math.sin(ang) * 0.1, 0)), (0.3, 1.1, 2.0), "glow_lantern", rot=(0, 0, math.degrees(ang)), bevel=0.0)
    # 문
    a.box((0, -r_bot - 0.1, BASE_Z + 3.6), (3.6, 0.6, 7.2), "wood_red", bevel=0.08)
    a.box((0, -r_bot - 0.25, BASE_Z + 7.6), (4.6, 0.8, 0.8), "stone_dk", bevel=0.1)
    S.lantern(a, (2.6, -r_bot - 1.2, BASE_Z + 6.4), bracket=(0, 1))
    # 갤러리 (전망대)
    GZ = BASE_Z + H
    a.cyl((0, 0, GZ - 0.3), (0, 0, GZ + 0.5), r_top + 3.2, "stone", sides=28, bevel=0.1)
    for k in range(14):
        ang = k * 2 * math.pi / 14
        a.box_between((math.cos(ang) * (r_top + 0.2), math.sin(ang) * (r_top + 0.2), GZ - 2.6), (math.cos(ang) * (r_top + 2.8), math.sin(ang) * (r_top + 2.8), GZ - 0.3), 0.5, "stone_dk", width=0.5)
    n = 28
    for k in range(n):
        ang = k * 2 * math.pi / n
        a.cyl((math.cos(ang) * (r_top + 2.9), math.sin(ang) * (r_top + 2.9), GZ + 0.5), (math.cos(ang) * (r_top + 2.9), math.sin(ang) * (r_top + 2.9), GZ + 3.4), 0.1, "iron", sides=4)
    for z in (GZ + 3.4, GZ + 1.9):
        ring = [Vector((math.cos(t) * (r_top + 2.9), math.sin(t) * (r_top + 2.9), z)) for t in [i * 2 * math.pi / 28 for i in range(29)]]
        a.tube(ring, 0.12, "iron", sides=5, caps=False, part_step=4)
    a.collider((0, 0, GZ + 0.1), (0.8, 2 * (r_top + 3.2), 2 * (r_top + 3.2)), rot=(0, 90, 0), shape="Cylinder", tag="Floor")
    # 등실 (유리 + 철골)
    LR = 4.2
    LZ0, LZ1 = GZ + 0.5, GZ + 8.5
    a.cyl((0, 0, LZ0), (0, 0, LZ0 + 1.6), LR + 0.2, "iron", sides=12, bevel=0.05)
    a.cyl((0, 0, LZ0 + 1.6), (0, 0, LZ1), LR, "glass", sides=12, caps=False)
    for k in range(12):
        ang = (k + 0.5) * 2 * math.pi / 12
        a.box((math.cos(ang) * LR, math.sin(ang) * LR, (LZ0 + 1.6 + LZ1) / 2), (0.25, 0.25, LZ1 - LZ0 - 1.6), "iron", rot=(0, 0, math.degrees(ang)), bevel=0.0)
    a.cyl((0, 0, LZ1), (0, 0, LZ1 + 0.4), LR + 0.5, "iron", sides=12)
    # 램프 (회전 빔 광원)
    a.cyl((0, 0, LZ0 + 1.6), (0, 0, LZ0 + 3.0), 1.2, "brass", sides=10)
    a.sphere((0, 0, LZ0 + 4.4), 1.5, "glow_lantern", seg=14, rings=9)
    a.light((0, 0, LZ0 + 4.4), color=(255, 226, 170), range_=60, brightness=3.0, shadows=False)
    a.marker("Beacon", (0, 0, LZ0 + 4.4))
    # 돔 지붕 + 풍향계
    prof = [(LZ1 + 0.4, LR + 0.6), (LZ1 + 1.6, LR * 0.9), (LZ1 + 3.2, LR * 0.55), (LZ1 + 4.2, 0.4)]
    a.tube([Vector((0, 0, z)) for z, _ in prof], [r for _, r in prof], "paint_red", sides=16, part_step=1)
    a.cyl((0, 0, LZ1 + 4.0), (0, 0, LZ1 + 7.5), 0.12, "iron", sides=5)
    a.sphere((0, 0, LZ1 + 4.4), 0.45, "brass", seg=8, rings=6)
    a.box((0.9, 0, LZ1 + 6.6), (2.4, 0.08, 0.9), "iron", bevel=0.0)
    a.box((-0.6, 0, LZ1 + 6.6), (0.9, 0.08, 0.5), "iron", rot=(45, 0, 0), bevel=0.0)
    # 관리인 오두막 (탑 옆, 기단 위)
    with a.at(loc=(0, 0, 0), rot=(0, 0, 40)):
        hx0, hx1, hy0, hy1 = 8.0, 12.5, -3.5, 3.5
        z0 = BASE_Z
        S.plank_wall(a, (hx1, hy0), (hx1, hy1), z0, z0 + 7, openings=[(2.2, 4.8, z0 + 3.0, z0 + 5.4)], keys=("paint_white", "wood_pale"), battens=False)
        S.plank_wall(a, (hx0, hy0), (hx1, hy0), z0, z0 + 7, openings=[(1.2, 3.8, z0, z0 + 6.2)], keys=("paint_white", "wood_pale"), battens=False)
        S.plank_wall(a, (hx1, hy1), (hx0, hy1), z0, z0 + 7, keys=("paint_white", "wood_pale"), battens=False)
        prof = (lambda u, s=hy1 - hy0: z0 + 7 + (s / 2 - abs(u - s / 2)) * math.tan(math.radians(38)) - 0.2)
        S.plank_wall(a, (hx1, hy0), (hx1, hy1), z0 + 6.8, z0 + 7, top_profile=prof, battens=False, collider=False, jag=0.0, keys=("paint_white", "wood_pale"))
        S.gable_roof(a, (hx0 + hx1) / 2, 0, z0 + 7, hx1 - hx0, hy1 - hy0, pitch=38, overhang=1.0, gable_over=0.8, keys=("paint_red", "brick", "paint_red"), moss=0.0)
        with a.at(loc=(hx0, hy0, 0)):
            S.door(a, 1.2, 2.6, 6.2, z0, keys=("wood_teal",), open_angle=0)
    a.marker("Entrance", (0, -r_bot - 3, BASE_Z + 0.1), rot=(0, 0, 180))
    return a


ASSETS = [lighthouse]
