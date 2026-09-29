# -*- coding: utf-8 -*-
"""
build_palace_props.py — 절화 궁을 채우는 소품. (2026-09-27)

치수는 스터드 그대로(배율 1). 원점은 바닥 가운데, 앞은 -y (로블록스 -Z). 블렌더 +x 는 로블록스 -X.
팔레트는 build_hanok_props.HPAL 을 같이 쓴다. 합본은 build_kit_hanok.py 가 안살림 소품과 함께 묶는다.

  정전 안   전돌 바닥, 우물반자 천장(단청 반자틀과 연꽃 반자), 의장기 넷, 홍·청 일산, 봉선,
            편종, 편경, 건고, 궁등(줄 길고 짧은 둘)
  월대·마당  드므, 정(세발 솥), 서수(뿔 하나 해치)
  경회루    방석, 악사 한 벌(가야금·장구·북·대금)

돌리는 법: blender --background --python build_palace_props.py [-- 이름...]
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
from build_hanok_props import HPAL, G  # noqa: E402
from build_props import lathe, ball, extrude, annulus, frustum, cone_between  # noqa: E402
from build_steam import tube  # noqa: E402


def ellipsoid(g, mat, cx, cy, cz, rx, ry, rz, seg=10, rings=6):
    """길쭉한 공. 극에서 부채꼴로 닫는다"""
    v = [(cx, cy, cz - rz)]
    for i in range(1, rings):
        t = math.pi * i / rings - math.pi / 2
        for k in range(seg):
            a = 2 * math.pi * k / seg
            v.append((cx + rx * math.cos(t) * math.cos(a), cy + ry * math.cos(t) * math.sin(a), cz + rz * math.sin(t)))
    v.append((cx, cy, cz + rz))
    top = len(v) - 1
    f = []
    for k in range(seg):
        f.append((0, 1 + (k + 1) % seg, 1 + k))
    for i in range(rings - 2):
        b0, b1 = 1 + i * seg, 1 + (i + 1) * seg
        for k in range(seg):
            k1 = (k + 1) % seg
            f.append((b0 + k, b0 + k1, b1 + k1, b1 + k))
    b = 1 + (rings - 2) * seg
    for k in range(seg):
        f.append((b + k, b + (k + 1) % seg, top))
    g[mat].add_mesh(v, f)


# ================================================================ 정전 바닥과 천장
HALL_W, HALL_D = 59.0, 35.0   # 정전 안 벽 사이 (x ±29.55, z ±17.55 보다 조금 작게)


def jeondol_hall(g):
    """
    정전 전돌 바닥. 네모 전돌 40 x 24 장을 줄눈(0.08)을 두고 깔고, 돌 빛을 셋으로 섞어 오래 밟힌 바닥처럼.
    원점은 전돌 밑. 윗면이 0.08 이라, 방바닥 0.05 아래에 놓으면 0.03 올라온다
    """
    rnd = random.Random(5)
    nx, nz = 40, 24
    px, pz = HALL_W / nx, HALL_D / nz
    for i in range(nx):
        for j in range(nz):
            r = rnd.random()
            mat = "Jeon1" if r < 0.5 else ("Jeon2" if r < 0.8 else "Jeon3")
            g[mat].box(-HALL_W / 2 + px * (i + 0.5), -HALL_D / 2 + pz * (j + 0.5), 0.04, px - 0.08, pz - 0.08, 0.08)


def ceiling_hall(g):
    """
    정전 우물반자. 초록 반자틀 20 x 12 칸, 틀 밑면 붉은 줄, 칸마다 반자널 가운데 연꽃(붉은 꽃잎, 흰 속, 금 씨방).
    벽을 따라 두른 단청 띠. 원점은 띠 밑, 반자널 윗면이 1.15
    """
    nx, nz = 20, 12
    cx, cz = HALL_W / nx, HALL_D / nz
    g["DanBlue"].box(0, 0, 1.075, HALL_W, HALL_D, 0.15)
    for i in range(nx + 1):
        x = -HALL_W / 2 + cx * i
        g["DanGreen"].box(x, 0, 0.8, 0.3, HALL_D, 0.4)
        g["Lacquer"].box(x, 0, 0.585, 0.1, HALL_D, 0.03)
    for j in range(nz + 1):
        y = -HALL_D / 2 + cz * j
        g["DanGreen"].box(0, y, 0.8, HALL_W, 0.3, 0.4)
        g["Lacquer"].box(0, y, 0.585, HALL_W, 0.1, 0.03)
    for i in range(nx):
        for j in range(nz):
            x, y = -HALL_W / 2 + cx * (i + 0.5), -HALL_D / 2 + cz * (j + 0.5)
            g["Lacquer"].cyl(x, y, 0.95, 0.95, 0.95, 0.05, seg=8)
            g["SilkWhite"].cyl(x, y, 0.91, 0.62, 0.62, 0.04, seg=8)
            g["Gold"].cyl(x, y, 0.87, 0.26, 0.26, 0.04, seg=8)
    # 벽 띠. 초록 바탕에 붉은 줄 하나, 금 선 하나
    for sy in (-1, 1):
        g["DanGreen"].box(0, sy * (HALL_D / 2 - 0.15), 0.5, HALL_W, 0.3, 1.0)
        g["Lacquer"].box(0, sy * (HALL_D / 2 - 0.33), 0.55, HALL_W - 0.6, 0.06, 0.3)
        g["Gold"].box(0, sy * (HALL_D / 2 - 0.33), 0.2, HALL_W - 0.6, 0.06, 0.08)
    for sx in (-1, 1):
        g["DanGreen"].box(sx * (HALL_W / 2 - 0.15), 0, 0.5, 0.3, HALL_D - 0.6, 1.0)
        g["Lacquer"].box(sx * (HALL_W / 2 - 0.33), 0, 0.55, 0.06, HALL_D - 1.2, 0.3)
        g["Gold"].box(sx * (HALL_W / 2 - 0.33), 0, 0.2, 0.06, HALL_D - 1.2, 0.08)


# ================================================================ 의장
def standard_base(g, h):
    """의장 받침. 돌 받침과 짙은 나무 꽂이, 주칠 장대"""
    g["Stone"].box(0, 0, 0.15, 0.9, 0.9, 0.3)
    frustum(g, "WoodDark", 0, 0, 0.3, 0.55, 0.55, 0.4, 0.4, 0.6)
    tube(g, "Lacquer", (0, 0, 0.3), (0, 0, h), 0.07, seg=8)


def spear_tip(g, h):
    """장대 끝 금 창날과 붉은 영자"""
    g["Gold"].cyl(0, 0, h, 0.1, 0.1, 0.12, seg=8)
    cone_between(g, "Gold", (0, 0, h + 0.12), (0, 0, h + 0.8), 0.1, 0.01, seg=4)
    lathe(g, "SilkRed", 0, 0, h - 0.55, [(0.09, 0.0), (0.2, 0.3), (0.11, 0.52)], 8)


def uijang_gi(g, cloth, flame, emblem):
    """
    의장기. 장대 옆(+x)에 네모 깃을 달고, 바깥 변과 아랫변에 화염각을 두르고, 가운데 둥근 문장.
    깃 끝에서 늘어진 꼬리 둘
    """
    H = 8.6
    standard_base(g, H)
    spear_tip(g, H)
    x0, x1, z0, z1 = 0.07, 2.0, 5.4, 8.1
    g[cloth].box((x0 + x1) / 2, 0, (z0 + z1) / 2, x1 - x0, 0.05, z1 - z0)
    for k in range(5):
        z = z0 + 0.05 + k * (z1 - z0 - 0.1) / 5
        dz = (z1 - z0 - 0.1) / 5
        extrude(g, flame, [(x1, z), (x1 + 0.38, z + dz * 0.45), (x1, z + dz)], -0.03, 0.03)
    for k in range(4):
        x = x0 + 0.05 + k * (x1 - x0 - 0.1) / 4
        dx = (x1 - x0 - 0.1) / 4
        extrude(g, flame, [(x, z0), (x + dx, z0), (x + dx * 0.55, z0 - 0.4)], -0.03, 0.03)
    extrude(g, flame, [(x1, z0), (x1 + 0.3, z0 - 0.1), (x1, z0 + 0.3)], -0.03, 0.03)
    cx, cz = (x0 + x1) / 2 + 0.05, (z0 + z1) / 2 + 0.1
    g[emblem].hcyl(cx, 0, cz, 0.58, 0.08, axis="y", seg=16)
    g["Gold"].hcyl(cx, 0, cz, 0.36, 0.1, axis="y", seg=14)
    g["Lacquer"].hcyl(cx, 0, cz, 0.2, 0.12, axis="y", seg=10)
    for x in (0.3, 1.1):   # 꼬리
        g[flame].obox(x, 0, z0 - 0.7, 0.18, 0.04, 1.4, ry=0.08)


def uijang_ilsan(g, cloth):
    """일산. 장대 위 둥근 덮개와 두 켜 드림, 금 테 둘, 드림 끝 노란 술 열여섯, 꼭지 금 구슬"""
    H = 8.0
    standard_base(g, H)
    lathe(g, cloth, 0, 0, H - 0.2, [(1.5, 0.0), (1.2, 0.35), (0.5, 0.7), (0.15, 0.85)], 16)
    annulus(g, cloth, (0, 0, H - 0.65), "z", 1.46, 1.54, 0.9, n=16)
    annulus(g, cloth, (0, 0, H - 1.25), "z", 1.52, 1.58, 0.3, n=16)
    annulus(g, "Gold", (0, 0, H - 0.2), "z", 1.5, 1.6, 0.08, n=16)
    annulus(g, "Gold", (0, 0, H - 1.1), "z", 1.5, 1.6, 0.06, n=16)
    for k in range(16):
        a = 2 * math.pi * (k + 0.5) / 16
        g["SilkYellow"].obox(1.56 * math.cos(a), 1.56 * math.sin(a), H - 1.65, 0.07, 0.07, 0.5, rz=a)
    g["Gold"].cyl(0, 0, H + 0.62, 0.12, 0.05, 0.3, seg=8)
    ball(g, "Gold", 0, 0, H + 0.98, 0.12, seg=8)


def uijang_seon(g):
    """봉선. 장대 위 앞을 보는 둥근 붉은 부채, 금 테와 속 테, 가운데 노란 원, 아래 양옆 붉은 술"""
    H = 7.2
    standard_base(g, H)
    cz = H + 1.3
    g["Gold"].box(0, 0, H + 0.05, 0.2, 0.14, 0.16)
    g["SilkRed"].hcyl(0, 0, cz, 1.2, 0.08, axis="y", seg=24)
    annulus(g, "Gold", (0, 0, cz), "y", 1.16, 1.3, 0.1, n=24)
    annulus(g, "Gold", (0, 0, cz), "y", 0.62, 0.7, 0.1, n=20)
    g["SilkYellow"].hcyl(0, 0, cz, 0.45, 0.1, axis="y", seg=16)
    g["SilkRed"].hcyl(0, 0, cz, 0.18, 0.12, axis="y", seg=10)
    for sx in (-1, 1):
        x = sx * 0.85
        g["Gold"].cyl(x, 0, cz - 0.95, 0.06, 0.06, 0.1, seg=6)
        lathe(g, "SilkRed", x, 0, cz - 1.75, [(0.06, 0.0), (0.14, 0.5), (0.08, 0.8)], 6)


# ================================================================ 악기
def akgi_frame(g, W=5.4, H=6.4):
    """편종·편경 틀. 받침목 둘(금 발), 주칠 기둥 둘, 걸이대 둘, 위 들보 양끝 금 용머리와 삼색 유소, 위에 금 새 다섯"""
    for sx in (-1, 1):
        x = sx * W / 2
        g["WoodDark"].box(x, 0, 0.3, 0.6, 2.0, 0.6)
        for sy in (-1, 1):
            ball(g, "Gold", x, sy * 0.95, 0.22, 0.2, seg=8)
        g["Lacquer"].box(x, 0, 0.6 + (H - 0.6) / 2, 0.36, 0.36, H - 0.6)
        g["Gold"].box(x, 0, H - 0.1, 0.46, 0.46, 0.2)
        g["Gold"].box(x, 0, 0.7, 0.46, 0.46, 0.2)
    for z in (2.2, 4.6):
        g["Lacquer"].box(0, 0, z, W, 0.24, 0.3)
        g["DanGreen"].box(0, -0.13, z, W - 0.8, 0.02, 0.16)
    g["Lacquer"].box(0, 0, H + 0.18, W + 0.6, 0.34, 0.36)
    g["DanGreen"].box(0, -0.18, H + 0.18, W - 0.2, 0.02, 0.2)
    for sx in (-1, 1):
        x = sx * (W / 2 + 0.5)
        g["Gold"].obox(x, 0, H + 0.34, 0.55, 0.3, 0.3, ry=-sx * 0.3)
        ball(g, "Gold", x + sx * 0.32, 0, H + 0.5, 0.17, seg=8)
        cone_between(g, "Gold", (x + sx * 0.36, 0, H + 0.62), (x + sx * 0.2, 0, H + 0.95), 0.05, 0.01, seg=4)
        for j, mat in enumerate(("SilkRed", "SilkBlue", "SilkYellow")):
            yy = -0.1 + 0.1 * j
            tube(g, mat, (x + sx * 0.1, yy, H + 0.2), (x + sx * 0.1, yy, H - 1.5), 0.045, seg=5)
            lathe(g, mat, x + sx * 0.1, yy, H - 2.1, [(0.05, 0.0), (0.12, 0.4), (0.07, 0.6)], 6)
    for k in range(5):
        x = -W / 2 + W * (k + 0.5) / 5
        ellipsoid(g, "Gold", x, 0.05, H + 0.52, 0.12, 0.2, 0.12, seg=8, rings=5)
        ball(g, "Gold", x, -0.16, H + 0.7, 0.08, seg=6)
        g["Gold"].obox(x, 0.3, H + 0.6, 0.05, 0.28, 0.05, rx=-0.6)


def pyeonjong(g):
    """편종. 두 줄 여덟씩 청동 종 열여섯을 고리로 건다. 종마다 아랫단 금 테"""
    akgi_frame(g)
    for z in (2.2, 4.6):
        for k in range(8):
            x = -2.17 + k * 0.62
            g["Brass"].box(x, 0, z - 0.28, 0.04, 0.04, 0.26)
            lathe(g, "Bronze", x, 0, z - 1.3, [(0.25, 0.0), (0.23, 0.4), (0.17, 0.85), (0.1, 0.9)], 10)
            annulus(g, "Gold", (x, 0, z - 1.26), "z", 0.23, 0.265, 0.06, n=10)


def pyeongyeong(g):
    """편경. 두 줄 여덟씩 ㄱ 자 경돌 열여섯을 꼭지 끈으로 건다"""
    akgi_frame(g)
    shape = [(0.0, 0.04), (0.3, -0.58), (0.18, -0.66), (-0.01, -0.16), (-0.2, -0.36), (-0.28, -0.28)]
    for z in (2.2, 4.6):
        for k in range(8):
            x = -2.17 + k * 0.62
            top = z - 0.5
            g["Straw"].box(x, 0, z - 0.33, 0.03, 0.03, 0.34)
            extrude(g, "Celadon", [(x + px, top + pz) for px, pz in shape], -0.06, 0.06)


def geongo(g):
    """
    건고. 십자 받침목 네 끝 금 발, 주칠 기둥이 가로 누인 큰 북을 꿰고, 위로 두 층 네모 닫집과 귀마다 붉은 술,
    꼭대기 흰 새. 북면(앞뒤 y)은 가죽에 붉은 원과 금 테, 통 둘레에 금 못 줄
    """
    g["WoodDark"].box(0, 0, 0.3, 3.4, 0.5, 0.6)
    g["WoodDark"].box(0, 0, 0.3, 0.5, 3.4, 0.6)
    for a in range(4):
        t = math.pi / 2 * a
        ball(g, "Gold", 1.6 * math.cos(t), 1.6 * math.sin(t), 0.24, 0.22, seg=8)
    tube(g, "Lacquer", (0, 0, 0.6), (0, 0, 9.1), 0.13, seg=8)
    zc = 4.3
    g["Lacquer"].hcyl(0, 0, zc, 1.5, 1.3, axis="y", seg=20)
    for sy in (-1, 1):
        g["Lacquer"].hcyl(0, sy * 0.9, zc, 1.4, 0.55, axis="y", seg=20)
        annulus(g, "Gold", (0, sy * 1.12, zc), "y", 1.32, 1.46, 0.12, n=20)
        g["Hide"].hcyl(0, sy * 1.2, zc, 1.3, 0.06, axis="y", seg=20)
        g["SilkRed"].hcyl(0, sy * 1.245, zc, 0.62, 0.04, axis="y", seg=16)
        annulus(g, "Gold", (0, sy * 1.25, zc), "y", 0.62, 0.72, 0.05, n=16)
        for k in range(14):
            a = 2 * math.pi * k / 14
            ball(g, "Gold", 1.4 * math.cos(a), sy * 1.02, zc + 1.4 * math.sin(a), 0.06, seg=5)
    annulus(g, "Gold", (0, 0, zc), "y", 1.46, 1.54, 0.2, n=20)
    for z, w in ((7.2, 2.8), (8.35, 1.9)):
        g["Lacquer"].box(0, 0, z - 0.15, w * 0.8, w * 0.8, 0.3)
        frustum(g, "WoodDark", 0, 0, z, w, w, w * 0.35, w * 0.35, 0.65)
        g["Gold"].box(0, 0, z + 0.02, w + 0.1, w + 0.1, 0.06)
        for sx in (-1, 1):
            for sy in (-1, 1):
                x, y = sx * w * 0.47, sy * w * 0.47
                tube(g, "SilkRed", (x, y, z), (x, y, z - 0.9), 0.05, seg=5)
                ball(g, "SilkRed", x, y, z - 1.0, 0.1, seg=6)
    ellipsoid(g, "SilkWhite", 0, 0.05, 9.35, 0.18, 0.32, 0.2, seg=8, rings=5)
    tube(g, "SilkWhite", (0, -0.15, 9.45), (0, -0.25, 9.85), 0.05, seg=5)
    ball(g, "SilkWhite", 0, -0.3, 9.9, 0.09, seg=6)
    cone_between(g, "Gold", (0, -0.36, 9.9), (0, -0.55, 9.86), 0.04, 0.005, seg=4)


def gungdeung(g, cord):
    """궁등. 육모 등롱에 붉은 비단(빛이 비친다), 금 모서리 살과 위아래 금 판, 연꽃 뚜껑, 아래 술. 원점은 술 끝, 줄이 위로 cord"""
    z0 = 0.7
    lathe(g, "SilkRed", 0, 0, 0.0, [(0.05, 0.0), (0.13, 0.45), (0.07, 0.68)], 6)
    g["Gold"].cyl(0, 0, z0 - 0.06, 0.1, 0.13, 0.1, seg=6)
    g["Gold"].cyl(0, 0, z0 + 0.04, 0.5, 0.5, 0.1, seg=6)
    lathe(g, "LanternSilk", 0, 0, z0 + 0.14, [(0.46, 0.0), (0.6, 0.5), (0.61, 0.9), (0.48, 1.42)], 6)
    for k in range(6):
        a = 2 * math.pi * k / 6
        c, s = math.cos(a), math.sin(a)
        tube(g, "Gold", (0.47 * c, 0.47 * s, z0 + 0.14), (0.62 * c, 0.62 * s, z0 + 0.64), 0.03, seg=4)
        tube(g, "Gold", (0.62 * c, 0.62 * s, z0 + 0.64), (0.62 * c, 0.62 * s, z0 + 1.04), 0.03, seg=4)
        tube(g, "Gold", (0.62 * c, 0.62 * s, z0 + 1.04), (0.49 * c, 0.49 * s, z0 + 1.56), 0.03, seg=4)
    lathe(g, "Gold", 0, 0, z0 + 1.54, [(0.56, 0.0), (0.45, 0.18), (0.16, 0.36), (0.05, 0.46)], 6)
    annulus(g, "Gold", (0, 0, z0 + 2.08), "x", 0.07, 0.11, 0.03, n=8)
    g["LampPt"].box(0, 0, z0 + 0.8, 0.1, 0.1, 0.1)
    tube(g, "Iron", (0, 0, z0 + 2.18), (0, 0, z0 + 2.18 + cord), 0.03, seg=4)


# ================================================================ 월대·마당
def deumeu(g):
    """드므. 돌 받침 위 넓적한 무쇠 독, 두꺼운 입술 안에 물, 양옆 고리 손잡이, 배에 놋 글자판 넷, 짧은 발 넷"""
    frustum(g, "Granite", 0, 0, 0.0, 2.7, 2.7, 2.4, 2.4, 0.45)
    for a in range(4):
        t = math.pi / 4 + math.pi / 2 * a
        cone_between(g, "Iron", (0.85 * math.cos(t), 0.85 * math.sin(t), 0.45), (0.95 * math.cos(t), 0.95 * math.sin(t), 0.7),
                     0.12, 0.16, seg=6)
    lathe(g, "Iron", 0, 0, 0.62, [(0.9, 0.0), (1.18, 0.18), (1.34, 0.62), (1.36, 0.95)], 20)
    annulus(g, "Iron", (0, 0, 1.64), "z", 1.18, 1.46, 0.14, n=20)
    g["Glass"].cyl(0, 0, 1.56, 1.2, 1.2, 0.03, seg=20)
    for sx in (-1, 1):
        annulus(g, "Iron", (sx * 1.44, 0, 1.2), "y", 0.12, 0.2, 0.06, n=10)
    for a in range(4):
        t = math.pi / 2 * a
        g["Brass"].obox(1.3 * math.cos(t), 1.3 * math.sin(t), 1.12, 0.36, 0.05, 0.36, rz=t + math.pi / 2, rx=-0.28)


def jeong(g):
    """정. 돌 받침 위 세 발 청동 솥, 배에 도드라진 띠, 두 귀 고리, 뚜껑과 금 꼭지"""
    frustum(g, "Granite", 0, 0, 0.0, 2.2, 2.2, 1.9, 1.9, 0.4)
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.pi / 2
        c, s = math.cos(a), math.sin(a)
        tube(g, "Bronze", (0.55 * c, 0.55 * s, 1.05), (0.72 * c, 0.72 * s, 0.5), 0.12, seg=8)
        ball(g, "Bronze", 0.74 * c, 0.74 * s, 0.5, 0.16, seg=8)
    lathe(g, "Bronze", 0, 0, 0.9, [(0.45, 0.0), (0.92, 0.2), (1.04, 0.55), (0.96, 0.9), (0.82, 1.02), (0.86, 1.1)], 18)
    annulus(g, "Brass", (0, 0, 1.45), "z", 1.02, 1.08, 0.12, n=18)
    lathe(g, "Bronze", 0, 0, 2.0, [(0.84, 0.0), (0.68, 0.22), (0.3, 0.42), (0.12, 0.48)], 16)
    ball(g, "Gold", 0, 0, 2.62, 0.14, seg=8)
    for sx in (-1, 1):
        annulus(g, "Bronze", (sx * 0.78, 0, 2.3), "x", 0.18, 0.27, 0.07, n=12)


def seosu(g):
    """
    서수. 돌 받침 위에 앞다리를 세우고 앉은 뿔 하나 해치. 둥근 엉덩이와 가슴, 접은 뒷다리, 갈기 고리,
    툭 튀어나온 눈과 주둥이, 말려 올라간 꼬리. 앞(-y)을 본다
    """
    m = "Granite"
    g[m].box(0, 0, 0.25, 1.7, 2.3, 0.5)
    frustum(g, m, 0, 0, 0.5, 1.7, 2.3, 1.5, 2.1, 0.1)
    z0 = 0.6
    ellipsoid(g, m, 0, 0.4, z0 + 0.5, 0.62, 0.65, 0.5)
    ellipsoid(g, m, 0, -0.1, z0 + 1.05, 0.5, 0.48, 0.62)
    for sx in (-1, 1):
        ellipsoid(g, m, sx * 0.5, 0.35, z0 + 0.38, 0.2, 0.45, 0.34, seg=8, rings=5)
        ellipsoid(g, m, sx * 0.45, -0.15, z0 + 0.08, 0.15, 0.24, 0.09, seg=8, rings=4)
        tube(g, m, (sx * 0.27, -0.35, z0 + 0.9), (sx * 0.3, -0.5, z0 + 0.1), 0.14, seg=8)
        ellipsoid(g, m, sx * 0.3, -0.62, z0 + 0.1, 0.17, 0.23, 0.1, seg=8, rings=4)
    hz = z0 + 1.8
    ellipsoid(g, m, 0, -0.35, hz, 0.44, 0.42, 0.38)
    ellipsoid(g, m, 0, -0.74, hz - 0.1, 0.27, 0.23, 0.19, seg=8)
    ball(g, m, 0, -0.95, hz - 0.04, 0.09, seg=6)
    for sx in (-1, 1):
        ball(g, m, sx * 0.17, -0.68, hz + 0.14, 0.08, seg=6)
        cone_between(g, m, (sx * 0.3, -0.25, hz + 0.25), (sx * 0.42, -0.15, hz + 0.5), 0.09, 0.02, seg=5)
    for k in range(11):   # 갈기
        a = math.radians(-150 + 30 * k)
        ball(g, m, 0.46 * math.sin(a), -0.2, hz + 0.46 * math.cos(a) * 0.9 - 0.05, 0.13, seg=6)
    for k in range(10):   # 갈기 둘째 켜. 첫 켜 사이로 뒤에
        a = math.radians(-135 + 30 * k)
        ball(g, m, 0.54 * math.sin(a), -0.02, hz + 0.54 * math.cos(a) * 0.9 - 0.1, 0.14, seg=6)
    cone_between(g, m, (0, -0.42, hz + 0.3), (0, -0.33, hz + 0.68), 0.08, 0.02, seg=5)
    for sx in (-1, 1):   # 눈두덩, 송곳니
        ellipsoid(g, m, sx * 0.17, -0.63, hz + 0.24, 0.14, 0.08, 0.06, seg=8, rings=4)
        cone_between(g, m, (sx * 0.12, -0.82, hz - 0.2), (sx * 0.12, -0.84, hz - 0.36), 0.04, 0.01, seg=4)
    ellipsoid(g, m, 0, -0.68, hz - 0.33, 0.22, 0.19, 0.08, seg=8, rings=4)   # 벌린 아래턱
    annulus(g, m, (0, -0.15, z0 + 1.52), "z", 0.36, 0.47, 0.1, n=14)       # 목걸이와 방울
    ball(g, m, 0, -0.6, z0 + 1.36, 0.13, seg=8)
    tube(g, m, (0, 0.95, z0 + 0.4), (0, 1.15, z0 + 0.9), 0.1, seg=6)
    tube(g, m, (0, 1.15, z0 + 0.9), (0, 1.0, z0 + 1.35), 0.09, seg=6)
    ball(g, m, 0, 0.95, z0 + 1.45, 0.16, seg=6)


# ================================================================ 경회루 잔치
def bangseok(g):
    """방석. 비단 바탕에 가운데 붉은 판, 네 귀 금 술"""
    g["SilkBlue"].box(0, 0, 0.1, 1.1, 1.1, 0.2)
    g["SilkRed"].box(0, 0, 0.21, 0.7, 0.7, 0.04)
    for sx in (-1, 1):
        for sy in (-1, 1):
            ball(g, "Gold", sx * 0.55, sy * 0.55, 0.1, 0.06, seg=6)


def akgi_set(g):
    """악사 한 벌. 방석 셋, 왼쪽 가야금(안족 열둘과 줄), 가운데 장구(끈 여덟), 오른쪽 받침 위 북, 앞에 대금"""
    for x in (-1.4, 0.0, 1.4):
        g["SilkBlue"].box(x, 0.6, 0.1, 1.0, 1.0, 0.2)
        g["SilkRed"].box(x, 0.6, 0.21, 0.6, 0.6, 0.04)
    # 가야금: 비스듬히 무릎에서 바닥으로
    rz = 1.9
    c, s = math.cos(rz), math.sin(rz)

    def P(u, v):
        return (-1.6 + u * c - v * s, -0.75 + u * s + v * c)
    x, y = P(0, 0)
    g["Wood"].obox(x, y, 0.3, 3.0, 0.5, 0.14, rz=rz, ry=0.05)
    g["WoodDark"].obox(*P(1.45, 0), 0.34, 0.12, 0.56, 0.2, rz=rz)
    for k in range(12):
        u = -1.1 + k * 0.17
        v = -0.2 + k * 0.036
        g["Bone"].obox(*P(u, v), 0.42, 0.05, 0.05, 0.1, rz=rz)
    for k in range(12):
        v = -0.2 + k * 0.036
        a, b = P(-1.4, v), P(1.4, v)
        tube(g, "Straw", (a[0], a[1], 0.39), (b[0], b[1], 0.39), 0.008, seg=3)
    # 장구: 가로 누인 모래시계 통, 두 가죽 판
    jx, jy, jz = 0.0, -0.4, 0.42
    for sx in (-1, 1):
        cone_between(g, "Lacquer", (jx, jy, jz), (jx + sx * 0.7, jy, jz), 0.1, 0.3, seg=10)
        g["Hide"].hcyl(jx + sx * 0.72, jy, jz, 0.4, 0.05, axis="x", seg=12)
        annulus(g, "Gold", (jx + sx * 0.72, jy, jz), "x", 0.36, 0.42, 0.06, n=12)
    for k in range(8):
        a = 2 * math.pi * k / 8
        a2 = a + math.pi / 8
        tube(g, "SilkRed", (jx - 0.7, jy + 0.38 * math.cos(a), jz + 0.38 * math.sin(a)),
             (jx + 0.7, jy + 0.38 * math.cos(a2), jz + 0.38 * math.sin(a2)), 0.012, seg=3)
    # 북: 받침 위 가로 누인 통
    bx, by = 1.4, -0.45
    for sx in (-1, 1):
        g["WoodDark"].box(bx + sx * 0.3, by, 0.2, 0.08, 0.5, 0.4)
    g["Lacquer"].hcyl(bx, by, 0.7, 0.42, 0.55, axis="x", seg=14)
    for sx in (-1, 1):
        g["Hide"].hcyl(bx + sx * 0.3, by, 0.7, 0.38, 0.05, axis="x", seg=14)
    tube(g, "WoodDark", (bx - 0.2, by - 0.5, 0.03), (bx + 0.35, by - 0.35, 0.03), 0.03, seg=4)
    # 대금
    tube(g, "WoodDark", (0.2, -1.35, 0.05), (1.8, -1.5, 0.05), 0.05, seg=6)
    for u in (0.5, 1.1, 1.6):
        annulus(g, "Gold", (u, -1.35 - (u - 0.2) * 0.094, 0.05), "x", 0.045, 0.062, 0.04, n=6)


# ---------------------------------------------------------------- 내놓기
JOBS = [
    ("Jeondol_Hall", "Jeondol", jeondol_hall, (20, -25, 18), (0, 0, 0)),
    ("Ceiling_Hall", "Ceil", ceiling_hall, (10, -14, -8), (0, 0, 1)),
    ("Uijang_GiBlue", "GiBlue", lambda g: uijang_gi(g, "SilkBlue", "SilkRed", "SilkYellow"), (6, -9, 6), (0.8, 0, 5)),
    ("Uijang_GiRed", "GiRed", lambda g: uijang_gi(g, "SilkRed", "SilkYellow", "SilkBlue"), (6, -9, 6), (0.8, 0, 5)),
    ("Uijang_GiYellow", "GiYel", lambda g: uijang_gi(g, "SilkYellow", "SilkRed", "SilkBlue"), (6, -9, 6), (0.8, 0, 5)),
    ("Uijang_GiWhite", "GiWhite", lambda g: uijang_gi(g, "SilkWhite", "SilkRed", "SilkBlue"), (6, -9, 6), (0.8, 0, 5)),
    ("Uijang_IlsanRed", "IlsanR", lambda g: uijang_ilsan(g, "SilkRed"), (6, -9, 7), (0, 0, 5)),
    ("Uijang_IlsanBlue", "IlsanB", lambda g: uijang_ilsan(g, "SilkBlue"), (6, -9, 7), (0, 0, 5)),
    ("Uijang_Seon", "Seon", uijang_seon, (5, -8, 6), (0, 0, 5)),
    ("Pyeonjong", "Jong", pyeonjong, (6, -9, 6), (0, 0, 3.4)),
    ("Pyeongyeong", "Gyeong2", pyeongyeong, (6, -9, 6), (0, 0, 3.4)),
    ("Geongo", "Geongo", geongo, (8, -11, 8), (0, 0, 4.8)),
    ("Gungdeung", "Deung2", lambda g: gungdeung(g, 3.4), (3, -5, 3), (0, 0, 2.5)),
    ("Gungdeung_Short", "DeungS", lambda g: gungdeung(g, 1.2), (3, -5, 3), (0, 0, 1.8)),
    ("Deumeu", "Deumeu", deumeu, (4, -5, 4), (0, 0, 0.9)),
    ("Jeong", "Jeong", jeong, (4, -5, 4), (0, 0, 1.3)),
    ("Seosu", "Seosu", seosu, (3.5, -4.5, 3.5), (0, 0, 1.5)),
    ("Bangseok", "Bang", bangseok, (1.5, -2, 1.5), (0, 0, 0.1)),
    ("Akgi_Set", "Akgi", akgi_set, (3.5, -4.5, 3.5), (0, 0, 0.4)),
]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, prefix, fn, cam, look in JOBS:
        if only and name not in only:
            continue
        L.clear_scene()
        g = G(prefix)
        fn(g)
        L.export_model(name, g, 1.0, renders=[("corner", cam, look)], min_objs=1, palette=HPAL)
