# -*- coding: utf-8 -*-
"""
snow_town_plan.py — 2026-10-09. 설원 마을(슈네라이히) 배치 — 사용자 그림의 마을 확대 그림(설원 지도.jpg 위 왼쪽)을 그대로 땄다.

좌표 = 확대 그림 원본 px(IX, IY). 마을 칸 = (205..535, 365..730)(위로 튀어나온 공방 포함). 이것을 승인된 지상 설계(snow3_plan)의
마을 구역(똑바로 한 그림 좌표 X 172..390, Y 997..1170)에 넣는다(가로 0.66배·세로 0.47배 — 확대 그림이 더 길쭉함).
돌리기: python tools/snow_town_plan.py → tools/snow_town_plan.svg (확대 그림 위에 겹쳐 그림)
"""
import base64
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from snow3_plan import world  # noqa: E402

INSET = (205, 365, 535, 730)
TOWN_ZONE = (172, 997, 390, 1170)
SCRATCH = os.environ.get("SNOW_SCRATCH", "")

# 건물 { 이름, 종류, IX0, IY0, IX1, IY1, 돌림(도, 그림에서 기울어 그린 것), 메모 }
BUILDINGS = [
    ("슈네라이히 공방", "workshop", 370, 365, 515, 460, 0, "위로 튀어나온 큰 공방(옛 차펜 공방 틀 + 늘림)"),
    ("광장 시계탑", "clock", 322, 552, 362, 587, 0, "팔각 광장 가운데"),
    ("잡화상점", "shop", 310, 490, 343, 507, -8, "광장 북"),
    ("장비상점", "shop", 367, 490, 402, 517, 25, "광장 북동"),
    ("물약상점", "shop", 270, 515, 292, 557, -25, "광장 북서"),
    ("강화소", "shop", 395, 592, 422, 642, 25, "광장 남동"),
    ("여관", "inn", 282, 622, 312, 647, 30, "광장 남서"),
    ("티켓 판매점", "booth", 325, 637, 365, 657, 0, "광장 남"),
    ("지하 입구", "stairs", 410, 635, 435, 670, 0, "강화소 아래"),
    ("천문대 (조율자 전직)", "observatory", 245, 670, 295, 720, 0, "남서 모서리, 둥근 지붕"),
    ("공장", "factory", 187, 530, 242, 625, 0, "서쪽, 굴뚝"),
    ("카지노+경매장", "casino", 440, 527, 500, 605, 0, "동쪽"),
    ("체스판 건물", "chess", 457, 635, 550, 690, 0, "남동(옛 기물군 본부 틀)"),
]
PLAZA = (348, 567, 53)  # 팔각 광장 가운데·반지름(그림 px)
ROADS = [  # { 이름, 점들(그림 px), 폭 px }
    ("서쪽 길(광장→공장)", [(295, 572), (242, 572)], 12),
    ("동쪽 길(광장→카지노)", [(400, 545), (445, 545)], 10),
    ("남서 길(→천문대)", [(262, 590), (262, 672)], 12),
    ("북쪽 길(→공방)", [(448, 590), (448, 460)], 12),
]


def to_town(ix, iy):
    """확대 그림 px → 똑바로 한 지상 그림 좌표"""
    a, b, c, d = INSET
    X0, Y0, X1, Y1 = TOWN_ZONE
    return X0 + (ix - a) / (c - a) * (X1 - X0), Y0 + (iy - b) / (d - b) * (Y1 - Y0)


def to_world(ix, iy):
    return world(*to_town(ix, iy))


def svg():
    p = os.path.join(SCRATCH, "town_inset_raw.png")
    bg = base64.b64encode(open(p, "rb").read()).decode() if os.path.exists(p) else ""
    o = ['<svg xmlns="http://www.w3.org/2000/svg" width="820" height="880" viewBox="150 340 410 440" font-family="Malgun Gothic, sans-serif">',
         '<rect x="150" y="340" width="410" height="440" fill="#fff"/>']
    if bg:
        o.append(f'<image x="150" y="340" width="410" height="440" opacity="0.55" href="data:image/png;base64,{bg}"/>')
    a, b, c, d = INSET
    o.append(f'<rect x="{a}" y="{b}" width="{c - a}" height="{d - b}" fill="none" stroke="#2050c0" stroke-width="1.5" stroke-dasharray="4 2"/>')
    cx, cy, r = PLAZA
    pts = " ".join(f"{cx + r * math.cos(math.radians(22.5 + 45 * k)):.1f},{cy + r * math.sin(math.radians(22.5 + 45 * k)):.1f}" for k in range(8))
    o.append(f'<polygon points="{pts}" fill="#d8c8a0" fill-opacity="0.35" stroke="#a08040" stroke-width="1.5"/>')
    for n, pts_, w in ROADS:
        o.append('<polyline points="' + " ".join(f"{x},{y}" for x, y in pts_) + f'" fill="none" stroke="#a08050" stroke-opacity="0.5" stroke-width="{w}"/>')
    col = {"workshop": "#b07040", "clock": "#806020", "shop": "#3070c0", "inn": "#8040c0", "booth": "#c03030", "stairs": "#303030",
           "observatory": "#304880", "factory": "#606060", "casino": "#a03050", "chess": "#404040"}
    for n, kind, x0, y0, x1, y1, rot, memo in BUILDINGS:
        c_ = col[kind]
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        if kind == "observatory":
            o.append(f'<circle cx="{mx}" cy="{my}" r="{(x1 - x0) / 2}" fill="{c_}" fill-opacity="0.35" stroke="{c_}" stroke-width="1.5"/>')
        else:
            o.append(f'<rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{y1 - y0}" transform="rotate({rot} {mx} {my})" fill="{c_}" fill-opacity="0.35" stroke="{c_}" stroke-width="1.5"/>')
        o.append(f'<text x="{mx}" y="{my + 3}" font-size="7" text-anchor="middle" font-weight="700" fill="#111" stroke="#fff" stroke-width="2" paint-order="stroke">{n}</text>')
    o.append('<text x="156" y="352" font-size="9" font-weight="700">바탕 = 마을 확대 그림 · 칠한 칸 = 제가 읽은 건물 자리(점선 = 마을 칸)</text>')
    o.append("</svg>")
    return "\n".join(o)


if __name__ == "__main__":
    open(os.path.join(HERE, "snow_town_plan.svg"), "w", encoding="utf-8").write(svg())
    for n, kind, x0, y0, x1, y1, rot, memo in BUILDINGS:
        (wx0, wz0), (wx1, wz1) = to_world(x0, y0), to_world(x1, y1)
        print(f"{n:16s} 월드 {wx1 - wx0:5.0f} × {wz1 - wz0:5.0f} 가운데 ({(wx0 + wx1) / 2:.0f}, {(wz0 + wz1) / 2:.0f})")
