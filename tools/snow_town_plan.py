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


# ── 짓기 자리(손 표) ── { 틀, 확대 그림 IX, IY, 배율, 바라볼 곳("plaza" | (IX, IY) | 방위 "N/S/E/W"), 이름 }
# 2026-10-09: 마을(약 807×641)이 옛 키트 건물보다 훨씬 커서 건물을 키우되(문이 너무 커지지 않게 1.4~2.0) 빈 구역은 집으로 채운다.
KIT_SIZE = {  # ServerStorage.SnowKit 잰 값 (X, Y, Z, 피벗 기준 가운데 dx, dz)
    "Casino_Hall": (61.6, 37.2, 36.1, -9.8, -1.9), "Clock_Tower": (17.0, 77.4, 17.8, 0.0, -0.4),
    "Figuren_HQ": (50.2, 57.6, 36.6, 0.0, -3.7), "Inn_House": (25.2, 39.3, 27.3, 0.0, 0.0),
    "Observatory": (45.7, 36.6, 38.3, 3.9, -0.1), "Shop_Blue": (19.3, 26.6, 21.0, 1.1, -0.9),
    "Shop_Gold": (19.3, 26.6, 21.0, 1.1, -0.9), "Shop_Red": (19.3, 26.6, 21.0, 1.1, -0.9), "Shop_Teal": (19.3, 26.6, 21.0, 1.1, -0.9),
    "Steam_Factory": (46.5, 69.7, 54.8, 3.6, 0.0), "Steam_House_A": (18.9, 34.3, 15.5, -0.8, -0.5),
    "Steam_House_B": (27.1, 26.8, 17.3, -2.6, -0.6), "Steam_House_C": (18.3, 38.8, 16.2, 0.1, -1.1),
    "Ticket_Booth": (11.8, 14.3, 9.7, -0.6, -0.5), "Under_Gate": (15.0, 13.2, 12.8, 0.0, -0.9),
    "Zapfen_Werk": (86.7, 59.7, 39.0, -3.4, -1.5), "City_Gate": (26.0, 24.3, 6.0, 0.0, 0.0), "Gas_Lamp": (1.9, 12.6, 3.2, 0.0, -0.9),
}
PLAZA_R = 90  # 광장 반지름(스터드)
PLACE = [
    ("Clock_Tower", 348, 567, 1.8, "S", "광장 시계탑"),
    ("Zapfen_Werk", 442, 410, 2.0, "S", "슈네라이히 공방"),
    ("Shop_Blue", 326, 498, 1.4, "plaza", "잡화상점"),
    ("Shop_Gold", 385, 503, 1.4, "plaza", "장비상점"),
    ("Shop_Teal", 280, 536, 1.4, "plaza", "물약상점"),
    ("Shop_Red", 410, 618, 1.4, "plaza", "강화소"),
    ("Inn_House", 296, 636, 1.4, "plaza", "여관"),
    ("Ticket_Booth", 348, 650, 1.4, "plaza", "티켓 판매점"),
    ("Under_Gate", 425, 655, 1.4, "plaza", "지하 입구"),
    ("Observatory", 268, 697, 1.6, "plaza", "천문대 (조율자 전직)"),
    ("Steam_Factory", 224, 577, 1.6, "E", "공장"),
    ("Casino_Hall", 472, 566, 1.6, "W", "카지노+경매장"),
    ("Figuren_HQ", 503, 664, 1.8, "N", "체스판 건물"),
    # 집(빈 구역 채움) — 북서
    ("Steam_House_A", 222, 392, 1.4, "S", "집"), ("Steam_House_B", 252, 388, 1.4, "S", "집"), ("Steam_House_C", 284, 392, 1.4, "S", "집"),
    ("Steam_House_A", 314, 390, 1.4, "S", "집"), ("Steam_House_B", 346, 395, 1.4, "S", "집"),
    ("Steam_House_C", 222, 428, 1.4, "S", "집"), ("Steam_House_A", 252, 430, 1.4, "S", "집"), ("Steam_House_B", 285, 428, 1.4, "S", "집"),
    ("Steam_House_C", 318, 430, 1.4, "S", "집"), ("Steam_House_A", 350, 438, 1.4, "S", "집"),
    ("Steam_House_B", 226, 466, 1.4, "S", "집"), ("Steam_House_C", 258, 470, 1.4, "S", "집"), ("Steam_House_A", 292, 466, 1.4, "S", "집"),
    ("Steam_House_B", 250, 506, 1.4, "E", "집"),
    # 서쪽·남쪽 띠
    ("Steam_House_A", 220, 652, 1.4, "E", "집"), ("Steam_House_C", 218, 712, 1.4, "N", "집"),
    ("Steam_House_C", 322, 708, 1.4, "N", "집"), ("Steam_House_A", 352, 710, 1.4, "N", "집"), ("Steam_House_B", 384, 706, 1.4, "N", "집"),
    ("Steam_House_C", 420, 712, 1.4, "N", "집"),
    # 동쪽 띠
    ("Steam_House_A", 520, 478, 1.4, "W", "집"), ("Steam_House_B", 520, 506, 1.4, "W", "집"), ("Steam_House_C", 524, 612, 1.4, "W", "집"),
    # 마을 문(아래 바위 무리로 올라오는 쪽)
    ("City_Gate", 330, 726, 1.4, "S", "남문"), ("City_Gate", 533, 590, 1.4, "E", "동문"),
]
# 길(돌 판) — 확대 그림 px 꺾은선, 폭 스터드
TOWN_ROADS = [
    ("서쪽 길", [(300, 572), (238, 572)], 22),
    ("동쪽 길", [(396, 560), (440, 560)], 20),
    ("남서 길", [(270, 600), (262, 676)], 20),
    ("북쪽 길", [(440, 548), (440, 462)], 20),
    ("남문 길", [(348, 610), (340, 726)], 22),
    ("동문 길", [(498, 580), (533, 590)], 20),
    ("북서 골목", [(205, 448), (370, 452)], 14),
]


def place_world():
    """→ [(틀, x, z, 배율, yaw(도), 이름)] 와 검사 문제들. yaw = 앞(-Z)이 바라볼 방향(로블록스 Y 돌림, 0 = -Z)"""
    bad = []
    pc = to_world(*PLAZA[:2])
    out = []
    for kit, ix, iy, sc, face, name in PLACE:
        x, z = to_world(ix, iy)
        if face == "plaza":
            dx, dz = pc[0] - x, pc[1] - z
        else:
            dx, dz = {"N": (0, -1), "S": (0, 1), "E": (1, 0), "W": (-1, 0)}[face]
        yaw = math.degrees(math.atan2(-dx, -dz))  # 로블록스: 앞 -Z 를 (dx,dz) 로 → Y 돌림
        out.append((kit, x, z, sc, yaw, name))
    # 발자국(돌린 직사각형의 둘러싼 상자)
    def foot(o):
        kit, x, z, sc, yaw, name = o
        sx, _, sz, ox, oz = KIT_SIZE[kit]
        a = math.radians(yaw)
        c, s = abs(math.cos(a)), abs(math.sin(a))
        w = (sx * c + sz * s) * sc
        d = (sx * s + sz * c) * sc
        # 피벗 기준 가운데 어긋남도 돌린다
        ca, sa = math.cos(a), math.sin(a)
        cx = x + (ox * ca + oz * sa) * sc
        cz = z + (-ox * sa + oz * ca) * sc
        return cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2
    zx0, zz0 = world(TOWN_ZONE[0], TOWN_ZONE[1])
    zx1, zz1 = world(TOWN_ZONE[2], TOWN_ZONE[3])
    fs = [foot(o) for o in out]
    for i, (o, f) in enumerate(zip(out, fs)):
        if o[0] == "City_Gate":
            continue
        if f[0] < zx0 + 2 or f[1] > zx1 - 2 or f[2] < zz0 + 2 or f[3] > zz1 - 2:
            bad.append(f"{o[5]}({o[0]}) 마을 밖으로 나감")
        if o[0] != "Clock_Tower":
            cx, cz = (f[0] + f[1]) / 2, (f[2] + f[3]) / 2
            r = max(f[1] - f[0], f[3] - f[2]) / 2
            if math.hypot(cx - pc[0], cz - pc[1]) < PLAZA_R + r * 0.7:
                bad.append(f"{o[5]}({o[0]}) 광장에 걸침")
        for j in range(i + 1, len(out)):
            g = fs[j]
            if f[0] < g[1] - 3 and f[1] > g[0] + 3 and f[2] < g[3] - 3 and f[3] > g[2] + 3:
                bad.append(f"겹침: {o[5]}({o[0]}) / {out[j][5]}({out[j][0]})")
    return out, bad, pc


def town_data():
    out, bad, pc = place_world()
    lines = ["-- snow_town_plan.py 가 만든 자료(손으로 고치지 말 것)", "local GROUND_Y = 59.8", f"local PLAZA = {{ {pc[0]:.1f}, {pc[1]:.1f}, {PLAZA_R} }}", "local PLACE = {"]
    lines += [f'\t{{ "{k}", {x:.1f}, {z:.1f}, {sc}, {yaw:.1f}, "{n}" }},' for k, x, z, sc, yaw, n in out]
    lines += ["}", "local ROADS = {"]
    for n, pts, w in TOWN_ROADS:
        ws = ", ".join(f"{{ {to_world(a, b)[0]:.1f}, {to_world(a, b)[1]:.1f} }}" for a, b in pts)
        lines.append(f'\t{{ "{n}", {w}, {{ {ws} }} }},')
    lines.append("}")
    return "\n".join(lines) + "\n", bad


if __name__ == "__main__" and "--town" in sys.argv:
    txt, bad = town_data()
    for p in bad:
        print("문제:", p)
    open(os.path.join(HERE, "Snow_Town_data.luau"), "w", encoding="utf-8", newline="\n").write(txt)
    print("자리", len(PLACE), "문제", len(bad))
