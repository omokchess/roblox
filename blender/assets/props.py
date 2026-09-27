"""소품: 가로등, 모닥불, 부표, 벤치, 화물 더미, 건조대, 횃불, 울타리, 우물."""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import shapes as S
from assets.dock import lamp_post


def lamp_post_asset():
    a = Asset("LampPost", "Prop", description="나무 가로등 (걸린 랜턴)")
    lamp_post(a, (0, 0, 0), h=9.0)
    return a


def campfire():
    a = Asset("Campfire", "Prop", description="모닥불 (돌 테두리, 장작, 불꽃 마커)")
    n = 10
    for k in range(n):
        ang = k * 2 * math.pi / n
        a.blob((math.cos(ang) * 2.4, math.sin(ang) * 2.4, 0.35), a.rng.uniform(0.5, 0.7), "stone", seg=8, rings=5, amp=0.25, scale=(1.2, 1.0, 0.8))
    for k in range(6):
        ang = k * 2 * math.pi / 6 + 0.3
        a.cyl((math.cos(ang) * 1.8, math.sin(ang) * 1.8, 0.2), (math.cos(ang) * 0.15, math.sin(ang) * 0.15, 1.6), 0.26, "wood_dark", sides=7, bevel=0.05)
    a.blob((0, 0, 0.6), 0.9, "glow_fire", seg=8, rings=5, amp=0.4, scale=(1.0, 1.0, 1.4), part=True)
    a.light((0, 0, 2.2), color=(255, 140, 60), range_=26, brightness=2.2, shadows=True)
    a.marker("Fire", (0, 0, 0.8))
    # 통나무 의자
    for ang in (0.5, 2.6, 4.4):
        c = Vector((math.cos(ang) * 6.0, math.sin(ang) * 6.0, 0.9))
        d = Vector((-math.sin(ang), math.cos(ang), 0)) * 2.2
        a.cyl(c - d, c + d, 0.9, "bark", sides=10, bevel=0.15)
        a.collider(c, (4.6, 1.8, 1.8), rot=(0, 0, math.degrees(ang) + 90), tag="Seat")
        a.marker("Seat", tuple(c + Vector((0, 0, 0.9))), rot=(0, 0, math.degrees(ang) + 180))
    return a


def buoy():
    a = Asset("Buoy", "Prop", description="항로 부표 (흔들림 애니메이션 대상, 불빛)")
    prof = [(-1.5, 0.3), (-0.8, 1.6), (0.6, 1.7), (1.2, 1.4)]
    a.tube([Vector((0, 0, z)) for z, _ in prof], [r for _, r in prof], "paint_red", sides=16, part_step=1)
    a.cyl((0, 0, 1.2), (0, 0, 1.6), 1.45, "paint_white", sides=16)
    for k in range(3):
        ang = k * 2 * math.pi / 3
        a.box_between((math.cos(ang) * 1.2, math.sin(ang) * 1.2, 1.5), (math.cos(ang) * 0.3, math.sin(ang) * 0.3, 5.2), 0.2, "iron", width=0.2)
    a.cyl((0, 0, 5.2), (0, 0, 5.5), 0.7, "iron", sides=10)
    a.sphere((0, 0, 6.0), 0.5, "glow_lantern", seg=10, rings=6)
    a.cyl((0, 0, 6.4), (0, 0, 6.7), 0.55, "iron", sides=10)
    a.light((0, 0, 6.0), color=(255, 200, 120), range_=22, brightness=1.6)
    a.marker("Bob", (0, 0, 0))
    return a


def bench():
    a = Asset("Bench", "Prop", description="나무 벤치")
    for sx in (-1, 1):
        a.box((sx * 2.4, 0, 0.9), (0.5, 1.8, 1.8), "wood_dark", bevel=0.05)
    for k in range(3):
        a.box((0, -0.6 + k * 0.6, 1.9), (6.0, 0.5, 0.22), S.pick(a, S.WOOD), bevel=0.04)
    a.box((0, 0.9, 3.0), (6.0, 0.2, 1.0), "wood_c", rot=(-12, 0, 0), bevel=0.04)
    a.collider((0, 0, 1.0), (6.0, 1.8, 2.0), tag="Seat")
    a.marker("Seat", (0, 0, 2.1), rot=(0, 0, 180))
    return a


def cargo_pile():
    a = Asset("CargoPile", "Prop", description="화물 더미 (상자, 통, 자루, 밧줄)")
    S.crate(a, (0, 0, 0), 2.8, 5)
    S.crate(a, (3.0, 0.3, 0), 2.6, -8)
    S.crate(a, (1.4, 0.2, 2.8), 2.4, 20)
    S.crate(a, (-0.2, 3.0, 0), 2.2, 40)
    S.barrel(a, (-3.2, 0.4, 0))
    S.barrel(a, (-3.0, 3.0, 0), h=2.6, r=1.0, key="wood_c")
    S.barrel(a, (4.8, 3.2, 1.05), lying=True, yaw=30)
    S.sack(a, (2.6, 3.0, 0), key="straw")
    S.sack(a, (1.2, 4.2, 0), key="cloth_green")
    S.rope_coil(a, (-5.4, -1.8, 0))
    return a


def fish_rack():
    a = Asset("FishRack", "Prop", description="생선 건조대")
    for x in (-5, 5):
        for y in (-1.5, 1.5):
            a.box_between((x, y, 0), (x, 0, 6.5), 0.4, "wood_dark", width=0.35)
    for z in (6.2, 4.6):
        a.box_between((-5.5, 0, z), (5.5, 0, z), 0.25, "wood_c", width=0.25)
    for z in (6.0, 4.4):
        for k in range(7):
            S.fish(a, (-4.2 + k * 1.4, 0, z - 0.8), L=a.rng.uniform(1.0, 1.4), yaw=a.rng.uniform(-15, 15))
    a.collider((0, 0, 3.2), (11, 3.2, 6.4), tag="Prop")
    return a


def torch_post():
    a = Asset("TorchPost", "Prop", description="늪 횃불 기둥 (길 표시)")
    pts = [Vector((0, 0, -2.0)), Vector((0.1, 0.05, 2.0)), Vector((-0.05, 0.1, 5.0)), Vector((0.05, 0, 7.0))]
    a.tube(pts, [0.35, 0.3, 0.26, 0.22], "wood_dark", sides=7, noise_amp=0.1, part_step=1)
    prof = [(6.8, 0.3), (7.2, 0.55), (7.8, 0.6)]
    a.tube([Vector((0, 0, z)) for z, _ in prof], [r for _, r in prof], "iron", sides=8, part_step=2)
    with a.no_parts():
        for k in range(3):
            ang = k * 2.1
            ring = [Vector((math.cos(t) * 0.33, math.sin(t) * 0.33, 6.2 + 0.2 * k)) for t in [i * 2 * math.pi / 8 for i in range(9)]]
            a.tube(ring, 0.07, "rope", sides=4, caps=False, part=False)
    a.blob((0, 0, 8.2), 0.5, "glow_fire", seg=8, rings=5, amp=0.35, scale=(1, 1, 1.6))
    a.light((0, 0, 8.6), color=(255, 150, 70), range_=22, brightness=1.8)
    a.marker("Fire", (0, 0, 8.2))
    a.collider((0, 0, 3.5), (0.8, 0.8, 9.0), tag="Prop")
    return a


def fence():
    a = Asset("Fence", "Prop", description="나무 울타리 12 stud")
    for x in (-6, 0, 6):
        S.post(a, x, 0, -0.5, 4.2, 0.45)
    for z in (1.4, 3.2):
        a.box_between((-6.2, 0, z), (6.2, 0, z), 0.3, S.pick(a, S.WOOD), width=0.35)
    a.collider((0, 0, 2.0), (12.4, 0.6, 4.2), tag="Rail")
    return a


def well():
    a = Asset("Well", "Prop", description="돌 우물 (도르래, 두레박)")
    n = 14
    for row in range(4):
        for k in range(n):
            ang = 2 * math.pi * (k + 0.5 * (row % 2)) / n
            a.box((math.cos(ang) * 2.8, math.sin(ang) * 2.8, 0.45 + row * 0.85), (1.0, 2 * math.pi * 2.8 / n - 0.1, 0.8), "stone" if a.rng.random() > 0.3 else "stone_moss", rot=(0, 0, math.degrees(ang)), bevel=0.1, part=False)
    a._prim_cyl_only((0, 0, 0), (0, 0, 3.4), 3.2, "stone")
    a.cyl((0, 0, 2.6), (0, 0, 2.7), 2.3, "glass", sides=16)
    for sx in (-1, 1):
        S.post(a, sx * 3.0, 0, 0, 7.5, 0.5)
    a.cyl((-3.2, 0, 6.2), (3.2, 0, 6.2), 0.3, "wood_c", sides=8)
    a.cyl((0, 0, 3.8), (0, 0, 6.1), 0.04, "rope", sides=4)
    a.cyl((0, 0, 3.0), (0, 0, 3.8), 0.55, "wood_b", r1=0.65, sides=10)
    S.gable_roof(a, 0, 0, 7.4, 6.4, 4.0, pitch=35, overhang=0.8, gable_over=0.4, moss=0.15)
    a.collider((0, 0, 1.7), (3.4, 6.4, 6.4), rot=(0, 90, 0), shape="Cylinder", tag="Prop")
    return a


def deck_platform():
    a = Asset("DeckPlatform", "Path", description="24x24 광장 데크 (시장/광장용, Z=7)")
    Z = 7.0
    P = 12.0
    for x in (-P + 1, 0, P - 1):
        for y in (-P + 1, 0, P - 1):
            S.stilt(a, x, y, Z - 0.6, z_bottom=-7.0, r=0.6, lash=(x == 0 or y == 0))
            a.collider((x, y, (Z - 7.0) / 2 - 0.3), (1.1, 1.1, Z + 7.0), tag="Stilt")
    for y in (-P + 1, 0, P - 1):
        a.box((0, y, Z - 1.15), (2 * P + 0.6, 0.8, 0.8), "wood_dark", bevel=0.08)
    S.plank_floor(a, -P, P, -P, P, Z, along="x", joists=False, overhang=0.15, keys=("wood_a", "wood_b", "wood_c", "wood_moss"))
    for (x, y) in ((-P + 0.6, -P + 0.6), (P - 0.6, P - 0.6)):
        lamp_post(a, (x, y, Z), h=8.5)
    with a.no_parts():
        for k in range(6):
            a.blob((a.rng.uniform(-P, P), a.rng.choice((-1, 1)) * (P - 0.2), Z - 0.5), a.rng.uniform(0.4, 0.8), "moss", seg=7, rings=4, amp=0.3, scale=(1.5, 1.0, 0.5))
    return a


def glow_mushroom_cluster():
    from assets.witch_hut import glow_mushrooms
    a = Asset("GlowMushrooms", "Vegetation", description="발광 버섯 군락 (밤에 청록빛)")
    glow_mushrooms(a, (0, 0, 0), n=8, spread=2.6, big=1.3, light=True)
    glow_mushrooms(a, (3.5, 1.5, 0), n=4, spread=1.2, big=0.8, light=False)
    with a.no_parts():
        a.blob((0.5, 0.5, 0.1), 2.4, "moss", seg=9, rings=5, amp=0.3, scale=(1.6, 1.3, 0.2))
    return a


lamp_post_asset.__name__ = "lamp_post"

ASSETS = [lamp_post_asset, campfire, buoy, bench, cargo_pile, fish_rack, torch_post, fence, well, deck_platform, glow_mushroom_cluster]
