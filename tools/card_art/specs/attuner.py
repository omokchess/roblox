# -*- coding: utf-8 -*-
# 조율자 카드 그림 — 북두칠성·별·화상/융해·수호·신앙(2026-10-25)
from cards import *  # noqa: F401,F403

GOLD = "#ffe28c"
MELT = "#ff5aa8"
FIRE = "#ff9450"
PALE = "#bed6ff"

# 북두칠성 별 자리(메달리온 안, 손잡이 → 국자)
DIPPER = [(0.16, 0.36), (0.3, 0.3), (0.43, 0.37), (0.54, 0.47), (0.58, 0.68), (0.82, 0.72), (0.85, 0.48)]


def dipper(A, sx=1.0, sy=1.0, ox=0.0, oy=0.0, lit=7, color=WHITE, w=THIN):
    pts = [(ox + (x - 0.5) * sx + 0.5, oy + (y - 0.5) * sy + 0.5) for x, y in DIPPER]
    A.poly(pts[:4], w=w, color=color, tr=0.35)
    A.poly([pts[3], pts[4], pts[5], pts[6], pts[3]], w=w, color=color, tr=0.35)
    for i, (x, y) in enumerate(pts):
        star(A, x, y, 0.045 * max(sx, 0.6), 5, 0.45, color=GOLD if i < lit else WHITE, w=THIN, filled=i < lit)
    return pts


@art("Attuner_E_GuardStar")  # 지키기 위한 별: 방패 위 별
def _(A):
    shield(A, C, 0.56, 0.62, color=WHITE, w=LINE)
    star(A, C, 0.52, 0.16, 5, 0.45, color=A.accent, w=LINE, filled=True)
    A.arc(C, 0.52, 0.3, 200, 340, w=THIN, color=GOLD)


@art("Attuner_E_BurnStar")  # 태우기 위한 별: 불꽃 속 별
def _(A):
    flame(A, C, 0.56, 0.62, color=FIRE)
    star(A, C, 0.6, 0.12, 5, 0.45, color=GOLD, w=LINE, filled=True)
    dots(A, [(0.26, 0.34), (0.74, 0.3), (0.8, 0.62)], 0.02, MELT)


@art("Attuner_E_Alcor")  # 알코르: 미자르 곁의 작은 여덟 번째 별
def _(A):
    dipper(A, 0.86, 0.86, 0, 0.04, lit=7, color=WHITE)
    star(A, 0.36, 0.2, 0.05, 5, 0.45, color=A.accent, w=THIN, filled=True)
    A.ring(0.36, 0.2, 0.08, w=THIN, color=A.accent, tr=0.4)


@art("Attuner_E_Oracle")  # 신탁: 별을 받드는 두 손과 빛
def _(A):
    hand_open(A, 0.36, 0.7, 0.36)
    hand_open(A, 0.64, 0.7, 0.36)
    star(A, C, 0.36, 0.14, 5, 0.45, color=GOLD, w=LINE, filled=True)
    rays(A, C, 0.36, 0.18, 0.28, 8, 22, color=A.accent, w=THIN)


@art("Attuner_R_Meteor")  # 유성우: 비스듬히 떨어지는 별똥별들
def _(A):
    for x, y, L in ((0.36, 0.3, 0.34), (0.62, 0.42, 0.4), (0.44, 0.62, 0.3), (0.76, 0.22, 0.26)):
        comet(A, x, y, 0.035, -35, L, color=FIRE, head=GOLD)


@art("Attuner_R_Furnace")  # 용광로 별: 도가니 위로 녹아 흐르는 별
def _(A):
    bowl(A, C, 0.66, 0.6)
    star(A, C, 0.38, 0.16, 5, 0.45, color=GOLD, w=LINE, filled=True)
    drop(A, 0.42, 0.56, 0.12, color=MELT)
    drop(A, 0.6, 0.6, 0.1, color=MELT)


@art("Attuner_R_Binary")  # 쌍성: 서로 도는 두 별
def _(A):
    A.ellipse(C, C, 0.3, 0.16, -20, w=THIN, color=WHITE, tr=0.3)
    star(A, 0.32, 0.58, 0.1, 5, 0.45, color=GOLD, w=LINE, filled=True)
    star(A, 0.68, 0.42, 0.08, 5, 0.45, color=A.accent, w=LINE, filled=True)


@art("Attuner_R_StarMap")  # 별자리 지도: 펼친 두루마리 위 별자리
def _(A):
    A.rect(C, C, 0.72, 0.52, 0, WHITE, 0.06, LINE)
    dipper(A, 0.62, 0.5, 0, 0, lit=2, color=A.accent)


@art("Attuner_R_Polaris")  # 북극성: 크고 밝은 별 하나와 도는 별자리
def _(A):
    sparkle(A, C, 0.42, 0.18, color=GOLD, w=LINE * 1.3)
    A.arc(C, 0.42, 0.32, 20, 160, w=THIN, color=WHITE, tr=0.3)
    A.arc(C, 0.42, 0.24, 200, 330, w=THIN, color=A.accent, tr=0.2)
    shield(A, C, 0.74, 0.22, color=WHITE, w=THIN)


@art("Attuner_R_Stigmata")  # 별의 상흔: 손바닥에 새겨진 별
def _(A):
    hand_open(A, C, 0.58, 0.6)
    star(A, C, 0.6, 0.09, 5, 0.45, color=FIRE, w=LINE, filled=True)
    A.ring(C, 0.6, 0.14, w=THIN, color=A.accent, tr=0.4)


@art("Attuner_R_Vigil")  # 철야 기도: 초와 별
def _(A):
    candle(A, 0.44, 0.6, 0.5, fire=GOLD)
    star(A, 0.7, 0.28, 0.07, 5, 0.45, color=A.accent, w=THIN, filled=True)
    moon(A, 0.26, 0.26, 0.1, color=WHITE, w=THIN)


@art("Attuner_R_Mirage")  # 신기루: 흐릿하게 겹친 별 그림자
def _(A):
    for i, tr in enumerate((0.7, 0.45, 0.0)):
        star(A, 0.36 + i * 0.14, 0.5, 0.16, 5, 0.45, color=A.accent if i == 2 else WHITE, w=LINE, filled=False)
        A.shapes[-1]["Transparency"] = tr


@art("Attuner_R_RedGiant")  # 적색거성: 부푼 붉은 별과 번지는 고리
def _(A):
    A.disc(C, C, 0.22, FIRE, tr=0.2)
    A.ring(C, C, 0.3, w=THIN, color=MELT, tr=0.3)
    A.ring(C, C, 0.38, w=THIN, color=MELT, tr=0.6)
    for ang in (30, 150, 270):
        x, y = polar(C, C, 0.36, ang)
        A.disc(x, y, 0.03, MELT)


@art("Attuner_R_Sunspot")  # 흑점: 해에 박힌 어두운 점
def _(A):
    sun(A, C, C, 0.2, color=GOLD, n=12)
    A.disc(0.56, 0.46, 0.06, "#3a2a46")
    A.disc(0.44, 0.58, 0.035, "#3a2a46")


@art("Attuner_C_Starlight")  # 별빛 조준: 별 너머 과녁
def _(A):
    target(A, C, C, 0.28, color=WHITE, dot=A.accent)
    sparkle(A, 0.72, 0.28, 0.08, color=GOLD)


@art("Attuner_C_Ember")  # 메그레즈의 불씨: 별에서 떨어지는 분홍 불티
def _(A):
    star(A, 0.4, 0.36, 0.13, 5, 0.45, color=GOLD, w=LINE, filled=True)
    for x, y in ((0.52, 0.56), (0.62, 0.68), (0.46, 0.74)):
        flame(A, x, y, 0.14, color=MELT, inner=False)


@art("Attuner_C_Orbit")  # 메라크의 궤도: 별이 되돌아오는 고리 화살
def _(A):
    loop_arrow(A, C, C, 0.26, color=A.accent)
    star(A, C, C, 0.1, 5, 0.45, color=GOLD, w=LINE, filled=True)


@art("Attuner_C_Flare")  # 알리오스의 섬광: 별에서 뻗는 빛살
def _(A):
    star(A, C, C, 0.14, 5, 0.45, color=GOLD, w=LINE, filled=True)
    rays(A, C, C, 0.2, 0.36, 12, 0, color=FIRE, w=THIN)


@art("Attuner_C_Roof")  # 두베의 지붕: 별 아래 지붕
def _(A):
    A.poly([(0.18, 0.6), (0.5, 0.32), (0.82, 0.6)], w=LINE * 1.2, color=WHITE)
    A.line(0.26, 0.6, 0.26, 0.8, w=LINE)
    A.line(0.74, 0.6, 0.74, 0.8, w=LINE)
    star(A, C, 0.2, 0.08, 5, 0.45, color=A.accent, w=THIN, filled=True)


@art("Attuner_C_StarPilgrim")  # 별 순례: 별을 따라가는 발자국
def _(A):
    footprints(A, 0.42, 0.66, 0.5, ang=-60, n=3)
    star(A, 0.72, 0.26, 0.09, 5, 0.45, color=GOLD, w=LINE, filled=True)


@art("Attuner_C_Observe")  # 관측: 별을 보는 망원경
def _(A):
    A.rect(0.42, 0.56, 0.5, 0.12, -30, WHITE, 0.3, LINE)
    A.line(0.4, 0.62, 0.3, 0.84, w=LINE)
    A.line(0.44, 0.62, 0.54, 0.84, w=LINE)
    sparkle(A, 0.76, 0.24, 0.08, color=A.accent)


@art("Attuner_C_Cinder")  # 남은 불티: 쓰러진 자리에서 옮겨 가는 불씨
def _(A):
    flame(A, 0.34, 0.62, 0.36, color=FIRE)
    arrow(A, 0.46, 0.5, 0.74, 0.36, color=A.accent, w=THIN)
    flame(A, 0.78, 0.34, 0.16, color=FIRE, inner=False)


@art("Attuner_C_Radiance")  # 성광: 빛나는 십자 별
def _(A):
    sparkle(A, C, C, 0.26, color=WHITE, w=LINE * 1.2)
    A.ring(C, C, 0.34, w=THIN, color=A.accent, tr=0.4)
    heart(A, C, 0.82, 0.12, color=A.accent, filled=True)


@art("Attuner_C_Devout")  # 경건: 모은 두 손과 내리는 빛
def _(A):
    A.poly([(0.42, 0.78), (0.5, 0.42), (0.58, 0.78)], w=LINE * 1.2)
    A.line(0.5, 0.42, 0.5, 0.78, w=THIN)
    rays(A, C, 0.24, 0.06, 0.16, 7, 200, color=GOLD, w=THIN, spread=140)


@art("Attuner_C_Rosary")  # 묵주: 구슬 고리에 달린 별
def _(A):
    for i in range(12):
        x, y = polar(C, 0.44, 0.24, i * 30)
        A.disc(x, y, 0.022, WHITE)
    A.line(C, 0.68, C, 0.78, w=THIN)
    star(A, C, 0.82, 0.07, 5, 0.45, color=A.accent, w=THIN, filled=True)


@art("Attuner_C_Lens")  # 중력 렌즈: 휘어지는 빛과 가운데 점
def _(A):
    A.disc(C, C, 0.08, "#2a2640")
    A.ring(C, C, 0.12, w=THIN, color=GOLD)
    for k in (0.2, 0.28):
        A.arc(C, C, k, 200, 340, w=THIN, color=WHITE, tr=0.2)
        A.arc(C, C, k, 20, 160, w=THIN, color=A.accent, tr=0.2)


@art("Attuner_C_MeltPoint")  # 녹는점: 녹아내리는 방울과 눈금
def _(A):
    A.rect(0.34, 0.5, 0.1, 0.5, 0, WHITE, 0.4, LINE)
    A.disc(0.34, 0.74, 0.06, MELT)
    drop(A, 0.64, 0.42, 0.2, color=MELT)
    drop(A, 0.7, 0.72, 0.1, color=MELT)


@art("Attuner_C_Cluster")  # 별무리: 모여 빛나는 작은 별들
def _(A):
    for x, y, r in ((0.4, 0.4, 0.07), (0.58, 0.36, 0.05), (0.5, 0.56, 0.08), (0.34, 0.62, 0.05), (0.66, 0.6, 0.06)):
        star(A, x, y, r, 5, 0.45, color=GOLD if r > 0.06 else WHITE, w=THIN, filled=True)
    A.ring(C, C, 0.3, w=THIN, color=A.accent, tr=0.5)


@art("Attuner_C_Hymn")  # 찬송: 펼친 책 위로 떠오르는 별
def _(A):
    book(A, C, 0.66, 0.56)
    star(A, C, 0.3, 0.09, 5, 0.45, color=GOLD, w=LINE, filled=True)
    note(A, 0.72, 0.36, 0.16, color=A.accent)


@art("Attuner_C_Devotion")  # 헌신의 별: 별을 감싼 하트
def _(A):
    heart(A, C, 0.52, 0.56, color=WHITE, filled=False, w=LINE)
    star(A, C, 0.5, 0.1, 5, 0.45, color=A.accent, w=LINE, filled=True)


@art("Attuner_C_HeatCycle")  # 열 순환: 불꽃을 도는 화살
def _(A):
    flame(A, C, 0.52, 0.32, color=FIRE)
    A.arc(C, C, 0.32, -60, 200, w=THIN, color=A.accent)
    arrow(A, 0.26, 0.74, 0.2, 0.62, color=A.accent, w=THIN)


@art("Attuner_C_Sanctum")  # 성소: 아치 안의 별
def _(A):
    arch(A, C, 0.56, 0.5, 0.56, color=WHITE, w=LINE)
    star(A, C, 0.5, 0.1, 5, 0.45, color=A.accent, w=LINE, filled=True)


@art("Attuner_C_Psalm")  # 시편: 별이 그려진 펼친 책장과 모래시계
def _(A):
    book(A, 0.44, 0.62, 0.48)
    hourglass(A, 0.74, 0.34, 0.26, color=A.accent, w=THIN)
    star(A, 0.32, 0.3, 0.06, 5, 0.45, color=GOLD, w=THIN, filled=True)


@art("Attuner_C_Twinkle")  # 반짝임: 깜빡이는 별 둘
def _(A):
    sparkle(A, 0.4, 0.44, 0.16, color=GOLD, w=LINE)
    sparkle(A, 0.68, 0.64, 0.09, color=A.accent, w=THIN)
    dots(A, [(0.26, 0.7), (0.74, 0.28)], 0.015, WHITE)
