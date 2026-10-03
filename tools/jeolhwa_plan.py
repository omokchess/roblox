# -*- coding: utf-8 -*-
"""
jeolhwa_plan.py — 절화 3판 배치표. (2026-09-26)

**배치는 전부 이 파일의 표에 손으로 적는다.** 스크립트는 표를
  1. 평면도(PNG)로 그려 눈으로 보게 하고
  2. 발자국끼리, 발자국과 길이 겹치는지 검사하고
  3. Studio 에서 돌릴 Luau 표(Jeolhwa_City3_data.luau)로 옮겨 적는다.
어디에 무엇을 둘지는 수식이 정하지 않는다. 행각·담처럼 한 줄로 잇는 것만 두 끝점을 적고
그 사이를 토막으로 고르게 나눈다.

좌표는 스터드. 방향(yaw)은 도. 0 이면 모델 앞(-Z)이 -Z 를 본다(궁에서 광장 쪽).
90 이면 -X, 180 이면 +Z, -90 이면 +X 를 본다. 이름은 옛 표를 따라 +X 를 동, -Z 를 남이라 부른다.

돌리는 법: python tools/jeolhwa_plan.py [출력 png] [높이지도] [x0,z0,x1,z1] [배율]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# ------------------------------------------------------------------ 틀 발자국
# Jeolhwa_Kit2 가 Studio 에서 잰 값. base 는 땅에 닿는 켜, all 은 지붕까지. (x0, x1, z0, z1)
KIT = {
    "Annex_Thatch": ((-10.0, 10.0, -9.7, 7.5), (-10.5, 10.5, -9.7, 8.0)),
    "Annex_Tile": ((-11.0, 11.0, -9.7, 7.5), (-11.8, 11.8, -9.7, 8.9)),
    "Building_Cottage": ((-13.5, 13.5, -11.7, 9.5), (-14.5, 14.5, -11.7, 10.5)),
    "Building_Hall": ((-23.0, 23.0, -22.2, 16.5), (-24.4, 24.4, -22.2, 17.9)),
    "Building_House": ((-15.5, 15.5, -12.7, 10.5), (-16.9, 16.9, -12.7, 12.4)),
    "Building_HouseL": ((-15.5, 15.5, -29.7, 9.5), (-17.4, 16.8, -29.7, 11.4)),
    "Building_HouseLM": ((-15.5, 15.5, -29.7, 9.5), (-16.9, 17.4, -29.7, 11.4)),
    "Corridor": ((-10.0, 10.0, -7.0, 7.0), (-10.0, 10.0, -8.6, 8.6)),
    "Corridor_Corner": ((-7.0, 5.0, -5.0, 7.0), (-8.6, 6.2, -6.2, 8.7)),
    "Gate_Hall": ((-18.5, 18.5, -11.4, 11.4), (-20.1, 20.1, -11.4, 11.4)),
    "Gate_Main": ((-15.0, 15.0, -6.5, 6.5), (-17.6, 17.6, -9.1, 9.1)),
    "Gate_Palace": ((-30.5, 30.5, -9.5, 9.5), (-30.5, 30.5, -11.1, 11.1)),
    "Granary": ((-12.8, 12.8, -11.0, 7.8), (-15.1, 15.1, -11.0, 10.6)),
    "Palace_Chimjeon": ((-32.2, 32.2, -33.6, 15.2), (-33.2, 33.2, -33.6, 16.1)),
    "Palace_Main": ((-46.0, 46.0, -42.9, 32.0), (-46.0, 46.0, -42.9, 32.0)),
    "Pavilion_Jeongja": ((-11.5, 11.5, -11.5, 11.5), (-13.6, 13.6, -16.6, 13.6)),
    "Pavilion_Nugak": ((-25.2, 25.2, -21.0, 21.0), (-27.6, 27.6, -23.5, 23.5)),
    "Prop_Garden": ((-5.9, 5.9, -4.2, 4.2), (-5.9, 5.9, -4.2, 4.2)),
    "Prop_Haystack": ((-4.2, 4.8, -3.3, 2.5), (-4.2, 4.8, -3.3, 2.5)),
    "Prop_Jangdok": ((-4.4, 4.4, -2.7, 2.7), (-4.4, 4.4, -2.7, 2.7)),
    "Prop_Well": ((-3.5, 3.5, -3.5, 3.5), (-3.9, 3.9, -3.5, 3.5)),
    "Shop_Row3": ((-15.0, 15.0, -10.7, 7.5), (-16.9, 16.9, -10.7, 9.9)),
    "Shop_Row5": ((-24.0, 24.0, -10.7, 7.5), (-25.8, 25.8, -10.7, 9.9)),
    "Tower_Bell": ((-14.8, 14.8, -10.8, 10.8), (-17.1, 17.1, -13.1, 13.1)),
    "Wall_GateTile": ((-10.0, 10.0, -1.0, 1.0), (-10.0, 10.0, -3.6, 4.1)),
    "Wall_Segment": ((-10.0, 10.0, -1.0, 1.0), (-10.0, 10.0, -2.0, 2.0)),
    "Wall_Stone": ((-10.0, 10.0, -1.2, 1.4), (-10.0, 10.0, -1.6, 1.6)),
    "Fence_Brush": ((-10.0, 10.0, -0.4, 0.4), (-10.0, 10.0, -0.4, 0.4)),
    "Fence_Gate": ((-10.0, 10.0, -0.4, 3.8), (-10.0, 10.0, -0.4, 3.8)),
}
PROPS = {"Prop_Garden", "Prop_Haystack", "Prop_Jangdok", "Prop_Well"}
WALLS = {"Wall_Segment", "Wall_Stone", "Fence_Brush"}

# 비워 둘 자리. (이름, x0, z0, x1, z1)
KEEP = [
    ("관아", 202, 343, 248, 383),
]

# ================================================================== 궁
# 둘레 담 안: x 20..430, z 640..957.  축은 x = 225
#   정문(광화문형) z 640 → 바깥마당과 금천 → 중문 z 712 → 행각으로 두른 정전 마당
#   → 북문 z 870 → 침전. 서쪽 경회루 연못, 동쪽 동궁과 후원
PALACE = [
    # (틀, x, z, yaw, 묶음)
    ("Gate_Palace", 225, 640, 0, "궁/정문"),
    ("Gate_Main", 20, 680, 90, "궁/정문"),        # 서문. 바깥을 본다
    ("Gate_Main", 430, 680, -90, "궁/정문"),      # 동문
    ("Gate_Hall", 225, 712, 0, "궁/정전"),
    ("Palace_Main", 225, 805, 0, "궁/정전"),
    ("Gate_Main", 225, 870, 0, "궁/정전"),        # 행각 북문
    ("Corridor_Corner", 140, 712, -90, "궁/행각"),
    ("Corridor_Corner", 310, 712, 180, "궁/행각"),
    ("Corridor_Corner", 310, 870, 90, "궁/행각"),
    ("Corridor_Corner", 140, 870, 0, "궁/행각"),
    ("Palace_Chimjeon", 225, 925, 0, "궁/침전"),
    ("Annex_Tile", 168, 912, 8, "궁/침전"),        # 침전 서쪽 나인 처소
    ("Building_House", 282, 912, -6, "궁/침전"),   # 동쪽 소주방
    ("Prop_Jangdok", 300, 940, 0, "궁/침전"),
    ("Prop_Well", 268, 944, 0, "궁/침전"),
    # 서쪽 궐내각사
    ("Building_House", 58, 735, 0, "궁/각사"),
    ("Granary", 110, 742, -90, "궁/각사"),
    ("Annex_Tile", 42, 772, 90, "궁/각사"),
    ("Prop_Well", 90, 718, 0, "궁/각사"),
    # 서쪽 경회루
    ("Pavilion_Nugak", 79, 862, 90, "궁/경회루"),
    # 동궁
    ("Gate_Main", 376, 705, 0, "궁/동궁"),
    ("Building_Hall", 376, 782, 0, "궁/동궁"),
    ("Annex_Tile", 345, 742, -90, "궁/동궁"),
    ("Annex_Tile", 407, 742, 90, "궁/동궁"),
    ("Prop_Jangdok", 408, 800, 0, "궁/동궁"),
    # 후원
    ("Pavilion_Jeongja", 377, 882, 0, "궁/후원"),
]

# 행각. (x0, z0, x1, z1, yaw, 토막 수). 토막은 두 끝 사이를 고르게 나눠 늘인다
CORRIDORS = [
    (145, 712, 206.5, 712, 180, 3),
    (243.5, 712, 305, 712, 180, 3),
    (145, 870, 210, 870, 0, 3),
    (240, 870, 305, 870, 0, 3),
    (140, 717, 140, 865, -90, 7),
    (310, 717, 310, 865, 90, 7),
]

# 담. (틀, x0, z0, x1, z1, 묶음)
PALACE_WALLS = [
    ("Wall_Segment", 21, 640, 194.5, 640, "궁/담"),
    ("Wall_Segment", 255.5, 640, 429, 640, "궁/담"),
    ("Wall_Segment", 20, 640, 20, 665, "궁/담"),
    ("Wall_Segment", 20, 695, 20, 957, "궁/담"),
    ("Wall_Segment", 430, 640, 430, 665, "궁/담"),
    ("Wall_Segment", 430, 695, 430, 957, "궁/담"),
    ("Wall_Segment", 21, 957, 429, 957, "궁/담"),
    # 동궁 담. 동쪽은 궁 담을 같이 쓴다
    ("Wall_Segment", 327, 705, 361, 705, "궁/동궁"),
    ("Wall_Segment", 391, 705, 429, 705, "궁/동궁"),
    ("Wall_Segment", 327, 706, 327, 815, "궁/동궁"),
    ("Wall_Segment", 328, 815, 429, 815, "궁/동궁"),
]

# 길 끝이 건물 앞에 닿도록 낸 것. 겹침 검사에서 뺀다. (길 이름, 틀)
ROAD_ENDS = {("어도", "Gate_Palace"), ("북문길", "Palace_Chimjeon"), ("관아앞", "Wall_GateTile")}

# 물. 돌 둘레를 두른 못과 도랑. (이름, x0, z0, x1, z1)
POOLS = [
    ("서촌못", -96, 488, -44, 526),
    ("경회루못", 34, 800, 118, 925),
    ("후원못", 342, 842, 412, 922),
    ("금천", 70, 669, 380, 677),
]
# 못 속 섬. 물 위로 올라온 돌 단. (x0, z0, x1, z1)
ISLANDS = [
    (362, 867, 392, 897),
]
# 다리. (가운데 x, z, 방향(0 이면 z 쪽으로 건넌다), 길이, 폭)
BRIDGES = [
    (225, 673, 0, 16, 26),
    (120, 673, 0, 14, 8),
    (330, 673, 0, 14, 8),
    (108, 862, 90, 22, 9),     # 경회루 동쪽 다리. 연못 둘레에서 누각 기단까지
    (377, 855, 0, 26, 6),      # 후원 섬 다리
]

# 박석 마당. (이름, x0, z0, x1, z1, 높이 기준). 기준 "ring" 은 행각 기단 높이에 맞춘다
PAVES = [
    ("바깥마당", 25, 650, 425, 700, "ground"),
    ("정문길", 195, 631, 255, 650, "ground"),
    ("정전마당", 131, 700, 319, 882, "ring"),
]

# 궁 안 길. 돌길
PALACE_PATHS = [
    ("어도", 24, "stone", [(225, 598), (225, 631)]),
    ("북문길", 10, "stone", [(225, 882), (225, 891)]),
]

PALACE_TREES = [
    (64, 788), (100, 786), (36, 935), (124, 940), (80, 945),
    (335, 830), (420, 835), (335, 935), (420, 940), (420, 772),
    (48, 705), (412, 655), (40, 655), (142, 890), (312, 888),
]

# ================================================================== 도성
# 구역마다 성격과 밀도를 다르게 한다. 한 가지 필지 틀을 되풀이하지 않는다
#   북촌    궁 서쪽. 기와집이 골목 담을 맞대고 빽빽하다. 대개 남(-Z)을 본다
#   서촌    그 바깥. 기와와 초가가 섞이고 성글다
#   저자    광장 동쪽 운종가. 행랑 가게가 길을 보고 늘어서고, 끝에 종루 선 저잣마당
#   동촌    궁 동쪽. 궁 동문 길을 따라 느슨하게
#   남촌    관아 남쪽 들판. 초가 서너 채씩 무리 짓고 사이는 논밭
# 길은 광장에서 방사로 나가고, 바깥을 도는 순환길이 끝을 이어 막다른 길이 없다

ROADS = [
    # (이름, 폭, 재질, 점들)
    ("운종가", 28, "dirt", [(285, 545), (340, 545), (374, 545), (422, 551), (470, 566)]),
    ("운종가동", 14, "dirt", [(540, 604), (590, 606), (638, 601), (668, 600)]),
    ("서촌길", 14, "dirt", [(165, 545), (120, 550), (72, 561), (30, 576), (0, 592), (-50, 597),
                         (-105, 606), (-158, 626), (-205, 656), (-245, 698), (-272, 750)]),
    ("북촌길", 12, "dirt", [(0, 592), (4, 640), (2, 690), (-1, 742), (3, 795), (-2, 850), (-18, 902), (-37, 922)]),
    ("북촌골목1", 9, "dirt", [(2, 690), (-40, 699), (-85, 692), (-128, 704), (-168, 732)]),
    ("북촌골목2", 9, "dirt", [(3, 795), (-38, 805), (-80, 820), (-120, 847), (-152, 880)]),
    ("남서길", 12, "dirt", [(170, 430), (130, 408), (82, 392), (22, 378), (-45, 370), (-115, 368),
                         (-185, 378), (-240, 402), (-282, 440)]),
    ("남동길", 12, "dirt", [(280, 430), (320, 410), (372, 394), (430, 382), (495, 372), (560, 374),
                         (618, 390), (660, 425)]),
    ("남산길", 8, "dirt", [(372, 394), (366, 320), (346, 232), (318, 140), (298, 72)]),
    ("동산길", 8, "dirt", [(618, 390), (650, 345), (678, 298), (690, 274)]),
    ("서순환", 10, "dirt", [(-282, 440), (-298, 520), (-300, 600), (-290, 680), (-272, 750), (-250, 815),
                         (-215, 868)]),
    ("동순환", 10, "dirt", [(660, 425), (672, 500), (668, 600), (655, 690), (625, 780), (585, 850), (548, 895)]),
    ("동문길", 12, "dirt", [(445, 680), (500, 688), (560, 698), (618, 706), (655, 690)]),
    ("관아앞", 16, "stone", [(225, 425), (225, 402)]),
]

TOWN = [
    # ---------------------------------------------------------- 북촌
    # 첫째 줄. 서촌길을 보고 선다
    ("Building_HouseL", -30, 652, 0, "북촌"),
    ("Annex_Tile", -60, 636, -90, "북촌"),        # 사랑 마당을 동쪽으로 본다
    ("Prop_Jangdok", -50, 670, 0, "북촌"),
    ("Building_House", -100, 650, 6, "북촌"),
    ("Prop_Garden", -82, 674, 6, "북촌"),
    ("Building_HouseLM", -150, 676, 12, "북촌"),
    ("Prop_Jangdok", -176, 684, 12, "북촌"),
    # 둘째 줄. 골목1 북쪽 담 안
    ("Building_House", -32, 758, -4, "북촌"),
    ("Annex_Tile", -62, 742, -90, "북촌"),
    ("Building_HouseL", -104, 770, -8, "북촌"),
    ("Prop_Jangdok", -80, 785, 0, "북촌"),
    ("Prop_Well", -18, 781, 0, "북촌"),             # 골목2 어귀 공동 우물
    ("Building_House", -146, 778, 14, "북촌"),
    # 셋째 줄. 골목2 너머 바닷가 쪽
    ("Building_HouseLM", -40, 868, 2, "북촌"),
    ("Building_House", -82, 874, 10, "북촌"),
    ("Annex_Tile", -104, 908, 100, "북촌"),
    ("Building_House", -142, 914, 22, "북촌"),
    ("Pavilion_Jeongja", -48, 944, 0, "북촌"),    # 바다를 등지고 섬 안쪽을 굽어본다
    # ---------------------------------------------------------- 궁 서남 모퉁이. 서촌길 북쪽에 붙은 가게와 집
    ("Building_House", 138, 590, 0, "서촌길가"),
    ("Shop_Row3", 92, 598, 4, "서촌길가"),
    ("Annex_Tile", 55, 612, -4, "서촌길가"),
    ("Prop_Well", 28, 614, 0, "서촌길가"),
    # 서촌길 남쪽 주막
    ("Building_HouseLM", 112, 508, 180, "주막"),
    ("Prop_Jangdok", 135, 492, 0, "주막"),
    ("Building_Cottage", 62, 520, 172, "주막"),
    # ---------------------------------------------------------- 서촌
    ("Building_Cottage", -236, 618, 15, "서촌"),
    ("Annex_Thatch", -262, 640, 75, "서촌"),
    ("Building_House", -252, 568, -10, "서촌"),
    ("Building_HouseL", -204, 796, 70, "서촌"),
    ("Annex_Thatch", -200, 842, 40, "서촌"),
    ("Prop_Garden", -178, 820, 20, "서촌"),
    ("Building_Cottage", -178, 520, 8, "서촌"),
    ("Prop_Garden", -150, 530, 8, "서촌"),
    # ---------------------------------------------------------- 저자
    # 운종가 북쪽. 남(-Z)을 본다
    ("Shop_Row5", 318, 572, 0, "저자"),
    ("Shop_Row3", 367, 575, -2, "저자"),
    ("Shop_Row5", 424, 587, -8, "저자"),
    ("Granary", 330, 614, 180, "저자"),
    ("Building_House", 405, 620, 176, "저자"),
    # 운종가 남쪽. 북(+Z)을 본다
    ("Shop_Row5", 374, 516, 180, "저자"),
    ("Shop_Row3", 422, 520, 184, "저자"),
    ("Building_House", 458, 503, 175, "저자"),
    ("Building_House", 372, 474, 184, "저자"),
    ("Granary", 414, 478, 176, "저자"),
    # 저잣마당
    ("Tower_Bell", 504, 580, 0, "저잣마당"),
    ("Prop_Well", 478, 604, 0, "저잣마당"),
    ("Shop_Row3", 505, 628, 0, "저잣마당"),
    ("Shop_Row5", 500, 530, 180, "저잣마당"),
    ("Building_HouseL", 574, 562, 90, "저잣마당"),     # 객주. 마당 쪽(서)을 본다
    ("Prop_Jangdok", 566, 590, 0, "저잣마당"),
    # ---------------------------------------------------------- 동촌
    ("Building_HouseL", 492, 738, 4, "동촌"),
    ("Annex_Tile", 522, 760, -95, "동촌"),
    ("Building_Cottage", 562, 748, -8, "동촌"),
    ("Building_Cottage", 470, 806, 20, "동촌"),
    ("Annex_Thatch", 505, 826, 60, "동촌"),
    ("Building_House", 560, 832, -25, "동촌"),
    ("Prop_Garden", 598, 750, -8, "동촌"),
    # 척수관. 동쪽 바위 밑. 짐승 표본을 갈무리해 내보내는 곳
    ("Building_Hall", 628, 858, -80, "척수관"),
    ("Granary", 596, 902, 190, "척수관"),
    ("Annex_Tile", 648, 800, -95, "척수관"),
    # ---------------------------------------------------------- 관아
    ("Granary", 200, 318, 0, "관아"),
    ("Annex_Tile", 254, 322, 90, "관아"),
    # ---------------------------------------------------------- 남촌. 초가 무리
    ("Building_Cottage", -210, 318, 10, "남촌"),
    ("Building_Cottage", -170, 298, -15, "남촌"),
    ("Annex_Thatch", -236, 294, 80, "남촌"),
    ("Building_Cottage", -60, 312, 5, "남촌"),
    ("Building_Cottage", -22, 290, -20, "남촌"),
    ("Annex_Thatch", -84, 290, 70, "남촌"),
    ("Building_Cottage", 72, 330, 0, "남촌"),
    ("Annex_Thatch", 100, 316, -80, "남촌"),
    ("Building_Cottage", 96, 284, 25, "남촌"),
    ("Building_Cottage", 456, 322, 5, "남촌"),
    ("Building_Cottage", 496, 302, -15, "남촌"),
    ("Building_House", 428, 290, 10, "남촌"),
    ("Annex_Thatch", 482, 268, 90, "남촌"),
    ("Building_Cottage", 590, 336, 20, "남촌"),
    ("Building_Cottage", 566, 300, -5, "남촌"),
    # ---------------------------------------------------------- 2026-10-03 평탄화 뒤 빈 자리 채움
    # (사용자: "빈 공간은 광장을 놓든 뭘 하든 해서 채워넣자". 논밭·짚더미를 걷어 낸 자리에 집을 앉힌다. Jeolhwa_Infill 이 없는 것만 짓는다)
    # 서촌 아랫말. 남서길 북쪽 옛 논밭 자리. 길(남, -Z)을 보고 선다
    ("Building_House", -205, 432, 4, "서촌"),
    ("Annex_Thatch", -238, 455, 80, "서촌"),
    ("Prop_Jangdok", -182, 452, 4, "서촌"),
    ("Building_Cottage", -150, 428, -6, "서촌"),
    ("Building_HouseL", -100, 440, 2, "서촌"),
    ("Prop_Well", -62, 470, 0, "서촌"),             # 서촌못 어귀 우물
    ("Building_House", -20, 420, -8, "서촌"),
    ("Annex_Tile", 16, 450, -90, "서촌"),
    ("Building_Cottage", 62, 432, 8, "서촌"),
    ("Prop_Jangdok", 88, 452, 0, "서촌"),
    # 남촌 빈 틈
    ("Building_Cottage", -120, 322, -10, "남촌"),
    ("Building_House", 28, 328, 6, "남촌"),
    ("Building_Cottage", 140, 330, 90, "남촌"),     # 관아 서쪽 담 밖. 서쪽 초가 무리를 본다
    ("Annex_Thatch", 146, 280, 0, "남촌"),
    ("Building_House", 338, 330, -90, "남촌"),       # 남산길 서쪽. 길(동)을 본다
    ("Annex_Thatch", 330, 290, -90, "남촌"),
    ("Prop_Well", 396, 362, 0, "남촌"),
    ("Building_Cottage", 535, 262, 10, "남촌"),
    # 마방. 저잣마당 장꾼 말과 짐을 맡는 집. 동순환 안쪽
    ("Building_HouseL", 622, 490, 90, "마방"),
    # 산 정자는 옛 자리 그대로(남산 정자는 2026-10-03 Plains_Build 가 남산 꼭대기 R_평원북 으로 옮겼다)
    ("Pavilion_Jeongja", 705, 250, 90, "산정자"),
]

TOWN_WALLS = [
    # 북촌 첫째 집. 앞 담에 솟을 기와 대문, 옆 담은 북촌길을 따라
    ("Wall_Segment", -71, 614, -31, 614, "북촌"),
    ("Wall_Segment", -11, 614, -7, 614, "북촌"),
    ("Wall_Segment", -7, 615, -7, 668, "북촌"),
    ("Wall_Segment", -72, 615, -72, 660, "북촌"),
    # 둘째 집은 낮은 돌담만. 가운데가 트였다
    ("Wall_Stone", -124, 624, -106, 621, "북촌"),
    ("Wall_Stone", -90, 619, -74, 618, "북촌"),
    # 골목1 북쪽 담. 골목을 따라 굽는다
    ("Wall_Segment", -6, 711, -20, 712, "북촌"),
    ("Wall_Segment", -40, 713, -86, 706, "북촌"),
    ("Wall_Segment", -86, 706, -94, 707, "북촌"),
    ("Wall_Segment", -114, 710, -130, 717, "북촌"),
    ("Wall_Segment", -130, 717, -162, 742, "북촌"),
    # 골목2 남쪽 담
    ("Wall_Segment", -8, 790, -38, 794, "북촌"),
    ("Wall_Segment", -58, 800, -120, 832, "북촌"),
    # 저잣마당 뒤 객주 담
    ("Wall_Stone", 592, 536, 592, 588, "저잣마당"),
    # 관아 담
    ("Wall_Segment", 180, 300, 270, 300, "관아"),
    ("Wall_Segment", 180, 301, 180, 398, "관아"),
    ("Wall_Segment", 270, 301, 270, 398, "관아"),
    ("Wall_Segment", 181, 398, 215, 398, "관아"),
    ("Wall_Segment", 235, 398, 269, 398, "관아"),
    # 척수관 목책
    ("Fence_Brush", 598, 812, 598, 880, "척수관"),
    ("Fence_Brush", 598, 812, 640, 780, "척수관"),
    # 남촌 싸리 울타리 몇 줄. 집마다 두르지 않고 길 쪽 한두 변만
    ("Fence_Brush", -226, 344, -186, 350, "남촌"),
    ("Fence_Brush", -76, 336, -46, 344, "남촌"),
    ("Fence_Brush", 58, 350, 90, 352, "남촌"),
    ("Fence_Brush", 440, 344, 478, 340, "남촌"),
]
# 기와 대문 자리. (x, z, yaw, 묶음)
TOWN_GATES = [
    (-21, 614, 0, "북촌"),
    (-30, 712.5, 0, "북촌"),
    (-104, 708.5, 5, "북촌"),
    (-48, 797, 17, "북촌"),
    (225, 398, 180, "관아"),
]

TOWN_TREES = [
    (22, 604), (-120, 684), (-190, 700), (-60, 820), (-160, 850), (-10, 930), (-110, 940),
    (150, 612), (8, 560), (148, 520), (40, 490), (-100, 500), (-230, 480), (-40, 440),
    (300, 600), (452, 612), (552, 622), (556, 528), (300, 450),
    (300, 500), (322, 522), (296, 474), (338, 488),
    (520, 700), (600, 790), (450, 860), (530, 930), (680, 560), (640, 470),
    (-150, 340), (0, 320), (40, 280), (130, 340), (400, 330), (540, 330), (620, 270),
    (-280, 360), (-260, 700), (-230, 900), (360, 250), (240, 260), (180, 260),
    (-300, 262), (-278, 252), (-120, 226), (-98, 212), (30, 214), (205, 230), (470, 225),
    (500, 236), (660, 330), (-40, 250),
    # 2026-10-03 채움 자리
    (-252, 424), (-128, 466), (100, 430), (300, 300), (560, 250),
    # 광장 가장자리(좌판 뒤 그늘)
    (170, 446), (170, 470), (168, 524), (169, 592), (282, 446), (283, 463),
]

# 논밭. (x0, z0, x1, z1) 두둑은 z 방향으로 선다
FIELDS = []  # 2026-10-03 사용자: "곳곳에 뜬금없이 있는 밭이나 건초더미 없애줘" — 논밭 15·짚더미 5 치움

TOWN_PAVES = [
    ("저잣마당", 468, 548, 540, 612, "ground"),
    ("광장", 165, 425, 285, 605, "ground"),  # 2026-10-03 옛 스폰광장 빈터 → 박석 광장
]

# 광장 꾸밈(2026-10-03). Jeolhwa_Infill 이 파트·소품으로 짓는다. (종류, x, z, yaw, 너비, 깊이)
#   관아 대문(z 398)과 궁 정문(z 640)을 잇는 x 225 축은 비우고, 서쪽에 당산나무 단, 동쪽 운종가 어귀에 좌판, 관아 앞에 방(알림판)
PLAZA = [
    ("Dangsan", 190, 500, 0, 28, 28),   # 두 켜 돌 단 위 큰 느티나무 + 평상 둘
    ("Sundial", 225, 520, 0, 4, 4),     # 앙부일구(해시계) 받침돌
    ("Notice", 252, 440, 180, 9, 2),    # 방. 광장 쪽(+Z)을 본다
    ("Booth", 270, 478, 90, 8, 6), ("Booth", 270, 500, 90, 8, 6), ("Booth", 270, 522, 90, 8, 6),
    ("Booth", 270, 572, 90, 8, 6), ("Booth", 270, 594, 90, 8, 6),
    ("Booth", 180, 576, -90, 8, 6), ("Booth", 180, 598, -90, 8, 6),
    # 맞은편 줄 — 좌판끼리 마주 보아 장 골목(폭 15)이 된다
    ("Booth", 248, 478, -90, 8, 6), ("Booth", 248, 500, -90, 8, 6), ("Booth", 248, 522, -90, 8, 6),
    ("Booth", 248, 572, -90, 8, 6), ("Booth", 248, 594, -90, 8, 6),
    ("Booth", 202, 576, 90, 8, 6), ("Booth", 202, 598, 90, 8, 6),
]

# ------------------------------------------------------------------ 계산
def rect_world(kind, x, z, yaw, which=0, pad=0.0):
    x0, x1, z0, z1 = KIT[kind][which]
    x0, x1, z0, z1 = x0 - pad, x1 + pad, z0 - pad, z1 + pad
    r = math.radians(yaw)
    c, s = math.cos(r), math.sin(r)
    pts = []
    for lx, lz in ((x0, z0), (x1, z0), (x1, z1), (x0, z1)):
        # 로블록스 CFrame.Angles(0, yaw, 0): (x, z) -> (x cos + z sin, -x sin + z cos)
        pts.append((x + lx * c + lz * s, z - lx * s + lz * c))
    return pts


def seg_rect(ax, az, bx, bz, w):
    dx, dz = bx - ax, bz - az
    L = math.hypot(dx, dz)
    ux, uz = dx / L, dz / L
    nx, nz = -uz * w / 2, ux * w / 2
    return [(ax + nx, az + nz), (bx + nx, bz + nz), (bx - nx, bz - nz), (ax - nx, az - nz)]


def overlap(p, q):
    for poly in (p, q):
        for i in range(4):
            a, b = poly[i], poly[(i + 1) % 4]
            ax, az = b[1] - a[1], -(b[0] - a[0])
            pa = [ax * v[0] + az * v[1] for v in p]
            qa = [ax * v[0] + az * v[1] for v in q]
            if max(pa) <= min(qa) or max(qa) <= min(pa):
                return False
    return True


def runs(items):
    """두 끝점 줄을 20 토막으로. (틀, x, z, yaw, stretch, 묶음)"""
    out = []
    for kind, ax, az, bx, bz, grp in items:
        L = math.hypot(bx - ax, bz - az)
        n = max(1, int(L / 20 + 0.5))
        yaw = math.degrees(math.atan2(-(bz - az), bx - ax))
        for k in range(n):
            t = (k + 0.5) / n
            out.append((kind, ax + (bx - ax) * t, az + (bz - az) * t, yaw, L / n / 20, grp))
    return out


def corridor_pieces():
    out = []
    for ax, az, bx, bz, yaw, n in CORRIDORS:
        L = math.hypot(bx - ax, bz - az)
        for k in range(n):
            t = (k + 0.5) / n
            out.append(("Corridor", ax + (bx - ax) * t, az + (bz - az) * t, yaw, L / n / 20, "궁/행각"))
    return out


def all_buildings():
    b = [(k, x, z, y, 1.0, g) for k, x, z, y, g in PALACE + TOWN]
    b += [("Wall_GateTile", x, z, y, 1.0, g) for x, z, y, g in TOWN_GATES]
    return b + corridor_pieces()


def check():
    msgs = []
    blds = all_buildings()
    polys = []
    for k, x, z, y, st, g in blds:
        if k in ("Corridor", "Corridor_Corner"):
            continue
        # 건물 사이는 4 스터드는 비어야 캐릭터가 지나간다. 살림살이는 1
        pad = 1.0 if (k in PROPS or k == "Wall_GateTile") else 2.0
        polys.append((f"{g}:{k}@({x:.0f},{z:.0f})", rect_world(k, x, z, y, 0, pad), k))
    for i in range(len(polys)):
        for j in range(i + 1, len(polys)):
            if overlap(polys[i][1], polys[j][1]):
                msgs.append("건물겹침 " + polys[i][0] + " <> " + polys[j][0])
    road_rects = []
    for name, w, mat, pts in ROADS + PALACE_PATHS:
        for a, b in zip(pts, pts[1:]):
            road_rects.append((name, seg_rect(a[0], a[1], b[0], b[1], w)))
    for n, p, k in polys:
        for rn, rr in road_rects:
            if overlap(p, rr) and (rn, k) not in ROAD_ENDS:
                msgs.append("길겹침 " + n + " <> " + rn)
    wall_rects = []
    for kind, x, z, y, st, g in runs(PALACE_WALLS + TOWN_WALLS):
        L = 20 * st
        wall_rects.append((f"{g}:{kind}", seg_rect(x - math.cos(math.radians(y)) * L / 2, z + math.sin(math.radians(y)) * L / 2,
                                                    x + math.cos(math.radians(y)) * L / 2, z - math.sin(math.radians(y)) * L / 2, 2.4)))
    for n, p, k in polys:
        if k.startswith("Gate") or k == "Wall_GateTile":
            continue
        for wn, wr in wall_rects:
            if overlap(p, wr):
                msgs.append("담겹침 " + n + " <> " + wn)
    for k, x, z, y, w, d in PLAZA:
        r = math.radians(y)
        pr = [(x + px * math.cos(r) + pz * math.sin(r), z - px * math.sin(r) + pz * math.cos(r))
              for px, pz in ((-w / 2 - 1, -d / 2 - 1), (w / 2 + 1, -d / 2 - 1), (w / 2 + 1, d / 2 + 1), (-w / 2 - 1, d / 2 + 1))]
        for n, p, kk in polys:
            if overlap(p, pr):
                msgs.append("광장겹침 " + k + f"@({x},{z}) <> " + n)
        for rn, rr in road_rects:
            if overlap(pr, rr) and rn not in ("남서길", "남동길", "서촌길", "운종가", "관아앞"):
                msgs.append("광장길겹침 " + k + f"@({x},{z}) <> " + rn)
    for name, x0, z0, x1, z1 in KEEP:
        kr = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
        for n, p, k in polys:
            if overlap(p, kr):
                msgs.append("비움자리 " + name + " <> " + n)
    return msgs


# ------------------------------------------------------------------ 그림
def stretched(pts, x, z, yaw, st):
    """늘인 토막은 로컬 x 로만 늘어난다"""
    if st == 1.0:
        return pts
    r = math.radians(yaw)
    ux, uz = math.cos(r), -math.sin(r)
    out = []
    for px, pz in pts:
        dx, dz = px - x, pz - z
        along = dx * ux + dz * uz
        out.append((x + dx + along * (st - 1) * ux, z + dz + along * (st - 1) * uz))
    return out


def render(path, region=(-340, -40, 740, 990), sc=1.0, heightmap=None):
    from plan_png import Canvas
    C = Canvas(*region, sc)
    C.rect(region[0], region[1], region[2], region[3], "#86ad70")
    if heightmap and os.path.exists(heightmap):
        for line in open(heightmap, encoding="utf-8"):
            if len(line) < 8:
                continue
            z = int(line[:5])
            for i, ch in enumerate(line.rstrip("\n")[6:]):
                x = -440 + 20 * i
                col = {"~": "#5d8fb0", "-": "#d9cc98", "#": "#7c7c78"}.get(ch)
                if col is None:
                    col = ["#86ad70", "#7a9f64", "#6e9258", "#62854e", "#577946"][min(int(ch), 4)] if ch.isdigit() else "#4d6b3e"
                C.rect(x - 10, z - 10, x + 10, z + 10, col)
    for gx in range(-300, 741, 50):
        C.line(gx, region[1], gx, region[3], (0.7 if gx % 100 else 1.3) / sc, "#3c5a33")
    for gz in range(0, 991, 50):
        C.line(region[0], gz, region[2], gz, (0.7 if gz % 100 else 1.3) / sc, "#3c5a33")
    for name, x0, z0, x1, z1 in KEEP:
        C.rect(x0, z0, x1, z1, "#ffffff", 0.18)
    for name, x0, z0, x1, z1, _ in PAVES + TOWN_PAVES:
        C.rect(x0, z0, x1, z1, "#b7b3a4")
    for x0, z0, x1, z1 in FIELDS:
        C.rect(x0, z0, x1, z1, "#8a6f4c")
        for fx in range(int(x0) + 2, int(x1), 4):
            C.line(fx, z0 + 1, fx, z1 - 1, 1.4, "#6f8f45")
    for name, w, mat, pts in ROADS + PALACE_PATHS:
        col = "#c9c3b0" if mat == "stone" else "#a88f68"
        for a, b in zip(pts, pts[1:]):
            C.line(a[0], a[1], b[0], b[1], w, col)
        for p in pts[1:-1]:
            C.circle(p[0], p[1], w / 2, col)
    for name, x0, z0, x1, z1 in POOLS:
        C.rect(x0 - 1.5, z0 - 1.5, x1 + 1.5, z1 + 1.5, "#8c887a")
        C.rect(x0, z0, x1, z1, "#4f7f8c")
    for x0, z0, x1, z1 in ISLANDS:
        C.rect(x0, z0, x1, z1, "#b7b3a4")
    for x, z, yaw, L, w in BRIDGES:
        if yaw == 0:
            C.rect(x - w / 2, z - L / 2, x + w / 2, z + L / 2, "#e4e0d2")
        else:
            C.rect(x - L / 2, z - w / 2, x + L / 2, z + w / 2, "#e4e0d2")
    for kind, x, z, y, st, g in runs(PALACE_WALLS + TOWN_WALLS):
        L = 20 * st
        r = math.radians(y)
        ax, az = x - math.cos(r) * L / 2, z + math.sin(r) * L / 2
        bx, bz = x + math.cos(r) * L / 2, z - math.sin(r) * L / 2
        col = {"Wall_Segment": "#f2eee2", "Wall_Stone": "#8f8b7d", "Fence_Brush": "#6d5a44"}[kind]
        C.line(ax, az, bx, bz, 3.2, "#2a2a2a")
        C.line(ax, az, bx, bz, 1.8, col)
    for k, x, z, y, st, g in all_buildings():
        allp = stretched(rect_world(k, x, z, y, 1), x, z, y, st)
        base = stretched(rect_world(k, x, z, y, 0), x, z, y, st)
        roof = {"Building_Cottage": "#c2a672", "Annex_Thatch": "#c2a672"}.get(k, "#50544c")
        if k in PROPS:
            roof = "#7a5a44"
        C.poly(allp, roof, 0.9)
        C.outline(base, 0.7 / sc, "#e9e2c8")
        r = math.radians(y)
        fz = KIT[k][0][2]
        C.circle(x + fz * math.sin(r), z + fz * math.cos(r), 1.8, "#e03a2a")
    for k, x, z, y, w, d in PLAZA:
        r = math.radians(y)
        pts = [(x + px * math.cos(r) + pz * math.sin(r), z - px * math.sin(r) + pz * math.cos(r))
               for px, pz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]
        C.poly(pts, {"Dangsan": "#8f8b7d", "Booth": "#b5523b", "Notice": "#6b4a2e", "Sundial": "#3d5c6b"}[k], 0.95)
    for x, z in PALACE_TREES + TOWN_TREES:
        C.circle(x, z, 8, "#2f5d34", 0.85)
    for gx in range(-300, 741, 100):
        for gz in range(0, 991, 100):
            if region[0] <= gx < region[2] and region[1] <= gz < region[3]:
                C.text(gx + 2 / sc, gz + 2 / sc, "%d" % gx, "#101010", 2)
                C.text(gx + 2 / sc, gz + 15 / sc, "%d" % gz, "#101010", 2)
    C.save(path)



# ------------------------------------------------------------------ Luau 로 옮겨 적기
def lua(v):
    if isinstance(v, str):
        return '"' + v + '"'
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return ("%.3f" % v).rstrip("0").rstrip(".")
    return "{" + ", ".join(lua(x) for x in v) + "}"


def emit(path):
    tables = [
        ("PALACE", PALACE), ("TOWN", TOWN), ("CORRIDORS", CORRIDORS),
        ("WALLS", PALACE_WALLS + TOWN_WALLS), ("GATES", TOWN_GATES),
        ("ROADS", ROADS + PALACE_PATHS), ("POOLS", POOLS), ("ISLANDS", ISLANDS), ("BRIDGES", BRIDGES),
        ("PAVES", PAVES + TOWN_PAVES), ("FIELDS", FIELDS), ("TREES", PALACE_TREES + TOWN_TREES),
        ("PLAZA", PLAZA),
    ]
    lines = ["-- jeolhwa_plan.py 가 적은 표. 손으로 고치지 말고 jeolhwa_plan.py 를 고쳐 다시 뽑는다", "local D = {}"]
    for name, rows in tables:
        lines.append("D.%s = {" % name)
        for r in rows:
            lines.append("\t" + lua(r) + ",")
        lines.append("}")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "jeolhwa_plan.png")
    hm = sys.argv[2] if len(sys.argv) > 2 else None
    region = tuple(float(v) for v in sys.argv[3].split(",")) if len(sys.argv) > 3 else (-340, -40, 740, 990)
    sc = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
    render(out, region, sc, hm)
    emit(os.path.join(HERE, "Jeolhwa_City3_data.luau"))
    msgs = check()
    print("건물 %d, 담 토막 %d, 길 %d" % (len(all_buildings()), len(runs(PALACE_WALLS + TOWN_WALLS)), len(ROADS)))
    for m in msgs:
        print(m)
    print("검사 %d 건" % len(msgs))
