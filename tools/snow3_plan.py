# -*- coding: utf-8 -*-
"""
snow3_plan.py — 2026-10-09. 설원 리메이크 설계 다시(사용자: "내가 준 구조도랑 완전히 딴판 — 설계부터 다시").

사용자 답(2026-10-09):
  - 비스듬히 그린 본 지도는 "약간 꺾어서 똑바로 된 상태로" 본다 → 그림을 13° 반시계로 돌려 똑바로 한 뒤 땄다(지상).
    아래쪽 지하 그림은 기울기가 달라 따로 8° 돌려 땄다.
  - 높낮이가 있다. 아래쪽은 지하를 위에서 본 평면도. 히든보스(대태도 청사진)는 지하 깊은 곳.
좌표 = '똑바로 한 그림 좌표'(원본 픽셀 단위, X 동 · Y 남). 지하는 자기 그림 좌표에서 UNDER_SHIFT 만큼 옮겨 지상 아래에 놓는다
  (지하 입구2 가 지상 동굴 입구 2 바로 밑에 오게). 월드 = (X·SCALE + OX, Y·SCALE + OZ).
돌리기: python tools/snow3_plan.py → tools/snow3_plan.svg (똑바로 한 사용자 그림 위에 딴 모양을 겹쳐 그림 — 맞는지 눈으로)
"""
import base64
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SCRATCH = os.environ.get("SNOW_SCRATCH", "")

SCALE = 3.7          # 숲 크기(≈2750)에 맞춤
OX = -2700 - 870 * SCALE   # 섬 동쪽 끝(X 870) → x -2700
OZ = -2330 - 1495 * SCALE  # 섬 남쪽 끝(Y 1495) → z -2330

# ── 지상(똑바로 한 그림 좌표) ── 높이는 제안(사용자 확인 받을 것)
FIELD = 20
ZONES = [
    # 이름, 다각형(시계), 윗면 높이, 색 — 북동 들 남서 비스듬한 변은 두 계단(X 640·670)으로 펴 둠(사용자: 기운 것은 블록을 크게 놓아 보정)
    ("마을", [(172, 997), (370, 997), (390, 1170), (160, 1160)], 60, "#7aa0d8"),
    ("북쪽 들", [(370, 945), (585, 935), (590, 1097), (395, 1100), (390, 1170), (370, 997)], 32, "#e0a060"),
    ("보스룸", [(395, 1100), (590, 1097), (628, 1135), (628, 1270), (595, 1312), (400, 1312)], 40, "#b070c0"),
    ("북동 들", [(600, 977), (715, 977), (720, 1017), (858, 1017), (870, 1280), (855, 1300), (855, 1397), (810, 1420), (670, 1452), (670, 1360), (640, 1360), (640, 1270), (628, 1270), (628, 1135), (590, 1097), (585, 975)], 44, "#d06060"),
    ("남서 필드", [(160, 1160), (390, 1170), (400, 1312), (595, 1312), (628, 1270), (640, 1270), (640, 1360), (670, 1360), (670, 1452), (500, 1492), (490, 1472), (145, 1472), (155, 1325), (132, 1322), (132, 1262)], FIELD, "#60a060"),
]
SPOTS = [  # 이름, X, Y
    ("동굴 입구 2", 293, 1407),
    ("동굴 입구 1", 697, 1318),
    ("순례자의 휴식처 2/8", 632, 1107),
    ("(구)설공방 폐허", 766, 1065),
    ("3번 입구(퀘스트) — 동쪽 벼랑", 866, 1320),
]
# ── 지하(지하 그림 좌표 → 지상 좌표로 옮김) ──
UNDER_SHIFT = (-135, -137)
UNDER_DEPTH = -70     # 지하 굴 바닥 높이
HIDDEN_DEPTH = -110   # 히든 보스 방 바닥(굴보다 깊게)
# 지하 그림 좌표(8° 돌린 그림 기준 원본 px) 상자 { 이름, x0, y0, x1, y1 }
UNDER = [
    ("입구2 방", 401, 1514, 456, 1574),
    ("윗굴(입구2 → 동)", 401, 1538, 625, 1616),
    ("윗굴 동쪽", 625, 1548, 937, 1608),
    ("입구1 굴(3번 입구·동굴 입구1 → 아래)", 942, 1402, 1010, 1626),
    ("비밀벽", 1006, 1470, 1016, 1525),
    ("히든 보스 방 (대태도 청사진)", 1016, 1444, 1145, 1548),
    ("케이브 (서브보스)", 240, 1600, 380, 1751),
    ("아랫굴(케이브 → 금 간 벽)", 380, 1652, 640, 1714),
    ("금이 간 벽", 637, 1652, 646, 1714),
    ("긴 아랫굴(금 간 벽 → 입구1 아래)", 646, 1610, 1067, 1662),
]
# 히든 보스(대태도 청사진) = 지하 동쪽 방(사용자 2026-10-09: 그림 오른쪽 위 네모는 이 방을 가리키는 글).
# 입구1 굴 동쪽 벽의 비밀벽을 지나 더 깊이(HIDDEN_DEPTH) 내려간 방. 위 UNDER 의 "히든 보스 방"


def under_rect(r):
    n, x0, y0, x1, y1 = r
    return n, x0 + UNDER_SHIFT[0], y0 + UNDER_SHIFT[1], x1 + UNDER_SHIFT[0], y1 + UNDER_SHIFT[1]


def world(X, Y):
    return X * SCALE + OX, Y * SCALE + OZ


def svg():
    """위 판: 13° 똑바로 한 지상 그림 + 지상 구역. 아래 판: 8° 똑바로 한 지하 그림 + 지하 굴(그림 자리 그대로)."""
    def b64(name):
        p = os.path.join(SCRATCH, name)
        return base64.b64encode(open(p, "rb").read()).decode() if os.path.exists(p) else ""
    W = 1080
    H1, H2 = 680, 400
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H1 + H2}" font-family="Malgun Gothic, sans-serif">',
         f'<rect width="{W}" height="{H1 + H2}" fill="#fff"/>']

    def label(x, y, t, size=13, col="#111"):
        o.append(f'<text x="{x}" y="{y}" font-size="{size}" fill="{col}" text-anchor="middle" font-weight="700" stroke="#fff" stroke-width="3" paint-order="stroke">{t}</text>')

    # 위 판(그림 좌표 X 90~1170, Y 900~1580)
    o.append(f'<svg x="0" y="0" width="{W}" height="{H1}" viewBox="90 900 {W} {H1}">')
    bg = b64("snow_rot.png")
    if bg:
        o.append(f'<image x="-120" y="760" width="1440" height="1057" opacity="0.6" href="data:image/png;base64,{bg}"/>')
    for name, poly, top, col in ZONES:
        pts = " ".join(f"{x},{y}" for x, y in poly)
        o.append(f'<polygon points="{pts}" fill="{col}" fill-opacity="0.25" stroke="{col}" stroke-width="3"/>')
        cx = sum(p[0] for p in poly) / len(poly)
        cy = sum(p[1] for p in poly) / len(poly)
        label(cx, cy, f"{name} · 높이 {top}")
    for n, x, y in SPOTS:
        o.append(f'<rect x="{x - 7}" y="{y - 7}" width="14" height="14" fill="#2f5fd0" stroke="#fff" stroke-width="2"/>')
        label(x, y - 11, n, 11, "#0b2a6b")
    label(400, 925, f"지상 — 그림을 13° 똑바로 돌림 · 1px = {SCALE} 스터드 → 섬 약 {740 * SCALE:.0f} × {565 * SCALE:.0f}", 15)
    o.append("</svg>")
    # 아래 판(지하 그림 좌표 X 200~1280, Y 1330~1730)
    o.append(f'<svg x="0" y="{H1}" width="{W}" height="{H2}" viewBox="200 1340 {W} {H2}">')
    bg2 = b64("snow_under.png")
    if bg2:
        o.append(f'<image x="180" y="1300" width="1140" height="517" opacity="0.6" href="data:image/png;base64,{bg2}"/>')
    for r in UNDER:
        n, x0, y0, x1, y1 = r
        o.append(f'<rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{y1 - y0}" fill="#8a5a30" fill-opacity="0.22" stroke="#8a5a30" stroke-width="2.5"/>')
        label((x0 + x1) / 2, (y0 + y1) / 2 + 4, n, 10, "#5a2a10")
    label(640, 1362, f"지하(굴 바닥 {UNDER_DEPTH}) — 그림을 8° 똑바로 돌림 · 입구2 가 지상 동굴 입구 2 바로 밑에 오게 놓음", 14)
    o.append("</svg>")
    o.append("</svg>")
    return "\n".join(o)


if __name__ == "__main__":
    open(os.path.join(HERE, "snow3_plan.svg"), "w", encoding="utf-8").write(svg())
    print("ok", world(130, 930), world(870, 1495))
