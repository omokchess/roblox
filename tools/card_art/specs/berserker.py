# -*- coding: utf-8 -*-
# 광전사 카드 그림
from cards import *  # noqa: F401,F403


@art("Berserker_E_Brink")  # 벼랑 끝: 무너지는 절벽 끝에 꽂힌 칼
def _(A):
    A.poly([(0.12, 0.64), (0.52, 0.64), (0.47, 0.72), (0.54, 0.8), (0.45, 0.9)], w=LINE)
    A.line(0.12, 0.64, 0.12, 0.9, w=THIN, tr=0.5)
    sword(A, 0.44, 0.4, 0.5, 90)
    for (x, y, sz) in ((0.64, 0.72, 0.035), (0.7, 0.82, 0.025), (0.6, 0.88, 0.02)):
        A.diamond(x, y, sz, A.accent)
    A.arc(0.5, 0.64, 0.12, 200, 340, w=THIN, color=A.accent, tr=0.3)


@art("Berserker_E_Undying")  # 불굴: 금 간 방패 뒤에서 버티는 칼
def _(A):
    shield(A, C, 0.5, 0.66)
    crack(A, C, 0.47, 0.46, 80, color=A.accent, w=THIN * 1.3)
    sword(A, C, 0.47, 0.34, -90, w=THIN * 1.2)


@art("Berserker_R_Frenzy")  # 광란: 교차한 두 도끼와 불똥
def _(A):
    axe(A, 0.46, 0.54, 0.64, -120, flip=True)
    axe(A, 0.54, 0.54, 0.64, -60)
    sparkle(A, 0.5, 0.2, 0.06, color=A.accent, w=THIN)
    sparkle(A, 0.2, 0.32, 0.04, color=A.accent, w=THIN)
    sparkle(A, 0.8, 0.32, 0.04, color=A.accent, w=THIN)


@art("Berserker_R_Wrath")  # 격노: 불꽃 속 주먹
def _(A):
    flame(A, C, 0.45, 0.78, color=A.accent, inner=False)
    fist(A, C, 0.56, 0.42)


@art("Berserker_R_Reckless")  # 무모: 금 간 방패를 버리고 앞으로
def _(A):
    chevrons(A, 0.6, 0.5, 0.42, 3, 0, gap=0.13, color=A.accent)
    shield(A, 0.27, 0.56, 0.38, w=THIN * 1.3)
    crack(A, 0.27, 0.54, 0.26, 90, w=THIN)


@art("Berserker_R_SecondWind")  # 재기: 다시 뛰는 심장
def _(A):
    heart(A, C, 0.46, 0.72)
    pulse(A, C, 0.47, 0.6, 0.24, color=A.accent)


@art("Berserker_R_Sweep")  # 휩쓸기: 크게 도는 도끼 궤적
def _(A):
    A.arc(C, 0.52, 0.34, 200, 470, w=LINE * 1.3, color=A.accent)
    A.arc(C, 0.52, 0.25, 220, 440, w=THIN, tr=0.3)
    axe(A, 0.6, 0.4, 0.42, -40)


@art("Berserker_R_PainTolerance")  # 견딤: 이를 악문 방패
def _(A):
    shield(A, C, 0.5, 0.68)
    fangs(A, C, 0.5, 0.5, color=A.accent)


@art("Berserker_R_Momentum")  # 가속: 이어지는 칼질 잔상
def _(A):
    for i, tr in enumerate((0.65, 0.35, 0.0)):
        A.arc(0.32 + i * 0.13, 0.6, 0.3, 235, 305, w=LINE * 1.2, tr=tr)
    axe(A, 0.64, 0.4, 0.36, -50)
    chevrons(A, 0.5, 0.78, 0.2, 3, 0, gap=0.08, color=A.accent, w=THIN)


@art("Berserker_R_Scars")  # 상흔: 꿰맨 흉터 세 줄
def _(A):
    A.ring(C, C, 0.33, w=THIN, tr=0.5)
    for dx in (-0.11, 0, 0.11):
        A.line(0.35 + dx, 0.28, 0.61 + dx, 0.72, w=LINE * 1.3, color=A.accent)
        for t in (0.3, 0.55, 0.8):
            x, y = 0.35 + dx + 0.26 * t, 0.28 + 0.44 * t
            A.line(x - 0.035, y + 0.02, x + 0.035, y - 0.02, w=THIN * 0.8)


@art("Berserker_R_Roar")  # 히스테릭: 울부짖는 입과 퍼지는 소리
def _(A):
    fangs(A, 0.38, 0.52, 0.5)
    for r, tr in ((0.16, 0.0), (0.25, 0.3), (0.34, 0.55)):
        A.arc(0.48, 0.5, r, -40, 40, w=LINE, color=A.accent, tr=tr)


@art("Berserker_C_Ember")  # 불씨
def _(A):
    flame(A, C, 0.52, 0.52, color=A.accent)
    dots(A, [(0.32, 0.3), (0.68, 0.24), (0.66, 0.74), (0.3, 0.7)], 0.016, A.accent)


@art("Berserker_C_Ram")  # 들이받기: 황소 뿔과 충격
def _(A):
    A.rect(C, 0.58, 0.26, 0.3, 0, WHITE, 0.4, LINE)
    A.arc(0.28, 0.48, 0.16, 200, 330, w=LINE * 1.5)
    A.arc(0.72, 0.48, 0.16, 210, 340, w=LINE * 1.5)
    A.line(0.18, 0.44, 0.13, 0.3, w=LINE * 1.3)
    A.line(0.82, 0.44, 0.87, 0.3, w=LINE * 1.3)
    rays(A, C, 0.2, 0.04, 0.12, 5, -90, spread=140, color=A.accent)
    A.disc(0.44, 0.56, 0.02)
    A.disc(0.56, 0.56, 0.02)


@art("Berserker_C_Grudge")  # 앙심: 가늘게 뜬 눈과 숨긴 단검
def _(A):
    A.arc(C, 0.62, 0.34, 225, 315, w=LINE)
    A.arc(C, 0.2, 0.34, 60, 120, w=LINE)
    A.disc(C, 0.44, 0.05, A.accent)
    A.line(0.26, 0.3, 0.42, 0.36, w=LINE * 1.2)
    A.line(0.74, 0.3, 0.58, 0.36, w=LINE * 1.2)
    dagger(A, C, 0.72, 0.3, 0)


@art("Berserker_C_Trance")  # 무아: 소용돌이 눈
def _(A):
    A.arc(C, 0.66, 0.36, 225, 315, w=LINE)
    A.arc(C, 0.34, 0.36, 45, 135, w=LINE)
    spiral(A, C, C, 0.14, 2.2, color=A.accent, w=THIN * 1.2)


@art("Berserker_C_Swing")  # 휘두르기: 큰 도끼 한 바퀴
def _(A):
    axe(A, 0.46, 0.5, 0.72, -35)
    A.arc(0.46, 0.5, 0.36, 110, 250, w=THIN, color=A.accent)
    A.arc(0.46, 0.5, 0.3, 120, 240, w=THIN, color=A.accent, tr=0.4)


@art("Berserker_C_Boiling")  # 끓어오름: 끓는 솥
def _(A):
    A.arc(C, 0.5, 0.28, 0, 180, w=LINE)
    A.line(0.18, 0.5, 0.82, 0.5, w=LINE * 1.2)
    A.line(0.14, 0.46, 0.22, 0.52, w=LINE)
    A.line(0.86, 0.46, 0.78, 0.52, w=LINE)
    for (x, y, r) in ((0.4, 0.4, 0.05), (0.55, 0.34, 0.04), (0.48, 0.24, 0.03), (0.62, 0.42, 0.03)):
        A.ring(x, y, r, w=THIN, color=A.accent)
    flame(A, C, 0.86, 0.14, color=A.accent, inner=False, w=THIN)


@art("Berserker_C_Numb")  # 무감각: 번개를 막는 손
def _(A):
    hand_open(A, 0.44, 0.56, 0.6)
    bolt(A, 0.7, 0.3, 0.3, color=A.accent, w=THIN)
    A.line(0.58, 0.18, 0.84, 0.44, w=LINE)


@art("Berserker_C_Headbutt")  # 박치기: 머리 부딪힘과 별
def _(A):
    A.ring(0.36, 0.56, 0.18, w=LINE)
    A.arc(0.36, 0.56, 0.24, 300, 360, w=THIN, tr=0.4)
    burst(A, 0.66, 0.42, 0.18, 10, color=A.accent, w=THIN * 1.2)
    star(A, 0.72, 0.72, 0.05, color=WHITE, w=THIN)
    star(A, 0.22, 0.3, 0.04, color=WHITE, w=THIN)


@art("Berserker_C_RageFuel")  # 화풀이: 핏방울을 먹는 불
def _(A):
    flame(A, C, 0.42, 0.62, color=A.accent)
    drop(A, C, 0.8, 0.22, color=BLOOD)


@art("Berserker_C_DeathWish")  # 집중: 조준선과 한 방울
def _(A):
    target(A, C, C, 0.26, color=WHITE, dot=A.accent)
    drop(A, 0.74, 0.74, 0.16, color=BLOOD)


@art("Berserker_C_UnstoppingArm")  # 자랑: 치켜든 주먹과 반짝
def _(A):
    fist(A, C, 0.5, 0.46)
    A.rect(C, 0.76, 0.14, 0.24, 0, WHITE, 0.3, LINE)
    sparkle(A, 0.24, 0.26, 0.07, color=A.accent, w=THIN)
    sparkle(A, 0.78, 0.22, 0.05, color=A.accent, w=THIN)


@art("Berserker_C_Stubborn")  # 고집: 잠긴 자물쇠에 뿔
def _(A):
    lock(A, C, 0.56, 0.6, key=A.accent)
    A.arc(0.3, 0.3, 0.12, 180, 300, w=LINE * 1.3)
    A.arc(0.7, 0.3, 0.12, 240, 360, w=LINE * 1.3)


@art("Berserker_C_Overkill")  # 과잉 살상: 도끼가 지나간 자리로 넘치는 피
def _(A):
    axe(A, 0.4, 0.44, 0.6, -45)
    for (x, y, sz) in ((0.66, 0.62, 0.2), (0.78, 0.46, 0.14), (0.6, 0.8, 0.14)):
        drop(A, x, y, sz, color=BLOOD)


@art("Berserker_C_Callus")  # 굳은살: 판이 덧댄 손
def _(A):
    hand_open(A, C, 0.52, 0.66)
    for (x, y) in ((0.46, 0.6), (0.56, 0.62)):
        stone(A, x, y, 0.05, color=A.accent, w=THIN)


@art("Berserker_C_NoRetreat")  # 잠깐의 준비: 방패 다음 한 걸음
def _(A):
    shield(A, 0.34, 0.5, 0.44)
    arrow(A, 0.52, 0.5, 0.84, 0.5, color=A.accent, w=LINE * 1.2, head=0.08)
