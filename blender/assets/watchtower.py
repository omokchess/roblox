"""감시탑 (Watchtower) — 해안/마을 경계의 높은 나무 망루."""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import shapes as S


def watchtower():
    a = Asset("Watchtower", "Building", description="늪 감시탑 (사다리, 전망대, 경종)")
    base_h, top_h = 6.0, 3.8   # 기둥 하단/상단 반폭
    Z0, ZP = -6.0, 34.0         # 기둥 바닥, 전망대 바닥
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    posts = []
    for sx, sy in corners:
        b = Vector((sx * base_h, sy * base_h, Z0))
        t = Vector((sx * top_h, sy * top_h, ZP - 0.8))
        a.cyl(b, b.lerp(t, (0.9 - Z0) / (ZP - Z0)), 0.95, "wood_wet", sides=10)
        a.cyl(b.lerp(t, (0.9 - Z0) / (ZP - Z0)), t, 0.9, "wood_dark", r1=0.75, sides=10, bevel=0.1)
        posts.append((b, t))
        a.collider((b + t) / 2, (1.6, 1.6, (t - b).length), rot=None, tag="Stilt")
    # 층별 가로보 + X 버팀
    levels = [2.0, 11.0, 20.0, 28.0]
    def at_z(p, z):
        b, t = p
        return b.lerp(t, (z - b.z) / (t.z - b.z))
    for i, z in enumerate(levels):
        for k in range(4):
            p0, p1 = at_z(posts[k], z), at_z(posts[(k + 1) % 4], z)
            a.box_between(p0, p1, 0.6, "wood_dark", width=0.5, bevel=0.08)
            if i < len(levels) - 1:
                z2 = levels[i + 1]
                q0, q1 = at_z(posts[k], z2), at_z(posts[(k + 1) % 4], z2)
                a.box_between(p0, q1, 0.4, "wood_b", width=0.35)
                a.box_between(p1, q0, 0.4, "wood_b", width=0.35)
    # 밧줄 결속
    with a.no_parts():
        for z in levels:
            for p in posts:
                c = at_z(p, z)
                ring = [c + Vector((math.cos(t) * 1.0, math.sin(t) * 1.0, 0.25)) for t in [i * 2 * math.pi / 8 for i in range(9)]]
                a.tube(ring, 0.13, "rope", sides=4, caps=False, part=False)
    # 전망대 바닥 (사다리 구멍 3x3 제외)
    P = 6.5
    S.plank_floor(a, -P, P, -P, -1.6, ZP, along="x", collider=False)
    S.plank_floor(a, -P, P, 1.6, P, ZP, along="x", collider=False, joists=False)
    S.plank_floor(a, -P, -1.6, -1.6, 1.6, ZP, along="y", collider=False, joists=False)
    S.plank_floor(a, 1.6, P, -1.6, 1.6, ZP, along="y", collider=False, joists=False)
    a.collider((0, (-P - 1.6) / 2, ZP - 0.6), (2 * P, P - 1.6, 1.2), tag="Floor")
    a.collider((0, (P + 1.6) / 2, ZP - 0.6), (2 * P, P - 1.6, 1.2), tag="Floor")
    a.collider(((-P - 1.6) / 2, 0, ZP - 0.6), (P - 1.6, 3.2, 1.2), tag="Floor")
    a.collider(((P + 1.6) / 2, 0, ZP - 0.6), (P - 1.6, 3.2, 1.2), tag="Floor")
    # 사다리 (중앙 구멍으로)
    S.ladder(a, 0, 1.2, 0.5, ZP, yaw=0, width=2.4, lean=0.0)
    # 사다리 받침 발판
    S.plank_floor(a, -3, 3, -3, 3, 0.9, along="x", collider=True, joists=False)
    # 난간 (판자 흉벽)
    for k in range(4):
        ang = k * 90
        with a.at(loc=(0, 0, 0), rot=(0, 0, ang)):
            S.plank_wall(a, (-P, -P), (P, -P), ZP, ZP + 3.4, battens=False, collider=True, jag=0.3, keys=("wood_a", "wood_b", "wood_c"))
            a.box((0, -P, ZP + 3.5), (2 * P + 0.4, 0.8, 0.35), "wood_dark", bevel=0.05)
    # 지붕 기둥 + 사각뿔 지붕
    for sx, sy in corners:
        S.post(a, sx * (P - 0.4), sy * (P - 0.4), ZP, ZP + 9.0, 0.7)
    S.pyramid_roof(a, 0, 0, ZP + 9.0, P + 0.2, 7.5, overhang=1.4, moss=0.08, finial=False)
    # 경종 (황동)
    bell_c = Vector((0, 0, ZP + 7.2))
    a.box_between((-P + 0.4, 0, ZP + 8.6), (P - 0.4, 0, ZP + 8.6), 0.4, "wood_dark", width=0.4)
    prof = [(0.0, 0.3), (-0.4, 0.55), (-1.2, 0.8), (-1.8, 1.15), (-2.0, 1.25)]
    a.tube([bell_c + Vector((0, 0, z)) for z, _ in prof], [r for _, r in prof], "brass", sides=14, part_step=2)
    a.cyl(bell_c + Vector((0, 0, 0.2)), bell_c + Vector((0, 0, 1.4)), 0.12, "iron", sides=5)
    a.sphere(bell_c + Vector((0, 0, -1.9)), 0.3, "iron", seg=8, rings=5)
    a.marker("Bell", tuple(bell_c))
    # 깃발 (지붕 꼭대기)
    a.cyl((0, 0, ZP + 15.8), (0, 0, ZP + 23.5), 0.16, "wood_dark", sides=6)
    a.sphere((0, 0, ZP + 23.6), 0.28, "brass", seg=8, rings=5)
    with a.no_parts():
        from swamplib import geom
        def flag(u, v):
            return (0.15 + u * 5.0, 0.45 * math.sin(u * 4.5 + v * 0.7) * u, ZP + 23.2 - v * 2.6 - u * 0.35)
        a.mesh(geom.solidify(*geom.grid_surface(flag, 12, 4), 0.06), "cloth_green")
    a._prim_box_only((2.6, 0, ZP + 21.7), (5.0, 0.1, 2.6), "cloth_green")
    S.lantern(a, (P - 0.4, -P + 0.4, ZP + 5.5), light=True, rng_range=26, brightness=1.4)
    S.lantern(a, (-P + 0.4, P - 0.4, ZP + 5.5), light=True, rng_range=26, brightness=1.4)
    S.barrel(a, (-4.6, -4.6, ZP), h=2.4, r=0.9)
    S.crate(a, (4.4, 4.2, ZP), 2.0, 20)
    a.marker("Lookout", (0, -4, ZP + 0.2))
    return a


ASSETS = [watchtower]
