# -*- coding: utf-8 -*-
# 월 브레이커 카드 그림 — 허물기·희생·벼랑·신앙
from cards import *  # noqa: F401,F403


def rubble(A, cx, cy, s=0.4, color=WHITE, seed=3):
    shards(A, cx, cy, s, 6, color=color, w=THIN, seed=seed)


@art("WallBreaker_E_BrokenRampart")  # 무너진 성벽
def _(A):
    bricks(A, C, 0.62, 0.6, rows=3, cols=3, gaps={(0, 2), (0, 3), (1, 2)}, w=THIN * 1.2)
    crack(A, 0.64, 0.46, 0.3, 60, color=A.accent, w=THIN)
    rubble(A, 0.74, 0.3, 0.24, color=A.accent)


@art("WallBreaker_E_SelfHarm")  # 자해: 스스로를 향한 망치와 피
def _(A):
    hammer(A, 0.46, 0.44, 0.56, -130)
    heart(A, 0.64, 0.66, 0.34)
    drop(A, 0.76, 0.84, 0.12, color=A.accent)


@art("WallBreaker_E_Martyrdom")  # 순교: 광륜과 부러진 칼
def _(A):
    A.ellipse(C, 0.22, 0.16, 0.05, 0, w=LINE, color=A.accent)
    A.line(C, 0.34, C, 0.58, w=LINE)
    A.line(0.4, 0.4, 0.6, 0.4, w=LINE)
    A.line(0.52, 0.64, 0.58, 0.84, w=LINE)
    A.line(0.46, 0.6, 0.54, 0.62, w=THIN, tr=0.4)


@art("WallBreaker_E_Levelling")  # 평탄화: 땅을 고르는 망치
def _(A):
    hammer(A, 0.56, 0.4, 0.56, -120)
    A.line(0.14, 0.72, 0.86, 0.72, w=LINE, color=A.accent)
    rubble(A, 0.3, 0.62, 0.2)


@art("WallBreaker_R_SoftBlow")  # 동정: 하트가 달린 망치
def _(A):
    hammer(A, 0.48, 0.5, 0.62, -120)
    heart(A, 0.72, 0.3, 0.26, color=A.accent, filled=True)


@art("WallBreaker_R_Salvage")  # 잔해 회수: 모아 올리는 벽돌
def _(A):
    rubble(A, C, 0.72, 0.3)
    A.rect(C, 0.36, 0.28, 0.13, 0, A.accent, 0.1, LINE)
    arrow(A, C, 0.62, C, 0.46, w=THIN, head=0.05)


@art("WallBreaker_R_Madness")  # 광증: 소용돌이 두 눈
def _(A):
    spiral(A, 0.36, 0.46, 0.12, 2.2, w=THIN * 1.2)
    spiral(A, 0.64, 0.46, 0.12, 2.2, color=A.accent, w=THIN * 1.2)
    A.arc(C, 0.56, 0.2, 30, 150, w=LINE)


@art("WallBreaker_R_Swallow")  # 섭취: 돌을 삼키는 입
def _(A):
    fangs(A, C, 0.46, 0.6)
    stone(A, C, 0.66, 0.08, color=A.accent)
    arrow(A, C, 0.84, C, 0.76, w=THIN, head=0.04)


@art("WallBreaker_R_PaidBack")  # 앙갚음: 되돌아가는 주먹
def _(A):
    fist(A, 0.62, 0.52, 0.38)
    loop_arrow(A, 0.4, 0.5, 0.2, color=A.accent, w=THIN * 1.3, start=-60, end=200)


@art("WallBreaker_R_Reliquary")  # 성유물: 십자 새긴 함
def _(A):
    box(A, C, 0.56, 0.62)
    cross(A, C, 0.6, 0.2, color=A.accent, w=THIN * 1.3)


@art("WallBreaker_R_Overkill")  # 뒤처리: 넘치는 충격
def _(A):
    hammer(A, 0.42, 0.42, 0.52, -135)
    burst(A, 0.66, 0.66, 0.2, 10, color=A.accent, w=THIN)


@art("WallBreaker_R_Dirge")  # 만가: 종과 떨어지는 방울
def _(A):
    bell(A, 0.44, 0.48, 0.52)
    note(A, 0.72, 0.5, 0.24, color=A.accent)


@art("WallBreaker_R_ChainCollapse")  # 연쇄 붕괴: 넘어지는 돌기둥들
def _(A):
    for i, ang in enumerate((0, 18, 36)):
        A.rect(0.3 + i * 0.18, 0.58, 0.08, 0.32, ang, A.accent if i == 2 else WHITE, 0.1, LINE)
    A.line(0.16, 0.76, 0.86, 0.76, w=THIN, tr=0.4)


@art("WallBreaker_R_DullFlesh")  # 무딘 살: 판을 덧댄 심장
def _(A):
    heart(A, C, 0.52, 0.66)
    for dx in (-0.08, 0.08):
        stone(A, C + dx, 0.5, 0.06, color=A.accent, w=THIN)


@art("WallBreaker_C_Shard")  # 파편
def _(A):
    shards(A, C, C, 0.62, 7, color=WHITE, w=THIN * 1.2, seed=11)
    A.diamond(C, C, 0.08, A.accent)


@art("WallBreaker_C_Tenacity")  # 악착: 금 간 땅을 움켜쥔 손
def _(A):
    fist(A, C, 0.46, 0.5)
    crack(A, C, 0.76, 0.5, 0, color=A.accent, w=THIN)


@art("WallBreaker_C_RuinPrayer")  # 폐허의 기도: 무너진 벽 위 촛불
def _(A):
    bricks(A, C, 0.72, 0.56, rows=2, cols=3, gaps={(0, 0), (0, 3)}, w=THIN)
    candle(A, C, 0.42, 0.42, fire=A.accent)


@art("WallBreaker_C_SameStride")  # 자비: 같은 보폭
def _(A):
    footprints(A, 0.38, C, 0.44, ang=-90)
    footprints(A, 0.62, C, 0.44, ang=-90)
    A.line(0.3, 0.84, 0.7, 0.84, w=THIN, color=A.accent)


@art("WallBreaker_C_FirstCrack")  # 이미 새겨진 균열
def _(A):
    A.rect(C, C, 0.56, 0.5, 0, WHITE, 0.06, LINE)
    crack(A, C, C, 0.46, 70, color=A.accent, w=LINE)


@art("WallBreaker_C_LooseBrick")  # 헐거운 벽돌: 빠져나오는 한 장
def _(A):
    bricks(A, 0.42, 0.52, 0.5, rows=3, cols=2, gaps={(1, 1)}, w=THIN * 1.2)
    A.rect(0.74, 0.6, 0.22, 0.1, 18, A.accent, 0.1, LINE)


@art("WallBreaker_C_ShoveOff")  # 밀어내기: 미는 손바닥
def _(A):
    hand_open(A, 0.36, 0.52, 0.5)
    chevrons(A, 0.7, 0.5, 0.24, 2, 0, gap=0.09, color=A.accent)


@art("WallBreaker_C_FleshPrice")  # 살점 값: 피와 벽돌을 다는 저울
def _(A):
    scales(A, C, 0.54, 0.62, tilt=-10)
    drop(A, 0.3, 0.6, 0.1, color=A.accent)


@art("WallBreaker_C_RuinOath")  # 파괴의 맹세: 찢긴 깃발
def _(A):
    banner(A, C, 0.52, 0.64)
    crack(A, 0.56, 0.32, 0.16, 90, color=A.accent, w=THIN)


@art("WallBreaker_C_DebrisPlus")  # 더 많은 잔해
def _(A):
    shards(A, C, C, 0.7, 9, w=THIN, seed=5)
    shards(A, C, C, 0.4, 5, color=A.accent, w=THIN, seed=9)


@art("WallBreaker_C_ShortWindup")  # 광적인 파괴: 망치와 빠른 화살
def _(A):
    hammer(A, 0.4, 0.5, 0.56, -60)
    chevrons(A, 0.72, 0.5, 0.2, 3, 0, gap=0.07, color=A.accent, w=THIN)


@art("WallBreaker_C_Defenceless")  # 무방비: 깨진 방패
def _(A):
    shield(A, C, C, 0.62)
    crack(A, C, 0.48, 0.5, 90, color=A.accent, w=LINE)


@art("WallBreaker_C_WeakPoint")  # 약점 파괴: 금 위의 과녁
def _(A):
    crack(A, C, C, 0.62, 30, w=THIN)
    target(A, C, C, 0.14, w=THIN, color=A.accent, dot=A.accent)


@art("WallBreaker_C_Comrade")  # 병 주고 약 주기: 망치와 붕대
def _(A):
    hammer(A, 0.38, 0.44, 0.5, -120)
    A.rect(0.66, 0.64, 0.24, 0.1, 45, WHITE, 0.3, LINE)
    A.rect(0.66, 0.64, 0.24, 0.1, -45, A.accent, 0.3, LINE)


@art("WallBreaker_C_Oblation")  # 제물: 제단과 핏방울
def _(A):
    A.rect(C, 0.72, 0.5, 0.14, 0, WHITE, 0.06, LINE)
    drop(A, C, 0.46, 0.3, color=A.accent)


@art("WallBreaker_C_LongHaft")  # 긴 자루
def _(A):
    hammer(A, C, 0.5, 0.82, -55)


@art("WallBreaker_C_Cliff")  # 벼랑: 절벽 끝
def _(A):
    A.poly([(0.14, 0.5), (0.56, 0.5), (0.5, 0.62), (0.58, 0.74), (0.5, 0.88)], w=LINE)
    A.line(0.14, 0.5, 0.14, 0.88, w=THIN, tr=0.5)
    for (x, y) in ((0.66, 0.62), (0.72, 0.76)):
        A.diamond(x, y, 0.03, A.accent)
    person(A, 0.42, 0.36, 0.28)


@art("WallBreaker_C_LightHand")  # 무뎌진 죄책감: 깃털과 망치
def _(A):
    feather(A, 0.4, 0.44, 0.56, -50, color=A.accent)
    hammer(A, 0.64, 0.62, 0.4, -120)


@art("WallBreaker_C_Tireless")  # 최선의 교본: 책과 망치
def _(A):
    book(A, C, 0.62, 0.56)
    hammer(A, 0.62, 0.3, 0.34, -140)
    A.disc(0.36, 0.3, 0.02, A.accent)


@art("WallBreaker_C_SharedLoad")  # 광인: 소용돌이 눈과 이빨
def _(A):
    spiral(A, 0.38, 0.4, 0.09, 2.0, color=A.accent, w=THIN)
    spiral(A, 0.62, 0.4, 0.09, 2.0, color=A.accent, w=THIN)
    fangs(A, C, 0.66, 0.44)
