# -*- coding: utf-8 -*-
"""
snow2_plan.py — 2026-10-09. 설원 리메이크 배치표(1단계: 구역) → tools/snow2_plan.svg

사용자 그림(C:\\프롬때 쓴 그림판\\설원 지도.jpg) + 답(2026-10-09):
  - 마을 위 긴 건물 = 슈네라이히 공방, 필드 북동 폐허 = (구)설공방(폐허). (둘 다 '공방')
  - 크기: 사용자 정정 — "설원 전체는 숲 크기랑 비슷해야 해"(숲 2판 ≈ 2750×2840) → **그림 1px ≈ 3.4 스터드**(SCALE).
    ("□←플레이어 크기" 네모는 어림 표시라 축척으로 쓰지 않는다.)
  - 지금 슈네라이히는 새 배치로 다시, 스팀펑크 키트·방은 다시 씀(옛 도시는 백업).
그림 → 로컬 좌표(스터드): 원점 = 그림 (200, 900) 근처. 마을 확대 그림(위 왼쪽)도 같은 축척(마을 칸 ≈ 315×255px ≈ 그림 본 지도 마을 칸).
지상(위) + 지하(아래 — 동굴 입구 1·2, 3번 입구(퀘스트), 케이브(서브보스), 비밀벽, 금이 간 벽, 히든 보스(대태도 청사진)).
월드 자리(ORIGIN): 지금 슈네라이히 고원 자리 근처. 돌리기: python tools/snow2_plan.py → tools/snow2_plan.svg
좌표 = 로컬 그림 px(x 동, z 남). 월드 = ORIGIN + 로컬 × SCALE.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SCALE = 3.4  # 그림 1px → 스터드. 아래 표는 그림 px(로컬)로 적고, 월드 = ORIGIN + 로컬 × SCALE
ORIGIN = (-5400, -4100)  # 로컬 (0,0) 의 월드 x, z — 지금 설원 섬 자리에서 북쪽(빈 바다)으로 넓힌다. 동쪽 끝 ≈ -2340(화산 -2037 앞)
GROUND_Y = 78  # 지금 슈네라이히 고원 높이

# ── 지상 ── (그림 본 지도를 축에 맞춘 상자로)
LAND = [  # 땅 판 { x0, z0, x1, z1 }
    (0, 0, 330, 280),      # 마을 고원(북서)
    (330, 30, 700, 150),   # 북쪽 들(설공방 폐허 쪽)
    (0, 280, 720, 560),    # 큰 필드(남)
    (330, 150, 720, 280),  # 필드 북동
]
ZONES = [  # { 이름, x0, z0, x1, z1, 색 }
    ("마을 (슈네라이히)", 0, 0, 330, 280, "#9ab8d8"),
    ("보스룸", 230, 170, 520, 340, "#c0a0d0"),
    ("히든 보스 (대태도 청사진)", 780, 300, 900, 520, "#d07070"),
]
SPOTS = [  # { 이름, x, z }
    ("(구)설공방 (폐허)", 600, 90),
    ("순례자의 휴식처 2/8", 470, 210),
    ("동굴 입구 1", 460, 450),
    ("동굴 입구 2", 120, 400),
    ("3번 입구 (퀘스트 필요)", 740, 470),
]
# ── 지하 ── (그림 아래 칸: 입구 아래로 이어지는 굴)
CAVES = [  # { 이름, x0, z0, x1, z1 }
    ("입구1 굴", 420, 560, 520, 640),
    ("입구2 굴", 80, 560, 200, 640),
    ("케이브 (서브보스)", 30, 640, 200, 760),
    ("가운데 굴", 200, 640, 640, 700),
    ("금이 간 벽 앞 굴", 380, 700, 640, 760),
    ("비밀벽 굴", 640, 560, 780, 700),
]
WALLS = [  # 특별한 벽 { 이름, x, z }
    ("비밀벽", 760, 610),
    ("금이 간 벽", 400, 760),
]

# ── 마을(확대 그림) ── 로컬, 1px ≈ 1 스터드. { 이름, x0, z0, x1, z1, 색 }
TOWN = [
    ("슈네라이히 공방", 240, 0, 300, 230, "#b08860"),
    ("공장", 0, 70, 40, 140, "#8a7a6a"),
    ("광장(시계)", 90, 55, 200, 170, "#d8d0b8"),
    ("잡화상점", 120, 40, 175, 55, "#5a7ad0"),
    ("장비상점", 175, 22, 205, 38, "#d0b030"),
    ("물약상점", 45, 45, 80, 95, "#40b0a0"),
    ("강화소", 205, 115, 222, 170, "#d0b030"),
    ("카지노+경매장", 250, 70, 300, 225, "#a05050"),
    ("여관", 85, 190, 115, 220, "#8050c0"),
    ("티켓 판매점", 130, 210, 170, 230, "#d04040"),
    ("지하 입구", 180, 185, 205, 230, "#404040"),
    ("천문대 (조율자 전직)", 20, 220, 100, 280, "#304878"),
    ("체스판 건물", 230, 230, 320, 260, "#606060"),
]


def svg():
    s = 1.0
    W, H = 960, 1180
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="Malgun Gothic, sans-serif">',
         f'<rect width="{W}" height="{H}" fill="#203040"/>']

    def rect(x0, z0, x1, z1, fill, dx=20, dz=30, op=1, stroke="#111", sw=1.5):
        o.append(f'<rect x="{dx + x0 * s}" y="{dz + z0 * s}" width="{(x1 - x0) * s}" height="{(z1 - z0) * s}" fill="{fill}" fill-opacity="{op}" stroke="{stroke}" stroke-width="{sw}"/>')

    def text(x, z, t, dx=20, dz=30, size=12, col="#111", anchor="middle"):
        o.append(f'<text x="{dx + x * s}" y="{dz + z * s}" font-size="{size}" fill="{col}" text-anchor="{anchor}" font-weight="700" stroke="#fff" stroke-width="2.5" paint-order="stroke">{t}</text>')

    o.append('<text x="20" y="20" font-size="15" fill="#fff" font-weight="700">설원 지상 — 그림 1px = 3.4 스터드 · 전체 약 3060 × 1900</text>')
    for x0, z0, x1, z1 in LAND:
        rect(x0, z0, x1, z1, "#e8eef4", sw=0)
    o.append('<defs><pattern id="h" width="24" height="24" patternUnits="userSpaceOnUse" patternTransform="rotate(-35)"><line x1="0" y1="0" x2="0" y2="24" stroke="#d24a3c" stroke-width="2" stroke-opacity="0.5"/></pattern></defs>')
    for x0, z0, x1, z1 in LAND[1:]:
        rect(x0, z0, x1, z1, "url(#h)", sw=0)
    for n, x0, z0, x1, z1, c in ZONES:
        rect(x0, z0, x1, z1, c, op=0.85)
        text((x0 + x1) / 2, (z0 + z1) / 2 + 4, n)
    for n, x, z in SPOTS:
        rect(x - 8, z - 8, x + 8, z + 8, "#2f5fd0", stroke="#fff")
        text(x + 12, z + 4, n, anchor="start", size=11)
    # 1000 스터드 자
    rect(20, 540, 20 + 1000 / SCALE, 545, "#000")
    text(20 + 500 / SCALE, 536, "1000 스터드", size=10)
    # 지하
    dz2 = 30
    o.append(f'<text x="20" y="{dz2 + 575}" font-size="15" fill="#fff" font-weight="700">지하(굴) — 입구 1·2·3 아래</text>')
    for n, x0, z0, x1, z1 in CAVES:
        rect(x0, z0, x1, z1, "#6a5a4a", dz=dz2 + 20, op=0.9)
        text((x0 + x1) / 2, (z0 + z1) / 2 + 4, n, dz=dz2 + 20, size=11)
    for n, x, z in WALLS:
        rect(x - 6, z - 12, x + 6, z + 12, "#c8a040", dz=dz2 + 20)
        text(x, z - 16, n, dz=dz2 + 20, size=11)
    # 마을 확대
    tx, tz = 20, 860
    o.append(f'<text x="{tx}" y="{tz - 8}" font-size="15" fill="#fff" font-weight="700">마을 확대(같은 축척) — 약 1120 × 950 스터드</text>')
    rect(0, 0, 330, 280, "#dfe8f0", dx=tx, dz=tz)
    for n, x0, z0, x1, z1, c in TOWN:
        if n.startswith("광장"):
            cx, cz, r = (x0 + x1) / 2, (z0 + z1) / 2, (x1 - x0) / 2
            import math
            pts = " ".join(f"{tx + cx + r * math.cos(math.radians(22.5 + 45 * k))},{tz + cz + r * math.sin(math.radians(22.5 + 45 * k))}" for k in range(8))
            o.append(f'<polygon points="{pts}" fill="{c}" stroke="#111"/>')
            o.append(f'<circle cx="{tx + cx}" cy="{tz + cz}" r="14" fill="#a08850" stroke="#111"/>')
        elif n.startswith("천문대"):
            o.append(f'<circle cx="{tx + (x0 + x1) / 2}" cy="{tz + (z0 + z1) / 2}" r="{(x1 - x0) / 2}" fill="{c}" stroke="#111"/>')
        else:
            rect(x0, z0, x1, z1, c, dx=tx, dz=tz, op=0.9)
        text((x0 + x1) / 2, (z0 + z1) / 2 + 4, n, dx=tx, dz=tz, size=10)
    o.append("</svg>")
    return "\n".join(o)


if __name__ == "__main__":
    open(os.path.join(HERE, "snow2_plan.svg"), "w", encoding="utf-8").write(svg())
    print("ok")
