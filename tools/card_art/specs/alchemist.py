# -*- coding: utf-8 -*-
# 연금술사 카드 그림 — 병·약재·불·부작용
from cards import *  # noqa: F401,F403

POISON = "#8cd070"
FIRE = "#ff9450"
OIL = "#b8a860"


@art("Alchemist_R_IronStomach")  # 강철 위장: 방패 두른 플라스크
def _(A):
    flask(A, 0.44, 0.52, 0.56, liquid=POISON)
    shield(A, 0.7, 0.62, 0.3, color=A.accent, w=THIN * 1.3)


@art("Alchemist_R_BottleKeeping")  # 준비성: 선반의 병들
def _(A):
    A.line(0.14, 0.74, 0.86, 0.74, w=LINE)
    for i, (x, liq) in enumerate(((0.28, POISON), (0.5, None), (0.72, FIRE))):
        bottle(A, x, 0.54, 0.34, liquid=liq)
    A.disc(0.5, 0.26, 0.02, A.accent)


@art("Alchemist_R_CriticalBlend")  # 가득 찬 가방: 병 셋이 든 가방
def _(A):
    A.rect(C, 0.62, 0.62, 0.36, 0, WHITE, 0.2, LINE)
    A.arc(C, 0.44, 0.14, 180, 360, w=LINE)
    for x, col in ((0.34, POISON), (0.5, FIRE), (0.66, OIL)):
        A.line(x, 0.36, x, 0.48, w=LINE, color=col)
        A.disc(x, 0.34, 0.025, col)


@art("Alchemist_R_Chain")  # 연쇄 반응: 이어진 세 플라스크와 번개
def _(A):
    for i, x in enumerate((0.26, 0.5, 0.74)):
        flask(A, x, 0.6, 0.3, liquid=A.accent if i == 1 else None, w=THIN * 1.2)
    bolt(A, 0.38, 0.3, 0.16, color=A.accent, w=THIN)
    bolt(A, 0.62, 0.3, 0.16, color=A.accent, w=THIN)


@art("Alchemist_R_Napalm")  # 네이팜: 불붙은 병
def _(A):
    bottle(A, 0.44, 0.58, 0.5, liquid=FIRE)
    flame(A, 0.46, 0.22, 0.24, color=A.accent, inner=False, w=THIN * 1.2)
    A.line(0.46, 0.3, 0.44, 0.38, w=THIN)


@art("Alchemist_R_Recycle")  # 방탄유리병: 도는 화살 속 빈 병
def _(A):
    loop_arrow(A, C, C, 0.32, color=A.accent, w=THIN * 1.3)
    bottle(A, C, 0.52, 0.4)


@art("Alchemist_C_AmpleMeasure")  # 넉넉한 계량: 눈금 비커
def _(A):
    A.poly([(0.3, 0.22), (0.34, 0.8), (0.66, 0.8), (0.7, 0.22)], w=LINE)
    for i in range(5):
        y = 0.34 + i * 0.1
        A.line(0.36, y, 0.44 if i % 2 else 0.48, y, w=THIN)
    A.fill(C, 0.66, 0.3, 0.24, 0, A.accent, corner=0.1, tr=0.2)


@art("Alchemist_C_Spare")  # 여분 병: 나란한 빈 병 둘
def _(A):
    bottle(A, 0.38, 0.54, 0.46)
    bottle(A, 0.64, 0.58, 0.4, color=A.accent)


@art("Alchemist_C_Extract")  # 농축: 방울이 떨어지는 플라스크
def _(A):
    flask(A, C, 0.6, 0.56, liquid=A.accent)
    drop(A, C, 0.2, 0.14, color=A.accent)


@art("Alchemist_C_Toxin")  # 별걸 다 쓰네: 해골 표시 병
def _(A):
    bottle(A, C, C, 0.6, liquid=None)
    skull(A, C, 0.6, 0.2, color=A.accent, w=THIN)


@art("Alchemist_C_Slick")  # 미끌미끌: 기름 방울과 미끄러운 물결
def _(A):
    drop(A, C, 0.4, 0.34, color=OIL)
    wave(A, C, 0.72, 0.56, 0.03, 2, color=A.accent)
    wave(A, C, 0.8, 0.56, 0.03, 2, tr=0.4)


@art("Alchemist_C_Tolerance")  # 내성: 방패 안 하트
def _(A):
    shield(A, C, C, 0.62)
    heart(A, C, 0.46, 0.3, color=A.accent, filled=True)


@art("Alchemist_C_Herbal")  # 약초학: 풀잎 가지
def _(A):
    sprig(A, 0.48, 0.52, 0.66, color=A.accent)


@art("Alchemist_C_Bulk")  # 고중량 고반복: 아령
def _(A):
    dumbbell(A, C, C, 0.66, ang=-15)
    A.disc(0.5, 0.28, 0.02, A.accent)


@art("Alchemist_C_Sideeffect")  # 부작용 완화: 알약과 방패
def _(A):
    pill(A, 0.44, 0.46, 0.5, -40, half=A.accent)
    shield(A, 0.7, 0.68, 0.26, w=THIN * 1.2)


@art("Alchemist_C_Killherb")  # 채집: 낫과 약초
def _(A):
    sickle(A, 0.44, 0.48, 0.56)
    leaf(A, 0.7, 0.66, 0.24, -60, color=A.accent)


@art("Alchemist_C_Cooldown")  # 시간 날 때 해둬야지: 모래시계와 플라스크
def _(A):
    hourglass(A, 0.36, C, 0.46, sand=A.accent)
    flask(A, 0.68, 0.56, 0.36, liquid=A.accent)


@art("Alchemist_C_Lowhp")  # 절박함: 반쯤 빈 하트
def _(A):
    heart(A, C, C, 0.62)
    A.fill(C, 0.62, 0.16, 0.1, 0, A.accent, corner=0.4)


@art("Alchemist_C_Sturdy")  # 두꺼운 유리: 두 겹 병
def _(A):
    bottle(A, C, C, 0.6)
    A.rect(C, 0.53, 0.26, 0.36, 0, A.accent, 0.25, THIN)


@art("Alchemist_C_Grind")  # 통달: 절구와 공이
def _(A):
    mortar(A, C, 0.56, 0.64)
    leaf(A, 0.36, 0.34, 0.16, -30, color=A.accent, w=THIN)
