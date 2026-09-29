# -*- coding: utf-8 -*-
"""
swamp_ref_assets.py — 안개늪 에셋 고친판 두 개를 만든다(참고 프로젝트 swamplib 을 빌려 씀, 그쪽 파일은 안 건드림). (2026-09-28)

- StiltHouseB2 : StiltHouseB 의 바깥 계단이 너무 가팔랐다(높이 11.2 를 6.2 에 오름, 약 61°).
                 사용자 말대로 집 몸체(1·2층)를 뒤로 10 밀어 넣고 아래 마루를 그만큼 늘려, 계단이 16.2 를 달려 약 35° 로 눕게 했다.
                 앞마루 소품(상자)은 계단 길을 막지 않게 뒤로 옮겼다.
- BoardwalkOpen : 난간·가로등 없는 판자길 16 x 7. 집 입구 앞·갈림길 가지에 써서 난간이 입구를 막지 않게 한다.
출력: models/swamp_ref/fbx/*.fbx, models/swamp_ref/manifest_extra.json
돌리는 법: blender --background --python models/swamp_ref_assets.py
"""
import json
import math
import sys
from pathlib import Path

REF = Path(r"C:\wth\roblox\blender")
sys.path.insert(0, str(REF))

import bpy  # noqa: E402

from swamplib import config, render  # noqa: E402
from swamplib.asset import Asset  # noqa: E402
from swamplib import shapes as S  # noqa: E402
from assets.stilt_house import _stilt_grid, _interior  # noqa: E402
from assets import boardwalk as BW  # noqa: E402

OUT = Path(__file__).resolve().parent / "swamp_ref"
config.FBX_DIR = OUT / "fbx"
config.PARTS_DIR = OUT / "parts"

D = 10.0  # 집 몸체를 뒤(+Y, 로블록스 -Z)로 미는 거리


def stilt_house_b2():
    a = Asset("StiltHouseB2", "Building", description="2층 수상 가옥 (몸체를 뒤로 밀어 바깥 계단을 35°로)")
    Z = 7.0
    _stilt_grid(a, -10, 10, -9, 9 + D, Z, 4, 5)
    S.plank_floor(a, -11.5, 11.5, -10.5, 10.5 + D, Z, along="y")
    x0, x1, y0, y1 = -7.5, 7.5, -6.0 + D, 7.5 + D
    z1 = Z + 10
    for (cx, cy) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        S.post(a, cx, cy, Z, z1 + 0.4, 0.9)
    S.plank_wall(a, (x0, y0), (x1, y0), Z, z1, openings=[(5.0, 10.0, Z, Z + 8.0)], outward=-1, keys=("wood_b", "wood_c", "wood_pale"))
    with a.at(loc=(x0, y0, 0)):
        S.door(a, 5.0, 5.0, 8.0, Z, keys=("wood_teal",), open_angle=95, outward=-1)
    S.plank_wall(a, (x1, y0), (x1, y1), Z, z1, openings=[(5.0, 8.4, Z + 3.5, Z + 7.2)], outward=-1, keys=("wood_b", "wood_c", "wood_pale"))
    with a.at(loc=(x1, y0, 0), rot=(0, 0, 90)):
        S.window(a, 5.0, Z + 3.5, 3.4, 3.7, keys=("wood_red",))
    S.plank_wall(a, (x1, y1), (x0, y1), Z, z1, outward=-1, keys=("wood_b", "wood_c", "wood_pale"))
    S.plank_wall(a, (x0, y1), (x0, y0), Z, z1, openings=[(5.0, 8.4, Z + 3.5, Z + 7.2)], outward=-1, keys=("wood_b", "wood_c", "wood_pale"))
    with a.at(loc=(x0, y1, 0), rot=(0, 0, -90)):
        S.window(a, 5.0, Z + 3.5, 3.4, 3.7, keys=("wood_red",))
    Z2 = z1 + 0.6
    S.plank_floor(a, x0 - 1.8, x1 + 1.8, y0 - 1.8, y1 + 0.4, Z2 + 0.6, along="x", joists=True)
    for x in (x0, 0, x1):
        a.box_between((x, y0, z1 - 2.5), (x, y0 - 1.6, Z2 - 0.4), 0.45, "wood_dark", width=0.45)
    X0, X1, Y0, Y1 = x0 - 1.6, x1 + 1.6, y0 - 1.6, y1 + 0.2
    z2 = Z2 + 0.6 + 8.5
    for (cx, cy) in ((X0, Y0), (X1, Y0), (X0, Y1), (X1, Y1)):
        S.post(a, cx, cy, Z2, z2 + 0.3, 0.8)
    wk = ("wood_a", "wood_moss", "wood_b")
    S.plank_wall(a, (X0, Y0), (X1, Y0), Z2 + 0.6, z2, openings=[(3.0, 6.4, Z2 + 3.4, Z2 + 7.0), (11.8, 15.2, Z2 + 3.4, Z2 + 7.0)], outward=-1, keys=wk)
    with a.at(loc=(X0, Y0, 0)):
        S.window(a, 3.0, Z2 + 3.4, 3.4, 3.6, keys=("wood_red",))
        S.window(a, 11.8, Z2 + 3.4, 3.4, 3.6, keys=("wood_red",))
    S.plank_wall(a, (X1, Y0), (X1, Y1), Z2 + 0.6, z2, openings=[(6.0, 12.0, Z2 + 0.6, Z2 + 8.0)], outward=-1, keys=wk)
    S.plank_wall(a, (X1, Y1), (X0, Y1), Z2 + 0.6, z2, openings=[(7.0, 10.4, Z2 + 3.4, Z2 + 7.0)], outward=-1, keys=wk)
    with a.at(loc=(X1, Y1, 0), rot=(0, 0, 180)):
        S.window(a, 7.0, Z2 + 3.4, 3.4, 3.6, keys=("wood_red",))
    S.plank_wall(a, (X0, Y1), (X0, Y0), Z2 + 0.6, z2, outward=-1, keys=wk)
    span = Y1 - Y0
    pitch = 40
    for xw in (X0, X1):
        prof = (lambda u, s=span: z2 + (s / 2 - abs(u - s / 2)) * math.tan(math.radians(pitch)) - 0.2)
        S.plank_wall(a, (xw, Y0), (xw, Y1), z2 - 0.2, z2, top_profile=prof, battens=False, collider=False, jag=0.0)
    S.gable_roof(a, 0, (Y0 + Y1) / 2, z2, X1 - X0, span, pitch=pitch, overhang=1.8, gable_over=1.5, moss=0.12)
    # 2층 옆 발코니 + 바깥 계단(앞 마루 끝에서 발코니 앞까지 16.2 달림)
    S.plank_floor(a, X1, X1 + 5.5, Y0 + 3.5, Y1 - 0.5, Z2 + 0.6, along="y", joists=False)
    for (px, py) in ((X1 + 5.2, Y0 + 3.8), (X1 + 5.2, Y1 - 0.8)):
        S.post(a, px, py, Z - 0.3, Z2 + 0.6, 0.7)
    S.railing(a, [(X1 + 5.3, Y1 - 0.6), (X1 + 5.3, Y0 + 3.6)], Z2 + 0.6)
    S.stairs(a, (X1 + 2.8, -10.2, Z), (X1 + 2.8, Y0 + 3.6, Z2 + 0.6), width=4.2)
    # 아래층 난간: 앞은 문 앞(-4..4)과 계단 발치(8..)를 비운다
    S.railing(a, [(-11.2, -10.2), (-4.0, -10.2)], Z)
    S.railing(a, [(4.0, -10.2), (7.5, -10.2)], Z)
    S.railing(a, [(-11.2, 10.2 + D), (-11.2, -10.2)], Z)
    S.railing(a, [(11.2, 10.2 + D), (-11.2, 10.2 + D)], Z)
    a.marker("Entrance", (0, -10.8, Z + 0.1), rot=(0, 0, 180))
    S.lantern(a, (x0 + 3.5, y0 - 1.2, Z + 8.0), bracket=(0, 1))
    S.lantern(a, (X1 + 5.3, Y0 + 3.6, Z2 + 4.2), light=True, brightness=1.1)
    S.lantern(a, (-10.6, -9.6, Z + 4.6), light=True, rng_range=16, brightness=1.0)
    S.barrel(a, (-9.5, -8.6, Z))
    S.crate(a, (-9.2, 12.0 + D * 0.5, Z), s=2.4)
    S.crate(a, (-9.0, 9.2 + D * 0.5, Z), s=2.4, yaw=20)
    for x in (X0 + 3.2, X0 + 12.0):
        a.box((x + 1.7, Y0 - 0.7, Z2 + 3.1), (3.6, 1.0, 0.8), "wood_dark", bevel=0.05)
        for k in range(4):
            a.sphere((x + 0.4 + k * 0.85, Y0 - 0.7, Z2 + 3.7), 0.5, "leaf", seg=6, rings=4)
            a.sphere((x + 0.4 + k * 0.85, Y0 - 0.9, Z2 + 4.1), 0.18, "flower_pink" if k % 2 else "flower_white", seg=5, rings=3)
    _interior(a, x0 + 0.6, x1 - 0.6, y0 + 0.6, y1 - 0.6, Z)
    S.lantern(a, (0, 0 + D, z2 - 1.0), hang=0.6, rng_range=18)
    return a


def boardwalk_open():
    a = Asset("BoardwalkOpen", "Path", description="나무 산책로 직선 16 stud (난간·가로등 없음, 입구 앞용)")
    BW._frame(a, -BW.L / 2, BW.L / 2, BW.W, BW.DECK)
    S.plank_floor(a, -BW.L / 2, BW.L / 2, -BW.W / 2, BW.W / 2, BW.DECK, along="y", joists=False, overhang=0.15,
                  keys=("wood_a", "wood_b", "wood_c", "wood_moss"))
    return a


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    man = {}
    for fn in (stilt_house_b2, boardwalk_open):
        render.reset_scene()
        a = fn()
        a.finalize()
        info = a.export(fbx=True)
        man[a.name] = info
        print("[ref] %s tris=%d colliders=%d" % (a.name, info["triCount"], len(info["colliders"])))
    (OUT / "manifest_extra.json").write_text(json.dumps(man, indent=1, ensure_ascii=False), encoding="utf-8")


main()
