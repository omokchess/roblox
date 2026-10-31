# -*- coding: utf-8 -*-
"""
snow_field_plan.py — 2026-10-09. 설원 지상 마무리(손 표) → tools/Snow_Field_data.luau
  - 얼어붙은 호수(2026-10-31 사용자: "여기 보스룸이에요 하고 표시하기보다 지형 하나를 놓고 들어가면 보스가 등장" — 참고 사진: 얼어붙은 호수의 보레아리스):
    보스 단 가운데 땅을 3.6 파내고(LAKE_CARVE — 블록 양식 네모 이음) 얼음판, 물가는 드러난 바위 턱 + 눈, 검은 큰 바위·디딤 바위,
    마른 흰 나무(손 표 — 줄기 + 가지), 눈 덮인 소나무, 북쪽 안개 속 벼랑 바위, 낮게 깔리는 안개(Fog 표지), 얼음 금, 얼음 위 눈 자국.
    들어가면 싸움: 표지 BossTrigger(태그 BossTrigger, 속성 EnemyId · Radius — 보스 미정이라 EnemyId 빈칸, BattleService 가 본다)
  - (구)설공방 폐허(2026-10-31, 이야기 "불탄 설 공방"): 돌 받침 + 부서진 벽(창·문 자리), 그을린 대들보·서까래·기둥 그루터기, 무너진 지붕판,
    벽돌 화덕(아직 남은 불씨 — 불·연기·빛) + 부러진 굴뚝, 모루, 탄 작업대·상자, 톱니(키트), 돌무더기, 그을음, 눈 더미, 떨어진 간판 "설 공방"
  - 순례자의 휴식처 2/8(북동 들): 돌 단, 모닥불, 차양 쉼터, 통나무 의자, 퀘스트 물건 받침(속성 QuestItem)
  - 동굴 입구 셋은 비스듬한 굴(snow_tunnel_plan.py · Snow_Tunnels.luau) — 여기선 그 자리에 나무만 안 심는다
  - 순간이동 명소(TeleportSpot 표지 Spot — 속성 SpotName · Region · Order): 보스룸 · 설공방 폐허 · 휴식처 2/8
  - 눈 나무 숲: 손 덩어리 안에 간격대로(숲 키트 나무를 눈 색으로) · 큰 바위 몇 개
좌표 = 똑바로 한 지상 그림 좌표(snow3_plan, 1px = 3.7 스터드). 바닥 높이는 그 자리 구역 높이(snow3_ground).
돌리기: python tools/snow_field_plan.py (문제 0건) → 짓기: tools/Snow_Field.luau
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from snow3_plan import SCALE, world  # noqa: E402
import snow3_ground as SG  # noqa: E402

G, NX, NY = SG.grid()
_, _, _, _, ROCKS, _ = SG.main()  # 단 사이 바위 무리 상자(나무를 피하려고)


def top_at(X, Y):
    return SG.zone_at(X, Y, G)


BOXES = []    # (묶음, cx, cy, cz, sx, sy, sz, ry, rx, rz)
KITS = []     # (틀, x, y, z, yaw, 배율, 기울기)
MARKS = []    # (이름, x, y, z, 속성)
TREES = []    # (틀, x, y, z, yaw, 배율)
bad = []


def box(group, X, Y, base, sx, sy, sz, ry=0.0, dy=0.0):
    x, z = world(X, Y)
    BOXES.append((group, x, base + dy + sy / 2, z, sx, sy, sz, ry, 0.0, 0.0))


def rot(lx, lz, a):
    """몸 좌표(lx, lz) → 세계 오프셋. 로블록스 Y 돌림 a 도: +X → (cos, -sin), +Z → (sin, cos)."""
    r = math.radians(a)
    return lx * math.cos(r) + lz * math.sin(r), -lx * math.sin(r) + lz * math.cos(r)


def lbox(group, ox, oz, base, yaw, lx0, lx1, lz0, lz1, y0, y1, ry=0.0, rx=0.0, rz=0.0):
    """yaw 로 돌린 몸 좌표의 상자(땅 높이 base 기준 y0~y1)."""
    cx, cz = rot((lx0 + lx1) / 2, (lz0 + lz1) / 2, yaw)
    BOXES.append((group, ox + cx, base + (y0 + y1) / 2, oz + cz, lx1 - lx0, y1 - y0, lz1 - lz0, yaw + ry, rx, rz))


def polar(cx, cz, r, ang):
    """가운데에서 ang 도(0 = 동, 90 = 남) r 스터드."""
    a = math.radians(ang)
    return cx + math.cos(a) * r, cz + math.sin(a) * r


# ── 얼어붙은 호수 ── 가운데(그림 — 옛 보스룸 자리) · 몸 좌표 lx 동 · lz 남(스터드)
BC = (510, 1205)
ltop = top_at(*BC)
by = ltop - 0.2                      # 물가 눈 높이
ICE = ltop - 3.8                     # 얼음 윗면(물가보다 3.6 낮다)
bx, bz = world(*BC)
# 호수 = 겹치지 않는 네모 이음(손) { lx0, lx1, lz0, lz1 } — 땅을 파는 상자이자 얼음판
LAKE = [(-150, 140, -95, 105), (-115, 85, -140, -95), (-185, -150, -55, 65), (140, 172, -45, 55),
        (-85, 55, 105, 138), (85, 125, -122, -95), (-60, -15, -162, -140)]
LAKE_CARVE = []
for x0, x1, z0, z1 in LAKE:
    LAKE_CARVE.append((bx + x0, bx + x1, ltop - 4.6, ltop + 1, bz + z0, bz + z1))
    BOXES.append(("LakeIce", bx + (x0 + x1) / 2, ICE - 0.4, bz + (z0 + z1) / 2, x1 - x0, 0.8, z1 - z0, 0.0, 0.0, 0.0))


def on_ice(lx, lz, pad=0.0):
    return any(x0 - pad <= lx <= x1 + pad and z0 - pad <= lz <= z1 + pad for x0, x1, z0, z1 in LAKE)


# 얼음 금(얇은 검푸른 줄, 부딪힘 없음) { lx, lz, 길이, 돌림 } · 얼음 위 눈 자국 { lx, lz, 폭, 깊이, 돌림 }
for lx, lz, ln, ry in ((-40, -20, 46, 25), (-18, -8, 22, -40), (30, 40, 38, 70), (52, 30, 18, 10), (-95, 50, 30, -15),
                       (90, -60, 34, 50), (-120, -30, 20, 85), (10, 95, 26, -60), (-10, -110, 28, 15)):
    BOXES.append(("IceCrack", bx + lx, ICE + 0.03, bz + lz, 0.35, 0.06, ln, ry, 0.0, 0.0))
for lx, lz, w, d, ry in ((-70, -60, 26, 14, 20), (60, 70, 18, 30, -15), (110, 10, 14, 22, 40), (-140, 20, 20, 12, 0),
                         (-30, 120, 30, 10, 5), (20, -125, 24, 9, -10)):
    BOXES.append(("IceSnow", bx + lx, ICE + 0.15, bz + lz, w, 0.3, d, ry, 0.0, 0.0))

# 물가 큰 바위(검은 바위 + 눈 윗판) { lx, lz, 폭, 높이, 깊이, 돌림, 기울기 x, z } — 반은 얼음에 박힌 것도
ROCKS_L = [(-160, -100, 26, 16, 20, 15, 0, 4), (-196, -20, 18, 12, 22, -20, 6, 0), (-178, 78, 24, 14, 18, 35, 0, -5),
           (-98, 150, 20, 10, 16, 10, 0, 0), (66, 148, 28, 15, 20, -25, -4, 0), (150, 78, 22, 18, 24, 5, 0, 6),
           (184, -10, 16, 11, 18, 40, 5, 0), (150, -78, 24, 13, 20, -10, 0, -4), (100, -136, 20, 16, 18, 22, 0, 0),
           (-70, -172, 30, 18, 22, -5, -5, 0), (-132, -150, 18, 12, 16, 50, 0, 7), (-20, 40, 12, 7, 10, 30, 8, 0),
           (70, -20, 9, 5, 8, -40, 0, 10), (-110, -60, 10, 6, 12, 15, -6, 0)]
for lx, lz, w, h, d, ry, rx, rz in ROCKS_L:
    base = ICE if on_ice(lx, lz) else by
    BOXES.append(("LakeRock" if (int(lx) // 10) % 2 == 0 else "LakeRock2", bx + lx, base - 1.5 + h / 2, bz + lz, w, h, d, ry, rx, rz))
    BOXES.append(("SnowCap", bx + lx, base - 1.5 + h + 0.2, bz + lz, w * 0.86, 0.7, d * 0.8, ry, rx, rz))
# 디딤 바위(물가 ↔ 얼음 — 3.6 턱을 두 번에) { lx, lz, 돌림 } — 얼음 쪽 낮은 돌(1.8) + 물가 쪽 높은 돌(3.4)
for lx, lz, ry in ((-150, 10, 0), (-20, 105, 90), (140, -10, 180), (-40, -140, 270)):
    for step, (dx, h, w) in enumerate(((-5, 1.8, 7), (0.5, 3.4, 6))):
        ox, oz = rot(dx, 0, ry)
        BOXES.append(("LakeRock2" if step else "LakeRock", bx + lx + ox, ICE + h / 2 - 0.1, bz + lz + oz, w, h, 8 + step * 2, ry + step * 9, 0.0, 0.0))
        BOXES.append(("SnowCap", bx + lx + ox, ICE + h + 0.15, bz + lz + oz, w * 0.8, 0.5, (8 + step * 2) * 0.8, ry + step * 9, 0.0, 0.0))

# 마른 흰 나무(손) { lx, lz, 높이, 돌림, 기울기, 모양 } — 줄기 + 가지(모양마다 { 높이 비율, 돌림, 길이, 들림 각 })
BRANCHES = {
    1: [(0.45, 30, 7, 40), (0.6, 160, 6, 35), (0.72, 260, 8, 50), (0.85, 90, 5, 30), (0.95, 200, 4, 55)],
    2: [(0.5, 0, 9, 25), (0.62, 120, 7, 45), (0.78, 230, 6, 35), (0.9, 330, 5, 60)],
    3: [(0.35, 70, 5, 20), (0.55, 200, 8, 40), (0.7, 310, 7, 30), (0.82, 40, 6, 50), (0.93, 150, 4, 45), (0.98, 260, 3, 60)],
}
DEAD = [(-128, -118, 26, 10, 4, 1), (-170, 40, 22, 80, -3, 2), (-120, 128, 30, 150, 5, 3), (-40, 150, 20, 200, 0, 2),
        (40, 152, 24, 30, -4, 1), (120, 110, 28, 260, 3, 3), (176, 30, 20, 300, 6, 2), (160, -60, 25, 120, -2, 1),
        (60, -140, 22, 45, 4, 3), (-10, -156, 27, 330, -5, 2), (-90, -40, 18, 15, 7, 1), (95, 60, 16, 100, -6, 3),
        (-55, 70, 14, 240, 9, 2)]
for lx, lz, h, ry, lean, shape in DEAD:
    base = ICE if on_ice(lx, lz) else by
    tone = "DeadWood" if shape != 3 else "DeadWood2"
    cx, cz = bx + lx, bz + lz
    BOXES.append((tone, cx, base - 1 + h / 2, cz, 1.6, h + 1, 1.6, ry, lean, 0.0))
    lr = math.radians(lean)
    for f, ay, ln, up in BRANCHES[shape]:
        hy = base - 1 + (h + 1) * f
        # 줄기가 기운 만큼 가지 뿌리도 옮긴다(기울기는 몸 X 축 — 위로 갈수록 몸 +Z 쪽으로)
        sx_, sz_ = rot(0, math.sin(lr) * (h + 1) * (f - 0.5), ry)
        a = math.radians(ry + ay)
        dirx, dirz = math.cos(a), -math.sin(a)
        reach = ln / 2 * math.cos(math.radians(up))
        BOXES.append((tone, cx + sx_ + dirx * reach, hy + ln / 2 * math.sin(math.radians(up)), cz + sz_ + dirz * reach,
                      0.6, 0.6, ln, ry + ay + 90, -up, 0.0))
# 눈 덮인 소나무(물가 뒤 — 손) { 틀, lx, lz, 돌림, 배율 }
for kind, lx, lz, ry, sc in (("Pine_A", -205, -90, 0, 1.6), ("Pine_B", -215, 30, 45, 1.4), ("Pine_A", -190, 120, 90, 1.5),
                             ("Pine_B", -60, 185, 30, 1.7), ("Pine_A", 100, 175, 60, 1.3), ("Pine_B", 205, 40, 15, 1.6),
                             ("Pine_A", 200, -80, 75, 1.4), ("Pine_B", 140, -150, 20, 1.5), ("Birch_A", -150, 165, 0, 1.3),
                             ("Pine_A", 30, 190, 120, 1.6)):
    TREES.append((kind, bx + lx, by - 0.3, bz + lz, ry, sc))
# 북쪽 안개 속 벼랑 바위(호수 뒤 230 ~ 300 — 엇갈린 큰 덩어리) { lx0, lx1, lz0, lz1, 높이, 돌림 }
for lx0, lx1, lz0, lz1, h, ry in ((-170, -110, -300, -250, 34, 6), (-120, -50, -285, -240, 46, -4), (-60, 10, -310, -262, 40, 3),
                                  (0, 70, -292, -246, 52, -7), (60, 130, -305, -255, 38, 5), (120, 180, -280, -235, 30, -3),
                                  (-90, -40, -250, -228, 20, 12), (30, 90, -248, -224, 24, -10), (-150, -95, -246, -226, 16, 8)):
    lbox("CliffRock" if h > 35 else "LakeRock", bx, bz, by - 1, 0, lx0, lx1, lz0, lz1, 0, h, ry)
    lbox("SnowCap", bx, bz, by - 1, 0, lx0 + 2, lx1 - 2, lz0 + 2, lz1 - 2, h - 0.2, h + 0.6, ry)
# 안개: 얼음 위 낮게 흐르는 안개 덩이(표지 Fog — 연기 입자) { lx, lz }
for lx, lz in ((-100, -40), (-20, 30), (60, -50), (110, 40), (-60, 100), (0, -110), (-150, 10), (140, -20)):
    MARKS.append(("Fog", bx + lx, ICE + 3, bz + lz, {}))
MARKS.append(("BossTrigger", bx, ICE + 6, bz, {"Region": "설원", "Name": "얼어붙은 호수", "EnemyId": "", "Radius": 150}))
sx_, sz_ = bx - 236, bz + 10
MARKS.append(("Spot", sx_, by + 1.4, sz_, {"SpotName": "얼어붙은 호수", "Region": "설원", "Order": 1, "LookX": bx, "LookZ": bz}))

# ── (구)설공방 폐허 ── 가운데(그림) · 몸 돌림(도). 몸 좌표 lx 동 · lz 남(스터드), y 땅 위
RC = (766, 1065)
RYAW = 8
rg = top_at(*RC) - 0.2
rcx, rcz = world(*RC)


def R(group, lx0, lx1, lz0, lz1, y0, y1, ry=0.0, rx=0.0, rz=0.0):
    lbox(group, rcx, rcz, rg, RYAW, lx0, lx1, lz0, lz1, y0, y1, ry, rx, rz)


def wall(lx0, lx1, lz0, lz1, top, tone=1, crumbs=()):
    """돌벽(받침 위 1.0 부터 top) + 눈 윗판 + 위 부스러기 { 몸 따라 비율, 폭, 높이, 돌림 }."""
    g = "RuinStone" if tone == 1 else "RuinStone2"
    R(g, lx0, lx1, lz0, lz1, 1.0, top)
    R("SnowCap", lx0 - 0.15, lx1 + 0.15, lz0 - 0.15, lz1 + 0.15, top - 0.2, top + 0.35)
    along_x = (lx1 - lx0) >= (lz1 - lz0)
    for f, w, h, ry in crumbs:
        if along_x:
            mx, mz = lx0 + (lx1 - lx0) * f, (lz0 + lz1) / 2
            R(g, mx - w / 2, mx + w / 2, mz - 1.3, mz + 1.3, top, top + h, ry)
        else:
            mx, mz = (lx0 + lx1) / 2, lz0 + (lz1 - lz0) * f
            R(g, mx - 1.3, mx + 1.3, mz - w / 2, mz + w / 2, top, top + h, ry)


R("Plinth", -35, 35, -25, 25, -0.4, 1.0)
R("Plinth2", -38, -31, 18, 29, -0.4, 0.6, 6)               # 문 앞 무너진 받침 돌
# 북쪽 벽(lz -24 ~ -21): 높고 낮음 손, 창 하나(lx -10 ~ -6, 8 ~ 14 비움), 22 ~ 34 는 낮게 남음
wall(-34, -20, -24, -21, 18, 1, ((0.3, 3, 2.2, 10),))
wall(-20, -14, -24, -21, 9.4, 2, ((0.6, 2.4, 1.6, -15),))
wall(-14, -10, -24, -21, 21.2, 1)
R("RuinStone2", -10, -6, -24, -21, 1.0, 8)
R("RuinStone2", -10, -6, -24, -21, 14, 21.2)
R("SnowCap", -10.15, -5.85, -24.15, -20.85, 21.0, 21.55)
wall(-6, -2, -24, -21, 20.6, 1, ((0.5, 2.6, 1.8, 20),))
wall(-2, 10, -24, -21, 11.2, 2, ((0.2, 3.4, 2.6, -8), (0.75, 2.2, 1.4, 25)))
wall(10, 22, -24, -21, 4.2, 1)
wall(22, 34, -24, -21, 15.4, 2, ((0.4, 3, 2.4, 12),))
# 남쪽 벽(lz 21 ~ 24): 문 자리 lx -8 ~ 2(문턱 돌), 창 하나(lx 6 ~ 11, 7 ~ 12 비움)
wall(-34, -22, 21, 24, 12.2, 1, ((0.6, 2.8, 2.0, -18),))
wall(-22, -8, 21, 24, 6.4, 2)
R("Plinth2", -8, 2, 20.5, 24.5, 1.0, 1.5)
wall(2, 6, 21, 24, 14.2, 1)
R("RuinStone", 6, 11, 21, 24, 1.0, 7)
R("RuinStone", 6, 11, 21, 24, 12, 14.2)
R("SnowCap", 5.85, 11.15, 20.85, 24.15, 14.0, 14.55)
wall(11, 16, 21, 24, 13.6, 2, ((0.5, 2.4, 1.8, 30),))
wall(16, 34, 21, 24, 3.2, 1)
# 서쪽 벽(lx -34 ~ -31), 동쪽 벽(lx 31 ~ 34 — 가운데 무너짐)
wall(-34, -31, -21, -6, 16.2, 2, ((0.4, 3, 2.2, 5),))
wall(-34, -31, -6, 6, 10.4, 1)
wall(-34, -31, 6, 21, 19.4, 2, ((0.7, 2.6, 2.0, -12),))
wall(31, 34, -21, -9, 7.2, 1, ((0.5, 2.4, 1.6, 18),))
wall(31, 34, 3, 21, 13.2, 2, ((0.3, 3, 2.4, -6),))
# 안 칸막이(lx 6 ~ 8.5)
wall(6, 8.5, -21, -10, 10.2, 1, ((0.5, 2, 1.6, 9),))
wall(6, 8.5, -10, -2, 5.2, 2)
# 돌무더기(무너진 동쪽 벽 · 북쪽 낮은 벽 · 남동 모퉁이) { lx, lz, 폭, 높이, 깊이, 돌림, 기울기 x, z }
for lx, lz, w, h, d, ry, rx, rz in ((33, -7, 4, 2.4, 3.6, 15, 0, 8), (35.5, -3, 3.2, 1.8, 3, -20, 6, 0), (32, 0, 4.4, 2.8, 3.4, 40, 0, -6),
                                    (36, 1.5, 2.6, 1.4, 2.2, 10, 0, 0), (29, -4, 2.8, 1.6, 2.6, -35, 8, 4), (16, -19, 3.4, 2, 3, 22, 0, 6),
                                    (19, -17.5, 2.4, 1.4, 2.2, -10, 0, 0), (27, 19, 3.6, 2.2, 3, 30, -6, 0), (31, 23.5, 2.8, 1.6, 2.6, 5, 0, 10)):
    R("RuinStone2" if int(lx) % 2 else "RuinStone", lx - w / 2, lx + w / 2, lz - d / 2, lz + d / 2, 1.0, 1.0 + h, ry, rx, rz)
# 그을린 나무: 쓰러진 대들보(북쪽 벽 위 → 바닥), 남은 서까래 둘(하나는 부러짐), 바닥에 누운 기둥 셋, 선 그루터기 넷
R("Char", -6.9, -5.3, -28, 12, 2.6, 4.2, 70, -6)            # 쓰러진 대들보(한 끝은 돌무더기에 걸침)
R("Char", -29.8, -28.2, -22, 20, 14.8, 16.4, 0, 6.8)          # 서까래(북쪽 벽 18 → 남쪽 벽 12.2 에 얹힘)
R("Char", -25.8, -24.2, -22, -2, 16.4, 18.0, 0, 9)            # 부러진 서까래(북쪽 벽에만 걸림)
R("Char", -26, -24.4, -1, 9, 1.0, 2.6, 0, 0, 14)
for lx, lz, ln, ry in ((-12, 6, 16, 35), (14, 2, 12, -50), (20, 12, 9, 80)):
    R("Char2" if ln > 10 else "Char", lx - 0.8, lx + 0.8, lz - ln / 2, lz + ln / 2, 1.0, 2.6, ry)
for lx, lz, h in ((-14, -1, 6.2), (14, 0, 3.0), (-14, 12, 9.4), (20, -8, 2.2)):
    R("Char", lx - 0.9, lx + 0.9, lz - 0.9, lz + 0.9, 1.0, 1.0 + h)
R("Plank", -8, 5, -16, -4, 2.4, 3.3, 0, 0, 25)               # 무너진 지붕판(칸막이에 기댐)
R("Plank", 9, 21, 4, 12, 1.0, 1.6, 18, 6, -4)                # 바닥에 떨어진 지붕판
# 화덕(서쪽 벽 안) + 부러진 굴뚝 + 풀무 · 불씨(표지 Ember — 작은 불·연기·빛)
R("Brick", -31, -22, 2, 12, 1.0, 10.2)
R("Soot", -22.05, -21.9, 5, 9, 2.0, 6.4)                    # 화덕 아가리(검게)
R("Brick", -30, -25, 4, 9, 10.2, 25.6)
R("Brick", -29.4, -26.6, 4.6, 7.4, 25.6, 27.4, 18)
R("SnowCap", -30.15, -24.85, 3.85, 9.15, 25.4, 25.9)
R("Char2", -21, -18, 10, 13.6, 1.0, 3.0, 12)
ex, ez = rot(-21.6, 7, RYAW)
MARKS.append(("Ember", rcx + ex, rg + 4.0, rcz + ez, {}))
# 모루 · 탄 작업대 · 상자
R("Iron", -17, -15, 7, 9, 1.0, 3.4)
R("Iron", -18.2, -13.8, 7.1, 8.9, 3.4, 4.6)
R("Char2", 12, 24, -18, -13, 3.6, 4.4, 0, 0, -6)
for lx, lz in ((12.6, -17.4), (23.4, -17.4), (12.6, -13.6)):
    R("Char", lx - 0.4, lx + 0.4, lz - 0.4, lz + 0.4, 1.0, 3.8)
R("Crate", 24.5, 27.5, 12.5, 15.5, 1.0, 4.0, 12)
R("Crate", 21, 23.4, 15.6, 18, 1.0, 3.4, -20)
R("Crate", 25.4, 27.4, 16.2, 18.2, 1.0, 2.6, 35, 0, 18)
for kit, lx, lz, yaw, sc, sink, tilt in (("Gear_24", 18, 10, 30, 0.8, 1.5, 70), ("Gear_24", 27, -2, -40, 0.55, 0.8, 80)):
    kx, kz = rot(lx, lz, RYAW)
    KITS.append((kit, rcx + kx, rg + 1.0 - sink, rcz + kz, yaw, sc, tilt))
# 그을음(벽 안쪽 면 · 창 둘레 — 얇은 판, 부딪힘 없음) · 눈 더미
for lx0, lx1, lz0, lz1, y0, y1 in ((-30.9, -30.75, -4, 14, 2, 14), (-14, -2, -20.9, -20.75, 4, 17), (2, 16, 20.75, 20.9, 3, 11),
                                   (8.55, 8.7, -20, -12, 2, 8)):
    R("Soot", lx0, lx1, lz0, lz1, y0, y1)
for lx0, lx1, lz0, lz1, h in ((-31, -24, -21, -15, 1.6), (-20, -9, 18, 21, 1.2), (26, 31, -21, -16, 2.0), (-31, -27, 15, 21, 2.4)):
    R("Drift", lx0, lx1, lz0, lz1, 1.0, 1.0 + h)
# 떨어진 간판 "설 공방"(남쪽 벽 밖, 문 옆에 기댐 — 표지 Sign 이 글씨를 붙인다)
sx0, sz0 = rot(-12, 25.2, RYAW)
BOXES.append(("Sign", rcx + sx0, rg + 2.4, rcz + sz0, 7, 2.6, 0.35, RYAW + 180, -16, 4))
MARKS.append(("Sign", rcx + sx0, rg + 2.4, rcz + sz0, {"Text": "설 공방", "Index": len(BOXES)}))
px_, pz_ = rot(-3, 62, RYAW)
MARKS.append(("Spot", rcx + px_, rg + 1.4, rcz + pz_, {"SpotName": "설공방 폐허", "Region": "설원", "Order": 2, "LookX": rcx, "LookZ": rcz}))

# ── 순례자의 휴식처 2/8 ──
RX, RY = 632, 1107
ry_ = top_at(RX, RY) - 0.2
rx, rz = world(RX, RY)
BOXES.append(("RestStone", rx, ry_ + 0.6, rz, 30, 1.2, 26, 8.0))
for k in range(7):  # 모닥불 돌 고리
    a = math.radians(k * 360 / 7)
    BOXES.append(("FireRock", rx + math.cos(a) * 3.2, ry_ + 1.6, rz + math.sin(a) * 3.2, 1.6, 1.2, 1.4, k * 31))
MARKS.append(("Campfire", rx, ry_ + 1.8, rz, {}))
for dx in (-9, 9):  # 차양 쉼터 기둥
    for dz in (6, 12):
        BOXES.append(("Timber", rx + dx, ry_ + 5.2, rz + dz, 0.8, 8.0, 0.8, 0.0))
BOXES.append(("Timber", rx, ry_ + 9.6, rz + 9, 20, 0.6, 9, 0.0))
BOXES.append(("SnowCap", rx, ry_ + 10.1, rz + 9, 20.6, 0.5, 9.6, 0.0))
BOXES.append(("Timber", rx - 6, ry_ + 1.8, rz - 6, 8, 1.6, 1.6, 20.0))  # 통나무 의자
BOXES.append(("Timber", rx + 6, ry_ + 1.8, rz - 5, 7, 1.6, 1.6, -15.0))
BOXES.append(("RestStone", rx + 11, ry_ + 2.4, rz - 2, 3, 3.6, 3, 0.0))  # 퀘스트 물건 받침
MARKS.append(("QuestItem", rx + 11, ry_ + 5.0, rz - 2, {"QuestItem": "전직 퀘템 2/8"}))
MARKS.append(("Spot", rx, ry_ + 1.4, rz - 22, {"SpotName": "휴식처 2/8", "Region": "설원", "Order": 3, "LookX": rx, "LookZ": rz}))

# ── 눈 나무 덩어리(손) { X0, X1, Y0, Y1, 간격 px } ── 바위 무리·마을·보스룸·구멍·바닷가를 피해서
GROVES = [
    (165, 330, 1252, 1455, 13),   # 남서 필드
    (460, 548, 948, 1058, 12),    # 북쪽 들 가운데
    (622, 722, 1180, 1290, 12),   # 북동 들 서쪽
    (760, 848, 1120, 1290, 12),   # 북동 들 동쪽
    (612, 700, 990, 1050, 12),    # 북동 들 북서
    (690, 800, 1350, 1405, 12),   # 북동 들 남쪽
    (410, 600, 1352, 1468, 14),   # 남쪽 필드
]
TREE_MIX = {"Pine_A": 5, "Pine_B": 4, "Birch_A": 2, "Oak_B": 2, "Bush_B": 1}
AVOID = [  # 그림 좌표 네모(나무 금지): 폐허·휴식처·굴 입구 셋(바위 언덕 + 도랑 — snow_tunnel_plan 출력 자리)
    (740, 795, 1040, 1092), (612, 652, 1088, 1128), (281, 305, 1312, 1358), (688, 712, 1229, 1286), (829, 853, 1189, 1246),
]


def in_rocks(x, z, r):
    for _, (a, b, c, d), lo, tp, _c in ROCKS:
        if a - r < x < b + r and c - r < z < d + r:
            return True
    return False


rng = random.Random(20261009)
tot = sum(TREE_MIX.values())
for X0, X1, Y0, Y1, sp in GROVES:
    n = 0
    nx_, ny_ = int((X1 - X0) // sp), int((Y1 - Y0) // sp)
    for i in range(nx_):
        for j in range(ny_):
            X = X0 + (i + 0.5) * sp + (rng.random() - 0.5) * sp * 0.6
            Y = Y0 + (j + 0.5) * sp + (rng.random() - 0.5) * sp * 0.6
            r = rng.random() * tot
            kind = None
            for k, w in TREE_MIX.items():
                r -= w
                if r <= 0:
                    kind = k
                    break
            kind = kind or "Pine_A"
            yaw = rng.randrange(0, 360, 15)
            sc = round(1.1 + rng.random() * 0.6, 2)
            t = top_at(X, Y)
            if t is None or any(a <= X <= b and c <= Y <= d for a, b, c, d in AVOID):
                continue
            # 이웃 칸이 바다·다른 높이면(가장자리) 빼기
            if any(top_at(X + dx, Y + dy) != t for dx, dy in ((8, 0), (-8, 0), (0, 8), (0, -8))):
                continue
            x, z = world(X, Y)
            if in_rocks(x, z, 8):
                continue
            TREES.append((kind, x, t - 0.3, z, yaw, sc))
            n += 1
    if n == 0:
        bad.append(f"나무 덩어리 {X0},{Y0} 에 한 그루도 없음")
# 큰 바위(손) { X, Y, 폭, 높이, 깊이, 돌림 }
BOULDERS = [(200, 1300, 22, 14, 18, 15), (318, 1440, 30, 18, 24, -20), (520, 1420, 26, 12, 20, 40), (585, 1380, 18, 10, 16, 5),
            (500, 1000, 24, 16, 20, 30), (660, 1240, 20, 12, 18, -35), (820, 1180, 28, 20, 22, 10), (740, 1380, 22, 14, 18, 60)]
for X, Y, w, h, d, ry in BOULDERS:
    t = top_at(X, Y)
    x, z = world(X, Y)
    if t is None or in_rocks(x, z, 2):
        bad.append(f"큰 바위 ({X},{Y}) 자리 문제(땅 {t}, 바위 무리 겹침)")
        continue
    BOXES.append(("PillarRock", x, t - 2 + h / 2, z, w, h, d, ry))
    BOXES.append(("SnowCap", x, t - 2 + h + 0.5, z, w + 0.4, 1.0, d + 0.4, ry))


if __name__ == "__main__":
    for p in bad:
        print("문제:", p)
    out = ["-- snow_field_plan.py 가 만든 자료(손으로 고치지 말 것)", "local BOXES = {"]
    out += [f'\t{{ "{g}", {x:.2f}, {y:.2f}, {z:.2f}, {sx:.2f}, {sy:.2f}, {sz:.2f}, {ry:.1f}, {rx:.1f}, {rz:.1f} }},' for g, x, y, z, sx, sy, sz, ry, rx, rz in [tuple(b) + (0.0,) * (10 - len(b)) for b in BOXES]]
    out += ["}", "local KITS = {"]
    out += [f'\t{{ "{k}", {x:.1f}, {y:.1f}, {z:.1f}, {yaw}, {sc}, {tilt} }},' for k, x, y, z, yaw, sc, tilt in KITS]
    out += ["}", "local MARKS = {"]
    for n, x, y, z, attrs in MARKS:
        a = ", ".join(f'{k} = {str(v).lower() if isinstance(v, bool) else (repr(v) if not isinstance(v, str) else chr(34) + v + chr(34))}' for k, v in attrs.items())
        out.append(f'\t{{ "{n}", {x:.1f}, {y:.1f}, {z:.1f}, {{ {a} }} }},')
    out += ["}", "local LAKE_CARVE = {"]
    out += [f"\t{{ {x0:.2f}, {x1:.2f}, {y0:.2f}, {y1:.2f}, {z0:.2f}, {z1:.2f} }}," for x0, x1, y0, y1, z0, z1 in LAKE_CARVE]
    out += ["}", "local TREES = {"]
    out += [f'\t{{ "{k}", {x:.1f}, {y:.1f}, {z:.1f}, {yaw}, {sc} }},' for k, x, y, z, yaw, sc in TREES]
    out += ["}"]
    open(os.path.join(HERE, "Snow_Field_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print(f"상자 {len(BOXES)} · 키트 {len(KITS)} · 표지 {len(MARKS)} · 나무 {len(TREES)} · 문제 {len(bad)}건")
