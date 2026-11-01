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
def dead_tree(cx, cz, base, h, ry, lean, shape, tone=None):
    """마른 나무: 줄기(기울기 lean) + 가지(BRANCHES[shape]). tone 없으면 모양 3 만 어둡게."""
    tone = tone or ("DeadWood" if shape != 3 else "DeadWood2")
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


for lx, lz, h, ry, lean, shape in DEAD:
    dead_tree(bx + lx, bz + lz, ICE if on_ice(lx, lz) else by, h, ry, lean, shape)
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
R("Char", -26, -24.4, -10, 0, 1.0, 2.6, 0, 0, 14)
for lx, lz, ln, ry in ((-12, 6, 16, 35), (14, 2, 12, -50), (20, 12, 9, 80)):
    R("Char2" if ln > 10 else "Char", lx - 0.8, lx + 0.8, lz - ln / 2, lz + ln / 2, 1.0, 2.6, ry)
for lx, lz, h in ((-14, -1, 6.2), (14, 0, 3.0), (-14, 12, 9.4), (20, -8, 2.2)):
    R("Char", lx - 0.9, lx + 0.9, lz - 0.9, lz + 0.9, 1.0, 1.0 + h)
R("Plank", -8, 5, -16, -4, 2.4, 3.3, 0, 0, 25)               # 무너진 지붕판(칸막이에 기댐)
R("Plank", 9, 21, 4, 12, 1.0, 1.6, 18, 6, -4)                # 바닥에 떨어진 지붕판
# 화덕 2판(2026-11-01 사용자 "이 화로 수정" — 1판은 반듯한 벽돌 상자 + 검은 판 위 촛불 같은 불이라 불탄 폐허답지 않았다).
# 레퍼런스: 옛 대장간 화덕 폐허(돌 화덕 받침 · 벽돌 화실 · 덮개 · 굴뚝, 불난 뒤 덮개 앞 모서리가 무너지고 굴뚝 끝이 부러짐).
# 서쪽 벽에 붙어 동쪽(+lx)을 본다. 화실 = lx -28.6 ~ -22, lz 4.2 ~ 9.8, 높이 3.6 ~ 7.4(움푹 들어간 진짜 구멍)
R("RuinStone2", -31, -20.8, 1.2, 12.8, 1.0, 3.6)                       # 화덕 받침(돌, 허리 높이)
R("Brick", -31, -22, 1.2, 4.2, 3.6, 9.6)                              # 화실 왼 벽
R("Brick", -31, -24.5, 9.8, 12.8, 3.6, 8.4)                           # 화실 오른 벽(뒤)
R("Brick", -24.5, -22, 9.8, 12.8, 3.6, 5.6)                           # 오른 벽 앞(무너져 낮음)
R("Brick", -31, -28.6, 4.2, 9.8, 3.6, 10.2)                           # 화실 뒷벽
R("Brick", -28.6, -24.5, 4.2, 9.8, 7.4, 9.8)                          # 덮개(앞쪽은 무너져 떨어짐)
R("Char", -22.7, -21.9, 3.4, 10.6, 6.6, 7.4, 0, 8)                    # 그을린 나무 인방(오른쪽으로 처짐)
R("Soot", -28.6, -28.45, 4.25, 9.75, 3.65, 10.0)                      # 화실 안 그을음(뒷벽·옆벽·덮개 밑)
R("Soot", -28.6, -22.2, 4.2, 4.35, 3.65, 9.4)
R("Soot", -28.6, -24.6, 9.65, 9.8, 3.65, 8.2)
R("Soot", -28.6, -24.5, 4.2, 9.8, 7.25, 7.4)
R("Soot", -21.98, -21.88, 1.4, 4.0, 6.0, 9.4)                         # 왼 벽 앞면 위 그을음
R("Coal", -28.2, -22.6, 4.6, 9.4, 3.6, 4.0)                           # 숯 바닥
for lx, lz, w, h, d, ry, rx, rz in ((-26.6, 5.6, 1.0, 0.7, 0.9, 20, 0, 9), (-24.8, 7.9, 1.2, 0.8, 1.0, -35, 7, 0), (-27.4, 8.6, 0.8, 0.6, 0.8, 50, 0, 0),
                                    (-23.6, 5.4, 0.9, 0.6, 1.1, 10, -8, 0), (-25.8, 7.0, 1.1, 0.9, 0.9, 70, 0, -6)):
    R("Coal2", lx - w / 2, lx + w / 2, lz - d / 2, lz + d / 2, 4.0, 4.0 + h, ry, rx, rz)      # 숯덩이
R("Brick", -31, -26.4, 3.8, 10.2, 10.2, 18.6)                         # 굴뚝(짧게 부러짐)
R("Brick", -31, -28.4, 3.8, 6.8, 18.6, 21.4)                          # 부러진 끝(높은 쪽)
R("Brick", -28.4, -26.4, 7.6, 10.2, 18.6, 19.8, 0, 5)                 # 부러진 끝(낮은 쪽)
R("Soot", -30.2, -27.2, 5.0, 9.0, 18.62, 18.7)                        # 굴뚝 구멍(검게)
R("SnowCap", -31.1, -28.3, 3.7, 6.9, 21.2, 21.7)
# 떨어진 덮개 조각·벽돌(화덕 앞 바닥)
R("Brick", -21.0, -17.6, 9.4, 12.6, 1.0, 3.2, 20, 0, -18)
for lx0, lx1, lz0, lz1, h, ry, rx, rz in ((-19.8, -17.6, 3.0, 5.2, 1.0, 25, 0, 8), (-19.4, -18.0, 6.0, 7.2, 0.7, -40, 0, 0),
                                          (-20.4, -18.8, 13.6, 15.2, 0.9, 15, 7, 0), (-16.4, -15.0, 11.0, 12.4, 0.6, 60, 0, 0)):
    R("Brick", lx0, lx1, lz0, lz1, 1.0, 1.0 + h, ry, rx, rz)
# 풀무(가죽) · 담금 통(얼어붙은 물)
R("Char2", -21.4, -18.2, 13.4, 15.6, 1.0, 1.4)
R("Leather", -21.2, -18.4, 13.6, 15.4, 1.4, 2.6)
R("Char2", -21.4, -18.2, 13.4, 15.6, 2.6, 3.0, 0, 0, -8)
R("Iron", -22.2, -21.2, 14.2, 14.8, 1.7, 2.1)
R("Char2", -20.6, -18.0, -1.8, 0.8, 1.0, 3.0, 8)
R("Ice", -20.3, -18.3, -1.5, 0.5, 2.5, 2.9, 8)
ex, ez = rot(-25.4, 7.0, RYAW)
MARKS.append(("Ember", rcx + ex, rg + 4.4, rcz + ez, {}))
cx_, cz_ = rot(-28.7, 7.0, RYAW)
MARKS.append(("ChimneySmoke", rcx + cx_, rg + 19.4, rcz + cz_, {}))
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

# ── 들판 나무(2026-11-01 사용자: "구역마다 너무 빽빽 — 설원 느낌이 더 잘 나게", 레퍼런스 여러 개) ──
# 레퍼런스: 야숨 헤브라(능선·벼랑 밑에만 침엽수, 나머지는 트인 눈밭) · 스카이림 더 페일/윈터홀드(드문드문한 눈 소나무 + 마른 나무,
# 넓은 툰드라) · 엘든 링 거인들의 산령(벼랑 가까이 서리 덮인 나무 무리, 트인 눈밭엔 흰 마른 나무) · 실제 타이가→툰드라 경계
# (바람 맞는 곳은 드물고, 바위·벼랑 그늘 우묵한 곳에만 작은 무리).
# 규칙: 대부분 트인 눈밭 · 무리는 3~7 그루를 바람 그늘(단 가장자리·바위 무리·바닷가 낮은 땅)에만 · 트인 곳엔 외딴 나무 하나 · 마른 흰 나무 흩음
#       (폐허 둘레는 그을린 마른 나무) · 마을·호수·폐허·휴식처·굴 입구 앞은 비움. 예전 간격 숲(GROVES 553 그루)은 지웠다.
# 무리 모양(2026-11-01 사용자: "배치는 마음에 드는데 3 개씩 뭉친 게 거슬린다" → 틀 반복 대신 포아송 디스크):
# 무리마다 자리·크기·돌림은 손 표(CLUMPS), 안쪽 나무 자리만 그 무리 씨앗으로 포아송 디스크(다트 던지기 — 서로 최소 거리 이상).
#   최소 거리 = 두 나무 몫의 평균, 한 그루 몫 = 3.5 + 2.6 × 배율(큰 나무일수록 자리를 넓게) × (1 + 0.7 (가운데에서 거리/반지름)²)(가장자리로 갈수록 성기게)
#   크기 계층 = 가운데 큰 나무 → 가장자리 어린 나무(배율 big → small, ±0.1), 테두리 밖(1.1 ~ 1.5 반지름) 묘목 0 ~ 2 그루
# { 테두리: 원 반지름 / 띠(길이, 폭), 그루 수(최소, 최대), 배율(가운데, 가장자리), 자작 비율, 묘목 수(최소, 최대) }
CLUMP = {
    "둘": {"r": 13, "n": (2, 3), "sc": (1.55, 1.0), "birch": 0.0, "kid": (0, 1)},
    "셋": {"r": 17, "n": (3, 4), "sc": (1.65, 0.95), "birch": 0.0, "kid": (0, 1)},
    "큰하나": {"r": 15, "n": (2, 4), "sc": (1.85, 0.8), "birch": 0.0, "kid": (0, 1)},
    "자작": {"r": 15, "n": (3, 5), "sc": (1.35, 0.95), "birch": 0.6, "kid": (0, 1)},
    "다섯": {"r": 23, "n": (4, 6), "sc": (1.75, 0.9), "birch": 0.1, "kid": (0, 2)},
    "일곱": {"r": 32, "n": (7, 10), "sc": (1.85, 0.9), "birch": 0.1, "kid": (1, 2)},
    "바람막이": {"strip": (44, 9), "n": (4, 6), "sc": (1.5, 1.05), "birch": 0.0, "kid": (0, 1)},
}


def poisson_clump(name, X, Y, ry):
    """무리 하나의 나무 [(그림 X, Y, 틀, 배율, 돌림)] — 씨앗 = 자리라서 다시 지어도 같다. 땅이 안 되는 자리는 던지기에서 뺀다."""
    spec = CLUMP[name]
    rng = random.Random(int(X * 7919 + Y * 104729 + ry))
    strip = spec.get("strip")
    R = spec.get("r") or strip[0] / 2
    big, small = spec["sc"]
    want = rng.randint(*spec["n"])
    out = []

    def room(sc, d):
        return (3.5 + 2.6 * sc) * (1 + 0.7 * (d / R) ** 2)

    def throw(lo, hi, count, scale_of, tries=400):
        for _ in range(tries):
            if count <= 0:
                return
            if strip:
                lx, lz = (rng.random() - 0.5) * strip[0] * hi, (rng.random() - 0.5) * strip[1] * hi
                if lo > 0 and abs(lx) < strip[0] * lo / 2 and abs(lz) < strip[1] * lo / 2:
                    continue
                d = abs(lx) / (strip[0] / 2) * R
            else:
                a = rng.random() * math.tau
                d = R * math.sqrt(lo * lo + rng.random() * (hi * hi - lo * lo))   # 넓이 고르게
                lx, lz = math.cos(a) * d, math.sin(a) * d
            sc = round(max(0.55, scale_of(min(d, R) / R) + (rng.random() - 0.5) * 0.2), 2)
            r = room(sc, min(d, R))
            if any(math.hypot(lx - ox, lz - oz) < (r + orr) / 2 for ox, oz, _, orr in out):
                continue
            ox_, oz_ = rot(lx, lz, ry)
            Xp, Yp = X + ox_ / SCALE, Y + oz_ / SCALE
            if not tree_ground(Xp, Yp):
                continue
            out.append((lx, lz, sc, r))
            count -= 1

    # 가운데부터: 첫 그루는 안쪽 30% 에서 가장 크게, 나머지는 무리 안, 묘목은 테두리 밖
    throw(0, 0.3, 1, lambda f: big)
    throw(0, 1.0, want - len(out), lambda f: big + (small - big) * f)
    throw(1.1, 1.5, rng.randint(*spec["kid"]), lambda f: 0.62)
    trees = []
    for k, (lx, lz, sc, _r) in enumerate(out):
        ox_, oz_ = rot(lx, lz, ry)
        kind = "Birch_A" if rng.random() < spec["birch"] else ("Pine_A" if rng.random() < 0.55 else "Pine_B")
        trees.append((X + ox_ / SCALE, Y + oz_ / SCALE, kind, sc, rng.randrange(0, 360, 5)))
    if len(out) < spec["n"][0]:
        bad.append(f"무리 {name}@{X},{Y}: 자리가 좁아 {len(out)} 그루만")
    return trees


# 무리 놓기 { 틀, 그림 X, Y, 돌림 } — 구역별(단 사이 바위 무리·단 가장자리에 걸린 자리는 가장 가까운 빈 자리로 조금 옮김)
CLUMPS = [
    # 북쪽 들(32): 마을 쪽 바람막이 두 줄(사이는 길), 북쪽 가장자리·모퉁이에만
    ("바람막이", 432, 1010, 90), ("바람막이", 432, 1062, 90), ("셋", 430, 948, 0), ("둘", 545, 960, 30), ("큰하나", 468, 1072, 15),
    # 호수 단(40) 모퉁이
    ("셋", 423, 1111, 40), ("둘", 575, 1280, 200), ("자작", 410, 1285, 0),
    # 북동 들(44): 단 가장자리·바위 그늘, 폐허와 3번 입구 사이 숲 조각 하나
    ("다섯", 640, 990, 10), ("셋", 700, 1015, 50), ("둘", 820, 1020, 0), ("큰하나", 607, 1157, 25), ("자작", 668, 1170, 70),
    ("일곱", 760, 1150, 0), ("셋", 655, 1245, 120), ("둘", 735, 1250, 300), ("다섯", 800, 1300, 40), ("큰하나", 815, 1340, 0),
    ("바람막이", 700, 1380, 10), ("셋", 760, 1420, 80), ("둘", 650, 1330, 0),
    # 남서 필드(20): 서쪽 낮은 바닷가에 타이가 조각 둘(사이가 트임), 나머지는 작은 무리
    ("일곱", 175, 1250, 0), ("일곱", 205, 1395, 40), ("다섯", 161, 1330, 80), ("셋", 251, 1238, 10), ("큰하나", 331, 1237, 60),
    ("둘", 262, 1300, 0), ("둘", 330, 1305, 180), ("자작", 390, 1350, 20), ("바람막이", 440, 1440, 0), ("다섯", 520, 1390, 30),
    ("셋", 592, 1349, 100), ("큰하나", 477, 1301, 0), ("셋", 330, 1450, 200), ("둘", 600, 1440, 0),
]
# 외딴 나무 { 그림 X, Y, 틀, 배율 }
LONE = [(418, 975, "Pine_B", 1.7), (505, 1010, "Pine_A", 1.4), (455, 1040, "Pine_A", 1.2), (560, 1060, "Pine_B", 1.5),
        (600, 1040, "Pine_A", 1.6), (850, 1080, "Pine_B", 1.4), (680, 1110, "Pine_A", 1.3), (720, 1300, "Pine_B", 1.7),
        (840, 1260, "Pine_A", 1.5), (601, 1402, "Birch_A", 1.3), (145, 1230, "Pine_B", 1.5),
        (420, 1280, "Pine_A", 1.6), (360, 1400, "Pine_B", 1.2), (560, 1460, "Pine_A", 1.4), (250, 1460, "Birch_A", 1.2),
        (460, 1380, "Pine_B", 1.5)]
# 마른 나무 { 그림 X, Y, 높이, 돌림, 기울기, 모양, 그을림 }
FIELD_DEAD = [(428, 1015, 18, 0, 3, 2, False), (520, 945, 22, 60, -4, 1, False), (420, 1110, 16, 120, 5, 3, False),
              (735, 1035, 14, 30, 6, 1, True), (800, 1050, 17, 200, -5, 3, True), (780, 1100, 12, 90, 8, 2, True), (725, 1095, 15, 150, -3, 1, True),
              (638, 1210, 20, 0, 4, 2, False), (790, 1370, 18, 45, -6, 1, False), (230, 1340, 19, 20, 5, 1, False),
              (400, 1203, 16, 80, -4, 3, False), (500, 1470, 21, 160, 6, 2, False), (560, 1300, 15, 240, -7, 1, False),
              (150, 1430, 18, 300, 3, 2, False)]
AVOID = [  # 그림 좌표 네모(나무 금지): 폐허·휴식처·굴 입구 셋(바위 언덕 + 도랑) 과 입구 앞 길·호수
    (740, 795, 1040, 1092), (612, 652, 1088, 1128), (281, 305, 1290, 1358), (688, 712, 1205, 1286), (829, 853, 1165, 1246),
    (460, 562, 1150, 1252),
]


def in_rocks(x, z, r):
    for _, (a, b, c, d), lo, tp, _c in ROCKS:
        if a - r < x < b + r and c - r < z < d + r:
            return True
    return False


def tree_ground(X, Y):
    """무리 안 다트용: 땅이 되면 True(가장자리·피할 곳·바위 무리·마을은 False — 문제로 적지 않는다)."""
    t = top_at(X, Y)
    if t is None or t >= 60 or any(a <= X <= b and c <= Y <= d for a, b, c, d in AVOID):
        return False
    if any(top_at(X + dx, Y + dy) != t for dx, dy in ((8, 0), (-8, 0), (0, 8), (0, -8))):
        return False
    x, z = world(X, Y)
    return not in_rocks(x, z, 8)


def ground_ok(X, Y, what):
    """나무 자리: 땅이 있고 가장자리(8 px 안이 다른 높이)·피할 곳·단 사이 바위가 아니어야. 아니면 문제로 적는다."""
    t = top_at(X, Y)
    x, z = world(X, Y)
    why = None
    if t is None:
        why = "땅 없음"
    elif t >= 60:
        why = "마을"
    elif any(a <= X <= b and c <= Y <= d for a, b, c, d in AVOID):
        why = "피할 곳"
    elif any(top_at(X + dx, Y + dy) != t for dx, dy in ((8, 0), (-8, 0), (0, 8), (0, -8))):
        why = "단 가장자리"
    elif in_rocks(x, z, 8):
        why = "바위 무리"
    if why:
        bad.append(f"{what} ({X:.0f},{Y:.0f}) {why}")
        return None
    return t


for name, X, Y, ry in CLUMPS:
    for Xp, Yp, kind, sc, yaw in poisson_clump(name, X, Y, ry):
        x, z = world(Xp, Yp)
        TREES.append((kind, x, top_at(Xp, Yp) - 0.3, z, yaw, sc))
for X, Y, kind, sc in LONE:
    t = ground_ok(X, Y, "외딴 나무")
    if t is not None:
        x, z = world(X, Y)
        TREES.append((kind, x, t - 0.3, z, int(X * 7 + Y) % 360, sc))
for X, Y, h, ry, lean, shape, burnt in FIELD_DEAD:
    t = ground_ok(X, Y, "마른 나무")
    if t is not None:
        x, z = world(X, Y)
        dead_tree(x, z, t - 0.2, h, ry, lean, shape, "Burnt" if burnt else None)
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
