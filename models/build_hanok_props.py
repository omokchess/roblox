# -*- coding: utf-8 -*-
"""
build_hanok_props.py — 절화 건물 안살림 소품. (2026-09-27)

치수는 스터드 그대로(배율 1). 원점은 바닥 가운데, 앞은 -y (로블록스 -Z).
블렌더 +x 는 로블록스 -X 로 간다. 팔레트는 조선 살림 빛깔로 따로 둔다(HPAL).
합본은 build_kit_hanok.py → JeolhwaProps.fbx → tools/Jeolhwa_Props.luau 가 ServerStorage.JeolhwaProps 로 가른다.

  궁      어좌 단, 어좌, 일월오봉도, 닫집, 향로, 촛대
  살림    병풍, 보료, 서안, 문갑, 반닫이, 이층장, 등잔, 경대, 사방탁자, 화로
  부엌·주막  부뚜막, 찬장, 소반, 평상, 술독, 초롱
  가게    계산대, 시렁
  척수관  표본 선반, 약장, 해부대, 말림 시렁, 궤짝
  곳간·헛간  가마니, 뒤주, 멍석과 지게
  좌판    비단, 옹기, 궤짝, 바구니 (가게 모델의 좌판 윗면 7.2 x 2.7 에 얹는다)
  마당    장독대, 우물, 짚가리, 텃밭 (절화 마당 틀 Prop_* 를 같은 발자국으로 갈아 끼운다)
  바깥    품계석, 논밭 이랑 다섯 가지(길이 10 토막), 돌다리 난간 네 길이 (tools/Jeolhwa_Details.luau 가 얹는다)

돌리는 법: blender --background --python build_hanok_props.py [-- 이름...]
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
from build_props import lathe, ball, extrude, annulus, frustum, arch_xz, cone_between  # noqa: E402
from build_steam import tube  # noqa: E402

HPAL = {
    "Wood": "#9A6B45",        # 소나무 결
    "WoodDark": "#4E3325",    # 먹감·옻 먹인 짙은 나무
    "Lacquer": "#8E2B22",     # 주칠
    "Gold": "#C9A24A",        # 금박
    "Brass": "#B8913F",       # 놋쇠
    "Iron": "#3A3C42",        # 무쇠
    "Paper": "#E8DFC8",       # 한지
    "Ink": "#1E1B1A",         # 먹, 숯
    "SilkBlue": "#3C5C8C",
    "SilkRed": "#A33A3A",
    "SilkGreen": "#4F7A58",
    "SilkYellow": "#D8B45A",
    "Celadon": "#8FB5A5",     # 청자
    "Porcelain": "#EDEBE3",   # 백자
    "Onggi": "#5C3F31",       # 옹기
    "Straw": "#BFA46A",       # 짚
    "Stone": "#8E8A80",
    "Clay": "#8A6A4E",        # 부뚜막 흙
    "Sky": "#2B4A78",         # 일월오봉도 하늘
    "Peak": "#2F6D4C",        # 일월오봉도 봉우리, 솔
    "Glow": "#FFC66B",        # 불빛
    "Bone": "#E0D6BE",
    "Hide": "#8A6546",        # 짐승 가죽
    "Glass": "#C8E1EB",
    "Tile": "#484A48",        # 기와
    "Soil": "#6E563E",        # 밭흙
    "Fruit": "#E07C30",       # 감, 귤빛 과일
    "LampPt": "#FFFFFF",      # 표지. 점광원 자리
    "Granite": "#C1BEB0",     # 궁 갓돌·다리 돌. 절화 3판 rim 빛과 같다
    "Leaf": "#6C8442",        # 밭 작물 잎. 옛 이랑 빛
    "Napa": "#9CC063",        # 배추 속잎 끝
    "NapaPale": "#DCE4B4",    # 배추 속 흰 밑동
    "CabbLeaf": "#4C8A3C",    # 배추 겉잎, 무청
    "Barley": "#C9BE72",      # 보리 이삭, 콩 꼬투리
    "Chili": "#B3261E",       # 고추
    "Jeon1": "#7C776B",       # 정전 전돌 셋
    "Jeon2": "#878173",
    "Jeon3": "#706B60",
    "DanGreen": "#2F7B69",    # 단청 뇌록
    "DanBlue": "#2C5A74",     # 반자널 군청
    "Bronze": "#6B5635",      # 청동 (편종, 정)
    "SilkWhite": "#E9E4D6",
    "LanternSilk": "#C8503A", # 궁등 비단. 불빛이 비쳐 스스로 빛난다
}


def G(prefix):
    return L.new_groups(prefix, HPAL)


def flame(g, x, y, z, h=0.28):
    """촛불·등잔불. 불꽃 둘과 점광원 표지"""
    g["Glow"].cyl(x, y, z, 0.09, 0.02, h, seg=6)
    g["Glow"].cyl(x, y, z, 0.05, 0.05, h * 0.4, seg=6)
    g["LampPt"].box(x, y, z + h + 0.15, 0.1, 0.1, 0.1)


def pull(g, x, y, z, r=0.09):
    """놋쇠 고리 손잡이와 받침"""
    g["Brass"].hcyl(x, y - 0.02, z, r * 0.9, 0.04, axis="y", seg=8)
    annulus(g, "Brass", (x, y - 0.06, z - r * 1.1), "y", r * 0.55, r, 0.03, n=10)


def panel_front(g, mat, cx, y, cz, w, h, t=0.04):
    g[mat].box(cx, y - t / 2, cz, w, t, h)


# ================================================================ 궁
def throne_dais(g):
    """어좌 단. 주칠 세 켜, 켜마다 앞 금박 띠, 가운데로 붉은 깔개, 윗단 셋 둘레 난간"""
    tiers = [(10.0, 7.0), (8.4, 5.8), (7.0, 4.8)]
    for k, (w, d) in enumerate(tiers):
        z0 = k * 0.7
        g["Lacquer"].box(0, 0, z0 + 0.35, w, d, 0.7)
        g["Gold"].box(0, -d / 2 - 0.01, z0 + 0.62, w - 0.2, 0.04, 0.1)
        for sx in range(-2, 3):
            g["Gold"].hcyl(sx * w / 5.2, -d / 2 - 0.02, z0 + 0.3, 0.14, 0.04, axis="y", seg=10)
        g["SilkRed"].box(0, -d / 2 + 0.6, z0 + 0.72, 1.8, 1.2, 0.04)
    top, (w, d) = 2.1, tiers[-1]
    rail = []
    for x in (-w / 2 + 0.2, w / 2 - 0.2):
        rail.append(((x, -d / 2 + 0.2), (x, d / 2 - 0.2)))
    rail.append(((-w / 2 + 0.2, d / 2 - 0.2), (w / 2 - 0.2, d / 2 - 0.2)))
    for (x0, y0), (x1, y1) in rail:
        n = max(2, int(math.hypot(x1 - x0, y1 - y0) / 1.2) + 1)
        for i in range(n):
            t = i / (n - 1)
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            g["Lacquer"].box(px, py, top + 0.6, 0.16, 0.16, 1.2)
            ball(g, "Gold", px, py, top + 1.28, 0.1, seg=8)
        cx, cy, L_ = (x0 + x1) / 2, (y0 + y1) / 2, math.hypot(x1 - x0, y1 - y0)
        along_x = abs(x1 - x0) > abs(y1 - y0)
        g["Lacquer"].box(cx, cy, top + 1.15, L_ if along_x else 0.12, 0.12 if along_x else L_, 0.1)
        g["WoodDark"].box(cx, cy, top + 0.45, L_ if along_x else 0.05, 0.05 if along_x else L_, 0.55)


def throne_chair(g):
    """어좌. 주칠 몸, 붉은 방석, 금박 테와 등판 가운데 둥근 금 문양, 팔걸이 끝 말림"""
    g["Lacquer"].box(0, 0, 0.6, 3.0, 2.2, 1.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Gold"].box(sx * 1.4, sy * 1.0, 0.15, 0.3, 0.3, 0.3)
    g["Gold"].box(0, -1.11, 1.08, 2.9, 0.04, 0.12)
    g["Gold"].box(0, -1.11, 0.25, 2.9, 0.04, 0.12)
    g["SilkRed"].box(0, -0.1, 1.33, 2.5, 1.7, 0.26)
    g["Lacquer"].box(0, 0.95, 2.5, 3.0, 0.3, 2.6)
    g["Lacquer"].box(0, 0.95, 3.95, 2.4, 0.3, 0.3)
    g["Lacquer"].box(0, 0.95, 4.2, 1.6, 0.3, 0.2)
    g["Gold"].hcyl(0, 0.78, 2.7, 0.55, 0.05, axis="y", seg=20)
    annulus(g, "Gold", (0, 0.78, 2.7), "y", 0.65, 0.75, 0.05, n=20)
    g["Gold"].box(0, 0.78, 3.95, 2.2, 0.04, 0.08)
    for sx in (-1, 1):
        g["Lacquer"].box(sx * 1.35, -0.1, 1.75, 0.3, 1.9, 0.9)
        g["Gold"].hcyl(sx * 1.35, -1.08, 2.1, 0.22, 0.34, axis="x", seg=12)
        g["Gold"].box(sx * 1.35, -0.1, 2.22, 0.34, 1.9, 0.06)


def irworobongdo(g):
    """
    일월오봉도. 어좌 뒤 큰 그림 병풍. 주칠 틀 안에 하늘, 다섯 봉우리, 해(붉음)와 달(흼),
    두 줄기 폭포, 양끝 붉은 줄기 솔, 아래 물결. 앞(-y)에 그린다
    """
    W, H, T = 11.0, 7.0, 0.4
    g["Lacquer"].box(0, 0, 0.5 + H / 2, W, T, H)
    for sx in (-1, 1):
        g["Lacquer"].box(sx * (W / 2 - 0.4), 0, 0.25, 0.8, 1.6, 0.5)
    g["Gold"].box(0, -T / 2 - 0.01, 0.5 + H - 0.2, W - 0.2, 0.03, 0.08)
    fy = -T / 2 - 0.03
    g["Sky"].box(0, fy, 0.5 + H / 2 + 0.2, W - 0.7, 0.03, H - 0.9)
    base = 0.5 + 1.6
    peaks = [(0.0, 3.8, 4.5), (-2.7, 3.0, 3.4), (2.7, 3.0, 3.4), (-4.4, 2.0, 2.4), (4.4, 2.0, 2.4)]
    for i, (cx, bw, h) in enumerate(peaks):
        prof = [(cx - bw / 2, base), (cx + bw / 2, base), (cx + bw * 0.22, base + h * 0.8), (cx, base + h),
                (cx - bw * 0.22, base + h * 0.8)]
        extrude(g, "Peak", prof, fy - 0.04 - i * 0.005, fy - 0.01)
    g["Lacquer"].hcyl(-3.4, fy - 0.05, 0.5 + H - 1.2, 0.55, 0.03, axis="y", seg=20)   # 해
    g["Porcelain"].hcyl(3.4, fy - 0.05, 0.5 + H - 1.2, 0.55, 0.03, axis="y", seg=20)  # 달
    for x in (-1.35, 1.35):
        g["Paper"].box(x, fy - 0.06, base + 1.2, 0.18, 0.02, 2.2)
    for sx in (-1, 1):   # 솔: 붉은 줄기와 푸른 잎 무리
        x = sx * 4.85
        g["Lacquer"].box(x, fy - 0.07, base + 1.2, 0.18, 0.02, 3.0)
        for k, (dz, w) in enumerate(((2.6, 1.0), (2.0, 1.3), (1.4, 1.1))):
            g["Peak"].box(x - sx * 0.2 * (k % 2), fy - 0.08, base + dz, w, 0.02, 0.35)
    g["SilkBlue"].box(0, fy - 0.02, 0.5 + 0.8, W - 0.7, 0.03, 1.2)
    for k in range(11):   # 물결 머리
        x = -W / 2 + 0.8 + k * (W - 1.6) / 10
        arch_xz(g, "Paper", x, fy - 0.06, 0.5 + 1.1, 0.25, 0.36, 0.02, n=8)
        arch_xz(g, "Paper", x + 0.45, fy - 0.06, 0.5 + 0.6, 0.2, 0.3, 0.02, n=8)


def datjip(g):
    """
    닫집. 어좌 위 천장에 매단 작은 집. 금박 공포 줄 두른 주칠 틀, 우물 반자, 짙은 지붕 뿔대,
    바닥 가운데 금 문양, 네 귀 붉은 술. 원점은 술 끝(바닥), 위로 매단 쇠줄 넷
    """
    z0 = 0.8
    g["Lacquer"].box(0, 0, z0 + 0.3, 8.0, 6.0, 0.6)
    g["Gold"].cyl(0, 0, z0 - 0.02, 1.2, 1.2, 0.04, seg=20)
    annulus(g, "Gold", (0, 0, z0 - 0.01), "z", 1.4, 1.6, 0.03, n=20)
    for k in range(12):   # 공포 줄
        x = -3.6 + k * 7.2 / 11
        for sy in (-1, 1):
            g["Gold"].box(x, sy * 3.05, z0 + 0.75, 0.3, 0.3, 0.3)
            g["Lacquer"].box(x, sy * 3.15, z0 + 1.0, 0.4, 0.4, 0.2)
    for k in range(9):
        y = -2.6 + k * 5.2 / 8
        for sx in (-1, 1):
            g["Gold"].box(sx * 4.05, y, z0 + 0.75, 0.3, 0.3, 0.3)
    g["WoodDark"].box(0, 0, z0 + 0.9, 7.0, 5.0, 0.6)
    frustum(g, "WoodDark", 0, 0, z0 + 1.2, 9.0, 7.0, 3.0, 1.6, 1.8)
    g["Gold"].box(0, 0, z0 + 3.05, 3.2, 1.8, 0.1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["SilkRed"].cyl(sx * 3.9, sy * 2.9, 0.0, 0.08, 0.14, z0, seg=6)
            g["Gold"].cyl(sx * 3.9, sy * 2.9, z0 - 0.1, 0.12, 0.12, 0.12, seg=8)
            g["Iron"].cyl(sx * 2.5, sy * 1.6, z0 + 3.0, 0.05, 0.05, 4.0, seg=6)


def hyangro(g):
    """향로. 팔각 돌받침 위 세 발 놋쇠 향로, 두 귀, 뚜껑과 꼭지"""
    g["Stone"].cyl(0, 0, 0, 0.75, 0.62, 1.3, seg=8)
    g["Stone"].cyl(0, 0, 1.3, 0.85, 0.85, 0.15, seg=8)
    for k in range(3):
        a = 2 * math.pi * k / 3
        g["Brass"].cyl(0.36 * math.cos(a), 0.36 * math.sin(a), 1.45, 0.07, 0.1, 0.35, seg=6)
    lathe(g, "Brass", 0, 0, 1.75, [(0.25, 0.0), (0.5, 0.12), (0.58, 0.35), (0.55, 0.55), (0.6, 0.6)], 16)
    for sx in (-1, 1):
        annulus(g, "Brass", (sx * 0.62, 0, 2.25), "y", 0.1, 0.17, 0.05, n=10)
    lathe(g, "Brass", 0, 0, 2.35, [(0.58, 0.0), (0.45, 0.2), (0.2, 0.36), (0.1, 0.42)], 16)
    ball(g, "Gold", 0, 0, 2.86, 0.11, seg=8)


def chotdae(g):
    """큰 놋쇠 촛대. 둥근 받침, 마디진 대, 촛농 받이, 초와 불"""
    lathe(g, "Brass", 0, 0, 0, [(0.6, 0.0), (0.6, 0.08), (0.35, 0.2), (0.12, 0.3), (0.1, 1.2), (0.16, 1.3),
                                (0.09, 1.4), (0.08, 3.4), (0.14, 3.5), (0.08, 3.6), (0.08, 3.8), (0.45, 3.85),
                                (0.45, 3.92)], 16)
    g["Porcelain"].cyl(0, 0, 3.92, 0.12, 0.11, 0.7, seg=10)
    flame(g, 0, 0, 4.62)


# ================================================================ 살림
def byeongpung(g):
    """
    화조 병풍. 여덟 폭을 지그재그로 세운다. 폭마다 짙은 나무 틀에 한지를 대고
    바위, 줄기, 꽃, 새 한 마리를 그린다. 앞은 -y
    """
    n, pw, ph = 8, 1.0, 4.2
    ang = math.radians(16)
    step = pw * math.cos(ang)
    flowers = ["SilkRed", "SilkYellow", "Porcelain", "SilkRed", "SilkYellow", "SilkRed", "Porcelain", "SilkYellow"]
    for k in range(n):
        a = ang if k % 2 == 0 else -ang
        cx = -step * (n - 1) / 2 + k * step
        g["WoodDark"].obox(cx, 0, 0.2 + ph / 2, pw, 0.12, ph, rz=a)
        u = (math.cos(a), math.sin(a))
        nrm = (-math.sin(a), math.cos(a))

        def at(px, off):
            return cx + u[0] * px - nrm[0] * off, u[1] * px - nrm[1] * off

        x, y = at(0, 0.075)
        g["Paper"].obox(x, y, 0.3 + ph / 2, pw - 0.14, 0.02, ph - 0.3, rz=a)
        x, y = at(0.1 * ((k % 3) - 1), 0.09)
        g["Stone"].obox(x, y, 0.75, 0.55, 0.02, 0.4, rz=a)
        x, y = at(0.0, 0.1)
        g["Peak"].obox(x, y, 1.9, 0.05, 0.02, 2.2, rz=a)
        for j, (px, pz) in enumerate(((-0.18, 2.7), (0.15, 2.35), (-0.05, 3.1), (0.2, 3.0))):
            x, y = at(px, 0.11)
            g[flowers[k]].obox(x, y, pz, 0.16, 0.02, 0.16, rz=a)
            x, y = at(px * 1.6, 0.105)
            g["Peak"].obox(x, y, pz - 0.18, 0.18, 0.02, 0.07, rz=a)
        if k in (2, 5):
            x, y = at(-0.1, 0.12)
            g["Ink"].obox(x, y, 3.55, 0.3, 0.02, 0.12, rz=a)
            x, y = at(0.08, 0.12)
            g["SilkBlue"].obox(x, y, 3.6, 0.14, 0.02, 0.14, rz=a)
        for side in (-1, 1):
            x, y = at(side * 0.38, 0)
            g["WoodDark"].box(x, y, 0.1, 0.14, 0.3, 0.2)


def boryo(g):
    """보료와 안석, 사방침, 방석. 앉는 이는 앞(-y)을 본다"""
    g["SilkBlue"].box(0, 0, 0.18, 5.0, 2.4, 0.36)
    for sy in (-1, 1):
        g["SilkYellow"].box(0, sy * 1.19, 0.18, 5.0, 0.04, 0.3)
    for sx in (-1, 1):
        g["SilkYellow"].box(sx * 2.49, 0, 0.18, 0.04, 2.4, 0.3)
    for k in range(5):
        g["Gold"].hcyl(-2.0 + k, -1.22, 0.18, 0.1, 0.02, axis="y", seg=8)
    g["SilkRed"].hcyl(0, 0.95, 0.75, 0.38, 2.2, axis="x", seg=14)
    for sx in (-1, 1):
        g["Gold"].hcyl(sx * 1.11, 0.95, 0.75, 0.3, 0.04, axis="x", seg=14)
    g["SilkYellow"].box(-2.0, 0.2, 0.75, 0.8, 0.8, 0.78)
    g["SilkRed"].box(-2.0, 0.2, 1.15, 0.6, 0.6, 0.03)
    g["SilkGreen"].box(0.6, -1.9, 0.12, 1.4, 1.4, 0.24)
    g["SilkYellow"].box(0.6, -1.9, 0.25, 0.5, 0.5, 0.02)


def seoan(g):
    """서안. 두루마리 끝 모양 짙은 상판, 옆판과 아래 칸. 책 셋, 필통과 붓, 벼루, 펼친 종이"""
    g["WoodDark"].box(0, 0, 1.08, 2.6, 1.1, 0.12)
    for sx in (-1, 1):
        g["WoodDark"].hcyl(sx * 1.3, 0, 1.14, 0.1, 1.1, axis="y", seg=10)
        g["Wood"].box(sx * 1.15, 0, 0.52, 0.12, 1.0, 1.0)
    g["Wood"].box(0, 0.1, 0.3, 2.2, 0.8, 0.08)
    for k, mat in enumerate(("SilkBlue", "Paper", "SilkBlue")):
        g[mat].box(-0.75, 0.2, 1.2 + k * 0.1, 0.8, 0.55, 0.09)
    g["Celadon"].cyl(0.8, 0.25, 1.14, 0.16, 0.14, 0.45, seg=12)
    for k in range(4):
        a = 2 * math.pi * k / 4
        tube(g, "Wood", (0.8 + 0.05 * math.cos(a), 0.25 + 0.05 * math.sin(a), 1.3),
             (0.8 + 0.12 * math.cos(a), 0.25 + 0.12 * math.sin(a), 1.95), 0.025, seg=5)
    g["Stone"].box(0.2, -0.2, 1.18, 0.5, 0.35, 0.08)
    g["Ink"].box(0.2, -0.28, 1.22, 0.36, 0.14, 0.02)
    g["Paper"].box(-0.2, -0.3, 1.145, 0.7, 0.4, 0.01)


def mungap(g):
    """문갑. 긴 나지막한 장. 짙은 테 두른 문짝 넷과 놋쇠 고리, 네 발. 위에 청자 병과 백자 항아리"""
    W, D, H = 3.6, 1.0, 1.5
    g["Wood"].box(0, 0, 0.2 + H / 2, W, D, H)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["WoodDark"].box(sx * (W / 2 - 0.1), sy * (D / 2 - 0.1), 0.1, 0.2, 0.2, 0.2)
    g["WoodDark"].box(0, 0, 0.2 + H + 0.04, W + 0.08, D + 0.08, 0.08)
    for k in range(4):
        cx = -W / 2 + W * (k + 0.5) / 4
        panel_front(g, "WoodDark", cx, -D / 2, 0.2 + H / 2, W / 4 - 0.12, H - 0.25)
        panel_front(g, "Wood", cx, -D / 2 - 0.02, 0.2 + H / 2, W / 4 - 0.3, H - 0.45)
        pull(g, cx + (0.28 if k % 2 == 0 else -0.28), -D / 2 - 0.05, 0.2 + H / 2)
    lathe(g, "Celadon", -1.0, 0, 0.2 + H + 0.08, [(0.12, 0.0), (0.24, 0.2), (0.26, 0.45), (0.12, 0.8), (0.08, 1.0),
                                                   (0.12, 1.1)], 14)
    lathe(g, "Porcelain", 0.9, 0.05, 0.2 + H + 0.08, [(0.12, 0.0), (0.3, 0.15), (0.33, 0.35), (0.22, 0.55), (0.14, 0.6)], 14)


def bandaji(g):
    """반닫이. 짙은 궤에 무쇠 귀장식·띠, 앞 가운데 놋쇠 앞바탕과 자물쇠. 위에 이불 셋과 베개 둘"""
    W, D, H = 2.8, 1.4, 1.8
    g["WoodDark"].box(0, 0, H / 2, W, D, H)
    for sx in (-1, 1):
        for sz in (0.12, H - 0.12):
            g["Iron"].box(sx * (W / 2 - 0.15), -D / 2 - 0.02, sz, 0.3, 0.04, 0.24)
        g["Iron"].box(sx * (W / 2 - 0.15), 0, H + 0.01, 0.3, D, 0.04)
    g["Iron"].box(0, -D / 2 - 0.02, H * 0.62, W - 0.2, 0.03, 0.08)
    g["Brass"].hcyl(0, -D / 2 - 0.03, H * 0.62, 0.34, 0.04, axis="y", seg=16)
    g["Brass"].box(0, -D / 2 - 0.07, H * 0.62 - 0.05, 0.22, 0.06, 0.34)
    g["Iron"].box(0, -D / 2 - 0.1, H * 0.62 - 0.05, 0.3, 0.05, 0.1)
    for k, mat in enumerate(("SilkRed", "SilkBlue", "SilkYellow")):
        g[mat].box(0.05 * k, 0, H + 0.2 + k * 0.34, W - 0.3 - 0.1 * k, D - 0.1, 0.34)
    for sx in (-1, 1):
        g["SilkGreen"].hcyl(sx * 0.6, 0.1, H + 1.26, 0.2, 0.8, axis="x", seg=12)
        for e in (-1, 1):
            g["Gold"].hcyl(sx * 0.6 + e * 0.41, 0.1, H + 1.26, 0.18, 0.03, axis="x", seg=12)


def ijeongjang(g):
    """이층장. 두 켜 장에 켜마다 문 둘, 놋쇠 경첩과 나비 앞바탕, 위 갓, 네 발"""
    W, D = 2.4, 1.2
    for k, z0 in enumerate((0.3, 2.4)):
        g["Wood"].box(0, 0, z0 + 1.0, W, D, 2.0)
        g["WoodDark"].box(0, 0, z0 + 2.02, W + 0.06, D + 0.06, 0.06)
        for sx in (-1, 1):
            panel_front(g, "WoodDark", sx * W / 4, -D / 2, z0 + 1.0, W / 2 - 0.14, 1.8)
            panel_front(g, "Wood", sx * W / 4, -D / 2 - 0.02, z0 + 1.0, W / 2 - 0.34, 1.55)
            for hz in (z0 + 0.4, z0 + 1.6):
                g["Brass"].box(sx * (W / 2 - 0.12), -D / 2 - 0.05, hz, 0.12, 0.03, 0.22)
        g["Brass"].hcyl(0, -D / 2 - 0.05, z0 + 1.0, 0.2, 0.03, axis="y", seg=12)
        for sx in (-1, 1):
            g["Brass"].obox(sx * 0.16, -D / 2 - 0.06, z0 + 1.0, 0.22, 0.03, 0.12, ry=sx * 0.5)
    g["WoodDark"].box(0, 0, 4.47, W + 0.3, D + 0.2, 0.14)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["WoodDark"].box(sx * (W / 2 - 0.1), sy * (D / 2 - 0.1), 0.15, 0.2, 0.2, 0.3)


def deungjan(g):
    """등잔대. 짙은 둥근 받침, 가는 대, 가운데 받침 쟁반, 위 놋쇠 받침에 옹기 기름 접시와 불"""
    lathe(g, "WoodDark", 0, 0, 0, [(0.42, 0.0), (0.42, 0.08), (0.3, 0.14), (0.07, 0.2)], 12)
    g["WoodDark"].cyl(0, 0, 0.2, 0.06, 0.05, 1.8, seg=8)
    g["WoodDark"].cyl(0, 0, 0.95, 0.26, 0.26, 0.05, seg=12)
    g["Brass"].cyl(0, 0, 2.0, 0.22, 0.24, 0.06, seg=12)
    lathe(g, "Onggi", 0, 0, 2.06, [(0.08, 0.0), (0.18, 0.06), (0.2, 0.1)], 12)
    flame(g, 0.12, 0, 2.14, h=0.2)


def gyeongdae(g):
    """경대. 작은 서랍 둘 달린 짙은 함 위에 주칠 틀 거울을 뒤로 조금 젖혀 세운다"""
    g["WoodDark"].box(0, 0, 0.4, 1.4, 1.0, 0.8)
    for k in range(2):
        panel_front(g, "Wood", 0, -0.5, 0.22 + k * 0.38, 1.2, 0.3)
        pull(g, 0, -0.53, 0.22 + k * 0.38, r=0.06)
    g["Lacquer"].obox(0, 0.15, 1.35, 1.1, 0.08, 1.1, rx=-0.2)
    g["Glass"].obox(0, 0.1, 1.35, 0.9, 0.02, 0.9, rx=-0.2)
    for sx in (-1, 1):
        g["Lacquer"].box(sx * 0.5, 0.25, 0.95, 0.08, 0.15, 0.3)
    g["Porcelain"].cyl(-0.45, -0.25, 0.8, 0.1, 0.1, 0.18, seg=10)
    g["SilkRed"].box(0.4, -0.2, 0.83, 0.3, 0.2, 0.06)


def sabang_takja(g):
    """사방탁자. 네 기둥에 선반 넷, 칸마다 청자·백자·옹기·책"""
    W, D, H = 1.5, 1.2, 4.2
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["WoodDark"].box(sx * (W / 2 - 0.06), sy * (D / 2 - 0.06), H / 2, 0.12, 0.12, H)
    for k, z in enumerate((0.3, 1.35, 2.4, 3.45, H - 0.05)):
        g["Wood"].box(0, 0, z, W, D, 0.08)
    lathe(g, "Celadon", 0, 0, 0.34, [(0.15, 0.0), (0.3, 0.2), (0.32, 0.4), (0.15, 0.75), (0.1, 0.9)], 14)
    lathe(g, "Porcelain", 0, 0, 1.39, [(0.18, 0.0), (0.42, 0.3), (0.44, 0.5), (0.3, 0.8), (0.2, 0.85)], 16)
    for k, mat in enumerate(("SilkBlue", "SilkYellow", "SilkBlue", "Paper")):
        g[mat].box(-0.2, 0, 2.48 + k * 0.1, 0.8, 0.6, 0.09)
    lathe(g, "Onggi", 0.4, 0.1, 2.44, [(0.1, 0.0), (0.2, 0.15), (0.2, 0.3), (0.1, 0.4)], 12)
    lathe(g, "Celadon", 0, 0, 3.49, [(0.08, 0.0), (0.2, 0.06), (0.26, 0.14)], 14)
    lathe(g, "Porcelain", 0.35, 0.2, 3.49, [(0.08, 0.0), (0.16, 0.2), (0.08, 0.45), (0.1, 0.55)], 12)


def hwaro(g):
    """화로. 세 발 옹기 화로에 숯불, 부젓가락"""
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        g["Onggi"].box(0.42 * math.cos(a), 0.42 * math.sin(a), 0.1, 0.18, 0.18, 0.2)
    lathe(g, "Onggi", 0, 0, 0.2, [(0.35, 0.0), (0.55, 0.15), (0.6, 0.45), (0.62, 0.5)], 16)
    g["Ink"].cyl(0, 0, 0.55, 0.52, 0.52, 0.08, seg=14)
    for x, y in ((0.1, 0.1), (-0.2, 0.05), (0.15, -0.2)):
        g["Glow"].box(x, y, 0.66, 0.16, 0.14, 0.08)
    for s in (-1, 1):
        tube(g, "Iron", (0.3, 0.1 * s, 0.6), (0.9, 0.12 * s, 0.05), 0.025, seg=5)
    g["LampPt"].box(0, 0, 0.9, 0.1, 0.1, 0.1)


# ================================================================ 부엌·주막
def buttumak(g):
    """
    부뚜막. 흙 부뚜막 위에 무쇠 가마솥 둘(나무 뚜껑과 손잡이), 앞면 아궁이 둘(돌 아치, 속 불빛, 그을음).
    옆에 장작 더미
    """
    W, D, H = 6.0, 3.0, 2.6
    g["Clay"].box(0, 0, H / 2, W, D, H)
    g["Stone"].box(0, 0, H + 0.08, W + 0.2, D + 0.2, 0.16)
    for sx in (-1, 1):
        x = sx * 1.5
        lathe(g, "Iron", x, 0.1, H - 0.6, [(0.5, 0.0), (0.85, 0.35), (0.95, 0.6), (1.15, 0.72), (1.15, 0.8)], 18)
        # 나무 뚜껑은 솥 테(H + 0.2)에 얹는다
        lathe(g, "Wood", x, 0.1, H + 0.2, [(0.98, 0.0), (0.95, 0.08), (0.6, 0.18), (0.25, 0.24)], 18)
        g["WoodDark"].box(x, 0.1, H + 0.5, 0.7, 0.16, 0.12)
        # 아궁이: 돌 아치 안을 불빛으로 채우고(흙 몸 앞면에 얇게), 그을음은 아치 위로 번진다
        g["Glow"].box(x, -D / 2 - 0.02, 0.45, 1.0, 0.03, 0.9)
        arch_xz(g, "Glow", x, -D / 2 - 0.02, 0.9, 0.01, 0.5, 0.03, n=10)
        g["Ink"].box(x, -D / 2 - 0.05, 0.12, 0.8, 0.04, 0.24)
        arch_xz(g, "Stone", x, -D / 2 - 0.1, 0.9, 0.5, 0.72, 0.2, n=10)
        for s in (-1, 1):
            g["Stone"].box(x + s * 0.61, -D / 2 - 0.1, 0.45, 0.22, 0.2, 0.9)
        g["Ink"].box(x, -D / 2 - 0.01, 1.95, 1.2, 0.02, 0.6)
        g["LampPt"].box(x, -D / 2 - 0.4, 0.6, 0.1, 0.1, 0.1)
    for k in range(5):   # 장작
        y = -1.0 + (k % 3) * 0.45
        z = 0.22 + (k // 3) * 0.4
        g["Wood"].hcyl(W / 2 + 0.8, y + 0.9, z, 0.2, 1.4, axis="y", seg=8)


def chanjang(g):
    """찬장. 위 셋 칸은 트여 사발·놋그릇·옹기를 얹고, 아래는 문 둘 달린 장"""
    W, D, H = 3.0, 1.2, 4.4
    for sx in (-1, 1):
        g["Wood"].box(sx * (W / 2 - 0.08), 0, H / 2, 0.16, D, H)
    g["Wood"].box(0, D / 2 - 0.05, H / 2, W, 0.1, H)
    for z in (0.2, 1.6, 2.5, 3.4, H - 0.05):
        g["Wood"].box(0, 0, z, W, D, 0.1)
    for sx in (-1, 1):
        panel_front(g, "WoodDark", sx * W / 4, -D / 2, 0.9, W / 2 - 0.2, 1.2)
        pull(g, sx * 0.25, -D / 2 - 0.04, 0.95, r=0.07)
    for k in range(4):   # 사발 탑
        x = -1.0 + k * 0.65
        for j in range(3 if k % 2 == 0 else 2):
            lathe(g, "Porcelain", x, 0, 1.65 + j * 0.14, [(0.12, 0.0), (0.26, 0.1), (0.3, 0.16)], 12)
    for k in range(3):
        lathe(g, "Brass", -0.9 + k * 0.9, 0, 2.55, [(0.14, 0.0), (0.3, 0.12), (0.34, 0.24)], 14)
    lathe(g, "Onggi", -0.7, 0, 3.45, [(0.18, 0.0), (0.32, 0.25), (0.3, 0.55), (0.16, 0.7)], 14)
    lathe(g, "Onggi", 0.5, 0, 3.45, [(0.14, 0.0), (0.26, 0.2), (0.24, 0.45), (0.13, 0.55)], 14)


def soban(g):
    """소반. 열두모 상판과 휜 다리 넷. 막걸리 사발 둘, 놋 주전자, 김치 접시"""
    lathe(g, "Wood", 0, 0, 0.72, [(0.72, 0.0), (0.75, 0.05), (0.75, 0.1), (0.7, 0.12)], 12)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        tube(g, "WoodDark", (0.5 * math.cos(a), 0.5 * math.sin(a), 0.72),
             (0.62 * math.cos(a), 0.62 * math.sin(a), 0.0), 0.06, seg=6)
    for x, y in ((-0.3, -0.25), (0.25, -0.3)):
        lathe(g, "Porcelain", x, y, 0.84, [(0.08, 0.0), (0.2, 0.08), (0.22, 0.15)], 12)
        g["Paper"].cyl(x, y, 0.9, 0.18, 0.18, 0.02, seg=12)
    lathe(g, "Brass", 0.15, 0.3, 0.84, [(0.12, 0.0), (0.2, 0.1), (0.2, 0.25), (0.1, 0.35), (0.05, 0.38)], 12)
    tube(g, "Brass", (0.3, 0.3, 0.98), (0.48, 0.3, 1.1), 0.03, seg=6)
    annulus(g, "Brass", (0.0, 0.3, 1.0), "y", 0.09, 0.12, 0.03, n=10)
    g["Celadon"].cyl(-0.3, 0.3, 0.84, 0.18, 0.2, 0.05, seg=12)
    for x, y in ((-0.34, 0.28), (-0.26, 0.34)):
        g["SilkRed"].box(x, y, 0.91, 0.1, 0.06, 0.04)


def pyeongsang(g):
    """평상. 짙은 틀 위 널판 여섯, 다리 여섯. 반쯤 깐 돗자리"""
    W, D, H = 5.2, 3.6, 1.3
    for k in range(6):
        y = -D / 2 + D * (k + 0.5) / 6
        g["Wood"].box(0, y, H - 0.08, W, D / 6 - 0.06, 0.16)
    for sy in (-1, 1):
        g["WoodDark"].box(0, sy * (D / 2 - 0.1), H - 0.25, W, 0.2, 0.2)
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            g["WoodDark"].box(sx * (W / 2 - 0.2), sy * (D / 2 - 0.2), (H - 0.16) / 2, 0.24, 0.24, H - 0.16)
    g["Straw"].box(-0.6, 0.1, H + 0.02, 3.2, 2.6, 0.04)
    for k in range(9):
        g["Wood"].box(-0.6 - 1.5 + k * 0.375, 0.1, H + 0.045, 0.03, 2.6, 0.01)


def suldok(g):
    """술독 무리. 큰 옹기 셋과 뚜껑, 하나는 짚 덮개, 나무 바가지"""
    for (x, y, s, lid) in ((-0.7, 0.3, 1.3, "Onggi"), (0.9, 0.4, 1.0, "Straw"), (0.2, -0.9, 0.8, "Onggi")):
        lathe(g, "Onggi", x, y, 0, [(0.4 * s, 0.0), (0.75 * s, 0.4 * s), (0.95 * s, 1.1 * s), (0.85 * s, 1.7 * s),
                                    (0.55 * s, 2.0 * s), (0.58 * s, 2.1 * s)], 18)
        if lid == "Straw":
            lathe(g, "Straw", x, y, 2.1 * s, [(0.7 * s, 0.0), (0.5 * s, 0.25 * s), (0.1 * s, 0.45 * s)], 14)
        else:
            lathe(g, "Onggi", x, y, 2.1 * s, [(0.62 * s, 0.0), (0.55 * s, 0.1 * s), (0.2 * s, 0.2 * s),
                                             (0.12 * s, 0.28 * s)], 14)
    lathe(g, "Wood", 0.2, -0.9, 1.78, [(0.12, 0.0), (0.28, 0.08), (0.32, 0.14)], 10)
    tube(g, "Wood", (0.45, -0.9, 1.9), (1.0, -0.95, 2.1), 0.04, seg=6)


def chorong(g):
    """초롱. 위 쇠고리에 매단 붉은 비단 등, 금 테 둘, 아래 술. 원점은 술 끝"""
    z0 = 0.5
    lathe(g, "SilkRed", 0, 0, z0, [(0.2, 0.0), (0.38, 0.15), (0.42, 0.6), (0.38, 1.05), (0.2, 1.2)], 14)
    for z in (z0 + 0.1, z0 + 1.1):
        g["Gold"].cyl(0, 0, z, 0.3, 0.3, 0.06, seg=14)
    g["Glow"].cyl(0, 0, z0 - 0.01, 0.16, 0.16, 0.02, seg=10)
    g["SilkRed"].cyl(0, 0, 0.0, 0.05, 0.1, z0 - 0.02, seg=6)
    g["Iron"].cyl(0, 0, z0 + 1.2, 0.03, 0.03, 0.7, seg=6)
    annulus(g, "Iron", (0, 0, z0 + 1.98), "y", 0.06, 0.1, 0.03, n=10)
    g["LampPt"].box(0, 0, z0 + 0.6, 0.1, 0.1, 0.1)


# ================================================================ 가게
def counter(g):
    """계산대. 앞판 짙은 궤 위에 주판, 놋 저울, 돈궤와 엽전 더미, 장부"""
    W, D, H = 4.4, 1.6, 2.3
    g["Wood"].box(0, 0, H - 0.06, W, D, 0.12)
    g["WoodDark"].box(0, -D / 2 + 0.1, (H - 0.12) / 2, W, 0.2, H - 0.12)
    for sx in (-1, 1):
        g["WoodDark"].box(sx * (W / 2 - 0.1), 0, (H - 0.12) / 2, 0.2, D, H - 0.12)
    for k in range(3):
        panel_front(g, "Wood", -W / 3 + k * W / 3, -D / 2, H / 2, W / 3 - 0.3, H - 0.8)
    # 주판
    ax, ay = -1.2, -0.1
    g["WoodDark"].box(ax, ay, H + 0.03, 1.4, 0.7, 0.06)
    for sy in (-1, 1):
        g["WoodDark"].box(ax, ay + sy * 0.32, H + 0.1, 1.4, 0.06, 0.08)
    g["WoodDark"].box(ax, ay + 0.14, H + 0.1, 1.4, 0.04, 0.06)
    for k in range(9):
        x = ax - 0.6 + k * 0.15
        g["Iron"].box(x, ay, H + 0.1, 0.02, 0.6, 0.02)
        for j, y in enumerate((-0.2, -0.12, -0.04, 0.24)):
            g["WoodDark"].hcyl(x, ay + y + (0.03 if (k + j) % 3 == 0 else 0), H + 0.1, 0.05, 0.06, axis="y", seg=6)
    # 저울
    bx = 0.4
    g["WoodDark"].box(bx, 0.3, H + 0.05, 0.5, 0.4, 0.1)
    g["Brass"].cyl(bx, 0.3, H + 0.1, 0.04, 0.04, 1.1, seg=6)
    g["Brass"].box(bx, 0.3, H + 1.2, 1.4, 0.05, 0.05)
    for s in (-1, 1):
        for k in range(3):
            a = 2 * math.pi * k / 3
            tube(g, "Brass", (bx + s * 0.68, 0.3, H + 1.18),
                 (bx + s * 0.68 + 0.18 * math.cos(a), 0.3 + 0.18 * math.sin(a), H + 0.55), 0.01, seg=4)
        lathe(g, "Brass", bx + s * 0.68, 0.3, H + 0.5, [(0.08, 0.0), (0.22, 0.05), (0.24, 0.08)], 12)
    # 돈궤와 엽전
    g["WoodDark"].box(1.6, 0.2, H + 0.3, 0.9, 0.7, 0.6)
    g["Iron"].box(1.6, -0.16, H + 0.35, 0.95, 0.03, 0.08)
    g["Brass"].box(1.6, -0.17, H + 0.45, 0.14, 0.03, 0.18)
    for k in range(6):
        g["Brass"].cyl(1.0 + (k % 2) * 0.05, -0.35, H + k * 0.03, 0.12, 0.12, 0.03, seg=10)
    g["SilkBlue"].box(-0.2, -0.45, H + 0.04, 0.6, 0.45, 0.08)


def sirung(g):
    """가게 시렁. 짙은 기둥에 선반 셋: 비단 필, 사발과 청자, 옹기와 보따리"""
    W, D, H = 6.0, 1.4, 5.0
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            g["WoodDark"].box(sx * (W / 2 - 0.1), sy * (D / 2 - 0.08), H / 2, 0.16, 0.16, H)
    for z in (0.25, 1.9, 3.5, H - 0.05):
        g["Wood"].box(0, 0, z, W, D, 0.1)
    silks = ["SilkRed", "SilkBlue", "SilkYellow", "SilkGreen", "SilkRed", "SilkBlue", "Porcelain", "SilkGreen"]
    for k, mat in enumerate(silks):   # 비단 필은 누워 앞으로 보인다
        x = -2.6 + k * 0.72
        g[mat].hcyl(x, 0, 3.8, 0.28, 1.2, axis="y", seg=12)
        if k % 3 == 0:
            g[silks[(k + 2) % len(silks)]].hcyl(x + 0.36, 0, 4.3, 0.26, 1.1, axis="y", seg=12)
    for k in range(6):
        x = -2.5 + k * 1.0
        if k % 2 == 0:
            for j in range(3):
                lathe(g, "Porcelain", x, 0, 2.0 + j * 0.13, [(0.12, 0.0), (0.26, 0.09), (0.3, 0.15)], 12)
        else:
            lathe(g, "Celadon", x, 0, 2.0, [(0.12, 0.0), (0.26, 0.2), (0.28, 0.45), (0.12, 0.8), (0.1, 0.95)], 12)
    for k, x in enumerate((-2.2, -0.6, 1.2)):
        s = 0.9 + 0.15 * k
        lathe(g, "Onggi", x, 0, 0.3, [(0.2 * s, 0.0), (0.4 * s, 0.35 * s), (0.42 * s, 0.8 * s), (0.25 * s, 1.1 * s),
                                      (0.28 * s, 1.15 * s)], 14)
    for x, mat in ((0.3, "SilkBlue"), (2.2, "SilkRed")):
        g[mat].box(x, 0, 0.75, 1.0, 0.9, 0.9)
        g[mat].obox(x, 0, 1.25, 0.3, 0.3, 0.3, rz=0.785)


# ================================================================ 척수관
def specimen_shelf(g):
    """
    표본 선반. 선반 셋에 유리 항아리가 줄지어 섰다. 항아리 속에 말린 짐승 조각
    (말린 몸통과 꼬리, 눈알, 뼈)이 보이고 놋 뚜껑과 한지 이름표를 붙였다
    """
    W, D, H = 6.0, 1.3, 5.5
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            g["WoodDark"].box(sx * (W / 2 - 0.1), sy * (D / 2 - 0.08), H / 2, 0.16, 0.16, H)
    g["Wood"].box(0, D / 2 - 0.04, H / 2, W, 0.08, H)
    shelves = (0.2, 1.95, 3.7, H - 0.05)
    for z in shelves:
        g["Wood"].box(0, 0, z, W, D, 0.1)
    kinds = ["curl", "eye", "bone", "curl", "bone", "eye", "curl", "bone", "curl", "eye", "bone", "curl"]
    for row, z0 in enumerate(shelves[:3]):
        for k in range(4):
            x = -2.2 + k * 1.45 + (0.2 if row == 1 else 0)
            s = 0.9 + 0.12 * ((k + row) % 3)
            h = 1.1 * s
            kind = kinds[row * 4 + k]
            if kind == "curl":
                ball(g, "Hide", x, 0, z0 + 0.1 + h * 0.4, 0.22 * s, seg=10)
                tube(g, "Hide", (x + 0.15, 0, z0 + 0.1 + h * 0.4), (x + 0.2, 0, z0 + 0.1 + h * 0.75), 0.05, seg=6)
                ball(g, "Bone", x - 0.12, -0.12, z0 + 0.1 + h * 0.5, 0.05, seg=6)
            elif kind == "eye":
                ball(g, "Porcelain", x, 0, z0 + 0.1 + h * 0.45, 0.24 * s, seg=12)
                g["Ink"].hcyl(x, -0.24 * s, z0 + 0.1 + h * 0.45, 0.09 * s, 0.03, axis="y", seg=10)
                g["SilkRed"].hcyl(x, -0.23 * s, z0 + 0.1 + h * 0.45, 0.14 * s, 0.02, axis="y", seg=10)
            else:
                tube(g, "Bone", (x - 0.12, 0, z0 + 0.15), (x + 0.1, 0, z0 + 0.1 + h * 0.8), 0.05, seg=6)
                ball(g, "Bone", x + 0.1, 0, z0 + 0.1 + h * 0.8, 0.09, seg=6)
                ball(g, "Bone", x - 0.12, 0, z0 + 0.15, 0.08, seg=6)
            lathe(g, "Glass", x, 0, z0 + 0.05, [(0.36 * s, 0.0), (0.4 * s, 0.1), (0.4 * s, h), (0.3 * s, h + 0.08)], 14)
            g["Brass"].cyl(x, 0, z0 + 0.05 + h + 0.06, 0.33 * s, 0.33 * s, 0.1, seg=14)
            g["Paper"].box(x, -0.41 * s, z0 + 0.05 + h * 0.3, 0.3, 0.02, 0.22)


def yakjang(g):
    """약장. 여섯 줄 다섯 칸 서랍, 칸마다 놋 고리와 한지 이름표. 위에 약 단지"""
    W, D, H = 3.2, 1.1, 4.2
    g["Wood"].box(0, 0, 0.2 + H / 2, W, D, H)
    g["WoodDark"].box(0, 0, 0.2 + H + 0.05, W + 0.1, D + 0.1, 0.1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["WoodDark"].box(sx * (W / 2 - 0.1), sy * (D / 2 - 0.1), 0.1, 0.2, 0.2, 0.2)
    rows, cols = 6, 5
    for r in range(rows):
        for c in range(cols):
            cx = -W / 2 + W * (c + 0.5) / cols
            cz = 0.2 + H * (r + 0.5) / rows
            panel_front(g, "WoodDark", cx, -D / 2, cz, W / cols - 0.08, H / rows - 0.08)
            g["Paper"].box(cx, -D / 2 - 0.05, cz + 0.16, 0.3, 0.02, 0.14)
            g["Brass"].hcyl(cx, -D / 2 - 0.06, cz - 0.08, 0.06, 0.04, axis="y", seg=8)
    for x, s in ((-0.9, 1.0), (0.3, 0.8), (1.1, 0.9)):
        lathe(g, "Onggi" if s > 0.85 else "Celadon", x, 0, 0.2 + H + 0.1,
              [(0.15 * s, 0.0), (0.3 * s, 0.2), (0.28 * s, 0.45), (0.16 * s, 0.55)], 12)


def haebudae(g):
    """
    해부대. 굵은 다리 넷과 가로대 받친 짙은 판 위에 짐승 가죽을 펼치고 뿔 달린 머리뼈,
    칼 셋, 놋 사발, 적어 둔 한지
    """
    W, D, H = 5.0, 2.6, 2.4
    g["WoodDark"].box(0, 0, H - 0.15, W, D, 0.3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["WoodDark"].box(sx * (W / 2 - 0.3), sy * (D / 2 - 0.3), (H - 0.3) / 2, 0.35, 0.35, H - 0.3)
        g["Wood"].box(sx * (W / 2 - 0.3), 0, 0.5, 0.2, D - 0.6, 0.2)
    g["Wood"].box(0, 0, 0.5, W - 0.6, 0.2, 0.2)
    g["Hide"].obox(-0.4, 0.1, H + 0.04, 3.0, 1.9, 0.06, rz=0.12)
    for sx, sy in ((-1.7, 0.9), (0.9, 0.95), (-1.8, -0.7), (1.0, -0.8)):
        g["Hide"].obox(-0.4 + sx, 0.1 + sy * 0.6, H + 0.04, 0.6, 0.5, 0.05, rz=0.6 * sx)
    sx0, sy0 = 1.7, -0.3
    ball(g, "Bone", sx0, sy0, H + 0.35, 0.35, seg=12)
    g["Bone"].box(sx0 - 0.3, sy0, H + 0.2, 0.5, 0.35, 0.2)
    for s in (-1, 1):
        g["Ink"].hcyl(sx0 - 0.15, sy0 + s * 0.14, H + 0.42, 0.08, 0.1, axis="x", seg=8)
        cone_between(g, "Bone", (sx0 + 0.1, sy0 + s * 0.25, H + 0.55), (sx0 + 0.45, sy0 + s * 0.65, H + 0.95), 0.1, 0.02, seg=8)
    for k in range(3):
        y = -0.9 + k * 0.25
        g["Iron"].box(0.2 + k * 0.1, y, H + 0.02, 0.6, 0.08, 0.03)
        g["Wood"].box(-0.25 + k * 0.1, y, H + 0.04, 0.35, 0.1, 0.07)
    lathe(g, "Brass", 2.0, 0.8, H, [(0.12, 0.0), (0.28, 0.12), (0.32, 0.22)], 12)
    g["Paper"].obox(-2.0, -0.9, H + 0.01, 0.8, 0.55, 0.01, rz=-0.2)


def malim(g):
    """말림 시렁. 양끝 A 자 틀에 가로대 둘, 짐승 가죽과 약초 다발, 뼈를 걸어 말린다"""
    W, H = 5.0, 4.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            tube(g, "Wood", (sx * W / 2, sy * 0.9, 0.1), (sx * W / 2, 0, H), 0.1, seg=6)
    for z in (H - 0.3, H - 1.6):
        g["Wood"].hcyl(0, 0, z, 0.08, W + 0.4, axis="x", seg=8)
    for k, x in enumerate((-1.7, -0.3, 1.2)):
        g["Hide"].obox(x, 0.05, H - 1.25, 1.1 - 0.15 * k, 0.05, 1.8, ry=0.05 * (k - 1))
    for k in range(5):
        x = -2.0 + k * 1.0
        g["Iron"].cyl(x, 0, H - 2.1, 0.015, 0.015, 0.5, seg=4)
        g["Peak"].cyl(x, 0, H - 2.6, 0.08, 0.2, 0.5, seg=8)
    for x in (-0.9, 0.6, 2.0):
        tube(g, "Bone", (x, 0, H - 1.7), (x + 0.1, 0, H - 2.5), 0.05, seg=6)
        ball(g, "Bone", x + 0.1, 0, H - 2.55, 0.08, seg=6)


def gwe(g):
    """궤짝 셋. 쇠 모서리와 띠를 두른 나무 궤를 쌓고, 하나는 열어 짚 속에 단지"""
    for x, y, z, s, rz in ((-0.8, 0, 0, 1.6, 0.0), (0.95, 0.1, 0, 1.4, 0.1), (-0.6, 0.05, 1.6, 1.3, -0.12)):
        g["Wood"].obox(x, y, z + s / 2, s, s * 0.9, s, rz=rz)
        for dz in (0.1, s - 0.1):
            g["Iron"].obox(x, y, z + dz, s + 0.04, s * 0.9 + 0.04, 0.1, rz=rz)
    g["Straw"].obox(0.95, 0.1, 1.42, 1.2, 1.1, 0.06, rz=0.1)
    lathe(g, "Onggi", 1.0, 0.1, 1.2, [(0.15, 0.0), (0.3, 0.2), (0.28, 0.45), (0.15, 0.55)], 12)


# ================================================================ 곳간·헛간
def gamani(g):
    """가마니 더미. 짚 가마니를 두 줄로 쌓고 새끼 매듭을 두른다"""
    spots = [(-1.3, 0, 0), (0.0, 0, 0), (1.3, 0, 0), (-0.65, 0, 1), (0.65, 0, 1), (0.0, 0, 2)]
    for x, y, lvl in spots:
        z = 0.61 + lvl * 0.95   # 새끼 매듭(반지름 0.6)이 바닥에 닿게
        g["Straw"].hcyl(x, y, z, 0.55, 1.8, axis="y", seg=10)
        for e in (-1, 1):
            g["Straw"].hcyl(x, y + e * 0.95, z, 0.4, 0.12, axis="y", seg=10)
        for k in (-0.4, 0.4):
            annulus(g, "Wood", (x, y + k, z), "y", 0.54, 0.6, 0.06, n=12)


def duiju(g):
    """뒤주. 네 발 위 쌀 궤, 반씩 여는 뚜껑과 놋 경첩, 앞 무쇠 장식. 옆에 쌀 담긴 말과 되"""
    W, D = 2.4, 1.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["WoodDark"].box(sx * (W / 2 - 0.12), sy * (D / 2 - 0.12), 0.35, 0.24, 0.24, 0.7)
    g["Wood"].box(0, 0, 0.6 + 0.8, W, D, 1.6)
    g["WoodDark"].box(0, 0.35, 2.25, W + 0.08, D / 2 + 0.1, 0.1)
    g["Wood"].box(0, -0.4, 2.25, W + 0.08, D / 2 - 0.1, 0.1)
    for sx in (-1, 1):
        g["Brass"].box(sx * 0.6, 0.0, 2.32, 0.2, 0.3, 0.03)
    g["Iron"].box(0, -D / 2 - 0.02, 1.7, 0.7, 0.03, 0.5)
    g["Brass"].hcyl(0, -D / 2 - 0.04, 1.7, 0.12, 0.03, axis="y", seg=10)
    for x, s in ((W / 2 + 0.8, 0.9), (W / 2 + 0.8, 0.55)):
        y = -0.2 if s > 0.6 else 0.6
        for sy in (-1, 1):
            g["Wood"].box(x, y + sy * (s / 2 - 0.03), s * 0.35, s, 0.06, s * 0.7)
            g["Wood"].box(x + sy * (s / 2 - 0.03), y, s * 0.35, 0.06, s, s * 0.7)
        g["Porcelain"].box(x, y, s * 0.62, s - 0.1, s - 0.1, 0.06)


def meongseok(g):
    """헛간 살림. 말아 세운 멍석과 깐 멍석, 기대 세운 지게, 소쿠리 둘"""
    g["Straw"].box(0.6, 0.4, 0.03, 3.0, 2.2, 0.06)
    for k in range(10):
        g["Wood"].box(-0.8 + k * 0.3, 0.4, 0.065, 0.02, 2.2, 0.01)
    g["Straw"].cyl(-1.7, 0.8, 0, 0.45, 0.45, 2.6, seg=12)
    g["Wood"].cyl(-1.7, 0.8, 2.59, 0.2, 0.2, 0.02, seg=10)
    # 지게. 뒤(+y)로 기대 세운다
    for sx in (-1, 1):
        tube(g, "Wood", (1.6 + sx * 0.35, 0.3, 0.07), (1.6 + sx * 0.28, 0.95, 3.2), 0.07, seg=6)
    for t in (0.3, 0.55, 0.8):
        y, z = 0.3 + 0.65 * t, 3.2 * t
        g["Wood"].box(1.6, y, z, 0.6, 0.08, 0.08)
    tube(g, "Wood", (1.6, 0.5, 1.0), (1.6, -0.4, 1.3), 0.05, seg=6)
    for x, y in ((0.2, -0.8), (1.0, -0.9)):
        lathe(g, "Straw", x, y, 0, [(0.25, 0.0), (0.45, 0.1), (0.55, 0.3), (0.58, 0.33)], 14)


# ================================================================ 가게 좌판 물건 (좌판 윗면 7.2 x 2.7 에 얹는다)
def silk_bolt(g, mat, x, y, z, length, r):
    """비단 한 필. 앞뒤(y)로 뉘었다. 가운데 한지 띠, 두 마구리에 말린 결 고리와 종이 심"""
    g[mat].hcyl(x, y, z, r, length, axis="y", seg=14)
    g["Paper"].hcyl(x, y, z, r + 0.015, 0.16, axis="y", seg=14)
    for e in (-1, 1):
        yy = y + e * (length / 2 + 0.01)
        annulus(g, mat, (x, yy, z), "y", r * 0.55, r * 0.7, 0.03, n=12)
        annulus(g, "Paper", (x, yy, z), "y", 0.05, 0.11, 0.03, n=10)


def stall_cloth(g):
    """비단 가게. 두 단 나무 진열대에 비단 필을 앞으로 뉘어 두 줄, 오른쪽에 개킨 천 더미, 앞에 자"""
    g["Wood"].box(0, 0, 0.06, 6.6, 2.3, 0.12)
    g["WoodDark"].box(0, 0.6, 0.37, 6.6, 1.0, 0.5)
    for k, m in enumerate(("SilkRed", "SilkBlue", "Porcelain", "SilkGreen", "SilkYellow")):
        silk_bolt(g, m, -2.4 + k * 1.0, -0.3, 0.52, 1.4, 0.4)
    for k, m in enumerate(("Sky", "Lacquer", "SilkGreen", "SilkRed")):
        silk_bolt(g, m, -1.9 + k * 1.0, 0.6, 1.0, 0.95, 0.37)
    for k, m in enumerate(("Porcelain", "SilkYellow", "SilkBlue", "SilkRed", "Porcelain")):
        g[m].box(2.7 + 0.03 * (k % 2), -0.35 + 0.02 * k, 0.18 + k * 0.13, 1.0, 0.9, 0.12)
    g["Wood"].box(-0.4, -1.02, 0.14, 2.2, 0.1, 0.04)
    for k in range(11):
        g["Ink"].box(-1.45 + k * 0.21, -1.02, 0.165, 0.02, 0.06, 0.01)


def onggi_jar(g, x, y, z, h, lid=True):
    """옹기 독. 굽, 불룩한 배, 손으로 그은 어깨 띠, 입술. 뚜껑과 꼭지"""
    r = h * 0.42
    lathe(g, "Onggi", x, y, z, [(r * 0.55, 0.0), (r * 0.62, 0.04 * h), (r * 0.9, 0.25 * h), (r, 0.5 * h),
                                (r * 0.92, 0.7 * h), (r * 0.62, 0.86 * h), (r * 0.5, 0.92 * h), (r * 0.57, 0.95 * h),
                                (r * 0.57, h)], 18)
    annulus(g, "Onggi", (x, y, z + 0.72 * h), "z", r * 0.86, r * 0.93, 0.03 * h, n=18)
    if lid:
        lathe(g, "Onggi", x, y, z + h, [(r * 0.64, 0.0), (r * 0.6, 0.05 * h), (r * 0.35, 0.12 * h),
                                        (r * 0.12, 0.15 * h)], 16)
        ball(g, "Onggi", x, y, z + h + 0.16 * h, r * 0.12, seg=8)
    else:
        g["Ink"].cyl(x, y, z + h - 0.06, r * 0.5, r * 0.5, 0.04, seg=14)


def gourd_dipper(g, x, y, z, s=1.0):
    """박 바가지. 반쪽 박을 엎어 놓은 꼴"""
    lathe(g, "Straw", x, y, z, [(0.12 * s, 0.0), (0.3 * s, 0.06 * s), (0.36 * s, 0.14 * s), (0.36 * s, 0.2 * s)], 14)
    g["Wood"].obox(x + 0.3 * s, y, z + 0.18 * s, 0.35 * s, 0.05 * s, 0.04 * s, ry=-0.3)


def stall_jars(g):
    """옹기 가게. 크고 작은 독 셋(하나는 열고 바가지), 작은 단지, 백자 사발 탑, 청자 병, 값 적은 종이 팻말"""
    onggi_jar(g, -2.3, 0.3, 0, 1.9)
    onggi_jar(g, -0.7, 0.35, 0, 1.5)
    onggi_jar(g, 0.65, 0.25, 0, 1.15, lid=False)
    gourd_dipper(g, 0.65, 0.25, 1.15, 0.8)
    onggi_jar(g, 1.7, 0.6, 0, 0.7)
    onggi_jar(g, 2.5, 0.65, 0, 0.55)
    for j in range(4):
        lathe(g, "Porcelain", 1.9, -0.55, j * 0.13, [(0.12, 0.0), (0.27, 0.09), (0.31, 0.15)], 14)
    lathe(g, "Celadon", 2.9, -0.2, 0, [(0.12, 0.0), (0.24, 0.2), (0.26, 0.42), (0.1, 0.78), (0.08, 0.95),
                                        (0.11, 1.02)], 14)
    g["Wood"].box(-1.5, -0.9, 0.35, 0.05, 0.05, 0.7)
    g["Paper"].box(-1.5, -0.93, 0.62, 0.36, 0.02, 0.24)
    g["Ink"].box(-1.5, -0.945, 0.64, 0.05, 0.01, 0.14)


def crate(g, x, y, z, w, d, h, rz=0.0, open_top=False):
    """나무 궤짝. 널 이음 줄, 쇠 모서리 띠, 덮개. 열면 짚을 깔았다"""
    c, s = math.cos(rz), math.sin(rz)
    g["Wood"].obox(x, y, z + h / 2, w, d, h, rz=rz)
    for k in (1, 2):
        g["WoodDark"].obox(x, y, z + h * k / 3, w + 0.02, d + 0.02, 0.04, rz=rz)
    for ex in (-1, 1):
        for ey in (-1, 1):
            px = x + ex * (w / 2) * c - ey * (d / 2) * s
            py = y + ex * (w / 2) * s + ey * (d / 2) * c
            g["Iron"].obox(px, py, z + h / 2, 0.09, 0.09, h + 0.02, rz=rz)
    if open_top:
        g["Straw"].obox(x, y, z + h - 0.06, w - 0.12, d - 0.12, 0.1, rz=rz)
    else:
        g["WoodDark"].obox(x, y, z + h + 0.04, w + 0.06, d + 0.06, 0.08, rz=rz)


def stall_crates(g):
    """궤짝 가게. 쌓은 궤짝 둘, 짚 깐 열린 궤짝에 백자 단지 셋, 새끼로 목을 묶은 자루"""
    crate(g, -2.1, 0.2, 0, 1.8, 1.4, 1.0, rz=0.05)
    crate(g, -2.0, 0.25, 1.08, 1.4, 1.1, 0.8, rz=-0.12)
    crate(g, 0.4, 0.1, 0, 1.8, 1.3, 0.9, rz=0.0, open_top=True)
    for x, y, h in ((-0.1, 0.2, 0.55), (0.45, -0.1, 0.45), (0.95, 0.3, 0.5)):
        lathe(g, "Porcelain", x, y, 0.84, [(0.1, 0.0), (0.18, 0.1), (0.2, h * 0.6), (0.1, h), (0.12, h + 0.04)], 12)
    lathe(g, "Straw", 2.4, 0.0, 0, [(0.4, 0.0), (0.55, 0.2), (0.58, 0.6), (0.45, 0.95), (0.18, 1.12), (0.2, 1.3),
                                     (0.12, 1.4)], 14)
    annulus(g, "Wood", (2.4, 0.0, 1.13), "z", 0.17, 0.23, 0.08, n=12)


def basket(g, x, y, z, r, h):
    """대바구니. 엮은 몸과 세로 살, 가운데 엮음 띠, 테. 윗면(z + h)에 물건을 얹는다"""
    lathe(g, "Straw", x, y, z, [(r * 0.7, 0.0), (r * 0.75, 0.05), (r * 0.95, h * 0.6), (r, h)], 16)
    for k in range(12):
        a = 2 * math.pi * k / 12
        g["Wood"].obox(x + r * 0.9 * math.cos(a), y + r * 0.9 * math.sin(a), z + h * 0.5, 0.05, 0.06, h * 0.95, rz=a)
    annulus(g, "Wood", (x, y, z + h * 0.45), "z", r * 0.86, r * 0.93, 0.06, n=16)
    annulus(g, "Wood", (x, y, z + h), "z", r * 0.92, r * 1.04, 0.08, n=16)


def heap(g, mat, x, y, z, rr, n_ring=(6, 3, 1)):
    """둥근 과일을 쌓은 무더기. 켜마다 둥글게 놓고 위로 좁힌다"""
    for layer, n in enumerate(n_ring):
        rad = (len(n_ring) - 1 - layer) * rr * 1.1
        for k in range(n):
            a = 2 * math.pi * k / n + layer * 0.5
            ball(g, mat, x + rad * math.cos(a), y + rad * math.sin(a), z + rr + layer * rr * 1.5, rr, seg=10)


def stall_baskets(g):
    """나물·과일 가게. 바구니 넷(감, 사과, 곡식, 고추), 앞에 배추 둘과 무 둘"""
    spots = (-2.5, -0.85, 0.85, 2.5)
    for x in spots:
        basket(g, x, 0.25, 0, 0.72, 0.55)
    heap(g, "Fruit", spots[0], 0.25, 0.5, 0.15)
    heap(g, "SilkRed", spots[1], 0.25, 0.5, 0.14)
    lathe(g, "Straw", spots[2], 0.25, 0.5, [(0.66, 0.0), (0.5, 0.2), (0.25, 0.38), (0.08, 0.45)], 14)
    for k in range(14):
        a = k * 2.4
        rr = 0.1 + 0.035 * (k % 5)
        g["SilkRed"].obox(spots[3] + rr * math.cos(a), 0.25 + rr * math.sin(a), 0.6 + 0.03 * (k % 3), 0.38, 0.07, 0.07,
                          rz=a)
    for x in (-1.9, -1.1):
        lathe(g, "Peak", x, -0.8, 0.0, [(0.18, 0.0), (0.3, 0.15), (0.32, 0.45), (0.25, 0.75), (0.1, 0.88)], 12)
        for k in range(3):
            a = 2 * math.pi * k / 3
            g["SilkGreen"].obox(x + 0.28 * math.cos(a), -0.8 + 0.28 * math.sin(a), 0.35, 0.3, 0.05, 0.6, rz=a, rx=0.25)
    for x in (0.9, 1.9):
        tube(g, "Porcelain", (x, -0.95, 0.17), (x + 0.6, -0.7, 0.17), 0.13, seg=10)
        for k in range(3):
            tube(g, "SilkGreen", (x, -0.95, 0.17), (x - 0.35, -1.0 + 0.12 * k, 0.43), 0.05, seg=5)


# ================================================================ 마당 살림 (절화 마당 틀 Prop_* 를 갈아 끼운다)
def yard_jangdok(g):
    """
    장독대. 두 켜 돌 단 가장자리에 막돌을 두르고, 뒷줄 큰 독 넷, 앞줄 작은 독 다섯.
    하나는 짚 덮개, 하나는 열고 바가지를 얹었다. 옛 틀 발자국 8.8 x 5.4 에 맞춘다
    """
    g["Stone"].box(0, 0, 0.2, 8.8, 5.4, 0.4)
    g["Stone"].box(0, 0.25, 0.55, 8.2, 4.6, 0.3)
    for k in range(11):
        w = 0.62 + 0.18 * ((k * 7) % 3)
        g["Stone"].obox(-4.1 + k * 0.82, -2.62, 0.25, w, 0.32, 0.46 + 0.06 * (k % 2), rz=0.06 * ((k % 3) - 1))
    for sx in (-1, 1):
        for k in range(6):
            g["Stone"].obox(sx * 4.3, -2.1 + k * 0.85, 0.24, 0.3, 0.7, 0.44, rz=0.05 * ((k % 3) - 1))
    for i, (x, h, kind) in enumerate(((-3.0, 2.3, "lid"), (-1.0, 2.1, "straw"), (1.0, 2.4, "lid"), (3.0, 2.0, "lid"))):
        onggi_jar(g, x, 1.25, 0.7, h, lid=(kind == "lid"))
        if kind == "straw":
            r = h * 0.42
            lathe(g, "Straw", x, 1.25, 0.7 + h - 0.04, [(r * 0.8, 0.0), (r * 0.55, 0.3), (r * 0.1, 0.55)], 14)
            annulus(g, "Wood", (x, 1.25, 0.7 + h + 0.08), "z", r * 0.66, r * 0.72, 0.05, n=14)
    for i, (x, h) in enumerate(((-3.3, 1.3), (-1.65, 1.5), (0.0, 1.1), (1.65, 1.4), (3.3, 1.2))):
        onggi_jar(g, x, -1.05, 0.7, h, lid=(i != 2))
    gourd_dipper(g, 0.0, -1.05, 0.7 + 1.1, 0.8)
    lathe(g, "Onggi", 0.9, -2.05, 0.7, [(0.34, 0.0), (0.3, 0.04), (0.18, 0.1), (0.06, 0.13)], 14)


def yard_well(g):
    """
    우물. 막돌을 세 켜 엇갈려 둥글게 쌓고 돌 갓을 얹었다. 어두운 물, 두 기둥 도르래 틀과 밧줄,
    갓 위 두레박, 작은 기와 지붕, 옆에 돌 구유. 옛 틀 발자국 7 x 7
    """
    g["Stone"].box(0, 0, 0.1, 7.0, 7.0, 0.2)
    R, n = 1.9, 14
    for layer in range(3):
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * (layer % 2)) / n
            w = 2 * math.pi * R / n * (0.98 + 0.08 * ((k + layer) % 3))
            g["Stone"].obox(R * math.cos(a), R * math.sin(a), 0.2 + 0.35 + layer * 0.7, w, 0.72, 0.66, rz=a + math.pi / 2)
    annulus(g, "Stone", (0, 0, 2.38), "z", 1.5, 2.36, 0.16, n=28)
    g["Ink"].cyl(0, 0, 1.85, 1.55, 1.55, 0.05, seg=20)
    g["Glass"].cyl(0, 0, 1.91, 1.52, 1.52, 0.02, seg=20)
    for sx in (-1, 1):
        g["Wood"].box(sx * 2.85, 0, 2.7, 0.32, 0.32, 5.0)
        g["Stone"].box(sx * 2.85, 0, 0.35, 0.6, 0.6, 0.3)
    g["Wood"].box(0, 0, 4.95, 6.2, 0.26, 0.26)
    g["Wood"].box(0, 0, 4.55, 0.22, 0.22, 0.6)
    annulus(g, "WoodDark", (0, 0, 4.1), "y", 0.12, 0.3, 0.12, n=16)
    g["Iron"].hcyl(0, 0, 4.1, 0.05, 0.3, axis="y", seg=8)
    tube(g, "Straw", (0.3, 0, 4.1), (1.2, -0.95, 2.95), 0.03, seg=5)
    bx, by = 1.2, -0.95
    lathe(g, "Wood", bx, by, 2.46, [(0.26, 0.0), (0.3, 0.05), (0.34, 0.45), (0.36, 0.5)], 14)
    for z in (2.56, 2.86):
        annulus(g, "Iron", (bx, by, z), "z", 0.3, 0.36, 0.04, n=14)
    annulus(g, "Iron", (bx, by, 3.0), "x", 0.3, 0.34, 0.03, n=14)
    for sy in (-1, 1):
        g["Tile"].obox(0, sy * 0.85, 5.5, 7.0, 1.95, 0.14, rx=-sy * 0.45)
        for k in range(8):
            g["Tile"].obox(-3.1 + k * 0.886, sy * 0.85, 5.58, 0.14, 1.9, 0.09, rx=-sy * 0.45)
        g["WoodDark"].box(0, sy * 1.6, 5.02, 6.6, 0.12, 0.12)
    g["Tile"].box(0, 0, 5.95, 7.2, 0.4, 0.3)
    for sx in (-1, 1):
        g["Tile"].box(sx * 3.55, 0, 6.0, 0.3, 0.45, 0.45)
    g["Stone"].box(2.5, -2.7, 0.45, 1.7, 0.9, 0.5)
    g["Glass"].box(2.5, -2.7, 0.66, 1.4, 0.6, 0.04)


def haystack(g, cx, cy, s):
    """짚가리 하나. 짚을 켜켜이 둘러 쌓아 켜마다 처마가 지고, 꼭대기 틀어 얹은 짚과 새끼 테 둘"""
    for (r, z, h) in ((1.9, 0.0, 1.0), (1.85, 0.9, 0.9), (1.7, 1.7, 0.8), (1.45, 2.4, 0.7), (1.1, 3.0, 0.6)):
        lathe(g, "Straw", cx, cy, z * s, [(r * s * 0.95, 0.0), (r * s, 0.12 * h * s), (r * s * 0.9, h * s)], 18)
    lathe(g, "Straw", cx, cy, 3.5 * s, [(0.95 * s, 0.0), (0.45 * s, 0.6 * s), (0.12 * s, 1.0 * s)], 14)
    tube(g, "Straw", (cx, cy, 4.45 * s), (cx + 0.25 * s, cy, 4.95 * s), 0.12 * s, seg=6)
    # 새끼 테는 그 높이의 짚 면에 붙인다 (켜 1 의 z 0.55 는 반지름 1.81, 켜 3 의 z 2.05 는 1.63)
    for z, r in ((0.55, 1.81), (2.05, 1.63)):
        annulus(g, "Wood", (cx, cy, z * s), "z", (r - 0.04) * s, (r + 0.05) * s, 0.07 * s, n=18)


def yard_haystack(g):
    """짚가리 둘과 볏단. 볏단은 허리를 묶어 세우거나 뉘었다. 옛 틀 발자국 x -4.2..4.8, y -3.3..2.5"""
    haystack(g, -1.4, 0.2, 1.0)
    haystack(g, 2.6, -0.6, 0.8)
    for (x, y, lean) in ((-3.4, -2.4, 0.15), (-2.7, -2.7, -0.1), (-1.9, -2.5, 0.2), (0.6, -2.6, -0.15)):
        tube(g, "Straw", (x, y, 0.12), (x + lean, y, 1.4), 0.26, seg=10)
        lathe(g, "Straw", x + lean, y, 1.38, [(0.26, 0.0), (0.4, 0.25), (0.44, 0.36)], 10)
        for j in range(7):   # 이삭 끝. 볏단 위로 벌어진 짚대
            a = 2 * math.pi * j / 7
            tube(g, "Straw", (x + lean + 0.2 * math.cos(a), y + 0.2 * math.sin(a), 1.7),
                 (x + lean + 0.5 * math.cos(a), y + 0.5 * math.sin(a), 2.05), 0.035, seg=4)
        annulus(g, "Wood", (x + lean * 0.6, y, 0.85), "z", 0.24, 0.3, 0.07, n=10)
    for (x, y) in ((3.6, 1.6), (2.4, 1.9)):
        tube(g, "Straw", (x - 0.9, y, 0.34), (x + 0.9, y, 0.34), 0.3, seg=10)
        annulus(g, "Wood", (x, y, 0.36), "x", 0.28, 0.34, 0.07, n=10)
    tube(g, "Wood", (4.4, -2.9, 0.1), (4.1, -2.0, 2.8), 0.05, seg=6)
    for k in range(3):
        tube(g, "Iron", (4.12 + (k - 1) * 0.12, -2.05, 2.75), (4.12 + (k - 1) * 0.14, -1.95, 3.3), 0.025, seg=4)


def yard_garden(g):
    """
    텃밭. 널 테두리 안 흙에 두둑 다섯: 배추, 무, 지주 세운 고추, 파, 어린 상추.
    한 귀에 물동이와 호미. 옛 틀 발자국 11.8 x 8.4
    """
    W, D = 11.8, 8.4
    for sy in (-1, 1):
        g["Wood"].box(0, sy * (D / 2 - 0.1), 0.2, W, 0.2, 0.4)
    for sx in (-1, 1):
        g["Wood"].box(sx * (W / 2 - 0.1), 0, 0.2, 0.2, D, 0.4)
        for sy in (-1, 1):
            g["WoodDark"].box(sx * (W / 2 - 0.1), sy * (D / 2 - 0.1), 0.3, 0.3, 0.3, 0.6)
    g["Soil"].box(0, 0, 0.1, W - 0.4, D - 0.4, 0.2)
    rows = [-3.0, -1.5, 0.0, 1.5, 3.0]
    for y in rows:
        extrude(g, "Soil", [(y - 0.55, 0.2), (y + 0.55, 0.2), (y + 0.3, 0.55), (y - 0.3, 0.55)], -5.3, 5.3, plane="yz")
    top = 0.55
    for k in range(7):   # 배추
        x = -4.6 + k * 1.5
        y = rows[0]
        lathe(g, "Peak", x, y, top, [(0.16, 0.0), (0.27, 0.14), (0.3, 0.42), (0.23, 0.7), (0.1, 0.82)], 12)
        for j in range(4):
            a = 2 * math.pi * j / 4 + k
            g["SilkGreen"].obox(x + 0.26 * math.cos(a), y + 0.26 * math.sin(a), top + 0.28, 0.28, 0.05, 0.55, rz=a,
                                rx=0.3)
    for k in range(9):   # 무
        x = -4.8 + k * 1.2
        y = rows[1]
        g["Porcelain"].cyl(x, y, top - 0.05, 0.13, 0.11, 0.28, seg=10)
        for j in range(4):
            a = 2 * math.pi * j / 4 + 0.4 * k
            tube(g, "SilkGreen", (x, y, top + 0.2), (x + 0.3 * math.cos(a), y + 0.3 * math.sin(a), top + 0.6), 0.05, seg=5)
    for k in range(6):   # 고추 (지주)
        x = -4.4 + k * 1.75
        y = rows[2]
        g["Wood"].box(x + 0.12, y, top + 0.6, 0.05, 0.05, 1.2)
        ball(g, "Peak", x, y, top + 0.75, 0.32, seg=10)
        for j in range(4):
            a = 2 * math.pi * j / 4 + k
            g["SilkRed"].obox(x + 0.28 * math.cos(a), y + 0.28 * math.sin(a), top + 0.55, 0.06, 0.06, 0.26, rz=a)
    for k in range(12):   # 파
        x = -5.0 + k * 0.9
        y = rows[3]
        for j in range(5):
            a = 2 * math.pi * j / 5
            g["Peak"].cyl(x + 0.08 * math.cos(a), y + 0.08 * math.sin(a), top, 0.03, 0.025, 0.7 + 0.08 * (j % 2), seg=5)
    for k in range(9):   # 상추
        x = -4.8 + k * 1.2
        y = rows[4]
        ball(g, "Peak", x, y, top + 0.1, 0.12, seg=8)
        for j in range(6):   # 벌어진 잎 여섯
            a = 2 * math.pi * j / 6 + 0.3 * k
            g["SilkGreen"].obox(x + 0.16 * math.cos(a), y + 0.16 * math.sin(a), top + 0.14, 0.26, 0.04, 0.3, rz=a + math.pi / 2,
                                rx=0.9)
    lathe(g, "Onggi", 5.1, 3.55, 0.4, [(0.18, 0.0), (0.3, 0.15), (0.34, 0.4), (0.25, 0.6), (0.22, 0.62)], 14)
    for sx in (-1, 1):
        annulus(g, "Onggi", (5.1 + sx * 0.34, 3.55, 0.85), "y", 0.05, 0.09, 0.04, n=8)
    tube(g, "Wood", (-5.3, 3.4, 0.45), (-3.8, 3.1, 0.45), 0.04, seg=6)
    g["Iron"].obox(-3.7, 3.08, 0.43, 0.08, 0.3, 0.2, rz=0.2)


# ================================================================ 바깥 (절화 3판이 기본 도형으로 놓은 품계석·이랑·다리 난간을 갈아 끼운다)
def pumgye(g):
    """
    품계석. 두 켜 받침돌 위에 네모 돌을 세우고 머리를 둥글게 깎았다. 머리와 몸 사이 띠 한 줄,
    앞면(-y)에 글 새길 판을 가는 테로 두른다. 글(正一品 따위)은 Studio 에서 단다. 옛 자리 1.4 x 2.2 x 1.0
    """
    g["Granite"].box(0, 0, 0.11, 1.5, 1.1, 0.22)
    frustum(g, "Granite", 0, 0, 0.22, 1.5, 1.1, 1.26, 0.86, 0.08)
    g["Granite"].box(0, 0, 1.1, 1.08, 0.62, 1.6)
    g["Granite"].box(0, 0, 1.93, 1.14, 0.68, 0.06)
    head = [(0.54 * math.cos(math.pi * (1 - k / 10)), 1.96 + 0.3 * math.sin(math.pi * (1 - k / 10))) for k in range(11)]
    extrude(g, "Granite", head, -0.31, 0.31)
    for x in (-0.4, 0.4):
        g["Granite"].box(x, -0.325, 1.15, 0.05, 0.03, 1.3)
    for z in (0.525, 1.775):
        g["Granite"].box(0, -0.325, z, 0.85, 0.03, 0.05)


def furrow(g):
    """이랑 두둑 한 토막. 길이 10 을 앞뒤(y)로 누인다. 토막을 잇대어 한 줄을 만든다"""
    extrude(g, "Soil", [(-0.8, 0.0), (0.8, 0.0), (0.55, 0.3), (-0.55, 0.3)], -5.0, 5.0)


def blade(g, mat, x, y, z, tx, ty, tz, w):
    """풀잎 하나. 밑 세모(너비 w)에서 끝 한 점으로 모이는 네 면"""
    v = [(x - w, y, z), (x + w * 0.5, y - w * 0.87, z), (x + w * 0.5, y + w * 0.87, z), (tx, ty, tz)]
    g[mat].add_mesh(v, [(0, 2, 1), (0, 1, 3), (1, 2, 3), (2, 0, 3)])


def leaf(g, mat, base, tip, w, lift=0.0):
    """
    잎 한 장. base 에서 tip 으로 뻗은 납작한 마름모, 밑에서 4 할 자리가 가장 넓다. 가운데 잎맥이 도드라지고
    양면이 보인다(닫힌 팔면체). lift 만큼 넓은 자리를 들어 올려 잎이 휜다
    """
    from mathutils import Vector
    b, t = Vector(base), Vector(tip)
    d = t - b
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-6:
        side = Vector((1, 0, 0))
    side.normalize()
    n = side.cross(d).normalized()
    if n.z < 0:
        n = -n
    m = b + d * 0.4 + n * lift
    th = w / 6
    v = [b, t, m + side * w / 2, m - side * w / 2, m + n * th, m - n * th]
    g[mat].add_mesh([tuple(p) for p in v],
                    [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (0, 5, 2), (2, 5, 1), (1, 5, 3), (3, 5, 0)])


def crop_barley(g):
    """보리 한 토막. 포기 열하나, 포기마다 벌어진 잎 여섯과 줄기 셋, 줄기 끝 가는 이삭에 까락 둘"""
    furrow(g)
    rnd = random.Random(11)
    for k in range(11):
        x, y = rnd.uniform(-0.15, 0.15), -4.55 + k * 0.91 + rnd.uniform(-0.15, 0.15)
        h = rnd.uniform(1.3, 1.65)
        for j in range(6):
            a = 2 * math.pi * j / 6 + rnd.uniform(0, 0.9)
            lean = rnd.uniform(0.3, 0.55)
            blade(g, "Leaf", x, y, 0.25, x + lean * math.cos(a), y + lean * math.sin(a), 0.25 + h * rnd.uniform(0.55, 0.85), 0.07)
        for j in range(3):
            a = 2 * math.pi * j / 3 + k
            ex, ey, ez = x + 0.14 * math.cos(a), y + 0.14 * math.sin(a), 0.25 + h
            cone_between(g, "Barley", (x, y, 0.25), (ex, ey, ez + 0.02), 0.035, 0.022, seg=3)
            tx, ty, tz = ex + 0.12 * math.cos(a), ey + 0.12 * math.sin(a), ez + 0.5
            cone_between(g, "Barley", (ex, ey, ez), (tx, ty, tz), 0.055, 0.025, seg=5)
            for da in (-0.5, 0.5):
                blade(g, "Barley", tx, ty, tz - 0.08, tx + 0.1 * math.cos(a + da), ty + 0.1 * math.sin(a + da), tz + 0.38, 0.012)


def crop_cabbage(g):
    """배추 한 토막. 통 다섯, 흰 밑동에서 연둣빛 속잎 넷이 위로 여미고, 짙은 겉잎 여섯이 휘어 벌어진다"""
    furrow(g)
    rnd = random.Random(23)
    for k in range(5):
        x, y = rnd.uniform(-0.1, 0.1), -4.0 + k * 2.0 + rnd.uniform(-0.2, 0.2)
        s = rnd.uniform(0.9, 1.1)
        z0 = 0.28
        lathe(g, "NapaPale", x, y, z0, [(0.22 * s, 0.0), (0.36 * s, 0.22 * s), (0.4 * s, 0.5 * s)], 9)
        lathe(g, "Napa", x, y, z0 + 0.5 * s, [(0.4 * s, 0.0), (0.36 * s, 0.3 * s), (0.26 * s, 0.52 * s), (0.08 * s, 0.62 * s)], 9)
        for j in range(4):
            a = 2 * math.pi * j / 4 + rnd.uniform(0, 0.6)
            leaf(g, "Napa", (x + 0.37 * s * math.cos(a), y + 0.37 * s * math.sin(a), z0 + 0.45 * s),
                 (x + 0.06 * s * math.cos(a), y + 0.06 * s * math.sin(a), z0 + 1.18 * s), 0.4 * s, lift=0.15 * s)
        for j in range(6):
            a = 2 * math.pi * j / 6 + rnd.uniform(0, 0.7)
            leaf(g, "CabbLeaf", (x + 0.4 * s * math.cos(a), y + 0.4 * s * math.sin(a), z0),
                 (x + 0.66 * s * math.cos(a), y + 0.66 * s * math.sin(a), z0 + rnd.uniform(0.75, 0.95) * s), 0.6 * s,
                 lift=0.16 * s)


def crop_bean(g):
    """콩 한 토막. 포기 여섯, 포기마다 줄기 여섯이 높낮이 달리 갈라져 오르고 줄기 끝에 세 잎, 줄기 허리에 푸른 꼬투리 셋"""
    furrow(g)
    rnd = random.Random(37)
    for k in range(6):
        x, y = rnd.uniform(-0.1, 0.1), -4.2 + k * 1.68 + rnd.uniform(-0.2, 0.2)
        tops = []
        for j in range(6):
            a = 2 * math.pi * j / 6 + rnd.uniform(0, 0.7)
            r, h = rnd.uniform(0.15, 0.4), rnd.uniform(0.35, 0.85)
            sx, sy, sz = x + r * math.cos(a), y + r * math.sin(a), 0.25 + h
            tops.append((a, sx, sy, sz))
            blade(g, "Leaf", x, y, 0.25, sx, sy, sz, 0.045)
            for da, ln in ((0.0, 0.4), (1.25, 0.32), (-1.25, 0.32)):
                c = a + da
                leaf(g, "Leaf", (sx, sy, sz), (sx + ln * math.cos(c), sy + ln * math.sin(c), sz + rnd.uniform(-0.06, 0.08)),
                     0.28, lift=0.05)
        for a, sx, sy, sz in tops[:3]:
            mx, my, mz = (x + sx) / 2, (y + sy) / 2, (0.25 + sz) / 2 + 0.05
            cone_between(g, "Napa", (mx, my, mz), (mx + 0.08 * math.cos(a), my + 0.08 * math.sin(a), mz - 0.24), 0.045, 0.025,
                         seg=4)


def crop_radish(g):
    """무 한 토막. 여덟 뿌리, 흰 어깨가 흙 위로 솟고 푸른 머리, 긴 무청 여섯이 휘어 벌어진다"""
    furrow(g)
    rnd = random.Random(41)
    for k in range(8):
        x, y = rnd.uniform(-0.1, 0.1), -4.4 + k * 1.26 + rnd.uniform(-0.15, 0.15)
        g["Porcelain"].cyl(x, y, 0.2, 0.17, 0.15, 0.3, seg=8)
        g["Napa"].cyl(x, y, 0.5, 0.15, 0.1, 0.06, seg=8)
        for j in range(6):
            a = 2 * math.pi * j / 6 + rnd.uniform(0, 1)
            r = rnd.uniform(0.5, 0.7)
            leaf(g, "CabbLeaf", (x, y, 0.54), (x + r * math.cos(a), y + r * math.sin(a), 0.54 + rnd.uniform(0.45, 0.75)),
                 0.2, lift=0.12)


def crop_pepper(g):
    """고추 한 토막. 2.5 마다 지주를 박고 두 켜 끈을 맸다(토막을 이어도 간격이 같다). 포기 여섯, 층층이 어긋난 잎 열둘 밑으로 붉은 고추 다섯"""
    furrow(g)
    rnd = random.Random(53)
    for y in (-3.75, -1.25, 1.25, 3.75):
        g["Wood"].box(0, y, 0.3 + 0.75, 0.07, 0.07, 1.5)
    for z in (0.85, 1.35):
        for x in (-0.06, 0.06):
            tube(g, "Straw", (x, -5.0, z), (x, 5.0, z), 0.015, seg=3)
    for k in range(6):
        x, y = rnd.uniform(-0.08, 0.08), -4.2 + k * 1.68 + rnd.uniform(-0.15, 0.15)
        blade(g, "Leaf", x, y, 0.28, x, y, 1.35, 0.05)
        for j in range(12):
            a = j * 2.4 + rnd.uniform(0, 0.4)
            z = 0.45 + 0.075 * j
            ln = 0.44 - 0.016 * j
            leaf(g, "Peak", (x, y, z), (x + ln * math.cos(a), y + ln * math.sin(a), z + 0.08), 0.2, lift=0.04)
        for j in range(5):
            a = rnd.uniform(0, 2 * math.pi)
            r, z = rnd.uniform(0.15, 0.3), rnd.uniform(0.55, 1.0)
            px, py = x + r * math.cos(a), y + r * math.sin(a)
            g["Peak"].cyl(px, py, z - 0.02, 0.04, 0.03, 0.06, seg=4)
            cone_between(g, "Chili", (px, py, z), (px + 0.05 * math.cos(a), py + 0.05 * math.sin(a), z - 0.34), 0.045, 0.012,
                         seg=5)


def fret_panel(g, mat, ya, yb, za, zb, t):
    """여덟모 풍혈을 뚫은 청판. 구멍 둘레를 여덟 조각으로 나눠 민다. 앞뒤(x) 두께 t"""
    my, mz = (yb - ya) * 0.22, (zb - za) * 0.25
    hy0, hy1, hz0, hz1 = ya + my, yb - my, za + mz, zb - mz
    c = min(hy1 - hy0, hz1 - hz0) * 0.3
    h = [(hy0 + c, hz0), (hy1 - c, hz0), (hy1, hz0 + c), (hy1, hz1 - c), (hy1 - c, hz1), (hy0 + c, hz1), (hy0, hz1 - c),
         (hy0, hz0 + c)]
    o = [(hy0 + c, za), (hy1 - c, za), (yb, hz0 + c), (yb, hz1 - c), (hy1 - c, zb), (hy0 + c, zb), (ya, hz1 - c),
         (ya, hz0 + c)]
    corners = {1: (yb, za), 3: (yb, zb), 5: (ya, zb), 7: (ya, za)}
    for i in range(8):
        j = (i + 1) % 8
        poly = [o[i]] + ([corners[i]] if i in corners else []) + [o[j], h[j], h[i]]
        extrude(g, mat, poly, -t / 2, t / 2, plane="yz")


def bridge_rail(g, L):
    """
    돌다리 난간 한 줄(길이 L, 앞뒤 y 로 누인다). 지방석 위 동자기둥이 하엽으로 여덟모 돌란대를 받치고,
    칸마다 풍혈 뚫린 청판, 두 끝은 연봉 얹은 엄지기둥
    """
    half = L / 2
    g["Granite"].box(0, 0, 0.14, 0.9, L, 0.28)
    y0, y1 = -half + 0.4, half - 0.4
    n = max(2, round((y1 - y0) / 2.4))
    bay = (y1 - y0) / n
    for k in range(n + 1):
        y = y0 + k * bay
        if k in (0, n):
            g["Granite"].box(0, y, 1.28, 0.64, 0.64, 2.0)
            g["Granite"].box(0, y, 2.33, 0.74, 0.74, 0.1)
            lathe(g, "Granite", 0, y, 2.38, [(0.22, 0.0), (0.3, 0.12), (0.26, 0.3), (0.12, 0.45), (0.04, 0.52)], 8)
        else:
            g["Granite"].box(0, y, 0.94, 0.3, 0.3, 1.32)
            lathe(g, "Granite", 0, y, 1.6, [(0.13, 0.0), (0.2, 0.1), (0.3, 0.2), (0.3, 0.26)], 8)
    tube(g, "Granite", (0, y0, 2.0), (0, y1, 2.0), 0.15, seg=8)
    for k in range(n):
        ya = y0 + k * bay + (0.32 if k == 0 else 0.15)
        yb = y0 + (k + 1) * bay - (0.32 if k == n - 1 else 0.15)
        fret_panel(g, "Granite", ya, yb, 0.28, 1.2, 0.2)


# ---------------------------------------------------------------- 내놓기
JOBS = [
    ("Throne_Dais", "TDais", throne_dais, (9, -9, 6), (0, 0, 1.5)),
    ("Throne_Chair", "Throne", throne_chair, (4, -6, 4), (0, 0, 2)),
    ("Irworobongdo", "Ilwol", irworobongdo, (0, -14, 4.5), (0, 0, 4)),
    ("Datjip", "Datjip", datjip, (8, -10, -2), (0, 0, 2)),
    ("Hyangro", "Hyang", hyangro, (2.5, -3.5, 3), (0, 0, 1.6)),
    ("Chotdae", "Chot", chotdae, (2.5, -4, 3.5), (0, 0, 2.3)),
    ("Byeongpung", "Byeong", byeongpung, (0, -9, 3), (0, 0, 2.2)),
    ("Boryo", "Boryo", boryo, (4, -5, 3), (0, 0, 0.5)),
    ("Seoan", "Seoan", seoan, (2.5, -3, 2.5), (0, 0, 1)),
    ("Mungap", "Mungap", mungap, (3, -4.5, 3), (0, 0, 1.3)),
    ("Bandaji", "Bandaji", bandaji, (3.5, -4.5, 3.5), (0, 0, 1.6)),
    ("Ijeongjang", "Jang", ijeongjang, (3.5, -5, 4), (0, 0, 2.3)),
    ("Deungjan", "Deung", deungjan, (1.5, -2.5, 2.2), (0, 0, 1.3)),
    ("Gyeongdae", "Gyeong", gyeongdae, (1.8, -2.5, 2), (0, 0, 0.9)),
    ("Sabang_Takja", "Takja", sabang_takja, (2.6, -4, 3.5), (0, 0, 2.1)),
    ("Hwaro", "Hwaro", hwaro, (1.6, -2, 1.5), (0, 0, 0.4)),
    ("Buttumak", "Buttu", buttumak, (5, -8, 5), (0.5, 0, 1.5)),
    ("Chanjang", "Chan", chanjang, (3, -5, 3.5), (0, 0, 2.2)),
    ("Soban", "Soban", soban, (1.5, -2, 1.8), (0, 0, 0.8)),
    ("Pyeongsang", "Pyeong", pyeongsang, (5, -6, 4), (0, 0, 1)),
    ("Suldok", "Suldok", suldok, (3.5, -5, 3.5), (0, 0, 1.3)),
    ("Chorong", "Chorong", chorong, (1.5, -2.5, 1.5), (0, 0, 1.2)),
    ("Counter", "Counter", counter, (3, -5, 4.5), (0, 0, 2.3)),
    ("Sirung", "Sirung", sirung, (4, -8, 4), (0, 0, 2.5)),
    ("Specimen_Shelf", "Spec", specimen_shelf, (3.5, -7, 4), (0, 0, 2.7)),
    ("Yakjang", "Yak", yakjang, (3, -5, 3.5), (0, 0, 2.2)),
    ("Haebudae", "Haebu", haebudae, (4, -5, 5), (0, 0, 2.3)),
    ("Malim", "Malim", malim, (4, -7, 3.5), (0, 0, 2.5)),
    ("Gwe", "Gwe", gwe, (3.5, -4.5, 3.5), (0, 0, 1.3)),
    ("Gamani", "Gamani", gamani, (4, -5, 3), (0, 0, 1.2)),
    ("Duiju", "Duiju", duiju, (4, -4.5, 3), (0.5, 0, 1.2)),
    ("Meongseok", "Meong", meongseok, (4, -5, 3), (0, 0, 1.2)),
    ("Stall_Cloth", "SCloth", stall_cloth, (3.5, -4.5, 3), (0, 0, 0.5)),
    ("Stall_Jars", "SJars", stall_jars, (3.5, -4.5, 3), (0, 0, 0.8)),
    ("Stall_Crates", "SCrate", stall_crates, (3.5, -4.5, 3), (0, 0, 0.8)),
    ("Stall_Baskets", "SBasket", stall_baskets, (3.5, -4.5, 3), (0, 0, 0.5)),
    ("Yard_Jangdok", "YJang", yard_jangdok, (7, -8, 6), (0, 0, 1.3)),
    ("Yard_Well", "YWell", yard_well, (7, -8, 6), (0, 0, 2.6)),
    ("Yard_Haystack", "YHay", yard_haystack, (7, -8, 5), (0.5, 0, 1.6)),
    ("Yard_Garden", "YGard", yard_garden, (8, -10, 7), (0, 0, 0.3)),
    ("Pumgye", "Pumgye", pumgye, (2.5, -3.5, 2.8), (0, 0, 1.1)),
    ("Crop_Barley", "CBarley", crop_barley, (4, -7, 3), (0, -1, 0.8)),
    ("Crop_Cabbage", "CCabb", crop_cabbage, (4, -7, 3), (0, -1, 0.5)),
    ("Crop_Bean", "CBean", crop_bean, (4, -7, 3), (0, -1, 0.5)),
    ("Crop_Radish", "CRadish", crop_radish, (4, -7, 3), (0, -1, 0.5)),
    ("Crop_Pepper", "CPepper", crop_pepper, (4, -7, 3), (0, -1, 0.7)),
] + [("Bridge_Rail_%d" % n, "BRail%d" % n, (lambda g, n=n: bridge_rail(g, n)), (4, -7, 3.5), (0, -2, 1.2))
     for n in (13, 15, 21, 25)]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, prefix, fn, cam, look in JOBS:
        if only and name not in only:
            continue
        L.clear_scene()
        g = G(prefix)
        fn(g)
        L.export_model(name, g, 1.0, renders=[("corner", cam, look)], min_objs=1, palette=HPAL)
