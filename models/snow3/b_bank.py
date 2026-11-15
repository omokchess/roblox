# -*- coding: utf-8 -*-
"""
b_bank.py — 2026-11-14. 설원 마을 3판: 은행(보관·환전). 아트 부서원 2, B 양식 — 돌 비율을 가장 높게(벽 절반까지 돌).

레퍼런스(회사/설원마을_레퍼런스.md B·C): 뢰로스 은행(B1 — 돌 1층 + 짙은 목재 위, 모임지붕), 1922 퀸즐랜드 은행 안(B2 — 나무 몸 + 쇠살 창구),
은행 박물관 금고문(B3 — 두꺼운 쇠문·빗장·손잡이·문틀), 검은 숲 농가(C4 — 짙은 뼈대·깊은 처마).
마을에서 유일한 모임지붕(박공 없음) + 문 양옆 돌 기둥 + 쇠살 창으로 멀리서 "단단한 집"으로 읽히게.

배치(블렌더, 앞 = -y, 바닥 FZ = 2):
  벽 가운데 선 x ±16.4 · y -13..13 → 안 31.6 × 24.8, 천장(평보 밑) 11. 앞 계단 폭 14
  정문 x -5.2..5.2 높이 10(양옆 돌 기둥 + 돌 인방) → 홀 → 창구 카운터 x -9..9 · y 3..5.5 (위 쇠살 칸막이, 창구 둘 x ±4)
  카운터 앞 빈 바닥 x -5..5 · y -7.15..2.85, NPC (-4, 7.5)·(4, 7.5). 카운터 끝 ~ 옆벽은 난간 문으로 막음(직원 쪽)
  뒷벽 가운데: 닫힌 금고문(퀘스트로 열 문 — INFO "vault_door") · 양옆 쇠 금고 상자 / 홀 양옆 긴 의자
  바깥: 왼 앞 증기 통(압력계가 길을 봄) → 관이 앞벽을 타고 올라 벽 속으로(금고 난방) · 양 옆벽 쇠 팔 동전 간판
"""
import lib as K
import lib_b as KB
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, WIN_W, WIN_SILL, bx, cbox, NPC, CLEAR

NAME = "Sn3_Bank"
PREFIX = "Sn3Bank"
VARIANT = "B"

WX, YF, YB = 16.4, -13.0, 13.0
T = LOG
AX, AY = WX + T / 2, YB + T / 2          # 벽 바깥면 반폭 17.0 · 13.6
XI, YI0, YI1 = WX - T / 2, YF + T / 2, YB - T / 2       # 15.8, -12.4, 12.4
Z_PLATE = FZ + CEIL + 0.9
STONE_TO = FZ + 6.0                      # 벽 절반까지 돌(B1)
PITCH = 40.0                             # 모임지붕은 네 면이 다 보여 50 이면 지붕이 집을 누른다(1차 렌더) → 40
WIN_F, WIN_B, WIN_S = (-11.5, 11.5), (-11.0, 11.0), (-6.5, 6.5)
COUNTER = (-9.0, 9.0, 3.0, 5.5)
FREE = (-5.0, 5.0, -7.15, 2.85)
TIES = (-10.0, -3.4, 3.4, 10.0)          # 평보(y 방향) 자리 — ±3.4 = 마룻대 끝
VAULT_R = 3.2


def walls(g):
    hole = lambda u: (u - WIN_W / 2, u + WIN_W / 2, FZ + WIN_SILL, FZ + WIN_SILL + K.WIN_H)     # noqa: E731
    door = (-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H)
    plan = (("x", YF, [door] + [hole(u) for u in WIN_F], -1),
            ("x", YB, [hole(u) for u in WIN_B], 1),
            ("y", -WX, [hole(u) for u in WIN_S], -1),
            ("y", WX, [hole(u) for u in WIN_S], 1))
    for ax, c, holes, face in plan:
        u0, u1 = (-WX, WX) if ax == "x" else (YF, YB)
        K.frame_wall(g, ax, c, u0, u1, FZ, Z_PLATE, holes, stone_to=STONE_TO, face=face)
        for h in holes[1 if ax == "x" and c == YF else 0:]:
            KB.barred_window(g, ax, c, (h[0] + h[1]) / 2, FZ + WIN_SILL, face)
    K.door_open(g, "x", YF, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=125.0, outward=False)   # 안으로 연 문(바깥 돌 기둥·창을 가리지 않게)


def portal(g):
    """정문 돌 기둥 둘(기초 위) + 돌 인방(처마 밑까지) — 은행만의 단단한 문"""
    y0, y1 = -AY - 0.9, -AY
    for s in (-1, 1):
        x0, x1 = sorted((s * 6.0, s * 7.5))
        bx(g, "StoneTrim", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1, FZ, FZ + 0.8)            # 기둥 밑동
        bx(g, "Stone", x0, x1, y0, y1, FZ + 0.8, FZ + 10.6)
        bx(g, "StoneTrim", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1, FZ + 10.6, FZ + 11.0)    # 기둥 머리
        cbox(x0, x1, y0, y1, FZ, FZ + 10.6)
    bx(g, "Stone", -7.65, 7.65, y0 - 0.1, y1, FZ + 11.0, FZ + 11.6)                     # 돌 인방(두 기둥 머리 위)
    bx(g, "StoneTrim", -7.9, 7.9, y0 - 0.3, y1, FZ + 11.6, FZ + 11.85)
    # 인방 가운데 놋쇠 동전 판
    g["Brass"].hcyl(0, y0 - 0.2, FZ + 11.3, 0.5, 0.2, axis="y", seg=16)


def roof(g):
    ztop, zb = KB.hip_roof(g, AX, AY, Z_PLATE, PITCH)
    # 평보(y 방향) + 동자기둥(마룻대 끝 · 모임 쪽 서까래 밑) + 버팀대
    zt0 = Z_PLATE - 0.9
    for xt in TIES:
        bx(g, "DarkLog", xt - 0.5, xt + 0.5, -AY + 0.05, AY - 0.05, zt0, Z_PLATE)
        inset = min(AY, AX - abs(xt) - 0.5)
        zp = zb(inset) - (1.15 if abs(xt) < AX - AY + 0.1 else 0.1)
        bx(g, "DarkLog", xt - 0.4, xt + 0.4, -0.4, 0.4, Z_PLATE, zp)
        for s in (-1, 1):
            KB.member(g, "DarkLog", (xt, s * 0.4, Z_PLATE + (zp - Z_PLATE) * 0.55), (xt, s * (AY - 4.0), Z_PLATE + 0.3), 0.45, 0.45)
    return ztop


def hall(g):
    """창구 카운터 + 쇠살 칸막이 + NPC · 카운터 끝 난간 문 · 금고문 + 금고 상자 · 긴 의자 · 등"""
    x0, x1, y0, y1 = COUNTER
    zt = K.counter(g, x0, x1, y0, y1)
    KB.grille(g, x0, x1, (y0 + y1) / 2, zt, FZ + 9.0, gaps=((-5.5, -2.5), (2.5, 5.5)))
    for x in (-4.0, 4.0):
        NPC(x, 7.5, FZ, 0.0)
    for x in (-7.2, 7.2):                     # 창구 등(놋쇠 갓)
        g["Brass"].cyl(x, 4.6, zt, 0.3, 0.2, 0.15, seg=10)
        g["Iron"].cyl(x, 4.6, zt + 0.15, 0.06, 0.06, 1.3, seg=6)
        g["Brass"].cyl(x, 4.6, zt + 1.1, 0.55, 0.2, 0.45, seg=12)
        g["Glow"].box(x, 4.6, zt + 1.05, 0.28, 0.28, 0.1)
    for x in (-1.0, 1.0):                     # 장부·동전 저울
        bx(g, "Leather", x - 0.6, x + 0.2, 3.3, 4.0, zt, zt + 0.25)
    # 카운터 끝 ~ 옆벽: 난간(직원 쪽 막음) — 끝 기둥 둘(바닥 위) 사이에만
    yc = (y0 + y1) / 2
    for s in (-1, 1):
        K.post(g, s * (XI - 0.5), yc, FZ, FZ + 3.8, s=0.8, coll=True)              # 벽 쪽 난간 기둥(받침돌 위)
        KB.railing(g, "x", yc, *sorted((s * (x1 + 0.1), s * (XI - 0.9))), FZ, h=3.6)    # 카운터 끝 ~ 기둥 사이만
    # 뒷벽 금고문(닫힘) + 양옆 쇠 금고 상자
    KB.vault_door(g, 0.0, YI1, FZ, r=VAULT_R, face=-1)
    for x in (-11.5, 11.5):
        bx(g, "Iron", x - 1.6, x + 1.6, YI1 - 2.2, YI1, FZ, FZ + 3.2)
        bx(g, "Brass", x - 1.65, x + 1.65, YI1 - 2.25, YI1, FZ + 2.8, FZ + 3.0)
        g["Brass"].hcyl(x, YI1 - 2.25, FZ + 1.8, 0.35, 0.12, axis="y", seg=10)
        bx(g, "IronLight", x - 1.2, x + 1.2, YI1 - 1.9, YI1 - 0.3, FZ + 3.2, FZ + 4.6)
        cbox(x - 1.6, x + 1.6, YI1 - 2.2, YI1, FZ, FZ + 4.6)
    # 홀 양옆 긴 의자
    for s in (-1, 1):
        xa, xb = sorted((s * XI, s * (XI - 1.8)))
        bx(g, "Wood", xa, xb, -9.5, -2.0, FZ + 1.6, FZ + 1.9)
        for yy in (-9.0, -2.5):
            bx(g, "Timber", xa + 0.3, xb - 0.3, yy - 0.25, yy + 0.25, FZ, FZ + 1.6)
        wa, wb = sorted((s * XI, s * (XI - 0.3)))
        bx(g, "Timber", wa, wb, -9.5, -2.0, FZ + 1.9, FZ + 4.0)
        cbox(xa, xb, -9.5, -2.0, FZ, FZ + 1.9)
    for x, y in ((-3.4, -6.0), (3.4, -6.0), (-10.0, -1.0), (10.0, -1.0), (-3.4, 9.0), (3.4, 9.0)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)


def signs(g):
    coin = lambda g_, x, y, z, f: K.SVC.coin_icon(g_, x, y, z - 0.75, face=f)    # noqa: E731
    K.hang_sign(g, AX, -10.2, FZ + 9.0, along="x", icon=coin, face_sign=1)
    K.hang_sign(g, -AX, -10.2, FZ + 9.0, along="x", icon=coin, face_sign=-1)


def steam(g):
    tx, ty = -12.5, -15.7
    rx = -8.4
    K.steam_bundle(g, tx, ty, 0.0, h=6.4, r=1.15, gauge_face=-1,
                   pipe_pts=[(tx + 1.15, ty, 4.2), (rx, ty, 4.2), (rx, -14.3, 4.2), (rx, -14.3, 12.6), (rx, -13.3, 12.6)])
    for z in (7.4, 10.4):
        bx(g, "Iron", rx - 0.45, rx + 0.45, -14.7, -AY, z - 0.12, z + 0.12)


def build(g):
    K.foundation(g, -AX - 0.3, AX + 0.3, -AY - 0.3, AY + 0.3)
    K.stair(g, 0.0, -AY - 0.3, 14.0, FZ)
    walls(g)
    portal(g)
    roof(g)
    hall(g)
    signs(g)
    steam(g)
    CLEAR(-4.7, 4.7, YI0 + 0.2, FREE[2], FZ + 0.15, FZ + 5.4)      # 안으로 연 문짝 띠가 0.1~0.3 들어와 ±4.7 (충돌 없음, 문 구멍 10.4)
    CLEAR(FREE[0], FREE[1], FREE[2], FREE[3] - 0.15, FZ + 0.15, FZ + 5.4)


INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": COUNTER,
    "free": FREE,
    "walk": ((0.0, YF - 1.5), (0.0, -2.0)),
    "inside": (-XI, XI, YF - T / 2 - 1.5, YI1),
    "forge_look": (0.0, YI1),                # 1인칭 안 렌더가 바라볼 금고문
    # 닫힌 금고문(2026-11-01 사용자: 퀘스트로 열 수 있게 닫아 둠). 블렌더 좌표 — 로블록스 로컬 = (-x, z, y)
    "vault_door": {"center": (0.0, YI1 - 0.9, FZ + 0.4 + VAULT_R), "diameter": 2 * VAULT_R, "face": "-y",
                   "frame": (-VAULT_R - 1.4, VAULT_R + 1.4, FZ, FZ + 2 * VAULT_R + 1.8), "depth": 2.1},
}
