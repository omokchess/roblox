# -*- coding: utf-8 -*-
"""
ruins_plan.py — 탑의 성역 재작업 배치표. (2026-09-27)

컨셉과 색은 기존 성역(Islands_Sanctuary / Islands_SanctuaryFill / Islands_Tower) 그대로:
  탑(가운데) → 네 참배로(20, 110, 200, 290도)와 열주 → 길 끝 무너진 문 → 순례 고리(r 433)와 회랑 → 고리 밖 부속 신전,
  계단 대지 둘, 검은 반사지 둘, 부러진 거상 여덟, 비석, 제단, 떨어진 탑 조각, 떠 있는 바위, 빛 기둥 넷, 가장자리 성벽.
모델은 models/build_ruins.py 의 큰 돌 블록 유적. **자리는 전부 이 표에 손으로 적는다** (각·거리로 적은 것도 내가 고른 수다).
원 둘레·길 따라 같은 간격으로 두르는 것(포석, 회랑 칸, 성벽 토막, 열주)만 반복으로 펼치고, 칸마다 상태는 손으로 적는다.

좌표: 가운데 C=(400,-1467). 각 θ 는 x=cos, z=sin (90 이 북, 평원 쪽). yaw 는 도(로블록스 Y 축).
길·고리를 보는 모델(문, 신전, 계단 대지, 회랑)은 yaw = 90 - θ 면 로컬 -Z(앞)가 탑을 본다.
돌리는 법: python tools/ruins_plan.py [출력.png] [배율]   → 평면도, 겹침·땅·빈 곳 검사, Ruins_data.luau
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from plan_png import Canvas  # noqa: E402

CX, CZ = 400.0, -1467.0
RING_R = 433.0

# 모델 발자국 반폭(로컬 X, Z). build_ruins.py 미리보기 치수에서
FOOT = {
    "Tower_Podium": (137, 137), "Col_Big": (5.4, 5.4), "Col_Big_B": (5.2, 5.2), "Col_Big_C": (5.2, 5.2),
    "Col_Drums": (20, 7.5), "Gate_A": (34, 10.5), "Gate_B": (41, 19), "Arcade_A": (13.8, 5), "Arcade_B": (13.8, 8.7),
    "Arcade_C": (13.5, 10.3), "Arcade_Pier": (3.7, 4), "Shrine_Pavilion": (33.5, 39), "Shrine_Tower": (21, 21), "Terrace_A": (76.6, 79),
    "Terrace_B": (61.6, 64), "Pool_Big": (64.5, 64.5), "Pool_Mid": (51.5, 51.5), "Colossus": (13, 13.3),
    "Colossus_Head": (8.7, 10.1), "Colossus_Hand": (8.8, 12), "Stele_Big": (8, 4.7), "Altar_Big": (11, 8.2),
    "Brazier_Big": (3, 3), "Beacon_Base": (9, 9), "Chunk_Tower_A": (35, 15), "Chunk_Tower_B": (35, 15),
    "Float_Rock_A": (20.5, 21.6), "Float_Rock_B": (29.5, 28), "Float_Rock_C": (15, 14.2), "Edge_Wall_A": (8.9, 21),
    "Edge_Wall_B": (10.7, 20), "Edge_Tower": (15.9, 21.2), "Ruin_Room_A": (19.2, 15.7), "Ruin_Room_B": (18, 15.5),
    "Rubble_Heap_A": (9.7, 8.5), "Rubble_Heap_B": (11.3, 10.2), "Rubble_Field_A": (32, 31), "Rubble_Field_B": (32, 31.5),
    "Pave_Strip_A": (16.2, 20), "Pave_Strip_B": (16.2, 20), "Lintel_Big": (15.3, 3.8),
}
# 서로 겹쳐도 되는 것 (바닥에 까는 것, 떠 있는 것)
FLAT = {"Pave_Strip_A", "Pave_Strip_B", "Rubble_Field_A", "Rubble_Field_B"}
FLOAT = {"Float_Rock_A", "Float_Rock_B", "Float_Rock_C"}


def P(th, r):
    a = math.radians(th)
    return CX + r * math.cos(a), CZ + r * math.sin(a)


def face_in(th):
    """앞(-Z)이 탑을 보는 yaw"""
    return 90.0 - th


# ------------------------------------------------------------------ 네 참배로
# { 각, 문까지 r, 문 종류, 열주 상태(왼쪽 줄, 오른쪽 줄: I 멀쩡 B 반 C 밑동 F 쓰러짐 . 없음) }
WAYS = [
    (20, 340, "Gate_A", "IIBIIC", "IICIBI"),
    (110, 287, "Gate_B", "IBII.", "ICIB"),
    (200, 373, "Gate_A", "IIIBICI", "BIIIFII"),
    (290, 260, "Gate_B", "ICII", "IIBF"),
]
WAY_W = 30.0
COL_OFF = 27.0      # 길 가운데에서 열주까지
COL_GAP = 30.0      # 열주 간격 (인방 길이)
COL_R0 = 162.0      # 첫 열주 거리 (기단 계단 발치 밖)

# ------------------------------------------------------------------ 순례 고리
# 포석이 남은 구간 {θ0, θ1} (기존 RING_KEPT)
RING_KEPT = [(342, 438), (96, 168), (188, 246), (262, 318)]
# 회랑 구간 {θ0, θ1, 칸 상태}  A 멀쩡 B 아치 무너짐 C 밑동  (기존 ARCADES 3 구간)
# 칸 규칙: A 뒤에는 A/B 나 빈칸(.)·끝만 온다(A 아치 오른끝이 다음 칸 기둥에 얹히므로). 빈칸·끝 앞 A 에는 끝 기둥을 세운다.
# 참배로가 지나는 칸(20, 110, 200도)은 비운다
ARCADES = [
    (348, 64, "ABAAAABCA" + "..." + "AABAAAABCAAAA"),
    (102, 162, "A" + "..." + "AABAAABCAAABAAAA"),
    (198, 242, ".." + "AABAABCAAAAA"),
]
ARC_R = 462.0       # 회랑은 고리 길 바깥

# ------------------------------------------------------------------ 가장자리 성벽 {θ0, θ1, r, 칸 상태 A/B/. }
EDGE = [
    (6, 66, 655, "AB.ABAAB.ABABAB.A"),
    (94, 144, 660, "AB.BA.ABABAB.A"),
    (184, 234, 650, "ABAB.AAB.BABAB"),
    (266, 318, 628, "ABA.BABAB.ABAB"),
]

# ------------------------------------------------------------------ 하나씩 적는 것 { 모델, θ, r, yaw(None 이면 탑을 봄), 묻기, 기울기x, 기울기z }
ITEMS = [
    # 부속 신전 (고리 밖, 탑을 본다)
    ("Shrine_Pavilion", 20, 525, None, 0),
    ("Shrine_Tower", 110, 500, None, 0),
    ("Shrine_Pavilion", 200, 525, None, 0),
    ("Shrine_Pavilion", 290, 525, None, 0),
    ("Shrine_Tower", 66, 540, None, 0),
    # 계단 대지 둘 (기존 PLAZAS)
    ("Terrace_A", 155, 330, None, 0),
    ("Terrace_B", 335, 352, None, 0),
    # 검은 반사지 둘 (기존 POOLS)
    ("Pool_Big", 248, 342, 0, 0),
    ("Pool_Mid", 42, 540, 0, 0),
    # 부러진 거상 여덟 (기존 STATUES, 문·반사지 피해 손으로 옮김)
    ("Colossus", 6, 390, None, 0), ("Colossus", 50, 405, None, 0), ("Colossus", 134, 400, None, 0),
    ("Colossus", 176, 404, None, 0), ("Colossus", 222, 400, None, 0), ("Colossus", 272, 392, None, 0),
    ("Colossus", 304, 396, None, 0), ("Colossus", 318, 410, None, 0),
    ("Colossus_Head", 176, 372, 40, 4, 80, 0), ("Colossus_Head", 304, 368, -60, 4, 0, 75),
    ("Colossus_Head", 50, 376, 150, 4, 70, 20), ("Colossus_Hand", 134, 372, 20, 1),
    ("Colossus_Hand", 272, 364, -120, 1), ("Colossus_Hand", 6, 364, 60, 1),
    # 비석 (기존 STELES, 기울기 포함)
    ("Stele_Big", 5, 222, None, 1, 6, 0), ("Stele_Big", 38, 268, None, 1, -12, 0), ("Stele_Big", 132, 250, None, 1, 8, 0),
    ("Stele_Big", 176, 262, None, 1, 20, 0), ("Stele_Big", 238, 255, None, 1, -7, 0), ("Stele_Big", 272, 282, None, 1, 15, 0),
    ("Stele_Big", 318, 236, None, 1, -10, 0), ("Stele_Big", 352, 300, None, 1, 24, 0),
    # 제단 둘 (기존 ALTARS)
    ("Altar_Big", 65, 172, None, 0), ("Altar_Big", 245, 178, None, 0),
    # 떨어진 탑 조각 (기존 FALLEN, 기단 밖으로)
    ("Chunk_Tower_A", 50, 232, 70, 4), ("Chunk_Tower_B", 88, 300, -20, 4), ("Chunk_Tower_A", 150, 205, 160, 4),
    ("Chunk_Tower_B", 166, 452, 60, 4), ("Chunk_Tower_A", 226, 215, -80, 4), ("Chunk_Tower_B", 230, 515, 20, 4),
    ("Chunk_Tower_A", 266, 212, 110, 4), ("Chunk_Tower_B", 306, 470, -40, 4), ("Chunk_Tower_A", 346, 198, 30, 4),
    ("Chunk_Tower_B", 2, 520, 150, 4),
    # 빛 기둥 넷 (기존 BEACONS, 고리 위)
    ("Beacon_Base", 40, 433, 0, 0), ("Beacon_Base", 130, 433, 0, 0), ("Beacon_Base", 220, 433, 0, 0),
    ("Beacon_Base", 310, 433, 0, 0),
    # 망루 (성벽 구간 끝)
    ("Edge_Tower", 70, 655, None, 0), ("Edge_Tower", 148, 660, None, 0), ("Edge_Tower", 238, 650, None, 0),
    ("Edge_Tower", 322, 628, None, 0), ("Edge_Tower", 2, 655, None, 0),
    # 자갈 무더기 (기존 RUBBLE)
    ("Rubble_Heap_B", 72, 287, 80, 0), ("Rubble_Heap_A", 100, 488, 40, 0),
    ("Rubble_Heap_A", 178, 460, 70, 0), ("Rubble_Heap_B", 210, 506, 20, 0),
    ("Rubble_Heap_A", 254, 480, 110, 0), ("Rubble_Heap_B", 286, 300, 30, 0), ("Rubble_Heap_A", 318, 520, 60, 0),
    ("Rubble_Heap_B", 352, 500, 90, 0), ("Rubble_Heap_A", 120, 547, 20, 0), ("Rubble_Heap_B", 240, 553, 50, 0),
]

# 떠 있는 바위 { 모델, θ, r, 땅 위 높이, yaw } (기존 FLOATERS)
FLOATERS = [
    ("Float_Rock_B", 30, 253, 70, 10), ("Float_Rock_A", 84, 327, 113, 40), ("Float_Rock_B", 128, 213, 57, 80),
    ("Float_Rock_A", 162, 373, 140, 120), ("Float_Rock_C", 196, 293, 87, 160), ("Float_Rock_A", 232, 447, 100, 200),
    ("Float_Rock_B", 274, 233, 63, 240), ("Float_Rock_C", 310, 393, 127, 280), ("Float_Rock_A", 344, 313, 77, 320),
    ("Float_Rock_C", 58, 473, 153, 30), ("Float_Rock_B", 148, 500, 93, 60), ("Float_Rock_A", 218, 520, 117, 90),
    ("Float_Rock_C", 292, 493, 67, 150), ("Float_Rock_A", 12, 540, 137, 210),
]


# ------------------------------------------------------------------ 펼치기
def way_items():
    out = []
    for th, rg, gate, left, right in WAYS:
        a = math.radians(th)
        ux, uz = math.cos(a), math.sin(a)
        nx, nz = -uz, ux
        # 포석: 기단 계단 발치(r 140)부터 신전 앞(r 460)까지. 문 자리도 깐다
        r = 158.0
        k = 0
        while r < 470.0:
            out.append(("Pave_Strip_A" if k % 2 == 0 else "Pave_Strip_B", CX + ux * r, CZ + uz * r, face_in(th), 0.9, 0, 0))
            r += 40.0
            k += 1
        # 문
        out.append((gate, CX + ux * rg, CZ + uz * rg, face_in(th), 0, 0, 0))
        # 열주
        for side, states in ((-1, left), (1, right)):
            for i, st in enumerate(states):
                r = COL_R0 + COL_GAP * i
                if st == "." or r > rg - 26:
                    continue
                x, z = CX + ux * r + nx * COL_OFF * side, CZ + uz * r + nz * COL_OFF * side
                if st == "F":
                    fx, fz = x + nx * side * 14, z + nz * side * 14
                    out.append(("Col_Drums", fx, fz, face_in(th) + 90 + 20 * side, 0, 0, 0))
                else:
                    out.append(({"I": "Col_Big", "B": "Col_Big_B", "C": "Col_Big_C"}[st], x, z, face_in(th), 0, 0, 0))
            # 인방: 이웃한 두 멀쩡한 기둥 위
            for i in range(len(states) - 1):
                if states[i] == "I" and states[i + 1] == "I" and COL_R0 + COL_GAP * (i + 1) <= rg - 26:
                    r = COL_R0 + COL_GAP * (i + 0.5)
                    x, z = CX + ux * r + nx * COL_OFF * side, CZ + uz * r + nz * COL_OFF * side
                    out.append(("Lintel_Big", x, z, face_in(th) + 90, "col", 0, 0))
        # 화로: 열주 바깥
        for r in (190.0, 250.0):
            if r < rg - 20:
                for side in (-1, 1):
                    out.append(("Brazier_Big", CX + ux * r + nx * 44 * side, CZ + uz * r + nz * 44 * side, 0, 0, 0, 0))
    return out


def ring_items():
    out = []

    def span(a0, a1):
        return (a1 - a0) % 360 if (a1 - a0) % 360 else 360

    # 고리 포석: 남은 구간만, 40 마다 (각 = 40/R)
    step = math.degrees(40.0 / RING_R)
    for a0, a1 in RING_KEPT:
        n = int(span(a0, a1 % 360) / step) if a1 > 360 else int((a1 - a0) / step)
        for j in range(n):
            th = a0 + step * (j + 0.5)
            x, z = P(th, RING_R)
            # 길 따라 눕는다: 로컬 Z 가 접선
            out.append(("Pave_Strip_A" if j % 2 else "Pave_Strip_B", x, z, -th, 0.9, 0, 0))
    # 회랑
    bay = math.degrees(24.0 / ARC_R)
    for a0, a1, states in ARCADES:
        for j, st in enumerate(states):
            th = a0 + bay * (j + 0.5)
            if st == ".":
                continue
            x, z = P(th, ARC_R)
            # 칸 기둥은 로컬 +X(블렌더 -x) 에 있다. 로컬 +X 가 θ 가 줄어드는 쪽을 보게 yaw = 90 - θ
            out.append(({"A": "Arcade_A", "B": "Arcade_B", "C": "Arcade_C"}[st], x, z, 90.0 - th, 0, 0, 0))
            nxt = states[j + 1] if j + 1 < len(states) else "."
            if st == "A" and nxt == ".":
                x, z = P(th + bay / 2, ARC_R)
                out.append(("Arcade_Pier", x, z, 90.0 - th, 0, 0, 0))
            assert not (st == "A" and nxt == "C"), "회랑 %d 칸: A 다음에 C 가 오면 아치가 밑동에 뜬다" % j
    # 가장자리 성벽
    for a0, a1, r, states in EDGE:
        seg = math.degrees(40.0 / r)
        for j, st in enumerate(states):
            th = a0 + seg * (j + 0.5)
            if st == "." or th > a1:
                continue
            x, z = P(th, r)
            out.append(("Edge_Wall_A" if st == "A" else "Edge_Wall_B", x, z, -th, 0, 0, 0))
    return out


def fillers():
    """빈 곳 메우기. 빈 곳 검사로 찾아 손으로 적는다 { 모델, x, z, yaw }"""
    return FILL


FILL_POLAR = [
    # 북동 바깥 (20~110)
    ("Rubble_Field_A", 8, 598, 0), ("Ruin_Room_A", 34, 605, 10), ("Rubble_Field_B", 32, 575, 20),
    ("Ruin_Room_B", 54, 606, -20), ("Rubble_Field_A", 62, 470, 30), ("Col_Big_B", 76, 596, 0), ("Col_Big", 80, 606, 0),
    ("Col_Big_C", 84, 596, 0), ("Ruin_Room_A", 94, 598, 40), ("Rubble_Field_B", 98, 548, 0), ("Rubble_Heap_B", 88, 530, 0),
    # 북서 바깥 (110~200)
    ("Ruin_Room_B", 124, 596, 0), ("Rubble_Field_B", 130, 546, 0), ("Ruin_Room_A", 142, 566, 30), ("Col_Big", 156, 590, 0),
    ("Col_Big_B", 160, 606, 0), ("Rubble_Field_A", 160, 520, 0), ("Ruin_Room_B", 174, 596, -30),
    ("Rubble_Field_B", 186, 596, 0), ("Rubble_Heap_A", 190, 562, 0),
    # 남서 바깥 (200~290)
    ("Ruin_Room_A", 214, 596, 0), ("Rubble_Field_A", 226, 600, 0), ("Ruin_Room_B", 250, 600, 20),
    ("Rubble_Field_B", 262, 544, 0), ("Col_Big_C", 266, 590, 0), ("Col_Big", 270, 598, 0), ("Ruin_Room_A", 280, 576, -10),
    # 남동 바깥 (290~380)
    ("Ruin_Room_B", 302, 580, 0), ("Rubble_Field_A", 312, 590, 0), ("Ruin_Room_A", 334, 590, 20),
    ("Rubble_Field_B", 344, 520, 0), ("Col_Big_B", 350, 594, 0), ("Ruin_Room_B", 358, 600, -40),
    # 안쪽 빈 곳
    ("Rubble_Field_B", 70, 334, 0), ("Col_Drums", 80, 352, 30), ("Rubble_Field_A", 222, 300, 0),
    ("Rubble_Field_B", 310, 300, 0), ("Rubble_Heap_A", 128, 300, 0), ("Rubble_Field_A", 165, 212, 0),
    ("Ruin_Room_A", 184, 300, 10), ("Rubble_Heap_B", 80, 222, 0),
    ("Rubble_Field_A", 328, 505, 15), ("Ruin_Room_B", 82, 492, 0), ("Rubble_Heap_A", 40, 330, 0),
    ("Ruin_Room_A", 272, 520, 5), ("Rubble_Field_B", 110, 590, 0), ("Rubble_Heap_B", 248, 505, 0),
    ("Rubble_Field_A", 58, 555, 0),
    # 성벽 바깥 가장자리
    ("Rubble_Field_B", 330, 702, 0), ("Rubble_Field_A", 166, 700, 0), ("Rubble_Field_B", 252, 705, 0),
    ("Rubble_Field_A", 78, 720, 0), ("Rubble_Field_B", 286, 700, 0), ("Rubble_Field_A", 45, 735, 0),
    ("Rubble_Field_B", 226, 718, 0), ("Rubble_Field_A", 135, 735, 0), ("Rubble_Field_B", 200, 705, 0),
    ("Rubble_Field_A", 17, 712, 0), ("Rubble_Field_B", 108, 722, 0), ("Rubble_Field_A", 27, 722, 0),
    ("Rubble_Heap_A", 338, 690, 0), ("Rubble_Heap_B", 160, 690, 0), ("Rubble_Heap_A", 258, 690, 0),
    ("Rubble_Heap_B", 84, 700, 0), ("Rubble_Heap_A", 220, 700, 0), ("Rubble_Heap_B", 140, 710, 0),
    # 성벽이 끊긴 들머리(318~6, 66~94, 144~184, 234~266)와 남은 가장자리
    ("Ruin_Room_B", 347, 650, 20), ("Rubble_Field_A", 313, 716, 0), ("Ruin_Room_A", 175, 536, 0),
    ("Rubble_Field_B", 151, 690, 0), ("Ruin_Room_B", 176, 672, 10), ("Rubble_Field_A", 244, 672, 0),
    ("Rubble_Field_B", 69, 735, 0), ("Ruin_Room_A", 89, 660, 0), ("Rubble_Field_A", 88, 436, 0),
    ("Rubble_Heap_A", 260, 642, 0), ("Rubble_Field_B", 293, 718, 0), ("Rubble_Heap_B", 75, 527, 0),
    ("Rubble_Field_A", 279, 712, 0), ("Rubble_Field_B", 233, 738, 0),
    ("Rubble_Heap_A", 354, 680, 0), ("Rubble_Field_A", 320, 722, 0), ("Rubble_Heap_B", 303, 690, 0),
    ("Rubble_Heap_A", 185, 505, 0), ("Col_Big_C", 166, 590, 0),
    # 빈 곳 기준 28 로 다시 찾은 맨땅 (2차)
    ("Rubble_Field_B", 337, 598, 30), ("Rubble_Field_A", 329, 624, 0), ("Col_Big_B", 342, 628, 0),
    ("Ruin_Room_B", 158, 630, -20), ("Rubble_Field_A", 150, 645, 0), ("Rubble_Field_B", 245, 520, 0),
    ("Rubble_Field_A", 359, 317, 0), ("Col_Drums", 0, 300, 60), ("Rubble_Field_B", 270, 337, 0),
    ("Rubble_Field_A", 203, 580, 0), ("Rubble_Field_B", 55, 331, 0), ("Rubble_Field_A", 256, 578, 0),
    ("Rubble_Field_B", 301, 540, 0), ("Rubble_Field_A", 68, 596, 0), ("Rubble_Field_B", 185, 393, 0),
    ("Rubble_Field_A", 78, 652, 0), ("Rubble_Heap_A", 85, 565, 0), ("Rubble_Field_A", 123, 355, 0),
    ("Rubble_Field_B", 268, 680, 0), ("Rubble_Field_B", 98, 365, 0), ("Rubble_Field_A", 117, 562, 0),
    ("Rubble_Heap_B", 20, 600, 0), ("Rubble_Field_B", 52, 722, 0), ("Rubble_Heap_A", 322, 455, 0),
    ("Rubble_Heap_B", 35, 362, 0), ("Rubble_Field_A", 279, 500, 0), ("Rubble_Field_B", 180, 648, 0),
    ("Rubble_Field_A", 128, 722, 0), ("Rubble_Heap_A", 38, 712, 0), ("Rubble_Field_B", 325, 215, 0),
    ("Rubble_Field_A", 222, 365, 0), ("Rubble_Heap_B", 136, 596, 0), ("Rubble_Heap_B", 353, 560, 0),
    ("Rubble_Heap_A", 115, 715, 0), ("Rubble_Heap_B", 192, 700, 0), ("Rubble_Field_A", 353, 645, 0),
    ("Rubble_Heap_B", 102, 608, 0), ("Rubble_Field_B", 138, 515, 0), ("Rubble_Heap_B", 181, 548, 0),
    ("Rubble_Heap_B", 342, 705, 0), ("Rubble_Field_B", 337, 490, 0), ("Rubble_Field_A", 239, 590, 0),
]
FILL = [(m, P(th, r)[0], P(th, r)[1], yaw) for m, th, r, yaw in FILL_POLAR]


def all_items():
    out = []
    for m, th, r, yaw, sink, *tilt in ITEMS:
        x, z = P(th, r)
        tx, tz = (tilt + [0, 0])[:2]
        out.append((m, x, z, face_in(th) if yaw is None else yaw, sink, tx, tz))
    out += way_items()
    out += ring_items()
    for m, x, z, yaw in FILL:
        out.append((m, x, z, yaw, 0, 0, 0))
    return out


def floaters():
    out = []
    for m, th, r, h, yaw in FLOATERS:
        x, z = P(th, r)
        out.append((m, x, z, h, yaw))
    return out


# ------------------------------------------------------------------ 땅
def terrain():
    L = open(os.path.join(HERE, "sanctuary_height.txt"), encoding="utf-8").read().split("\n")
    x0, z0, st, nx, nz = map(int, L[0].split())
    rows = [list(map(float, r.split())) for r in L[1:1 + nz]]
    return x0, z0, st, nx, nz, rows


T = terrain()


def ground(x, z):
    x0, z0, st, nx, nz, rows = T
    i, j = int(round((x - x0) / st)), int(round((z - z0) / st))
    if not (0 <= i < nx and 0 <= j < nz):
        return None
    v = rows[j][i]
    return None if v < -900 else v


def rect(m, x, z, yaw, pad=0.0):
    hx, hz = FOOT[m]
    hx, hz = hx + pad, hz + pad
    a = math.radians(yaw)
    c, s = math.cos(a), math.sin(a)
    return [(x + lx * c + lz * s, z - lx * s + lz * c) for lx, lz in ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz))]


def overlap(p, q):
    def axes(Pp):
        return [(Pp[(k + 1) % 4][1] - Pp[k][1], -(Pp[(k + 1) % 4][0] - Pp[k][0])) for k in range(2)]
    for ax in axes(p) + axes(q):
        pa = [ax[0] * x + ax[1] * z for x, z in p]
        qa = [ax[0] * x + ax[1] * z for x, z in q]
        if max(pa) <= min(qa) or max(qa) <= min(pa):
            return False
    return True


def check():
    msgs = []
    items = [it for it in all_items() if it[4] != "col"]
    R = [(m, x, z, rect(m, x, z, y, -1.0)) for m, x, z, y, s, tx, tz in items]
    R.append(("Tower_Podium", CX, CZ, rect("Tower_Podium", CX, CZ, 0, -1.0)))
    for i in range(len(R)):
        for j in range(i + 1, len(R)):
            a, b = R[i], R[j]
            if a[0] in FLAT or b[0] in FLAT:
                continue
            if a[0][:6] == b[0][:6] and a[0][:6] in ("Arcade", "Edge_W"):
                continue
            if {a[0], b[0]} <= {"Arcade_A", "Arcade_B", "Arcade_C", "Arcade_Pier"}:
                continue
            if a[0] == "Tower_Podium" or b[0] == "Tower_Podium":
                o = b if a[0] == "Tower_Podium" else a
                if math.hypot(o[1] - CX, o[2] - CZ) - max(FOOT[o[0]]) * 0.9 < 137:
                    msgs.append("기단 겹침 %s(%.0f,%.0f)" % (o[0], o[1], o[2]))
                continue
            if overlap(a[3], b[3]):
                msgs.append("겹침 %s(%.0f,%.0f) ~ %s(%.0f,%.0f)" % (a[0], a[1], a[2], b[0], b[1], b[2]))
    for m, x, z, r in R:
        if m == "Tower_Podium":
            continue
        g = ground(x, z)
        if g is None or g < 6.4:
            msgs.append("땅 밖 %s(%.0f,%.0f) 땅 %s" % (m, x, z, g))
    return msgs


def coverage(cell=20.0, gap=45.0):
    """섬 땅(모래 아닌) 칸마다 가장 가까운 유적 발자국까지 거리. gap 넘는 칸을 이웃끼리 묶어 빈 곳으로 보고"""
    items = [it for it in all_items() if it[4] != "col"]
    boxes = [(x, z, max(FOOT[m])) for m, x, z, y, s, tx, tz in items] + [(CX, CZ, 137)]
    boxes += [(x, z, max(FOOT[m])) for m, x, z, h, yaw in floaters()]
    x0, z0, st, nx, nz, rows = T
    empty = []
    x = x0 + cell / 2
    while x < x0 + st * nx:
        z = z0 + cell / 2
        while z < z0 + st * nz:
            g = ground(x, z)
            if g is not None and g >= 6.4:
                d = min(math.hypot(x - bx, z - bz) - br for bx, bz, br in boxes)
                if d > gap:
                    empty.append((x, z, d))
            z += cell
        x += cell
    # 이웃끼리 묶기
    key = {(round(e[0]), round(e[1])): e for e in empty}
    seen, blobs = set(), []
    for e in empty:
        k0 = (round(e[0]), round(e[1]))
        if k0 in seen:
            continue
        stack, cells = [k0], []
        seen.add(k0)
        while stack:
            k = stack.pop()
            cells.append(key[k])
            for dx in (-cell, 0, cell):
                for dz in (-cell, 0, cell):
                    q = (round(k[0] + dx), round(k[1] + dz))
                    if q in key and q not in seen:
                        seen.add(q)
                        stack.append(q)
        cx = sum(c[0] for c in cells) / len(cells)
        cz = sum(c[1] for c in cells) / len(cells)
        blobs.append((len(cells), cx, cz, max(c[2] for c in cells)))
    blobs.sort(reverse=True)
    return empty, blobs


# ------------------------------------------------------------------ 평면도
def render(path, sc):
    x0, z0, st, nx, nz, rows = T
    reg = (x0, z0, x0 + st * (nx - 1), z0 + st * (nz - 1))
    C = Canvas(*reg, sc)
    C.rect(*reg, "#3d6488")
    for j, row in enumerate(rows):
        for i, h in enumerate(row):
            if h < -900:
                continue
            xx, zz = x0 + i * st, z0 + j * st
            C.rect(xx - st / 2, zz - st / 2, xx + st / 2, zz + st / 2, "#cdbf94" if h < 6.4 else "#8e8b80")
    empty, blobs = coverage()
    for ex, ez, d in empty:
        C.rect(ex - 10, ez - 10, ex + 10, ez + 10, "#c04040", 0.5)
    C.circle(CX, CZ, 137, "#d9d5c6")
    col = {"Pave_Strip_A": "#bdb9ab", "Pave_Strip_B": "#bdb9ab", "Rubble_Field_A": "#a9a598", "Rubble_Field_B": "#a9a598"}
    for m, x, z, y, s, tx, tz in all_items():
        if s == "col":
            continue
        C.poly(rect(m, x, z, y), col.get(m, "#f1eee4" if not m.startswith("Col") else "#fbfaf5"))
    for m, x, z, h, yaw in floaters():
        C.poly(rect(m, x, z, yaw), "#6a6a70", 0.5)
    C.save(path)


def lua(v):
    if isinstance(v, str):
        return '"' + v + '"'
    if isinstance(v, (int, float)):
        return ("%.3f" % v).rstrip("0").rstrip(".")
    return "{" + ", ".join(lua(x) for x in v) + "}"


def emit(path):
    lines = ["-- ruins_plan.py 가 적은 표. 손으로 고치지 말고 ruins_plan.py 를 고쳐 다시 뽑는다", "local D = {}",
             "D.CX, D.CZ = %s, %s" % (lua(CX), lua(CZ))]
    lines.append("D.ITEMS = {")
    for it in all_items():
        lines.append("\t" + lua(list(it)) + ",")
    lines.append("}")
    lines.append("D.FLOATERS = {")
    for it in floaters():
        lines.append("\t" + lua(list(it)) + ",")
    lines.append("}")
    lines.append("return D")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "ruins_plan.png")
    sc = float(sys.argv[2]) if len(sys.argv) > 2 else 0.6
    render(out, sc)
    emit(os.path.join(HERE, "Ruins_data.luau"))
    items = all_items()
    kinds = {}
    for m, *_ in items:
        kinds[m] = kinds.get(m, 0) + 1
    print("놓을 것 %d, 떠 있는 바위 %d" % (len(items), len(floaters())))
    print(", ".join("%s %d" % kv for kv in sorted(kinds.items())))
    msgs = check()
    for m in msgs:
        print(m)
    print("검사 %d 건" % len(msgs))
    empty, blobs = coverage()
    print("빈 칸(가장 가까운 유적까지 45 넘음) %d, 덩어리 %d" % (len(empty), len(blobs)))
    for n, x, z, d in blobs[:40]:
        print("  빈 곳 %3d 칸 @ (%.0f, %.0f) 최대 %.0f" % (n, x, z, d))
