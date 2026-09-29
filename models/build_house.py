# -*- coding: utf-8 -*-
"""
build_house.py — 살림집들.

  Building_House    기와집. 정면 3칸, 맞배지붕. 공포 없이 도리만 얹는다
  Building_Cottage  초가집. 같은 뼈대를 더 낮게, 둥근 볏짚 지붕을 덮는다
  Building_HouseL   ㄱ자 기와집. 몸채 앞 오른쪽에 날개채가 앞으로 뻗는다
  Annex_Tile        기와 곁채. 2칸 맞배. 부엌이나 광으로 몸채 옆에 붙인다
  Annex_Thatch      초가 곁채. 2칸

일반 건물(Building_Hall)보다 한 급 낮아 보여야 한다.
  기단은 한 켜로 낮게, 단청은 없다, 기둥이 가늘고 짧다.
문은 배율을 곱한 뒤에도 7 스터드 넘게 높아 캐릭터가 드나든다.

**ㄱ자 날개채 지붕은 몸채 지붕 속으로 파고들어 끝난다.** 날개 용마루가 몸채 지붕면보다
낮아지는 자리까지 늘인 뒤 자르고, 그 끝에는 박공을 두지 않는다. 그래야 두 지붕이
만나는 골이 생기고 잘린 면이 밖에서 보이지 않는다.

돌리는 법: blender --background --python build_house.py
"""
import math
import os
import sys

from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

MODEL_SCALE = 0.5


def thatch_roof(g, roof_z, W, D, eave, H):
    """초가 지붕과 용마름. 앙곡 없이 둥글고 두툼하게"""
    ridge_z = L.build_roof(g, roof_z - 2.0, W, D, eave, H, style="hip",
                           ridge_half=(W - D) / 2 + 4.0, thick=3.6, exp=0.62, lift=0.0,
                           round_p=2.6, mat="Thatch", eave=False, ridge=False)
    # 용마름. 꼭대기에 틀어 얹은 짚. 지붕면에 반쯤 묻어 뜨지 않게 한다
    g["Thatch"].box(0, 0, ridge_z + 0.2, max(6.0, W - D + 10), 3.4, 1.8)


def simple(g, v):
    """곧은 한 채. 기와든 초가든 뼈대는 같다"""
    W, D, col_h = v["W"], v["D"], v["col_h"]
    floor = L.stylobate(g, W, D, v.get("base_h", 3.0), 0.0, margin1=8,
                        stair_w=v.get("stair_w", 14.0), steps=2, mat=v["base"])
    xs, ys = L.column_grid(W, D, v["bx"], v["by"])
    top = L.columns(g, xs, ys, floor, col_h, r=v.get("r", 1.6))
    roof_z = L.beams(g, xs, ys, top, brackets=False)
    L.walls(g, xs, ys, floor, col_h + 1.8, front=v["front"], back=v["back"], side=v["side"])
    g["Stylobate"].box(0, 0, floor + 0.3, W - 2, D - 2, 0.6)
    if v["roof"] == "tile":
        L.build_roof(g, roof_z, W, D, v["eave"], v["H"], style="gable", chimi=False)
    else:
        thatch_roof(g, roof_z, W, D, v["eave"], v["H"])


SIMPLE = [
    dict(name="Building_House", prefix="House", W=54.0, D=34.0, col_h=19.0, bx=3, by=2,
         base="Stylobate", roof="tile", eave=6.5, H=13.0,
         front=["window", "open", "window"], back=["window", "solid", "window"], side=["solid", "window"]),
    dict(name="Building_Cottage", prefix="Cottage", W=46.0, D=30.0, col_h=17.0, bx=3, by=2,
         base="Masonry", roof="thatch", eave=6.0, H=15.0,
         front=["window", "open", "window"], back=["window", "solid", "window"], side=["solid", "window"]),
    dict(name="Annex_Tile", prefix="AnnexT", W=36.0, D=22.0, col_h=16.0, bx=2, by=1, r=1.4,
         base="Stylobate", base_h=2.4, stair_w=11.0, roof="tile", eave=5.5, H=9.5,
         front=["open", "window"], back=["solid", "window"], side=["solid"]),
    dict(name="Annex_Thatch", prefix="AnnexC", W=32.0, D=22.0, col_h=15.0, bx=2, by=1, r=1.4,
         base="Masonry", base_h=2.4, stair_w=11.0, roof="thatch", eave=5.0, H=11.0,
         front=["open", "window"], back=["solid", "solid"], side=["window"]),
]

# ㄱ자 집 치수. 몸채는 원점, 날개채는 몸채 앞 오른쪽 칸에서 앞(-y)으로 뻗는다
LW, LD, L_COL = 54.0, 30.0, 19.0        # 몸채
WING_W, WING_LEN = 18.0, 36.0            # 날개채 폭과 몸채 앞벽에서 뻗는 길이
WING_CX = LW / 2 - WING_W / 2            # 날개채 가운데 x. 몸채 오른쪽 끝 칸에 맞춘다. 반전이면 왼쪽
WING_CY = -LD / 2 - WING_LEN / 2
MAIN_H, WING_H, EAVE = 13.0, 7.0, 6.5


def wing(g, floor, s=1):
    """
    날개채를 제 좌표에서 곧게 짓는다. 제 x 가 긴 쪽이고 +x 끝이 몸채에 붙는 끝이다.
    돌려 앉히면 제 +x 가 몸채 쪽(+y), 제 -y 가 바깥 오른쪽(+x)이 된다
    """
    xs, ys = L.column_grid(WING_LEN, WING_W, 2, 1)
    top = L.columns(g, xs, ys, floor, L_COL)
    roof_z = L.beams(g, xs, ys, top, brackets=False)
    L.walls(g, xs, ys, floor, L_COL + 1.8,
            # 돌려 앉히면 제 앞(-y)이 +x 를 본다. 오른 날개는 +x 가 바깥, 왼 날개는 +x 가 마당이다
            front=["window", "window"] if s > 0 else ["lattice", "window"],
            back=["lattice", "window"] if s > 0 else ["window", "window"],
            side=["open"],                     # 앞 끝. 날개채로 드나드는 문
            side2=["none"])                    # 몸채에 붙는 끝. 안이 이어진다
    g["Stylobate"].box(0, 0, floor + 0.3, WING_LEN - 2, WING_W - 2, 0.6)

    # 날개 지붕을 몸채 용마루 가까이까지 늘여 몸채 지붕 속에서 끝낸다.
    # 제 앞 끝(-x) 박공은 날개채 앞벽에 맞추고, 뒤 끝은 잘라 박공을 두지 않는다
    tail = WING_LEN / 2 + LD / 2 - 1.5         # 날개 가운데에서 몸채 용마루 1.5 앞까지
    RW = WING_LEN + (tail - WING_LEN / 2) * 2  # 앞 끝을 벽에 맞춘 채 뒤로 늘인 지붕 길이
    shift = RW / 2 - WING_LEN / 2
    L.build_roof(g, roof_z, RW, WING_W, EAVE, WING_H, style="gable", chimi=False,
                 cx=shift, x_hi=tail - shift, nx=34, ny=20, gable_ends=(True, False))
    return roof_z


def house_l(g, s=1):
    wcx = s * WING_CX
    base_h = 3.0
    # 기단. 몸채와 날개채 둘을 겹쳐 ㄱ자로 깐다
    g["Stylobate"].box(0, 0, base_h / 2, LW + 8, LD + 8, base_h)
    g["Stylobate"].box(wcx, WING_CY, base_h / 2, WING_W + 8, WING_LEN + 8, base_h)
    floor = base_h
    L.stair(g, 0, -(LD + 8) / 2, floor, 13.0, steps=2)
    L.stair(g, wcx, WING_CY - (WING_LEN + 8) / 2, floor, 10.0, steps=2)

    xs, ys = L.column_grid(LW, LD, 3, 1)
    top = L.columns(g, xs, ys, floor, L_COL)
    roof_z = L.beams(g, xs, ys, top, brackets=False)
    L.walls(g, xs, ys, floor, L_COL + 1.8,
            front=["window", "open", "none"] if s > 0 else ["none", "open", "window"],  # 날개 쪽 칸은 트인다
            back=["window", "solid", "window"],
            side=["window"])
    g["Stylobate"].box(0, 0, floor + 0.3, LW - 2, LD - 2, 0.6)
    ridge = L.build_roof(g, roof_z, LW, LD, EAVE, MAIN_H, style="gable", chimi=False, nx=40, ny=28)

    m = Matrix.Translation((wcx, WING_CY, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z")
    wing_roof_z = L.transformed(g, m, wing, floor, s)
    # 날개 용마루 끝이 몸채 지붕면 밑에 묻히는지. 드러나면 잘린 면이 보인다
    B = LD / 2 + EAVE
    y_end = -1.5
    t = (B - abs(y_end)) / B
    main_surface = roof_z + MAIN_H * t ** 1.42
    assert wing_roof_z + WING_H + 3.4 < main_surface + 0.8, \
        "날개 용마루 끝(%.1f)이 몸채 지붕면(%.1f) 위로 드러난다" % (wing_roof_z + WING_H + 3.4, main_surface)
    assert ridge > wing_roof_z + WING_H


if __name__ == "__main__":
    ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

    for v in SIMPLE:
        if ONLY and v["name"] not in ONLY:
            continue
        L.clear_scene()
        g = L.new_groups(v["prefix"])
        simple(g, v)
        L.export_model(v["name"], g, MODEL_SCALE, renders=[
            ("front", (0, -120, 40), (0, 0, 20)),
            ("corner", (90, -85, 62), (0, 0, 18)),
        ], min_objs=6)

    for name, prefix, side, cam in (("Building_HouseL", "HouseL", 1, 1), ("Building_HouseLM", "HouseLM", -1, -1)):
        if ONLY and name not in ONLY:
            continue
        L.clear_scene()
        g = L.new_groups(prefix)
        house_l(g, side)
        L.export_model(name, g, MODEL_SCALE, renders=[
            ("front", (-20 * cam, -150, 50), (8 * cam, -15, 18)),
            ("corner", (-110 * cam, -120, 75), (8 * cam, -15, 16)),
            ("corner2", (120 * cam, -130, 70), (8 * cam, -15, 16)),
        ], min_objs=8)
