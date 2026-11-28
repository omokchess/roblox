# -*- coding: utf-8 -*-
"""
b_inn.py — 2026-11-14. 설원 마을 3판: 여관(쉬기·저장, 발자국 40×32, 2층). 아트 부서원 1, A 양식(짙은 통나무).
2026-11-18 아트 2팀: 구멍 막이(박공 꼭대기 띠·처마 막이판) · 김 하나(굴뚝 갓 위) · 내부 다시(벽난로·바·식당·2층 방 — lib_int2 소품).
2026-11-24 2팀 2차(비평 1차): 엇갈린 널 마루 · 계단(곧은 측판·깔개·놋쇠 누름대) + 계단 밑 판 벽 열쇠판·벽 등·큰 그림 · 안락의자를 아가리 양옆으로 ·
  바 병(짙은 녹·갈·호박, 이름표 없음)·꼭지 통·쌓은 잔 · 2층 옆벽 꾸밈 · 스키 한 벌(휜 코·폴).

레퍼런스(회사/설원마을_레퍼런스.md I·C·내부 2팀 IN): 랑엔 "히르셴" 여관(I1 — 두꺼운 지붕 눈·박공 발코니(기둥 위 보 → 바닥 → 난간은 기둥 사이)·덧창 줄),
베르나우 "뢰슬레"(I2 — 길게 누운 2층 몸 + 목조 발코니), 몬테로사 호텔(I3 — 규칙적인 창 줄), 시모니 산장(I4 — 문 옆 표지판·바깥 벤치),
뢰로스 2층 통나무집(C2 — 짙은 갈색 통나무 + 회색 밑단, 성긴 창). 내부: 알프스 여관 '슈투베'(돌 벽난로·널 마루·판넬 카운터·통 받침).
멀리서 구별: 마을에서 가장 큰 2층 앞 박공 + 앞 전체 2층 발코니(기둥 넷이 땅에서 지붕 앞 트러스까지) + 오른 옆 굵은 돌 굴뚝.

배치(블렌더, 앞 = -y, 1층 바닥 FZ = 2(널 마루 윗면 FL = 2.08), 2층 바닥 Z2F = 14.4, 천장 1층 11 · 2층 10):
  몸 벽 가운데 선 x ±17.4 · y -11.5..11.6 → 안 33.6 × 21.9. 앞 마루(y -16..-12.1, 지붕 밑) + 계단 폭 14.
  1층: 정문 x ±5.2 → 문에 들어서면 오른쪽 벽난로(불·주전자·엇걸린 스키) + 날개 안락의자 둘, 왼쪽 판넬 바 카운터(맥주 꼭지·손님 장부·종),
     카운터 뒤 장식장(병·잔·구리 차 단지·벽 등) + 왼 벽 누운 통 셋(꼭지), 오른 앞 긴 식탁 + 걸상, 가운데 둥근 탁자 + 의자 셋 + 샹들리에.
     카운터 x -16..-6 · y -0.25..1.75, NPC (-11, 2.45), 카운터 앞 빈 바닥 x -16..-6 · y -10.9..-0.4(비움) · 뒷벽 따라 나무 계단.
     2층 바닥 짜임: 큰 보(x ±6, y 방향) + 계단 앞 받을보(y 2.5, x 방향) ← 1층 기둥 둘(±6, 2.5) · 장선 · 마루
  2층: 계단참(옷장·창 밑 걸상) → 왼 방(빨간 담요 침대·세면대·의자) · 오른 방(파란 담요 침대·옷장·굴뚝 가슴 작은 벽난로) ·
     뒤 오른 구석(셋째 침대 · 머리맡 탁자) = 쉬는 자리 셋 · 가운데 방 = 발코니 문(책장·책상) · 계단 구멍 둘레 난간(기둥 사이)
  발코니: 앞 기둥 넷(x ±17.5, ±7 · y -15.5, 땅 → 지붕 앞 트러스) · 2층 높이 보 → 장선 → 마루 → 난간은 기둥 사이
"""
import math

import lib as K
import lib_a as A
import lib_int1 as P
import lib_int2 as N
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, DOOR_W, DOOR_H, WIN_SILL, bx, cbox, NPC, CLEAR

I = K.I

NAME = "Sn3_Inn"
PREFIX = "Sn3Inn"
VARIANT = "A"

WX, YF, YB = 17.4, -11.5, 11.6
T = LOG
HALF = WX + T / 2                          # 18.0
XI, YFI, YBI = WX - T / 2, YF + T / 2, YB - T / 2       # 16.8 · -10.9 · 11.0
Z1C = FZ + CEIL                            # 1층 천장(보 밑) 13
Z2F = Z1C + 1.4                            # 2층 바닥 14.4
CEIL2 = 10.0
Z_PLATE = Z2F + CEIL2 + 0.9                # 25.3
PORCH_Y, TRUSS_Y = -16.0, -15.5
POST_XS = (-17.5, -7.0, 7.0, 17.5)
ST_Y0, ST_Y1 = 3.0, YBI                    # 계단 폭(뒷벽에 붙음)
ST_BOT, ST_TOP = 13.3, -6.2                # 아랫단 앞 x · 윗단 끝 x
HDR_Y = 2.5                                # 계단 앞 받을보 가운데 y
STACK = (16.4, 19.4, -5.8, -2.2)           # 굴뚝(오른 벽을 뚫고 밖으로 2.0)
HEARTH = (13.2, XI, -7.6, -0.4)            # 벽난로 x0 x1 y0 y1
COUNTER = (-16.0, -6.0, -0.25, 1.75)
REST = [(-12.5, -6.2), (12.5, -6.2)]     # 쉬는 자리(침대 발치, 2층 바닥 위)
FL = FZ + 0.08                             # 1층 널 마루 윗면

# holes.py: 일부러 트인 자리 — 앞 마루·2층 발코니와 그 위 열린 트러스 박공(지붕 밑이지만 바깥). 몸 안(박공벽 안쪽)은 다 막는다
OPEN_ZONES = [(-19.0, 19.0, -19.0, YF - T / 2 - 0.05, 0.0, 60.0, "앞 마루·발코니와 그 위 지붕 밑(열린 트러스 박공 — 알프스 샬레 발코니, I1)")]


def shell(g, R):
    S = A.sides(-WX, WX, YF, YB)
    w1, w2 = FZ + WIN_SILL, Z2F + WIN_SILL
    holes = {"f": [(-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H), A.hole(-14.0, w1), A.hole(14.0, w1),
                   (-DOOR_W / 2, DOOR_W / 2, Z2F, Z2F + DOOR_H), A.hole(-12.0, w2), A.hole(12.0, w2)],
             "b": [A.hole(-12.0, w1), A.hole(-12.0, w2), A.hole(14.75, w2)],
             "l": [A.hole(-6.0, w1), A.hole(0.0, w1), A.hole(-6.0, w2), A.hole(7.0, w2)],
             "r": [A.hole(-9.4, w1), A.hole(6.0, w1), A.hole(-8.6, w2), A.hole(6.0, w2), (STACK[2], STACK[3], FZ, 99.0)]}
    A.log_box(g, -WX, WX, YF, YB, FZ, Z_PLATE, holes)
    for side, lst in holes.items():
        for a, b, za, zb in lst:
            if zb - za == K.WIN_H and b - a == K.WIN_W:
                A.win(g, S, side, (a + b) / 2, za, shutters=side != "f")
    top = lambda m: R.zb(m) - 0.05      # noqa: E731
    gz = Z_PLATE + 2.0
    K.gable_logs(g, "x", YF, HALF, Z_PLATE, top, holes=[(-1.5, 1.5, gz, gz + 4.0)])
    K.window(g, "x", YF, 0.0, gz, 3.0, 4.0, face=-1)
    K.gable_logs(g, "x", YB, HALF, Z_PLATE, top)
    # (2팀) 박공 꼭대기 띠(통나무 켜 계단 세모 틈 + 서까래 높이 틈 — 공용 gable_logs 의 틈) · 처마 막이판(서까래 사이)
    for c in (YF, YB):
        N.gable_seal(g, "x", c, R)
    N.eave_block(g, R, YF, YB)
    K.door_open(g, "x", YF, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=170.0)
    K.door_open(g, "x", YF, 0.0, DOOR_W, DOOR_H, Z2F, face=-1, open_deg=170.0)


def floor2(g):
    """2층 바닥 짜임: 1층 기둥 둘 → 큰 보(x ±6, y 방향 — 앞벽에서 받을보까지) · 받을보(y 2.5, 벽에서 벽) · 계단 구멍 테 보 → 장선 → 마루"""
    zg0, zg1 = Z1C, Z1C + 0.8                  # 보 13.0..13.8
    for x in (-6.0, 6.0):
        K.post(g, x, HDR_Y, FZ, zg0, s=1.0)
        bx(g, "DarkLog", x - 0.5, x + 0.5, YFI - 0.6, HDR_Y + 0.5, zg0, zg1)                # 큰 보(끝은 앞벽에 묻힘)
        K.brace(g, "y", x, HDR_Y - 0.5, zg0 - 2.0, HDR_Y - 2.5, zg0, s=0.45)                # 까치발
    bx(g, "DarkLog", -XI - 0.6, XI + 0.6, HDR_Y - 0.5, HDR_Y + 0.5, zg0, zg1)               # 받을보(끝은 옆벽에 묻힘)
    for x in (ST_TOP, ST_BOT):                                                              # 계단 구멍 테 보(받을보 → 뒷벽)
        bx(g, "DarkLog", x - 0.4, x + 0.4, HDR_Y + 0.5, YBI + 0.6, zg0 + 0.2, zg1)
    # 장선(x 방향, 큰 보 사이·벽 사이) — 앞쪽 큰 칸
    for k in range(9):
        y = YFI + 0.8 + k * (HDR_Y - 0.5 - YFI - 1.6) / 8
        bx(g, "Timber", -XI, XI, y - 0.3, y + 0.3, zg0 + 0.3, zg1)
    # 뒤 칸(계단참·뒤 오른 구석)은 y 방향 장선
    for x0, x1 in ((-XI, ST_TOP - 0.4), (ST_BOT + 0.4, XI)):
        n = max(1, int((x1 - x0) / 2.0))
        for i in range(n + 1):
            x = x0 + 0.4 + (x1 - x0 - 0.8) * i / n
            bx(g, "Timber", x - 0.3, x + 0.3, HDR_Y + 0.5, YBI, zg0 + 0.3, zg1)
    # 마루(0.6) — 계단 구멍만 비움 · (2팀) 위 널(두 색, 줄눈)
    bx(g, "Wood", -XI, XI, YFI, HDR_Y + 0.5, zg1, Z2F)
    bx(g, "Wood", -XI, ST_TOP, HDR_Y + 0.5, YBI, zg1, Z2F)
    bx(g, "Wood", ST_BOT, XI, HDR_Y + 0.5, YBI, zg1, Z2F)
    N.plank_floor(g, -XI, XI, YFI, HDR_Y + 0.45, Z2F, t=0.06)
    N.plank_floor(g, -XI, ST_TOP - 0.05, HDR_Y + 0.55, YBI, Z2F, t=0.06, along="y")
    N.plank_floor(g, ST_BOT + 0.45, XI, HDR_Y + 0.55, YBI, Z2F, t=0.06, along="y")
    cbox(-XI, XI, YFI, HDR_Y + 0.5, zg0, Z2F)
    cbox(-XI, ST_TOP, HDR_Y + 0.5, YBI, zg0, Z2F)
    cbox(ST_BOT, XI, HDR_Y + 0.5, YBI, zg0, Z2F)
    # 계단 구멍 둘레 난간(기둥 사이에만) — 기둥은 마루 위
    ry = HDR_Y + 0.5 + 0.3
    xs = (ST_TOP + 0.3, 0.5, 6.5, ST_BOT - 0.3)
    for x in xs:
        bx(g, "DarkLog", x - 0.35, x + 0.35, ry - 0.35, ry + 0.35, Z2F, Z2F + 3.6)
        bx(g, "Wood", x - 0.45, x + 0.45, ry - 0.45, ry + 0.45, Z2F + 3.6, Z2F + 3.85)          # (2팀) 기둥 갓
    for a, b in zip(xs, xs[1:]):
        A.rail_between(g, "x", ry, a + 0.35, b - 0.35, Z2F, h=3.4)
    xr = ST_BOT - 0.3
    bx(g, "DarkLog", xr - 0.35, xr + 0.35, YBI - 0.7, YBI, Z2F, Z2F + 3.6)
    A.rail_between(g, "y", xr, ry + 0.35, YBI - 0.7, Z2F, h=3.4)


def hearth(g):
    """오른 벽 돌 벽난로(2팀 2026-11-18 다시 지음 — 문에서 오른쪽으로 보이는 첫 초점):
    올린 깔돌 · 켜 쌓은 돌 문설주(줄눈이 보이게) · 그을린 화실 · 장작불 + 쇠 받침 둘 · 쇠 팔에 건 무쇠 주전자 ·
    굵은 통나무 인방(쇠 띠 셋) · 선반(까치발) + 촛대·잔·시계 · 굴뚝 가슴 위 엇걸린 스키 · 2층 방 작은 벽난로(같은 굴뚝)"""
    x0, x1, y0, y1 = HEARTH
    ym = (y0 + y1) / 2
    zf = FZ + 0.35                                                              # 화실 바닥(깔돌 윗면)
    bx(g, "StoneTrim", 12.3, x1, y0 + 0.5, y1 - 0.5, FZ, zf)                    # 앞 깔돌(올린 단)
    cbox(12.3, x1, y0 + 0.5, y1 - 0.5, FZ, zf)
    oy0, oy1, zo = ym - 2.2, ym + 2.2, zf + 4.2                                  # 아가리
    for a, b in ((y0, oy0), (oy1, y1)):                                          # 문설주: 켜마다 돌(내밈 번갈아) + 속 모르타르 줄눈
        bx(g, "StoneTrim", x0 + 0.08, x1, a + 0.06, b - 0.06, FZ, zo)
        for k in range(5):
            za, zb = FZ + k * (zo - FZ) / 5 + 0.05, FZ + (k + 1) * (zo - FZ) / 5 - 0.05
            st = 0.12 if k % 2 else 0.0
            bx(g, "Stone", x0 - st, x1 - 0.2, a - (0.0 if k % 2 else 0.06), b + (0.06 if k % 2 else 0.0), za, zb)
        cbox(x0, x1, a, b, FZ, zo)
    bx(g, "Soot", 15.4, x1, oy0, oy1, zf, zo)                                    # 화실 뒤·옆·위 그을음
    for a, b in ((oy0, oy0 + 0.1), (oy1 - 0.1, oy1)):
        bx(g, "Soot", 14.0, 15.4, a, b, zf, zo - 0.1)
    bx(g, "Soot", 13.6, 15.4, oy0, oy1, zo - 0.12, zo)
    cbox(15.4, x1, oy0, oy1, zf, zo)
    I.fire_logs(g, 14.5, ym, zf, 3.0, 1.3, axis="y", size=1.7)
    g["LampPt"].box(13.9, ym, zf + 1.9, 0.3, 0.3, 0.3)
    for dy in (-1.3, 1.3):                                                      # 쇠 받침(장작 받침 개) 둘 — 놋쇠 공 머리
        bx(g, "Iron", 13.55, 15.2, ym + dy - 0.12, ym + dy + 0.12, zf, zf + 0.35)
        bx(g, "Iron", 13.45, 13.75, ym + dy - 0.15, ym + dy + 0.15, zf, zf + 1.3)
        g["Brass"].cyl(13.6, ym + dy, zf + 1.3, 0.24, 0.16, 0.3, seg=8)
    bx(g, "Iron", 14.0, 14.3, oy0 + 0.1, ym - 0.1, zf + 3.25, zf + 3.5)         # 주전자 팔 → 갈고리 → 무쇠 주전자
    bx(g, "Iron", 14.07, 14.23, ym - 0.25, ym - 0.1, zf + 2.35, zf + 3.25)
    N.kettle(g, 14.15, ym - 0.2, zf + 1.2, s=1.1)
    bx(g, "DarkLog", x0 - 0.2, x1, y0 - 0.2, y1 + 0.2, zo, zo + 1.0)            # 인방(굵은 통나무 + 쇠 띠 셋·못 머리)
    for yy in (y0 + 0.6, ym, y1 - 0.6):
        bx(g, "Iron", x0 - 0.26, x0 + 0.6, yy - 0.18, yy + 0.18, zo - 0.04, zo + 1.04)
        g["Brass"].box(x0 - 0.28, yy, zo + 0.5, 0.08, 0.16, 0.16)
    cbox(x0 - 0.2, x1, y0 - 0.2, y1 + 0.2, zo, zo + 1.0)
    zs = zo + 1.0                                                                # 선반 + 까치발 · 촛대 둘 · 백랍 잔 셋 · 작은 시계
    bx(g, "Wood", x0 - 0.75, x1, y0 - 0.5, y1 + 0.5, zs, zs + 0.32)
    for yy in (y0 - 0.1, y1 + 0.1):
        g["DarkLog"].obox(x0 - 0.35, yy, zs - 0.45, 0.3, 0.3, 1.0, ry=0.62)
        N.candle(g, x0 - 0.3, yy, zs + 0.32, h=0.75)
    for yy in (ym - 1.6, ym - 1.0, ym + 1.4):
        N.mug(g, x0 - 0.3, yy, zs + 0.32, body="Steel", band="Iron", beer=False)
    g["Wood"].box(x0 - 0.15, ym + 0.2, zs + 0.32 + 0.55, 0.7, 1.1, 1.1)
    g["Brass"].hcyl(x0 - 0.5, ym + 0.2, zs + 0.32 + 0.62, 0.47, 0.04, axis="x", seg=12)
    g["Dial"].hcyl(x0 - 0.54, ym + 0.2, zs + 0.32 + 0.62, 0.4, 0.06, axis="x", seg=12)
    bx(g, "StoneTrim", 13.8, x1, y0 + 0.7, y1 - 0.7, zs + 0.32, Z1C)            # 굴뚝 가슴(1층): 모르타르 몸 + 켜 쌓은 돌(앞·옆)
    N.stone_face(g, "y", 13.8, -1, y0 + 0.7, y1 - 0.7, zs + 0.32, Z1C, seed=1)
    N.stone_face(g, "x", y0 + 0.7, -1, 13.95, x1, zs + 0.32, Z1C, seed=4)
    N.stone_face(g, "x", y1 - 0.7, 1, 13.95, x1, zs + 0.32, Z1C, seed=6)
    cbox(13.8, x1, y0 + 0.7, y1 - 0.7, zs, Z1C)
    N.put(g, 13.72, ym, zs + 3.6, 0.0, N.ski_pair, 6.2)                          # 엇걸린 스키 한 벌 + 폴 둘(비평 1차: 휜 코·바인딩·폴)
    # 2층: 같은 굴뚝 가슴에 작은 벽난로(2층 오른 방)
    bx(g, "StoneTrim", 14.0, x1, y0 + 0.9, ym - 1.1, Z2F, Z_PLATE - 0.9)
    bx(g, "StoneTrim", 14.0, x1, ym + 1.1, y1 - 0.9, Z2F, Z_PLATE - 0.9)
    bx(g, "StoneTrim", 14.0, x1, ym - 1.1, ym + 1.1, Z2F + 2.9, Z_PLATE - 0.9)
    for a, b, sd in ((y0 + 0.9, ym - 1.1, 2), (ym + 1.1, y1 - 0.9, 5)):
        N.stone_face(g, "y", 14.0, -1, a, b, Z2F + 0.25, Z2F + 2.9, seed=sd)
    N.stone_face(g, "y", 14.0, -1, y0 + 0.9, y1 - 0.9, Z2F + 3.5, Z_PLATE - 0.9, seed=3)
    N.stone_face(g, "x", y0 + 0.9, -1, 14.15, x1, Z2F + 0.25, Z_PLATE - 0.9, seed=7)
    N.stone_face(g, "x", y1 - 0.9, 1, 14.15, x1, Z2F + 0.25, Z_PLATE - 0.9, seed=0)
    bx(g, "Soot", 15.2, x1, ym - 1.1, ym + 1.1, Z2F, Z2F + 2.9)
    bx(g, "StoneTrim", 13.5, x1, ym - 1.9, ym + 1.9, Z2F, Z2F + 0.25)
    bx(g, "DarkLog", 13.8, x1, ym - 1.5, ym + 1.5, Z2F + 2.9, Z2F + 3.5)
    I.fire_logs(g, 14.6, ym, Z2F + 0.25, 1.6, 0.9, axis="y", size=0.9)
    cbox(14.0, x1, y0 + 0.9, y1 - 0.9, Z2F, Z_PLATE - 0.9)
    # 옆: 장작 더미(앞 오른 구석, 끝이 방을 봄) · 불 도구 걸이
    N.put(g, 15.35, -9.55, FL, -math.pi / 2, N.log_pile, 2.6, 2.0, 3)
    cbox(14.35, 16.35, -10.85, -8.25, FZ, FL + 2.4)
    tx, ty = 12.9, y0 - 0.7
    g["Iron"].cyl(tx, ty, FL, 0.4, 0.3, 0.15, seg=8)
    g["Iron"].cyl(tx, ty, FL + 0.15, 0.1, 0.1, 3.0, seg=6)
    g["Brass"].cyl(tx, ty, FL + 3.1, 0.18, 0.12, 0.25, seg=8)
    for dy, ang in ((-0.22, 0.12), (0.22, -0.12)):
        g["Iron"].obox(tx, ty + dy, FL + 1.6, 0.12, 0.12, 2.8, rx=ang)
        g["Brass"].obox(tx, ty + dy * 1.6, FL + 3.0, 0.18, 0.18, 0.4, rx=ang)


def bar(g):
    """바(접수 겸 선술집): 판넬 앞판 카운터 · 놋쇠 발걸이 · 맥주 꼭지 · 손님 장부(펼침, 깃펜·잉크 — 저장하는 자리) · 종 ·
    뒤 장식장(아래 문짝 넷 · 위 열린 선반 · 병·잔 · 구리 차 단지 · 벽 등 둘) · 왼 벽 누운 통 셋(꼭지) · 뒤 광(상자·자루)"""
    x0, x1, y0, y1 = COUNTER
    zt = FZ + K.COUNTER_H
    bx(g, "Timber", x0 + 0.15, x1 - 0.15, y0 + 0.3, y1 - 0.05, FZ, zt - 0.35)
    n = 6
    for i in range(n + 1):                                                       # 앞판: 기둥 일곱 · 들인 판넬
        x = x0 + 0.15 + (x1 - x0 - 0.3) * i / n
        bx(g, "DarkLog", x - 0.18, x + 0.18, y0 + 0.12, y0 + 0.32, FZ + 0.6, zt - 0.85)
        if i < n:
            xa, xb = x + 0.18, x0 + 0.15 + (x1 - x0 - 0.3) * (i + 1) / n - 0.18
            bx(g, "Wood", xa + 0.15, xb - 0.15, y0 + 0.2, y0 + 0.3, FZ + 0.9, zt - 1.15)
    bx(g, "DarkLog", x0 + 0.15, x1 - 0.15, y0 + 0.08, y0 + 0.31, FZ, FZ + 0.6)
    bx(g, "DarkLog", x0 + 0.15, x1 - 0.15, y0 + 0.1, y0 + 0.31, zt - 0.85, zt - 0.35)
    bx(g, "Wood", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.1, zt - 0.35, zt)
    bx(g, "Brass", x0 - 0.17, x1 + 0.17, y0 - 0.19, y0 - 0.11, zt - 0.3, zt - 0.05)
    for x in (x0 + 0.6, (x0 + x1) / 2, x1 - 0.6):                               # 발걸이(놋쇠 관 + 받침)
        bx(g, "Brass", x - 0.08, x + 0.08, y0 - 0.45, y0 + 0.1, FZ + 0.4, FZ + 0.55)
    g["Brass"].hcyl((x0 + x1) / 2, y0 - 0.45, FZ + 0.47, 0.12, x1 - x0 - 0.8, axis="x", seg=8)
    cbox(x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.1, FZ, zt)
    K.SVC.beer_tower(g, -14.2, 1.0, zt)
    for x, y in ((-12.9, 0.4), (-12.3, 0.8)):
        N.mug(g, x, y, zt)
    N.book(g, -10.2, 0.55, zt, w=1.0, d=1.4, cover="Leather", open_=True)        # 손님 장부(저장)
    g["DarkStone"].cyl(-9.0, 0.3, zt, 0.2, 0.17, 0.32, seg=8)                   # 잉크병
    g["Canvas"].obox(-8.95, 0.32, zt + 0.7, 0.08, 0.3, 1.0, rx=0.35)             # 깃펜(굵게)
    g["Brass"].cyl(-7.4, 0.6, zt, 0.4, 0.34, 0.1, seg=10)                       # 손님 부르는 종
    g["Brass"].cyl(-7.4, 0.6, zt + 0.1, 0.3, 0.12, 0.36, seg=10)
    g["Brass"].cyl(-7.4, 0.6, zt + 0.46, 0.06, 0.06, 0.16, seg=6)
    N.candle(g, -8.2, 1.3, zt, h=0.6)
    NPC(-11.0, 2.45, FZ, 0.0)
    # 뒤 장식장(앞 = -y)
    cx0, cx1, cy0, cy1 = -14.2, -6.8, 3.2, 4.6
    bx(g, "Timber", cx0 + 0.1, cx1 - 0.1, cy0 + 0.3, cy1, FZ, FZ + 3.0)
    for i in range(4):
        xa = cx0 + 0.3 + i * (cx1 - cx0 - 0.6) / 4
        xb = xa + (cx1 - cx0 - 0.6) / 4
        bx(g, "DarkLog", xa + 0.06, xb - 0.06, cy0 + 0.16, cy0 + 0.3, FZ + 0.35, FZ + 2.75)
        bx(g, "Wood", xa + 0.3, xb - 0.3, cy0 + 0.08, cy0 + 0.16, FZ + 0.65, FZ + 2.45)
        g["Brass"].box((xa + xb) / 2 + (0.5 if i % 2 == 0 else -0.5), cy0 + 0.02, FZ + 1.6, 0.18, 0.12, 0.3)
    bx(g, "Wood", cx0, cx1, cy0 - 0.05, cy1, FZ + 3.0, FZ + 3.28)
    bx(g, "Timber", cx0 + 0.3, cx1 - 0.3, cy1 - 0.2, cy1, FZ + 3.28, FZ + 8.6)
    for x in (cx0 + 0.22, (cx0 + cx1) / 2, cx1 - 0.22):
        bx(g, "DarkLog", x - 0.22, x + 0.22, cy0 + 0.2, cy1, FZ + 3.28, FZ + 8.6)
    for z in (FZ + 4.9, FZ + 6.5):
        bx(g, "Wood", cx0 + 0.44, cx1 - 0.44, cy0 + 0.35, cy1 - 0.2, z - 0.18, z)
    bx(g, "DarkLog", cx0 - 0.15, cx1 + 0.15, cy0 + 0.05, cy1, FZ + 8.6, FZ + 9.1)
    bx(g, "Brass", cx0 - 0.17, cx1 + 0.17, cy0 + 0.0, cy0 + 0.1, FZ + 8.68, FZ + 8.82)
    cbox(cx0 - 0.15, cx1 + 0.15, cy0, cy1, FZ, FZ + 9.1)
    liq = ("Needle", "Leather", "SignGold", "Needle", "Bark", "SignGold", "Leather")      # 짙은 녹색·갈색·호박색 술병(이름표 없음)
    k = 0
    for z, xs in ((FZ + 4.9, (-13.5, -12.8, -12.1, -9.6, -8.9, -8.2, -7.5)),
                  (FZ + 6.5, (-13.5, -12.9, -12.2, -11.5, -9.5, -8.8, -8.1, -7.5))):
        for x in xs:
            N.bottle(g, x, 4.05, z, liq[k % len(liq)], r=0.26, h=1.05 + 0.3 * (k % 3 == 0), kind=1 if k % 5 == 4 else 0, label=None)
            k += 1
    for x in (-11.2, -10.4):                                                     # 가운데 칸 맥주잔
        N.mug(g, x, 4.0, FZ + 4.9, beer=False)
    for x in (-13.3, -7.7):                                                      # 첫 칸: 꼭지 달린 작은 통 둘(받침 위)
        N.put(g, x, 3.95, FZ + 3.28, 0.0, N.cradle, 1.2, 0.9, 0.3)
        N.put(g, x, 3.95, FZ + 3.28 + N.cradle_lift(0.55, 0.9, 0.3), 0.0, N.barrel_lying, 0.55, 1.2)
    for row, xs in enumerate(((-12.2, -11.6, -11.0), (-11.9, -11.3), (-11.6,))):      # 쌓은 잔(셋·둘·하나)
        for x in xs:
            N.mug(g, x, 3.9, FZ + 3.28 + row * 0.72, beer=False)
    g["Copper"].cyl(-10.5, 3.95, FZ + 3.28, 0.55, 0.62, 1.2, seg=12)           # 구리 차 단지(장식장 위)
    g["Brass"].cyl(-10.5, 3.95, FZ + 4.48, 0.62, 0.3, 0.35, seg=12)
    g["Brass"].cyl(-10.5, 3.95, FZ + 4.83, 0.12, 0.18, 0.06, seg=6)
    g["Brass"].hcyl(-10.5, 3.3, FZ + 3.63, 0.09, 0.4, axis="y", seg=6)
    for sx in (-1, 1):
        g["Brass"].obox(-10.5 + sx * 0.66, 3.95, FZ + 4.18, 0.12, 0.12, 0.6, ry=sx * 0.4)
    for x in (cx0 + 0.22, cx1 - 0.22):                                          # 벽 등 둘(장식장 기둥 앞)
        N.put(g, x, cy0 + 0.18, FZ + 7.2, 0.0, N.sconce)
    # 왼 벽 누운 통 셋(받침) + 위 둘 — 꼭지가 방(+x)을 본다
    lift = N.cradle_lift(1.0, 1.1)
    for y in (5.4, 7.6, 9.8):
        N.put(g, -15.5, y, FL, math.pi / 2, N.cradle, 2.2, 1.1)
        N.put(g, -15.5, y, FL + lift, math.pi / 2, N.barrel_lying, 1.0, 2.4)
        cbox(-16.8, -14.2, y - 1.05, y + 1.05, FZ, FL + lift + 2.0)
    zc2 = lift + 1.0 + math.sqrt(1.85 ** 2 - 1.1 ** 2) - 0.85                     # 위 줄 통 밑(아래 두 통 사이 골에 얹힘)
    for y in (6.5, 8.7):
        N.put(g, -15.6, y, FL + zc2, math.pi / 2, N.barrel_lying, 0.85, 2.1, False)
    # 뒤 광(장식장 뒤): 상자·자루
    N.put(g, -12.4, 9.7, FL, 0.0, N.crate, 2.3, 2.0, 1.9)
    N.put(g, -12.3, 9.7, FL + 1.95, 0.25, N.crate, 1.8, 1.6, 1.4)
    N.put(g, -9.4, 9.9, FL, 0.1, N.crate, 2.2, 1.8, 2.0)
    for x, y, r in ((-8.0, 7.8, 0.2), (-9.3, 7.4, -0.3)):
        N.put(g, x, y, FL, r, N.sack, 1.0)
    cbox(-13.6, -8.2, 8.6, 10.9, FZ, FL + 3.4)


def stair_nook(g):
    """계단 옆면(문에서 정면으로 보이는 벽, y 3.0): 계단 밑 세로 판 벽(위는 곧은 측판이 덮음) · 방 열쇠판(놋쇠 열쇠) + 양옆 벽 등 둘 ·
    큰 설산 그림 + 그림 등 — 문에 들어서면 정면 가운데 따뜻한 초점(비평 1차 4)"""
    n = 13
    rs, d = (Z2F - FZ) / n, (ST_TOP - ST_BOT) / n
    xg0, zg0 = ST_BOT + 2 * d, FZ + 3 * rs
    zl = lambda x: zg0 + (x - xg0) * rs / d             # noqa: E731  디딤판 앞 끝 선(측판과 같음)
    N.board_wall(g, "x", ST_Y0, -1, ST_TOP + 0.2, ST_BOT, FL, lambda x: zl(x) - 1.2)
    yf = ST_Y0 - 0.22
    N.put(g, 1.6, yf, FZ + 3.0, 0.0, N.key_board, 3.0, 2.0)
    for x in (-0.6, 3.8):
        N.put(g, x, yf, FZ + 4.1, 0.0, N.sconce)
    N.put(g, -3.2, yf, FZ + 4.4, 0.0, N.painting, 4.5, 2.6)
    N.put(g, -3.2, yf, FZ + 7.0, 0.0, N.picture_lamp, 2.4)


def hall(g):
    """식당(오른쪽): 앞 벽 쪽 긴 식탁 + 걸상 둘 · 가운데 둥근 탁자 + 의자 셋 + 샹들리에 · 벽난로 앞 날개 안락의자 둘 + 깔개 ·
    탁자 위 잔·접시·촛대 · 왼 벽 외투 걸이(망토·모자·눈신) · 앞 벽 알림판 · 등"""
    N.put(g, 7.6, -8.4, FL, 0.0, N.table, 4.2, 1.9, 2.8)
    cbox(5.5, 9.7, -9.35, -7.45, FZ, FL + 2.8)
    for y in (-10.15, -6.65):
        N.put(g, 7.6, y, FL, 0.0, N.bench, 3.8)
        cbox(5.7, 9.5, y - 0.65, y + 0.65, FZ, FL + 1.75)
    for x, y in ((6.4, -8.7), (8.2, -8.0), (9.0, -8.9)):
        N.mug(g, x, y, FL + 2.8)
    for x, food in ((7.2, "Wood"), (8.6, None)):
        N.plate(g, x, -8.5, FL + 2.8, food=food)
    N.candle(g, 7.7, -8.0, FL + 2.8, h=0.7)
    tx, ty = 8.3, 0.0                                                            # 둥근 탁자 + 의자 둘(불 보는 선 y -6..-2 밖)
    N.put(g, tx, ty, FL, 0.0, N.round_table, 1.6)
    cbox(tx - 1.6, tx + 1.6, ty - 1.6, ty + 1.6, FZ, FL + 2.8)
    for (x, y, rz) in ((tx - 1.7, ty - 2.4, 0.3), (tx + 1.0, ty - 2.5, -0.2)):     # 의자 둘 다 앞(긴 식탁 쪽 틈 2.8 — 3~9 틈 금지)
        N.put(g, x, y, FL, rz, N.chair, cushion="Banner")
        N.coll(x, y, FL, rz, -0.9, 0.9, -0.85, 0.85, -0.08, 1.95)
    N.mug(g, tx - 0.6, ty + 0.3, FL + 2.8)
    N.plate(g, tx + 0.4, ty - 0.4, FL + 2.8, food="Wood")
    P.chandelier(g, tx, ty, Z1C + 0.8, FZ + 8.6)                                  # 사슬이 2층 마루 판까지(장선 사이)
    N.put(g, 11.0, -4.0, FL, 0.0, N.rug, 3.0, 6.6, "Banner", "SignGold", "Felt")   # 벽난로 앞 깔개(아가리 앞은 비움)
    for y, rz in ((-7.4, math.pi), (-0.5, 0.0)):                                  # 안락의자 둘: 아가리 양옆, 서로 마주 봄, 등 낮게
        N.put(g, 11.3, y, FL, rz, N.armchair, "Leather", "DarkLog", "Brass", 3.0)
        N.coll(11.3, y, FL, rz, -1.3, 1.3, -1.2, 1.2, -0.08, 2.4)
    # 왼 벽 외투 걸이(앞 구석): 걸이판 · 나무 못 넷 · 망토 둘 · 모자 · 기댄 눈신 한 켤레(벽에 붙여 — 빈 바닥 밖 x < -16)
    wx = -XI
    bx(g, "Timber", wx, wx + 0.25, -10.6, -7.4, FZ + 6.2, FZ + 6.8)
    for y in (-10.1, -9.2, -8.3, -7.6):
        bx(g, "DarkLog", wx + 0.25, wx + 0.75, y - 0.12, y + 0.12, FZ + 6.35, FZ + 6.6)
    for y, mat in ((-9.9, "Banner"), (-8.6, "Canvas")):
        g[mat].obox(wx + 0.5, y, FZ + 4.9, 0.36, 1.0, 2.6, ry=0.05)
        g[mat].obox(wx + 0.58, y, FZ + 3.8, 0.3, 1.25, 0.9, ry=0.12)
        bx(g, mat, wx + 0.28, wx + 0.75, y - 0.3, y + 0.3, FZ + 6.0, FZ + 6.5)
    g["Leather"].cyl(wx + 0.75, -7.6, FZ + 6.6, 0.55, 0.5, 0.12, seg=10)
    g["Leather"].cyl(wx + 0.75, -7.6, FZ + 6.72, 0.35, 0.3, 0.45, seg=10)
    for y in (-9.6, -8.4):
        g["Wood"].obox(wx + 0.42, y, FZ + 1.6, 0.18, 1.3, 3.0, ry=-0.12)
        for zz in (0.9, 1.6, 2.3):
            g["Leather"].obox(wx + 0.42 + (zz - 1.6) * 0.12, y, FZ + zz, 0.1, 1.1, 0.12, ry=-0.12)
    fy = YFI                                                                     # 앞 벽 알림판(빈 바닥 위 벽면 — 충돌 없음)
    bx(g, "DarkLog", -11.6, -8.4, fy, fy + 0.18, FZ + 5.6, FZ + 8.8)
    bx(g, "Timber", -11.4, -8.6, fy + 0.18, fy + 0.24, FZ + 5.8, FZ + 8.6)
    for x, z, a, mat in ((-10.7, 7.6, 0.08, "Canvas"), (-9.4, 7.8, -0.1, "Paint"), (-10.2, 6.5, -0.05, "Paint"), (-9.1, 6.6, 0.12, "Canvas")):
        g[mat].obox(x, fy + 0.27, FZ + z, 0.9, 0.04, 1.1, ry=a)
        g["Brass"].box(x, fy + 0.31, FZ + z + 0.45, 0.12, 0.05, 0.12)
    for x, y in ((7.6, -8.4), (-11.0, -5.6), (-11.0, 0.6), (0.0, -7.6)):        # 등(1층 장선 사이 → 2층 마루 판에 매닮 — 2026-11-28: 보 밑 0.3 에 떠 있었다)
        K.lantern(g, x, y, Z1C + 0.8, FZ + 8.4)


def rooms(g):
    """2층(쉬는 자리 셋): 왼 방·오른 방 침대(머리 = 옆벽) · 뒤 오른 구석 셋째 침대 · 옷장·세면대·의자·책상·깔개 · 계단참 걸상·옷장 · 등.
    INFO['floors'] 의 빈 바닥(x -16.6..-6.6 · 3.6..13.6, y -7..3)은 비운다(깔개만)"""
    zc = Z_PLATE - 0.9
    for x in (-6.0, 6.0):
        A.partition(g, "y", x, YFI, -8.2, Z2F, zc)
    F = Z2F + 0.06
    N.put(g, -13.4, -8.95, F, math.pi / 2, N.bed, 3.8, 6.6, "Banner")             # 왼 방
    cbox(-16.7, -10.1, -10.85, -7.05, Z2F, F + 2.4)
    N.put(g, -8.2, -10.2, F, math.pi, N.washstand)
    cbox(-9.3, -7.1, -10.9, -9.5, Z2F, F + 3.0)
    N.put(g, -8.4, -8.15, F, math.pi + 0.3, N.chair, cushion="Felt")
    N.coll(-8.4, -8.15, F, math.pi + 0.3, -0.9, 0.9, -0.85, 0.85, -0.06, 1.95)
    N.put(g, -11.5, -4.5, F, 0.0, N.rug, 4.0, 3.0, "Felt", "SignGold", "Banner")
    N.put(g, 13.4, -8.95, F, -math.pi / 2, N.bed, 3.8, 6.6, "SignBlue")            # 오른 방
    cbox(10.1, 16.7, -10.85, -7.05, Z2F, F + 2.4)
    N.put(g, 6.95, -9.4, F, -math.pi / 2, N.wardrobe)                           # 칸막이에 등을 댐(침대와 틈 2.2 — 3~9 틈 금지)
    cbox(6.1, 7.9, -10.9, -7.9, Z2F, F + 7.2)
    N.put(g, 11.5, -4.5, F, 0.0, N.rug, 4.0, 3.0, "SignBlue", "Canvas", "Banner")
    N.put(g, 15.1, 7.7, F, 0.0, N.bed, 3.4, 6.6, "Felt", "Canvas", "DarkLog", "Wood", 3.3, 2.6)   # 뒤 오른 구석
    cbox(13.4, 16.8, 4.4, 11.0, Z2F, F + 2.4)
    N.put(g, 15.6, 3.7, F, 0.0, N.nightstand)
    cbox(14.9, 16.3, 3.1, 4.3, Z2F, F + 2.3)
    N.candle(g, 15.6, 3.7, F + 2.2, h=0.6)
    N.put(g, -4.8, -10.2, F, math.pi, N.bookcase, 2.2)                           # 가운데 방(발코니 문 앞)
    cbox(-5.9, -3.7, -10.9, -9.6, Z2F, F + 7.0)
    N.put(g, 4.85, -10.0, F, 0.0, N.table, 2.2, 1.5, 2.7)
    cbox(3.75, 5.95, -10.75, -9.25, Z2F, F + 2.7)
    N.book(g, 4.6, -10.0, F + 2.7, cover="Banner")
    N.candle(g, 5.5, -10.3, F + 2.7)
    N.put(g, 4.85, -8.4, F, math.pi, N.chair)
    N.coll(4.85, -8.4, F, math.pi, -0.9, 0.9, -0.85, 0.85, -0.06, 1.95)
    N.put(g, 0.0, -5.6, F, 0.0, N.rug, 7.0, 3.6, "Banner", "SignGold", "Felt")
    N.put(g, XI - 1.6, 0.0, F, 0.0, N.drawer_chest, 3.2, 1.2, 3.0, 2, 2)          # 오른 방 굴뚝 가슴 ~ 뒤 침대 머리맡 사이 서랍장(4.4 틈을 막음)
    cbox(XI - 3.2, XI, -0.6, 0.6, Z2F, F + 3.0)
    for side in (-1, 1):                                                         # 옆벽 꾸밈(왼 방 = x -16.8, 오른 방 = x 16.8)
        wx, rz = side * XI, (math.pi / 2 if side < 0 else -math.pi / 2)
        N.put(g, wx, -8.95, F + 5.0, rz, N.painting, 3.0, 2.0)                     # 침대 머리 위 그림
        sy = -3.0 if side < 0 else 1.0
        bx(g, "Timber", *sorted((wx, wx - side * 0.25)), sy - 1.3, sy + 1.3, F + 6.2, F + 6.75)          # 못 걸이판 + 못 셋 + 외투 하나
        for k in range(3):
            bx(g, "DarkLog", *sorted((wx - side * 0.25, wx - side * 0.7)), sy - 0.9 + k * 0.9 - 0.12, sy - 0.9 + k * 0.9 + 0.12, F + 6.35, F + 6.6)
        cm = "Banner" if side < 0 else "Felt"
        g[cm].obox(wx - side * 0.45, sy - 0.9, F + 4.75, 0.34, 0.95, 2.5, ry=side * 0.05)
        bx(g, cm, *sorted((wx - side * 0.2, wx - side * 0.7)), sy - 1.2, sy - 0.6, F + 5.95, F + 6.4)
        shy = 1.2 if side < 0 else 3.6                                           # 벽 선반: 접은 담요 둘 + 초
        N.put(g, wx, shy, F + 5.4, rz, N.wall_shelf, 2.2, 1.0)
        for k, m in enumerate(("Felt", "Canvas")):
            bx(g, m, *sorted((wx - side * 0.15, wx - side * 0.85)), shy - 0.75, shy + 0.15, F + 5.4 + k * 0.32, F + 5.7 + k * 0.32)
        N.candle(g, wx - side * 0.5, shy + 0.6, F + 5.4, h=0.55)
        if side < 0:                                                             # 창 밑 작은 궤짝(무릎 밑 — 충돌 없음)
            N.put(g, -16.1, -6.0, F, math.pi / 2, N.trunk, 1.8, 1.1, 1.3)
    for x, y in ((-12.0, -9.0), (0.0, -9.0), (12.0, -9.0), (-11.5, 9.0), (15.0, 9.0), (4.0, 3.0)):   # 평보(y -9 · 3 · 9)에 매닮
        K.lantern(g, x, y, zc, Z2F + 7.4)


def balcony(g, R):
    """앞 발코니·마루: 기둥 넷(받침돌, 땅 → 앞 트러스) · 2층 높이 보(기둥 옆) → 장선(보 → 앞벽) → 마루 → 난간은 기둥 사이 · 앞 트러스 · 간판"""
    ztb = Z_PLATE - 0.9
    for x in POST_XS:
        K.post(g, x, TRUSS_Y, FZ, ztb, s=1.0)
    for s in (-1, 1):
        x = s * 17.5
        K.brace(g, "x", TRUSS_Y, x - s * 0.5, ztb - 2.6, x - s * 3.0, ztb, s=0.5)
    K.tie_truss(g, TRUSS_Y, R)
    zb0, zb1 = Z2F - 1.5, Z2F - 0.9
    yb = YF - T / 2
    bx(g, "DarkLog", -18.0, 18.0, TRUSS_Y - 0.5, TRUSS_Y + 0.5, zb0 - 0.3, zb1)                 # 발코니 보(기둥 머리 아닌 기둥 옆 — 기둥이 꿰뚫음)
    for k in range(13):
        x = -17.0 + k * 34.0 / 12
        bx(g, "Timber", x - 0.3, x + 0.3, TRUSS_Y - 0.4, yb, zb1, Z2F - 0.3)                      # 장선(보 위 → 앞벽)
    bx(g, "Wood", -18.0, 18.0, PORCH_Y, yb, Z2F - 0.3, Z2F)
    cbox(-18.0, 18.0, PORCH_Y, yb, zb0 - 0.3, Z2F)
    for a, b in zip(POST_XS, POST_XS[1:]):
        A.rail_between(g, "x", TRUSS_Y, a + 0.5, b - 0.5, Z2F, h=3.4)
    for x in (-17.5, 17.5):
        A.rail_between(g, "y", x, TRUSS_Y + 0.5, yb, Z2F, h=3.4)
    # 1층 마루 등(발코니 보에 매닮) · 바깥 걸상(I4)
    for x in (-17.0 + 2 * 34.0 / 12, -17.0 + 10 * 34.0 / 12):                     # 발코니 장선 밑에 매닮(2026-11-28: 보 앞 허공에 떠 있었다)
        K.lantern(g, x, -13.8, zb1, FZ + 7.6)
    K.SVC.bench(g, -11.0, -12.9, FZ, 6.0, axis="x", mat="Wood")
    # 앞 트러스 밑 큰 간판(맥주잔) + 오른 기둥 쇠 팔 간판
    for x in (-2.8, 2.8):
        bx(g, "Iron", x - 0.06, x + 0.06, TRUSS_Y - 0.06, TRUSS_Y + 0.06, Z2F + 7.6, ztb)
    bx(g, "Timber", -4.0, 4.0, TRUSS_Y - 0.15, TRUSS_Y + 0.15, Z2F + 4.9, Z2F + 7.6)
    bx(g, "Brass", -4.15, 4.15, TRUSS_Y - 0.2, TRUSS_Y + 0.2, Z2F + 7.55, Z2F + 7.75)
    bx(g, "SnowCap", -4.0, 4.0, TRUSS_Y - 0.18, TRUSS_Y + 0.18, Z2F + 7.75, Z2F + 7.87)
    for f in (-1, 1):
        _big(g, lambda q, f=f: K.SVC.mug_icon(q, -0.15, TRUSS_Y + f * 0.15, Z2F + 5.2, face=f), (0.0, TRUSS_Y, Z2F + 5.2), 1.15)
    K.hang_sign(g, 18.0, TRUSS_Y, FZ + 9.0, along="x", arm=2.4, board=(2.6, 2.2),
                icon=lambda g_, x, y, z, f: K.SVC.mug_icon(g_, x - 0.15, y, z, face=f))


def _big(g, fn, at, k):
    from mathutils import Matrix
    m = Matrix.Translation(at) @ Matrix.Scale(k, 4) @ Matrix.Translation((-at[0], -at[1], -at[2]))
    K.L.transformed(g, m, fn)


def outside(g):
    # 왼 옆 증기 통 → 관이 왼벽으로(난방). (2팀) 김은 처마 밑이라 빼고(위가 막힘) 굴뚝 하나에만 둔다
    tx, ty = -HALF - 1.6, 6.0
    N.no_vent(g, K.steam_bundle, tx, ty, 0.0, h=7.0, r=1.2, gauge_face=-1, pipe_pts=[(tx + 1.2, ty, 7.6), (-HALF + 0.3, ty, 7.6)])


def build(g):
    R = K.roof_frame(HALF, PORCH_Y, YB + T / 2, Z_PLATE, VARIANT)
    K.foundation(g, -HALF - 0.3, HALF + 0.3, PORCH_Y, YB + T / 2 + 0.3)
    K.stair(g, 0.0, PORCH_Y, 14.0, FZ)
    N.plank_floor(g, -XI, XI, YFI, YBI, FZ)                                      # (2팀) 1층 널 마루
    shell(g, R)
    floor2(g)
    N.stair2(g, ST_BOT, ST_TOP, ST_Y0, ST_Y1, FZ, Z2F, open_y=ST_Y0)            # (2팀 2차) 곧은 측판·깔개·놋쇠 누름대·내민 디딤판
    for y in (-9.0, -3.0, 3.0, 9.0):
        K.tie_truss(g, y, R)
    balcony(g, R)
    K.roof_gable(g, R, openings=[STACK])
    ztop = R.top() + 1.0
    N.no_vent(g, K.chimney, *STACK, ztop)                                        # (2팀) 김은 굴뚝 쇠 갓 위로(갓 밑이면 위가 막힘)
    K.S.vent(g, (STACK[0] + STACK[1]) / 2, (STACK[2] + STACK[3]) / 2, ztop + 2.6)
    hearth(g)
    bar(g)
    hall(g)
    stair_nook(g)
    rooms(g)
    outside(g)
    CLEAR(-4.8, 4.8, YFI + 0.2, -6.0, FZ + 0.15, FZ + 5.4)
    CLEAR(-16.0, -6.0, -10.9, -0.4, FZ + 0.15, FZ + 5.4)


INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": COUNTER,
    "free": (-16.0, -6.0, -10.9, -0.4),
    "walk": ((0.0, YF - 1.5), (-11.0, -6.0)),
    "inside": (-XI, XI, YF - T / 2 - 1.5, YBI),
    "forge_look": (HEARTH[0], (HEARTH[2] + HEARTH[3]) / 2),
    "plan_scale": 50,
    "rest": REST,                               # 쉬는 자리(블렌더 x, y — 바닥 = Z2F). Studio 표지 종류는 질문 md
    "floors": [
        {"name": "2층", "floor": Z2F, "what": "계단 윗단 → 왼 방 쉬는 자리",
         "walk": ((-11.5, 5.0), (-11.4, -2.0)), "free": (-16.6, -6.6, -7.0, 3.0),
         "inside": (-XI, XI, YFI, YBI), "voids": [(ST_TOP, ST_BOT, HDR_Y + 0.5, YBI)]},
        {"name": "2층b", "floor": Z2F, "what": "계단 윗단 → 오른 방 쉬는 자리",
         "walk": ((-11.5, 5.0), (8.6, -2.0)), "free": (3.6, 13.6, -7.0, 3.0),
         "inside": (-XI, XI, YFI, YBI), "voids": [(ST_TOP, ST_BOT, HDR_Y + 0.5, YBI)]},
    ],
    "extra_views": [
        ("fp_stair", (16.0, 7.0, FZ + 4.5), (-2.0, 7.0, Z2F - 1.0), 17, None),          # 계단 아랫단(동쪽)에서 올려다봄
        ("fp_stair_side", (8.0, -2.5, FZ + 4.5), (2.0, 7.0, FZ + 5.0), 17, None),          # 계단 앞(식당 쪽)에서 측판 보기
        ("fp_stairtop", (-9.0, 7.0, Z2F + 4.5), (-11.0, -8.0, Z2F + 2.0), 17, None),     # 2층 계단참 → 왼 방
        ("fp_2f", (0.0, 1.0, Z2F + 4.5), (12.0, -8.0, Z2F + 2.0), 17, None),            # 2층 복도 → 오른 방
        ("fp_balcony", (-10.0, -14.0, Z2F + 4.5), (10.0, -14.5, Z2F + 2.0), 17, None),  # 발코니
        ("plan2", (0.0, 0.0, 120.0), (0.0, 0.01, 0.0), None, (120 - (Z2F + CEIL2 - 0.3), 50)),
    ],
}
