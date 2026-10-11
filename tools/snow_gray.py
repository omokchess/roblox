# -*- coding: utf-8 -*-
"""
snow_gray.py — 2026-10-11. 슈네라이히 광장 서비스 고리의 회색 상자(그레이박스) 건물 7채.

사용자(2026-10-11): "건물들이 '예쁘게'에 치중돼 영화 촬영장 같다. 유저 플레이에 맞춰 재구성." → 꾸미기 전에 상자만으로
동선·크기를 짓고 1·3인칭으로 걸어 본 뒤 승인 → 그다음 블렌더로 꾸민다. 크기 기준은 `마을_플레이_기준.md`.
  R6 캐릭터: 팔까지 폭 4, 키 5. 문 폭 6·높이 9(정문 10×10), 복도 8, 천장 12+, 계단 폭 6·단 1, 카운터 높이 3.5·앞 빈 바닥 10×10.
  실내 세 구역: 입구 완충(비움) → 가운데 기능(카운터·NPC 자리) → 벽 쪽 이야기(볼거리).

좌표는 다른 건물 스크립트와 같은 블렌더식 (x 오른쪽, y 안쪽, z 위; 앞 = -y) → 로블록스 로컬 (-x, z, y).
  python tools/snow_gray.py   → tools/Snow_Gray.luau (ServerStorage.SnowKit 에 Gray_* 틀을 만든다)
  bash tools/job.sh tools/Snow_Gray.luau
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
T = 1.0          # 벽 두께
FZ = 0.4         # 1층 바닥 윗면

# 재질: (색 RGB, Material, 충돌, 투명도)
MATS = {
    "Wall": ((198, 198, 194), "SmoothPlastic", True, 0),
    "Floor": ((140, 138, 134), "SmoothPlastic", True, 0),
    "Roof": ((110, 112, 118), "SmoothPlastic", True, 0),
    "Stair": ((160, 158, 152), "SmoothPlastic", True, 0),
    "Counter": ((214, 140, 60), "SmoothPlastic", True, 0),     # 기능: 카운터·작업대
    "Story": ((120, 140, 168), "SmoothPlastic", True, 0),      # 이야기: 선반·볼거리 덩어리
    "Bed": ((236, 236, 230), "SmoothPlastic", True, 0),
    "Fire": ((255, 110, 40), "Neon", True, 0),
    "Sign": ((52, 46, 40), "SmoothPlastic", False, 0),
    "NPC": ((70, 200, 90), "Neon", False, 0),                   # NPC 설 자리(받침)
    "Ghost": ((70, 200, 90), "SmoothPlastic", False, 0.65),     # NPC 크기 유령(R6 4×5×1)
    "Zone": ((250, 210, 60), "SmoothPlastic", False, 0.55),    # 카운터 앞 빈 바닥 10×10
    "Spawn": ((90, 200, 230), "Neon", False, 0.3),              # 부활 자리
    "Yard": ((176, 172, 162), "SmoothPlastic", True, 0),        # 뜰 바닥
    "Herb": ((96, 150, 70), "Grass", True, 0),                  # 약초밭·정원
}


def wall(out, axis, c, a0, a1, z0, z1, holes=(), t=T, mat="Wall"):
    """axis "x": y = c 에 선 벽(x a0..a1), "y": x = c 에 선 벽(y a0..a1). holes = [(u0, u1, z0, z1)] 를 뺀 칸들로 쪼갠다"""
    us = sorted({a0, a1, *[h[0] for h in holes], *[h[1] for h in holes]})
    zs = sorted({z0, z1, *[h[2] for h in holes], *[h[3] for h in holes]})
    us = [u for u in us if a0 <= u <= a1]
    zs = [z for z in zs if z0 <= z <= z1]
    for zi in range(len(zs) - 1):
        za, zb = zs[zi], zs[zi + 1]
        run = None
        for ui in range(len(us) + 0):
            if ui < len(us) - 1:
                ua, ub = us[ui], us[ui + 1]
                um, zm = (ua + ub) / 2, (za + zb) / 2
                solid = not any(h[0] <= um <= h[1] and h[2] <= zm <= h[3] for h in holes)
            else:
                solid = False
            if solid and run is None:
                run = ua
            if not solid and run is not None:
                end = us[ui]
                if axis == "x":
                    out.append((mat, (run + end) / 2, c, (za + zb) / 2, end - run, t, zb - za))
                else:
                    out.append((mat, c, (run + end) / 2, (za + zb) / 2, t, end - run, zb - za))
                run = None


def box(out, mat, x0, x1, y0, y1, z0, z1):
    out.append((mat, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0))


def npc(out, x, y, z=FZ, face="-y"):
    """NPC 설 자리: 받침 원판 대신 납작 상자 3.5×3.5 + R6 크기 유령(폭 4·키 5·두께 1)"""
    box(out, "NPC", x - 1.75, x + 1.75, y - 1.75, y + 1.75, z + 0.05, z + 0.2)
    if face in ("-y", "+y"):
        box(out, "Ghost", x - 2.0, x + 2.0, y - 0.5, y + 0.5, z + 0.2, z + 5.2)
    else:
        box(out, "Ghost", x - 0.5, x + 0.5, y - 2.0, y + 2.0, z + 0.2, z + 5.2)


def zone(out, x0, x1, y0, y1, z=FZ):
    box(out, "Zone", x0, x1, y0, y1, z + 0.06, z + 0.14)


def shell(out, W, D, H, front_holes, side_holes=(), back_holes=(), roof=True):
    """바닥 판 · 네 벽(앞 y=-D/2) · 평지붕. 높이 H = 벽 윗면"""
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    box(out, "Floor", x0, x1, y0, y1, 0.0, FZ)
    wall(out, "x", y0 + T / 2, x0, x1, FZ, H, front_holes)
    wall(out, "x", y1 - T / 2, x0, x1, FZ, H, back_holes)
    for s in (-1, 1):
        wall(out, "y", s * (W / 2 - T / 2), y0 + T, y1 - T, FZ, H, side_holes)
    if roof:
        box(out, "Roof", x0 - 0.6, x1 + 0.6, y0 - 0.6, y1 + 0.6, H, H + 1.0)
    return x0 + T, x1 - T, y0 + T, y1 - T      # 안쪽 면


SIGNS = {}     # kind → (글, x, y, z, w, h)


def sign(kind, text, D, z, w=12.0, h=3.0, y=None, both=False, x=0.0):
    SIGNS[kind] = (text, x, -D / 2 - 0.35 if y is None else y, z, w, h, both)


# ── 건물 ─────────────────────────────────────────────────────────────────────

def shop(kind, text, W=26.0, D=26.0, H=14.0):
    """작은 가게 공통 틀(잡화·물약·강화소): 문 6×9, 앞 창 둘, 옆 창(앞쪽 반), 카운터 뒤 가운데"""
    o = []
    fh = [(-3.0, 3.0, FZ, FZ + 9.0), (-11.0, -6.5, 3.5, 8.5), (6.5, 11.0, 3.5, 8.5)]
    sh = [(-9.5, -5.0, 3.5, 8.5)]
    ix0, ix1, iy0, iy1 = shell(o, W, D, H, fh, sh)
    sign(kind, text, D, FZ + 11.2)
    return o, (ix0, ix1, iy0, iy1)


def gray_general():
    o, (ix0, ix1, iy0, iy1) = shop("Gray_General", "잡화점")
    box(o, "Counter", -6.0, 6.0, 4.0, 6.5, FZ, FZ + 3.5)                 # 카운터(가운데 뒤)
    npc(o, 0.0, 8.5)
    zone(o, -5.0, 5.0, -6.0, 4.0)
    box(o, "Story", -9.0, 9.0, iy1 - 1.5, iy1, FZ, FZ + 9.0)              # 뒤 선반
    for s in (-1, 1):
        xa, xb = (ix1 - 1.5, ix1) if s > 0 else (ix0, ix0 + 1.5)
        box(o, "Story", xa, xb, -3.0, 9.0, FZ, FZ + 8.0)                                       # 옆 선반
        box(o, "Story", s * 8.0 - 1.5, s * 8.0 + 1.5, iy0 + 0.5, iy0 + 3.5, FZ, FZ + 3.0)     # 앞 구석 상자 더미(문 길 x ±3 밖)
    return o


def gray_potion():
    o, (ix0, ix1, iy0, iy1) = shop("Gray_Potion", "물약상점")
    box(o, "Counter", -6.0, 6.0, 4.0, 6.5, FZ, FZ + 3.5)
    npc(o, 0.0, 8.5)
    zone(o, -5.0, 5.0, -6.0, 4.0)
    box(o, "Story", -6.0, 9.0, iy1 - 1.5, iy1, FZ, FZ + 9.0)              # 뒤 약병 선반
    box(o, "Story", ix0, ix0 + 4.0, iy1 - 4.0, iy1, FZ, FZ + 3.0)          # 큰 솥(왼 뒤 구석)
    box(o, "Fire", ix0 + 1.0, ix0 + 3.0, iy1 - 3.0, iy1 - 1.0, FZ + 3.0, FZ + 3.3)
    box(o, "Story", ix1 - 1.5, ix1, -3.0, 9.0, FZ, FZ + 8.0)              # 오른 선반
    box(o, "Story", ix0, ix0 + 1.5, -3.0, 5.0, FZ, FZ + 8.0)              # 왼 선반(솥 앞까지)
    return o


def gray_enhance():
    o, (ix0, ix1, iy0, iy1) = shop("Gray_Enhance", "강화소 · 룬")
    box(o, "Counter", -4.0, 4.0, 4.0, 7.0, FZ, FZ + 3.5)                  # 룬 새기는 작업대
    npc(o, 0.0, 9.0)
    zone(o, -5.0, 5.0, -6.0, 4.0)
    box(o, "Story", -9.0, 9.0, iy1 - 1.5, iy1, FZ, FZ + 9.0)              # 룬 선반
    for k, y in enumerate((-4.0, 1.0, 6.0)):                               # 왼 벽 룬 받침 셋
        box(o, "Story", ix0, ix0 + 2.0, y - 1.0, y + 1.0, FZ, FZ + 3.5)
        box(o, "Fire", ix0 + 0.6, ix0 + 1.4, y - 0.4, y + 0.4, FZ + 3.5, FZ + 4.3)
    box(o, "Story", ix1 - 1.5, ix1, -3.0, 9.0, FZ, FZ + 8.0)
    return o


def gray_smithy():
    """대장간(장비 제작): 앞이 넓게 트인 작업장 14×11, 화덕(왼 뒤)·모루(가운데)·제작 카운터(오른 뒤)"""
    o = []
    W, D, H = 36.0, 30.0, 16.0
    fh = [(-7.0, 7.0, FZ, FZ + 11.0)]
    ix0, ix1, iy0, iy1 = shell(o, W, D, H, fh, back_holes=[(1.0, 7.0, FZ, FZ + 9.0)])   # 뒷문 → 대장간 마당
    sign("Gray_Smithy", "대장간", D, FZ + 13.2, w=14.0)
    box(o, "Story", ix0 + 1.0, ix0 + 9.0, iy1 - 6.0, iy1, FZ, FZ + 7.0)    # 화덕
    box(o, "Fire", ix0 + 3.0, ix0 + 7.0, iy1 - 6.3, iy1 - 5.8, FZ + 2.0, FZ + 4.5)
    box(o, "Story", ix0 + 3.0, ix0 + 7.0, iy1 - 4.0, iy1, FZ + 7.0, H + 4.0)   # 굴뚝(지붕 위로)
    box(o, "Story", ix0 + 11.0, ix0 + 14.0, iy1 - 5.0, iy1 - 2.0, FZ, FZ + 2.0)   # 담금질 물통
    box(o, "Counter", -2.3, 0.3, 3.4, 4.6, FZ, FZ + 2.8)                  # 모루
    box(o, "Counter", 5.0, 15.0, 4.0, 6.5, FZ, FZ + 3.5)                  # 제작 카운터
    npc(o, 10.0, 9.0)
    zone(o, 5.0, 15.0, -6.0, 4.0)
    box(o, "Story", ix0, ix0 + 1.5, -10.0, 4.0, FZ, FZ + 7.0)             # 왼 벽 무기 걸이
    box(o, "Story", ix1 - 1.5, ix1, 8.0, iy1, FZ, FZ + 7.0)                # 오른 뒤 재료 선반
    return o


def gray_bank():
    """은행: 정문 10×10, 창구 둘(가로 카운터), 뒤 벽 가운데 금고 문, 옆 벽 대기 의자 · 시세판"""
    o = []
    W, D, H = 36.0, 30.0, 16.0
    fh = [(-5.0, 5.0, FZ, FZ + 10.0), (-15.0, -9.0, 4.0, 10.0), (9.0, 15.0, 4.0, 10.0)]
    ix0, ix1, iy0, iy1 = shell(o, W, D, H, fh, [(-10.0, -4.0, 5.0, 10.0)])
    sign("Gray_Bank", "은행", D, FZ + 12.2)
    box(o, "Counter", -14.0, 14.0, 3.0, 5.5, FZ, FZ + 3.5)                # 창구 카운터
    box(o, "Story", -0.4, 0.4, 3.0, 5.5, FZ + 3.5, FZ + 7.5)              # 창구 가르는 칸막이
    for x in (-6.0, 6.0):
        npc(o, x, 8.0)
        zone(o, x - 5.0, x + 5.0, -7.0, 3.0)
    box(o, "Story", -4.5, 4.5, iy1 - 0.6, iy1, FZ + 1.0, FZ + 10.0)        # 금고 문
    box(o, "Counter", -1.0, 1.0, iy1 - 1.0, iy1 - 0.6, FZ + 4.5, FZ + 6.5)  # 금고 손잡이
    for s in (-1, 1):
        xa, xb = (ix0, ix0 + 2.0) if s < 0 else (ix1 - 2.0, ix1)
        box(o, "Story", xa, xb, iy0 + 2.0, iy0 + 10.0, FZ, FZ + 1.8)      # 대기 의자
    box(o, "Story", ix0, ix0 + 0.3, iy0 + 3.0, iy0 + 13.0, FZ + 5.0, FZ + 10.0)   # 시세판(왼 벽)
    return o


def gray_hospital():
    """병원: 정문 10×10, 왼쪽 접수 카운터, 뒤·오른 벽 침대 여섯, 가운데 뒤 부활 자리(사망 뒤 돌아오는 곳)"""
    o = []
    W, D, H = 40.0, 30.0, 16.0
    fh = [(-5.0, 5.0, FZ, FZ + 10.0), (-16.0, -10.0, 4.0, 10.0), (10.0, 16.0, 4.0, 10.0)]
    ix0, ix1, iy0, iy1 = shell(o, W, D, H, fh, [(-6.0, 0.0, 5.0, 10.0)], back_holes=[(-3.0, 3.0, FZ, FZ + 9.0)])   # 뒷문 → 회복 정원
    sign("Gray_Hospital", "병원", D, FZ + 12.2)
    box(o, "Counter", -10.5, -8.0, -8.0, 0.0, FZ, FZ + 3.5)              # 접수 카운터(문 길을 본다)
    npc(o, -13.0, -4.0, face="x")
    zone(o, -8.0, 2.0, -9.0, 1.0)
    for x in (-15.0, -9.0, 9.0, 15.0):                                     # 뒤 벽 침대 넷(머리가 벽)
        box(o, "Bed", x - 1.8, x + 1.8, iy1 - 7.0, iy1, FZ, FZ + 2.2)
        box(o, "Story", x - 1.8, x + 1.8, iy1 - 0.4, iy1, FZ + 2.2, FZ + 4.5)
    for y in (-8.0, -2.0):                                                 # 오른 벽 침대 둘
        box(o, "Bed", ix1 - 7.0, ix1, y - 1.8, y + 1.8, FZ, FZ + 2.2)
        box(o, "Story", ix1 - 0.4, ix1, y - 1.8, y + 1.8, FZ + 2.2, FZ + 4.5)
    box(o, "Spawn", -3.0, 3.0, iy1 - 9.0, iy1 - 3.0, FZ + 0.05, FZ + 0.25)  # 부활 자리
    npc(o, 5.0, 3.0)                                                       # 치료사
    box(o, "Story", ix0, ix0 + 1.5, 3.0, 12.0, FZ, FZ + 7.0)              # 약장(왼 벽)
    return o


def gray_inn():
    """여관 2층: 1층 바(왼 벽)·벽난로(뒤)·탁자, 계단(오른 벽, 앞→뒤, 폭 6·단 1), 2층 = 뒤 복도 8 + 앞 방 셋"""
    o = []
    W, D = 40.0, 30.0
    Z2, H = 13.4, 27.4                     # 2층 바닥 윗면(1층 천장 13), 벽 윗면
    fh = [(-4.0, 4.0, FZ, FZ + 10.0), (-15.0, -9.0, 3.5, 8.5), (9.0, 14.0, 3.5, 8.5),
          (-16.5, -11.5, Z2 + 3.0, Z2 + 8.0), (-5.5, -0.5, Z2 + 3.0, Z2 + 8.0), (5.0, 10.0, Z2 + 3.0, Z2 + 8.0)]
    ix0, ix1, iy0, iy1 = shell(o, W, D, H, fh, back_holes=[(-11.0, -5.0, FZ, FZ + 9.0)])   # 뒷문 → 마구간
    sign("Gray_Inn", "여관", D, FZ + 11.2)
    # 계단: x 13..19, y -11.5 → 8 (13 단, 단 높이 1.0, 디딤 1.5), 꼭대기 = 2층 바닥
    sx0, sx1, sy0, n = 13.0, ix1, -11.5, 13
    for i in range(n):
        box(o, "Stair", sx0, sx1, sy0 + i * 1.5, sy0 + (i + 1) * 1.5, FZ, FZ + (i + 1) * (Z2 - FZ) / n)
    sy1 = sy0 + n * 1.5
    # 2층 바닥(계단 구멍 x 13..19, y -11.5..8 을 뺀다)
    box(o, "Floor", ix0, sx0, iy0, iy1, Z2 - 1.0, Z2)
    box(o, "Floor", sx0, ix1, sy1, iy1, Z2 - 1.0, Z2)
    wall(o, "y", sx0 - 0.3, iy0, 6.0, Z2, H, (), t=0.6)                    # 계단 구멍 옆 벽(방 C 오른 벽)
    # 2층 방 셋(앞), 복도(뒤 y 6..14 = 8)
    xs = [ix0, -8.33, 2.33, sx0 - 0.6]
    for k in range(3):
        cx = (xs[k] + xs[k + 1]) / 2
        if k > 0:
            wall(o, "y", xs[k], iy0, 6.0, Z2, H, (), t=0.6)
        box(o, "Bed", cx - 1.8, cx + 1.8, iy0, iy0 + 7.0, Z2, Z2 + 2.2)
        box(o, "Story", xs[k] + 0.3, xs[k] + 3.3, -4.0, 0.0, Z2, Z2 + 7.0)  # 옷장(옆 벽, 문 길 밖)
    door_h = [((xs[k] + xs[k + 1]) / 2 - 3.0, (xs[k] + xs[k + 1]) / 2 + 3.0, Z2, Z2 + 9.0) for k in range(3)]
    wall(o, "x", 6.0, ix0, sx0 - 0.6, Z2, H, door_h, t=0.6)
    # 1층: 바(왼 벽), 바텐더 자리, 뒤 선반, 벽난로(뒤 가운데), 탁자 셋
    box(o, "Counter", -14.0, -11.5, -4.0, 12.0, FZ, FZ + 3.5)
    npc(o, -16.5, 4.0, face="x")
    zone(o, -11.5, -1.5, -3.0, 7.0)
    box(o, "Story", ix0, ix0 + 1.0, -4.0, 12.0, FZ, FZ + 9.0)
    box(o, "Story", -4.0, 4.0, iy1 - 2.0, iy1, FZ, FZ + 7.0)               # 벽난로
    box(o, "Fire", -2.0, 2.0, iy1 - 2.3, iy1 - 1.9, FZ + 0.8, FZ + 3.0)
    for x, y in ((5.0, -3.0), (5.0, 5.0), (-9.0, -10.0)):
        box(o, "Story", x - 2.0, x + 2.0, y - 2.0, y + 2.0, FZ, FZ + 3.0)  # 탁자
    return o


# ── 뜰(2026-10-11 사용자: "뜰 활용 아이디어 좋아 보이네") — 건물 뒤, 구역 남은 땅을 그 기능의 바깥 연장으로.
#    앞(-y)이 건물 뒷벽을 본다. 바닥 판 0.2 + 덩어리. 간판은 앞 가운데 양면 ──

def yard(kind, text, W, D):
    o = []
    box(o, "Yard", -W / 2, W / 2, -D / 2, D / 2, 0.0, 0.2)
    px = -W / 2 + 1.0                                                     # 간판 기둥은 앞 왼 모서리(뒷문에서 오는 길을 비운다)
    box(o, "Story", px - 0.3, px + 0.3, -D / 2 + 0.2, -D / 2 + 0.8, 0.2, 7.0)
    sign(kind, text, D, 7.6, w=8.0, h=1.8, y=-D / 2 + 0.5, both=True, x=px + 3.5)
    return o


def yard_smithy():
    """대장간 마당: 광석 더미 셋 · 바깥 모루 · 담금질 통 · 장작"""
    o = yard("Gray_Yard_Smithy", "대장간 마당", 30.0, 16.0)
    for x in (-11.0, -6.0, -1.0):
        box(o, "Story", x - 2.0, x + 2.0, 2.0, 6.0, 0.2, 2.7)
    box(o, "Counter", 5.0, 7.6, -1.0, 0.2, 0.2, 3.0)                     # 바깥 모루
    box(o, "Story", 9.0, 14.0, -5.0, -3.0, 0.2, 2.2)                     # 담금질 통
    box(o, "Story", 9.0, 14.0, 3.0, 7.0, 0.2, 3.2)                       # 장작 더미
    return o


def yard_enhance():
    """룬 시험대: 룬 돌 기둥 셋(꼭대기 빛)"""
    o = yard("Gray_Yard_Enhance", "룬 시험대", 20.0, 12.0)
    for x in (-6.0, 0.0, 6.0):
        box(o, "Story", x - 1.0, x + 1.0, 1.0, 3.0, 0.2, 4.2)
        box(o, "Fire", x - 0.5, x + 0.5, 1.5, 2.5, 4.2, 5.0)
    return o


def yard_bank():
    """오늘의 시세판(양면 큰 판) + 걸상 둘 — 명예 거래·시세 보는 곳"""
    o = []
    box(o, "Yard", -8.0, 8.0, -5.0, 5.0, 0.0, 0.2)
    for x in (-5.5, 5.5):
        box(o, "Story", x - 0.3, x + 0.3, -0.3, 0.3, 0.2, 9.0)
        box(o, "Story", x - 2.5, x + 2.5, 3.0, 4.5, 0.2, 2.0)             # 걸상
    sign("Gray_Yard_Bank", "오늘의 시세", 10.0, 6.0, w=11.0, h=5.0, y=0.0, both=True)
    return o


def yard_inn():
    """마구간: 지붕 덮인 칸 넷(뒤 벽), 여물통, 건초, 마부 자리 — 말 등록·호출"""
    o = yard("Gray_Yard_Inn", "마구간", 26.0, 14.0)
    box(o, "Wall", -12.0, 12.0, 6.4, 7.0, 0.2, 9.0)                       # 뒤 벽
    for x in (-12.0, 12.0):
        box(o, "Story", x - 0.3, x + 0.3, -1.0, 7.0, 0.2, 9.0)            # 옆 벽(칸 깊이)
    for x in (-6.0, 0.0, 6.0):
        box(o, "Story", x - 0.2, x + 0.2, 1.0, 6.4, 0.2, 4.5)             # 칸막이
    box(o, "Roof", -12.6, 12.6, -1.6, 7.0, 9.0, 9.6)
    box(o, "Story", -11.0, -3.0, -4.5, -3.5, 0.2, 1.6)                   # 여물통
    box(o, "Counter", 3.0, 6.0, -5.5, -3.5, 0.2, 2.2)                    # 건초
    npc(o, 9.0, -4.0, z=0.2)
    return o


def yard_potion():
    """약초밭: 돋운 밭 넷 + 물통 — 채집 퀘스트"""
    o = yard("Gray_Yard_Potion", "약초밭", 20.0, 16.0)
    for x in (-7.5, -2.5, 2.5, 7.5):
        box(o, "Herb", x - 1.5, x + 1.5, -4.0, 7.0, 0.2, 1.0)
    box(o, "Story", 7.0, 9.0, -7.0, -5.0, 0.2, 2.7)
    return o


def yard_hospital():
    """회복 정원: 부활 뒤 병원 뒷문으로 나오는 곳 — 가운데 화단 · 걸상 셋(앞은 비움)"""
    o = yard("Gray_Yard_Hospital", "회복 정원", 20.0, 16.0)
    box(o, "Herb", -2.0, 2.0, 0.0, 4.0, 0.2, 1.5)
    for x in (-7.5, 7.5):
        box(o, "Story", x - 0.75, x + 0.75, -0.5, 4.5, 0.2, 2.0)
    box(o, "Story", -2.5, 2.5, 6.0, 7.5, 0.2, 2.0)
    return o


def yard_general():
    """노점 칸: 가운데 길(폭 6)을 사이에 두고 셋씩 — 25인 서버 거래 만남"""
    o = yard("Gray_Yard_General", "노점", 28.0, 16.0)
    for y, s in ((-4.0, -1), (4.0, 1)):
        for x in (-9.0, 0.0, 9.0):
            box(o, "Counter", x - 2.5, x + 2.5, y - 0.75, y + 0.75, 0.2, 3.7)
            box(o, "Story", x - 2.5, x - 2.1, y + s * 2.5 - 0.2, y + s * 2.5 + 0.2, 0.2, 8.0)
            box(o, "Story", x + 2.1, x + 2.5, y + s * 2.5 - 0.2, y + s * 2.5 + 0.2, 0.2, 8.0)
            box(o, "Roof", x - 3.0, x + 3.0, y + s * 0.5 - 1.5, y + s * 0.5 + 2.5 if s > 0 else y + s * 0.5 + 1.5, 8.0, 8.3)
    return o


GRAY = {
    "Gray_General": gray_general,
    "Gray_Potion": gray_potion,
    "Gray_Enhance": gray_enhance,
    "Gray_Smithy": gray_smithy,
    "Gray_Bank": gray_bank,
    "Gray_Hospital": gray_hospital,
    "Gray_Inn": gray_inn,
    "Gray_Yard_Smithy": yard_smithy,
    "Gray_Yard_Enhance": yard_enhance,
    "Gray_Yard_Bank": yard_bank,
    "Gray_Yard_Inn": yard_inn,
    "Gray_Yard_Potion": yard_potion,
    "Gray_Yard_Hospital": yard_hospital,
    "Gray_Yard_General": yard_general,
}
SIZE = {"Gray_General": (26, 26), "Gray_Potion": (26, 26), "Gray_Enhance": (26, 26), "Gray_Smithy": (36, 30),
        "Gray_Bank": (36, 30), "Gray_Hospital": (40, 30), "Gray_Inn": (40, 30),
        "Gray_Yard_Smithy": (30, 16), "Gray_Yard_Enhance": (20, 12), "Gray_Yard_Bank": (16, 10), "Gray_Yard_Inn": (26, 14),
        "Gray_Yard_Potion": (20, 16), "Gray_Yard_Hospital": (20, 16), "Gray_Yard_General": (28, 16)}


def kit():
    """snow_plan2.KIT 형식 발자국(로블록스 로컬 x0 x1 z0 z1). 간판이 앞으로 0.6 나온다"""
    return {k: ((-w / 2, w / 2, -d / 2, d / 2), (-w / 2 - 0.6, w / 2 + 0.6, -d / 2 - 0.6, d / 2 + 0.6)) for k, (w, d) in SIZE.items()}


def lua():
    out = ["-- tools/snow_gray.py 가 만든 회색 상자 틀(손으로 고치지 말 것). ServerStorage.SnowKit.Gray_*",
           'local SS = game:GetService("ServerStorage")',
           'local kit = assert(SS:FindFirstChild("SnowKit"), "ServerStorage.SnowKit 이 없다")',
           "local MATS = {"]
    for k, (c, m, coll, tr) in MATS.items():
        out.append('\t%s = { Color3.fromRGB(%d, %d, %d), Enum.Material.%s, %s, %s },' % (k, *c, m, str(coll).lower(), tr))
    out.append("}")
    out.append("local DATA = {")
    for kind, fn in GRAY.items():
        o = fn()
        out.append('\t%s = { boxes = {' % kind)
        for mat, x, y, z, sx, sy, sz in o:
            if sx > 0.01 and sy > 0.01 and sz > 0.01:
                out.append('\t\t{ "%s", %.3f, %.3f, %.3f, %.3f, %.3f, %.3f },' % (mat, -x, z, y, sx, sz, sy))
        t, x, y, z, w, h, both = SIGNS[kind]
        out.append('\t}, sign = { "%s", %.3f, %.3f, %.3f, %.3f, %.3f, %s } },' % (t, -x, z, y, w, h, str(both).lower()))
    out.append("}")
    out.append('''local n = 0
for kind, d in pairs(DATA) do
	local old = kit:FindFirstChild(kind)
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = kind
	for _, b in ipairs(d.boxes) do
		local mt = MATS[b[1]]
		local p = Instance.new("Part")
		p.Name = b[1]
		p.Anchored = true
		p.Size = Vector3.new(b[5], b[6], b[7])
		p.CFrame = CFrame.new(b[2], b[3], b[4])
		p.Color = mt[1]
		p.Material = mt[2]
		p.CanCollide = mt[3]
		p.CanQuery = mt[3]
		p.CanTouch = false
		p.Transparency = mt[4]
		p.CastShadow = mt[4] == 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		n += 1
	end
	local s = d.sign
	local p = Instance.new("Part")
	p.Name = "Sign"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = Vector3.new(s[5], s[6], 0.5)
	p.CFrame = CFrame.new(s[2], s[3], s[4])
	p.Color = MATS.Sign[1]
	p.Material = MATS.Sign[2]
	p.Parent = m
	for _, face in ipairs(s[7] and { Enum.NormalId.Front, Enum.NormalId.Back } or { Enum.NormalId.Front }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.CanvasSize = Vector2.new(s[5] * 40, s[6] * 40)
		g.LightInfluence = 0
		g.Parent = p
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Text = s[1]
		l.TextScaled = true
		l.Font = Enum.Font.GothamBold
		l.TextColor3 = Color3.fromRGB(255, 226, 150)
		l.Parent = g
	end
	m.WorldPivot = CFrame.new()
	m.Parent = kit
end
print("회색 상자 틀", n)
pcall(function()
	game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/gray", "회색 상자 틀 파트 " .. n)
end)''')
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    p = os.path.join(HERE, "Snow_Gray.luau")
    with open(p, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(lua())
    print({k: len(fn()) for k, fn in GRAY.items()}, "→", p)
